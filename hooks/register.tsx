import { atom, read, update } from 'claude-code'
import type { EngineInterface, Register } from 'claude-code'

import type { Mood } from '../types'

const PANE = 'clawd'
const TITLE = 'Clawd'

const mood = atom({ plugin: 'clawd', key: 'mood' } as const, 'idle')
const speech = atom({ plugin: 'clawd', key: 'speech' } as const, 'Hi! I\'m Clawd 🦀')
const model = atom({ plugin: 'clawd', key: 'model' } as const, '')
const contextPercent = atom({ plugin: 'clawd', key: 'contextPercent' } as const, null)
const isBreakDue = atom({ plugin: 'clawd', key: 'isBreakDue' } as const, false)
const isPetRunning = atom({ plugin: 'clawd', key: 'isPetRunning' } as const, false)
const today = atom({ plugin: 'clawd', key: 'today' } as const, '')
const isFocus = atom({ plugin: 'clawd', key: 'isFocus' } as const, false)
const isTracking = atom({ plugin: 'clawd', key: 'isTracking' } as const, true)

const TICK_MS = 1_000
const SPEECH_MS = 8_000
const SLEEPY_MS = 5 * 60_000
const BREAK_MS = 50 * 60_000
const AWAY_MS = 15 * 60_000
const COMPACT_AT = 80
// A gap between two things Claude does shorter than this counts as time worked.
const ACTIVE_GAP_MS = 5 * 60_000
const CELEBRATE_MS = 60_000
const WEATHER_MS = 30 * 60_000
const STATS_MS = 30_000
const EVENT_KEEP = 20
const TEMPO_MS = 3_000
const FILE_MAX = 50_000

const MODELS = [
  { label: 'Opus', alias: 'opus' },
  { label: 'Sonnet', alias: 'sonnet' },
  { label: 'Haiku', alias: 'haiku' },
  { label: 'Fable', alias: 'fable' },
]

// What the pet's Claude menu can run; anything else it sends is ignored.
const RUNS: Record<string, { command: string, args?: string }> = {
  new: { command: 'clear' },
}

type Settings = {
  focus: boolean
  tracking: boolean
  trackTitles: boolean
  sound: boolean
  tts: boolean
  weather: boolean
  place: string
  lat: number | null
  lon: number | null
  summaryAt: string
}

// Shared with the pet, which has the same defaults; a missing file means all of these.
// Weather stays off until lat and lon are set in settings.json.
const DEFAULT_SETTINGS: Settings = {
  focus: false,
  tracking: true,
  trackTitles: false,
  sound: false,
  tts: false,
  weather: true,
  place: '',
  lat: null,
  lon: null,
  summaryAt: '17:30',
}

const LINES = {
  greet: ['Hi! I\'m Clawd 🦀', 'Ready when you are!', 'Let\'s build something.'],
  submit: ['On it!', 'Ooh, a new task!', 'Let\'s go!', 'Thinking cap on.'],
  done: ['Done! ✨', 'All yours.', 'That went well!', 'Nice one.'],
  error: ['Uh oh, an error.', 'Hmm, that failed.', 'Oops. Retrying?'],
  pet: ['Hehe, thanks!', '*happy clicking*', 'You\'re the best!', '🦀💛'],
  sleepy: ['zzz...', 'Just resting my eyes...'],
}

const ASK_SYSTEM = 'You are Clawd, a tiny crab who lives on a developer\'s desktop. '
  + 'Answer in at most three short sentences, plain text, no markdown.'

const pick = (lines: readonly string[]) => lines[Math.floor(Math.random() * lines.length)] ?? ''

const baseName = (path: string) => path.split(/[\\/]/).pop() ?? path

const lineForTool = (tool: string, file: string | undefined) => {
  const name = file ? baseName(file) : undefined

  switch (tool) {
    case 'Read':
      return name ? `Reading ${name}...` : 'Reading...'
    case 'Edit':
    case 'Write':
    case 'NotebookEdit':
      return name ? `Editing ${name}...` : 'Editing...'
    case 'Bash':
    case 'PowerShell':
      return 'Running a command...'
    case 'Grep':
    case 'Glob':
      return 'Searching...'
    case 'WebFetch':
    case 'WebSearch':
      return 'Looking it up online...'
    case 'Agent':
      return 'Sending a helper!'
    default:
      return `Using ${tool}...`
  }
}

