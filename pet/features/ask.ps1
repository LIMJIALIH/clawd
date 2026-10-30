# ------------------------------------------------------------------ asking --
# Ask Claude a quick question, have it look at the clipboard or a dropped file (the mod asks
# Haiku and the answer comes back as an "answer" event), and the Claude menu.

$ASK = @{ last = '' }
$ClipFile = Join-Path $petDir 'clip.txt'

function Ask-Claude {
  $q = Show-Input 'Ask Clawd' 'Ask a quick question (Haiku answers in a sentence or three):'
  if (-not $q) { return }
  if (-not (Is-Connected)) { Say 'Open Claude Code first, then ask me! 🦀' 4 $true; return }
  Send "ask $($q -replace '\s+', ' ')"
  Float '?' $ORANGE 18 1.2
}

function Clip-Text {
  try { return [Windows.Clipboard]::GetText() } catch { return '' }
}

function Clipboard-Ask([string]$mode) {
  $text = Clip-Text
  if (-not $text.Trim()) { Say 'The clipboard is empty.' 2 $true; return }
  if (-not (Is-Connected)) { Say 'Open Claude Code first, then ask me! 🦀' 4 $true; return }
  try { [IO.File]::WriteAllText($ClipFile, $text) } catch { return }
  Hold-Prop 'read' 8
  Send "clip $mode"
}

# Pretty-prints JSON on the clipboard, right here; no model needed.
function Clipboard-FormatJson {
  $text = Clip-Text
  try {
    $pretty = $text | ConvertFrom-Json | ConvertTo-Json -Depth 50
    [Windows.Clipboard]::SetText($pretty)
    Say 'JSON formatted on your clipboard ✨' 2.5 $true
  } catch { Say 'That''s not JSON I can read 🤔' 2.5 $true }
}

function Clipboard-Trim {
  $text = Clip-Text
  if (-not $text) { return }
  $clean = (($text -split "`r?`n") | ForEach-Object { $_.TrimEnd() }) -join "`r`n"
  [Windows.Clipboard]::SetText($clean.Trim())
  Say 'Trailing spaces trimmed ✂️' 2 $true
}

function Add-ClaudeMenu($menu, [bool]$live) {
  $m = [Windows.Controls.MenuItem]::new(); $m.Header = 'Claude'
  foreach ($r in @(@('New session (/clear)', 'new'), @('Open Clawd panel', 'panel'))) {
    $i = Menu-Item $r[0] { param($sender) Send "run $($sender.Tag)"; Say 'On it!' 2 }
    $i.Tag = $r[1]; $i.IsEnabled = $live
    [void]$m.Items.Add($i)
  }
  [void]$m.Items.Add([Windows.Controls.Separator]::new())
  $askItem = Menu-Item 'Ask Claude...' { Ask-Claude }
  $askItem.IsEnabled = $live
  [void]$m.Items.Add($askItem)
  if ($ASK.last) { [void]$m.Items.Add((Menu-Item 'Copy last answer' { [Windows.Clipboard]::SetText($ASK.last); Say 'Copied! 📋' 1.5 $true })) }
  $clip = [Windows.Controls.MenuItem]::new(); $clip.Header = 'Clipboard'
  foreach ($c in @(@('Explain it', 'explain'), @('Summarise it', 'summarise'), @('Find the bug', 'fix'))) {
    $i = Menu-Item $c[0] { param($sender) Clipboard-Ask $sender.Tag }
    $i.Tag = $c[1]; $i.IsEnabled = $live
    [void]$clip.Items.Add($i)
  }
  [void]$clip.Items.Add([Windows.Controls.Separator]::new())
  [void]$clip.Items.Add((Menu-Item 'Format JSON' { Clipboard-FormatJson }))
  [void]$clip.Items.Add((Menu-Item 'Trim trailing spaces' { Clipboard-Trim }))
  [void]$m.Items.Add($clip)
  $hint = Menu-Item 'Tip: drop a file on me for a summary' { }
  $hint.IsEnabled = $false
  [void]$m.Items.Add($hint)
  [void]$menu.Items.Add($m)
}

# ------------------------------------------------------------ the glue ------
# Where the features meet the main script: its menu, start and close.

function Add-TrickMenu($acts) {
  [void]$acts.Items.Add([Windows.Controls.Separator]::new())
  [void]$acts.Items.Add((Menu-Item 'Throw a ball ⚽' { Throw-Ball }))
  [void]$acts.Items.Add((Menu-Item 'Sit on this window' { if ((Start-Perch) -ne $true) { Say 'No window to sit on here 🤷' 2 $true } }))
  [void]$acts.Items.Add((Menu-Item 'Coffee ☕' { Start-Action 'sip' 4 }))
  Add-PlayMenu $acts
}

function Add-FeatureMenus($menu) {
  $prod = [Windows.Controls.MenuItem]::new(); $prod.Header = 'Productivity'
  Add-PomodoroMenu $prod
  Add-ReminderMenu $prod
  Add-CalendarMenu $prod
  $focus = Menu-Item 'Focus mode 🤫' { Set-Setting 'focus' (-not $S.focus); if ($S.focus) { Say 'Focus mode. I''ll be quiet.' 2 $true } else { Say 'Focus mode off!' 2 } } $S.focus
  [void]$prod.Items.Add($focus)
  [void]$prod.Items.Add([Windows.Controls.Separator]::new())
  $sum = 'Today: nothing tracked yet'
  if ($TRK.stats) { $sum = "Today: $(Summary-Text $TRK.stats)" }
  $today = Menu-Item $sum { Say (Summary-Text $TRK.stats) 10 $true }
  [void]$prod.Items.Add($today)
  [void]$prod.Items.Add((Menu-Item 'How am I doing?' { How-AmI }))
  [void]$menu.Items.Add($prod)
  Add-GameMenu $menu
  Add-SettingsMenu $menu
}

