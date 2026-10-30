export type Mood = 'idle' | 'working' | 'happy' | 'worried' | 'sleepy' | 'break'

declare module 'claude-code' {
  interface PluginState {
    clawd: {
      mood: Mood
      speech: string
      model: string
      contextPercent: number | null
      isBreakDue: boolean
      isPetRunning: boolean
      // The machine-wide totals for today, one line, from the pet's stats.json.
      today: string
      isFocus: boolean
      isTracking: boolean
    }
  }
}
