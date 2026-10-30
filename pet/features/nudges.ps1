# -------------------------------------------------------------- the nudges --
# Eyes, water, posture: each on its own clock, counting only time you are at the machine.
# The mod's 50-minute stretch break stays as it was; these are lighter taps on the shoulder.

$NUDGES = @(
  @{ id = 'eyes'; setting = 'nudgeEyes'; lines = @('20-20-20: look at something 20 feet away for 20 seconds 👀', 'Eye break! Look far away for a bit 👀') }
  @{ id = 'water'; setting = 'nudgeWater'; lines = @('Sip of water? 💧', 'Hydration check! 💧') }
  @{ id = 'posture'; setting = 'nudgePosture'; lines = @('Posture check: shoulders back, feet flat 🧘', 'Sit up tall with me! 🧘') }
)
# Not $NUDGE: names ignore case, and the main script's $nudge moves the sprite.
$NUDGING = @{ since = 0.0; active = @{} }

function Tick-Nudges([double]$dt) {
  $NUDGING.since += $dt
  if ($NUDGING.since -lt 5) { return }
  $step = $NUDGING.since
  $NUDGING.since = 0
  # Only while you are at the machine, and never in focus, quiet hours, a meeting or a break.
  if ([ClawdPet.Native]::IdleMs() -ge 120000) { return }
  $blocked = $S.focus -or (Is-Quiet) -or $POMO.phase -or $S.mood -eq 'break' -or $S.autoHidden
  foreach ($n in $NUDGES) {
    $every = [double]$SET[$n.setting]
    if ($every -le 0) { continue }
    $NUDGING.active[$n.id] = [double]$NUDGING.active[$n.id] + $step
    if ($NUDGING.active[$n.id] -lt $every * 60 -or $blocked) { continue }
    $NUDGING.active[$n.id] = 0
    Say $n.lines[$rand.Next($n.lines.Count)] 8
    switch ($n.id) {
      'eyes' { Start-Action 'look' 4 }
      'water' { Start-Action 'sip' 5 }
      'posture' { Start-Action 'stretch' 2 }
    }
    return
  }
}
