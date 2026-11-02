import { atom, read, update } from 'claude-code'
import type { EngineInterface, Register } from 'claude-code'

import { appRows, collectBaseRef, collectBranchDiff, collectCi, collectGit, collectPr, nodeAppsIn, osc8Supported, scanListeners } from './statusline/collect'
import { ciGlyph, nodeAppUrl } from './statusline/render'
import type { Apps } from '../types'
import type { Io, Shared } from './statusline/types'

// The statusLine command (cli/statusline.ts) renders each run from its own payload plus this file, so
// the slow parts (git, gh, lsof) and tok/s never hold it up: /tmp/statusline-mod/<session id>.state.
const DIR = '/tmp/statusline-mod'

const apps = atom({ plugin: 'statusline-mod', key: 'apps' } as const, [] as Apps)

// Each source on its own lifetime, so the 1s statusLine refresh never waits on the slow ones: git moves
// as you work; the base branch, PR and CI rarely do (and cost a network call or a dozen git runs).
const TTL_MS = { git: 3000, diff: 3000, base: 600_000, pr: 120_000, ci: 60_000, node: 30_000, osc8: 60_000 }
// Between turns the tree mostly changes by hand, so git and the diff are polled this much less often.
const IDLE_FACTOR = 5
const POLL_MS = 1000

// Collected once for every session on the machine, per checkout (and branch) where the answer depends on
// one: with dozens of sessions open, each running its own git and lsof was most of the machine's load.
const SHARED = `${DIR}/shared`

/** `collect`'s value as some session last stored it under `key`, collecting afresh once it is `ttl` old.
 * A stale entry is re-stamped before collecting, so the other sessions keep reading it meanwhile
 * instead of all collecting at once. */
async function shared<T>($: EngineInterface, key: string, ttl: number, collect: () => Promise<T>): Promise<T> {
  const path = `${SHARED}/${encodeURIComponent(key)}.json`
  const now = await $.clock.now()
  let held: { at: number; value: T } | undefined
  try {
    held = JSON.parse(String(await $.fs.read(path)))
  } catch {
    // Missing, or caught mid-write: collect.
  }
  if (held && now - held.at < ttl) return held.value
  if (held) await $.fs.write(path, JSON.stringify({ at: now, value: held.value }))
  const value = await collect()
  await $.fs.write(path, JSON.stringify({ at: await $.clock.now(), value }))
  return value
}

const SPIN = '⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
// The statusLine re-reads once a second; 250ms keeps each read on a fresh frame without busy writes.
const TICK_MS = 250
// Usage only arrives when the step ends, so the live rate guesses tokens from streamed text.
const CHARS_PER_TOKEN = 4

const mod = {
  id: '',
  // speed starts empty, not absent: the statusLine then holds its tok/s row from the first draw.
  shared: { cwd: '', baseRef: '', ci: '', nodeApps: [], speed: {} } as Shared,
  fetched: { git: -Infinity, diff: -Infinity, base: -Infinity, pr: -Infinity, ci: -Infinity, node: -Infinity, osc8: -Infinity },
  /** The branch the PR, CI and base were fetched for. */
  branch: '',
  isRefreshing: false,
  written: '',
  frame: 0,
  turnTimer: undefined as { cancel: () => void } | undefined,
  /** The main agent's current reply stream, for the live tok/s estimate. */
  stream: undefined as { first?: number; chars: number; ticks: number } | undefined,
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
      mod.fetched = { ...mod.fetched, git: -Infinity, diff: -Infinity, base: -Infinity, pr: -Infinity, ci: -Infinity, node: -Infinity }
      s.git = undefined
      s.branchDiff = undefined
      s.nodeApps = []
      await update($, apps, () => [])
    }

    const idle = mod.turnTimer ? 1 : IDLE_FACTOR
    if (now - mod.fetched.git >= TTL_MS.git * idle) {
      s.git = await shared($, `git:${cwd}`, TTL_MS.git * idle, () => collectGit(io, cwd))
      mod.fetched.git = now
    }
    const branch = s.git?.branch ?? ''
    if (branch !== mod.branch) {
      mod.branch = branch
      mod.fetched.base = mod.fetched.diff = mod.fetched.pr = mod.fetched.ci = -Infinity
      s.baseRef = ''
      s.branchDiff = undefined
      s.pr = undefined
      s.ci = ''
    }
    await write($)

    if (branch && now - mod.fetched.base >= TTL_MS.base) {
      s.baseRef = await shared($, `base:${cwd}:${branch}`, TTL_MS.base, () => collectBaseRef(io, cwd, branch))
      mod.fetched.base = now
    }
    if (s.baseRef && s.baseRef !== branch && now - mod.fetched.diff >= TTL_MS.diff * idle) {
      const base = s.baseRef
      s.branchDiff = await shared($, `diff:${cwd}:${base}`, TTL_MS.diff * idle, () => collectBranchDiff(io, cwd, base))
      mod.fetched.diff = now
    }
    if (branch && now - mod.fetched.pr >= TTL_MS.pr) {
      const pr = await shared($, `pr:${cwd}:${branch}`, TTL_MS.pr, () => collectPr(io, cwd, branch))
      s.pr = pr.url ? pr : undefined
      mod.fetched.pr = now
    }
    // CI only matters while the PR is open.
    if (s.pr?.state === 'OPEN' && now - mod.fetched.ci >= TTL_MS.ci) {
      s.ci = ciGlyph(await shared($, `ci:${cwd}:${branch}`, TTL_MS.ci, () => collectCi(io, cwd, branch)))
      mod.fetched.ci = now
    }
    // The lsof scan is skipped unless this looks like a Node project or an earlier scan found apps.
    if (now - mod.fetched.node >= TTL_MS.node && (s.nodeApps.length || (await io.exists(`${cwd}/package.json`)))) {
      s.nodeApps = nodeAppsIn(await shared($, 'listeners', TTL_MS.node, () => scanListeners(io)), cwd)
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
