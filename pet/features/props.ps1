# --------------------------------------------------------------- the props --
# What Clawd holds: a prop for the tool Claude is using, a sign for a reminder, an umbrella in
# the rain. Same pieces as the outfits (New-Piece), on their own layer in front of everything.

$wearProp = [Windows.Controls.Canvas]::new()
[void]$body.Children.Add($wearProp)

$PROPS = @{
  # Reading glasses for Read.
  read = @(@(3.4, 0.7, 2.2, 1.2, 'ring:#7A4E2D'), @(10.4, 0.7, 2.2, 1.2, 'ring:#7A4E2D'), @(5.6, 1.1, 4.8, 0.2, '#7A4E2D'))
  # A hard hat for Edit and Write.
  edit = @(@(2.5, -0.4, 11, 0.5, '#F2C230'), @(4, -1.3, 8, 1.0, '#F2C230', 0.5), @(7.6, -1.5, 0.8, 1.2, '#E0A800'))
  # A magnifier for Grep and Glob, held out front.
  search = @(@(14.6, 0.6, 2.2, 2.2, 'ring:#5B5F66'), @(14.9, 0.9, 1.6, 1.6, 'glass:#9FD3FF', 0.8), @(15.4, 2.7, 0.5, 1.4, '#7A4E2D'))
  # A little terminal for Bash.
  bash = @(@(14.2, 0.4, 3.4, 2.4, '#1E1E24', 0.2), @(14.5, 0.8, 1.2, 0.3, '#5BE38C'), @(14.5, 1.4, 2.2, 0.3, '#5BE38C'))
  # A globe for the web.
  web = @(@(14.4, 0.5, 2.6, 2.6, '#5BC0EB', 1.3), @(14.9, 1.0, 1.0, 0.8, '#2E9E6B', 0.4), @(15.8, 2.0, 0.8, 0.6, '#2E9E6B', 0.3))
  # A walkie-talkie for sending a helper.
  agent = @(@(14.6, 0.2, 1.6, 2.6, '#E8505B', 0.2), @(15.6, -0.8, 0.3, 1.0, '#1E1E24'), @(14.9, 0.6, 1.0, 0.6, '#9FD3FF'))
  # A broom for compacting.
  compact = @(@(15.1, -1.2, 0.4, 4.2, '#7A4E2D'), @(14.3, 2.8, 2.0, 1.2, '#F2C230'))
  # A sign held up high, for reminders and meetings.
  sign = @(@(14.9, -1.0, 0.4, 3.6, '#7A4E2D'), @(13.4, -2.6, 3.6, 1.8, '#FFF4E6'), @(13.4, -2.6, 3.6, 1.8, 'ring:#D97757'))
  # An umbrella in the rain.
  umbrella = @(@(0.5, -2.2, 15, 1.2, '#3A6EA5', 0.8), @(7.8, -1.2, 0.4, 2.8, '#1E1E24'), @(7.3, 1.4, 0.9, 0.4, '#1E1E24'))
  # A coffee mug.
  mug = @(@(14.4, 1.2, 1.8, 1.8, '#F4FAFF', 0.2), @(16.1, 1.6, 0.6, 0.9, 'ring:#F4FAFF'), @(14.6, 1.3, 1.4, 0.3, '#6B3F22'))
  # A nightcap after dark.
  nightcap = @(@(2, -0.6, 12, 0.7, '#3A4E8C'), @(6, -1.5, 6, 1.0, '#3A4E8C'), @(11, -2.0, 3, 0.6, '#3A4E8C'), @(13.6, -2.2, 1, 0.8, '#FFFFFF', 0.4))
}
# What a prop is held for, and until when (in Tick seconds); a held prop beats the tool prop.
$PROP = @{ held = ''; until = 0.0; shown = '' }

function Hold-Prop([string]$key, [double]$seconds) {
  $PROP.held = $key
  $PROP.until = $clock.Elapsed.TotalSeconds + $seconds
}

function Show-Prop([string]$key) {
  if ($key -eq $PROP.shown) { return }
  $PROP.shown = $key
  $wearProp.Children.Clear()
  if ($key -and $PROPS.ContainsKey($key)) {
    foreach ($p in $PROPS[$key]) { [void]$wearProp.Children.Add((New-Piece $p)) }
  }
}

# A small heads-up beside Clawd: pomodoro, context, level, open sessions.
$hudText = [Windows.Controls.TextBlock]::new()
$hudText.FontSize = 10
$hudText.FontFamily = 'Segoe UI'
$hudText.Foreground = $DARK
$hudText.Background = [Windows.Media.BrushConverter]::new().ConvertFromString('#E6FFFFFF')
$hudText.Padding = '3,1,3,1'
$hudText.IsHitTestVisible = $false
$hudText.Visibility = 'Collapsed'
[Windows.Controls.Canvas]::SetLeft($hudText, 2)
[void]$stage.Children.Add($hudText)
$HUDSTATE = @{ lines = [ordered]@{}; since = 9.0 }

function Set-Hud([string]$key, [string]$text) {
  if ($text) { $HUDSTATE.lines[$key] = $text } elseif ($HUDSTATE.lines.Contains($key)) { $HUDSTATE.lines.Remove($key) }
}

function Tick-Props([double]$dt, [double]$now) {
  $key = ''
  if ($PROP.held -and $now -lt $PROP.until) { $key = $PROP.held }
  elseif ($S.mood -eq 'working' -and $S.toolKind) { $key = $S.toolKind }
  elseif ($S.action -eq 'sip') { $key = 'mug' }
  elseif ($S.weather -and $S.weather.kind -in @('rain', 'storm') -and -not $S.sky) { $key = 'umbrella' }
  elseif ((Get-Date).Hour -ge 22 -and $S.outfit -eq 'none') { $key = 'nightcap' }
  Show-Prop $key

  # The context meter: from half full, a bar in the HUD; past 80%, Clawd sweats now and then.
  if ($null -ne $S.percent -and (Is-Connected) -and [double]$S.percent -ge 50) {
    $p = [double]$S.percent
    $filled = [int][Math]::Round($p / 10)
    Set-Hud 'ctx' ("ctx " + ('▓' * $filled) + ('░' * (10 - $filled)) + " $([Math]::Round($p))%")
    if ($p -ge 80 -and $rand.Next(400) -eq 0) { Float '💦' $SCREEN 14 1.4 }
  } else { Set-Hud 'ctx' '' }

  $HUDSTATE.since += $dt
  if ($HUDSTATE.since -ge 0.5) {
    $HUDSTATE.since = 0
    $text = (@($HUDSTATE.lines.Values) -join "`n")
    if ($text) {
      $hudText.Text = $text
      $hudText.Visibility = 'Visible'
      [Windows.Controls.Canvas]::SetTop($hudText, $SPRITE_Y - 14 * $HUDSTATE.lines.Count)
    } else { $hudText.Visibility = 'Collapsed' }
  }
}
