# ------------------------------------------------------------ the settings --
# settings.json, shared with the mod (which has the same defaults). Either side changes one key
# at a time, reading the file fresh, so neither undoes the other.

$SettingsFile = Join-Path $petDir 'settings.json'
$SETTING_DEFAULTS = [ordered]@{
  focus = $false; tracking = $true; trackTitles = $false
  sound = $false; tts = $false; weather = $true
  # Weather stays off until lat and lon are set.
  place = ''; lat = $null; lon = $null
  summaryAt = '17:30'
  # Quiet hours: no nudges, no chatter, between these times.
  quietFrom = '22:00'; quietTo = '08:00'
  pomodoroWork = 25; pomodoroBreak = 5; pomodoroLong = 15
  # Minutes between nudges; 0 turns one off.
  nudgeEyes = 20; nudgeWater = 60; nudgePosture = 45
  meetings = $true; seasonal = $true; perch = $true; autoHide = $true
  scale = 1.0; opacity = 1.0; startWithWindows = $false
}
$SET = @{}

function Read-Settings {
  foreach ($k in $SETTING_DEFAULTS.Keys) { $SET[$k] = $SETTING_DEFAULTS[$k] }
  try {
    $raw = [IO.File]::ReadAllText($SettingsFile) | ConvertFrom-Json
    foreach ($p in $raw.PSObject.Properties) { $SET[$p.Name] = $p.Value }
  } catch { }
  $S.focus = [bool]$SET.focus
}

function Set-Setting([string]$key, $value) {
  $raw = [ordered]@{}
  try {
    $old = [IO.File]::ReadAllText($SettingsFile) | ConvertFrom-Json
    foreach ($p in $old.PSObject.Properties) { $raw[$p.Name] = $p.Value }
  } catch { }
  $raw[$key] = $value
  try { [IO.File]::WriteAllText($SettingsFile, ($raw | ConvertTo-Json)) } catch { }
  Read-Settings
  # The mod's pane shows some of these.
  Send 'setting'
}

# Between quietFrom and quietTo (which may wrap past midnight).
function Is-Quiet {
  try {
    $now = (Get-Date).TimeOfDay
    $from = [TimeSpan]::Parse([string]$SET.quietFrom); $to = [TimeSpan]::Parse([string]$SET.quietTo)
    if ($from -le $to) { return ($now -ge $from -and $now -lt $to) }
    return ($now -ge $from -or $now -lt $to)
  } catch { return $false }
}

# A checkable menu item for an on/off setting.
function Setting-Item([string]$header, [string]$key) {
  $item = Menu-Item $header { param($sender) Set-Setting $sender.Tag (-not [bool]$SET[$sender.Tag]); Apply-Settings } ([bool]$SET[$key])
  $item.Tag = $key
  return $item
}

Read-Settings