// Which prop the pet holds for a tool.
const kindForTool = (tool: string) => {
  switch (tool) {
    case 'Read':
      return 'read'
    case 'Edit':
    case 'Write':
    case 'NotebookEdit':
      return 'edit'
    case 'Grep':
    case 'Glob':
      return 'search'
    case 'Bash':
    case 'PowerShell':
      return 'bash'
    case 'WebFetch':
    case 'WebSearch':
      return 'web'
    case 'Agent':
      return 'agent'
    default:
      return ''
  }
}

const GIT = [
  { what: 'commit', pattern: /\bgit\s+(?:-\S+\s+)*commit\b/, xp: 20, line: 'Committed! 📦' },
  { what: 'push', pattern: /\bgit\s+(?:-\S+\s+)*push\b/, xp: 10, line: 'Pushed! 🚀' },
  { what: 'mr', pattern: /\b(?:glab\s+mr\s+create|gh\s+pr\s+create)\b/, xp: 30, line: 'Merge request raised! 🎉' },
] as const
const TEST_RUN = /\b(?:mvnw?|gradlew?|npm|pnpm|yarn|bun|pytest|go|dotnet)\b.*\btest\b/

const meter = (percent: number, width: number) => {
  const filled = Math.round((percent / 100) * width)

  return '▓'.repeat(filled) + '░'.repeat(Math.max(0, width - filled))
}

const pad = (n: number) => String(n).padStart(2, '0')

