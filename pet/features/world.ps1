# --------------------------------------------------------------- the world --
# Clawd in the rest of the desktop: sitting on windows, the seasons and the weather, a ball to
# chase, keeping out of the way of fullscreen apps, size and opacity, start with Windows.

# Holiday and unlockable outfits, beside the everyday ones.
$OUTFITS['pumpkin'] = @{ label = 'Pumpkin'; group = 'Seasonal'; seasonOnly = $true; front = @(
  @(3, -1.4, 10, 1.5, '#E67E22', 0.6), @(7.4, -2.1, 1.2, 0.8, '#2E7D32'), @(8.6, -2.0, 1.4, 0.4, '#43A047', 0.2),
  @(5, 2.3, 1.2, 0.6, '#1E1E24'), @(9.8, 2.3, 1.2, 0.6, '#1E1E24'), @(6.2, 3.0, 3.6, 0.5, '#1E1E24')
) }
$OUTFITS['ghost'] = @{ label = 'Ghost'; group = 'Seasonal'; seasonOnly = $true; arms = '#F4FAFF'; front = @(
  @(1.2, -1.0, 13.6, 5.0, '#F4FAFF', 1.4), @(4, 0.8, 1.2, 1.3, '#1E1E24', 0.5), @(10.8, 0.8, 1.2, 1.3, '#1E1E24', 0.5),
  @(7.2, 2.3, 1.6, 1.0, '#1E1E24', 0.6)
) }
$OUTFITS['cny'] = @{ label = 'Lunar New Year'; group = 'Seasonal'; seasonOnly = $true; arms = '#C8343F'; front = @(
  @(2.5, -0.9, 11, 1.0, '#C8343F', 0.4), @(7.3, -1.5, 1.4, 0.7, '#F2C230', 0.3),
  @(2, 2.2, 12, 1.8, '#C8343F'), @(7, 2.4, 2, 1.3, '#F2C230', 1), @(7.6, 2.8, 0.8, 0.5, '#C8343F')
) }
$OUTFITS['songkok'] = @{ label = 'Songkok (Hari Raya)'; group = 'Seasonal'; seasonOnly = $true; front = @(
  @(3, -1.3, 10, 1.4, '#1E1E24', 0.15), @(3, -0.1, 10, 0.2, '#3A3A44'), @(2, 2.2, 12, 1.8, '#2E9E6B'), @(7.6, 2.2, 0.8, 1.8, '#F2C230')
) }
$OUTFITS['deepavali'] = @{ label = 'Marigold garland (Deepavali)'; group = 'Seasonal'; seasonOnly = $true; front = @(
  @(2.5, 2.0, 1.6, 0.9, '#F39C12', 0.45), @(4.3, 2.3, 1.6, 0.9, '#F7DC6F', 0.45), @(6.1, 2.5, 1.6, 0.9, '#F39C12', 0.45),
  @(7.9, 2.5, 1.6, 0.9, '#F7DC6F', 0.45), @(9.7, 2.3, 1.6, 0.9, '#F39C12', 0.45), @(11.5, 2.0, 1.6, 0.9, '#F7DC6F', 0.45),
  @(7.5, -1.6, 1, 1.2, '#F39C12', 0.5), @(7.7, -1.2, 0.6, 0.6, '#FDE74C', 0.3), @(6.6, -0.5, 2.8, 0.5, '#B9770E', 0.2)
) }
$OUTFITS['chef'] = @{ label = 'Chef''s hat'; group = 'Hats'; front = @(
  @(4, -0.4, 8, 0.5, '#FFFFFF'), @(3.5, -2.2, 9, 1.9, '#FFFFFF', 0.8), @(4, -0.45, 8, 0.12, '#DDDDDD')
) }
$OUTFITS['graduate'] = @{ label = 'Graduation cap'; group = 'Hats'; front = @(
  @(2, -1.2, 12, 0.5, '#1E1E24'), @(4.5, -0.7, 7, 0.7, '#1E1E24'), @(12.6, -1.0, 0.3, 1.4, '#F2C230'), @(12.4, 0.3, 0.7, 0.4, '#F2C230')
) }
$OUTFITS['knight'] = @{ label = 'Knight'; group = 'Costumes'; arms = '#9AA3AD'; front = @(
  @(1.6, -1.0, 12.8, 2.6, '#9AA3AD', 0.5), @(3, 0.9, 10, 0.35, '#1E1E24'), @(7, -2.2, 2, 1.3, '#C8343F', 0.5), @(7.7, -0.9, 0.6, 1.6, '#7F8790')
) }
$OUTFITS['halo'] = @{ label = 'Halo'; group = 'Hats'; front = , @(4, -1.8, 8, 0.8, 'ring:#F2C230', 0.4) }
$OUTFITS['dragon'] = @{ label = 'Dragon'; group = 'Costumes'; arms = '#2E9E6B'
  back = @(@(-1.5, -0.2, 4, 2.4, '#2E9E6B', 0.6), @(13.5, -0.2, 4, 2.4, '#2E9E6B', 0.6))
  front = @(@(2, -0.7, 12, 0.8, '#2E9E6B'), @(4, -1.3, 1, 0.6, '#F2C230'), @(7.5, -1.5, 1, 0.8, '#F2C230'), @(11, -1.3, 1, 0.6, '#F2C230'), @(5, 2.6, 6, 1.2, '#A9DFBF', 0.4))
}
$OUTFIT_GROUPS = @($OUTFIT_GROUPS) + @('Seasonal')

