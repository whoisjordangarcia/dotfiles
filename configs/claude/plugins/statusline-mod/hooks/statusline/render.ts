import type { Git, Limit, Opts, Pr, Speed, State } from './types'

// The terminal's own 16-colour slots, so the line follows its theme in light and dark.
const ACCENT = '\x1b[0;35m'
const WHITE = '\x1b[0;39m'
const WARN = '\x1b[0;33m'
const DIM = '\x1b[0;2;39m'
const ADD = '\x1b[0;32m'
const DEL = '\x1b[0;31m'
const RESET = '\x1b[0m'

const SEP = `${DIM} ⋮ ${RESET}`

/** printf "%.0f": ties go to the even neighbour. */
export function round(x: number) {
  const f = Math.floor(x)
  const d = x - f
  return d > 0.5 ? f + 1 : d < 0.5 ? f : f % 2 === 0 ? f : f + 1
}

export function formatTokens(t: number) {
  if (t >= 1e6) return `${(t / 1e6).toFixed(1)}M`
  if (t >= 1000) return `${Math.floor(t / 1000)}k`
  return `${t}`
}

export function truncate(s: string, max: number) {
  const chars = Array.from(s)
  return chars.length > max ? `${chars.slice(0, max).join('')}…` : s
}

export function formatReset(resets: string, now: number) {
  if (!/^[0-9]+$/.test(resets)) return ''
  const remaining = Number(resets) - now
  if (remaining <= 0) return 'now'
  if (remaining < 60) return '<1m'
  if (remaining < 3600) return `${Math.floor(remaining / 60)}m`
  const h = Math.floor(remaining / 3600)
  const m = Math.floor((remaining % 3600) / 60)
  return m > 0 ? `${h}h${m}m` : `${h}h`
}

function oscLink(url: string, text: string, opts: Opts) {
  return opts.osc8 ? `\x1b]8;;${url}\x07${text}\x1b]8;;\x07` : text
}

// ━ is box-drawing, which the terminal draws itself: crisp at any font size, unlike ▰▱.
function meter(pct: number, fill: string) {
  const filled = Math.min(10, Math.floor((pct * 10 + 50) / 100))
  return `${fill}${'━'.repeat(filled)}${DIM}${'━'.repeat(10 - filled)}${RESET}`
}

export function ciGlyph(kind: '' | 'fail' | 'pending' | 'pass') {
  return kind === 'fail' ? `${DEL}✗${RESET}` : kind === 'pending' ? `${WARN}⏳${RESET}` : kind === 'pass' ? `${ADD}✓${RESET}` : ''
}

function prStateColor(state: string, draft: boolean) {
  if (state === 'MERGED') return ACCENT
  if (state === 'OPEN' && draft) return DIM
  if (state === 'CLOSED') return DIM
  return ADD
}

function formatCommitAge(secs: number) {
  let label: string
  if (secs < 60) label = 'just now'
  else if (secs < 3600) label = `${Math.floor(secs / 60)}m ago`
  else if (secs < 86400) {
    const h = Math.floor(secs / 3600)
    const m = Math.floor((secs % 3600) / 60)
    label = m > 0 ? `${h}h ${m}m ago` : `${h}h ago`
  } else label = `${Math.floor(secs / 86400)}d ago`
  return `${DIM}${label}${RESET}`
}

export function shortModel(full: string) {
  let short = full
  const m = full.match(/Claude ([0-9.]+ )?(.+)/)
  if (m) {
    const version = m[1] ?? ''
    short = `${m[2]}${version ? ` ${version.replace(/ $/, '')}` : ''}`
  }
  short = short.replace(/ \(1M context\)$/, '')
  const c = short.match(/^([A-Za-z])[A-Za-z]* ([0-9.]+)$/)
  return c ? `${c[1]!.toLowerCase()}${c[2]}` : short
}

function effortDisplay(level: string) {
  if (!level) return ''
  const e = level === 'xhigh' ? '(xh)' : level === 'max' ? '(max)' : `(${level[0]})`
  return `${ACCENT}${e}${RESET}`
}

// Its own row, so nothing after it shifts as it changes.
function speedDisplay(s: Speed | undefined) {
  if (!s) return ''
  if (s.blocked) return `${DEL}⏸ needs you${RESET}`
  const n = s.est !== undefined ? `~${s.est}` : s.rate
  if (s.spin) return `${WARN}⚡ ${s.spin}${n !== undefined ? ` ${n} tok/s` : ''}${RESET}`
  return s.rate !== undefined ? `${WARN}⚡ ${s.rate} tok/s${RESET}` : `${DIM}⚡ – tok/s${RESET}`
}