// The local calendar day, as the activity folders name it.
const dayOf = (ms: number) => {
  const d = new Date(ms)

  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`
}

const hours = (minutes: number) => {
  const m = Math.round(minutes)

  return m >= 60 ? `${Math.floor(m / 60)}h${pad(m % 60)}m` : `${m}m`
}

const weatherKind = (code: number) => {
  if (code <= 1) return 'clear'
  if (code <= 3) return 'cloudy'
  if (code <= 48) return 'fog'
  if (code >= 95) return 'storm'
  if ((code >= 71 && code <= 77) || code === 85 || code === 86) return 'snow'

  return 'rain'
}

type PetEvent = { id: number, kind: string, at: number, data?: Record<string, unknown> }

// One session's share of the day, in its own file: no session writes another's.
type Activity = {
  day: string
  sessionId: string
  cwd: string
  project: string
  startedAt: number
  lastAt: number
  prompts: number
  turns: number
  toolCalls: Record<string, number>
  errors: number
  commits: number
  pushes: number
  mrs: number
  tests: number
  activeMs: number
  filesTouched: string[]
}

// What the pet adds up from every session and the whole PC, in stats.json.
type Stats = {
  date?: string
  activeMin?: number
  idleMin?: number
  perCategory?: Record<string, number>
  claude?: { sessions?: number, prompts?: number, turns?: number, toolCalls?: number, commits?: number, pushes?: number, mrs?: number, activeMin?: number }
  perProject?: Record<string, number>
}

// The module's own variables start over on a reload (which also ends the pet); the atoms stay.
let speechUntil = 0
let lastActivity = 0
let cancelTick: (() => void) | undefined
let pet: AsyncGenerator<unknown, unknown> | undefined
let events: PetEvent[] = []
let eventSeq = 0
let lastWritten = ''
// When this session last told the pet it is here; 0 once it has said goodbye.
let aliveAt = 0
let hasEnded = false
let toolKind = ''
let turnStartedAt = 0
let keyTimes: number[] = []
let weather: { temp: number, kind: string, isDay: boolean } | null = null
let lastWeatherAt = 0
let lastStatsAt = 0
let activity: Activity | undefined
let sessionKey = ''
let cwd = ''
let project = ''

const BEAT_MS = 20_000
const PET_ALIVE_MS = 10_000

// The pet's files live outside the mod folder, so writing them reloads nothing.
async function petPath($: EngineInterface, file: string) {
  const config = (await $.env.get('CLAUDE_CONFIG_DIR'))
    ?? `${(await $.env.get('USERPROFILE')) ?? (await $.env.get('HOME')) ?? '.'}\\.claude`

  return `${config}\\clawd-pet\\${file}`
}

async function statePath($: EngineInterface) {
  return petPath($, 'state.json')
}

async function readJson<T>($: EngineInterface, file: string): Promise<T | undefined> {
  try {
    return JSON.parse(await $.fs.read(await petPath($, file))) as T
  } catch {
    return undefined
  }
}

async function readSettings($: EngineInterface): Promise<Settings> {
  return { ...DEFAULT_SETTINGS, ...(await readJson<Partial<Settings>>($, 'settings.json')) }
}

async function refreshSettings($: EngineInterface) {
  const s = await readSettings($)
  await update($, isFocus, () => s.focus)
  await update($, isTracking, () => s.tracking)

  return s
}

// The pet writes the same file, so read it fresh and change one key.
async function writeSetting<K extends keyof Settings>($: EngineInterface, key: K, value: Settings[K]) {
  const raw = (await readJson<Record<string, unknown>>($, 'settings.json')) ?? {}
  await $.fs.write(await petPath($, 'settings.json'), JSON.stringify({ ...raw, [key]: value }, null, 2))
  await refreshSettings($)
}

async function syncPet($: EngineInterface) {
  const now = await $.clock.now()
  // Before the state is read: nothing may wait between reading it and writing it, or an older
  // sync still waiting would overwrite a newer one.
  const path = await statePath($)
  keyTimes = keyTimes.filter(t => now - t < TEMPO_MS)
  const json = JSON.stringify({
    mood: await read($, mood),
    speech: await read($, speech),
    model: await read($, model),
    contextPercent: await read($, contextPercent),
    isBreakDue: await read($, isBreakDue),
    toolKind,
    // Keystrokes a second in the prompt, so Clawd types along.
    tempo: Math.round((keyTimes.length / (TEMPO_MS / 1_000)) * 10) / 10,
    weather,
    events,
    // A pet from before the event queue reads only the latest.
    event: events.at(-1) ?? { id: 0, kind: 'none' },
    aliveAt,
  })
  if (json !== lastWritten) {
    lastWritten = json
    await $.fs.write(path, json)
  }
}

// Queued for the pet, which acts on each event once; ids grow across reloads and sessions.
async function pushEvent($: EngineInterface, kind: string, data?: Record<string, unknown>) {
  const at = await $.clock.now()
  eventSeq = Math.max(eventSeq + 1, at)
  events = [...events, { id: eventSeq, kind, at, ...(data ? { data } : {}) }].slice(-EVENT_KEEP)
  await syncPet($)
}

async function say($: EngineInterface, next: Mood, text: string) {
  lastActivity = await $.clock.now()
  speechUntil = lastActivity + SPEECH_MS
  await update($, mood, () => next)
  await update($, speech, () => text)
  await syncPet($)
}

async function petClawd($: EngineInterface) {
  await pushEvent($, 'pet')
  await say($, 'happy', pick(LINES.pet))
}

async function refreshModel($: EngineInterface) {
  const current = await $.session.model()
  await update($, model, () => current)
  await syncPet($)

  return current
}

async function refreshUsage($: EngineInterface) {
  const { context } = await $.session.usage()
  await update($, contextPercent, () => context.percent ?? null)
  await syncPet($)
}

// ------------------------------------------------------------- the tracking --

// Where this session's work lands: the repository's folder name, else the working folder's.
async function learnSession($: EngineInterface) {
  const now = await $.clock.now()
  sessionKey = await $.session.id().catch(() => `session-${now}`)
  cwd = await $.session.cwd().catch(() => '')
  const repo = await $.session.repo().catch(() => null)
  project = baseName(repo?.root ?? cwd) || 'unknown'
}

// Counts something this session did into its activity file for today.
async function track($: EngineInterface, change: (a: Activity) => void = () => undefined) {
  if (!(await read($, isTracking))) {
    return
  }
  const now = await $.clock.now()
  const day = dayOf(now)
  if (!activity || activity.day !== day) {
    activity = {
      day, sessionId: sessionKey, cwd, project, startedAt: now, lastAt: now, prompts: 0, turns: 0,
      toolCalls: {}, errors: 0, commits: 0, pushes: 0, mrs: 0, tests: 0, activeMs: 0, filesTouched: [],
    }
  }
  const gap = now - activity.lastAt
  if (gap > 0 && gap < ACTIVE_GAP_MS) {
    activity.activeMs += gap
  }
  activity.lastAt = now
  change(activity)
  const file = sessionKey.replace(/[^\w.-]/g, '_')
  await $.fs.write(await petPath($, `activity\\${day}\\${file}.json`), JSON.stringify(activity))
}

const todayLine = (s: Stats | undefined) => {
  if (!s || s.date === undefined) {
    return ''
  }
  const c = s.claude ?? {}
  const parts = [`${hours(s.activeMin ?? 0)} active`]
  if (s.perCategory?.terminal) parts.push(`${hours(s.perCategory.terminal)} in terminals`)
  parts.push(`${c.sessions ?? 0} Claude sessions`, `${c.prompts ?? 0} prompts`)
  if (c.commits) parts.push(`${c.commits} commits`)

  return parts.join(' · ')
}

async function refreshToday($: EngineInterface) {
  const line = todayLine(await readJson<Stats>($, 'stats.json'))
  if (line !== (await read($, today))) {
    await update($, today, () => line)
  }
}

// The day's totals across every terminal and Claude session, from the pet's sums.
async function statsReport($: EngineInterface, span: string) {
  const now = await $.clock.now()
  const days = span === 'week' ? 7 : 1
  const rows: string[] = []
  const projects: Record<string, number> = {}
  let active = 0
  for (let i = days - 1; i >= 0; i--) {
    const day = dayOf(now - i * 86_400_000)
    const s = i === 0
      ? await readJson<Stats>($, 'stats.json')
      : await readJson<Stats>($, `activity\\${day}\\_total.json`)
    if (!s || (i === 0 && s.date !== day)) {
      continue
    }
    active += s.activeMin ?? 0
    for (const [name, min] of Object.entries(s.perProject ?? {})) {
      projects[name] = (projects[name] ?? 0) + min
    }
    rows.push(`${day}: ${todayLine(s)}`)
  }
  if (!rows.length) {
    return 'No activity tracked yet. Clawd adds it up once the desktop pet is running.'
  }
  const top = Object.entries(projects).sort((a, b) => b[1] - a[1]).slice(0, 5)
    .map(([name, min]) => `  ${name}: ${hours(min)}`)

  return [
    days === 1 ? 'Today, across every terminal:' : `Last 7 days: ${hours(active)} active`,
    ...rows,
    ...(top.length ? ['Claude time by project:', ...top] : []),
  ].join('\n')
}

// ----------------------------------------------------------- the pet's side --

// Whether a Clawd is on the desktop, whoever started it: it touches pet.alive every few seconds.
async function isPetAlive($: EngineInterface) {
  try {
    const at = Number(await $.fs.read(await petPath($, 'pet.alive')))

    return (await $.clock.now()) - at < PET_ALIVE_MS
  } catch {
    return false
  }
}

// What the pet's right-click menu asked for since the last look.
async function readPetCommands($: EngineInterface) {
  const path = await petPath($, 'commands.txt')
  let text = ''
  try {
    text = await $.fs.read(path)
  } catch {
    return
  }
  if (!text.trim()) {
    return
  }
  await $.fs.write(path, '')
  for (const line of text.split(/\r?\n/).filter(Boolean)) {
    await onPetLine($, line).catch(() => undefined)
  }
}

async function refreshWeather($: EngineInterface) {
  const s = await readSettings($)
  if (!s.weather || typeof s.lat !== 'number' || typeof s.lon !== 'number') {
    weather = null

    return
  }
  const r = await $.http.fetch(
    `https://api.open-meteo.com/v1/forecast?latitude=${s.lat}&longitude=${s.lon}&current=temperature_2m,weather_code,is_day`,
  )
  if (!r.ok) {
    return
  }
  const cur = (JSON.parse(r.text) as { current?: { temperature_2m: number, weather_code: number, is_day: number } }).current
  if (cur) {
    weather = { temp: cur.temperature_2m, kind: weatherKind(cur.weather_code), isDay: cur.is_day === 1 }
  }
}

