# ------------------------------------------------------------- the meetings --
# Today's Outlook appointments, read through COM every 5 minutes. Clawd waves 5 minutes before
# each. No Outlook (or no permission) and this quietly does nothing.

$CAL = @{ since = 300.0; items = @(); warned = @{}; ok = $true }

function Read-Calendar {
  $outlook = $null
  try {
    # Only an Outlook that is already running: never start one.
    $outlook = [Runtime.InteropServices.Marshal]::GetActiveObject('Outlook.Application')
  } catch { return @() }
  $found = @()
  try {
    $items = $outlook.Session.GetDefaultFolder(9).Items
    $items.IncludeRecurrences = $true
    $items.Sort('[Start]')
    $from = (Get-Date).ToString('g'); $to = (Get-Date).Date.AddDays(1).ToString('g')
    $today = $items.Restrict("[Start] >= '$from' AND [Start] < '$to'")
    foreach ($a in $today) {
      if ($a.AllDayEvent) { continue }
      $found += @{ start = [DateTime]$a.Start; subject = [string]$a.Subject; where = [string]$a.Location }
      if ($found.Count -ge 20) { break }
    }
  } catch { }
  return $found
}

function Tick-Calendar([double]$dt) {
  if (-not $SET.meetings) { return }
  $CAL.since += $dt
  if ($CAL.since -ge 300) { $CAL.since = 0; $CAL.items = @(Read-Calendar) }
  $now = Get-Date
  foreach ($m in $CAL.items) {
    $mins = ($m.start - $now).TotalMinutes
    $key = "$($m.start.ToString('s'))|$($m.subject)"
    if ($mins -le 5 -and $mins -gt 0 -and -not $CAL.warned.ContainsKey($key)) {
      $CAL.warned[$key] = $true
      Hold-Prop 'sign' 15
      Start-Action 'wave' 4
      $where = ''; if ($m.where) { $where = " ($($m.where))" }
      Say "📅 $($m.subject) in $([Math]::Ceiling($mins)) min$where" 20 $true
      Play-Cue 'Exclamation'
      Speak-Line "Meeting in $([Math]::Ceiling($mins)) minutes: $($m.subject)"
      Send "toast 📅 $($m.subject) starts at $($m.start.ToString('HH:mm'))"
    }
  }
}

function Add-CalendarMenu($parent) {
  if (-not $SET.meetings) { return }
  $m = [Windows.Controls.MenuItem]::new()
  $m.Header = 'Today''s meetings 📅'
  $upcoming = @($CAL.items | Where-Object { $_.start -gt (Get-Date) })
  if (-not $upcoming.Count) {
    $none = Menu-Item 'Nothing coming up (from Outlook)' { }
    $none.IsEnabled = $false
    [void]$m.Items.Add($none)
  }
  foreach ($a in $upcoming) {
    $i = Menu-Item "$($a.start.ToString('HH:mm'))  $($a.subject)" { }
    $i.IsEnabled = $false
    [void]$m.Items.Add($i)
  }
  [void]$parent.Items.Add($m)
}