# Holidays, by date: [from, to] inclusive, as MM-dd for fixed ones and yyyy-MM-dd for the moving ones.
$SEASONS = @(
  @{ outfits = @('pumpkin', 'ghost', 'witch'); from = '10-24'; to = '10-31' }
  @{ outfits = @('santa'); from = '12-18'; to = '12-26' }
  @{ outfits = @('party'); from = '12-31'; to = '12-31' }
  @{ outfits = @('party'); from = '01-01'; to = '01-01' }
  @{ outfits = @('cny'); from = '2026-02-15'; to = '2026-02-22' }
  @{ outfits = @('cny'); from = '2027-02-04'; to = '2027-02-11' }
  @{ outfits = @('cny'); from = '2028-01-24'; to = '2028-01-31' }
  @{ outfits = @('songkok'); from = '2026-03-19'; to = '2026-03-23' }
  @{ outfits = @('songkok'); from = '2027-03-09'; to = '2027-03-13' }
  @{ outfits = @('songkok'); from = '2028-02-26'; to = '2028-03-01' }
  @{ outfits = @('deepavali'); from = '2026-11-07'; to = '2026-11-10' }
  @{ outfits = @('deepavali'); from = '2027-10-28'; to = '2027-10-31' }
  @{ outfits = @('deepavali'); from = '2028-10-16'; to = '2028-10-19' }
)

function Season-Outfit {
  if (-not $SET.seasonal) { return '' }
  $md = Get-Date -Format 'MM-dd'; $ymd = Get-Date -Format 'yyyy-MM-dd'
  foreach ($hol in $SEASONS) {
    $d = $md; if ($hol.from.Length -gt 5) { $d = $ymd }
    if ($d -ge $hol.from -and $d -le $hol.to) {
      return $hol.outfits[[int](Get-Date -Format 'yyyyMMdd') % $hol.outfits.Count]
    }
  }
  return ''
}

$WORLD = @{ since = 0.0; weatherKind = ''; perch = $null; perchUntil = 0.0; ball = $null; greetedDay = ''; allowFull = [IntPtr]::Zero }

# -------------------------------------------------------------- perching ------

$SKIP_CLASSES = @('Progman', 'WorkerW', 'Shell_TrayWnd', 'Shell_SecondaryTrayWnd', 'Windows.UI.Core.CoreWindow', 'NotifyIconOverflowWindow')