async function tick($: EngineInterface) {
  const now = await $.clock.now()

  if (!hasEnded && now - aliveAt >= BEAT_MS) {
    aliveAt = now
  }
  await readPetCommands($)
  const alive = Boolean(pet) || (await isPetAlive($))
  if (alive !== (await read($, isPetRunning))) {
    await update($, isPetRunning, () => alive)
  }
  if (now - lastStatsAt >= STATS_MS) {
    lastStatsAt = now
    await refreshSettings($)
    await refreshToday($)
  }
  if (now - lastWeatherAt >= WEATHER_MS) {
    lastWeatherAt = now
    void refreshWeather($).catch(() => undefined)
  }

  const lastBreakAt = Number((await $.store.get('lastBreakAt')) ?? now)
  if (now - lastActivity > AWAY_MS) {
    // Away long enough to count as a break.
    await $.store.set('lastBreakAt', now)
  } else if (now - lastBreakAt > BREAK_MS && !(await read($, isBreakDue)) && !(await read($, isFocus))) {
    await update($, isBreakDue, () => true)
    await update($, mood, () => 'break')
    await update($, speech, () => 'Time to stretch & drink water 💧')
    await syncPet($)
    $.ui.toast('Clawd: time to stretch & drink water 💧')

    return
  }

  if (await read($, isBreakDue)) {
    return
  }

  const current = await read($, mood)
  if (now - lastActivity > SLEEPY_MS) {
    if (current !== 'sleepy') {
      await update($, mood, () => 'sleepy')
      await update($, speech, () => pick(LINES.sleepy))
    }
  } else if (now > speechUntil && current !== 'idle' && current !== 'working') {
    await update($, mood, () => 'idle')
  }
  if ((await read($, mood)) !== 'working') {
    toolKind = ''
  }
  await syncPet($)
}

