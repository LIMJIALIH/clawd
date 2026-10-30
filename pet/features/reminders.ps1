# ----------------------------------------------------------- the reminders --
# "Remind me in 20m to stand up" / "at 15:30 standup". Kept in reminders.json, so they outlive
# a restart. When one is due Clawd runs to the middle of the screen holding up a sign.

$RemindersFile = Join-Path $petDir 'reminders.json'
$REM = @{ list = [Collections.ArrayList]::new(); since = 0.0 }

# A small text box; the answer, or $null when cancelled.
function Show-Input([string]$title, [string]$prompt, [string]$initial = '') {
  $w = [Windows.Window]::new()
  $w.Title = $title
  $w.Width = 380; $w.SizeToContent = 'Height'
  $w.WindowStartupLocation = 'CenterScreen'
  $w.Topmost = $true
  $w.ResizeMode = 'NoResize'
  $panel = [Windows.Controls.StackPanel]::new()
  $panel.Margin = '14'
  $label = [Windows.Controls.TextBlock]::new()
  $label.Text = $prompt; $label.TextWrapping = 'Wrap'; $label.Margin = '0,0,0,8'
  $box = [Windows.Controls.TextBox]::new()
  $box.Text = $initial; $box.Padding = '4'
  $row = [Windows.Controls.StackPanel]::new()
  $row.Orientation = 'Horizontal'; $row.HorizontalAlignment = 'Right'; $row.Margin = '0,10,0,0'
  $ok = [Windows.Controls.Button]::new(); $ok.Content = 'OK'; $ok.Width = 80; $ok.IsDefault = $true; $ok.Margin = '0,0,8,0'
  $cancel = [Windows.Controls.Button]::new(); $cancel.Content = 'Cancel'; $cancel.Width = 80; $cancel.IsCancel = $true
  $ok.Add_Click({ $w.DialogResult = $true }.GetNewClosure())
  [void]$row.Children.Add($ok); [void]$row.Children.Add($cancel)
  [void]$panel.Children.Add($label); [void]$panel.Children.Add($box); [void]$panel.Children.Add($row)
  $w.Content = $panel
  $w.Add_ContentRendered({ [void]$w.Activate(); [void]$box.Focus(); $box.SelectAll() }.GetNewClosure())
  if ($w.ShowDialog()) { return $box.Text.Trim() }
  return $null
}

function Load-Reminders {
  $REM.list.Clear()
  try {
    foreach ($r in @([IO.File]::ReadAllText($RemindersFile) | ConvertFrom-Json)) {
      if ($r.at) { [void]$REM.list.Add(@{ at = [DateTime]::Parse([string]$r.at); text = [string]$r.text }) }
    }
  } catch { }
}

function Save-Reminders {
  $out = @($REM.list | ForEach-Object { [ordered]@{ at = $_.at.ToString('s'); text = $_.text } })
  try { [IO.File]::WriteAllText($RemindersFile, (ConvertTo-Json -InputObject $out -Depth 3)) } catch { }
}

# "in 20m stretch", "20 min tea", "in 1h30m call mum", "at 15:30 standup", "15:30 standup".
function Parse-Reminder([string]$text) {
  $t = $text.Trim()
  if ($t -match '^(?:in\s+)?(?:(\d+)\s*h(?:ours?|rs?)?)?\s*(?:(\d+)\s*m(?:in(?:ute)?s?)?)?\s+(?:to\s+)?(.+)$' -and ($Matches[1] -or $Matches[2])) {
    $mins = 60 * [int]$Matches[1] + [int]$Matches[2]
    return @{ at = (Get-Date).AddMinutes($mins); text = $Matches[3] }
  }
  if ($t -match '^(?:at\s+)?(\d{1,2}):(\d{2})\s*(am|pm)?\s+(?:to\s+)?(.+)$') {
    $h = [int]$Matches[1]; $m = [int]$Matches[2]
    if ($Matches[3] -eq 'pm' -and $h -lt 12) { $h += 12 }
    if ($Matches[3] -eq 'am' -and $h -eq 12) { $h = 0 }
    $at = (Get-Date).Date.AddHours($h).AddMinutes($m)
    if ($at -le (Get-Date)) { $at = $at.AddDays(1) }
    return @{ at = $at; text = $Matches[4] }
  }
  return $null
}

function Ask-Reminder {
  $text = Show-Input 'Remind me' 'When and what? e.g. "in 20m stretch", "at 15:30 standup", "1h30m call back"'
  if (-not $text) { return }
  $r = Parse-Reminder $text
  if (-not $r) { Say 'Hmm, try "in 20m stretch" or "at 15:30 standup".' 5 $true; return }
  [void]$REM.list.Add($r)
  Save-Reminders
  Say "Got it! $($r.at.ToString('HH:mm')): $($r.text) 📌" 4 $true
}

function Remind([string]$text) {
  Hold-Prop 'sign' 25
  $S.target = ($S.left + $S.right) / 2
  if (-not $S.air -and -not $S.sky) { Start-Action 'run' 10 }
  Say "⏰ $text" 25 $true
  Play-Cue 'Exclamation'
  Speak-Line "Reminder: $text"
  Send "toast ⏰ $text"
}

function Tick-Reminders([double]$dt) {
  $REM.since += $dt
  if ($REM.since -lt 1) { return }
  $REM.since = 0
  $now = Get-Date
  $due = @($REM.list | Where-Object { $_.at -le $now })
  if (-not $due.Count) { return }
  foreach ($r in $due) { [void]$REM.list.Remove($r); Remind $r.text }
  Save-Reminders
}

function Add-ReminderMenu($parent) {
  $m = [Windows.Controls.MenuItem]::new()
  $m.Header = 'Reminders ⏰'
  [void]$m.Items.Add((Menu-Item 'Remind me...' { Ask-Reminder }))
  foreach ($r in @($REM.list | Sort-Object { $_.at })) {
    $item = Menu-Item "✕ $($r.at.ToString('ddd HH:mm')) $($r.text)" {
      param($sender)
      [void]$REM.list.Remove($sender.Tag); Save-Reminders
      Say 'Reminder removed.' 2 $true
    }
    $item.Tag = $r
    $item.ToolTip = 'Click to remove'
    [void]$m.Items.Add($item)
  }
  [void]$parent.Items.Add($m)
}