function Window-Class([IntPtr]$hwnd) {
  $sb = New-Object Text.StringBuilder 128
  [void][ClawdPet.Native]::GetClassName($hwnd, $sb, 128)
  return $sb.ToString()
}

# The window in front, as a perch: visible, not maximised, not the desktop or taskbar.
function Find-Perch {
  $hwnd = [ClawdPet.Native]::GetForegroundWindow()
  if ($hwnd -eq [IntPtr]::Zero -or -not [ClawdPet.Native]::IsWindowVisible($hwnd) -or [ClawdPet.Native]::IsZoomed($hwnd)) { return $null }
  if ($SKIP_CLASSES -contains (Window-Class $hwnd)) { return $null }
  $r = New-Object ClawdPet.Native+RECT
  if (-not [ClawdPet.Native]::GetWindowRect($hwnd, [ref]$r)) { return $null }
  $sc = $S.scale
  $left = $r.Left / $sc + $ART_W / 2; $right = $r.Right / $sc - $ART_W / 2; $top = $r.Top / $sc
  if ($right - $left -lt 60 -or $top -lt $S.top + 40 -or $top -gt $S.floor - 80) { return $null }
  return @{ hwnd = $hwnd; left = $left; right = $right; top = $top; rLeft = $r.Left; rTop = $r.Top }
}

function Start-Perch {
  $p = Find-Perch
  if (-not $p) { return $false }
  foreach ($i in 1..3) { Float '✦' $ORANGE 14 0.9 }
  $p.offset = [Math]::Max($p.left, [Math]::Min($p.right, $S.x)) - $p.left
  $WORLD.perch = $p
  $WORLD.perchUntil = $clock.Elapsed.TotalSeconds + 25 + $rand.Next(35)
  $S.x = $p.left + $p.offset; $S.y = $p.top; $S.air = $false; $S.vx = 0; $S.vy = 0
  Start-Action 'sit' 6
  Say 'Nice view up here! 🪟' 2.5
  return $true
}

function End-Perch([bool]$jump = $true) {
  $WORLD.perch = $null
  $S.air = $true
  if ($jump) { $S.vy = -250; $S.vx = $S.face * 60 }
}

# Rides along on the window; falls off when it closes, minimises, maximises or Clawd is grabbed.
# Always $false: the ground step still runs Clawd's actions up there.
function Step-Perch([double]$dt) {
  $p = $WORLD.perch
  if (-not $p) { return $false }
  if ($S.air -or $S.sky -or $S.dragging) { $WORLD.perch = $null; return $false }
  $r = New-Object ClawdPet.Native+RECT
  $ok = [ClawdPet.Native]::IsWindowVisible($p.hwnd) -and -not [ClawdPet.Native]::IsZoomed($p.hwnd) -and [ClawdPet.Native]::GetWindowRect($p.hwnd, [ref]$r)
  if (-not $ok -or $r.Right - $r.Left -lt 50) { End-Perch $false; Say 'Whoa!' 1.5; return $false }
  $sc = $S.scale
  $p.left = $r.Left / $sc + $ART_W / 2; $p.right = [Math]::Max($p.left, $r.Right / $sc - $ART_W / 2); $p.top = $r.Top / $sc
  if ($S.action -in @('walk', 'run')) {
    # Walking along the title bar, not off it.
    $p.offset = [Math]::Max(0, [Math]::Min($p.right - $p.left, $S.x - $p.left))
    if ($S.x -le $p.left -or $S.x -ge $p.right) { Start-Action 'look' 1.2 }
  }
  $S.x = $p.left + $p.offset
  $S.y = $p.top
  if ($clock.Elapsed.TotalSeconds -ge $WORLD.perchUntil) { End-Perch; Say 'Wheee!' 1.5 }
  return $false
}

# ---------------------------------------------------------------- the ball ------

