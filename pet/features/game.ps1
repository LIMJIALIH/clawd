# ---------------------------------------------------------------- the game --
# XP and levels from real work (turns, commits, pomodoros...), hunger and happiness, a daily
# streak, achievements, and two little games. All in game.json, which only the pet writes.

$GameFile = Join-Path $petDir 'game.json'
$GAME = @{
  xp = 0; hunger = 80.0; happy = 80.0; streak = 0; streakDay = ''; achievements = @{}; counts = @{}
  lastDecayAt = ''; since = 0.0; sinceSave = 0.0; askedFood = 0.0; petsThisMinute = 0
  tagUntil = 0.0; tagScore = 0; tagCool = 0.0
}
$FOODS = @(
  @{ label = 'Shrimp 🍤'; hunger = 30; happy = 5; line = 'Nom nom nom! 🍤' }
  @{ label = 'Cookie 🍪'; hunger = 15; happy = 10; line = 'Crunchy! 🍪' }
  @{ label = 'Coffee ☕'; hunger = 5; happy = 15; line = 'Ahh, fuel for code ☕'; sip = $true }
  @{ label = 'Kaya toast 🍞'; hunger = 25; happy = 10; line = 'Sedap! 🍞' }
)
$ACHIEVEMENTS = [ordered]@{
  first_commit = @{ label = 'First commit'; icon = '📦' }
  first_mr = @{ label = 'First merge request'; icon = '🔀' }
  streak_3 = @{ label = '3-day streak'; icon = '🔥' }
  streak_7 = @{ label = '7-day streak'; icon = '🔥' }
  streak_30 = @{ label = '30-day streak'; icon = '🌋' }
  deep_work = @{ label = '4 hours of focus in a day'; icon = '🧠' }
  tools_100 = @{ label = '100 Claude tool calls in a day'; icon = '🛠️' }
  prompts_50 = @{ label = '50 prompts in a day'; icon = '💬' }
  pomodoro_10 = @{ label = '10 pomodoros'; icon = '🍅' }
  early_bird = @{ label = 'Working before 8am'; icon = '🐦' }
  night_owl = @{ label = 'Working after 11pm'; icon = '🦉' }
  well_fed = @{ label = 'Fed Clawd 10 times'; icon = '🍤' }
  bug_hunter = @{ label = 'Caught 20 bugs in one game'; icon = '🐛' }
  level_5 = @{ label = 'Reached level 5'; icon = '⭐' }
  level_10 = @{ label = 'Reached level 10'; icon = '🌟' }
}
# Outfits that wait for a level; anything not here is free.
$UNLOCKS = @{ chef = 2; graduate = 3; knight = 4; halo = 5; dragon = 7 }

function Level-Of([int]$xp) { return [int][Math]::Floor([Math]::Sqrt($xp / 50)) }
function Xp-For([int]$level) { return 50 * $level * $level }

function Outfit-Unlock([string]$key) {
  $need = [int]$UNLOCKS[$key]
  if ($need -gt (Level-Of $GAME.xp)) { return $need }
  return 0
}

function Load-Game {
  try {
    $g = [IO.File]::ReadAllText($GameFile) | ConvertFrom-Json
    $GAME.xp = [int]$g.xp; $GAME.hunger = [double]$g.hunger; $GAME.happy = [double]$g.happy
    $GAME.streak = [int]$g.streak; $GAME.streakDay = [string]$g.streakDay; $GAME.lastDecayAt = [string]$g.lastDecayAt
    foreach ($p in $g.achievements.PSObject.Properties) { $GAME.achievements[$p.Name] = [string]$p.Value }
    foreach ($p in $g.counts.PSObject.Properties) { $GAME.counts[$p.Name] = [int]$p.Value }
  } catch { }
  # Time away: hungrier, but never more than 20 points for however long Clawd was gone.
  if ($GAME.lastDecayAt) {
    try {
      $hrs = ((Get-Date) - [DateTime]::Parse($GAME.lastDecayAt)).TotalHours
      $GAME.hunger = [Math]::Max(5, $GAME.hunger - [Math]::Min(20, $hrs * 3))
      $GAME.happy = [Math]::Max(5, $GAME.happy - [Math]::Min(20, $hrs * 2))
    } catch { }
  }
}