function prBadge(pr: Pr, ci: string, opts: Opts) {
  const number = pr.url.slice(pr.url.lastIndexOf('/') + 1)
  const suffix =
    pr.state === 'MERGED' ? ' merged' : pr.state === 'CLOSED' ? ' closed' : pr.state === 'OPEN' && pr.draft ? ' draft' : ''
  let review = ''
  if (pr.state === 'OPEN' && !pr.draft) {
    if (pr.review === 'APPROVED') review = `${ADD}approved${RESET}`
    else if (pr.review === 'CHANGES_REQUESTED') review = `${WARN}changes${RESET}`
  }
  let badge = `${prStateColor(pr.state, pr.draft)}${oscLink(pr.url, `#${number}`, opts)}${suffix}${RESET}`
  if (review) badge += ` ${review}`
  if (pr.state === 'OPEN' && ci) badge += ` ${oscLink(`${pr.url}/checks`, ci, opts)}`
  return badge
}

function line2(s: State, opts: Opts) {
  const g = s.git
  const branch = g?.branch ?? ''
  let isWorktree = g?.isWorktree ?? false
  let wtName = g?.wtName ?? ''
  // Path-based detection runs even when git detection fails.
  if (!isWorktree && s.cwd) {
    const m = s.cwd.match(/^(.*)(\/\.claude\/worktrees\/|\/\.worktrees\/|\/\.worktree\/)([^/]+)/)
    if (m) {
      isWorktree = true
      wtName = m[3]!
    }
  }

  const pr = branch && s.pr?.url ? s.pr : undefined
  const badge = pr ? prBadge(pr, s.ci, opts) : ''

  let wtPr = ''
  if (branch) {
    if (isWorktree && wtName) {
      if (badge) wtPr = `${prStateColor(pr!.state, pr!.draft)}⎇${RESET} ${badge}`
      else {
        // A worktree named after its branch needs no ⎇ label.
        const norm = (x: string) => x.replace(/[/-]/g, '').toLowerCase()
        if (norm(branch) !== norm(wtName)) wtPr = `${DIM}⎇ ${truncate(wtName, 45)}${RESET}`
      }
    } else if (badge) wtPr = badge
  }

  const sync = g
    ? [g.ahead > 0 ? `${WHITE}↑${g.ahead}${RESET}` : '', g.behind > 0 ? `${WHITE}↓${g.behind}${RESET}` : ''].filter(Boolean).join(' ')
    : ''
  const lines = g
    ? [g.added > 0 ? `${ADD}+${g.added}${RESET}` : '', g.removed > 0 ? `${DEL}-${g.removed}${RESET}` : ''].filter(Boolean).join(' ')
    : ''
  const web = g?.web ?? ''
  const link = (path: string, text: string) => (web ? oscLink(`${web}${path}`, text, opts) : text)
  const d = s.branchDiff
  // Dimmed whole: the bright +/- further along is uncommitted work, which this already counts.
  const diff =
    d && d.files > 0 ? ` ${DIM}${[`${d.files}f`, d.added > 0 ? `+${d.added}` : '', d.removed > 0 ? `-${d.removed}` : ''].filter(Boolean).join(' ')}${RESET}` : ''
  const base =
    branch && s.baseRef && s.baseRef !== branch ? link(`/compare/${s.baseRef}...${branch}`, `${DIM}← ${DIM}${s.baseRef}${RESET}${diff}`) : ''
  const age =
    g && g.commitEpoch > 0 && opts.now - g.commitEpoch < 18000 ? link(`/commit/${g.sha}`, formatCommitAge(opts.now - g.commitEpoch)) : ''
  const branchText = link(`/tree/${branch}`, `${ACCENT}${truncate(branch, 45)}${RESET}`)

  let out = ''
  if (branch) {
    if (isWorktree) {
      if (wtPr) out += wtPr
      if (out) out += ' '
      out += branchText
      if (base) out += ` ${base}`
      if (sync) out += (out ? SEP : '') + sync
    } else {
      out += branchText
      if (wtPr) out += ` ${wtPr}`
      if (base) out += ` ${base}`
      if (sync) out += SEP + sync
    }
    const repo = isWorktree && g?.gitCommon ? g.gitCommon.replace(/\/\.git$/, '').split('/').pop()! : s.cwd.split('/').pop()!
    if (repo) out = `${link('', `${WHITE}${truncate(repo, 30)}${RESET}`)}${SEP}${out}`
  }
  if (!out && isWorktree && wtName) out = `${DIM}⎇ ${truncate(wtName, 45)}${RESET}`
  if (lines) out += (out ? SEP : '') + lines
  if (age) out += (out ? SEP : '') + age
  return out
}