function Throw-Ball {
  if ($WORLD.ball) { $WORLD.ball.win.Close(); $WORLD.ball = $null }
  $bw = [Windows.Window]::new()
  $bw.WindowStyle = 'None'; $bw.AllowsTransparency = $true; $bw.Background = [Windows.Media.Brushes]::Transparent
  $bw.Topmost = $true; $bw.ShowInTaskbar = $false; $bw.ShowActivated = $false; $bw.Width = 26; $bw.Height = 26
  $e = [Windows.Shapes.Ellipse]::new(); $e.Width = 24; $e.Height = 24
  $grad = [Windows.Media.RadialGradientBrush]::new()
  $grad.GradientStops.Add([Windows.Media.GradientStop]::new([Windows.Media.Color]::FromRgb(0xFF, 0xE0, 0x6B), 0))
  $grad.GradientStops.Add([Windows.Media.GradientStop]::new([Windows.Media.Color]::FromRgb(0xE8, 0x50, 0x5B), 1))
  $e.Fill = $grad; $e.Stroke = $DARK; $e.StrokeThickness = 1.5
  $bw.Content = $e
  $WORLD.ball = @{ win = $bw; x = $S.x; y = $S.y - 60; vx = $S.face * (300 + $rand.Next(400)); vy = -500.0 - $rand.Next(300); life = 45.0 }
  $bw.Show()
  Say 'Fetch! ⚽' 2
  Start-Chase-Ball
}

function Start-Chase-Ball {
  if (-not $WORLD.ball -or $S.air -or $S.sky) { return }
  $S.target = $WORLD.ball.x
  Start-Action 'run' 8
}

function Step-Ball([double]$dt) {
  $b = $WORLD.ball
  if (-not $b) { return }
  $b.life -= $dt
  if ($b.life -le 0) { $b.win.Close(); $WORLD.ball = $null; return }
  $b.vy += $GRAVITY * $dt
  $b.x += $b.vx * $dt; $b.y += $b.vy * $dt
  if ($b.x -lt $S.left - $ART_W / 2 + 12) { $b.x = $S.left - $ART_W / 2 + 12; $b.vx = -$b.vx * 0.7 }
  if ($b.x -gt $S.right + $ART_W / 2 - 12) { $b.x = $S.right + $ART_W / 2 - 12; $b.vx = -$b.vx * 0.7 }
  if ($b.y -ge $S.floor - 12) {
    $b.y = $S.floor - 12
    if ([Math]::Abs($b.vy) -gt 120) { $b.vy = -$b.vy * 0.6 } else { $b.vy = 0 }
    $b.vx *= 0.985
  }
  $b.win.Left = $b.x - 13; $b.win.Top = $b.y - 13
  # Clawd runs after it, and kicks it when close.
  if ($S.action -eq 'run' -and -not $S.air) { $S.target = $b.x }
  if ([Math]::Abs($b.x - $S.x) -lt 40 -and [Math]::Abs($b.y - ($S.y - 20)) -lt 40 -and -not $S.air) {
    $b.vx = $S.face * (350 + $rand.Next(450)); $b.vy = -450.0 - $rand.Next(400)
    Float '!' $ORANGE 14 0.6
    if ($rand.Next(3) -eq 0) { Hop 380 40 }
  }
}

# ------------------------------------------------------------ hide and seek ------

function Hide-Clawd {
  $root.Visibility = 'Hidden'
  if ($WORLD.ball) { $WORLD.ball.win.Visibility = 'Hidden' }
}

function Show-Clawd {
  $S.hiddenUntil = [DateTime]::MinValue
  if ($S.autoHidden) { return }
  $root.Visibility = 'Visible'
  if ($WORLD.ball) { $WORLD.ball.win.Visibility = 'Visible' }
}

function Hide-For([int]$minutes) {
  $S.hiddenUntil = (Get-Date).AddMinutes($minutes)
  Hide-Clawd
  Send "toast Clawd is hiding for $minutes min. /clawd brings them back sooner."
}

