# ----------------------------------------------------------------- the hub --
# Right-click Clawd: a small, calm control panel with everything Clawd can do, in five tabs.
# Shift+right-click still opens the full menu. The panel closes when you click elsewhere or press Esc.

Add-Type -AssemblyName System.Drawing
$HUBUI = @{ win = $null; closing = $false; moved = $false; tab = 'home'; shown = ''; since = 0.0; connected = $null; live = [Collections.ArrayList]::new() }

$HUB_XAML = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        WindowStyle="None" AllowsTransparency="True" Background="Transparent" Topmost="True"
        ShowInTaskbar="False" ResizeMode="NoResize" Width="376" SizeToContent="Height"
        FontFamily="Segoe UI" UseLayoutRounding="True" Title="Clawd">
  <Window.Resources>
    <Style TargetType="ScrollBar">
      <Setter Property="Width" Value="6"/>
      <Setter Property="MinWidth" Value="6"/>
      <Setter Property="Margin" Value="4,2,0,2"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="ScrollBar">
            <Track x:Name="PART_Track" IsDirectionReversed="True">
              <Track.Thumb>
                <Thumb>
                  <Thumb.Template>
                    <ControlTemplate TargetType="Thumb"><Border CornerRadius="3" Background="#4A4363"/></ControlTemplate>
                  </Thumb.Template>
                </Thumb>
              </Track.Thumb>
            </Track>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style x:Key="Chip" TargetType="Button">
      <Setter Property="Foreground" Value="#EDE8F5"/>
      <Setter Property="Background" Value="#363049"/>
      <Setter Property="FontSize" Value="12"/>
      <Setter Property="Padding" Value="11,6"/>
      <Setter Property="Margin" Value="0,0,6,6"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Focusable" Value="False"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="b" Background="{TemplateBinding Background}" CornerRadius="12" Padding="{TemplateBinding Padding}">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="b" Property="Opacity" Value="0.82"/></Trigger>
              <Trigger Property="IsPressed" Value="True"><Setter TargetName="b" Property="Opacity" Value="0.65"/></Trigger>
              <Trigger Property="IsEnabled" Value="False"><Setter TargetName="b" Property="Opacity" Value="0.38"/></Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style x:Key="Accent" TargetType="Button" BasedOn="{StaticResource Chip}">
      <Setter Property="Background" Value="#E8957A"/>
      <Setter Property="Foreground" Value="#2A1D18"/>
    </Style>
    <Style x:Key="On" TargetType="Button" BasedOn="{StaticResource Chip}">
      <Setter Property="Background" Value="#8FD3B6"/>
      <Setter Property="Foreground" Value="#17261F"/>
    </Style>
    <Style x:Key="Ghost" TargetType="Button" BasedOn="{StaticResource Chip}">
      <Setter Property="Background" Value="Transparent"/>
      <Setter Property="Foreground" Value="#A79FC0"/>
      <Setter Property="Padding" Value="8,4"/>
      <Setter Property="Margin" Value="0"/>
    </Style>
    <Style x:Key="Tab" TargetType="RadioButton">
      <Setter Property="Foreground" Value="#B9B2CF"/>
      <Setter Property="FontSize" Value="11.5"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Focusable" Value="False"/>
      <Setter Property="Margin" Value="2,0"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="RadioButton">
            <Border x:Name="b" CornerRadius="12" Padding="4,6" Background="Transparent">
              <ContentPresenter HorizontalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="b" Property="Background" Value="#332D45"/></Trigger>
              <Trigger Property="IsChecked" Value="True">
                <Setter TargetName="b" Property="Background" Value="#E8957A"/>
                <Setter Property="Foreground" Value="#2A1D18"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style x:Key="Switch" TargetType="CheckBox">
      <Setter Property="Foreground" Value="#E4DEEF"/>
      <Setter Property="FontSize" Value="12.5"/>
      <Setter Property="Margin" Value="0,4"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Focusable" Value="False"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="CheckBox">
            <Grid Background="Transparent">
              <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
              <ContentPresenter VerticalAlignment="Center"/>
              <Border x:Name="track" Grid.Column="1" Width="34" Height="18" CornerRadius="9" Background="#3A3450" Margin="10,0,0,0">
                <Ellipse x:Name="thumb" Width="12" Height="12" Fill="#9C95B3" HorizontalAlignment="Left" Margin="3,0"/>
              </Border>
            </Grid>
            <ControlTemplate.Triggers>
              <Trigger Property="IsChecked" Value="True">
                <Setter TargetName="track" Property="Background" Value="#8FD3B6"/>
                <Setter TargetName="thumb" Property="HorizontalAlignment" Value="Right"/>
                <Setter TargetName="thumb" Property="Fill" Value="#17261F"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
  </Window.Resources>
  <Border x:Name="Shell" Margin="14" Padding="16,14,16,10" CornerRadius="22" Background="#F5221F2E" BorderBrush="#26FFFFFF" BorderThickness="1">
    <Border.Effect><DropShadowEffect BlurRadius="26" ShadowDepth="5" Opacity="0.4" Color="#000000"/></Border.Effect>
    <Border.RenderTransform><TranslateTransform x:Name="Slide" Y="0"/></Border.RenderTransform>
    <StackPanel>
      <Grid x:Name="Head" Background="Transparent" Cursor="SizeAll">
        <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
        <StackPanel>
          <TextBlock x:Name="Title" FontSize="17" FontWeight="SemiBold" Foreground="#F3EEFA"/>
          <TextBlock x:Name="Sub" FontSize="11.5" Foreground="#9C95B3" Margin="0,2,0,0"/>
        </StackPanel>
        <Button x:Name="CloseBtn" Grid.Column="1" Style="{StaticResource Ghost}" Content="✕" VerticalAlignment="Top" ToolTip="Close (Esc)"/>
      </Grid>
      <Border x:Name="XpTrack" Height="5" CornerRadius="3" Background="#332E47" Margin="0,10,0,0">
        <Border x:Name="XpFill" HorizontalAlignment="Left" CornerRadius="3" Background="#E8957A" Width="0"/>
      </Border>
      <TextBlock x:Name="Status" FontSize="11.5" Foreground="#9C95B3" Margin="0,8,0,0" TextWrapping="Wrap"/>
      <UniformGrid x:Name="Tabs" Columns="5" Margin="-2,12,-2,10"/>
      <ScrollViewer x:Name="Scroll" MaxHeight="400" VerticalScrollBarVisibility="Auto">
        <StackPanel x:Name="Body"/>
      </ScrollViewer>
      <Grid Margin="0,6,0,0">
        <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
        <Button x:Name="MoreBtn" Style="{StaticResource Ghost}" Content="⋯ Full menu" HorizontalAlignment="Left" ToolTip="Every option, as a menu (also Shift+right-click)"/>
        <Button x:Name="NapBtn" Grid.Column="1" Style="{StaticResource Ghost}" Content="🙈 Hide 1h"/>
        <Button x:Name="ByeBtn" Grid.Column="2" Style="{StaticResource Ghost}" Content="👋 Bye" ToolTip="Close Clawd (/clawd brings them back)"/>
      </Grid>
    </StackPanel>
  </Border>