function Init-Features {
  Init-Tracker
  [void](Write-Stats (Today-Key))
  Load-Reminders
  Init-World
}

# CLAWD_PET_SELFTEST=1: each step once, to stderr. Leaves out what takes over the screen or the
# clipboard (the bug game, the outfit maker, Format JSON).
function Run-SelfTest {
  $steps = [ordered]@{
    'menu' = { Build-Menu; $n = 0; $q = [Collections.Queue]::new(@($menu.Items)); while ($q.Count) { $it = $q.Dequeue(); $n++; if ($it -is [Windows.Controls.MenuItem]) { foreach ($c in $it.Items) { $q.Enqueue($c) } } }; "$n items" }
    'reminders' = { (@('in 20m stretch', 'at 15:30 standup', '1h30m call back', 'nonsense') | ForEach-Object { $r = Parse-Reminder $_; if ($r) { "$($r.at.ToString('HH:mm'))=$($r.text)" } else { 'none' } }) -join '; ' }
    'season' = { "season='$(Season-Outfit)' daily='$(Resolve-Outfit 'daily')'" }
    'outfits' = { $was = $S.outfitChoice; foreach ($k in @($OUTFITS.Keys)) { Set-Outfit $k }; Wear-Outfit $was; "$($OUTFITS.Count) outfits" }
    'props' = { foreach ($k in @($PROPS.Keys)) { Show-Prop $k }; Show-Prop ''; "$($PROPS.Count) props" }
    'events' = { Handle-Event ([pscustomobject]@{ kind = 'answer'; data = [pscustomobject]@{ text = 'selftest answer' } }); Handle-Event ([pscustomobject]@{ kind = 'celebrate'; data = [pscustomobject]@{ secs = 75 } }); 'ok' }
    'pomodoro' = { Toggle-Pomodoro; $p = $POMO.phase; Toggle-Pomodoro; "started '$p', now '$($POMO.phase)'" }
    'ball' = { Throw-Ball; 'thrown' }
    'perch' = { "find=$([bool](Find-Perch)) fullscreen=$(Is-FullscreenApp)" }
    'hide' = { Hide-For 1; $h = $root.Visibility; Show-Clawd; "hidden=$h shown=$($root.Visibility)" }
    'settings' = { Apply-Settings; "scale=$($WORLD.k) quiet=$(Is-Quiet)" }
    'calendar' = { "$(@(Read-Calendar).Count) meetings today" }
    'stats' = { Summary-Text (Write-Stats (Today-Key)) }
    'game' = { "level $(Level-Of $GAME.xp), unlock(dragon)=$(Outfit-Unlock 'dragon')" }
    'tag' = { Start-Tag; 'running' }
    'screens' = {
      Update-Bounds
      $all = ($S.screens | ForEach-Object { '{0:N0}..{1:N0}' -f $_.l, $_.r }) -join ' | '
      $span = '{0:N0}..{1:N0}' -f $S.left, $S.right
      # Lost far off every screen: pulled back in.
      $S.x = -99999; $S.y = 99999; $S.air = $false
      Pick-Screen; Keep-OnScreen
      $back = ($S.x -ge $S.left -and $S.x -le $S.right -and $S.y -le $S.floor)
      Handle-Event ([pscustomobject]@{ kind = 'show' })
      "screens [$all] walls $span, rescued=$back, shown=$($root.Visibility)"
    }
    'hub' = {
      Open-Hub; $n = 0
      $HUBUI.shell.BeginAnimation([Windows.UIElement]::OpacityProperty, $null)
      # A picture of each tab, next to the state file, to eyeball the look.
      foreach ($k in @($HUB_TABS.Keys)) {
        $HUBUI.tabs.Children | Where-Object { $_.Tag -eq $k } | ForEach-Object { $_.IsChecked = $true }
        $n += $HUBUI.body.Children.Count
        Refresh-HubLive
        $HUBUI.win.UpdateLayout()
        $sh = $HUBUI.shell
        $bmp = [Windows.Media.Imaging.RenderTargetBitmap]::new([int]$sh.ActualWidth + 40, [int]$sh.ActualHeight + 40, 96, 96, [Windows.Media.PixelFormats]::Pbgra32)
        $bmp.Render($sh)
        $png = [Windows.Media.Imaging.PngBitmapEncoder]::new()
        $png.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bmp))
        $fs = [IO.File]::Create((Join-Path $petDir "hub-$k.png")); $png.Save($fs); $fs.Close()
      }
      $txt = $HUBUI.sub.Text; Hub-Close
      "$n cards, '$txt', closed=$($null -eq $HUBUI.win)"
    }
  }
  foreach ($name in $steps.Keys) {
    try { [Console]::Error.WriteLine("clawd-pet: selftest $name : $(& $steps[$name])") }
    catch { [Console]::Error.WriteLine("clawd-pet: selftest $name FAILED: $($_.Exception.Message) at $($_.InvocationInfo.ScriptName | Split-Path -Leaf):$($_.InvocationInfo.ScriptLineNumber)") }
  }
}

function Save-Features {
  Save-SysDay
  [void](Write-Stats (Today-Key))
  Save-Game
}