function Save-Game {
  $GAME.lastDecayAt = (Get-Date).ToString('s')
  $out = [ordered]@{
    xp = $GAME.xp; level = (Level-Of $GAME.xp); hunger = [Math]::Round($GAME.hunger, 1); happy = [Math]::Round($GAME.happy, 1)
    streak = $GAME.streak; streakDay = $GAME.streakDay; lastDecayAt = $GAME.lastDecayAt
    achievements = $GAME.achievements; counts = $GAME.counts
  }
  try { [IO.File]::WriteAllText($GameFile, ($out | ConvertTo-Json -Depth 3)) } catch { }
}

function Add-Xp([int]$n, [string]$why) {
  if ($n -le 0) { return }
  $before = Level-Of $GAME.xp
  $GAME.xp += $n
  $after = Level-Of $GAME.xp
  if ($after -gt $before) {
    Confetti 18
    if (-not $S.air -and -not $S.sky) { Start-Backflip }
    $new = @($UNLOCKS.Keys | Where-Object { $UNLOCKS[$_] -eq $after -and $OUTFITS.Contains($_) } | ForEach-Object { $OUTFITS[$_].label })
    $extra = ''; if ($new.Count) { $extra = " Unlocked: $($new -join ', ')!" }
    Say "Level $after! ⭐$extra" 6 $true
    Send "toast Clawd reached level $after!$extra"
    if ($after -ge 5) { Award 'level_5' }
    if ($after -ge 10) { Award 'level_10' }
  }
  Save-Game
}

function Award([string]$id) {
  if ($GAME.achievements.ContainsKey($id) -or -not $ACHIEVEMENTS.Contains($id)) { return }
  $GAME.achievements[$id] = (Get-Date).ToString('yyyy-MM-dd')
  $a = $ACHIEVEMENTS[$id]
  Confetti 12
  Say "🏆 $($a.icon) $($a.label)!" 6 $true
  Send "toast 🏆 Achievement: $($a.label)"
  $GAME.xp += 25
  Save-Game
}

function Game-Count([string]$what) {
  $GAME.counts[$what] = [int]$GAME.counts[$what] + 1
  switch ($what) {
    'commit' { Award 'first_commit' }
    'mr' { Award 'first_mr' }
    'pomodoro' { if ($GAME.counts.pomodoro -ge 10) { Award 'pomodoro_10' } }
    'fed' { if ($GAME.counts.fed -ge 10) { Award 'well_fed' } }
  }
  Save-Game
}

function Game-Petted {
  if ($GAME.petsThisMinute -ge 5) { return }
  $GAME.petsThisMinute++
  $GAME.happy = [Math]::Min(100, $GAME.happy + 3)
}

function Feed($food) {
  $GAME.hunger = [Math]::Min(100, $GAME.hunger + $food.hunger)
  $GAME.happy = [Math]::Min(100, $GAME.happy + $food.happy)
  Float ($food.label -split ' ')[-1] $ORANGE 18 1.5
  if ($food.sip) { Start-Action 'sip' 4 } else { Start-Action 'dance' 2 }
  Say $food.line 3 $true
  Game-Count 'fed'
}