</Window>
'@

$HUB_TABS = [ordered]@{ home = '🏠 Home'; focus = '🍅 Focus'; play = '🎈 Play'; style = '👒 Style'; setup = '⚙ Setup' }
$HUB_TRICKS = [ordered]@{
  '💃 Dance' = { Start-Action 'dance' 4 }
  '👋 Wave' = { Start-Action 'wave' 2.5; Say 'Hi there! 👋' 2 }
  '⤴ Jump' = { if (-not $S.air) { Hop 520 0 } }
  '🙆 Stretch' = { Start-Action 'stretch' 1.8 }
  '💺 Sit' = { Start-Action 'sit' 8 }
  '😴 Nap' = { Start-Action 'sleep' 20 }
  '☕ Coffee' = { Start-Action 'sip' 4 }
  '🖱 Chase me' = { Start-Chase }
  '🕊 Fly' = { Start-Sky 'fly' }
  '🌂 Parachute' = { Start-Sky 'parachute' }
  '🎈 Balloon' = { Start-Sky 'balloon' }
  '🚀 Jetpack' = { Start-Sky 'jetpack' }
  '✨ Teleport' = { if (-not $S.air -and -not $S.sky) { Start-Teleport } }
  '🔄 Backflip' = { if (-not $S.air -and -not $S.sky) { Start-Backflip } }
  '🧗 Climb' = { $S.wantClimb = $true; $S.target = $S.right; if ($S.x - $S.left -lt $S.right - $S.x) { $S.target = $S.left }; Start-Action 'run' 15 }
  '⚽ Ball' = { Throw-Ball }
  '🗔 Sit on window' = { if ((Start-Perch) -ne $true) { Say 'No window to sit on here 🤷' 2 $true } }
  '📍 Come here' = { $c = Cursor-Dip; $S.x = [Math]::Max($S.left, [Math]::Min($S.right, $c.X)); $S.y = $c.Y - 40; $S.vx = 0; $S.vy = 0; $S.air = $true; Say 'Here I am!' 2 }
}
$HUB_NUDGES = [ordered]@{ nudgeEyes = @('👀 Eye breaks, every 20 min', 20); nudgeWater = @('💧 Water, every hour', 60); nudgePosture = @('🧍 Posture, every 45 min', 45) }

