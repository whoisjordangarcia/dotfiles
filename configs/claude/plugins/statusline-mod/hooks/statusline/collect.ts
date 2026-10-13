import type { Git, Io, Pr } from './types'

const out = async (io: Io, argv: string[], cwd: string) => (await io.run(argv, cwd)).stdout.trim()

/** git@host:owner/repo.git, ssh://git@host/owner/repo or https://host/owner/repo.git → https://host/owner/repo. */
export function webUrl(remote: string) {
  const m = remote.match(/^(?:git@([^:]+):|ssh:\/\/(?:[^@]+@)?([^/:]+)(?::[0-9]+)?\/|https?:\/\/(?:[^@]+@)?([^/]+)\/)(.+?)(?:\.git)?\/?$/)
  return m ? `https://${m[1] ?? m[2] ?? m[3]}/${m[4]}` : ''
}

export type TermVars = Partial<Record<'TMUX' | 'TERM_PROGRAM' | 'TERM' | 'VTE_VERSION' | 'WT_SESSION' | 'KONSOLE_VERSION', string>>

/** Whether the terminal draws OSC 8 links; elsewhere the escapes print as text. Inside tmux it is the
 * client's terminal that matters, named by `tmux display -p '#{client_termname}'`. */
export function osc8Supported(v: TermVars, tmuxClientTerm: string) {
  const terms = /ghostty|kitty|wezterm|iterm|alacritty|foot|rio|contour/i
  if (v.TMUX) return terms.test(tmuxClientTerm)
  return (
    ['ghostty', 'iTerm.app', 'WezTerm', 'rio', 'vscode', 'Hyper'].includes(v.TERM_PROGRAM ?? '') ||
    terms.test(v.TERM ?? '') ||
    Number(v.VTE_VERSION ?? 0) >= 5000 ||
    !!v.WT_SESSION ||
    !!v.KONSOLE_VERSION
  )
}

/** Git state of `cwd`, or undefined when `cwd` is not a repo root (as statusline.sh checks). */
export async function collectGit(io: Io, cwd: string): Promise<Git | undefined> {
  if (!cwd || !(await io.exists(`${cwd}/.git`))) return undefined

  const branch = await out(io, ['git', '-c', 'core.useBuiltinFSMonitor=false', 'branch', '--show-current'], cwd)
  // Both absolute: a bare --git-dir is ".git" at a repo root and would misflag every repo as a worktree.
  const gitDir = await out(io, ['git', 'rev-parse', '--path-format=absolute', '--git-dir'], cwd)
  const gitCommon = await out(io, ['git', 'rev-parse', '--path-format=absolute', '--git-common-dir'], cwd)

  let isWorktree = false
  let wtName = ''
  if (gitDir && gitCommon && gitDir !== gitCommon) {
    isWorktree = true
    const m = cwd.match(/(\/\.claude\/worktrees\/|\/\.worktrees\/|\/\.worktree\/)([^/]+)(\/|$)/)
    wtName = m ? m[2]! : gitDir.split('/').pop()!
  }

  let ahead = 0
  let behind = 0
  const upstream = await out(io, ['git', 'rev-list', '--left-right', '--count', 'HEAD...@{upstream}'], cwd)
  if (upstream) [ahead, behind] = upstream.split(/\s+/).map(n => Number(n) || 0) as [number, number]

  // " N files changed, A insertions(+), D deletions(-)": either count may be absent.
  const shortstat = await out(io, ['git', 'diff', '--shortstat', 'HEAD'], cwd)
  const added = Number(shortstat.match(/([0-9]+) insertion/)?.[1] ?? 0)
  const removed = Number(shortstat.match(/([0-9]+) deletion/)?.[1] ?? 0)

  const [epoch = '', sha = ''] = (await out(io, ['git', 'log', '-1', '--format=%ct %H'], cwd)).split(' ')
  const commitEpoch = Number(epoch) || 0
  const web = webUrl(await out(io, ['git', 'remote', 'get-url', 'origin'], cwd))

  return { branch, gitCommon, isWorktree, wtName, ahead, behind, added, removed, commitEpoch, sha, web }
}

/**
 * The base `branch` was most plausibly cut from: the candidate whose merge-base is fewest commits
 * behind HEAD. Semver release branches are tried first so they win exact-distance ties.
 */
