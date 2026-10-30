import { expect, mock, test } from 'claude-code/testing'
import type { TestBody } from 'claude-code/testing'
import type { On } from 'claude-code'

const PANE = {
  plugin: 'clawd',
  component: 'Pane',
  requestId: 'clawd',
  props: {
    title: 'Clawd',
    isFocused: false,
    bodyColumns: 30,
    placement: 'dock',
    scroll: { offset: 0, bodyRows: 20 },
    view: {},
  },
} as const

type World = {
  model: string
  percent: number
  commands: string[]
  spawned: string[][]
  written: Record<string, string>
}

const world = (over: Partial<World> = {}): World => ({
  model: 'claude-opus',
  percent: 30,
  commands: [],
  spawned: [],
  written: {},
  ...over,
})

// Stands in for the engine beneath the mod.
function engine(on: On, w: World) {
  const clock = mock.clock(on, { now: 1_000 })
  mock.store(on)
  mock.env(on, { OS: 'Windows_NT', USERPROFILE: 'C:\\Users\\me' })
  on('ui.close', () => ({ value: undefined }))
  on('command.register', (_, e) => ({ value: { command: e.name } }))
  on('ui.open', () => ({ value: { isPlaced: true } }))
  on('session.start', (_, e) => ({ cwd: e.cwd }))
  on('session.model', () => ({ value: w.model }))
  on('session.usage', () => ({
    value: { startedAt: 0, context: { window: 200_000, percent: w.percent }, rateLimits: [] },
  }))
  on('fs.write', (_, e) => {
    w.written[e.path] = e.text

    return { value: undefined }
  })
  on('fs.read', (_, e) => {
    const text = w.written[e.path]

    return text === undefined ? { deny: `ENOENT: ${e.path}` } : { value: text }
  })
  on('process.spawn', async function* (_, e) {
    w.spawned.push([...e.argv])
    yield { stream: 'stdout' as const, text: 'started\n' }

    return { value: { code: 0, signal: null } }
  })
  on('command.run', (_, e) => {
    w.commands.push(`${e.command} ${e.args ?? ''}`.trim())
    if (e.command === 'model') {
      w.model = `claude-${e.args}`
    }

    return { text: '' }
  })
  on('tool.call', () => ({ result: {} }))
  on('prompt.submit', (_, e) => ({ text: e.text }))

  return { clock }
}

const STATE = 'C:\\Users\\me\\.claude\\clawd-pet\\state.json'
const ALIVE = 'C:\\Users\\me\\.claude\\clawd-pet\\pet.alive'
const COMMANDS = 'C:\\Users\\me\\.claude\\clawd-pet\\commands.txt'

test('a Clawd already on the desktop (started at login) is reused, not doubled', async ($, on) => {
  // The pet touched pet.alive a moment ago.
  const w = world({ written: { [ALIVE]: '900' } })
  const { clock } = engine(on, w)

  await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })
  await clock.settle()

  expect(w.spawned.length).toBe(0)
  expect(JSON.parse(w.written[STATE] ?? '{}').aliveAt).toBeGreaterThan(0)
})

test('the session\'s end tells the pet Claude is away', async ($, on) => {
  const w = world()
  engine(on, w)
  on('session.end', (_, e) => ({ sessionId: e.sessionId }))

  await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })
  await $.session.end({ reason: 'prompt_input_exit', sessionId: 's1', resume: { id: 's1' } })

  const state = JSON.parse(w.written[STATE] ?? '{}')
  expect(state.aliveAt).toBe(0)
  expect(state.mood).toBe('idle')
})

test('the session start puts Clawd on the desktop', async ($, on) => {
  const w = world()
  const { clock } = engine(on, w)

  await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })
  await clock.settle()

  expect(w.spawned.length).toBe(1)
  expect(w.spawned[0]?.[0]).toBe('powershell.exe')
  expect(w.spawned[0]?.some(arg => arg.endsWith('clawd-pet.ps1'))).toBe(true)
  expect(w.spawned[0]).toContain(STATE)
})

test('the pet hears what Claude is doing', async ($, on) => {
  const w = world()
  engine(on, w)

  await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })
  await $.tool.call({ tool: 'Read', file_path: 'C:\\src\\App.java' })

  const state = JSON.parse(w.written[STATE] ?? '{}')
  expect(state.mood).toBe('working')
  expect(state.speech).toBe('Reading App.java...')
  expect(state.model).toBe('claude-opus')
})

test('the pet\'s right-click menu switches the model', async ($, on) => {
  const w = world()
  const { clock } = engine(on, w)

  await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })
  w.written[COMMANDS] = 'model sonnet\r\n'
  await clock.advance(1_500)

  expect(w.commands).toContain('model sonnet')
  expect(w.written[COMMANDS]).toBe('')
  expect(JSON.parse(w.written[STATE] ?? '{}').model).toBe('claude-sonnet')
})

test('the panel\'s model button runs /model and shows the new model', async ($, on) => {
  const w = world()
  engine(on, w)

  await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })
  const ui = await $.ui.mount({ ...PANE, surface: 'terminal' })
  await ui.press({ key: 'model-sonnet' })

  expect(w.commands).toContain('model sonnet')
  expect(await ui.find({ type: 'Text', text: /Model: claude-sonnet/ })).toBeDefined()
  await ui.unmount()
})

test('a full context offers Compact, on every surface', async ($, on) => {
  engine(on, world({ percent: 91 }))

  await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })
  for (const surface of ['terminal', 'desktop', 'vscode', 'mobile'] as const) {
    const ui = await $.ui.mount({ ...PANE, surface })
    expect(await ui.find({ key: 'compact' })).toBeDefined()
    await ui.unmount()
  }
})

