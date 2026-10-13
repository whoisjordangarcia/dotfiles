import { test, expect, mock } from 'claude-code/testing'

test('writes the collected state at session start', async ($, on) => {
  mock.clock(on)
  const files = new Map<string, string>()
  const state = () => JSON.parse(files.get('/tmp/statusline-mod/sid.state') ?? 'null')

  on('session.start', () => ({ cwd: '/work/notes' }) as never)
  on('session.id', () => ({ value: 'sid' }) as never)
  on('session.cwd', () => ({ value: '/work/notes' }) as never)
  on('env.get', () => ({ value: undefined }) as never)
  on('fs.write', (_$, e) => {
    const { path, text } = e as { path: string; text: string }
    files.set(path, text)
    return { value: undefined } as never
  })
  // Not a git repo and no package.json: nothing to collect beyond the directory.
  on('fs.exists', () => ({ value: false }) as never)
  on('process.run', () => ({ value: { exitCode: 1, stdout: '', stderr: '', isStdoutTruncated: false, isStderrTruncated: false } }) as never)

  await $.session.start({ cwd: '/work/notes' } as never)
  expect(state()).toEqual({ cwd: '/work/notes', baseRef: '', ci: '', nodeApps: [], speed: {}, osc8: false })
})

test('draws a set-up checkout\'s apps above the prompt: running as links, unmapped ones to localhost, the rest down, a nested worktree\'s not at all', async ($, on) => {
  mock.clock(on)
  const cwd = '/work/nest'
  on('session.start', () => ({ cwd }) as never)
  on('session.id', () => ({ value: 'sid' }) as never)
  on('session.cwd', () => ({ value: cwd }) as never)
  on('env.get', () => ({ value: undefined }) as never)
  on('fs.write', () => ({ value: undefined }) as never)
  const present = ['package.json', 'node_modules', 'apps/frontend/yoda', 'apps/backend/client-api', 'docker-compose.shared.yml']
  on('fs.exists', (_$, e) => ({ value: present.some(p => (e as { path: string }).path === `${cwd}/${p}`) }) as never)
  on('process.run', (_$, e) => {
    const [cmd, ...args] = (e as { argv: string[] }).argv
    const stdout =
      cmd === 'lsof' && args[0] === '-tiTCP:8025' ? '57617\n'
      : cmd === 'lsof' && args[0] === '-iTCP'
        ? 'COMMAND PID USER FD TYPE DEVICE SIZE/OFF NODE NAME\nnode 4242 nest 20u IPv6 0x1 0t0 TCP *:3113 (LISTEN)\nnode 5151 nest 20u IPv6 0x2 0t0 TCP *:47123 (LISTEN)\nnode 6161 nest 20u IPv6 0x3 0t0 TCP *:6006 (LISTEN)\n'
      : cmd === 'ps' && args[1] === '4242' ? `node ${cwd}/apps/frontend/yoda/dev.server.js\n`
      : cmd === 'ps' && args[1] === '6161' ? `node ${cwd}/node_modules/.bin/storybook dev\n`
      : cmd === 'ps' ? 'node /tmp/static-server.ts\n'
      : cmd === 'lsof' && args[1] === '4242' ? `p4242\nfcwd\nn${cwd}/apps/frontend/yoda\n`
      // A server started from a worktree nested in this checkout belongs to that worktree.
      : cmd === 'lsof' && args[1] === '6161' ? `p6161\nfcwd\nn${cwd}\n`
      : cmd === 'lsof' ? `p5151\nfcwd\nn${cwd}/.worktrees/other-branch\n`
      : ''
    return { value: { exitCode: stdout ? 0 : 1, stdout, stderr: '', isStdoutTruncated: false, isStderrTruncated: false } } as never
  })
  on('ui.render', { component: 'AbovePrompt' }, () => ({ type: 'Text', children: [] }) as never)

  await $.session.start({ cwd } as never)
  const tree = await $.ui.render({
    surface: 'terminal', component: 'AbovePrompt', requestId: 'r',
    props: { hasSurvey: false, isWorking: false, maxRows: 10, bodyColumns: 120 },
  } as never)

  const json = JSON.stringify(tree)
  expect(json).toContain('yoda')
  expect(json).toContain('"href":"https://dev.yoda.nestgenomics.com:3113"')
  expect(json).not.toContain('47123')
  expect(json).toContain('client-api')
  expect(json).toContain('down')
  expect(json).toContain('"href":"http://localhost:8025"')
  expect(json).toContain('"href":"http://localhost:6006"')
})
