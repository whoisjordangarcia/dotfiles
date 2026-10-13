// The statusLine command: payload on stdin, the statusline on stdout. Renders every run from the
// payload plus what the statusline-mod plugin collected (/tmp/statusline-mod/<session id>.state), so
// it needs no git, gh or lsof of its own; without that file (mod not loaded) it collects them itself
// behind statusline.sh's caches. statusline_test.sh drives it through cli/statusline.sh.
import { execFileSync, spawn } from 'node:child_process'
import { createHash } from 'node:crypto'
import { appendFileSync, existsSync, mkdirSync, readFileSync, renameSync, statSync, utimesSync, writeFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'

import { collectBaseRef, collectCi, collectGit, collectNodeApps, collectPr, osc8Supported } from '../hooks/statusline/collect.ts'
import { fromPayload } from '../hooks/statusline/payload.ts'
import { ciGlyph, render } from '../hooks/statusline/render.ts'
import type { Io, Shared, State } from '../hooks/statusline/types.ts'

const io: Io = {
  run: async (argv, cwd) => {
    try {
      return { exitCode: 0, stdout: execFileSync(argv[0]!, argv.slice(1), { cwd, encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] }) }
    } catch (e) {
      const err = e as { status?: number; stdout?: string }
      return { exitCode: err.status ?? 1, stdout: err.stdout ?? '' }
    }
  },
  exists: async path => existsSync(path),
}

const now = Math.floor(Date.now() / 1000)
const md5 = (s: string) => createHash('md5').update(s).digest('hex')
const age = (file: string) => (existsSync(file) ? now - Math.floor(statSync(file).mtimeMs / 1000) : Infinity)
const write = (file: string, text: string) => {
  mkdirSync(file.replace(/\/[^/]*$/, ''), { recursive: true })
  writeFileSync(`${file}.${process.pid}`, text)
  renameSync(`${file}.${process.pid}`, file)
}

const PR_DIR = '/tmp/claude-statusline-pr-cache'
const GIT_DIR = '/tmp/claude-statusline-git-cache'

async function fetchPr(cwd: string, branch: string, file: string) {
  const p = await collectPr(io, cwd, branch)
  // No PR is four empty fields, as statusline.sh wrote it.
  write(file, p.url ? [p.url, p.state, String(p.draft), p.review].join('\t') : '\t\t\t')
}
async function fetchCi(cwd: string, branch: string, file: string) {
  write(file, ciGlyph(await collectCi(io, cwd, branch)))
}

// Stale-while-revalidate: a stale file is served and refreshed by a detached child (touching it claims
// the refresh so concurrent runs don't stack fetches); only a missing one is fetched in-line.
async function swr(file: string, ttl: number, kind: 'pr' | 'ci', cwd: string, branch: string) {
  const a = age(file)
  if (a < ttl) return
  if (a === Infinity) return kind === 'pr' ? fetchPr(cwd, branch, file) : fetchCi(cwd, branch, file)
  utimesSync(file, new Date(), new Date())
  spawn(process.execPath, [fileURLToPath(import.meta.url), '--refresh', kind, cwd, branch, file], { detached: true, stdio: 'ignore' }).unref()
}

if (process.argv[2] === '--refresh') {
  const [, , , kind, cwd, branch, file] = process.argv as string[]
  await (kind === 'pr' ? fetchPr(cwd!, branch!, file!) : fetchCi(cwd!, branch!, file!))
  process.exit(0)
}

const raw = readFileSync(0, 'utf8')
let input: any = {}
try {
  input = JSON.parse(raw) ?? {}
} catch {
  // Malformed input still renders, as statusline.sh survives a failed jq.
}
const state: State = { ...fromPayload(input, process.env.CLAUDE_EFFORT ?? ''), baseRef: '', ci: '', nodeApps: [] }

// ai-stats reads plan limits from the whole payload; one history line per 5 minutes at most.
if (state.rate5h.pct !== -1) {
  const stats = `${process.env.XDG_CACHE_HOME || `${process.env.HOME}/.cache`}/ai-stats`
  write(`${stats}/statusline.json`, raw)
  if (age(`${stats}/limits.log`) >= 300) appendFileSync(`${stats}/limits.log`, `${now} ${state.rate5h.pct} ${state.rate7d.pct}\n`)
}

const cwd = state.cwd
let shared: Shared | undefined
const sid = typeof input.session_id === 'string' ? input.session_id : ''
if (sid && existsSync(`/tmp/statusline-mod/${sid}.state`)) {
  try {
    const s = JSON.parse(readFileSync(`/tmp/statusline-mod/${sid}.state`, 'utf8')) as Shared
    if (s.cwd === cwd) shared = s
  } catch {
    // Mid-write: collect this run instead.
  }
}

// A spinner only ticks while its file does; a session killed mid-reply mustn't leave one spinning.
if (shared?.speed?.spin && age(`/tmp/statusline-mod/${sid}.state`) > 3) shared.speed = { rate: shared.speed.rate }
// The mod draws running dev servers above the prompt, so the line leaves them out.
if (shared) Object.assign(state, shared, { nodeApps: [] })
else if (cwd && existsSync(cwd)) {
  const key = md5(cwd)
  const gitFile = `${GIT_DIR}/${key}_git.json`
  if (age(gitFile) < 10) state.git = JSON.parse(readFileSync(gitFile, 'utf8')) ?? undefined
  else {
    state.git = await collectGit(io, cwd)
    write(gitFile, JSON.stringify(state.git ?? null))
  }
  const branch = state.git?.branch ?? ''
  if (branch) {
    const baseFile = `${GIT_DIR}/${key}_base`
    if (age(baseFile) < 600) state.baseRef = readFileSync(baseFile, 'utf8')
    else write(baseFile, (state.baseRef = await collectBaseRef(io, cwd, branch)))

    const prFile = `${PR_DIR}/${md5(`${cwd}:${branch}`)}`
    await swr(prFile, 120, 'pr', cwd, branch)
    const [url = '', prState = '', draft = '', review = ''] = readFileSync(prFile, 'utf8').split('\t')
    if (url) state.pr = { url, state: prState, draft: draft === 'true', review }
    if (url && prState === 'OPEN') {
      await swr(`${prFile}_ci`, 60, 'ci', cwd, branch)
      state.ci = readFileSync(`${prFile}_ci`, 'utf8')
    }
  }
  const nodeFile = `/tmp/claude-statusline-node-cache/${key}_node`
  if (existsSync(`${cwd}/package.json`) || existsSync(nodeFile)) {
    if (age(nodeFile) >= 30) write(nodeFile, (await collectNodeApps(io, cwd)).join(' '))
    state.nodeApps = readFileSync(nodeFile, 'utf8').split(' ').filter(Boolean)
  }
}

// Detected and cached by the mod; worked out here only without it.
let osc8 = shared?.osc8
if (osc8 === undefined) {
  const client = process.env.TMUX ? (await io.run(['tmux', 'display', '-p', '#{client_termname}'])).stdout : ''
  osc8 = osc8Supported(process.env, client)
}

// Claude Code sets COLUMNS to the terminal width for each run; STATUSLINE_COLS overrides.
const cols = Number(process.env.STATUSLINE_COLS || process.env.COLUMNS || 0) || 0

process.stdout.write(
  render(state, {
    cols,
    oneLine: !!process.env.STATUSLINE_ONE_LINE,
    osc8,
    hideModelRegex: process.env.STATUSLINE_HIDE_MODEL_REGEX ?? 'Opus 4\\.8.*1M',
    now,
  }),
)
