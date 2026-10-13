import type { Register } from 'claude-code'

// Rate is measured first chunk → last chunk, so time-to-first-token (queueing,
// prompt processing) doesn't drag it down. Subagent steps are left out.
export const register: Register = on => {
  let tokens = 0
  let ms = 0 // ponytail: session totals live in module vars, reset on hot reload; move to $.state if that matters

  on('turn.step', async function* ($, e, next) {
    if (e.agentId) return yield* next(e)

    let first: number | undefined
    const stream = next(e)
    let step = await stream.next()
    while (!step.done) {
      first ??= await $.clock.now()
      yield step.value
      step = await stream.next()
    }
    const result = step.value
    const out = result.usage?.output_tokens ?? 0
    const elapsed = first === undefined ? 0 : (await $.clock.now()) - first

    if (out > 0 && elapsed > 0) {
      tokens += out
      ms += elapsed
      const rate = (n: number, t: number) => Math.round((n * 1000) / t)
      $.ui.status(`⚡ ${rate(out, elapsed)} tok/s · avg ${rate(tokens, ms)}`)
    }
    return result
  })
}