# What the day's numbers earn: the streak (30 active minutes counts the day) and achievements.
# (Never a local named $s in these files: PowerShell names ignore case, and Say would see it as $S.)
function Game-CheckStats($day) {
  if (-not $day) { return }
  $today = Today-Key
  if ($day.activeMin -ge 30 -and $GAME.streakDay -ne $today) {
    if ($GAME.streakDay -eq (Get-Date).AddDays(-1).ToString('yyyy-MM-dd')) { $GAME.streak++ } else { $GAME.streak = 1 }
    $GAME.streakDay = $today
    if ($GAME.streak -gt 1) { Say "🔥 $($GAME.streak)-day streak!" 4 }
    if ($GAME.streak -ge 3) { Award 'streak_3' }
    if ($GAME.streak -ge 7) { Award 'streak_7' }
    if ($GAME.streak -ge 30) { Award 'streak_30' }
    Save-Game
  }
  if ($day.activeMin -ge 240) { Award 'deep_work' }
  if ($day.claude.toolCalls -ge 100) { Award 'tools_100' }
  if ($day.claude.prompts -ge 50) { Award 'prompts_50' }
  if ($day.firstAt -and $day.firstAt -lt '08:00') { Award 'early_bird' }
  if ($day.lastAt -and $day.lastAt -ge '23:00') { Award 'night_owl' }
}

function Game-NewDay { Save-Game }

function Tick-Game([double]$dt) {
  $GAME.since += $dt
  if ($GAME.since -ge 60) {
    $GAME.since = 0
    $GAME.petsThisMinute = 0
    $GAME.hunger = [Math]::Max(0, $GAME.hunger - 0.1)
    $GAME.happy = [Math]::Max(0, $GAME.happy - 0.05)
    Save-Game
  }
  # Hungry or blue: say so, now and then, unless it's a bad time.
  $GAME.askedFood += $dt
  if ($GAME.askedFood -ge 600 -and -not $S.focus -and -not $POMO.phase -and $S.mood -ne 'working') {
    if ($GAME.hunger -lt 25) { $GAME.askedFood = 0; Say 'I''m hungry... 🍤? (right-click → Clawd → Feed)' 5; Float '🍤' $ORANGE 16 1.6 }
    elseif ($GAME.happy -lt 25) { $GAME.askedFood = 0; Say 'Pet me? 🥺' 4 }
  }
  Tick-Tag $dt
}

# --------------------------------------------------------------- tag ------
# Clawd runs from the cursor for 20 seconds; touch them to score.

function Start-Tag {
  $GAME.tagUntil = $clock.Elapsed.TotalSeconds + 20
  $GAME.tagScore = 0
  Say 'Catch me if you can! 🏃' 2 $true
  Start-Action 'flee' 20
}

function Tick-Tag([double]$dt) {
  if ($GAME.tagUntil -le 0) { return }
  $now = $clock.Elapsed.TotalSeconds
  if ($now -ge $GAME.tagUntil) {
    $GAME.tagUntil = 0
    Start-Action 'idle' 1
    Say "Tag over! You caught me $($GAME.tagScore) times." 4 $true
    Add-Xp ($GAME.tagScore * 3) 'tag'
    return
  }
  if ($S.air -or $S.sky -or $S.dragging) { return }
  if ($S.action -ne 'flee') { Start-Action 'flee' 20 }
  $c = Cursor-Dip
  $dx = $S.x - $c.X
  $S.face = 1; if ($dx -lt 0) { $S.face = -1 }
  $S.x = [Math]::Max($S.left, [Math]::Min($S.right, $S.x + $S.face * $RUN * 1.1 * $dt))
  # Cornered: jump over the cursor.
  if (($S.x -le $S.left -or $S.x -ge $S.right) -and [Math]::Abs($dx) -lt 120) { $S.face = -$S.face; Hop 700 260 }
  $GAME.tagCool -= $dt
  if ($GAME.tagCool -le 0 -and [Math]::Abs($dx) -lt 36 -and ($S.y - $c.Y) -lt 60 -and ($S.y - $c.Y) -gt -10) {
    $GAME.tagScore++
    $GAME.tagCool = 1.2
    Float '!' $ORANGE 18 0.8
    Say "Tagged! ($($GAME.tagScore))" 1.5 $true
    Start-Teleport
  }
}

# ------------------------------------------------------- catch the bug ------
# A see-through window over the whole screen; bugs fall, a crab under the mouse catches them.