# /clawd: out of hiding, on top, and onto the screen your mouse is on.
function Bring-Clawd {
  # Whatever is in front now may be fullscreen: you asked for Clawd anyway, so it doesn't count.
  $WORLD.allowFull = [ClawdPet.Native]::GetForegroundWindow()
  $S.autoHidden = $false
  Show-Clawd
  Stay-OnTop
  $mine = [Windows.Forms.Screen]::FromPoint([Drawing.Point]::new([int]($S.x * $S.scale), [int](($S.y - 10) * $S.scale)))
  $yours = [Windows.Forms.Screen]::FromPoint([Windows.Forms.Cursor]::Position)
  if ($mine.DeviceName -ne $yours.DeviceName) {
    $WORLD.perch = $null
    $a = $yours.WorkingArea
    $c = Cursor-Dip
    $S.x = [Math]::Max($a.Left / $S.scale + $ART_W, [Math]::Min($a.Right / $S.scale - $ART_W, $c.X))
    $S.y = $a.Top / $S.scale + $ART_H + 20
    $S.vx = 0; $S.vy = 0; $S.sky = $false; $S.air = $true
    Pick-Screen
  }
  Start-Action 'wave' 2
  Say 'Here I am! 👋' 2.5 $true
}

# Back above other always-on-top windows, which can push Clawd under them.
function Stay-OnTop {
  $handle = [Windows.Interop.WindowInteropHelper]::new($win).Handle
  # HWND_TOPMOST; no move, no resize, no focus.
  if ($handle -ne [IntPtr]::Zero) { [void][ClawdPet.Native]::SetWindowPos($handle, [IntPtr]::new(-1), 0, 0, 0, 0, 0x13) }
}

# Something fullscreen in front (a video, slides, a game, a screen share in fullscreen). Not a
# maximised window, which fills the screen too when the taskbar hides itself.
function Is-FullscreenApp {
  $hwnd = [ClawdPet.Native]::GetForegroundWindow()
  if ($hwnd -eq [IntPtr]::Zero) { return $false }
  if ($hwnd -eq $WORLD.allowFull) { return $false }
  $WORLD.allowFull = [IntPtr]::Zero
  if ([ClawdPet.Native]::IsZoomed($hwnd)) { return $false }
  if ($SKIP_CLASSES -contains (Window-Class $hwnd)) { return $false }
  $r = New-Object ClawdPet.Native+RECT
  if (-not [ClawdPet.Native]::GetWindowRect($hwnd, [ref]$r)) { return $false }
  $b = [Windows.Forms.Screen]::FromHandle($hwnd).Bounds
  return ($r.Left -le $b.Left -and $r.Top -le $b.Top -and $r.Right -ge $b.Right -and $r.Bottom -ge $b.Bottom)
}

# ------------------------------------------------------------- the settings ------

$StartupLink = Join-Path ([Environment]::GetFolderPath('Startup')) 'Clawd.lnk'

function Set-StartWithWindows([bool]$on) {
  if (-not $on) { try { [IO.File]::Delete($StartupLink) } catch { }; return }
  $sh = New-Object -ComObject WScript.Shell
  $lnk = $sh.CreateShortcut($StartupLink)
  $lnk.TargetPath = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
  $lnk.Arguments = "-NoProfile -NonInteractive -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File `"$PetScript`" -StateFile `"$StateFile`" -Standalone"
  $lnk.WindowStyle = 7
  $lnk.Save()
}

# Size and see-through, from the settings.
function Apply-Settings {
  $k = [Math]::Max(0.5, [Math]::Min(2.0, [double]$SET.scale))
  $root.LayoutTransform = [Windows.Media.ScaleTransform]::new($k, $k)
  $win.Width = $WIN_W * $k; $win.Height = $WIN_H * $k
  $win.Opacity = [Math]::Max(0.3, [Math]::Min(1.0, [double]$SET.opacity))
  $WORLD.k = $k
}

