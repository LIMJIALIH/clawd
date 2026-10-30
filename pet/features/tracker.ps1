# ------------------------------------------------------------- the tracker --
# Productivity across the whole machine, not one terminal. Two sources, one day:
#  - every Claude Code session, in any terminal, writes its own activity\<day>\<session>.json
#    (the mod; no session writes another's file);
#  - this pet samples the whole PC every 5s: input or idle, and which app is in front, which
#    counts terminals with no Claude in them too. Only process names and seconds are kept
#    (window titles only with trackTitles on), all in ~\.claude\clawd-pet, nothing sent anywhere.
# Once a minute the pet adds them up into stats.json, which /clawd stats, the pane, the 17:30
# summary and the game read.

$ActivityDir = Join-Path $petDir 'activity'
$StatsFile = Join-Path $petDir 'stats.json'
$TrackerFile = Join-Path $petDir 'tracker.json'
[void][IO.Directory]::CreateDirectory($ActivityDir)

$SAMPLE_SECS = 5
$IDLE_MS = 120000
$KEEP_DAYS = 90
$APP_CATEGORIES = [ordered]@{
  terminal = @('WindowsTerminal', 'OpenConsole', 'conhost', 'powershell', 'pwsh', 'cmd', 'wezterm-gui', 'alacritty', 'mintty', 'bash', 'Tabby', 'Hyper', 'putty', 'MobaXterm')
  ide = @('idea64', 'idea', 'Code', 'Cursor', 'devenv', 'eclipse', 'pycharm64', 'webstorm64', 'datagrip64', 'rider64', 'notepad++', 'sublime_text')
  database = @('dbeaver', 'Ssms', 'pgAdmin4', 'sqldeveloper64W', 'sqldeveloper', 'toad', 'DBeaver')
  browser = @('chrome', 'msedge', 'firefox', 'brave', 'opera', 'vivaldi')
  meetings = @('Teams', 'ms-teams', 'Zoom', 'slack', 'Discord', 'webex', 'OUTLOOK', 'olk')
  tools = @('Postman', 'Insomnia', 'GitHubDesktop', 'SourceTree', 'TortoiseProc', 'WinSCP', 'FileZilla')
  docs = @('WINWORD', 'EXCEL', 'POWERPNT', 'ONENOTE', 'Notion', 'Obsidian', 'AcroRd32', 'Acrobat')
}
$APP_LOOKUP = @{}
foreach ($c in $APP_CATEGORIES.Keys) { foreach ($a in $APP_CATEGORIES[$c]) { $APP_LOOKUP[$a.ToLower()] = $c } }

$TRK = @{ day = ''; since = 0.0; sinceSave = 0.0; sinceAgg = 50.0; pidName = @{}; summaryDay = ''; cleanedDay = ''; sys = $null }

function Today-Key { return (Get-Date -Format 'yyyy-MM-dd') }
function Day-Dir([string]$day) { return (Join-Path $ActivityDir $day) }

function New-SysDay([string]$day) {
  return @{ day = $day; activeSec = 0; idleSec = 0; firstAt = ''; lastAt = ''; perApp = @{}; perCategory = @{}; hourly = (New-Object int[] 24); titles = @{} }
}

# Today's PC numbers so far, so a restart carries on instead of starting over.
function Load-SysDay([string]$day) {
  $sys = New-SysDay $day
  try {
    $j = [IO.File]::ReadAllText((Join-Path (Day-Dir $day) 'system.json')) | ConvertFrom-Json
    $sys.activeSec = [int]$j.activeSec; $sys.idleSec = [int]$j.idleSec
    $sys.firstAt = [string]$j.firstAt; $sys.lastAt = [string]$j.lastAt
    foreach ($p in $j.perApp.PSObject.Properties) { $sys.perApp[$p.Name] = [int]$p.Value }
    foreach ($p in $j.perCategory.PSObject.Properties) { $sys.perCategory[$p.Name] = [int]$p.Value }
    if ($j.titles) { foreach ($p in $j.titles.PSObject.Properties) { $sys.titles[$p.Name] = [int]$p.Value } }
    $h = @($j.hourly); for ($i = 0; $i -lt [Math]::Min(24, $h.Count); $i++) { $sys.hourly[$i] = [int]$h[$i] }
  } catch { }
  return $sys
}