async function switchModel($: EngineInterface, alias: string, label: string) {
  await say($, 'working', `Switching to ${label}...`)
  await $.command.run({ command: 'model', args: alias })
  const current = await refreshModel($)
  await say($, 'happy', `Now on ${current}!`)
}

async function compact($: EngineInterface) {
  toolKind = 'compact'
  await say($, 'working', 'Tidying up context...')
  try {
    await $.session.compact({})
    await refreshUsage($)
    await say($, 'happy', 'Squeaky clean! ✨')
  } catch {
    await say($, 'worried', 'Can\'t compact mid-turn.')
  }
}

async function takeBreak($: EngineInterface) {
  await $.store.set('lastBreakAt', await $.clock.now())
  await update($, isBreakDue, () => false)
  await say($, 'happy', 'Welcome back! 💪')
}

// A short answer from Haiku, shown in Clawd's bubble.
async function answer($: EngineInterface, prompt: string) {
  await say($, 'working', 'Hmm, let me think...')
  const r = await $.model.complete({ model: 'haiku', system: ASK_SYSTEM, prompt, maxTokens: 400 })
  const text = r.isAnswered ? r.text.trim() : 'I couldn\'t get an answer just now.'
  await say($, r.isAnswered ? 'happy' : 'worried', r.isAnswered ? 'Here\'s what I think!' : 'Hmm...')
  await pushEvent($, 'answer', { text })
}

async function summarizeFile($: EngineInterface, path: string) {
  let text = ''
  try {
    text = await $.fs.read(path)
  } catch {
    await say($, 'worried', `I can't read ${baseName(path)}.`)

    return
  }
  await answer($, `In two sentences, what is this file (${baseName(path)}) and what does it do?\n\n${text.slice(0, FILE_MAX)}`)
}

const CLIP_ASKS: Record<string, string> = {
  explain: 'Explain this briefly:',
  summarise: 'Summarise this in two sentences:',
  fix: 'Point out the most likely bug or mistake in this, briefly:',
}

async function onClipboard($: EngineInterface, mode: string) {
  const text = await $.fs.read(await petPath($, 'clip.txt')).catch(() => '')
  if (!text.trim()) {
    await say($, 'worried', 'The clipboard is empty.')

    return
  }
  await answer($, `${CLIP_ASKS[mode] ?? CLIP_ASKS.explain}\n\n${text.slice(0, FILE_MAX)}`)
}