function Add-SettingsMenu($parent) {
  $m = [Windows.Controls.MenuItem]::new(); $m.Header = 'Settings ⚙'
  [void]$m.Items.Add((Setting-Item 'Focus mode (quiet, no tricks)' 'focus'))
  [void]$m.Items.Add((Setting-Item 'Track my productivity (whole PC)' 'tracking'))
  [void]$m.Items.Add((Setting-Item 'Also record window titles' 'trackTitles'))
  [void]$m.Items.Add((Menu-Item 'Delete today''s tracking data' { Forget-Today }))
  [void]$m.Items.Add([Windows.Controls.Separator]::new())
  [void]$m.Items.Add((Setting-Item 'Sound cues' 'sound'))
  [void]$m.Items.Add((Setting-Item 'Read alerts aloud' 'tts'))
  [void]$m.Items.Add((Setting-Item 'Meeting alerts (Outlook)' 'meetings'))
  [void]$m.Items.Add((Setting-Item 'Weather' 'weather'))
  [void]$m.Items.Add((Setting-Item 'Holiday outfits' 'seasonal'))
  [void]$m.Items.Add((Setting-Item 'Sit on windows' 'perch'))
  [void]$m.Items.Add((Setting-Item 'Hide during fullscreen apps' 'autoHide'))
  $nudgeMenu = [Windows.Controls.MenuItem]::new(); $nudgeMenu.Header = 'Nudges'
  foreach ($n in @(@('Eye breaks (every 20 min)', 'nudgeEyes', 20), @('Water (every hour)', 'nudgeWater', 60), @('Posture (every 45 min)', 'nudgePosture', 45))) {
    $i = Menu-Item $n[0] { param($sender) $on = [double]$SET[$sender.Tag[1]] -gt 0; $v = 0; if (-not $on) { $v = $sender.Tag[2] }; Set-Setting $sender.Tag[1] $v } ([double]$SET[$n[1]] -gt 0)
    $i.Tag = $n
    [void]$nudgeMenu.Items.Add($i)
  }
  [void]$m.Items.Add($nudgeMenu)
  $size = [Windows.Controls.MenuItem]::new(); $size.Header = 'Size'
  foreach ($v in @(0.6, 0.8, 1.0, 1.25, 1.5, 2.0)) {
    $i = Menu-Item "$([int]($v * 100))%" { param($sender) Set-Setting 'scale' $sender.Tag; Apply-Settings } ([double]$SET.scale -eq $v)
    $i.Tag = $v; [void]$size.Items.Add($i)
  }
  [void]$m.Items.Add($size)
  $op = [Windows.Controls.MenuItem]::new(); $op.Header = 'Opacity'
  foreach ($v in @(0.4, 0.6, 0.8, 1.0)) {
    $i = Menu-Item "$([int]($v * 100))%" { param($sender) Set-Setting 'opacity' $sender.Tag; Apply-Settings } ([double]$SET.opacity -eq $v)
    $i.Tag = $v; [void]$op.Items.Add($i)
  }
  [void]$m.Items.Add($op)
  [void]$m.Items.Add([Windows.Controls.Separator]::new())
  [void]$m.Items.Add((Menu-Item 'Start with Windows' { Set-StartWithWindows (-not [IO.File]::Exists($StartupLink)) } ([IO.File]::Exists($StartupLink))))
  [void]$m.Items.Add((Menu-Item 'Open Clawd''s folder' { Start-Process explorer.exe $petDir }))
  [void]$parent.Items.Add($m)
}

# ------------------------------------------------------------ files and idle ------

$win.AllowDrop = $true
$win.Add_DragOver({ param($sender, $e) $e.Effects = 'Copy'; $e.Handled = $true })
$win.Add_Drop({
  param($sender, $e)
  $files = $e.Data.GetData([Windows.DataFormats]::FileDrop)
  if (-not $files) { return }
  $path = [string]@($files)[0]
  Hold-Prop 'read' 12
  Say "Reading $([IO.Path]::GetFileName($path))... 📄" 4 $true
  Send "file $path"
})

