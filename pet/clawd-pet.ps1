<#
  Clawd, the desktop pet. Started at login (-Standalone, from the Startup
  folder) or by the clawd mod, when it lives as long as that Claude session.
  Only one Clawd runs at a time; a second start leaves at once.

  The mod -> pet: state.json (mood, speech, model, context, events, aliveAt).
  The pet -> mod: commands.txt, one command per line ("model sonnet", "compact").
  The pet touches pet.alive every few seconds so the mod knows it is up.
#>
param(
  [Parameter(Mandatory = $true)][string]$StateFile,
  [int]$ParentPid = 0,
  [switch]$Standalone
)

$ErrorActionPreference = 'Stop'

# CLAWD_PET_INSTANCE names a separate instance, so a test run can sit beside the real Clawd.
$mutex = [Threading.Mutex]::new($false, "Local\ClawdDesktopPet$env:CLAWD_PET_INSTANCE")
if (-not $mutex.WaitOne(0)) {
  [Console]::Out.WriteLine('already-running')
  exit 0
}

$petDir = Split-Path -Parent $StateFile
[void][IO.Directory]::CreateDirectory($petDir)
$CommandFile = Join-Path $petDir 'commands.txt'
$AliveFile = Join-Path $petDir 'pet.alive'
# This file, for the Start with Windows link; inside a feature's function $PSCommandPath names the feature.
$PetScript = $PSCommandPath

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms

Add-Type -Namespace ClawdPet -Name Native -MemberDefinition @'
[DllImport("user32.dll")] public static extern int GetWindowLong(System.IntPtr hWnd, int nIndex);
[DllImport("user32.dll")] public static extern int SetWindowLong(System.IntPtr hWnd, int nIndex, int dwNewLong);
[StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
[StructLayout(LayoutKind.Sequential)] public struct LASTINPUTINFO { public uint cbSize; public uint dwTime; }
[DllImport("user32.dll")] public static extern System.IntPtr GetForegroundWindow();
[DllImport("user32.dll")] public static extern bool GetWindowRect(System.IntPtr hWnd, out RECT rect);
[DllImport("user32.dll")] public static extern bool IsZoomed(System.IntPtr hWnd);
[DllImport("user32.dll")] public static extern bool SetWindowPos(System.IntPtr hWnd, System.IntPtr after, int x, int y, int cx, int cy, uint flags);
[DllImport("user32.dll")] public static extern bool IsWindowVisible(System.IntPtr hWnd);
[DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(System.IntPtr hWnd, out uint pid);
[DllImport("user32.dll")] public static extern bool GetLastInputInfo(ref LASTINPUTINFO info);
[DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetWindowText(System.IntPtr hWnd, System.Text.StringBuilder text, int max);
[DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetClassName(System.IntPtr hWnd, System.Text.StringBuilder text, int max);
// Milliseconds since the last key or mouse input anywhere on the machine.
public static uint IdleMs() {
  LASTINPUTINFO info = new LASTINPUTINFO();
  info.cbSize = (uint)Marshal.SizeOf(info);
  if (!GetLastInputInfo(ref info)) { return 0; }
  return (uint)Environment.TickCount - info.dwTime;
}
'@

if ($Standalone) {
  $ParentPid = 0
} elseif ($ParentPid -le 0) {
  $ParentPid = [int](Get-CimInstance Win32_Process -Filter "ProcessId=$PID").ParentProcessId
}

# ---------------------------------------------------------------- the look --

$ORANGE = [Windows.Media.BrushConverter]::new().ConvertFromString('#D97757')
$DARK = [Windows.Media.BrushConverter]::new().ConvertFromString('#2B1D16')
$GREY = [Windows.Media.BrushConverter]::new().ConvertFromString('#5B5F66')
$SCREEN = [Windows.Media.BrushConverter]::new().ConvertFromString('#9FD3FF')

# One pixel of the art, in DIPs: terminal half-blocks are taller than wide.
$PX = 8
$PY = 10
$ART_W = 16 * $PX
$ART_H = 5 * $PY
$WIN_W = 260
$WIN_H = 220
# The sprite's top-left inside the window; its feet sit on the window's bottom edge.
$SPRITE_X = ($WIN_W - $ART_W) / 2
$SPRITE_Y = $WIN_H - $ART_H - 2

function New-Rect([double]$col, [double]$row, [double]$w, [double]$h, $brush) {
  $r = [Windows.Shapes.Rectangle]::new()
  $r.Width = $w * $PX
  $r.Height = $h * $PY
  $r.Fill = $brush
  [Windows.Controls.Canvas]::SetLeft($r, $col * $PX)
  [Windows.Controls.Canvas]::SetTop($r, $row * $PY)
  return $r
}

function Move-Rect($r, [double]$col, [double]$row) {
  [Windows.Controls.Canvas]::SetLeft($r, $col * $PX)
  [Windows.Controls.Canvas]::SetTop($r, $row * $PY)
}

# The body, drawn from the terminal art: ▐▛███▜▌ / ▝▜█████▛▘ / ▘▘ ▝▝
$body = [Windows.Controls.Canvas]::new()
$body.Width = $ART_W
$body.Height = $ART_H
# A near-invisible fill so the whole sprite catches the mouse, not just its pixels.
$grab = [Windows.Shapes.Rectangle]::new()
$grab.Width = $ART_W; $grab.Height = $ART_H
$grab.Fill = [Windows.Media.BrushConverter]::new().ConvertFromString('#01FFFFFF')
[void]$body.Children.Add($grab)

$legs = @(
  (New-Rect 3 4 1 1 $ORANGE), (New-Rect 5 4 1 1 $ORANGE),
  (New-Rect 10 4 1 1 $ORANGE), (New-Rect 12 4 1 1 $ORANGE)
)
foreach ($l in $legs) { [void]$body.Children.Add($l) }
$torso = New-Rect 2 0 12 4 $ORANGE
[void]$body.Children.Add($torso)
$armL = New-Rect 0 2 2 1 $ORANGE
$armR = New-Rect 14 2 2 1 $ORANGE
[void]$body.Children.Add($armL)
[void]$body.Children.Add($armR)
$eyeL = New-Rect 4 1 1 1 $DARK
$eyeR = New-Rect 11 1 1 1 $DARK
[void]$body.Children.Add($eyeL)
[void]$body.Children.Add($eyeR)
# What Clawd wears in front: hats, clothes, glasses. Under the laptop, over the eyes.
$wearFront = [Windows.Controls.Canvas]::new()
[void]$body.Children.Add($wearFront)

$laptop = [Windows.Controls.Canvas]::new()
$lapBase = New-Rect 3 3.4 10 0.6 $GREY
$lapLid = New-Rect 4 2.2 8 1.2 $GREY
$lapGlow = New-Rect 4.5 2.4 7 0.8 $SCREEN
[void]$laptop.Children.Add($lapLid)
[void]$laptop.Children.Add($lapGlow)
[void]$laptop.Children.Add($lapBase)
$laptop.Visibility = 'Collapsed'
[void]$body.Children.Add($laptop)

# Wings for flying, hinged at the body's sides.
$WING = [Windows.Media.BrushConverter]::new().ConvertFromString('#F4FAFF')
$WING_EDGE = [Windows.Media.BrushConverter]::new().ConvertFromString('#9FD3FF')
function New-Wing([double]$col, [double]$hingeX) {
  $w = New-Rect $col 0.4 3 1.1 $WING
  $w.Stroke = $WING_EDGE; $w.StrokeThickness = 1.5
  $w.RadiusX = 4; $w.RadiusY = 4
  $w.RenderTransformOrigin = [Windows.Point]::new($hingeX, 0.5)
  $w.RenderTransform = [Windows.Media.RotateTransform]::new(0)
  $w.Visibility = 'Collapsed'
  return $w
}
$wingL = New-Wing -2.6 1
$wingR = New-Wing 15.6 0
[void]$body.Children.Insert(1, $wingL)
[void]$body.Children.Insert(1, $wingR)

# Jetpack flames under the feet.
$FLAME_HOT = [Windows.Media.BrushConverter]::new().ConvertFromString('#FFD45C')
$FLAME = [Windows.Media.BrushConverter]::new().ConvertFromString('#FF8A3D')
$flames = @((New-Rect 4 5 2 1 $FLAME), (New-Rect 10 5 2 1 $FLAME))
foreach ($f in $flames) { $f.Visibility = 'Collapsed'; [void]$body.Children.Insert(1, $f) }

# What Clawd wears behind: capes and backpacks, under everything else.
$wearBack = [Windows.Controls.Canvas]::new()
[void]$body.Children.Insert(1, $wearBack)

$flip = [Windows.Media.ScaleTransform]::new(1, 1)
$squash = [Windows.Media.ScaleTransform]::new(1, 1)
$turn = [Windows.Media.RotateTransform]::new(0)
$nudge = [Windows.Media.TranslateTransform]::new(0, 0)
$xf = [Windows.Media.TransformGroup]::new()
$xf.Children.Add($flip); $xf.Children.Add($squash); $xf.Children.Add($turn); $xf.Children.Add($nudge)
$body.RenderTransform = $xf
$body.RenderTransformOrigin = [Windows.Point]::new(0.5, 1)

# The speech bubble, above the sprite.
$bubbleText = [Windows.Controls.TextBlock]::new()
$bubbleText.FontSize = 12
$bubbleText.FontFamily = 'Segoe UI'
$bubbleText.Foreground = $DARK
$bubbleText.TextWrapping = 'Wrap'
$bubbleText.MaxWidth = 200
$bubble = [Windows.Controls.Border]::new()
$bubble.Background = [Windows.Media.Brushes]::White
$bubble.BorderBrush = $ORANGE
$bubble.BorderThickness = 2
$bubble.CornerRadius = 9
$bubble.Padding = '8,4,8,4'
$bubble.Child = $bubbleText
$bubble.HorizontalAlignment = 'Center'
$bubble.VerticalAlignment = 'Bottom'
$bubble.Margin = "0,0,0,$($ART_H + 10)"
$bubble.Visibility = 'Collapsed'
$bubble.IsHitTestVisible = $false

# Hearts, Z's, notes and sparkles float on this layer.
$fx = [Windows.Controls.Canvas]::new()
$fx.IsHitTestVisible = $false

# The parachute: a striped canopy over the sprite, its lines down to the arms.
$CHUTE_W = 150
$chute = [Windows.Controls.Canvas]::new()
$canopy = [Windows.Shapes.Path]::new()
$canopy.Data = [Windows.Media.Geometry]::Parse("M 0,44 Q $($CHUTE_W / 2),-34 $CHUTE_W,44 Q $($CHUTE_W * 0.75),34 $($CHUTE_W / 2),44 Q $($CHUTE_W / 4),34 0,44 Z")
$stripes = [Windows.Media.LinearGradientBrush]::new()
$stripes.StartPoint = [Windows.Point]::new(0, 0); $stripes.EndPoint = [Windows.Point]::new(1, 0)
$RED = [Windows.Media.Color]::FromRgb(0xE8, 0x50, 0x5B)
$CREAM = [Windows.Media.Color]::FromRgb(0xFF, 0xF4, 0xE6)
foreach ($i in 0..4) {
  $c = $RED; if ($i % 2 -eq 1) { $c = $CREAM }
  $stripes.GradientStops.Add([Windows.Media.GradientStop]::new($c, $i / 5))
  $stripes.GradientStops.Add([Windows.Media.GradientStop]::new($c, ($i + 1) / 5))
}
$canopy.Fill = $stripes
$canopy.Stroke = $DARK; $canopy.StrokeThickness = 1.5
$chuteTop = $SPRITE_Y - 96
$armY = 96 + 2.5 * $PY
$armInChute = $SPRITE_X - ($WIN_W - $CHUTE_W) / 2
foreach ($pair in @(@(6, ($armInChute + 6)), @(($CHUTE_W - 6), ($armInChute + $ART_W - 6)))) {
  $line = [Windows.Shapes.Line]::new()
  $line.X1 = $pair[0]; $line.Y1 = 44; $line.X2 = $pair[1]; $line.Y2 = $armY
  $line.Stroke = $DARK; $line.StrokeThickness = 1
  [void]$chute.Children.Add($line)
}
[void]$chute.Children.Add($canopy)
$chuteSway = [Windows.Media.RotateTransform]::new(0, $CHUTE_W / 2, $armY)
$chute.RenderTransform = $chuteSway
$chute.Visibility = 'Collapsed'
[Windows.Controls.Canvas]::SetLeft($chute, ($WIN_W - $CHUTE_W) / 2)
[Windows.Controls.Canvas]::SetTop($chute, $chuteTop)

# The balloon, on a string down to the top of the head.
$balloon = [Windows.Controls.Canvas]::new()
$string = [Windows.Shapes.Line]::new()
$string.X1 = 19; $string.Y1 = 46; $string.X2 = -14; $string.Y2 = 120
$string.Stroke = $DARK; $string.StrokeThickness = 1
$ball = [Windows.Shapes.Ellipse]::new()
$ball.Width = 38; $ball.Height = 46
$ball.Fill = [Windows.Media.SolidColorBrush]::new($RED)
$ball.Stroke = $DARK; $ball.StrokeThickness = 1.5
$shine = [Windows.Shapes.Ellipse]::new()
$shine.Width = 9; $shine.Height = 13; $shine.Fill = [Windows.Media.Brushes]::White; $shine.Opacity = 0.6
[Windows.Controls.Canvas]::SetLeft($shine, 8); [Windows.Controls.Canvas]::SetTop($shine, 7)
[void]$balloon.Children.Add($string)
[void]$balloon.Children.Add($ball)
[void]$balloon.Children.Add($shine)
$balloonBob = [Windows.Media.RotateTransform]::new(0, -14, 120)
$balloon.RenderTransform = $balloonBob
$balloon.Visibility = 'Collapsed'
[Windows.Controls.Canvas]::SetLeft($balloon, $WIN_W / 2 + 14)
[Windows.Controls.Canvas]::SetTop($balloon, $SPRITE_Y - 120)

# ------------------------------------------------------------ the outfits --

# Each piece is @(col, row, w, h, colour[, radius]) on the sprite's grid; negative rows sit
# above the head. "ring:#hex" is a hollow frame, "glass:#hex" a see-through pane.
$OUTFITS = [ordered]@{
  tophat = @{ label = 'Top hat'; group = 'Hats'; front = @(
    @(3, -0.35, 10, 0.45, '#1E1E24'), @(5, -2.6, 6, 2.3, '#1E1E24'), @(5, -0.85, 6, 0.45, '#C8343F')
  ) }
  party = @{ label = 'Party hat'; group = 'Hats'; front = @(
    @(4.5, -0.5, 7, 0.5, '#5BC0EB'), @(5.5, -1.0, 5, 0.5, '#FDE74C'), @(6.5, -1.5, 3, 0.5, '#E8505B'),
    @(7.3, -2.0, 1.4, 0.5, '#5BC0EB'), @(7.2, -2.6, 1.6, 0.6, '#FFFFFF', 0.4)
  ) }
  beanie = @{ label = 'Beanie'; group = 'Hats'; front = @(
    @(2, -1.1, 12, 1.2, '#3A6EA5', 0.4), @(2, -0.2, 12, 0.55, '#2A5080'), @(7, -1.7, 2, 0.7, '#E8505B', 0.4)
  ) }
  crown = @{ label = 'Crown'; group = 'Hats'; front = @(
    @(4, -0.7, 8, 0.7, '#F2C230'), @(4, -1.4, 1.2, 0.7, '#F2C230'), @(7.4, -1.6, 1.2, 0.9, '#F2C230'),
    @(10.8, -1.4, 1.2, 0.7, '#F2C230'), @(7.6, -0.55, 0.8, 0.4, '#E8505B'),
    @(5, -0.5, 0.6, 0.3, '#5BC0EB'), @(10.4, -0.5, 0.6, 0.3, '#5BC0EB')
  ) }
  wizard = @{ label = 'Wizard hat'; group = 'Hats'; front = @(
    @(2.5, -0.4, 11, 0.5, '#4B3A8C'), @(4.5, -1.2, 7, 0.8, '#4B3A8C'), @(5.5, -2.0, 5, 0.8, '#4B3A8C'),
    @(6.5, -2.8, 3, 0.8, '#4B3A8C'), @(7.5, -3.5, 2, 0.7, '#4B3A8C'), @(8.6, -3.9, 1.4, 0.5, '#4B3A8C'),
    @(6.2, -1.9, 1, 0.6, '#FDE74C'), @(8.8, -1.0, 0.8, 0.5, '#FDE74C')
  ) }
  hoodie = @{ label = 'Hoodie'; group = 'Clothes'; arms = '#56606E'; front = @(
    @(2, 2.2, 12, 1.8, '#56606E'), @(5.5, 3.1, 5, 0.7, '#474F5B'),
    @(6.2, 2.2, 0.4, 0.7, '#F4FAFF'), @(9.4, 2.2, 0.4, 0.7, '#F4FAFF')
  ) }
  bowtie = @{ label = 'Bow tie'; group = 'Clothes'; front = @(
    @(6, 2.25, 1.6, 0.8, '#C8343F'), @(8.4, 2.25, 1.6, 0.8, '#C8343F'), @(7.5, 2.4, 1, 0.5, '#8E1F28')
  ) }
  scarf = @{ label = 'Scarf'; group = 'Clothes'; front = @(
    @(2, 1.9, 12, 0.65, '#2E9E6B'), @(10, 2.5, 1.6, 1.4, '#2E9E6B'), @(10, 3.0, 1.6, 0.25, '#F4FAFF'),
    @(4, 1.9, 0.6, 0.65, '#F4FAFF'), @(7.5, 1.9, 0.6, 0.65, '#F4FAFF')
  ) }
  cape = @{ label = 'Superhero cape'; group = 'Clothes'
    back = , @(0.8, 0.8, 14.4, 3.9, '#C8343F')
    front = @(@(2, 0.85, 12, 0.3, '#8E1F28'), @(7.4, 0.75, 1.2, 0.5, '#F2C230'))
  }
  shades = @{ label = 'Sunglasses'; group = 'Face gear'; front = @(
    @(3.3, 0.55, 2.4, 1.5, '#111111'), @(10.3, 0.55, 2.4, 1.5, '#111111'), @(5.7, 0.9, 4.6, 0.3, '#111111'),
    @(3.6, 0.75, 0.6, 0.3, '#9FD3FF'), @(10.6, 0.75, 0.6, 0.3, '#9FD3FF')
  ) }
  nerd = @{ label = 'Nerd glasses'; group = 'Face gear'; front = @(
    @(3.1, 0.5, 2.8, 1.7, 'ring:#1E1E24'), @(10.1, 0.5, 2.8, 1.7, 'ring:#1E1E24'), @(5.9, 1.1, 4.2, 0.25, '#1E1E24')
  ) }
  mustache = @{ label = 'Mustache'; group = 'Face gear'; front = @(
    @(5.5, 2.0, 5, 0.55, '#3B2618'), @(4.6, 1.75, 1.2, 0.5, '#3B2618'), @(10.2, 1.75, 1.2, 0.5, '#3B2618')
  ) }
  pirate = @{ label = 'Pirate'; group = 'Costumes'; front = @(
    @(1.5, -0.5, 13, 0.6, '#1E1E24'), @(3.5, -1.4, 9, 1.0, '#1E1E24'), @(1.5, -0.5, 13, 0.15, '#F2C230'),
    @(7.4, -1.15, 1.2, 0.6, '#F4FAFF'), @(2, 0.35, 12, 0.25, '#111111'), @(10.4, 0.6, 2.2, 1.6, '#111111')
  ) }
  ninja = @{ label = 'Ninja'; group = 'Costumes'; arms = '#1E1E24'
    back = @(@(-1.2, 0.3, 3.2, 0.3, '#1E1E24'), @(-1.0, 0.7, 2.4, 0.3, '#1E1E24'))
    front = @(@(2, 0.15, 12, 0.5, '#1E1E24'), @(7, 0.25, 2, 0.3, '#9AA3AD'), @(2, 1.85, 12, 1.0, '#1E1E24'))
  }
  astronaut = @{ label = 'Astronaut'; group = 'Costumes'; arms = '#F4FAFF'
    back = , @(1, 0.4, 14, 3.2, '#C9CED6', 0.6)
    front = @(
      @(1.2, -1.2, 13.6, 3.6, 'glass:#9FD3FF', 1.5), @(7.7, -1.9, 0.4, 0.7, '#9AA3AD'), @(7.5, -2.2, 0.8, 0.4, '#E8505B', 0.2),
      @(5.5, 2.6, 5, 0.9, '#F4FAFF'), @(6, 2.85, 0.7, 0.4, '#E8505B'), @(7.4, 2.85, 0.7, 0.4, '#5BC0EB')
    )
  }
  santa = @{ label = 'Santa'; group = 'Costumes'; arms = '#C8343F'; front = @(
    @(2, -0.9, 12, 1.0, '#C8343F'), @(4, -1.7, 7, 0.8, '#C8343F'), @(9, -2.1, 3.5, 0.6, '#C8343F'),
    @(12.3, -2.3, 1.4, 0.9, '#FFFFFF', 0.4), @(1.6, -0.2, 12.8, 0.6, '#FFFFFF', 0.2),
    @(3, 2.0, 10, 1.3, '#FFFFFF'), @(4.5, 3.3, 7, 0.5, '#FFFFFF'),
    @(2, 3.6, 12, 0.4, '#1E1E24'), @(7.3, 3.55, 1.4, 0.5, '#F2C230')
  ) }
  witch = @{ label = 'Witch'; group = 'Costumes'
    back = , @(0.8, 0.8, 14.4, 3.9, '#6C3483')
    front = @(
      @(1.5, -0.35, 13, 0.45, '#2A2238'), @(5, -1.3, 6, 1.0, '#2A2238'), @(6, -2.2, 4, 0.9, '#2A2238'),
      @(7, -3.0, 2, 0.8, '#2A2238'), @(8.4, -3.4, 2, 0.5, '#2A2238'),
      @(5, -0.75, 6, 0.35, '#8E44AD'), @(7.5, -0.8, 1, 0.45, '#F2C230')
    )
  }
}
$OUTFIT_GROUPS = @('Hats', 'Clothes', 'Face gear', 'Costumes')
$OutfitFile = Join-Path $petDir 'outfit.txt'

function Brush([string]$hex) { return [Windows.Media.BrushConverter]::new().ConvertFromString($hex) }

function New-Piece($p) {
  $spec = [string]$p[4]
  $r = New-Rect $p[0] $p[1] $p[2] $p[3] $null
  if ($spec -like 'ring:*') {
    $r.Stroke = Brush $spec.Substring(5); $r.StrokeThickness = 2
  } elseif ($spec -like 'glass:*') {
    $edge = Brush $spec.Substring(6)
    $pane = $edge.Clone(); $pane.Opacity = 0.25
    $r.Fill = $pane; $r.Stroke = $edge; $r.StrokeThickness = 2
  } else { $r.Fill = Brush $spec }
  if ($p.Count -gt 5) { $r.RadiusX = $p[5] * $PX; $r.RadiusY = $p[5] * $PY }
  return $r
}

# Dresses Clawd in one outfit (or none, for an unknown key).
function Set-Outfit([string]$key) {
  $wearFront.Children.Clear(); $wearBack.Children.Clear()
  $S.outfit = 'none'
  $arms = $ORANGE; $top = 0.0
  if ($key -and $OUTFITS.Contains($key)) {
    $S.outfit = $key
    $o = $OUTFITS[$key]
    foreach ($p in $o.front) { [void]$wearFront.Children.Add((New-Piece $p)); $top = [Math]::Min($top, $p[1]) }
    foreach ($p in $o.back) { [void]$wearBack.Children.Add((New-Piece $p)); $top = [Math]::Min($top, $p[1]) }
    if ($o.arms) { $arms = Brush $o.arms }
  }
  $armL.Fill = $arms; $armR.Fill = $arms
  # The bubble clears the hat.
  $bubble.Margin = "0,0,0,$($ART_H + 10 - $top * $PY)"
}

# "daily" is the same random pick all day, restarts or not.
# A holiday picks its own costume; otherwise only outfits Clawd has unlocked.
function Resolve-Outfit([string]$choice) {
  if ($choice -ne 'daily') { return $choice }
  $season = Season-Outfit
  if ($season) { return $season }
  $keys = @($OUTFITS.Keys | Where-Object { (Outfit-Unlock $_) -eq 0 -and -not $OUTFITS[$_].seasonOnly })
  return $keys[[Random]::new([int](Get-Date -Format 'yyyyMMdd')).Next($keys.Count)]
}

function Read-OutfitChoice {
  $c = ''
  try { $c = ([IO.File]::ReadAllText($OutfitFile)).Trim() } catch { }
  if ($c -ne 'none' -and -not $OUTFITS.Contains($c)) { $c = 'daily' }
  return $c
}

function Wear-Outfit([string]$choice, [bool]$save = $false) {
  $S.outfitChoice = $choice
  $S.outfitDay = Get-Date -Format 'yyyyMMdd'
  Set-Outfit (Resolve-Outfit $choice)
  if ($save) { try { [IO.File]::WriteAllText($OutfitFile, $choice) } catch { } }
}

$stage = [Windows.Controls.Canvas]::new()
$stage.Width = $WIN_W; $stage.Height = $WIN_H
[void]$stage.Children.Add($chute)
[void]$stage.Children.Add($balloon)
[Windows.Controls.Canvas]::SetLeft($body, $SPRITE_X)
[Windows.Controls.Canvas]::SetTop($body, $SPRITE_Y)
[void]$stage.Children.Add($body)
[void]$stage.Children.Add($fx)

$root = [Windows.Controls.Grid]::new()
[void]$root.Children.Add($stage)
[void]$root.Children.Add($bubble)

$win = [Windows.Window]::new()
$win.Title = 'Clawd'
$win.Width = $WIN_W; $win.Height = $WIN_H
$win.WindowStyle = 'None'
$win.AllowsTransparency = $true
$win.Background = [Windows.Media.Brushes]::Transparent
$win.Topmost = $true
$win.ShowInTaskbar = $false
$win.ShowActivated = $false
$win.ResizeMode = 'NoResize'
$win.Content = $root

# --------------------------------------------------------------- the state --

$rand = [Random]::new()
$S = @{
  x = 0.0; y = 0.0; vx = 0.0; vy = 0.0; air = $true; face = 1
  action = 'idle'; t = 0.0; dur = 2.0; target = 0.0; climbTo = 0.0
  # Screen bounds of the monitor Clawd is on, in DIPs.
  left = 0.0; right = 0.0; floor = 0.0; top = 0.0; scale = 1.0
  blinkAt = 2.0; blinkFor = 0.0; bubbleFor = 0.0
  pressed = $false; dragging = $false; grabDX = 0.0; grabDY = 0.0
  downX = 0.0; downY = 0.0; lastMX = 0.0; lastMY = 0.0; dragVX = 0.0; dragVY = 0.0
  mood = 'idle'; model = ''; percent = $null; eventId = -1; speech = ''
  stateStamp = [DateTime]::MinValue; sinceState = 0.0; sinceParent = 0.0; sinceBounds = 9.0
  wantClimb = $false
  aliveAt = 0.0; connected = $null; sinceAlive = 9.0
  # Flying under its own steam (wings, jetpack, parachute, balloon): no gravity, its own path.
  sky = $false; phase = ''; tx = 0.0; ty = 0.0; hops = 0; wind = 0.0
  # What Clawd wears, what was picked ("daily", "none" or a key), and the day it was put on.
  outfit = 'none'; outfitChoice = 'daily'; outfitDay = ''; sinceOutfit = 0.0
  # What Claude is using (a prop), how fast you type, and the weather outside, from the mod.
  toolKind = ''; tempo = 0.0; weather = $null
  # Events already acted on, by id: several sessions write the queue, so ids are not in one order.
  seen = [Collections.Generic.HashSet[double]]::new()
  # Quiet unless it matters (focus mode), and away while something is fullscreen or hidden for a while.
  focus = $false; hiddenUntil = [DateTime]::MinValue; autoHidden = $false
}
$SKY_ACTIONS = @('fly', 'jetpack', 'parachute', 'balloon')
$particles = [Collections.ArrayList]::new()

$GRAVITY = 1500.0
$WALK = 55.0
$RUN = 170.0

# An alert speaks even in focus mode; chatter does not.
function Say([string]$text, [double]$seconds = 6, [bool]$alert = $false) {
  if (-not $text) { return }
  if ($S.focus -and -not $alert) { return }
  $bubbleText.Text = $text
  $bubble.Visibility = 'Visible'
  $S.bubbleFor = $seconds
}

function Send([string]$line) {
  try { [IO.File]::AppendAllText($CommandFile, "$line`r`n") } catch { }
}

function Float([string]$glyph, $brush, [double]$size = 16, [double]$life = 1.4) {
  $tb = [Windows.Controls.TextBlock]::new()
  $tb.Text = $glyph
  $tb.FontSize = $size
  $tb.FontWeight = 'Bold'
  $tb.Foreground = $brush
  $x0 = $WIN_W / 2 + $rand.Next(-30, 30)
  $y0 = $SPRITE_Y - 6
  [Windows.Controls.Canvas]::SetLeft($tb, $x0)
  [Windows.Controls.Canvas]::SetTop($tb, $y0)
  [void]$fx.Children.Add($tb)
  [void]$particles.Add(@{ el = $tb; x = $x0; y = $y0; vx = $rand.Next(-15, 15); vy = -45.0; t = 0.0; life = $life })
}

function Start-Action([string]$name, [double]$dur = 0) {
  # Anything but a flight, started mid-air, lets go: Clawd falls and carries on below.
  if ($S.sky -and $SKY_ACTIONS -notcontains $name) {
    $S.sky = $false; $S.air = $true; $S.vx = 0; $S.vy = 0
  }
  $S.action = $name
  $S.t = 0.0
  if ($dur -le 0) { $dur = 2 + $rand.NextDouble() * 3 }
  $S.dur = $dur
}

function Hop([double]$up = 380, [double]$side = 40) {
  $S.vy = -$up
  $S.vx = $S.face * $side
  $S.air = $true
}

# Every screen's working area, in DIPs; refreshed twice a second, so plugging a monitor in or out shows up.
function Update-Bounds {
  $src = [Windows.PresentationSource]::FromVisual($win)
  if ($src) { $S.scale = $src.CompositionTarget.TransformToDevice.M11 }
  $S.screens = @(foreach ($mon in [Windows.Forms.Screen]::AllScreens) {
    $a = $mon.WorkingArea
    @{ l = $a.Left / $S.scale; r = $a.Right / $S.scale; t = $a.Top / $S.scale; b = $a.Bottom / $S.scale }
  })
  Pick-Screen
}

# The screen Clawd is over (or nearest to) gives the walls, the floor and the sky. Clawd stays on
# that one screen; dragging it onto another monitor moves it there.
function Pick-Screen {
  if (-not $S.screens) { return }
  $here = $null; $best = [double]::MaxValue
  foreach ($mon in $S.screens) {
    $dx = [Math]::Max(0, [Math]::Max($mon.l - $S.x, $S.x - $mon.r))
    $dy = [Math]::Max(0, [Math]::Max($mon.t - ($S.y - 10), ($S.y - 10) - $mon.b))
    $d = $dx * 100000 + $dy
    if ($d -lt $best) { $best = $d; $here = $mon }
  }
  $S.left = $here.l + $ART_W / 2
  $S.right = $here.r - $ART_W / 2
  $S.floor = $here.b
  $S.top = $here.t + $ART_H
}

# Never lost: back inside its screen and never below the floor.
function Keep-OnScreen {
  if ($S.dragging -or $WORLD.perch) { return }
  $S.x = [Math]::Max($S.left, [Math]::Min($S.right, $S.x))
  if ($S.air -or $S.sky -or $S.action -in @('climb', 'hang')) { return }
  if ($S.y -gt $S.floor + 2) { $S.y = $S.floor }
  elseif ($S.y -lt $S.floor - 2) { $S.air = $true }
}

function Cursor-Dip {
  $p = [Windows.Forms.Cursor]::Position
  return [Windows.Point]::new($p.X / $S.scale, $p.Y / $S.scale)
}

# Picks what to do next when nothing is going on.
function Choose-Idle {
  # Focus mode: sit still in the corner, no tricks.
  if ($S.focus) {
    if ([Math]::Abs($S.x - $S.right) -gt 4) { $S.target = $S.right; Start-Action 'walk' 30 }
    else { Start-Action 'sit' 10 }
    return
  }
  # Something a feature wants to do now and then: chase the ball, sip coffee, sit on a window.
  if ((Choose-FeatureIdle) -eq $true) { return }
  $roll = $rand.Next(100)
  if ($roll -lt 22) { $S.target = $S.left + $rand.NextDouble() * ($S.right - $S.left); Start-Action 'walk' 12 }
  elseif ($roll -lt 32) { Start-Action 'idle' }
  elseif ($roll -lt 39) { Start-Action 'look' 2.4 }
  elseif ($roll -lt 46) { Start-Action 'sit' (4 + $rand.NextDouble() * 5) }
  elseif ($roll -lt 51) { Hop; Start-Action 'idle' 1 }
  elseif ($roll -lt 55) { Start-Action 'wave' 2 }
  elseif ($roll -lt 59) { Start-Action 'stretch' 1.6 }
  elseif ($roll -lt 63) { Start-Action 'dance' 3.5 }
  elseif ($roll -lt 68) {
    $S.target = $S.left + $rand.NextDouble() * ($S.right - $S.left)
    Start-Action 'run' 6
  }
  elseif ($roll -lt 72) { Start-Chase }
  elseif ($roll -lt 78) { Start-Sky 'fly' }
  elseif ($roll -lt 83) { Start-Sky 'parachute' }
  elseif ($roll -lt 88) { Start-Sky 'balloon' }
  elseif ($roll -lt 92) { Start-Sky 'jetpack' }
  elseif ($roll -lt 96) { Start-Teleport }
  else { Start-Backflip }
}

# Drowsy, not out cold: a short nap now and then, otherwise the usual antics.
function Choose-Sleepy {
  if ($rand.Next(100) -lt 25) { Start-Action 'sleep' (20 + $rand.NextDouble() * 25) }
  else { Choose-Idle }
}

# Somewhere in the sky above the screen Clawd is on.
function Pick-SkyTarget {
  $S.tx = $S.left + $rand.NextDouble() * ($S.right - $S.left)
  $S.ty = $S.top + 80 + $rand.NextDouble() * [Math]::Max(40, $S.floor - $S.top - 260)
}

function Start-Sky([string]$name) {
  Start-Action $name 3600
  $S.sky = $true; $S.air = $false; $S.vx = 0; $S.vy = 0
  $S.phase = 'go'
  switch ($name) {
    'fly' {
      Pick-SkyTarget
      $S.dur = 9 + $rand.NextDouble() * 6
      $lines = @('I believe I can fly!', 'Wings, activate!', 'Up, up and away!')
      Say $lines[$rand.Next($lines.Count)] 2.5
    }
    'jetpack' { $S.hops = 3; Pick-SkyTarget; Say 'Jetpack go! 🚀' 2 }
    'parachute' {
      $S.phase = 'launch'
      $S.tx = [Math]::Max($S.left, [Math]::Min($S.right, $S.x + $S.face * 60))
      $S.ty = $S.top + 110
      Say '3... 2... 1... liftoff!' 2
    }
    'balloon' {
      $S.ty = [Math]::Max($S.top + 120, $S.floor - 260 - $rand.Next(160))
      Say 'Ooh, a balloon!' 2
    }
  }
}

function Start-Teleport {
  foreach ($i in 1..3) { Float '✦' $ORANGE 14 0.9 }
  Say 'Poof!' 1.2
  Start-Action 'teleport' 0.9
}

function Start-Backflip {
  Hop 600 0
  Start-Action 'backflip' 3
}

# Moves toward the sky target at `speed`; true once there.
function Move-Toward([double]$speed, [double]$dt) {
  $dx = $S.tx - $S.x; $dy = $S.ty - $S.y
  $dist = [Math]::Sqrt($dx * $dx + $dy * $dy)
  if ([Math]::Abs($dx) -gt 3) { $S.face = [Math]::Sign($dx) }
  if ($dist -le $speed * $dt) { $S.x = $S.tx; $S.y = $S.ty; return $true }
  $S.x += $dx / $dist * $speed * $dt
  $S.y += $dy / $dist * $speed * $dt
  return $false
}

function Land-Sky {
  $S.sky = $false; $S.air = $false
  $S.y = $S.floor
  Start-Action 'land' 0.3
}

function Step-Sky([double]$dt) {
  switch ($S.action) {
    'fly' {
      if ($S.phase -eq 'go') {
        if (Move-Toward 130 $dt) { Pick-SkyTarget }
        $S.y += [Math]::Sin($S.t * 3) * 25 * $dt
        if ($S.t -ge $S.dur) { $S.phase = 'down'; $S.tx = $S.x + $S.face * 80; $S.ty = $S.floor }
      } elseif (Move-Toward 110 $dt) { Land-Sky }
    }
    'jetpack' {
      if ($S.phase -eq 'go') {
        if (Move-Toward 430 $dt) {
          $S.hops--
          Float '✦' $FLAME_HOT 14 0.8
          if ($S.hops -le 0) { $S.phase = 'down'; $S.tx = $S.x + $S.face * 60; $S.ty = $S.floor }
          else { Pick-SkyTarget }
        }
      } elseif (Move-Toward 170 $dt) { Land-Sky }
    }
    'parachute' {
      if ($S.phase -eq 'launch') {
        if (Move-Toward 540 $dt) {
          $S.phase = 'drift'
          $S.wind = ($rand.NextDouble() - 0.5) * 50
          Float 'POP!' $DARK 15 0.9
          Say 'Wheee~' 2.5
        }
      } else {
        $S.y += 58 * $dt
        $S.x += ($S.wind + [Math]::Sin($S.t * 1.6) * 28) * $dt
        if ($S.y -ge $S.floor) { Land-Sky; Say 'Nailed the landing!' 2 }
      }
    }
    'balloon' {
      $S.y -= 40 * $dt
      $S.x += [Math]::Sin($S.t * 1.2) * 20 * $dt
      if ($S.y -le $S.ty -or $S.t -gt 16) {
        # It pops, and Clawd drops.
        Float 'POP!' ([Windows.Media.SolidColorBrush]::new($RED)) 18 0.9
        Say 'Uh oh...' 1.5
        Start-Action 'idle' 1.5
      }
    }
  }
  $S.x = [Math]::Max($S.left, [Math]::Min($S.right, $S.x))
  if ($S.y -lt $S.top) { $S.y = $S.top }
}

function Start-Chase {
  Float '!' $ORANGE 20 0.9
  Start-Action 'chase' 7
}

# The mood the mod reports picks what Clawd does.
function Apply-Mood([string]$mood, [string]$was) {
  switch ($mood) {
    'working' { Start-Action 'type' 3600 }
    'happy' {
      if ($was -eq 'working' -or $was -eq 'idle') {
        Hop 420 0
        foreach ($i in 1..3) { Float '✦' $ORANGE 14 1.2 }
        Start-Action 'idle' 2
      }
    }
    'worried' { Float '💧' $SCREEN 16 1.6; Start-Action 'shake' 1.4 }
    'sleepy' { Start-Action 'sleep' (20 + $rand.NextDouble() * 25) }
    # A pomodoro keeps its own breaks.
    'break' { if (-not $POMO.phase) { Start-Action 'break' 3600 } }
    default {
      if ($S.action -eq 'type' -or $S.action -eq 'sleep' -or $S.action -eq 'break') { Start-Action 'idle' 1.5 }
    }
  }
}

function Read-State {
  try {
    $info = [IO.FileInfo]::new($StateFile)
    if (-not $info.Exists -or $info.LastWriteTimeUtc -eq $S.stateStamp) { return }
    $raw = [IO.File]::ReadAllText($StateFile)
    $st = $raw | ConvertFrom-Json
    $S.stateStamp = $info.LastWriteTimeUtc
  } catch { return }

  $S.model = [string]$st.model
  $S.percent = $st.contextPercent
  if ($null -ne $st.aliveAt) { $S.aliveAt = [double]$st.aliveAt }
  # A state no Claude session keeps up (say, last night's, read at login) moves nothing.
  $live = Is-Connected
  if ($live -and $st.speech -and $st.speech -ne $S.speech) {
    $S.speech = [string]$st.speech
    Say $S.speech 7
  }
  if ($live -and $st.mood -and $st.mood -ne $S.mood) {
    $was = $S.mood
    $S.mood = [string]$st.mood
    if (-not $S.dragging) { Apply-Mood $S.mood $was }
  }
  if ($live) { $S.toolKind = [string]$st.toolKind } else { $S.toolKind = '' }
  if ($null -ne $st.tempo) { $S.tempo = [double]$st.tempo }
  $S.weather = $st.weather
  # Each queued event once. The first read, and anything older than 15s, only marks them seen:
  # last night's queue, read at login, does nothing.
  $first = $S.eventId -lt 0
  $S.eventId = 0
  $nowMs = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
  foreach ($ev in @($st.events)) {
    if ($null -eq $ev -or $null -eq $ev.id) { continue }
    if (-not $S.seen.Add([double]$ev.id)) { continue }
    if ($first -or ($nowMs - [double]$ev.at) -gt 15000) { continue }
    if ($ev.kind -eq 'hide') { $win.Close(); return }
    Handle-Event $ev
  }
  if ($S.seen.Count -gt 500) {
    $S.seen.Clear()
    foreach ($ev in @($st.events)) { if ($null -ne $ev.id) { [void]$S.seen.Add([double]$ev.id) } }
  }
}

# Whether a Claude session wrote the state lately (the mod beats every 20s).
function Is-Connected {
  $nowMs = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
  return ($nowMs - $S.aliveAt) -lt 60000
}

function Check-Connection {
  $on = Is-Connected
  if ($on -eq $S.connected) { return }
  $S.connected = $on
  if ($on) {
    Say 'Claude''s here! Let''s code 👋' 3
    Start-Action 'wave' 2
  } else {
    if ($S.mood -eq 'working' -or $S.mood -eq 'break') { $S.mood = 'idle'; Start-Action 'idle' 1 }
    Say 'Claude''s away. I''ll hang out here.' 4
  }
}

function Show-Off {
  foreach ($i in 1..3) { Float '✦' $ORANGE 14 1.2 }
  Say 'How do I look?' 2.5
}

function Pet {
  foreach ($i in 1..4) { Float '♥' ([Windows.Media.Brushes]::HotPink) 16 1.5 }
  $lines = @('Hehe!', '*happy clicking*', 'You''re the best!', 'More pets pls')
  Say $lines[$rand.Next($lines.Count)] 3
  if (-not $S.air) { Hop 300 0 }
  Game-Petted
}

# ------------------------------------------------------------- the drawing --

function Set-Legs([int]$step, [bool]$tucked) {
  $cols = @(3, 5, 10, 12)
  if ($step -eq 1) { $cols = @(4, 6, 11, 13) }
  if ($step -eq 2) { $cols = @(2, 4, 9, 11) }
  for ($i = 0; $i -lt 4; $i++) {
    Move-Rect $legs[$i] $cols[$i] 4
    if ($tucked) { $legs[$i].Visibility = 'Hidden' } else { $legs[$i].Visibility = 'Visible' }
  }
}

function Set-Eyes([string]$kind) {
  # Eyes glance toward where Clawd faces (the flip mirrors this, so +1 is "ahead").
  $look = 0.0
  if ($S.action -eq 'walk' -or $S.action -eq 'run' -or $S.action -eq 'chase') { $look = 0.4 }
  switch ($kind) {
    'shut' { $h = 0.25; $top = 1.5 }
    'happy' { $h = 0.45; $top = 1.1 }
    'wide' { $h = 1.4; $top = 0.6 }
    default { $h = 1.0; $top = 1.0 }
  }
  foreach ($pair in @(@($eyeL, 4), @($eyeR, 11))) {
    $pair[0].Height = $h * $PY
    Move-Rect $pair[0] ($pair[1] + $look) $top
  }
}

function Set-Arms([double]$left, [double]$right) {
  Move-Rect $armL 0 $left
  Move-Rect $armR 14 $right
}

function Draw([double]$now) {
  $a = $S.action
  $legStep = 0
  $tucked = $false
  $eyes = 'open'
  $armLRow = 2.0; $armRRow = 2.0
  $sy = 1.0; $sx = 1.0; $bob = 0.0; $shakeX = 0.0
  $laptop.Visibility = 'Collapsed'
  $wingsOn = $false; $flameOn = $false; $chuteOn = $false; $balloonOn = $false
  # Turned about the feet (the default) or, for a spin, about the middle of the body.
  $angle = 0.0; $spinMiddle = $false
  $fade = 1.0

  if ($S.dragging) {
    $legStep = [int]($now * 14) % 3
    $eyes = 'wide'
    $armLRow = 1; $armRRow = 1
  } elseif ($S.sky) {
    switch ($a) {
      'fly' {
        $wingsOn = $true
        $legStep = 1; $eyes = 'happy'
        $armLRow = 1.6; $armRRow = 1.6
        $bob = [Math]::Sin($now * 5) * 3
      }
      'jetpack' {
        $flameOn = $true
        $legStep = 1; $eyes = 'wide'
        $armLRow = 0.4; $armRRow = 0.4
        if ($S.phase -eq 'go') { $angle = 14 * $S.face }
      }
      'parachute' {
        if ($S.phase -eq 'launch') {
          $flameOn = $true; $eyes = 'wide'; $armLRow = 0.4; $armRRow = 0.4
        } else {
          $chuteOn = $true; $eyes = 'happy'
          $armLRow = 0; $armRRow = 0
          $legStep = [int]($now * 2) % 2
          $angle = [Math]::Sin($S.t * 1.6) * 9
        }
      }
      'balloon' {
        $balloonOn = $true
        $armRRow = 0
        $legStep = [int]($now * 2.5) % 2
        $angle = [Math]::Sin($S.t * 1.2) * 5
      }
    }
  } elseif ($S.air) {
    $legStep = 1
    $armLRow = 1.3; $armRRow = 1.3
    if ($a -eq 'backflip') {
      $k = [Math]::Min(1, $S.t / 0.75)
      $angle = -360 * $k * $S.face
      $spinMiddle = $true; $legStep = 0; $armLRow = 0; $armRRow = 0; $eyes = 'happy'
    }
  } else {
    switch ($a) {
      { $_ -in 'walk', 'chase', 'run', 'flee' } {
        $rate = 7; if ($a -ne 'walk') { $rate = 13 }
        $legStep = [int]($now * $rate) % 2
        $bob = -[Math]::Abs([Math]::Sin($now * $rate * [Math]::PI)) * 2
      }
      'sit' { $tucked = $true; $bob = $PY * 0.8 }
      'sleep' { $tucked = $true; $bob = $PY * 0.8; $eyes = 'shut'; $sy = 1 + [Math]::Sin($now * 2) * 0.03 }
      'type' {
        $tucked = $true; $bob = $PY * 0.8
        $laptop.Visibility = 'Visible'
        # Types along with you: faster while you type fast in Claude's prompt.
        $tap = [int]($now * (9 + [Math]::Min(12, $S.tempo * 1.5))) % 2
        $armLRow = 2.6 + 0.3 * $tap; $armRRow = 2.9 - 0.3 * $tap
      }
      'wave' { if ([int]($now * 5) % 2 -eq 0) { $armRRow = 0 } else { $armRRow = 1 }; $eyes = 'happy' }
      # A sip from the mug: arm up, eyes shut in bliss now and then.
      'sip' { $armRRow = 1 + [Math]::Sin($now * 2) * 0.5; if ([int]($now * 1.5) % 3 -eq 0) { $eyes = 'happy' } }
      'break' {
        if ([int]($now * 4) % 2 -eq 0) { $armRRow = 0; $armLRow = 0 } else { $armRRow = 1; $armLRow = 1 }
        $sy = 1 + [Math]::Sin($now * 3) * 0.08
      }
      'dance' {
        $legStep = [int]($now * 6) % 3
        $bob = -[Math]::Abs([Math]::Sin($now * 6)) * 6
        if ([int]($now * 3) % 2 -eq 0) { $armLRow = 0; $armRRow = 2 } else { $armLRow = 2; $armRRow = 0 }
        $eyes = 'happy'
      }
      'stretch' {
        $k = [Math]::Sin([Math]::Min(1, $S.t / $S.dur) * [Math]::PI)
        $sy = 1 + 0.3 * $k; $sx = 1 - 0.12 * $k
        $armLRow = 2 - 2 * $k; $armRRow = 2 - 2 * $k
      }
      'land' { $k = 1 - [Math]::Min(1, $S.t / $S.dur); $sy = 1 - 0.3 * $k; $sx = 1 + 0.2 * $k }
      'shake' { $shakeX = [Math]::Sin($now * 60) * 2.5; $eyes = 'wide' }
      'climb' { $legStep = [int]($now * 6) % 2 }
      'hang' { $eyes = 'wide' }
      'teleport' {
        # Shrinks away, then grows back in its new spot.
        $k = [Math]::Abs($S.t - 0.45) / 0.45
        $fade = [Math]::Min(1, $k); $sx = [Math]::Max(0.05, $k); $sy = [Math]::Max(0.05, $k)
      }
    }
  }

  $wingVis = 'Collapsed'; if ($wingsOn) { $wingVis = 'Visible' }
  $wingL.Visibility = $wingVis; $wingR.Visibility = $wingVis
  if ($wingsOn) {
    $flap = [Math]::Sin($now * 18) * 35
    $wingL.RenderTransform.Angle = $flap
    $wingR.RenderTransform.Angle = -$flap
  }
  foreach ($f in $flames) {
    if ($flameOn) {
      $f.Visibility = 'Visible'
      $f.Height = $PY * (0.8 + $rand.NextDouble() * 1.2)
      if ($rand.Next(2) -eq 0) { $f.Fill = $FLAME_HOT } else { $f.Fill = $FLAME }
    } else { $f.Visibility = 'Collapsed' }
  }
  if ($chuteOn) { $chute.Visibility = 'Visible'; $chuteSway.Angle = $angle } else { $chute.Visibility = 'Collapsed' }
  if ($balloonOn) { $balloon.Visibility = 'Visible'; $balloonBob.Angle = [Math]::Sin($now * 1.7) * 6 } else { $balloon.Visibility = 'Collapsed' }
  $body.Opacity = $fade

  if ($eyes -eq 'open' -and $S.blinkFor -gt 0) { $eyes = 'shut' }
  Set-Legs $legStep $tucked
  Set-Eyes $eyes
  Set-Arms $armLRow $armRRow

  $flip.ScaleX = $S.face
  $squash.ScaleX = $sx; $squash.ScaleY = $sy
  $nudge.X = $shakeX; $nudge.Y = $bob
  $turn.CenterY = 0
  if (($a -eq 'climb' -or $a -eq 'hang') -and -not $S.air) {
    # Feet on the wall: turned about them, then slid out to the screen's edge.
    $turn.Angle = -90 * $S.face
    $nudge.X = $S.face * $ART_W / 2
  } else {
    $turn.Angle = $angle
    if ($spinMiddle) { $turn.CenterY = -$ART_H / 2 }
  }

  # The window grows with the Size setting; its feet stay on the floor.
  $k = 1.0; if ($WORLD.k) { $k = $WORLD.k }
  $left = $S.x - $WIN_W * $k / 2
  $top = $S.y - $WIN_H * $k + 2
  if ([Math]::Abs($win.Left - $left) -gt 0.3) { $win.Left = $left }
  if ([Math]::Abs($win.Top - $top) -gt 0.3) { $win.Top = $top }
}

# -------------------------------------------------------------- the moving --

function Step-Ground([double]$dt, [double]$now) {
  $a = $S.action
  switch ($a) {
    { $_ -in 'walk', 'run' } {
      $speed = $WALK; if ($a -eq 'run') { $speed = $RUN }
      $d = $S.target - $S.x
      $atWall = ($S.x -le $S.left -and $d -le 0) -or ($S.x -ge $S.right -and $d -ge 0)
      if ([Math]::Abs($d) -lt 3 -and -not $atWall) { Start-Action 'idle'; break }
      if ([Math]::Abs($d) -ge 1) { $S.face = [Math]::Sign($d) }
      $S.x += $S.face * $speed * $dt
      if ($S.x -le $S.left -or $S.x -ge $S.right) {
        $S.x = [Math]::Max($S.left, [Math]::Min($S.right, $S.x))
        $climb = $S.wantClimb -or $rand.Next(100) -lt 45
        $S.wantClimb = $false
        if ($climb) {
          $S.climbTo = $S.y - (80 + $rand.Next(220))
          Start-Action 'climb' 20
        } else { Start-Action 'look' 1.5 }
      }
    }
    'chase' {
      $c = Cursor-Dip
      $d = $c.X - $S.x
      if ([Math]::Abs($d) -gt 2) { $S.face = [Math]::Sign($d) }
      $S.x = [Math]::Max($S.left, [Math]::Min($S.right, $S.x + $S.face * $RUN * $dt))
      $above = $S.y - $c.Y
      if ([Math]::Abs($d) -lt 40) {
        if ($above -gt 60 -and $above -lt 420) { Hop ([Math]::Min(900, 300 + $above * 1.6)) 30 }
        else {
          foreach ($i in 1..2) { Float '♥' ([Windows.Media.Brushes]::HotPink) 14 1.2 }
          Say 'Got you!' 2
          Hop 300 0
        }
        Start-Action 'idle' 2
      }
    }
    'climb' {
      $S.y -= 45 * $dt
      if ($S.y -le [Math]::Max($S.climbTo, $S.top)) { Start-Action 'hang' 1.2 }
    }
    'hang' {
      if ($S.t -ge $S.dur) {
        # Let go, and push off the wall.
        $S.face = -$S.face
        $S.vx = $S.face * 90; $S.vy = -150; $S.air = $true
        Start-Action 'idle' 1
      }
    }
    'look' {
      $flipEvery = 0.8
      if ([int]($S.t / $flipEvery) -ne [int](($S.t - $dt) / $flipEvery)) {
        $S.face = -$S.face
        if ($S.t -lt 1) { Float '?' $ORANGE 16 1.0 }
      }
    }
    'dance' {
      if ([int]($S.t * 2.5) -ne [int](($S.t - $dt) * 2.5)) {
        $S.face = -$S.face
        Float '♪' $ORANGE 15 1.3
      }
    }
    'sleep' {
      if ([int]($S.t / 1.3) -ne [int](($S.t - $dt) / 1.3)) { Float 'z' $DARK (12 + $rand.Next(6)) 2.2 }
    }
    'break' {
      if ([int]($S.t / 6) -ne [int](($S.t - $dt) / 6)) { Say 'Stretch break! 💧 Stand up with me!' 4 }
    }
    'teleport' {
      if ($S.t -ge 0.45 -and ($S.t - $dt) -lt 0.45) {
        $S.x = $S.left + $rand.NextDouble() * ($S.right - $S.left)
        foreach ($i in 1..3) { Float '✦' $ORANGE 14 0.9 }
      }
    }
  }

  # Moods hold their action; everything else times out into the next idea.
  $held = @('type', 'break', 'climb', 'hang', 'walk', 'run')
  if ($S.t -ge $S.dur -and $held -notcontains $S.action) {
    if ($S.mood -eq 'working') { Start-Action 'type' 3600 }
    elseif ($S.mood -eq 'sleepy') { Choose-Sleepy }
    else { Choose-Idle }
  }
  if (($S.action -eq 'walk' -or $S.action -eq 'run') -and $S.t -ge $S.dur) { Start-Action 'idle' }
}

function Step-Air([double]$dt) {
  $S.vy += $GRAVITY * $dt
  $S.x += $S.vx * $dt
  $S.y += $S.vy * $dt
  if ($S.x -lt $S.left) { $S.x = $S.left; $S.vx = -$S.vx * 0.55 }
  if ($S.x -gt $S.right) { $S.x = $S.right; $S.vx = -$S.vx * 0.55 }
  if ($S.y -lt $S.top) { $S.y = $S.top; $S.vy = [Math]::Abs($S.vy) * 0.3 }
  if ($S.y -ge $S.floor) {
    $S.y = $S.floor
    if ($S.vy -gt 500) {
      $S.vy = -$S.vy * 0.32
      $S.vx *= 0.6
      Start-Action 'land' 0.25
      if ($S.vy -lt -250) { Float '!' $ORANGE 14 0.6 }
    } else {
      $S.vy = 0; $S.vx = 0; $S.air = $false
      if ($S.action -ne 'land') { Start-Action 'land' 0.2 }
    }
  }
}

# ------------------------------------------------------------- the features --

# Each file adds its own state, functions and menu; Tick-Features and Add-FeatureMenus call them.
foreach ($f in @('settings', 'props', 'events', 'tracker', 'pomodoro', 'reminders', 'nudges', 'calendar', 'game', 'world', 'ask', 'editor', 'hub')) {
  . (Join-Path $PSScriptRoot "features\$f.ps1")
}

function Tick-Features([double]$dt, [double]$now) {
  Tick-Props $dt $now
  Tick-Tracker $dt
  Tick-Pomodoro $dt
  Tick-Reminders $dt
  Tick-Nudges $dt
  Tick-Calendar $dt
  Tick-Game $dt
  Tick-World $dt $now
  Tick-Hub $dt
}

# Now and then, instead of the usual antics; true when it started something.
function Choose-FeatureIdle {
  if ((Choose-WorldIdle) -eq $true) { return $true }
  return $false
}

$clock = [Diagnostics.Stopwatch]::StartNew()
$last = 0.0
$errors = 0
$demoNext = 3.0
$demoIndex = 0
$tourNext = 1.0
$tourIndex = 0

function Tick {
  $now = $clock.Elapsed.TotalSeconds
  $dt = [Math]::Min(0.05, $now - $script:last)
  $script:last = $now
  $S.t += $dt

  $S.sinceBounds += $dt
  if ($S.sinceBounds -gt 0.5) { $S.sinceBounds = 0; Update-Bounds }
  $S.sinceState += $dt
  if ($S.sinceState -gt 0.25) { $S.sinceState = 0; Read-State }
  $S.sinceAlive += $dt
  if ($S.sinceAlive -gt 3) {
    $S.sinceAlive = 0
    try { [IO.File]::WriteAllText($AliveFile, [string][DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()) } catch { }
    if ($null -eq $S.connected) { $S.connected = Is-Connected } else { Check-Connection }
  }
  $S.sinceParent += $dt
  if ($S.sinceParent -gt 3) {
    $S.sinceParent = 0
    if ($env:CLAWD_PET_DEBUG) {
      [Console]::Error.WriteLine(("clawd-pet: x={0:N0} y={1:N0} floor={2:N0} left={3:N0} right={4:N0} scale={5} action={6} air={7} win={8:N0},{9:N0} visible={10}" -f $S.x, $S.y, $S.floor, $S.left, $S.right, $S.scale, $S.action, $S.air, $win.Left, $win.Top, $win.IsVisible))
    }
    if ($ParentPid -gt 0 -and -not (Get-Process -Id $ParentPid -ErrorAction SilentlyContinue)) { $win.Close(); return }
  }

  # Blink now and then.
  if ($S.blinkFor -gt 0) { $S.blinkFor -= $dt }
  $S.blinkAt -= $dt
  if ($S.blinkAt -le 0) { $S.blinkFor = 0.14; $S.blinkAt = 2 + $rand.NextDouble() * 4 }

  if ($S.bubbleFor -gt 0) {
    $S.bubbleFor -= $dt
    if ($S.bubbleFor -le 0) { $bubble.Visibility = 'Collapsed' }
  }

  # A new day, a new daily outfit.
  $S.sinceOutfit += $dt
  if ($S.sinceOutfit -gt 30) {
    $S.sinceOutfit = 0
    if ($S.outfitChoice -eq 'daily' -and (Get-Date -Format 'yyyyMMdd') -ne $S.outfitDay) {
      Wear-Outfit 'daily'
      Say 'New day, new look! ✨' 3
    }
  }

  # CLAWD_PET_OUTFIT_TOUR=1 tries on every outfit in turn, for checking how they sit.
  if ($env:CLAWD_PET_OUTFIT_TOUR -and $now -gt $script:tourNext) {
    $keys = @($OUTFITS.Keys)
    $key = $keys[$script:tourIndex % $keys.Count]
    $script:tourIndex++
    $script:tourNext = $now + 3
    [Console]::Error.WriteLine("clawd-pet: outfit $key")
    Set-Outfit $key
    Say $OUTFITS[$key].label 2.5
  }

  # CLAWD_PET_SELFTEST=1 builds every menu and runs each feature once, logging what failed.
  if ($env:CLAWD_PET_SELFTEST -and $now -gt 4 -and -not $script:selfTested) {
    $script:selfTested = $true
    Run-SelfTest
  }

  # CLAWD_PET_DEMO="fly,parachute,..." runs those tricks in turn, for trying them out.
  if ($env:CLAWD_PET_DEMO -and -not $S.air -and -not $S.sky -and $S.action -ne 'teleport' -and $now -gt $script:demoNext) {
    $tricks = $env:CLAWD_PET_DEMO -split ','
    $trick = $tricks[$script:demoIndex % $tricks.Count].Trim()
    $script:demoIndex++
    $script:demoNext = $now + 4
    [Console]::Error.WriteLine("clawd-pet: demo $trick")
    switch ($trick) {
      'teleport' { Start-Teleport }
      'backflip' { Start-Backflip }
      default { Start-Sky $trick }
    }
  }

  # Trackers, timers, reminders, the game: each on its own clock.
  Tick-Features $dt $now

  Pick-Screen
  Keep-OnScreen
  if (-not $S.dragging -and -not (Step-Perch $dt)) {
    if ($S.sky) { Step-Sky $dt } elseif ($S.air) { Step-Air $dt } else { Step-Ground $dt $now }
  }

  for ($i = $particles.Count - 1; $i -ge 0; $i--) {
    $p = $particles[$i]
    $p.t += $dt
    $p.x += $p.vx * $dt; $p.y += $p.vy * $dt
    $p.el.Opacity = [Math]::Max(0, 1 - $p.t / $p.life)
    [Windows.Controls.Canvas]::SetLeft($p.el, $p.x)
    [Windows.Controls.Canvas]::SetTop($p.el, $p.y)
    if ($p.t -ge $p.life) { $fx.Children.Remove($p.el); $particles.RemoveAt($i) }
  }

  Draw $now
}

# --------------------------------------------------------------- the mouse --

function Mouse-Screen($e) {
  $p = $e.GetPosition($win)
  return [Windows.Point]::new($win.Left + $p.X, $win.Top + $p.Y)
}

$body.Add_MouseLeftButtonDown({
  param($sender, $e)
  if ($e.ClickCount -ge 2) {
    Start-Action 'dance' 4
    Say 'Dance party! ♪' 2.5
    $e.Handled = $true
    return
  }
  $m = Mouse-Screen $e
  $S.pressed = $true; $S.dragging = $false
  $S.downX = $m.X; $S.downY = $m.Y
  $S.lastMX = $m.X; $S.lastMY = $m.Y
  $S.grabDX = $S.x - $m.X; $S.grabDY = $S.y - $m.Y
  $S.dragVX = 0; $S.dragVY = 0
  [void]$body.CaptureMouse()
  $e.Handled = $true
})

$body.Add_MouseMove({
  param($sender, $e)
  if (-not $S.pressed) { return }
  $m = Mouse-Screen $e
  if (-not $S.dragging -and ([Math]::Abs($m.X - $S.downX) + [Math]::Abs($m.Y - $S.downY)) -gt 5) {
    $S.dragging = $true
    $S.air = $false; $S.sky = $false
    $lines = @('Wheee!', 'Whoa!', 'Where are we going?', 'Put me down! ...actually this is fun')
    Say $lines[$rand.Next($lines.Count)] 2
  }
  if ($S.dragging) {
    # Keep a smoothed velocity for the throw.
    $S.dragVX = 0.6 * $S.dragVX + 0.4 * (($m.X - $S.lastMX) / 0.016)
    $S.dragVY = 0.6 * $S.dragVY + 0.4 * (($m.Y - $S.lastMY) / 0.016)
    $S.lastMX = $m.X; $S.lastMY = $m.Y
    $S.x = $m.X + $S.grabDX
    $S.y = $m.Y + $S.grabDY
  }
})

$body.Add_MouseLeftButtonUp({
  param($sender, $e)
  if (-not $S.pressed) { return }
  $S.pressed = $false
  $body.ReleaseMouseCapture()
  if ($S.dragging) {
    $S.dragging = $false
    $S.vx = [Math]::Max(-1600, [Math]::Min(1600, $S.dragVX))
    $S.vy = [Math]::Max(-1600, [Math]::Min(1600, $S.dragVY))
    $S.air = $true
    Update-Bounds
    Start-Action 'idle' 1.5
  } else {
    Pet
  }
  $e.Handled = $true
})

# The right-click menu.
function Menu-Item([string]$header, [scriptblock]$onClick, [bool]$checked = $false) {
  $item = [Windows.Controls.MenuItem]::new()
  $item.Header = $header
  $item.IsChecked = $checked
  $item.Add_Click($onClick)
  return $item
}

$menu = [Windows.Controls.ContextMenu]::new()
$body.ContextMenu = $menu
function Build-Menu {
  $menu.Items.Clear()
  $live = Is-Connected
  $title = [Windows.Controls.MenuItem]::new()
  $title.Header = "Model: $($S.model)"
  if (-not $live) { $title.Header = 'Open Claude Code to switch models' }
  $title.IsEnabled = $false
  [void]$menu.Items.Add($title)
  foreach ($m in @(@('Opus', 'opus'), @('Sonnet', 'sonnet'), @('Haiku', 'haiku'), @('Fable', 'fable'))) {
    $item = Menu-Item "Switch to $($m[0])" {
      param($sender)
      Send "model $($sender.Tag)"
      Say "Switching to $($sender.Header -replace '^Switch to ', '')..." 3
    } ($S.model -match $m[1])
    $item.Tag = $m[1]
    $item.IsEnabled = $live
    [void]$menu.Items.Add($item)
  }
  [void]$menu.Items.Add([Windows.Controls.Separator]::new())
  $ctx = 'Compact context'
  if ($null -ne $S.percent) { $ctx = "Compact context ($([Math]::Round($S.percent))% full)" }
  $compactItem = Menu-Item $ctx { Send 'compact' }
  $compactItem.IsEnabled = $live
  [void]$menu.Items.Add($compactItem)
  Add-ClaudeMenu $menu $live
  [void]$menu.Items.Add([Windows.Controls.Separator]::new())

  $acts = [Windows.Controls.MenuItem]::new()
  $acts.Header = 'Do a trick'
  [void]$acts.Items.Add((Menu-Item 'Dance' { Start-Action 'dance' 4 }))
  [void]$acts.Items.Add((Menu-Item 'Wave' { Start-Action 'wave' 2.5; Say 'Hi there! 👋' 2 }))
  [void]$acts.Items.Add((Menu-Item 'Jump' { if (-not $S.air) { Hop 520 0 } }))
  [void]$acts.Items.Add((Menu-Item 'Stretch' { Start-Action 'stretch' 1.8 }))
  [void]$acts.Items.Add((Menu-Item 'Sit' { Start-Action 'sit' 8 }))
  [void]$acts.Items.Add((Menu-Item 'Nap' { Start-Action 'sleep' 20 }))
  [void]$acts.Items.Add((Menu-Item 'Chase my cursor' { Start-Chase }))
  [void]$acts.Items.Add([Windows.Controls.Separator]::new())
  [void]$acts.Items.Add((Menu-Item 'Fly' { Start-Sky 'fly' }))
  [void]$acts.Items.Add((Menu-Item 'Parachute drop' { Start-Sky 'parachute' }))
  [void]$acts.Items.Add((Menu-Item 'Balloon ride' { Start-Sky 'balloon' }))
  [void]$acts.Items.Add((Menu-Item 'Jetpack' { Start-Sky 'jetpack' }))
  [void]$acts.Items.Add((Menu-Item 'Teleport' { if (-not $S.air -and -not $S.sky) { Start-Teleport } }))
  [void]$acts.Items.Add((Menu-Item 'Backflip' { if (-not $S.air -and -not $S.sky) { Start-Backflip } }))
  [void]$acts.Items.Add((Menu-Item 'Climb a wall' {
    $S.wantClimb = $true
    $S.target = $S.right; if ($S.x - $S.left -lt $S.right - $S.x) { $S.target = $S.left }
    Start-Action 'run' 15
  }))
  Add-TrickMenu $acts
  [void]$menu.Items.Add($acts)

  $wardrobe = [Windows.Controls.MenuItem]::new()
  $wardrobe.Header = 'Outfit'
  [void]$wardrobe.Items.Add((Menu-Item 'Surprise me daily' { Wear-Outfit 'daily' $true; Show-Off } ($S.outfitChoice -eq 'daily')))
  [void]$wardrobe.Items.Add((Menu-Item 'No outfit' { Wear-Outfit 'none' $true; Say 'Au naturel 🦀' 2 } ($S.outfitChoice -eq 'none')))
  [void]$wardrobe.Items.Add([Windows.Controls.Separator]::new())
  foreach ($g in $OUTFIT_GROUPS) {
    $sub = [Windows.Controls.MenuItem]::new()
    $sub.Header = $g
    foreach ($k in $OUTFITS.Keys) {
      if ($OUTFITS[$k].group -ne $g) { continue }
      $item = Menu-Item $OUTFITS[$k].label {
        param($sender)
        Wear-Outfit $sender.Tag $true
        Show-Off
      } ($S.outfit -eq $k)
      $item.Tag = $k
      # Some outfits wait for a level.
      $need = Outfit-Unlock $k
      if ($need -gt 0) { $item.Header = "🔒 $($OUTFITS[$k].label) (Lv $need)"; $item.IsEnabled = $false }
      [void]$sub.Items.Add($item)
    }
    if ($sub.Items.Count -gt 0) { [void]$wardrobe.Items.Add($sub) }
  }
  [void]$wardrobe.Items.Add([Windows.Controls.Separator]::new())
  [void]$wardrobe.Items.Add((Menu-Item 'Make an outfit...' { Show-OutfitEditor }))
  [void]$menu.Items.Add($wardrobe)
  Add-FeatureMenus $menu
  [void]$menu.Items.Add((Menu-Item 'Come here' {
    $c = Cursor-Dip
    $S.x = [Math]::Max($S.left, [Math]::Min($S.right, $c.X)); $S.y = $c.Y - 40
    $S.vx = 0; $S.vy = 0; $S.air = $true
    Say 'Here I am!' 2
  }))
  [void]$menu.Items.Add([Windows.Controls.Separator]::new())
  [void]$menu.Items.Add((Menu-Item 'Hide for 1 hour' { Hide-For 60 }))
  [void]$menu.Items.Add((Menu-Item 'Hide Clawd' { Send 'hide'; $win.Close() }))
}
# Right-click opens the hub (features\hub.ps1); Shift+right-click, this full menu.
$body.ContextMenu = $null
$body.Add_MouseRightButtonUp({
  param($sender, $e)
  if ([Windows.Input.Keyboard]::Modifiers -band [Windows.Input.ModifierKeys]::Shift) { Open-FullMenu } else { Toggle-Hub }
  $e.Handled = $true
})

# ----------------------------------------------------------------- the run --

$win.Add_SourceInitialized({
  # A tool window that never takes the focus: clicking Clawd leaves your typing where it was.
  $hwnd = [Windows.Interop.WindowInteropHelper]::new($win).Handle
  $GWL_EXSTYLE = -20
  $style = [ClawdPet.Native]::GetWindowLong($hwnd, $GWL_EXSTYLE)
  [void][ClawdPet.Native]::SetWindowLong($hwnd, $GWL_EXSTYLE, ($style -bor 0x80 -bor 0x08000000))
})

$win.Add_Loaded({
  Update-Bounds
  # Drop in from the top of the main screen, toward its right.
  $main = [Windows.Forms.Screen]::PrimaryScreen.WorkingArea
  $S.x = $main.Right / $S.scale - $ART_W - 120 - $rand.Next(200)
  $S.y = $main.Top / $S.scale + $ART_H + 20
  $S.air = $true
  Update-Bounds
  Init-Features
  # CLAWD_PET_OUTFIT=<key> dresses this run without touching the saved pick.
  if ($env:CLAWD_PET_OUTFIT) { Wear-Outfit $env:CLAWD_PET_OUTFIT } else { Wear-Outfit (Read-OutfitChoice) }
  Read-State
  if (-not $S.speech) { Say 'Hi! I''m Clawd 🦀' 4 }
})

$win.Add_Closed({
  # Gone at once, so /clawd can bring a new Clawd straight back.
  try { [IO.File]::Delete($AliveFile) } catch { }
  try { Save-Features } catch { }
})

$timer = [Windows.Threading.DispatcherTimer]::new()
$timer.Interval = [TimeSpan]::FromMilliseconds(30)
$timer.Add_Tick({
  try { Tick } catch {
    $script:errors++
    if ($script:errors -le 3) { [Console]::Error.WriteLine("clawd-pet: $($_.Exception.Message) at $($_.InvocationInfo.ScriptLineNumber)") }
  }
})
$timer.Start()

[void]$win.ShowDialog()