export async function collectBaseRef(io: Io, cwd: string, branch: string) {
  if (!branch) return ''
  const releases = (await out(io, ['git', 'branch', '-r', '--list', 'origin/release/*', '--sort=-version:refname'], cwd))
    .split('\n')
    .map(r => r.trim())
    .filter(r => /\/release\/[0-9]+\.[0-9]+\.[0-9]+$/.test(r))
    .slice(0, 5)
  let baseRef = ''
  let best = -1
  for (const ref of [...releases, 'origin/stg', 'origin/main', 'origin/master']) {
    const mb = await out(io, ['git', 'merge-base', ref, 'HEAD'], cwd)
    if (!mb) continue
    const dist = await out(io, ['git', 'rev-list', '--count', `${mb}..HEAD`], cwd)
    if (!dist) continue
    if (best < 0 || Number(dist) < best) {
      best = Number(dist)
      baseRef = ref.replace(/^origin\//, '')
    }
  }
  return baseRef
}

export async function collectPr(io: Io, cwd: string, branch: string): Promise<Pr> {
  const json = await out(io, ['gh', 'pr', 'view', branch, '--json', 'url,state,isDraft,reviewDecision'], cwd)
  try {
    const p = JSON.parse(json)
    return { url: p.url ?? '', state: p.state ?? '', draft: p.isDraft === true, review: p.reviewDecision ?? '' }
  } catch {
    return { url: '', state: '', draft: false, review: '' }
  }
}

export async function collectCi(io: Io, cwd: string, branch: string): Promise<'' | 'fail' | 'pending' | 'pass'> {
  // gh exits non-zero while checks are pending; its JSON is still on stdout.
  const json = await out(io, ['gh', 'pr', 'checks', branch, '--json', 'name,state,conclusion'], cwd)
  let checks: { state?: string; conclusion?: string }[]
  try {
    checks = JSON.parse(json)
  } catch {
    return ''
  }
  if (!Array.isArray(checks) || !checks.length) return ''
  const count = (f: (c: { state?: string; conclusion?: string }) => boolean) => checks.filter(f).length
  if (count(c => ['FAILURE', 'CANCELLED', 'TIMED_OUT'].includes(c.conclusion ?? ''))) return 'fail'
  if (count(c => ['PENDING', 'QUEUED', 'IN_PROGRESS'].includes(c.state ?? ''))) return 'pending'
  if (count(c => ['SUCCESS', 'NEUTRAL', 'SKIPPED'].includes(c.conclusion ?? ''))) return 'pass'
  return ''
}

const NESTED_WORKTREE = /^\/(?:\.claude\/worktrees|\.worktrees|\.worktree)\//

function inProject(text: string, cwd: string) {
  const i = text.indexOf(cwd)
  return i >= 0 && !NESTED_WORKTREE.test(text.slice(i + cwd.length))
}

/** Node servers listening from inside `cwd`, as sorted "name:port" entries, one per name. */
export async function collectNodeApps(io: Io, cwd: string) {
  const lsof = (await io.run(['lsof', '-iTCP', '-sTCP:LISTEN', '-P', '-n'], cwd)).stdout
  const listening = [
    ...new Set(
      lsof
        .split('\n')
        .map(l => l.trim().split(/\s+/))
        .filter(c => c[0] === 'node' && /^[0-9]+$/.test(c[1] ?? ''))
        .map(c => `${c[1]} ${c[8] ?? ''}`),
    ),
  ].sort()

  const entries: string[] = []
  for (const row of listening) {
    const [pid, addr = ''] = row.split(' ') as [string, string?]
    const port = addr.match(/[0-9]+$/)?.[0]
    if (!port) continue
    const args = (await io.run(['ps', '-p', pid, '-o', 'args='], cwd)).stdout.trim()
    const procCwd =
      (await io.run(['lsof', '-p', pid, '-a', '-d', 'cwd', '-Fn'], cwd)).stdout
        .split('\n')
        .find(l => l.startsWith('n/'))
        ?.slice(1) ?? ''
    // Only apps belonging to the current project directory, and not to a worktree nested inside it.
    if (!inProject(args, cwd) && !inProject(procCwd, cwd)) continue
    const combined = `${args} ${procCwd}`
    let name =
      combined.match(/.*apps\/backend\/([^/ ]*)/)?.[1] ??
      combined.match(/.*apps\/frontend\/([^/]*)/)?.[1] ??
      args.match(/.*nx\.js run ([^:]*):/)?.[1] ??
      ''
    // Plain Next.js/Vite projects are named after the directory, so their server still shows.
    if (!name) name = cwd.split('/').pop() ?? ''
    if (name) entries.push(`${name}:${port}`)
  }
  const seen = new Set<string>()
  return entries
    .sort((a, b) => a.split(':')[0]!.localeCompare(b.split(':')[0]!) || a.localeCompare(b))
    .filter(e => {
      const name = e.split(':')[0]!
      if (seen.has(name)) return false
      seen.add(name)
      return true
    })
}