# Now and then: sit on a window, or chase the ball if it's out. Up on a window, only calm things.
function Choose-WorldIdle {
  if ($WORLD.perch) {
    $acts = @('sit', 'look', 'wave', 'dance', 'walk')
    $a = $acts[$rand.Next($acts.Count)]
    if ($a -eq 'walk') { $S.target = $WORLD.perch.left + $rand.NextDouble() * ($WORLD.perch.right - $WORLD.perch.left); Start-Action 'walk' 6 }
    else { Start-Action $a (2 + $rand.NextDouble() * 4) }
    return $true
  }
  if ($WORLD.ball -and $rand.Next(100) -lt 70) { Start-Chase-Ball; return $true }
  if ($SET.perch -and $rand.Next(100) -lt 6 -and -not $S.air -and -not $S.sky) {
    if ((Start-Perch) -eq $true) { return $true }
  }
  if ($rand.Next(100) -lt 3) { Start-Action 'sip' 4; Say 'Coffee break ☕' 2; return $true }
  return $false
}

function Tick-World([double]$dt, [double]$now) {
  Step-Ball $dt
  $WORLD.since += $dt
  if ($WORLD.since -lt 1) { return }
  $WORLD.since = 0

  # Hidden for a while, or out of the way of a fullscreen app.
  if ($S.hiddenUntil -gt [DateTime]::MinValue -and (Get-Date) -ge $S.hiddenUntil) { Show-Clawd }
  $full = $SET.autoHide -and (Is-FullscreenApp)
  if ($full -ne $S.autoHidden) {
    $S.autoHidden = $full
    if ($full) { Hide-Clawd } elseif ($S.hiddenUntil -lt (Get-Date)) { Show-Clawd }
  }
  if ($root.Visibility -eq 'Visible') { Stay-OnTop }

  # Good morning, once a day, at the first sign of you.
  $day = Get-Date -Format 'yyyy-MM-dd'
  if ($WORLD.greetedDay -ne $day -and [ClawdPet.Native]::IdleMs() -lt 5000) {
    $WORLD.greetedDay = $day
    $h = (Get-Date).Hour
    $hello = 'Good evening! 🌙'; if ($h -lt 12) { $hello = 'Good morning! ☀️' } elseif ($h -lt 18) { $hello = 'Good afternoon! 🌤️' }
    $season = Season-Outfit
    if ($season) { $hello += " Happy holidays, I dressed up! 🎉" }
    Say $hello 4
  }

  # The weather outside, from the mod.
  $w = $S.weather
  if ($w -and $w.kind -ne $WORLD.weatherKind) {
    $was = $WORLD.weatherKind
    $WORLD.weatherKind = [string]$w.kind
    if ($was) {
      switch ($WORLD.weatherKind) {
        'rain' { Say "It's raining outside ☔ ($([Math]::Round($w.temp))°C)" 4 }
        'storm' { Say 'Thunderstorm! ⛈️ Stay dry.' 4 }
        'clear' { if ($w.isDay) { Say "Sunny out! ☀️ $([Math]::Round($w.temp))°C" 4 } }
      }
    }
  }
  if ($w -and [double]$w.temp -ge 33 -and $rand.Next(90) -eq 0) { Float '💦' $SCREEN 14 1.4; Say 'Phew, it''s hot! 🥵' 2 }
}

function Init-World {
  Apply-Settings
  # Starting hidden-at-boot is not a thing: the setting only says whether the link exists.
  $SET.startWithWindows = [IO.File]::Exists($StartupLink)
  # A plugin update moves this script, so an existing link is pointed at where it is now.
  if ($SET.startWithWindows) { try { Set-StartWithWindows $true } catch { } }
}