# --------------------------------------------------------- building blocks --

function Hub-Brush([string]$hex) { return [Windows.Media.BrushConverter]::new().ConvertFromString($hex) }

# A soft card with a small heading; returns the StackPanel to fill.
function Hub-Card([string]$heading) {
  $card = [Windows.Controls.Border]::new()
  $card.Background = Hub-Brush '#2A2639'
  $card.CornerRadius = '16'
  $card.Padding = '12,10,12,6'
  $card.Margin = '0,0,0,10'
  $inner = [Windows.Controls.StackPanel]::new()
  if ($heading) {
    $h = [Windows.Controls.TextBlock]::new()
    $h.Text = $heading.ToUpper(); $h.FontSize = 10.5; $h.FontWeight = 'SemiBold'
    $h.Foreground = Hub-Brush '#8E86A8'; $h.Margin = '0,0,0,8'
    [void]$inner.Children.Add($h)
  }
  $card.Child = $inner
  [void]$HUBUI.body.Children.Add($card)
  return $inner
}

function Hub-Wrap($parent) {
  $wrap = [Windows.Controls.WrapPanel]::new()
  [void]$parent.Children.Add($wrap)
  return $wrap
}

function Hub-Text($parent, [string]$text, [string]$color = '#D9D3E6', [double]$size = 12.5) {
  $tb = [Windows.Controls.TextBlock]::new()
  $tb.Text = $text; $tb.TextWrapping = 'Wrap'; $tb.FontSize = $size
  $tb.Foreground = Hub-Brush $color; $tb.Margin = '0,0,0,8'
  [void]$parent.Children.Add($tb)
  return $tb
}

# Text that keeps itself fresh while the hub is open: $get is run every half second.
function Hub-Live($parent, [scriptblock]$get, [string]$color = '#D9D3E6', [double]$size = 12.5) {
  $tb = Hub-Text $parent (& $get) $color $size
  [void]$HUBUI.live.Add(@{ tb = $tb; get = $get })
  return $tb
}

# A pill button. $do runs with the button as its argument; $data rides along in DataContext.
# $away closes the hub first (for anything that opens its own window).
function Hub-Button($parent, [string]$label, [scriptblock]$do, [string]$look = 'Chip', $data = $null, [bool]$enabled = $true, [bool]$away = $false, [string]$tip = '') {
  $btn = [Windows.Controls.Button]::new()
  $btn.Content = $label
  $btn.Style = $HUBUI.win.Resources[$look]
  $btn.Tag = @{ do = $do; away = $away }
  $btn.DataContext = $data
  $btn.IsEnabled = $enabled
  if ($tip) { $btn.ToolTip = $tip }
  $btn.Add_Click({ param($sender) Hub-Click $sender })
  [void]$parent.Children.Add($btn)
  return $btn
}

function Hub-Click($sender) {
  $what = $sender.Tag
  if ($what.away) { Hub-Close }
  try { & $what.do $sender } catch { [Console]::Error.WriteLine("clawd-pet: hub: $($_.Exception.Message)") }
  if ($HUBUI.win -and -not $HUBUI.closing) { Show-HubTab $HUBUI.tab }
}

# An on/off row. $key is a setting, 'startup', or a nudge.
function Hub-Switch($parent, [string]$label, [string]$key, [bool]$on) {
  $cb = [Windows.Controls.CheckBox]::new()
  $cb.Content = $label
  $cb.Style = $HUBUI.win.Resources['Switch']
  $cb.IsChecked = $on
  $cb.Tag = $key
  $cb.Add_Click({ param($sender) Hub-Flip $sender.Tag ([bool]$sender.IsChecked) })
  [void]$parent.Children.Add($cb)
}

