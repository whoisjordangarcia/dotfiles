import { test, expect, mock } from 'claude-code/testing'

test('reports output tokens per second, excluding time to first token', async ($, on) => {
  const clock = mock.clock(on)
  const statuses: (string | undefined)[] = []
  on('ui.status', (_$, e) => { statuses.push(e.text); return { value: undefined } as never })

  on('turn.step', async function* (_$, e) {
    await clock.advance(5000) // time to first token: not counted
    yield { kind: 'text', index: 0, text: 'hi' }
    await clock.advance(2000)
    yield { kind: 'text', index: 0, text: ' there' }
    return {
      turnId: e.turnId, index: e.index, answer: 'hi there', toolUses: [], stopReason: 'end_turn',
      usage: { model: 'm', input_tokens: 1, output_tokens: 100, cache_read_input_tokens: 0, cache_creation_input_tokens: 0 },
    }
  })

  for await (const _ of $.turn.step({ turnId: 't', index: 0, model: 'm', messageCount: 1 })) { /* drain */ }
  expect(statuses).toEqual(['⚡ 50 tok/s · avg 50'])
})
