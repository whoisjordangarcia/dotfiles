import { atom, read, update } from 'claude-code'
import type { EngineInterface, Register } from 'claude-code'

import { collectBaseRef, collectCi, collectGit, collectNodeApps, collectPr, osc8Supported } from './statusline/collect'
import { ciGlyph, KNOWN_APPS, nodeAppUrl } from './statusline/render'
import type { Apps } from '../types'
import type { Io, Shared } from './statusline/types'

// The statusLine command (cli/statusline.ts) renders each run from its own payload plus this file, so
// the slow parts (git, gh, lsof) and tok/s never hold it up: /tmp/statusline-mod/<session id>.state.
const DIR = '/tmp/statusline-mod'

const apps = atom({ plugin: 'statusline-mod', key: 'apps' } as const, [] as Apps)

// Each source on its own lifetime, so the 1s statusLine refresh never waits on the slow ones: git moves
// as you work; the base branch, PR and CI rarely do (and cost a network call or a dozen git runs).
const TTL_MS = { git: 3000, base: 600_000, pr: 120_000, ci: 60_000, node: 30_000, osc8: 60_000 }
const POLL_MS = 1000

const SPIN = '⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
// The statusLine re-reads once a second; 250ms keeps each read on a fresh frame without busy writes.
const TICK_MS = 250
// Usage only arrives when the step ends, so the live rate guesses tokens from streamed text.
const CHARS_PER_TOKEN = 4

const mod = {
  id: '',
  // speed starts empty, not absent: the statusLine then holds its tok/s row from the first draw.
  shared: { cwd: '', baseRef: '', ci: '', nodeApps: [], speed: {} } as Shared,
  fetched: { git: -Infinity, base: -Infinity, pr: -Infinity, ci: -Infinity, node: -Infinity, osc8: -Infinity },
  /** The branch the PR, CI and base were fetched for. */
  branch: '',
  isRefreshing: false,
  written: '',
  frame: 0,
  turnTimer: undefined as { cancel: () => void } | undefined,
  /** The main agent's current reply stream, for the live tok/s estimate. */
  stream: undefined as { first?: number; chars: number; ticks: number } | undefined,
}

// A set-up checkout (node_modules present) lists every app it holds, running or not, so a down one shows;
// anywhere else only what is running. Running apps the list doesn't know follow, as found. Nothing
// running at all means no rows.
async function appRows(io: Io, cwd: string, running: string[]): Promise<Apps> {
  const ports = new Map(running.map(e => [e.slice(0, e.lastIndexOf(':')), e.slice(e.lastIndexOf(':') + 1)]))
  const rows: Apps = []
  if (await io.exists(`${cwd}/node_modules`)) {
    for (const [name, dir] of Object.entries(KNOWN_APPS)) {
      if (await io.exists(`${cwd}/${dir}`)) rows.push({ name, port: ports.get(name) })
    }
  }
  for (const [name, port] of ports) if (!rows.some(r => r.name === name)) rows.push({ name, port })
  return rows.some(r => r.port) ? rows : []
}

function ioFor($: EngineInterface): Io {
  return {
    run: async (argv, cwd) => {
      try {
        const r = await $.process.run(argv, { cwd, timeoutMs: 15_000 })
        return { exitCode: r.exitCode, stdout: r.stdout }
      } catch {
        return { exitCode: 127, stdout: '' }
      }
    },
    exists: path => $.fs.exists(path),
  }
}

async function write($: EngineInterface) {
  const text = JSON.stringify(mod.shared)
  if (!mod.id || text === mod.written) return
  mod.written = text
  await $.fs.write(`${DIR}/${mod.id}.state`, text)
}