async function toastSummary($: EngineInterface) {
  const line = todayLine(await readJson<Stats>($, 'stats.json'))
  if (line) {
    $.ui.toast(`Clawd's day: ${line}`)
  }
}

// What the pet asks for, one line each in commands.txt.
async function onPetLine($: EngineInterface, line: string) {
  const trimmed = line.trim()
  const verb = trimmed.split(/\s+/)[0] ?? ''
  const arg = trimmed.slice(verb.length).trim()
  switch (verb) {
    case 'model': {
      const known = MODELS.find(m => m.alias === arg)
      if (arg) {
        await switchModel($, arg, known?.label ?? arg)
      }
      break
    }
    case 'compact':
      await compact($)
      break
    case 'hide':
      $.ui.toast('Clawd went to hide. /clawd brings them back.')
      break
    case 'ask':
      if (arg) await answer($, arg)
      break
    case 'file':
      if (arg) await summarizeFile($, arg)
      break
    case 'clip':
      await onClipboard($, arg)
      break
    case 'run': {
      if (arg === 'panel') {
        await $.ui.open({ id: PANE, title: TITLE })
      } else if (RUNS[arg]) {
        await $.command.run(RUNS[arg])
      }
      break
    }
    case 'toast':
      if (arg) $.ui.toast(`Clawd: ${arg}`)
      break
    case 'speak':
      if (arg && (await readSettings($)).tts) await $.audio.speak(arg)
      break
    case 'summary':
      await toastSummary($)
      break
    // The pet changed settings.json itself; pick it up.
    case 'setting':
      await refreshSettings($)
      break
  }
}

// Starts the desktop pet unless one is up already (say, the one started at login); it runs
// until the module unloads, stopPet, or the pet's own Hide.
async function startPet($: EngineInterface) {
  if (pet || (await $.env.get('OS')) !== 'Windows_NT') {
    return
  }
  // Read the time first: a goodbye may land while the read waits.
  const now = await $.clock.now()
  if (!hasEnded) {
    aliveAt = now
  }
  await syncPet($)
  if (await isPetAlive($)) {
    await update($, isPetRunning, () => true)

    return
  }
  const script = `${$.plugin.root}\\pet\\clawd-pet.ps1`
  const stream = $.process.spawn({
    argv: [
      'powershell.exe', '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-STA',
      '-WindowStyle', 'Hidden', '-File', script, '-StateFile', await statePath($),
    ],
  })
  pet = stream
  await update($, isPetRunning, () => true)

  let errors = ''
  try {
    for await (const { stream: from, text } of stream) {
      // The pet's commands come through commands.txt; its stdout only says "already-running".
      if (from === 'stderr') {
        errors += text
        $.ui.log(`clawd-pet: ${text.trim()}`, { to: 'debug' })
      }
    }
    const { code } = await stream.result
    if (code !== 0 && pet === stream && errors) {
      $.ui.toast(`Clawd's desktop pet stopped: ${errors.trim().split(/\r?\n/)[0]}`)
    }
  } catch {
    // Closed by stopPet or the module unloading.
  } finally {
    if (pet === stream) {
      pet = undefined
    }
    await update($, isPetRunning, () => false).catch(() => undefined)
  }
}

// Puts Clawd away, whoever started them: the pet leaves on a hide event.
async function stopPet($: EngineInterface) {
  await pushEvent($, 'hide')
  const running = pet
  pet = undefined
  await running?.return(undefined)
  await update($, isPetRunning, () => false)
}

// Tells the pet this session is gone, so it stops showing Claude's last mood.
async function sayGoodbye($: EngineInterface) {
  hasEnded = true
  aliveAt = 0
  await update($, mood, () => 'idle')
  await update($, speech, () => 'See you soon! 👋')
  await syncPet($)
}

async function toggleFocus($: EngineInterface) {
  const on = !(await read($, isFocus))
  await writeSetting($, 'focus', on)
  await say($, 'happy', on ? 'Focus mode: I\'ll be quiet. 🤫' : 'Focus mode off!')
}

