# Desktop Agent

A KDE Plasma panel widget that turns Claude Code into a system administrator for a CachyOS
desktop, modeled on Omarchy's agents panel.

- **Panel icon.** Click opens the popup, middle-click opens the agent. The icon turns
  orange or red and shows a count when something needs attention.
- **Popup:**
  - a prompt box ("Ask the agent to do something…")
  - your Claude plan limits, with reset times
  - health checks: updates, .pacnew files, failed units, disk space, crashes in the last 24h,
    pending reboot, and error count for this boot. Each one has a button that hands the problem
    to the agent.
  - task buttons: update, health check, disk cleanup, boot errors
- **Crash capture.** When something core dumps you get a notification with *Diagnose* (launches
  the agent on the core dump) and *Mute* buttons.
- **Usage alerts.** You get one notification when a plan limit passes 90%.
- **Shortcuts.** Meta+A toggles the popup and Meta+Shift+A opens the agent. Change either one
  on the widget's *Agent* settings page (the gear in the popup, or right-click the icon >
  *Configure Desktop Agent*), or with `desktop-agent shortcut "Meta+Ctrl+A"`. Plasma uses both
  default keys for walking through activities, so a fresh install unbinds them there. Later
  installs leave your keys alone.

The agent runs `claude` in Konsole from `~/.local/share/desktop-agent/workspace`. Its
`CLAUDE.md` describes this machine and sets ground rules: snapshot before risky changes, never
reboot without asking, log every change to `~/.local/share/desktop-agent/changes.md`.

## Install

```sh
./install.sh
```

The script symlinks the CLI into `~/.local/bin`, installs the widget and adds it to the panel
that holds the system tray, enables the `desktop-agent` user service, and registers the
shortcuts. Re-run it after pulling changes. QML changes take effect after
`systemctl --user restart plasma-plasmashell`.

The first launch shows Claude Code's folder-trust prompt for the workspace.

## Configure

`desktop-agent config` prints the effective config. Override any key in
`~/.config/desktop-agent/config.json`:

```json
{
  "claude_args": ["--permission-mode", "acceptEdits"],
  "disk_mounts": ["/", "/home", "/mnt/data"],
  "actions": [{ "label": "Tidy KDE", "icon": "preferences-desktop", "prompt": "…" }]
}
```

`terminal` sets the terminal command (Konsole by default). `muted` lists programs whose crashes
don't notify; `desktop-agent mute <exe>` adds to it.

## How it works

| Piece | File |
| --- | --- |
| CLI: status JSON, launcher, watcher | `bin/desktop-agent` (Python, stdlib only) |
| Panel widget | `plasmoid/` (QML; runs `desktop-agent status` every minute) |
| Crash and usage watcher | `systemd/desktop-agent.service` |
| Agent instructions | `workspace/CLAUDE.md` |

Plan usage comes from the same endpoint Claude Code's `/usage` uses, authenticated with
Claude Code's own login in `~/.claude/.credentials.json`. The widget never refreshes that token,
because rotating it could sign Claude Code out. If the token has expired, the widget says so until the
next `claude` session renews it. The CLI caches the slow checks (`checkupdates`, `yay -Qua`,
`pacdiff`) for an hour. The refresh button forces a re-check.