const ACTIVITY_DIR = 'C:\\Users\\me\\.claude\\clawd-pet\\activity\\'
const STATS = 'C:\\Users\\me\\.claude\\clawd-pet\\stats.json'
const SETTINGS = 'C:\\Users\\me\\.claude\\clawd-pet\\settings.json'
const HUB = 'C:\\src\\my-app'
const APP = 'C:\\src\\my-app\\App.java'

const activityFiles = (w: World) => Object.keys(w.written).filter(p => p.startsWith(ACTIVITY_DIR))

// What the engine fills in for a typed /clawd or prompt, left out here.
type Engine = Parameters<TestBody>[0]
const clawd = ($: Engine, args: string) => $.command.run({ command: 'clawd', args } as never)
const submit = ($: Engine, text: string) => $.prompt.submit({ text } as never)
const edit = ($: Engine, file_path: string) => $.tool.call({ tool: 'Edit', file_path, old_string: 'a', new_string: 'b' })

test('two events in a row both reach the pet, oldest first', async ($, on) => {
  const w = world()
  engine(on, w)

  await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })
  await clawd($, 'pet')
  await clawd($, 'pomodoro')

  const kinds = JSON.parse(w.written[STATE] ?? '{}').events.map((e: { kind: string }) => e.kind)
  expect(kinds.slice(-2)).toEqual(['pet', 'pomodoro'])
  const ids = JSON.parse(w.written[STATE] ?? '{}').events.map((e: { id: number }) => e.id)
  expect([...ids].sort((a, b) => a - b)).toEqual(ids)
})

test('each session counts its own work into its own activity file', async ($, on) => {
  const w = world()
  engine(on, w)
  on('session.id', () => ({ value: 'abc-123' }))
  on('session.cwd', () => ({ value: HUB }))

  await $.session.start({ cwd: HUB, surface: 'terminal', isInteractive: true })
  await submit($, 'fix the bug')
  await edit($, APP)

  const files = activityFiles(w)
  expect(files.length).toBe(1)
  expect(files[0]?.endsWith('abc-123.json')).toBe(true)
  const a = JSON.parse(w.written[files[0] ?? ''] ?? '{}')
  expect(a.project).toBe('my-app')
  expect(a.prompts).toBe(1)
  expect(a.toolCalls.Edit).toBe(1)
  expect(a.filesTouched).toContain(APP)
})

test('paused tracking writes no activity', async ($, on) => {
  const w = world({ written: { [SETTINGS]: '{"tracking":false}' } })
  engine(on, w)

  await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })
  await submit($, 'hello')

  expect(activityFiles(w).length).toBe(0)
})

test('a tool waiting for approval makes Clawd wave for attention', async ($, on) => {
  const w = world()
  engine(on, w)
  on('tool.check', () => ({ decision: 'ask' as const }))

  await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })
  await $.tool.check({ tool: 'Bash', input: { command: 'rm -rf build' } })

  const last = JSON.parse(w.written[STATE] ?? '{}').events.at(-1)
  expect(last.kind).toBe('permission')
  expect(last.data.tool).toBe('Bash')
})

test('a commit is celebrated, counted and worth XP', async ($, on) => {
  const w = world()
  engine(on, w)

  await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })
  await $.tool.call({ tool: 'Bash', command: 'git add . && git commit -m "feat: x"' })

  const state = JSON.parse(w.written[STATE] ?? '{}')
  const kinds = state.events.map((e: { kind: string }) => e.kind)
  expect(kinds).toContain('git')
  expect(state.events.at(-1)).toMatchObject({ kind: 'xp', data: { n: 20, why: 'commit' } })
  expect(state.speech).toBe('Committed! 📦')
  const a = JSON.parse(w.written[activityFiles(w)[0] ?? ''] ?? '{}')
  expect(a.commits).toBe(1)
})

test('asking Clawd from the desktop gets Haiku\'s answer in a bubble', async ($, on) => {
  const w = world()
  const { clock } = engine(on, w)
  const asked: string[] = []
  on('model.complete', (_, e) => {
    asked.push(`${e.model}: ${typeof e.prompt === 'string' ? e.prompt : ''}`)

    return { value: { isAnswered: true as const, text: 'A JPA entity maps a table.', usage: { input_tokens: 1, output_tokens: 1, cache_read_input_tokens: 0, cache_creation_input_tokens: 0 } } }
  })

  await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })
  w.written[COMMANDS] = 'ask what is a JPA entity?\r\n'
  await clock.advance(1_500)

  expect(asked).toEqual(['haiku: what is a JPA entity?'])
  const last = JSON.parse(w.written[STATE] ?? '{}').events.at(-1)
  expect(last).toMatchObject({ kind: 'answer', data: { text: 'A JPA entity maps a table.' } })
})

test('/clawd stats reports the machine-wide day the pet added up', async ($, on) => {
  const w = world()
  engine(on, w)
  const day = new Date(1_000)
  const date = `${day.getFullYear()}-${String(day.getMonth() + 1).padStart(2, '0')}-${String(day.getDate()).padStart(2, '0')}`
  w.written[STATS] = JSON.stringify({
    date, activeMin: 312, perCategory: { terminal: 140 },
    claude: { sessions: 3, prompts: 42, commits: 2 }, perProject: { 'my-app': 120, kb: 40 },
  })

  await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })
  const r = await clawd($, 'stats')

  expect(r.text).toContain('5h12m active')
  expect(r.text).toContain('2h20m in terminals')
  expect(r.text).toContain('3 Claude sessions')
  expect(r.text).toContain('my-app: 2h00m')
})