async function toggleTracking($: EngineInterface) {
  await writeSetting($, 'tracking', !(await read($, isTracking)))
}

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    await $.command.register({
      name: 'clawd',
      description: 'Clawd, your desktop coding buddy (args: hide, pet, panel, stats [week], focus, pomodoro)',
    })

    lastActivity = await $.clock.now()
    eventSeq = Math.max(eventSeq, lastActivity)
    if ((await $.store.get('lastBreakAt')) === undefined) {
      await $.store.set('lastBreakAt', lastActivity)
    }
    await refreshSettings($)
    await learnSession($)
    await track($)
    await refreshModel($)
    await refreshUsage($)
    await say($, 'happy', pick(LINES.greet))

    cancelTick?.()
    // Both run on past this hook; a failure of theirs is no reason to stop the session.
    cancelTick = $.clock.every(TICK_MS, () => void tick($).catch(() => undefined)).cancel
    void startPet($).catch(() => undefined)

    return next(e)
  })

  on('session.end', async ($, e, next) => {
    await track($).catch(() => undefined)
    await sayGoodbye($).catch(() => undefined)

    return next(e)
  })

  on('command.run', { command: 'clawd' }, async ($, e) => {
    const [arg = '', rest = ''] = (e.args ?? '').trim().toLowerCase().split(/\s+/)

    if (arg === 'hide') {
      await stopPet($)
      await $.ui.close({ id: PANE })

      return { text: 'Clawd is hiding. /clawd to bring them back.' }
    }
    if (arg === 'panel') {
      await $.ui.open({ id: PANE, title: TITLE })

      return { text: 'Clawd\'s control panel is open.' }
    }
    if (arg === 'stats') {
      return { text: await statsReport($, rest) }
    }
    if (arg === 'focus') {
      await toggleFocus($)

      return { text: (await read($, isFocus)) ? 'Focus mode on: Clawd stays quiet.' : 'Focus mode off.' }
    }
    if (arg === 'pomodoro') {
      await pushEvent($, 'pomodoro')

      return { text: 'Pomodoro toggled on the desktop pet. 🍅' }
    }

    void startPet($).catch(() => undefined)
    // Back from "Hide for 1 hour", if that is where they are.
    await pushEvent($, 'show')
    if (arg === 'pet') {
      await petClawd($)

      return { text: 'You petted Clawd. 🦀' }
    }

    return { text: 'Clawd is on your desktop! 🦀 Right-click them for the menu; /clawd panel for the control panel.' }
  })

  on('prompt.submit', async ($, e, next) => {
    await say($, 'working', pick(LINES.submit))
    await track($, a => { a.prompts++ })

    return next(e)
  })
    // Clawd's chatter must never hold up a prompt.
    .catch(($, e, next) => next(e))

  on('prompt.change', async ($, e, next) => {
    keyTimes.push(await $.clock.now())

    return next(e)
  })
    .catch(($, e, next) => next(e))

  on('tool.check', async ($, e, next) => {
    const r = await next(e)
    if (r.decision === 'ask') {
      // Waiting on the person: Clawd waves until the next thing happens.
      await pushEvent($, 'permission', { tool: e.tool }).catch(() => undefined)
    }

    return r
  })
    .catch(($, e, next) => next(e))

  on('tool.call', async ($, e, next) => {
    const file = (e as { file_path?: unknown }).file_path
    const command = (e as { command?: unknown }).command
    toolKind = kindForTool(e.tool)
    await say($, 'working', lineForTool(e.tool, typeof file === 'string' ? file : undefined))

    const ran = await next(e)
    // The tool already ran: a failure here must not reach the .catch, which would run it again.
    await afterTool($, e.tool, ran.isError === true, typeof file === 'string' ? file : undefined,
      typeof command === 'string' ? command : '', ran.text).catch(() => undefined)

    return ran
  })
    // Or a tool call.
    .catch(($, e, next) => next(e))

  on('turn.start', async ($, e, next) => {
    if (!turnStartedAt) {
      turnStartedAt = await $.clock.now()
    }

    return next(e)
  })
    .catch(($, e, next) => next(e))

  on('turn.complete', async ($, e, next) => {
    const done = await next(e)
    const now = await $.clock.now()
    const took = turnStartedAt ? now - turnStartedAt : 0
    turnStartedAt = 0
    toolKind = ''
    await refreshUsage($)
    await refreshModel($)
    await track($, a => { a.turns++ })
    await pushEvent($, 'xp', { n: 5, why: 'turn' })
    if (!(await read($, isBreakDue))) {
      await say($, 'happy', pick(LINES.done))
      if (took >= CELEBRATE_MS) {
        await pushEvent($, 'celebrate', { secs: Math.round(took / 1_000) })
      }
    }

    return done
  })

  on('ui.render', { component: 'Pane', requestId: PANE }, async ($, e) => {
    const { Box, Text, Button } = $.ui.resolve(e)
    const percent = await read($, contextPercent)
    const current = await read($, model)
    const breakDue = await read($, isBreakDue)
    const running = await read($, isPetRunning)
    const day = await read($, today)
    const focus = await read($, isFocus)
    const tracking = await read($, isTracking)
    const columns = e.props.bodyColumns ?? 30
    const meterWidth = Math.max(6, Math.min(16, columns - 12))

    return (
      <Box flexDirection="column" paddingX={1}>
        <Text color="claude">🦀 {await read($, speech)}</Text>
        {!running && <Text dimColor>Clawd isn't on your desktop: /clawd brings them back.</Text>}

        <Box flexDirection="column" marginTop={1}>
          <Text dimColor>Model: {current || '...'}</Text>
          <Box flexDirection="row" flexWrap="wrap">
            {MODELS.map(m => (
              <Button key={`model-${m.alias}`} label={m.label} onPress={() => void switchModel($, m.alias, m.label)} />
            ))}
          </Box>
        </Box>

        {percent !== null && (
          <Box flexDirection="column" marginTop={1}>
            <Text color={percent >= COMPACT_AT ? 'warning' : undefined} dimColor={percent < COMPACT_AT}>
              ctx {meter(percent, meterWidth)} {Math.round(percent)}%
            </Text>
            {percent >= COMPACT_AT && <Button key="compact" label="Compact" onPress={() => void compact($)} />}
          </Box>
        )}

        <Box flexDirection="column" marginTop={1}>
          <Text dimColor>
            {tracking ? (day ? `Today: ${day}` : 'Today: nothing tracked yet') : 'Tracking is paused'}
          </Text>
          <Box flexDirection="row" flexWrap="wrap">
            <Button key="focus" label={focus ? 'Focus: on' : 'Focus: off'} onPress={() => void toggleFocus($)} />
            <Button key="pomodoro" label="Pomodoro" onPress={() => void pushEvent($, 'pomodoro')} />
            <Button key="tracking" label={tracking ? 'Pause tracking' : 'Resume tracking'} onPress={() => void toggleTracking($)} />
          </Box>
        </Box>

        <Box flexDirection="row" marginTop={1}>
          <Button key="pet" label="Pet" onPress={() => void petClawd($)} />
          {breakDue && <Button key="break" label="Done stretching" onPress={() => void takeBreak($)} />}
        </Box>
      </Box>
    )
  })
}

