import { Plugin, usePlugin } from '@opencode/plugin/tui'
import { execFile } from 'node:child_process'
import { realpathSync } from 'node:fs'
import { access, readFile, stat } from 'node:fs/promises'
import { fileURLToPath, pathToFileURL } from 'node:url'
import { type Accessor, createMemo, createSignal, For, type JSX, onCleanup, Show } from 'solid-js'

import type { Apps } from '../../../claude/plugins/statusline-mod/types'
import type { Diff, Git, Io, Limit, Pr, State } from '../../../claude/plugins/statusline-mod/hooks/statusline/types'

// Claude Code's statusline-mod in OpenCode: the same collectors and the same render code, whose ANSI is
// turned into spans here. OpenCode loads this through the ~/.config/opencode/plugins symlink without
// resolving it, so a static relative import would look beside the link; these resolve from the file's
// real place in dotfiles.
const statusline = new URL('../../../claude/plugins/statusline-mod/hooks/statusline/', pathToFileURL(realpathSync(fileURLToPath(import.meta.url))))
const { appRows, collectBaseRef, collectBranchDiff, collectCi, collectGit, collectNodeApps, collectPr }: typeof import('../../../claude/plugins/statusline-mod/hooks/statusline/collect') = await import(new URL('collect.ts', statusline).href)
const { ciGlyph, fitLine, formatTokens, line2, nodeAppUrl, round }: typeof import('../../../claude/plugins/statusline-mod/hooks/statusline/render') = await import(new URL('render.ts', statusline).href)

// As statusline-mod's register.tsx: git moves as you work; the base branch, PR and CI rarely do.
const TTL_MS = { git: 3000, diff: 3000, base: 600_000, pr: 120_000, ci: 60_000, node: 30_000 }
const POLL_MS = 1000

// Claude Code's statusline writes its whole payload to statusline.json (ai-stats reads it too); OpenCode's
// Claude subprocess runs without one, so plan limits are only as fresh as the last Claude Code session.
// summary.json is ai-stats' --json, rewritten each time sketchybar's Claude widget runs it.
const AI_STATS = `${process.env.XDG_CACHE_HOME || `${process.env.HOME}/.cache`}/ai-stats`
const LIMITS_POLL_MS = 10_000

// Ultra: no 5h window, and a week worth 10x the base plan's.
const PLAN = { name: 'Ultra', multiplier: 10 }

// $/MTok (input, output, cache read), first prefix match wins: ai-stats' PRICES (configs/ai-stats/ai_stats.py).
const PRICES: [string, number, number, number][] = [
  ['claude-fable-5-1', 10, 50, 0.25],
  ['claude-fable', 10, 50, 1.0],
  ['claude-opus', 5, 25, 0.5],
  ['claude-sonnet-5', 2, 10, 0.2],
  ['claude-sonnet', 3, 15, 0.3],
  ['claude-haiku', 1, 5, 0.1],
]
// Claude Agent's model aliases, each the newest of its family.
const ALIASES: Record<string, string> = { opus: 'claude-opus', sonnet: 'claude-sonnet-5', haiku: 'claude-haiku', fable: 'claude-fable-5-1' }

const io: Io = {
  run: (argv, cwd) =>
    new Promise(resolve =>
      execFile(argv[0]!, argv.slice(1), { cwd, timeout: 15_000 }, (err, stdout) =>
        resolve({ exitCode: err ? (typeof err.code === 'number' ? err.code : 127) : 0, stdout: stdout ?? '' }),
      ),
    ),
  exists: path => access(path).then(
    () => true,
    () => false,
  ),
}

type Collected = { git?: Git; baseRef: string; branchDiff?: Diff; pr?: Pr; ci: string; apps: Apps }

/** The checkout a session belongs to: its directory less the subpath OpenCode records within the repo. */
function sessionRoot(s: any): string | undefined {
  const dir: string | undefined = s?.location?.directory
  const sub: string = s?.subpath ?? ''
  return dir && sub && dir.endsWith(`/${sub}`) ? dir.slice(0, -(sub.length + 1)) : dir
}