function Hub-Flip([string]$key, [bool]$on) {
  if ($key -eq 'startup') { Set-StartWithWindows $on; return }
  if ($HUB_NUDGES.Contains($key)) { $v = 0; if ($on) { $v = $HUB_NUDGES[$key][1] }; Set-Setting $key $v; return }
  Set-Setting $key $on
  Apply-Settings
  if ($key -eq 'focus') { if ($on) { Say 'Focus mode. I''ll be quiet.' 2 $true } else { Say 'Focus mode off!' 2 } }
}

# A thin bar, 0..100.
function Hub-Meter($parent, [string]$label, [double]$value, [string]$color) {
  $grid = [Windows.Controls.Grid]::new()
  $grid.Margin = '0,0,0,8'
  foreach ($gl in @([Windows.GridLength]::new(92), [Windows.GridLength]::new(1, 'Star'), [Windows.GridLength]::new(40))) {
    $cd = [Windows.Controls.ColumnDefinition]::new(); $cd.Width = $gl; [void]$grid.ColumnDefinitions.Add($cd)
  }
  $name = [Windows.Controls.TextBlock]::new(); $name.Text = $label; $name.FontSize = 12; $name.Foreground = Hub-Brush '#D9D3E6'
  $track = [Windows.Controls.Border]::new(); $track.Height = 6; $track.CornerRadius = '3'; $track.Background = Hub-Brush '#3A3450'; $track.VerticalAlignment = 'Center'
  [Windows.Controls.Grid]::SetColumn($track, 1)
  $fill = [Windows.Controls.Border]::new(); $fill.CornerRadius = '3'; $fill.Background = Hub-Brush $color; $fill.HorizontalAlignment = 'Left'
  $fill.Width = 1.5 * [Math]::Max(0, [Math]::Min(100, $value))
  $track.Width = 150
  $track.HorizontalAlignment = 'Left'
  $track.Child = $fill
  $pct = [Windows.Controls.TextBlock]::new(); $pct.Text = "$([int]$value)%"; $pct.FontSize = 11; $pct.Foreground = Hub-Brush '#9C95B3'; $pct.HorizontalAlignment = 'Right'
  [Windows.Controls.Grid]::SetColumn($pct, 2)
  [void]$grid.Children.Add($name); [void]$grid.Children.Add($track); [void]$grid.Children.Add($pct)
  [void]$parent.Children.Add($grid)
}

# ------------------------------------------------------------------ the tabs --

function Hub-Home {
  $today = Hub-Card 'Today'
  [void](Hub-Live $today { Summary-Text $TRK.stats })
  $row = Hub-Wrap $today
  [void](Hub-Button $row '🌱 How am I doing?' { How-AmI })

  $live = Is-Connected
  $claude = Hub-Card 'Claude'
  if (-not $live) { [void](Hub-Text $claude 'Open Claude Code and these wake up.' '#9C95B3' 12) }
  $row = Hub-Wrap $claude
  foreach ($m in @(@('Opus', 'opus'), @('Sonnet', 'sonnet'), @('Haiku', 'haiku'), @('Fable', 'fable'))) {
    $look = 'Chip'; if ($S.model -match $m[1]) { $look = 'On' }
    [void](Hub-Button $row $m[0] { param($b) Send "model $($b.DataContext[1])"; Say "Switching to $($b.DataContext[0])..." 3 } $look $m $live)
  }
  $row = Hub-Wrap $claude
  $ctx = '🧹 Compact'; if ($null -ne $S.percent) { $ctx = "🧹 Compact ($([Math]::Round($S.percent))%)" }
  [void](Hub-Button $row $ctx { Send 'compact' } 'Chip' $null $live)
  foreach ($r in @(@('✨ New session', 'new'), @('📊 Panel', 'panel'))) {
    [void](Hub-Button $row $r[0] { param($b) Send "run $($b.DataContext)"; Say 'On it!' 2 } 'Chip' $r[1] $live)
  }

  $askCard = Hub-Card 'Ask'
  $row = Hub-Wrap $askCard
  [void](Hub-Button $row '💬 Ask Claude…' { Ask-Claude } 'Accent' $null $live $true)
  if ($ASK.last) { [void](Hub-Button $row '📋 Copy last answer' { [Windows.Clipboard]::SetText($ASK.last); Say 'Copied! 📋' 1.5 $true }) }
  [void](Hub-Text $askCard 'From your clipboard' '#8E86A8' 11)
  $row = Hub-Wrap $askCard
  foreach ($c in @(@('Explain', 'explain'), @('Summarise', 'summarise'), @('Find the bug', 'fix'))) {
    [void](Hub-Button $row $c[0] { param($b) Clipboard-Ask $b.DataContext } 'Chip' $c[1] $live)
  }
  [void](Hub-Button $row '{ } Format JSON' { Clipboard-FormatJson })
  [void](Hub-Button $row '✂ Trim' { Clipboard-Trim })
  [void](Hub-Text $askCard 'Tip: drop a file on Clawd for a summary.' '#8E86A8' 11)
}