function Save-SysDay {
  if (-not $TRK.sys) { return }
  $dir = Day-Dir $TRK.sys.day
  [void][IO.Directory]::CreateDirectory($dir)
  $out = [ordered]@{
    day = $TRK.sys.day; activeSec = $TRK.sys.activeSec; idleSec = $TRK.sys.idleSec
    firstAt = $TRK.sys.firstAt; lastAt = $TRK.sys.lastAt
    perApp = $TRK.sys.perApp; perCategory = $TRK.sys.perCategory; hourly = @($TRK.sys.hourly)
  }
  if ($SET.trackTitles) { $out.titles = $TRK.sys.titles }
  try { [IO.File]::WriteAllText((Join-Path $dir 'system.json'), ($out | ConvertTo-Json -Depth 4 -Compress)) } catch { }
}

function Save-TrackerState {
  try { [IO.File]::WriteAllText($TrackerFile, (@{ summaryDay = $TRK.summaryDay; cleanedDay = $TRK.cleanedDay } | ConvertTo-Json -Compress)) } catch { }
}

function Init-Tracker {
  try {
    $t = [IO.File]::ReadAllText($TrackerFile) | ConvertFrom-Json
    $TRK.summaryDay = [string]$t.summaryDay; $TRK.cleanedDay = [string]$t.cleanedDay
  } catch { }
  $TRK.day = Today-Key
  $TRK.sys = Load-SysDay $TRK.day
}

function App-Of([IntPtr]$hwnd) {
  [uint32]$procId = 0
  [void][ClawdPet.Native]::GetWindowThreadProcessId($hwnd, [ref]$procId)
  if ($procId -eq 0) { return '' }
  if (-not $TRK.pidName.ContainsKey($procId)) {
    if ($TRK.pidName.Count -gt 300) { $TRK.pidName.Clear() }
    $name = ''
    try { $name = (Get-Process -Id $procId -ErrorAction Stop).ProcessName } catch { }
    $TRK.pidName[$procId] = $name
  }
  return $TRK.pidName[$procId]
}

function Category-Of([string]$app) {
  $c = $APP_LOOKUP[$app.ToLower()]
  if ($c) { return $c }
  return 'other'
}

function Sample-Pc {
  $now = Get-Date
  $idle = [ClawdPet.Native]::IdleMs() -ge $IDLE_MS
  $sys = $TRK.sys
  if ($idle) { $sys.idleSec += $SAMPLE_SECS; return }
  $sys.activeSec += $SAMPLE_SECS
  $sys.hourly[$now.Hour] += $SAMPLE_SECS
  $stamp = $now.ToString('HH:mm')
  if (-not $sys.firstAt) { $sys.firstAt = $stamp }
  $sys.lastAt = $stamp
  $hwnd = [ClawdPet.Native]::GetForegroundWindow()
  if ($hwnd -eq [IntPtr]::Zero) { return }
  $app = App-Of $hwnd
  if (-not $app) { return }
  # Clawd's own window counts as nothing.
  if ($app -eq 'powershell' -and $hwnd -eq (New-Object Windows.Interop.WindowInteropHelper $win).Handle) { return }
  $sys.perApp[$app] = [int]$sys.perApp[$app] + $SAMPLE_SECS
  $cat = Category-Of $app
  $sys.perCategory[$cat] = [int]$sys.perCategory[$cat] + $SAMPLE_SECS
  if ($SET.trackTitles -and $sys.titles.Count -lt 300) {
    $sb = New-Object Text.StringBuilder 256
    [void][ClawdPet.Native]::GetWindowText($hwnd, $sb, 256)
    $key = "$app | $($sb.ToString())"
    $sys.titles[$key] = [int]$sys.titles[$key] + $SAMPLE_SECS
  }
}

function Min([double]$secs) { return [Math]::Round($secs / 60, 1) }

# Adds every session's file and the PC's numbers into one day.
function Aggregate-Day([string]$day) {
  $dir = Day-Dir $day
  $claude = [ordered]@{ sessions = 0; prompts = 0; turns = 0; toolCalls = 0; errors = 0; commits = 0; pushes = 0; mrs = 0; tests = 0; activeMin = 0.0 }
  $perProject = @{}
  $tools = @{}
  if ([IO.Directory]::Exists($dir)) {
    foreach ($f in [IO.Directory]::GetFiles($dir, '*.json')) {
      $name = [IO.Path]::GetFileName($f)
      if ($name -eq 'system.json' -or $name -eq '_total.json') { continue }
      try { $a = [IO.File]::ReadAllText($f) | ConvertFrom-Json } catch { continue }
      $claude.sessions++
      foreach ($k in @('prompts', 'turns', 'errors', 'commits', 'pushes', 'mrs', 'tests')) { $claude[$k] += [int]$a.$k }
      foreach ($p in $a.toolCalls.PSObject.Properties) { $claude.toolCalls += [int]$p.Value; $tools[$p.Name] = [int]$tools[$p.Name] + [int]$p.Value }
      $m = [double]$a.activeMs / 60000
      $claude.activeMin += $m
      $proj = [string]$a.project; if (-not $proj) { $proj = 'unknown' }
      $perProject[$proj] = [Math]::Round([double]$perProject[$proj] + $m, 1)
    }
  }
  $claude.activeMin = [Math]::Round($claude.activeMin, 1)
  $sys = $TRK.sys
  if ($sys.day -ne $day) { $sys = Load-SysDay $day }
  $perCategory = @{}; foreach ($k in $sys.perCategory.Keys) { $perCategory[$k] = Min $sys.perCategory[$k] }
  $perApp = @{}
  foreach ($e in ($sys.perApp.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 15)) { $perApp[$e.Key] = Min $e.Value }
  return [ordered]@{
    date = $day
    activeMin = Min $sys.activeSec; idleMin = Min $sys.idleSec
    firstAt = $sys.firstAt; lastAt = $sys.lastAt
    perCategory = $perCategory; perApp = $perApp
    hourlyMin = @($sys.hourly | ForEach-Object { Min $_ })
    claude = $claude; toolCalls = $tools; perProject = $perProject
    updatedAt = (Get-Date).ToString('s')
  }
}