function poll(dir: string, set: (c: Collected) => void) {
  const s: Collected = { baseRef: '', ci: '', apps: [] }
  const fetched = { git: -Infinity, diff: -Infinity, base: -Infinity, pr: -Infinity, ci: -Infinity, node: -Infinity }
  let branch = ''
  let busy = false
  const tick = async () => {
    if (busy) return
    busy = true
    try {
      const now = Date.now()
      if (now - fetched.git >= TTL_MS.git) {
        s.git = await collectGit(io, dir)
        fetched.git = now
      }
      if ((s.git?.branch ?? '') !== branch) {
        branch = s.git?.branch ?? ''
        fetched.base = fetched.diff = fetched.pr = fetched.ci = -Infinity
        s.baseRef = ''
        s.branchDiff = s.pr = undefined
        s.ci = ''
      }
      if (branch && now - fetched.base >= TTL_MS.base) {
        s.baseRef = await collectBaseRef(io, dir, branch)
        fetched.base = now
      }
      if (s.baseRef && s.baseRef !== branch && now - fetched.diff >= TTL_MS.diff) {
        s.branchDiff = await collectBranchDiff(io, dir, s.baseRef)
        fetched.diff = now
      }
      if (branch && now - fetched.pr >= TTL_MS.pr) {
        const pr = await collectPr(io, dir, branch)
        s.pr = pr.url ? pr : undefined
        fetched.pr = now
      }
      // CI only matters while the PR is open.
      if (s.pr?.state === 'OPEN' && now - fetched.ci >= TTL_MS.ci) {
        s.ci = ciGlyph(await collectCi(io, dir, branch))
        fetched.ci = now
      }
      if (now - fetched.node >= TTL_MS.node && (s.apps.length || (await io.exists(`${dir}/package.json`)))) {
        s.apps = await appRows(io, dir, await collectNodeApps(io, dir))
        fetched.node = now
      }
      set({ ...s })
    } finally {
      busy = false
    }
  }
  void tick()
  const timer = setInterval(() => void tick(), POLL_MS)
  return () => clearInterval(timer)
}

// One poller per directory, however many slots draw it.
const watched = new Map<string, { state: Accessor<Collected | undefined>; refs: number; stop: () => void }>()

function useCollected(dir: Accessor<string | undefined>) {
  return createMemo(() => {
    const d = dir()
    if (!d) return undefined
    let w = watched.get(d)
    if (!w) {
      const [state, set] = createSignal<Collected>()
      w = { state, refs: 0, stop: poll(d, set) }
      watched.set(d, w)
    }
    w.refs++
    const entry = w
    onCleanup(() => {
      if (--entry.refs > 0) return
      entry.stop()
      watched.delete(d)
    })
    return entry.state
  })
}

async function readJson(file: string) {
  try {
    const [text, info] = await Promise.all([readFile(file, 'utf8'), stat(file)])
    return { data: JSON.parse(text), mtime: Math.floor(info.mtimeMs / 1000) }
  } catch {
    return undefined
  }
}

type Usage = { week?: Limit; limitsMtime: number; costs: [string, number][]; costMtime: number }

const [usage, setUsage] = createSignal<Usage>()
async function readUsage() {
  const [statusline, summary] = await Promise.all([readJson(`${AI_STATS}/statusline.json`), readJson(`${AI_STATS}/summary.json`)])
  const w = statusline?.data?.rate_limits?.seven_day
  // ai-stats' week is the last 7 days; its month is the calendar month.
  const costs = (['today', 'week', 'month'] as const).flatMap(key => {
    const cost = summary?.data?.[key]?.cost_usd
    return typeof cost === 'number' ? [[key, cost] as [string, number]] : []
  })
  setUsage({
    week: typeof w?.used_percentage === 'number' ? { pct: w.used_percentage, resets: w.resets_at ? String(w.resets_at) : '' } : undefined,
    limitsMtime: statusline?.mtime ?? 0,
    costs,
    costMtime: summary?.mtime ?? 0,
  })
}

type Role = 'base' | 'muted' | 'accent' | 'success' | 'warning' | 'error'
type Segment = { text: string; role: Role; href?: string }

// The render code only ever emits full-reset SGRs (`0;…m`) and BEL-terminated OSC 8 links.
const ESCAPES = /\x1b\[([0-9;]*)m|\x1b\]8;;([^\x07]*)\x07/g
const SGR_ROLES: [string, Role][] = [['2', 'muted'], ['31', 'error'], ['32', 'success'], ['33', 'warning'], ['35', 'accent']]