function Hub-PomoClock {
  if (-not $POMO.phase) { return "$($SET.pomodoroWork):00" }
  $left = [Math]::Max(0, $POMO.left)
  return ('{0:00}:{1:00}' -f [Math]::Floor($left / 60), [Math]::Floor($left % 60))
}

function Hub-PomoWhat {
  if (-not $POMO.phase) { return "Ready when you are · $($POMO.done) done today" }
  $what = @{ work = 'Focusing'; break = 'Short break'; long = 'Long break' }[$POMO.phase]
  if ($POMO.paused) { $what += ' (paused)' }
  return "$what · #$($POMO.done + 1)"
}

function Hub-Focus {
  $pomoCard = Hub-Card 'Pomodoro'
  $bigTime = Hub-Live $pomoCard { Hub-PomoClock } '#F3EEFA' 34
  $bigTime.FontWeight = 'Light'; $bigTime.Margin = '0,-4,0,0'
  [void](Hub-Live $pomoCard { Hub-PomoWhat } '#9C95B3' 11.5)
  $row = Hub-Wrap $pomoCard
  if (-not $POMO.phase) {
    [void](Hub-Button $row '▶ Start' { Start-Pomodoro 'work' } 'Accent')
  } else {
    $label = '⏸ Pause'; if ($POMO.paused) { $label = '▶ Resume' }
    [void](Hub-Button $row $label { $POMO.paused = -not $POMO.paused } 'Accent')
    [void](Hub-Button $row '⏭ Skip' { $POMO.left = 0 })
    [void](Hub-Button $row '⏹ Stop' { Stop-Pomodoro })
  }
  $row = Hub-Wrap $pomoCard
  foreach ($len in @(@(25, 5), @(50, 10), @(15, 3))) {
    $look = 'Chip'; if ([int]$SET.pomodoroWork -eq $len[0]) { $look = 'On' }
    [void](Hub-Button $row "$($len[0])/$($len[1])" { param($b) Set-Setting 'pomodoroWork' $b.DataContext[0]; Set-Setting 'pomodoroBreak' $b.DataContext[1] } $look $len)
  }

  $quiet = Hub-Card ''
  Hub-Switch $quiet '🤫 Focus mode: quiet, no tricks' 'focus' ([bool]$S.focus)

  $remCard = Hub-Card 'Reminders'
  $list = @($REM.list | Sort-Object { $_.at })
  if (-not $list.Count) { [void](Hub-Text $remCard 'Nothing yet. Try "in 20m stretch" or "at 15:30 standup".' '#9C95B3' 12) }
  foreach ($r in $list) {
    $row = Hub-Wrap $remCard
    [void](Hub-Button $row '✕' { param($b) [void]$REM.list.Remove($b.DataContext); Save-Reminders } 'Ghost' $r $true $false 'Remove')
    $t = Hub-Text $row "$($r.at.ToString('ddd HH:mm'))  $($r.text)" '#D9D3E6' 12.5
    $t.VerticalAlignment = 'Center'; $t.Margin = '4,0,0,6'
  }
  $row = Hub-Wrap $remCard
  [void](Hub-Button $row '＋ Remind me…' { Ask-Reminder } 'Chip' $null $true $true)

  if ($SET.meetings) {
    $calCard = Hub-Card 'Meetings today'
    $next = @($CAL.items | Where-Object { $_.start -gt (Get-Date) })
    if (-not $next.Count) { [void](Hub-Text $calCard 'Nothing coming up (from Outlook).' '#9C95B3' 12) }
    foreach ($a in $next) { [void](Hub-Text $calCard "$($a.start.ToString('HH:mm'))  $($a.subject)") }
  }
}

