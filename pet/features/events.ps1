# -------------------------------------------------------------- the events --
# What the mod queues in state.json's events, each acted on once (see Read-State).

$CONFETTI = @('✦', '✶', '★', '♦', '●')
$CONFETTI_COLORS = @('#E8505B', '#F2C230', '#5BC0EB', '#2E9E6B', '#D97757', '#8E44AD')

function Confetti([int]$n = 10) {
  for ($i = 0; $i -lt $n; $i++) {
    Float $CONFETTI[$rand.Next($CONFETTI.Count)] (Brush $CONFETTI_COLORS[$rand.Next($CONFETTI_COLORS.Count)]) (12 + $rand.Next(8)) (1.2 + $rand.NextDouble())
  }
}

function Format-Secs([double]$secs) {
  $m = [int][Math]::Floor($secs / 60); $rest = [int]($secs % 60)
  if ($m -gt 0) { return "${m}m ${rest}s" }
  return "${rest}s"
}

function Handle-Event($ev) {
  $data = $ev.data
  switch ([string]$ev.kind) {
    'pet' { Pet }
    'permission' {
      # Claude waits on you: jump, wave, and say so until the next thing happens.
      if (-not $S.air -and -not $S.sky) { Hop 480 0 }
      Start-Action 'wave' 4
      Say "Need your OK for $($data.tool)! 👀" 10 $true
      Play-Cue 'Exclamation'
      Speak-Line 'Claude needs your approval'
    }
    'celebrate' {
      Confetti 14
      if (-not $S.air -and -not $S.sky) { Hop 520 0 }
      Say "Done in $(Format-Secs ([double]$data.secs))! 🎉" 4
      Play-Cue 'Asterisk'
    }
    'git' {
      switch ([string]$data.what) {
        'commit' { Confetti 6; Start-Action 'dance' 3 }
        'push' { Start-Sky 'jetpack' }
        'mr' { Confetti 16; Start-Backflip }
      }
      Game-Count ([string]$data.what)
    }
    'xp' { Add-Xp ([int]$data.n) ([string]$data.why) }
    'answer' {
      # A long bubble; right-click has "Copy answer" while it lasts.
      $ASK.last = [string]$data.text
      Say $ASK.last ([Math]::Min(30, 6 + $ASK.last.Length / 15)) $true
      Speak-Line $ASK.last
    }
    'pomodoro' { Toggle-Pomodoro }
    'show' { Bring-Clawd }
  }
}

# A short system sound, if sound is on.
function Play-Cue([string]$name) {
  if (-not $SET.sound) { return }
  try { [Media.SystemSounds]::$name.Play() } catch { }
}

# Read aloud through the mod, if text-to-speech is on.
function Speak-Line([string]$text) {
  if ($SET.tts -and $text) { Send "speak $($text -replace '\s+', ' ')" }
}
