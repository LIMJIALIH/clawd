# Clawd 🦀

A Claude Code plugin that puts a tiny crab on your desktop. Clawd reacts to what Claude is doing:
it reads along, types along, holds a prop for each tool, worries at errors and celebrates commits.
It also keeps you company through the day with pomodoros, reminders, gentle nudges and a
productivity summary, and it levels up as you work.

## Install

### Before you start

- [Claude Code](https://docs.claude.com/en/docs/claude-code) installed, with plugin support.
- [Git](https://git-scm.com/downloads) on your `PATH`. Claude Code uses it to fetch the plugin from GitHub.
- For the desktop pet: Windows 10 or 11. See [Requirements](#requirements).

### Option 1: inside Claude Code (recommended)

At the prompt of a Claude Code terminal session, type:

```
/plugin install clawd --marketplace LIMJIALIH/clawd
```

1. Claude Code asks **Add marketplace?** for `github:LIMJIALIH/clawd`. Answer `y`.
2. Pick a scope. **User** makes Clawd available in every project.
3. You see `Installed clawd`. Clawd is active in this session right away and in every new session.

### Option 2: from a shell

```
claude plugin install clawd --marketplace LIMJIALIH/clawd
```

Or in two steps:

```
claude plugin marketplace add LIMJIALIH/clawd
claude plugin install clawd@clawd --scope user
```

### Option 3: Claude desktop app

`/plugin` doesn't run in the desktop app. Instead:

1. Click **+** next to the prompt box.
2. Choose **Plugins**, then **Add marketplace**, and enter `LIMJIALIH/clawd`.
3. Click **Add plugin** next to **clawd**.

### Check that it worked

Start a new Claude Code session and run:

```
/clawd
```

On Windows, the crab appears on your desktop. Run `/clawd panel` to open the control panel
beside the chat. `claude plugin list` should show `clawd@clawd` as enabled.

### Update

```
claude plugin marketplace update clawd
claude plugin update clawd@clawd
```

Then run `/reload-plugins` in an open session, or start a new one.

### Install from a clone (for contributors)

```
git clone https://github.com/LIMJIALIH/clawd.git
claude plugin marketplace add ./clawd
claude plugin install clawd@clawd
```

Claude Code reads a folder marketplace straight from that folder. After you edit the code, run
`/reload-plugins` to pick up the change.

### From npm

The plugin is packaged for npm as [`claude-clawd`](https://www.npmjs.com/package/claude-clawd).
Once the package is published, you can install from npm by adding a marketplace whose entry
points at the package:

```json
{
  "name": "clawd-npm",
  "owner": { "name": "you" },
  "plugins": [{ "name": "clawd", "source": { "source": "npm", "package": "claude-clawd" } }]
}
```

Save it as `.claude-plugin/marketplace.json` in any folder, then:

```
claude plugin marketplace add <that folder>
claude plugin install clawd@clawd-npm
```

## Requirements

- Claude Code with plugin support.
- **The desktop pet needs Windows 10 or 11** with Windows PowerShell 5.1, which ships with Windows.
  On macOS and Linux the `/clawd` command, the control panel, the moods and the tracking of
  Claude sessions still work. Only the desktop pet doesn't appear.

## Using it

Clawd starts with your first Claude Code session. Only one Clawd runs at a time, however many
terminals you have open.

| Command | What it does |
| --- | --- |
| `/clawd` | Brings Clawd back onto the screen your mouse is on |
| `/clawd hide` | Puts Clawd away |
| `/clawd pet` | Pets Clawd |
| `/clawd panel` | Opens the control panel beside the chat (model, context meter, focus, pomodoro) |
| `/clawd stats` / `/clawd stats week` | Your active time, Claude sessions, prompts and commits |
| `/clawd focus` | Focus mode: Clawd stays quiet |
| `/clawd pomodoro` | Starts or stops a pomodoro |

**Right-click** Clawd for the hub. **Shift+right-click** opens the full menu.

### What Clawd does

- **Reacts to Claude:** a mood and speech bubble for every prompt, tool call, error and finished
  turn. Clawd waves when Claude is waiting for your permission and celebrates long turns, commits,
  pushes and PRs/MRs (`gh pr create`, `glab mr create`).
- **Ask:** quick questions, "explain/summarise/fix what's on my clipboard", or drop a file on
  Clawd for a summary. Answers come from Haiku.
- **Pomodoros, reminders and nudges:** for example "remind me in 20m to stand up" or "at 15:30
  standup". There are eye, water and posture nudges, a stretch break every 50 minutes, and
  quiet hours.
- **Outlook meetings:** if Outlook is running, Clawd waves 5 minutes before each appointment.
- **Productivity tracking:** active and idle time, which kind of app is in front, and Claude
  activity per project. Clawd shows a daily summary toast.
- **Game:** XP and levels from real work, a daily streak, achievements, outfits (including
  ones you paint yourself) and two mini games.
- **Desktop life:** Clawd sits on windows, chases a ball, follows the seasons and the weather,
  works across multiple monitors, and steps out of the way of fullscreen apps.

## Settings

Most settings are in the hub's settings tab. All of them are stored in
`~/.claude/clawd-pet/settings.json` (or `$CLAUDE_CONFIG_DIR/clawd-pet/` if you set that
variable). The pet and the plugin share this file.

| Key | Default | Meaning |
| --- | --- | --- |
| `focus` | `false` | Focus mode |
| `tracking` | `true` | Productivity tracking on or off |
| `trackTitles` | `false` | Also record window titles, not just app names |
| `sound` / `tts` | `false` | Sounds / Clawd reads its lines aloud |
| `weather` | `true` | Weather on the desktop. Needs `lat` and `lon` |
| `place`, `lat`, `lon` | empty | Your location for the weather, e.g. `"place": "Berlin", "lat": 52.52, "lon": 13.40` |
| `summaryAt` | `"17:30"` | When the daily summary appears |
| `quietFrom` / `quietTo` | `"22:00"` / `"08:00"` | Quiet hours |
| `pomodoroWork` / `pomodoroBreak` / `pomodoroLong` | `25` / `5` / `15` | Pomodoro minutes |
| `nudgeEyes` / `nudgeWater` / `nudgePosture` | `20` / `60` / `45` | Minutes between nudges. `0` turns a nudge off |
| `meetings`, `seasonal`, `perch`, `autoHide` | `true` | Outlook alerts, seasonal outfits, sitting on windows, hiding for fullscreen apps |
| `scale` / `opacity` | `1.0` | Clawd's size and see-through |
| `startWithWindows` | `false` | Start Clawd at login, without Claude Code |

The weather comes from [Open-Meteo](https://open-meteo.com/). No request is made until you set
a location.

## Privacy

Everything Clawd records stays on your machine, in `~/.claude/clawd-pet/`. The tracker keeps
process names and seconds. It keeps window titles only if you turn on `trackTitles`. You can
pause tracking from the hub or the panel. The only network requests are the weather (when a
location is set) and the Haiku answers you ask for.

## Uninstall

```
claude plugin uninstall clawd@clawd
claude plugin marketplace remove clawd
```

Then delete `~/.claude/clawd-pet/` to remove your data. If you turned on "Start with Windows",
also remove `Clawd.lnk` from your Startup folder (`shell:startup`).

## Development

```
claude --plugin-dir .      # run Claude Code with this folder loaded; edits hot-reload
npm run validate           # claude plugin validate .
npm test                   # claude plugin test .
npm run typecheck          # tsc -p . (after one --plugin-dir run has written .claude-plugin/types)
```

`hooks/register.tsx` is the Claude Code side: moods, the `/clawd` command, the panel and
tracking. `pet/clawd-pet.ps1` and `pet/features/*.ps1` are the WPF desktop pet. The two
communicate through files in `~/.claude/clawd-pet/`: `state.json` carries plugin → pet
messages, and `commands.txt` carries pet → plugin messages.

## License

MIT