function segments(line: string) {
  const out: Segment[] = []
  let role: Role = 'base'
  let href: string | undefined
  let at = 0
  for (const m of line.matchAll(ESCAPES)) {
    if (m.index > at) out.push({ text: line.slice(at, m.index), role, href })
    at = m.index + m[0].length
    if (m[2] !== undefined) href = m[2] || undefined
    else {
      const codes = m[1]!.split(';')
      role = SGR_ROLES.find(([code]) => codes.includes(code))?.[1] ?? 'base'
    }
  }
  if (at < line.length) out.push({ text: line.slice(at), role, href })
  return out
}

function useColor() {
  const context = usePlugin()
  return (role: Role) => {
    const t = context.theme
    if (role === 'muted') return t.text.muted
    // A theme's own accent sits at step 200 of the scale built from it.
    if (role === 'accent') return t.hue.accent[200]
    if (role === 'base') return t.text.base
    return t.text.feedback[role].base
  }
}

type Tokens = { input: number; output: number; reasoning: number; cache: { read: number; write: number } }

/** What a session's tokens would cost at API rates; 0 for a model with no Claude price. */
function apiCost(model: string, t: Tokens) {
  const id = ALIASES[model] ?? model.replace(/\[.*\]$/, '')
  const price = PRICES.find(([prefix]) => id.startsWith(prefix))
  if (!price) return 0
  const [, input, output, read] = price
  return (t.input * input + (t.output + t.reasoning) * output + t.cache.write * input * 1.25 + t.cache.read * read) / 1e6
}

/**
 * Output and thinking tokens over the reply's generation, as statusline-mod times first chunk → last.
 * A tool part's time is its execution, so generation ends where the tool starts. Under a second means
 * the text arrived in one burst rather than streamed, and the rate would be meaningless.
 */
function replyRate(m: any) {
  const parts: any[] = (m.content ?? []).filter((p: any) => typeof p.time?.created === 'number')
  if (!parts.length) return undefined
  const start = Math.min(...parts.map(p => p.time.created))
  const end = Math.max(...parts.map(p => (p.type === 'tool' ? p.time.created : (p.time.completed ?? p.time.created))))
  const tokens = (m.tokens?.output ?? 0) + (m.tokens?.reasoning ?? 0)
  return end - start >= 1000 && tokens > 0 ? Math.round((tokens * 1000) / (end - start)) : undefined
}

function meterRole(pct: number): Role {
  return pct >= 80 ? 'error' : pct >= 50 ? 'warning' : 'accent'
}

function age(secs: number) {
  return secs < 3600 ? `${Math.floor(secs / 60)}m` : secs < 86400 ? `${Math.floor(secs / 3600)}h` : `${Math.floor(secs / 86400)}d`
}

function until(resets: string, now: number) {
  const s = Number(resets) - now
  if (!(s > 0)) return ''
  const d = Math.floor(s / 86400)
  const h = Math.floor((s % 86400) / 3600)
  const m = Math.floor((s % 3600) / 60)
  return d ? `${d}d ${h}h` : h ? `${h}h ${m}m` : `${m}m`
}

/** Label left, value right-aligned: every line of every section. */
function Row(props: { label: JSX.Element; value?: JSX.Element; labelFg?: unknown; valueFg?: unknown }) {
  const context = usePlugin()
  return (
    <box flexDirection="row" justifyContent="space-between" gap={1}>
      <text fg={props.labelFg ?? context.theme.text.muted} wrapMode="none" truncate flexShrink={1} minWidth={0}>
        {props.label}
      </text>
      <Show when={props.value !== undefined}>
        <text fg={props.valueFg ?? context.theme.text.base} wrapMode="none" flexShrink={0}>
          {props.value}
        </text>
      </Show>
    </box>
  )
}

function Title(props: { title: JSX.Element; aside?: JSX.Element; asideFg?: unknown }) {
  const context = usePlugin()
  return <Row label={<b>{props.title}</b>} labelFg={context.theme.text.base} value={props.aside} valueFg={props.asideFg ?? context.theme.text.muted} />
}