async function refresh($: EngineInterface) {
  if (mod.isRefreshing) return
  mod.isRefreshing = true
  try {
    const io = ioFor($)
    const now = await $.clock.now()
    const s = mod.shared
    const cwd = await $.session.cwd()
    if (cwd !== s.cwd) {
      s.cwd = cwd
      mod.fetched = { ...mod.fetched, git: -Infinity, base: -Infinity, pr: -Infinity, ci: -Infinity, node: -Infinity }
      s.git = undefined
      s.nodeApps = []
      await update($, apps, () => [])
    }

    if (now - mod.fetched.git >= TTL_MS.git) {
      s.git = await collectGit(io, cwd)
      mod.fetched.git = now
    }
    const branch = s.git?.branch ?? ''
    if (branch !== mod.branch) {
      mod.branch = branch
      mod.fetched.base = mod.fetched.pr = mod.fetched.ci = -Infinity
      s.baseRef = ''
      s.pr = undefined
      s.ci = ''
    }
    await write($)

    if (branch && now - mod.fetched.base >= TTL_MS.base) {
      s.baseRef = await collectBaseRef(io, cwd, branch)
      mod.fetched.base = now
    }
    if (branch && now - mod.fetched.pr >= TTL_MS.pr) {
      const pr = await collectPr(io, cwd, branch)
      s.pr = pr.url ? pr : undefined
      mod.fetched.pr = now
    }
    // CI only matters while the PR is open.
    if (s.pr?.state === 'OPEN' && now - mod.fetched.ci >= TTL_MS.ci) {
      s.ci = ciGlyph(await collectCi(io, cwd, branch))
      mod.fetched.ci = now
    }
    // The lsof scan is skipped unless this looks like a Node project or an earlier scan found apps.
    if (now - mod.fetched.node >= TTL_MS.node && (s.nodeApps.length || (await io.exists(`${cwd}/package.json`)))) {
      s.nodeApps = await collectNodeApps(io, cwd)
      mod.fetched.node = now
      const rows = await appRows(io, cwd, s.nodeApps)
      if (JSON.stringify(rows) !== JSON.stringify(await read($, apps))) await update($, apps, () => rows)
    }
    if (now - mod.fetched.osc8 >= TTL_MS.osc8) {
      const vars = {
        TMUX: await $.env.get('TMUX'),
        TERM_PROGRAM: await $.env.get('TERM_PROGRAM'),
        TERM: await $.env.get('TERM'),
        VTE_VERSION: await $.env.get('VTE_VERSION'),
        WT_SESSION: await $.env.get('WT_SESSION'),
        KONSOLE_VERSION: await $.env.get('KONSOLE_VERSION'),
      }
      const client = vars.TMUX ? (await io.run(['tmux', 'display', '-p', '#{client_termname}'])).stdout : ''
      s.osc8 = osc8Supported(vars, client)
      mod.fetched.osc8 = now
    }
    await write($)
  } finally {
    mod.isRefreshing = false
  }
}

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    const result = await next(e)
    mod.id = await $.session.id()
    await refresh($)
    $.clock.every(POLL_MS, () => void refresh($))
    return result
  })

  // Spins for the whole turn (thinking, tools, streaming), not just while text streams.
  on('turn.start', async ($, e, next) => {
    const result = await next(e)
    const s = mod.shared
    mod.turnTimer?.cancel()
    mod.turnTimer = $.clock.every(TICK_MS, () => {
      mod.frame++
      if (mod.stream?.first !== undefined) mod.stream.ticks++
      const st = mod.stream
      const est = st?.ticks ? Math.round((st.chars / CHARS_PER_TOKEN) * 1000 / (st.ticks * TICK_MS)) : undefined
      s.speed = { ...s.speed, spin: SPIN.charAt(mod.frame % SPIN.length), est }
      void write($)
    })
    return result
  })

  on('turn.complete', async ($, e, next) => {
    mod.turnTimer?.cancel()
    mod.turnTimer = undefined
    mod.shared.speed = { rate: mod.shared.speed?.rate }
    await write($)
    return next(e)
  })

  // Rate is first chunk → last chunk; subagent steps are left out.
  on('turn.step', async function* ($, e, next) {
    if (e.agentId) return yield* next(e)
    const st = { first: undefined as number | undefined, chars: 0, ticks: 0 }
    mod.stream = st

    let result
    try {
      const stream = next(e)
      let step = await stream.next()
      while (!step.done) {
        st.first ??= await $.clock.now()
        if (step.value.kind === 'text' || step.value.kind === 'thinking') st.chars += step.value.text.length
        yield step.value
        step = await stream.next()
      }
      result = step.value
    } finally {
      mod.stream = undefined
    }

    const out = result.usage?.output_tokens ?? 0
    const elapsed = st.first === undefined ? 0 : (await $.clock.now()) - st.first
    if (out > 0 && elapsed > 0) mod.shared.speed = { ...mod.shared.speed, rate: Math.round((out * 1000) / elapsed), est: undefined }
    await write($)
    return result
  })

  // Only tools that always wait on the person: in auto mode a permission "ask" goes to the classifier.
  on('tool.call', async ($, e, next) => {
    if (e.tool !== 'AskUserQuestion' && e.tool !== 'ExitPlanMode') return next(e)
    mod.shared.speed = { ...mod.shared.speed, blocked: true }
    await write($)
    try {
      return await next(e)
    } finally {
      mod.shared.speed = { ...mod.shared.speed, blocked: undefined }
      await write($)
    }
  })

  // This checkout's dev servers, one row each: a link while running, red while down. The statusLine leaves them out.
  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    const rows = await read($, apps)
    if (e.props.hasSurvey || !rows.length) return next(e)
    const { Box, Link, Text } = $.ui.resolve(e)
    return (
      <Box flexDirection="column">
        {rows.map(({ name, port }) => (
          <Text>
            <Text color={port ? 'success' : 'error'}>● </Text>
            <Text>{name.padEnd(18)}</Text>
            {port ? <Link href={nodeAppUrl(name, port)}>{nodeAppUrl(name, port)}</Link> : <Text color="error">down</Text>}
          </Text>
        ))}
      </Box>
    )
  })
}