// What a finished tool call means for the pet and the day's numbers.
async function afterTool($: EngineInterface, tool: string, isError: boolean, file: string | undefined, command: string, text: string | undefined) {
  const git = isError ? undefined : GIT.find(g => g.pattern.test(command))
  const tested = !isError && TEST_RUN.test(command)
  await track($, a => {
    a.toolCalls[tool] = (a.toolCalls[tool] ?? 0) + 1
    if (isError) a.errors++
    if (git?.what === 'commit') a.commits++
    if (git?.what === 'push') a.pushes++
    if (git?.what === 'mr') a.mrs++
    if (tested) a.tests++
    if (file && (tool === 'Edit' || tool === 'Write') && !a.filesTouched.includes(file) && a.filesTouched.length < 200) {
      a.filesTouched.push(file)
    }
  })
  if (isError) {
    const first = (text ?? '').split(/\r?\n/).find(l => l.trim())?.trim().slice(0, 60)
    await say($, 'worried', first ? `Uh oh: ${first}` : pick(LINES.error))
  } else if (git) {
    await say($, 'happy', git.line)
    await pushEvent($, 'git', { what: git.what })
    await pushEvent($, 'xp', { n: git.xp, why: git.what })
  } else if (tested) {
    await pushEvent($, 'xp', { n: 10, why: 'test' })
  }
}
