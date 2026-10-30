# ------------------------------------------------------------ the pomodoro --
# Work, short break, work... and a long break every fourth. The countdown sits in the HUD; Clawd
# types through the work and stretches through the breaks.

$POMO = @{ phase = ''; left = 0.0; done = 0; paused = $false }

function Start-Pomodoro([string]$phase) {
  $POMO.phase = $phase
  $POMO.paused = $false
  switch ($phase) {
    'work' { $POMO.left = 60 * [double]$SET.pomodoroWork; Start-Action 'type' 3600; Say 'Focus time! 🍅' 3 $true }
    'break' { $POMO.left = 60 * [double]$SET.pomodoroBreak; Start-Action 'break' 3600; Say 'Short break! Stretch with me 🙆' 5 $true }
    'long' { $POMO.left = 60 * [double]$SET.pomodoroLong; Start-Action 'break' 3600; Say 'Long break, you earned it! ☕' 5 $true }
  }
}

function Stop-Pomodoro {
  $POMO.phase = ''
  Set-Hud 'pomo' ''
  if ($S.action -eq 'type' -or $S.action -eq 'break') { Start-Action 'idle' 1 }
  Say 'Pomodoro stopped.' 2 $true
}

function Toggle-Pomodoro {
  if ($POMO.phase) { Stop-Pomodoro } else { Start-Pomodoro 'work' }
}

function Tick-Pomodoro([double]$dt) {
  if (-not $POMO.phase) { return }
  if (-not $POMO.paused) { $POMO.left -= $dt }
  $icon = '🍅'; if ($POMO.phase -ne 'work') { $icon = '☕' }
  $pause = ''; if ($POMO.paused) { $pause = ' ⏸' }
  $left = [Math]::Max(0, $POMO.left)
  Set-Hud 'pomo' ("$icon {0:00}:{1:00}$pause" -f [Math]::Floor($left / 60), [Math]::Floor($left % 60))
  # Keep doing the right thing, whatever else came along.
  if (-not $S.air -and -not $S.sky -and $S.mood -ne 'working') {
    if ($POMO.phase -eq 'work' -and $S.action -notin @('type', 'wave', 'land', 'dance')) { Start-Action 'type' 3600 }
    if ($POMO.phase -ne 'work' -and $S.action -notin @('break', 'land')) { Start-Action 'break' 3600 }
  }
  if ($POMO.left -gt 0) { return }

  Play-Cue 'Asterisk'
  if ($POMO.phase -eq 'work') {
    $POMO.done++
    Add-Xp 15 'pomodoro'
    Game-Count 'pomodoro'
    Confetti 8
    Send "toast Pomodoro #$($POMO.done) done! Time for a break."
    Speak-Line 'Pomodoro done. Time for a break.'
    if ($POMO.done % 4 -eq 0) { Start-Pomodoro 'long' } else { Start-Pomodoro 'break' }
  } else {
    Send 'toast Break''s over, back to it!'
    Speak-Line 'Break is over.'
    Start-Pomodoro 'work'
  }
}

function Add-PomodoroMenu($parent) {
  $m = [Windows.Controls.MenuItem]::new()
  $m.Header = 'Pomodoro 🍅'
  if (-not $POMO.phase) {
    [void]$m.Items.Add((Menu-Item "Start ($($SET.pomodoroWork)/$($SET.pomodoroBreak) min)" { Start-Pomodoro 'work' }))
  } else {
    $label = 'Pause'; if ($POMO.paused) { $label = 'Resume' }
    [void]$m.Items.Add((Menu-Item $label { $POMO.paused = -not $POMO.paused }))
    [void]$m.Items.Add((Menu-Item 'Skip to next' { $POMO.left = 0 }))
    [void]$m.Items.Add((Menu-Item 'Stop' { Stop-Pomodoro }))
  }
  [void]$m.Items.Add([Windows.Controls.Separator]::new())
  foreach ($len in @(@(25, 5), @(50, 10), @(15, 3))) {
    $item = Menu-Item "Use $($len[0])/$($len[1]) min" {
      param($sender)
      Set-Setting 'pomodoroWork' $sender.Tag[0]; Set-Setting 'pomodoroBreak' $sender.Tag[1]
    } ([int]$SET.pomodoroWork -eq $len[0])
    $item.Tag = $len
    [void]$m.Items.Add($item)
  }
  [void]$parent.Items.Add($m)
}