/** A full-width bar; with `segments`, that many cells split by a gap, filled left to right. */
function Meter(props: { fraction: number; role: Role; segments?: number }) {
  const context = usePlugin()
  const color = useColor()
  const [width, setWidth] = createSignal(0)
  const cells = createMemo(() => {
    const w = width()
    if (!w) return []
    const n = props.segments ?? 1
    const f = Math.max(0, Math.min(1, props.fraction))
    const size = n > 1 ? Math.max(1, Math.floor((w - (n - 1)) / n)) : w
    return Array.from({ length: n }, (_, i) => {
      const filled = Math.round(size * Math.max(0, Math.min(1, f * n - i)))
      return { filled: '━'.repeat(filled), empty: '━'.repeat(size - filled), gap: i < n - 1 ? ' ' : '' }
    })
  })
  // Not every theme defines a faint tier.
  const track = () => context.theme.text.faint ?? context.theme.text.muted
  return (
    <box width="100%" onSizeChange={function (this: { width: number }) { setWidth(this.width) }}>
      <text wrapMode="none">
        <For each={cells()}>
          {c => (
            <>
              <span style={{ fg: color(props.role) }}>{c.filled}</span>
              <span style={{ fg: track() }}>{c.empty}</span>
              {c.gap}
            </>
          )}
        </For>
      </text>
    </box>
  )
}