function Write-Stats([string]$day) {
  $stats = Aggregate-Day $day
  $json = $stats | ConvertTo-Json -Depth 4
  try {
    [IO.File]::WriteAllText((Join-Path (Day-Dir $day) '_total.json'), $json)
    if ($day -eq (Today-Key)) { [IO.File]::WriteAllText($StatsFile, $json) }
  } catch { }
  $TRK.stats = $stats
  return $stats
}

function Hours-Text([double]$min) {
  $m = [int][Math]::Round($min)
  if ($m -ge 60) { return ('{0}h{1:00}m' -f [Math]::Floor($m / 60), ($m % 60)) }
  return "${m}m"
}

function Summary-Text($day) {
  if (-not $day) { return 'Nothing tracked yet today.' }
  $parts = @("$(Hours-Text $day.activeMin) active")
  if ($day.perCategory.terminal) { $parts += "$(Hours-Text $day.perCategory.terminal) in terminals" }
  if ($day.perCategory.ide) { $parts += "$(Hours-Text $day.perCategory.ide) in the IDE" }
  $parts += "$($day.claude.prompts) prompts over $($day.claude.sessions) Claude sessions"
  if ($day.claude.commits) { $parts += "$($day.claude.commits) commits" }
  return ($parts -join ', ')
}

function Clean-OldDays {
  $cut = (Get-Date).AddDays(-$KEEP_DAYS).ToString('yyyy-MM-dd')
  foreach ($d in [IO.Directory]::GetDirectories($ActivityDir)) {
    $name = [IO.Path]::GetFileName($d)
    if ($name -match '^\d{4}-\d{2}-\d{2}$' -and $name -lt $cut) { try { [IO.Directory]::Delete($d, $true) } catch { } }
  }
}

function Tick-Tracker([double]$dt) {
  $day = Today-Key
  if ($day -ne $TRK.day) {
    # Midnight: close yesterday out, start today.
    Save-SysDay
    [void](Write-Stats $TRK.day)
    $TRK.day = $day
    $TRK.sys = New-SysDay $day
    Game-NewDay
  }
  if ($TRK.cleanedDay -ne $day) { $TRK.cleanedDay = $day; Clean-OldDays; Save-TrackerState }

  if ($SET.tracking) {
    $TRK.since += $dt
    if ($TRK.since -ge $SAMPLE_SECS) { $TRK.since = 0; Sample-Pc }
    $TRK.sinceSave += $dt
    if ($TRK.sinceSave -ge 60) { $TRK.sinceSave = 0; Save-SysDay }
  }
  $TRK.sinceAgg += $dt
  if ($TRK.sinceAgg -ge 60) {
    $TRK.sinceAgg = 0
    Game-CheckStats (Write-Stats $day)
  }

  # The day's summary, once, at summaryAt.
  if ($TRK.summaryDay -ne $day -and (Get-Date).ToString('HH:mm') -ge [string]$SET.summaryAt) {
    $TRK.summaryDay = $day
    Save-TrackerState
    $totals = Write-Stats $day
    if ($totals.activeMin -ge 5) {
      Say "Today: $(Summary-Text $totals) 🦀" 15 $true
      Confetti 8
      Send 'summary'
    }
  }
}

function Forget-Today {
  $dir = Day-Dir (Today-Key)
  try { if ([IO.Directory]::Exists($dir)) { [IO.Directory]::Delete($dir, $true) } } catch { }
  try { [IO.File]::Delete($StatsFile) } catch { }
  $TRK.sys = New-SysDay (Today-Key)
  Say 'Today''s tracking data is gone. 🧹' 3 $true
}