function Start-BugGame {
  $area = [Windows.Forms.Screen]::FromPoint([Windows.Forms.Cursor]::Position).WorkingArea
  $sc = $S.scale
  $gw = [Windows.Window]::new()
  $gw.WindowStyle = 'None'; $gw.AllowsTransparency = $true; $gw.Topmost = $true; $gw.ShowInTaskbar = $false
  $gw.Background = [Windows.Media.BrushConverter]::new().ConvertFromString('#22000000')
  $gw.Left = $area.Left / $sc; $gw.Top = $area.Top / $sc; $gw.Width = $area.Width / $sc; $gw.Height = $area.Height / $sc
  $canvas = [Windows.Controls.Canvas]::new()
  $gw.Content = $canvas
  $catcher = [Windows.Shapes.Rectangle]::new(); $catcher.Width = 96; $catcher.Height = 26; $catcher.Fill = $ORANGE; $catcher.RadiusX = 6; $catcher.RadiusY = 6
  [void]$canvas.Children.Add($catcher)
  $label = [Windows.Controls.TextBlock]::new(); $label.FontSize = 22; $label.FontWeight = 'Bold'; $label.Foreground = [Windows.Media.Brushes]::White
  [Windows.Controls.Canvas]::SetLeft($label, 20); [Windows.Controls.Canvas]::SetTop($label, 16)
  [void]$canvas.Children.Add($label)
  $g = @{ win = $gw; canvas = $canvas; catcher = $catcher; label = $label; bugs = [Collections.ArrayList]::new(); score = 0; left = 30.0; spawn = 0.0; last = 0.0; clock = [Diagnostics.Stopwatch]::StartNew(); rand = [Random]::new() }
  $timer = [Windows.Threading.DispatcherTimer]::new()
  $timer.Interval = [TimeSpan]::FromMilliseconds(16)
  $g.timer = $timer
  # Not closures: those cannot see this script's functions. The game lives in $GAME.bugGame.
  $timer.Add_Tick({ try { Step-BugGame $GAME.bugGame } catch { $GAME.bugGame.timer.Stop(); $GAME.bugGame.win.Close() } })
  $gw.Add_KeyDown({ param($sender, $e) if ($e.Key -eq 'Escape') { $GAME.bugGame.left = 0 } })
  $gw.Add_Closed({ $GAME.bugGame.timer.Stop() })
  $GAME.bugGame = $g
  $gw.Show(); [void]$gw.Activate()
  $timer.Start()
  Say 'Catch the bugs! 🐛 (Esc to stop)' 3 $true
}

function Step-BugGame($g) {
  $now = $g.clock.Elapsed.TotalSeconds
  $dt = [Math]::Min(0.05, $now - $g.last); $g.last = $now
  $g.left -= $dt
  $gameW = $g.win.ActualWidth; $gameH = $g.win.ActualHeight
  $m = [Windows.Input.Mouse]::GetPosition($g.canvas)
  $cx = [Math]::Max(0, [Math]::Min($gameW - 96, $m.X - 48)); $cy = $gameH - 60
  [Windows.Controls.Canvas]::SetLeft($g.catcher, $cx); [Windows.Controls.Canvas]::SetTop($g.catcher, $cy)
  $g.label.Text = "🐛 $($g.score)    ⏱ $([Math]::Ceiling([Math]::Max(0, $g.left)))s"
  $g.spawn -= $dt
  if ($g.spawn -le 0 -and $g.left -gt 0) {
    $g.spawn = [Math]::Max(0.25, 0.9 - (30 - $g.left) * 0.02)
    $tb = [Windows.Controls.TextBlock]::new(); $tb.Text = '🐛'; $tb.FontSize = 28
    $x = $g.rand.Next(20, [int][Math]::Max(40, $gameW - 40))
    [void]$g.canvas.Children.Add($tb)
    [void]$g.bugs.Add(@{ el = $tb; x = [double]$x; y = -30.0; vy = 140.0 + $g.rand.Next(160) + (30 - $g.left) * 6 })
  }
  for ($i = $g.bugs.Count - 1; $i -ge 0; $i--) {
    $b = $g.bugs[$i]
    $b.y += $b.vy * $dt
    [Windows.Controls.Canvas]::SetLeft($b.el, $b.x); [Windows.Controls.Canvas]::SetTop($b.el, $b.y)
    $caught = $b.y + 28 -ge $cy -and $b.y -le $cy + 26 -and $b.x + 24 -ge $cx -and $b.x -le $cx + 96
    if ($caught -or $b.y -gt $gameH) {
      if ($caught) { $g.score++ }
      $g.canvas.Children.Remove($b.el); $g.bugs.RemoveAt($i)
    }
  }
  if ($g.left -le 0) {
    $g.timer.Stop(); $g.win.Close()
    End-BugGame $g.score
  }
}