function Sidebar(props: { sessionID: string }) {
  const context = usePlugin()
  const color = useColor()
  const session = () => context.data.session.get(props.sessionID)
  const root = () => sessionRoot(session())
  const collected = useCollected(root)
  const money = new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' })

  const messages = () => {
    const revert = session()?.revert?.messageID
    return (context.data.session.message.list(props.sessionID) ?? []).filter((m: any) => m.type === 'assistant' && (!revert || m.id < revert))
  }
  const latest = (list: any[]) => list.reduce((a, m) => (!a || m.time.created > a.time.created ? m : a), undefined)

  const ctx = createMemo(() => {
    const s = session()
    const t = latest(messages().filter((m: any) => m.tokens))?.tokens as Tokens | undefined
    if (!s || !t) return undefined
    const tokens = t.input + t.output + t.reasoning + t.cache.read + t.cache.write
    const model = context.data.location.model.list(s.location)?.find((m: any) => m.providerID === s.model?.providerID && m.id === s.model?.id)
    const limit: number = model?.limit?.context ?? 0
    // As statusline-mod: the share of the prompt read from cache, which it flags below 80%.
    const prompt = t.input + t.cache.read + t.cache.write
    const cache = prompt > 0 && t.cache.read > 0 ? Math.floor((t.cache.read * 100) / prompt) : undefined
    return { tokens, limit, cache, percent: limit ? Math.round((tokens * 100) / limit) : undefined }
  })

  const cost = createMemo(() => {
    const spent = context.data.session.cost(props.sessionID) ?? 0
    if (spent > 0) return { label: 'spent', value: money.format(spent) }
    const family = context.data.session.family(props.sessionID) ?? [props.sessionID]
    const est = family.reduce((sum: number, id: string) => {
      const s = context.data.session.get(id)
      return s?.tokens && s.model ? sum + apiCost(s.model.id, s.tokens) : sum
    }, 0)
    return est > 0 ? { label: 'cost at API rates', value: `~${money.format(est)}` } : undefined
  })

  const rate = createMemo(() => {
    const last = latest(messages().filter((m: any) => replyRate(m) !== undefined))
    return last ? replyRate(last) : undefined
  })

  const apps = () => collected()?.()?.apps ?? []
  const up = () => apps().filter(a => a.port).length

  const project = createMemo(() => {
    const c = collected()?.()
    const g = c?.git
    const cwd = root()
    if (!c || !g || !cwd) return undefined
    // As line2 names it: a worktree by its main checkout, anything else by its directory.
    const repo = (g.isWorktree && g.gitCommon ? g.gitCommon.replace(/\/\.git$/, '') : cwd).split('/').pop()!
    const pr = c.pr?.state === 'OPEN' ? c.pr : undefined
    const review = pr && !pr.draft ? (pr.review === 'APPROVED' ? 'approved' : pr.review === 'CHANGES_REQUESTED' ? 'changes' : '') : ''
    return {
      repo,
      web: g.web,
      worktree: g.isWorktree ? g.wtName : '',
      branch: g.branch,
      base: c.baseRef && c.baseRef !== g.branch ? c.baseRef : '',
      diff: c.branchDiff && c.branchDiff.files > 0 ? c.branchDiff : undefined,
      pr: pr && { url: pr.url, number: pr.url.slice(pr.url.lastIndexOf('/') + 1), draft: pr.draft, review },
      ci: c.ci ? segments(c.ci) : [],
    }
  })

  return (
    <box flexDirection="column" gap={1}>
      <Show when={project()}>
        {p => (
          <box>
            <Title
              title={<Show when={p().web} fallback={p().repo}><a href={p().web}>{p().repo}</a></Show>}
              aside={p().worktree ? 'worktree' : undefined}
            />
            <Show when={p().worktree}>
              <Row label={`⎇ ${p().worktree}`} />
            </Show>
            <Show when={p().branch}>
              <Row
                labelFg={color('accent')}
                label={<Show when={p().web} fallback={p().branch}><a href={`${p().web}/tree/${p().branch}`}>{p().branch}</a></Show>}
              />
            </Show>
            <Show when={p().base}>
              <Row
                label={<Show when={p().web} fallback={`← ${p().base}`}><a href={`${p().web}/compare/${p().base}...${p().branch}`}>← {p().base}</a></Show>}
                value={
                  <Show when={p().diff}>
                    {d => (
                      <>
                        <span style={{ fg: color('muted') }}>{d().files}f</span>
                        <Show when={d().added}><span style={{ fg: color('success') }}> +{d().added}</span></Show>
                        <Show when={d().removed}><span style={{ fg: color('error') }}> -{d().removed}</span></Show>
                      </>
                    )}
                  </Show>
                }
              />
            </Show>
            <Show when={p().pr}>
              {pr => (
                <Row
                  labelFg={color(pr().draft ? 'muted' : 'success')}
                  label={
                    <>
                      <a href={pr().url}>PR #{pr().number}</a>
                      {pr().draft ? ' draft' : ' open'}
                    </>
                  }
                  value={
                    <>
                      <Show when={pr().review}>
                        <span style={{ fg: color(pr().review === 'approved' ? 'success' : 'warning') }}>{pr().review}</span>
                        <Show when={p().ci.length}>{' '}</Show>
                      </Show>
                      <For each={p().ci}>
                        {seg => (
                          <a href={`${pr().url}/checks`} style={{ fg: color(seg.role) }}>
                            {seg.text}
                          </a>
                        )}
                      </For>
                    </>
                  }
                />
              )}
            </Show>
          </box>
        )}
      </Show>
      <Show when={ctx() || cost() || rate()}>
        <box>
          <Show
            when={ctx()?.percent !== undefined && ctx()}
            fallback={<Title title="Context" />}
          >
            {c => (
              <>
                <Title title="Context" aside={`${c().percent}%`} asideFg={color(meterRole(c().percent!))} />
                <Meter fraction={c().percent! / 100} role={meterRole(c().percent!)} />
              </>
            )}
          </Show>
          <Show when={ctx()}>
            {c => (
              <>
                <Row label="tokens" value={c().limit ? `${formatTokens(c().tokens)} / ${formatTokens(c().limit)}` : c().tokens.toLocaleString()} />
                <Show when={c().cache !== undefined}>
                  <Row label="cached" value={`${c().cache}%`} valueFg={c().cache! < 80 ? color('warning') : undefined} />
                </Show>
              </>
            )}
          </Show>
          <Show when={rate()}>{r => <Row label="speed" value={`${r()} tok/s`} />}</Show>
          <Show when={cost()}>{c => <Row label={c().label} value={c().value} />}</Show>
        </box>
      </Show>
      <Show when={apps().length}>
        <box>
          <Title title="Dev servers" aside={`${up()}/${apps().length} up`} asideFg={color(up() === apps().length ? 'success' : 'muted')} />
          <For each={apps()}>
            {({ name, port }) => (
              <Row
                labelFg={context.theme.text.base}
                label={
                  <>
                    <span style={{ fg: color(port ? 'success' : 'error') }}>● </span>
                    <Show when={port} fallback={<span style={{ fg: color('muted') }}>{name}</span>}>
                      <a href={nodeAppUrl(name, port!)}>{name}</a>
                    </Show>
                  </>
                }
                value={port ? <a href={nodeAppUrl(name, port)}>:{port}</a> : 'down'}
                valueFg={color(port ? 'muted' : 'error')}
              />
            )}
          </For>
        </box>
      </Show>
    </box>
  )
}

