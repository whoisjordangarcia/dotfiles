export type Run = (argv: string[], cwd?: string) => Promise<{ exitCode: number; stdout: string }>

export type Io = {
  run: Run
  exists: (path: string) => Promise<boolean>
}

/** A plan window as the statusline payload has it: `pct` -1 when absent; `resets` epoch seconds as text. */
export type Limit = { pct: number; resets: string }

export type Git = {
  branch: string
  gitCommon: string
  isWorktree: boolean
  wtName: string
  ahead: number
  behind: number
  added: number
  removed: number
  /** Epoch seconds of HEAD's commit; 0 when unknown. */
  commitEpoch: number
  sha: string
  /** origin as a browsable https URL, for links; empty when it isn't one. */
  web: string
}

export type Diff = { files: number; added: number; removed: number }

export type Pr = { url: string; state: string; draft: boolean; review: string }

/** `spin` through a turn, `est` while its text streams, `rate` once a reply has finished; `blocked` while a tool waits on the person. */
export type Speed = { spin?: string; est?: number; rate?: number; blocked?: boolean }

export type State = {
  /** The payload's model.display_name, e.g. "Opus 4.8 (1M context)". */
  model: string
  effort: string
  cost: number
  ctxPct: number
  ctxCurrent: number
  ctxCacheRead: number
  rate5h: Limit
  rate7d: Limit
  cwd: string
  git?: Git
  baseRef: string
  /** Against `baseRef`'s merge-base, uncommitted work included. */
  branchDiff?: Diff
  pr?: Pr
  /** CI glyph as rendered (ANSI included); empty for none. */
  ci: string
  /** "name:port" entries. */
  nodeApps: string[]
  speed?: Speed
}

/** What the mod collects for the statusLine command; `cwd` is the directory it was collected in. */
export type Shared = Pick<State, 'cwd' | 'git' | 'baseRef' | 'branchDiff' | 'pr' | 'ci' | 'nodeApps' | 'speed'> & { osc8?: boolean }

export type Opts = {
  /** 0 = unknown: nothing is shed or clamped. */
  cols: number
  oneLine: boolean
  osc8: boolean
  hideModelRegex: string
  /** Epoch seconds. */
  now: number
}
