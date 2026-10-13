import type { Limit, State } from './types'

type Window = { used_percentage?: number; resets_at?: unknown } | undefined

const limit = (w: Window): Limit => ({
  pct: typeof w?.used_percentage === 'number' ? w.used_percentage : -1,
  resets: w?.resets_at === undefined || w?.resets_at === null ? '' : String(w.resets_at),
})

/** The statusLine payload's fields, read as statusline.sh's jq does; `effortEnv` is CLAUDE_EFFORT. */
export function fromPayload(input: any, effortEnv: string) {
  const usage = input?.context_window?.current_usage
  return {
    model: input?.model?.display_name ?? 'Unknown',
    effort:
      input?.effort?.level ?? input?.effortLevel ?? input?.reasoning_effort ?? input?.model?.reasoning_effort ??
      input?.output_style?.effortLevel ?? effortEnv,
    cost: Number(input?.cost?.total_cost_usd ?? 0),
    ctxPct: Number(input?.context_window?.used_percentage ?? 0),
    ctxCurrent: usage ? (usage.input_tokens ?? 0) + (usage.cache_creation_input_tokens ?? 0) + (usage.cache_read_input_tokens ?? 0) : 0,
    ctxCacheRead: usage ? usage.cache_read_input_tokens ?? 0 : 0,
    rate5h: limit(input?.rate_limits?.five_hour),
    rate7d: limit(input?.rate_limits?.seven_day),
    cwd: input?.cwd ?? input?.workspace?.current_dir ?? '',
  } satisfies Partial<State>
}