function Plan() {
  const color = useColor()
  const money = new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' })

  const plan = createMemo(() => {
    const u = usage()
    if (!u || (!u.week && !u.costs.length)) return undefined
    const now = Math.floor(Date.now() / 1000)
    const stale = (mtime: number) => (now - mtime >= 900 ? age(now - mtime) : '')
    const w = u.week
    // A window whose reset has passed has started over; the cache can't say how far.
    const reset = !!w && Number(w.resets) > 0 && Number(w.resets) <= now
    return {
      week: w && {
        reset,
        fraction: w.pct / 100,
        role: meterRole(round(w.pct)),
        used: `${((w.pct * PLAN.multiplier) / 100).toFixed(1)}x of ${PLAN.multiplier}x`,
        resets: reset ? '' : until(w.resets, now),
        stale: stale(u.limitsMtime),
      },
      costs: u.costs.map(([key, cost]) => ({ key, cost: money.format(cost) })),
      costStale: stale(u.costMtime),
    }
  })

  return (
    <Show when={plan()}>
      {p => (
        <box gap={1}>
          <Show when={p().week}>
            {w => (
              <box>
                <Title title="Plan" aside={`${PLAN.name}${w().stale ? ` · ${w().stale} ago` : ''}`} />
                <Show when={!w().reset} fallback={<Row label="7d window reset" />}>
                  <Meter fraction={w().fraction} role={w().role} segments={PLAN.multiplier} />
                  <Row label={w().used} labelFg={color(w().role)} value={w().resets ? `resets in ${w().resets}` : undefined} valueFg={color('muted')} />
                </Show>
              </box>
            )}
          </Show>
          <Show when={p().costs.length}>
            <box>
              <Title title="Spend" aside={`API rates${p().costStale ? ` · ${p().costStale} ago` : ''}`} />
              <For each={p().costs}>{c => <Row label={c.key} value={c.cost} />}</For>
            </box>
          </Show>
        </box>
      )}
    </Show>
  )
}

function GitLine(props: { sessionID: string }) {
  const context = usePlugin()
  const color = useColor()
  const dir = () => sessionRoot(context.data.session.get(props.sessionID))
  const collected = useCollected(dir)
  const [cols, setCols] = createSignal(0)

  const line = createMemo(() => {
    const cwd = dir()
    const c = collected()?.()
    if (!cwd || !c) return []
    const none: Limit = { pct: -1, resets: '' }
    const state: State = {
      model: '', effort: '', cost: 0, ctxPct: 0, ctxCurrent: 0, ctxCacheRead: 0, rate5h: none, rate7d: none,
      cwd, git: c.git, baseRef: c.baseRef, branchDiff: c.branchDiff, pr: c.pr, ci: c.ci, nodeApps: [],
    }
    const text = line2(state, { cols: cols(), oneLine: true, osc8: true, hideModelRegex: '', now: Math.floor(Date.now() / 1000) })
    return text ? segments(fitLine(text, cols())) : []
  })

  return (
    <box width="100%" onSizeChange={function (this: { width: number }) { setCols(this.width) }}>
      <Show when={line().length}>
        <text wrapMode="none" truncate>
          <For each={line()}>
            {seg => (
              <Show when={seg.href} fallback={<span style={{ fg: color(seg.role) }}>{seg.text}</span>}>
                <a href={seg.href!} style={{ fg: color(seg.role) }}>{seg.text}</a>
              </Show>
            )}
          </For>
        </text>
      </Show>
    </box>
  )
}

export default Plugin.define({
  id: 'dotfiles.statusline-mod',
  setup(context) {
    void readUsage()
    const timer = setInterval(() => void readUsage(), LIMITS_POLL_MS)
    // Prepended so it takes the place of the built-in opencode.sidebar.context, which cli.json turns off.
    const sidebar = context.ui.slot({ prepend: 'sidebar.content', render: ({ sessionID }) => <Sidebar sessionID={sessionID} /> })
    const footer = context.ui.slot({ append: 'sidebar.footer', render: () => <Plan /> })
    const composer = context.ui.slot({ append: 'session.composer.top', render: ({ sessionID }) => <GitLine sessionID={sessionID} /> })
    return () => {
      clearInterval(timer)
      sidebar()
      footer()
      composer()
    }
  },
})