/** The apps a checkout is expected to run, by the directory that holds each. */
export const KNOWN_APPS: Record<string, string> = {
  'client-api': 'apps/backend/client-api',
  'patient-navigator': 'apps/frontend/patient-navigator',
  'provider-portal': 'apps/frontend/provider-portal',
  yoda: 'apps/frontend/yoda',
}

export function nodeAppUrl(name: string, port: string) {
  switch (name) {
    case 'client-api': return `https://dev.api.nestgenomics.com:${port}/graphql`
    case 'yoda': return `https://dev.yoda.nestgenomics.com:${port}`
    case 'patient-navigator': return `https://dev.app.nestgenomics.com:${port}`
    case 'provider-portal': return `https://dev.portal.nestgenomics.com:${port}`
    default: return `http://localhost:${port}`
  }
}

function line3(s: State, opts: Opts) {
  const limits = ([['S', s.rate5h], ['W', s.rate7d]] as [string, Limit][]).flatMap(([label, l]) => {
    if (l.pct === -1) return []
    const p = round(l.pct)
    if (p < 80) return []
    const reset = l.resets && l.resets !== 'null' ? ` ${DIM}↻${formatReset(l.resets, opts.now)}${RESET}` : ''
    return [oscLink('https://claude.ai/settings/usage', `${DIM}${label}${RESET} ${meter(p, DEL)} ${DEL}${p}%${RESET}${reset}`, opts)]
  })
  const apps = s.nodeApps.length
    ? `${ADD}${s.nodeApps
        .map(entry => {
          const i = entry.lastIndexOf(':')
          const port = entry.slice(i + 1)
          return /^[0-9]+$/.test(port) ? oscLink(nodeAppUrl(entry.slice(0, i), port), entry, opts) : entry
        })
        .join(' ')}${RESET}`
    : ''
  return [limits.join(SEP), apps].filter(Boolean).join(SEP)
}

// Display columns of one code point; a zero-width one (U+FE0F) is 0 here.
function wcwidth(cp: number) {
  if (cp === 0x200d || (cp >= 0xfe00 && cp <= 0xfe0f) || (cp >= 0x300 && cp <= 0x36f)) return 0
  const wide: [number, number][] = [
    [0x1100, 0x115f], [0x231a, 0x231b], [0x23e9, 0x23ec], [0x23f0, 0x23f0], [0x23f3, 0x23f3], [0x25fd, 0x25fe],
    [0x2614, 0x2615], [0x2648, 0x2653], [0x267f, 0x267f], [0x2693, 0x2693], [0x26a1, 0x26a1], [0x26aa, 0x26ab],
    [0x26bd, 0x26be], [0x26c4, 0x26c5], [0x26ce, 0x26ce], [0x26d4, 0x26d4], [0x26ea, 0x26ea], [0x26f2, 0x26f5],
    [0x26fa, 0x26fa], [0x26fd, 0x26fd], [0x2705, 0x2705], [0x270a, 0x270b], [0x2728, 0x2728], [0x274c, 0x274c],
    [0x274e, 0x274e], [0x2753, 0x2755], [0x2757, 0x2757], [0x2795, 0x2797], [0x27b0, 0x27b0], [0x27bf, 0x27bf],
    [0x2b1b, 0x2b1c], [0x2b50, 0x2b50], [0x2b55, 0x2b55], [0x2e80, 0xa4cf], [0xac00, 0xd7a3], [0xf900, 0xfaff],
    [0xfe30, 0xfe4f], [0xff00, 0xff60], [0xffe0, 0xffe6], [0x1f300, 0x1faff], [0x20000, 0x3fffd],
  ]
  return wide.some(([a, b]) => cp >= a && cp <= b) ? 2 : 1
}

const ESCAPES = /\x1b\[[0-9;]*m|\x1b\]8;;[^\x07]*\x07/g