function Hub-Play {
  $me = Hub-Card 'Clawd'
  Hub-Meter $me '🍤 Full' $GAME.hunger '#E8957A'
  Hub-Meter $me '💛 Happy' $GAME.happy '#F2C46D'
  $row = Hub-Wrap $me
  foreach ($f in $FOODS) { [void](Hub-Button $row $f.label { param($b) Feed $b.DataContext } 'Chip' $f) }

  $tricks = Hub-Card 'Tricks'
  $row = Hub-Wrap $tricks
  foreach ($t in $HUB_TRICKS.Keys) { [void](Hub-Button $row $t $HUB_TRICKS[$t]) }

  $games = Hub-Card 'Games'
  $row = Hub-Wrap $games
  [void](Hub-Button $row '🐛 Catch the bug' { Start-BugGame } 'Accent' $null $true $true)
  [void](Hub-Button $row '🏃 Tag' { Start-Tag })

  $ach = Hub-Card "Achievements · $($GAME.achievements.Count)/$($ACHIEVEMENTS.Count)"
  $row = Hub-Wrap $ach
  foreach ($k in $ACHIEVEMENTS.Keys) {
    $a = $ACHIEVEMENTS[$k]
    $got = $GAME.achievements.ContainsKey($k)
    $tb = [Windows.Controls.TextBlock]::new()
    $tb.FontSize = 18; $tb.Margin = '0,0,8,6'; $tb.Cursor = 'Help'
    if ($got) { $tb.Text = $a.icon; $tb.ToolTip = "$($a.label) · $($GAME.achievements[$k])" }
    else { $tb.Text = '🔒'; $tb.Opacity = 0.35; $tb.ToolTip = $a.label }
    [void]$row.Children.Add($tb)
  }
}

function Hub-Style {
  $pick = Hub-Card 'Wardrobe'
  $row = Hub-Wrap $pick
  $look = 'Chip'; if ($S.outfitChoice -eq 'daily') { $look = 'On' }
  [void](Hub-Button $row '🎲 Surprise me daily' { Wear-Outfit 'daily' $true; Show-Off } $look)
  $look = 'Chip'; if ($S.outfitChoice -eq 'none') { $look = 'On' }
  [void](Hub-Button $row '🦀 None' { Wear-Outfit 'none' $true; Say 'Au naturel 🦀' 2 } $look)
  [void](Hub-Button $row '✏ Make one…' { Show-OutfitEditor } 'Chip' $null $true $true)
  foreach ($g in $OUTFIT_GROUPS) {
    $keys = @($OUTFITS.Keys | Where-Object { $OUTFITS[$_].group -eq $g })
    if (-not $keys.Count) { continue }
    $group = Hub-Card $g
    $row = Hub-Wrap $group
    foreach ($k in $keys) {
      $need = Outfit-Unlock $k
      $look = 'Chip'; if ($S.outfit -eq $k) { $look = 'On' }
      $label = $OUTFITS[$k].label
      if ($need -gt 0) { $label = "🔒 $label · Lv $need" }
      [void](Hub-Button $row $label { param($b) Wear-Outfit $b.DataContext $true; Show-Off } $look $k ($need -le 0))
    }
  }
}

function Hub-Setup {
  $me = Hub-Card 'Clawd'
  Hub-Switch $me '🔊 Sound cues' 'sound' ([bool]$SET.sound)
  Hub-Switch $me '🗣 Read alerts aloud' 'tts' ([bool]$SET.tts)
  Hub-Switch $me '🗔 Sit on windows' 'perch' ([bool]$SET.perch)
  Hub-Switch $me '🎃 Holiday outfits' 'seasonal' ([bool]$SET.seasonal)
  Hub-Switch $me '🌦 Weather' 'weather' ([bool]$SET.weather)
  Hub-Switch $me '📅 Meeting alerts (Outlook)' 'meetings' ([bool]$SET.meetings)
  Hub-Switch $me '🎬 Hide during fullscreen apps' 'autoHide' ([bool]$SET.autoHide)
  Hub-Switch $me '🚀 Start with Windows' 'startup' ([IO.File]::Exists($StartupLink))

  $nudgeCard = Hub-Card 'Gentle nudges'
  foreach ($k in $HUB_NUDGES.Keys) { Hub-Switch $nudgeCard $HUB_NUDGES[$k][0] $k ([double]$SET[$k] -gt 0) }

  $sizeCard = Hub-Card 'Size and see-through'
  $row = Hub-Wrap $sizeCard
  foreach ($v in @(0.6, 0.8, 1.0, 1.25, 1.5, 2.0)) {
    $style = 'Chip'; if ([double]$SET.scale -eq $v) { $style = 'On' }
    [void](Hub-Button $row "$([int]($v * 100))%" { param($b) Set-Setting 'scale' $b.DataContext; Apply-Settings } $style $v)
  }
  $row = Hub-Wrap $sizeCard
  foreach ($v in @(0.4, 0.6, 0.8, 1.0)) {
    $style = 'Chip'; if ([double]$SET.opacity -eq $v) { $style = 'On' }
    [void](Hub-Button $row "◐ $([int]($v * 100))%" { param($b) Set-Setting 'opacity' $b.DataContext; Apply-Settings } $style $v)
  }

  $data = Hub-Card 'Your data'
  Hub-Switch $data '📈 Track my productivity (whole PC)' 'tracking' ([bool]$SET.tracking)
  Hub-Switch $data '🏷 Also record window titles' 'trackTitles' ([bool]$SET.trackTitles)
  [void](Hub-Text $data 'Stays on this PC, in ~\.claude\clawd-pet.' '#8E86A8' 11)
  $row = Hub-Wrap $data
  [void](Hub-Button $row '🗑 Delete today' { Forget-Today })
  [void](Hub-Button $row '📂 Open folder' { Start-Process explorer.exe $petDir })
}