function End-BugGame([int]$score) {
  Say "You caught $score bugs! 🐛" 4 $true
  if ($score -ge 20) { Award 'bug_hunter' }
  Game-Count 'games'
  Add-Xp ($score * 2) 'game'
}

function Add-GameMenu($parent) {
  $m = [Windows.Controls.MenuItem]::new()
  $lvl = Level-Of $GAME.xp
  $m.Header = "Clawd ⭐ Lv $lvl"
  $info = Menu-Item ("XP {0}/{1} · 🍤 {2:N0}% · 💛 {3:N0}% · 🔥 {4}" -f $GAME.xp, (Xp-For ($lvl + 1)), $GAME.hunger, $GAME.happy, $GAME.streak) { }
  $info.IsEnabled = $false
  [void]$m.Items.Add($info)
  $feed = [Windows.Controls.MenuItem]::new(); $feed.Header = 'Feed'
  foreach ($f in $FOODS) { $i = Menu-Item $f.label { param($sender) Feed $sender.Tag }; $i.Tag = $f; [void]$feed.Items.Add($i) }
  [void]$m.Items.Add($feed)
  $ach = [Windows.Controls.MenuItem]::new(); $ach.Header = "Achievements ($($GAME.achievements.Count)/$($ACHIEVEMENTS.Count))"
  foreach ($k in $ACHIEVEMENTS.Keys) {
    $a = $ACHIEVEMENTS[$k]
    if ($GAME.achievements.ContainsKey($k)) { $h = "$($a.icon) $($a.label) · $($GAME.achievements[$k])" } else { $h = "🔒 $($a.label)" }
    $i = Menu-Item $h { }
    $i.IsEnabled = $GAME.achievements.ContainsKey($k)
    [void]$ach.Items.Add($i)
  }
  [void]$m.Items.Add($ach)
  [void]$m.Items.Add((Menu-Item 'How am I doing?' { How-AmI }))
  [void]$parent.Items.Add($m)
}

function Add-PlayMenu($parent) {
  $p = [Windows.Controls.MenuItem]::new(); $p.Header = 'Play'
  [void]$p.Items.Add((Menu-Item 'Catch the bug 🐛' { Start-BugGame }))
  [void]$p.Items.Add((Menu-Item 'Tag 🏃' { Start-Tag }))
  [void]$parent.Items.Add($p)
}

# A pep talk from today's numbers and Clawd's own.
function How-AmI {
  $day = $TRK.stats
  $lines = @()
  if ($day -and $day.activeMin -ge 1) { $lines += "Today: $(Summary-Text $day)." }
  if ($day -and $day.activeMin -ge 240) { $lines += 'That''s a big day, remember to rest! 💪' }
  elseif ($day -and $day.activeMin -ge 60) { $lines += 'Solid progress! Keep it up 🚀' }
  else { $lines += 'Every bit counts. Let''s get going! 🌱' }
  if ($GAME.streak -ge 2) { $lines += "🔥 $($GAME.streak)-day streak." }
  Say ($lines -join ' ') 12 $true
}

Load-Game