/** Display columns of a line, ANSI and OSC 8 excluded; U+FE0F widens its base to emoji width. */
export function visibleWidth(s: string) {
  let w = 0
  for (const ch of s.replace(ESCAPES, '')) {
    const cp = ch.codePointAt(0)!
    w += cp === 0xfe0f ? 1 : wcwidth(cp)
  }
  return w
}

/** Clamps a line to `max` columns: escapes copied, an open link closed, … in the last column. */
export function fitLine(s: string, max: number) {
  if (max <= 0 || visibleWidth(s) <= max) return s
  const lim = max - 1
  const chars = Array.from(s)
  let out = ''
  let dw = 0
  let oscOpen = false
  for (let i = 0; i < chars.length; ) {
    if (chars[i] === '\x1b') {
      let j = i + 1
      if (chars[j] === ']') {
        while (j < chars.length && chars[j] !== '\x07') j++
        const seq = chars.slice(i, j + 1).join('')
        out += seq
        oscOpen = seq !== '\x1b]8;;\x07'
      } else {
        while (j < chars.length && !/[A-Za-z]/.test(chars[j]!)) j++
        out += chars.slice(i, j + 1).join('')
      }
      i = j + 1
      continue
    }
    const cw = Math.max(1, wcwidth(chars[i]!.codePointAt(0)!))
    if (dw + cw > lim) break
    out += chars[i]
    dw += cw
    i++
  }
  if (oscOpen) out += '\x1b]8;;\x07'
  return `${out}${RESET}…`
}

/** The statusline's text, every line newline-terminated, as statusline.sh prints it. */
export function render(s: State, opts: Opts) {
  let hidden = false
  try {
    hidden = new RegExp(opts.hideModelRegex).test(s.model)
  } catch {
    // An invalid pattern hides nothing, as a failed [[ =~ ]] does.
  }
  const effort = effortDisplay(s.effort)
  const modelSegment = [hidden ? '' : `${DIM}${shortModel(s.model)}${RESET}`, effort].filter(Boolean).join(' ')

  const pct = round(s.ctxPct)
  const [barColor, pctColor, warn] = pct >= 80 ? [DEL, DEL, ' ⚠️'] : pct >= 50 ? [WARN, WARN, ''] : [ACCENT, WHITE, '']
  // Padded to fixed widths so the line holds still while they change; everything after them would shift.
  const tokens = s.ctxCurrent > 0 ? ` ${DIM}(${formatTokens(s.ctxCurrent).padStart(4)})${RESET}` : ''
  const contextBar = `${meter(pct, barColor)} ${pctColor}${String(pct).padStart(3)}%${RESET}`
  let cache = ''
  if (s.ctxCurrent > 0 && s.ctxCacheRead > 0) {
    const cachePct = Math.floor((s.ctxCacheRead * 100) / s.ctxCurrent)
    if (cachePct < 80) cache = ` ${DIM}⚡${cachePct}%${RESET}`
  }
  const speed = speedDisplay(s.speed)

  // Optional segments shed on a narrow pane: cache %, then token count.
  const line1 = (incTok: boolean, incCache: boolean) => {
    let l = `${WHITE}${`$${s.cost.toFixed(2)}`.padStart(6)}${RESET}`
    if (modelSegment) l = `${modelSegment}${SEP}${l}`
    l += `${SEP}${contextBar}`
    if (incTok) l += tokens
    l += warn
    if (incCache) l += cache
    return l
  }

  const l2 = line2(s, opts)
  const l3 = line3(s, opts)

  if (opts.oneLine) {
    let one = line1(true, true)
    if (l2) one += SEP + l2
    if (l3) one += SEP + l3
    // Too wide falls back to multi-line: a clipped one-liner is worse than two short lines.
    if (!(opts.cols > 0 && visibleWidth(one) > opts.cols)) return [one, speed].filter(Boolean).map(l => `${l}\n`).join('')
  }

  let l1 = line1(true, true)
  let f2 = l2
  let f3 = l3
  if (opts.cols > 0) {
    for (const [tok, cache_] of [[true, true], [true, false], [false, false]] as const) {
      l1 = line1(tok, cache_)
      if (visibleWidth(l1) <= opts.cols) break
    }
    l1 = fitLine(l1, opts.cols)
    if (f2) f2 = fitLine(f2, opts.cols)
    if (f3) f3 = fitLine(f3, opts.cols)
  }
  return [l1, speed, f2, f3].filter(Boolean).map(l => `${l}\n`).join('')
}