# ----------------------------------------------------------- open and close --

function Hub-Greeting {
  $h = (Get-Date).Hour
  if ($h -lt 5) { return 'Up late? 🌙' }
  if ($h -lt 12) { return 'Good morning ☀' }
  if ($h -lt 18) { return 'Good afternoon 🌤' }
  return 'Good evening 🌙'
}

function Refresh-HubLive {
  $hw = $HUBUI.win
  if (-not $hw) { return }
  $lvl = Level-Of $GAME.xp
  $from = Xp-For $lvl; $to = Xp-For ($lvl + 1)
  $streak = ''; if ($GAME.streak -ge 1) { $streak = " · 🔥 $($GAME.streak)-day streak" }
  $HUBUI.title.Text = Hub-Greeting
  $HUBUI.sub.Text = "Clawd · Lv $lvl · $($GAME.xp)/$to XP$streak"
  $width = $HUBUI.xpTrack.ActualWidth; if ($width -le 0) { $width = 312 }
  $HUBUI.xpFill.Width = $width * [Math]::Max(0, [Math]::Min(1, ($GAME.xp - $from) / [Math]::Max(1, $to - $from)))
  $live = Is-Connected
  if ($live) {
    $ctx = ''; if ($null -ne $S.percent) { $ctx = " · context $([Math]::Round($S.percent))%" }
    $model = $S.model; if (-not $model) { $model = 'Claude' }
    $HUBUI.status.Text = "● $model$ctx · $($S.mood)"
    $HUBUI.status.Foreground = Hub-Brush '#8FD3B6'
  } else {
    $HUBUI.status.Text = '○ Claude Code isn''t open, I''m just hanging out'
    $HUBUI.status.Foreground = Hub-Brush '#9C95B3'
  }
  foreach ($l in $HUBUI.live) { try { $l.tb.Text = [string](& $l.get) } catch { } }
  # Claude came or went: the Home buttons change.
  if ($live -ne $HUBUI.connected) { $HUBUI.connected = $live; if ($HUBUI.tab -eq 'home') { Show-HubTab 'home' } }
}

function Show-HubTab([string]$key) {
  if (-not $HUBUI.win) { return }
  $HUBUI.tab = $key
  $offset = $HUBUI.scroll.VerticalOffset
  $same = ($HUBUI.shown -eq $key)
  $HUBUI.live.Clear()
  $HUBUI.body.Children.Clear()
  switch ($key) {
    'home' { Hub-Home }
    'focus' { Hub-Focus }
    'play' { Hub-Play }
    'style' { Hub-Style }
    'setup' { Hub-Setup }
  }
  $HUBUI.shown = $key
  # Redrawn after a click: stay where you were.
  if ($same) { $HUBUI.win.UpdateLayout(); $HUBUI.scroll.ScrollToVerticalOffset($offset) } else { $HUBUI.scroll.ScrollToTop() }
}

# Beside Clawd (left if there's room), on Clawd's screen.
function Place-Hub {
  $hw = $HUBUI.win
  $k = $S.scale
  $cx = $win.Left + $win.Width / 2
  $area = [Windows.Forms.Screen]::FromPoint([Drawing.Point]::new([int]($cx * $k), [int](($win.Top + $win.Height / 2) * $k))).WorkingArea
  $l = $area.Left / $k; $t = $area.Top / $k; $r = $area.Right / $k; $b = $area.Bottom / $k
  $hwW = $hw.ActualWidth; if ($hwW -le 0) { $hwW = $hw.Width }
  $hwH = $hw.ActualHeight; if ($hwH -le 0) { $hwH = 560 }
  $gap = $ART_W / 2 * [double]$WORLD.k + 4
  $left = $cx - $gap - $hwW
  if ($left -lt $l) { $left = $cx + $gap }
  $hw.Left = [Math]::Max($l, [Math]::Min($r - $hwW, $left))
  $hw.Top = [Math]::Max($t, [Math]::Min($b - $hwH, $win.Top + $win.Height - $hwH + 14))
}

function Open-Hub {
  if ($HUBUI.win) { [void]$HUBUI.win.Activate(); return }
  $hw = [Windows.Markup.XamlReader]::Parse($HUB_XAML)
  $HUBUI.win = $hw
  $HUBUI.closing = $false
  $HUBUI.moved = $false
  $HUBUI.shown = ''
  $HUBUI.connected = Is-Connected
  foreach ($n in @('Body', 'Scroll', 'Title', 'Sub', 'Status', 'XpFill', 'XpTrack', 'Tabs', 'Shell', 'Head')) { $HUBUI[$n.ToLower()] = $hw.FindName($n) }

  foreach ($k in $HUB_TABS.Keys) {
    $rb = [Windows.Controls.RadioButton]::new()
    $rb.Content = $HUB_TABS[$k]; $rb.Tag = $k; $rb.GroupName = 'hubTabs'
    $rb.Style = $hw.Resources['Tab']
    $rb.IsChecked = ($k -eq $HUBUI.tab)
    $rb.Add_Checked({ param($sender) Show-HubTab $sender.Tag })
    [void]$HUBUI.tabs.Children.Add($rb)
  }
  $hw.FindName('CloseBtn').Add_Click({ Hub-Close })
  $hw.FindName('MoreBtn').Add_Click({ Hub-Close; Open-FullMenu })
  $hw.FindName('NapBtn').Add_Click({ Hub-Close; Hide-For 60 })
  $hw.FindName('ByeBtn').Add_Click({ Hub-Close; Send 'hide'; $win.Close() })
  $HUBUI.head.Add_MouseLeftButtonDown({ $HUBUI.moved = $true; try { $HUBUI.win.DragMove() } catch { } })
  $hw.Add_KeyDown({ param($sender, $e) if ($e.Key -eq 'Escape') { Hub-Close } })
  $hw.Add_Deactivated({ Hub-Close })
  $hw.Add_Closed({ $HUBUI.win = $null; $HUBUI.closing = $false; $HUBUI.live.Clear() })
  $hw.Add_Loaded({
    Place-Hub
    # A soft fade and float in.
    $ms = [Windows.Duration]::new([TimeSpan]::FromMilliseconds(200))
    $HUBUI.shell.BeginAnimation([Windows.UIElement]::OpacityProperty, [Windows.Media.Animation.DoubleAnimation]::new(0, 1, $ms))
    $ease = [Windows.Media.Animation.DoubleAnimation]::new(10, 0, $ms)
    $ease.EasingFunction = [Windows.Media.Animation.CubicEase]::new()
    $HUBUI.shell.RenderTransform.BeginAnimation([Windows.Media.TranslateTransform]::YProperty, $ease)
  })
  $hw.Add_SizeChanged({ if (-not $HUBUI.moved) { Place-Hub } })

  Show-HubTab $HUBUI.tab
  Refresh-HubLive
  $hw.Show()
  [void]$hw.Activate()
  Float '♪' $ORANGE 14 1.0
}

function Hub-Close {
  $hw = $HUBUI.win
  if (-not $hw -or $HUBUI.closing) { return }
  $HUBUI.closing = $true
  try { $hw.Close() } catch { }
}

function Toggle-Hub {
  if ($HUBUI.win) { Hub-Close } else { Open-Hub }
}

# The classic right-click menu, on demand.
function Open-FullMenu {
  Build-Menu
  $menu.PlacementTarget = $body
  $menu.Placement = 'MousePoint'
  $menu.IsOpen = $true
}

function Tick-Hub([double]$dt) {
  if (-not $HUBUI.win) { return }
  $HUBUI.since += $dt
  if ($HUBUI.since -lt 0.5) { return }
  $HUBUI.since = 0
  Refresh-HubLive
}
