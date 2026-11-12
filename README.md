# Desktop Agent

A KDE Plasma panel widget that turns Claude Code or OpenAI Codex into a system administrator for
a CachyOS desktop, modeled on Omarchy's agents panel.

- **Panel icon.** Click opens the popup, middle-click opens the agent. The icon turns
  orange or red and shows a count when something needs attention.
- **Popup:**
  - an agent switcher in the header
  - a prompt box ("Ask the agent to do something…")
  - plan limits with reset times for every login on the machine (Claude, ChatGPT)
  - health checks: updates, .pacnew files, failed units, disk space, crashes in the last 24h,
    pending reboot, and error count for this boot. Each one has a button that hands the problem
    to the agent.
  - task buttons: update, health check, disk cleanup, boot errors
- **Several agents.** Each agent has a name, a program (Claude Code or Codex), a model and a
  permission level. Two come preconfigured, and you can add more: a "Claude · GPT-5.5" that runs
  Claude Code on a gateway model, say, or a read-only Codex for questions. The one you pick in
  the popup handles the prompt box, the buttons and the hotkey.
- **Crash capture.** When something core dumps you get a notification with *Diagnose* (launches
  the agent on the core dump) and *Mute* buttons.
- **Usage alerts.** You get one notification when a plan limit passes 90%.
- **Shortcuts.** Meta+A toggles the popup and Meta+Shift+A opens the agent. Plasma uses both
  default keys for walking through activities, so a fresh install unbinds them there. Later
  installs leave your keys alone.

Agents run in Konsole from `~/.local/share/desktop-agent/workspace`. Its `AGENTS.md` (which
`CLAUDE.md` imports) describes the system and sets ground rules: snapshot before risky changes,
never reboot without asking, log every change to `~/.local/share/desktop-agent/changes.md`.
Machine-specific notes, such as a sudo wrapper, go in `local.md` next to it; see
`workspace/local.md.example`.

## Install

```sh
./install.sh
```

The script symlinks the CLI into `~/.local/bin`, installs the widget and adds it to the panel
that holds the system tray, enables the `desktop-agent` user service, and registers the
shortcuts. Re-run it after pulling changes. QML changes take effect after
`systemctl --user restart plasma-plasmashell`.

The first launch of each program shows its folder-trust prompt for the workspace.

## Settings

Open them with the gear in the popup, or right-click the icon and pick *Configure Desktop
Agent*. The *Agent* page has:

- **Agents**: name, model (type one, or pick from Claude Code's model picker or Codex's model
  list), permissions, and which agent is active. Add and remove agents here.
- **Shortcuts**: the open-agent and show-popup hotkeys.

Permissions map to each program's own flags:

| Claude Code | Flags |
| --- | --- |
| Read-only: plan mode | `--permission-mode plan` |
| Ask before edits and commands | `--permission-mode manual` |
| Auto-approve file edits | `--permission-mode acceptEdits` |
| Auto mode | `--permission-mode auto` |
| Never ask | `--dangerously-skip-permissions` |

| Codex | Flags |
| --- | --- |
| Read-only sandbox | `--sandbox read-only --ask-for-approval on-request` |
| Sandboxed to the workspace | `--sandbox workspace-write --ask-for-approval on-request` |
| Auto-review | `--approve-for-me` |
| Full access, model asks when risky | `--sandbox danger-full-access --ask-for-approval on-request` |
| Never ask | `--dangerously-bypass-approvals-and-sandbox` |

"Own settings" passes no flags, so `~/.claude/settings.json` or `~/.codex/config.toml` decides.
A sandboxed Codex can't run `sudo`, so use full access or never-ask for system changes.

Everything is also scriptable: `desktop-agent agents`, `desktop-agent use codex`,
`desktop-agent launch --agent codex "check my disks"`, `desktop-agent shortcut "Meta+Ctrl+A"`.
`desktop-agent config` prints the effective config, and you can override any key in
`~/.config/desktop-agent/config.json`:

```json
{
  "disk_mounts": ["/", "/home", "/mnt/data"],
  "actions": [{ "label": "Tidy KDE", "icon": "preferences-desktop", "prompt": "…" }]
}
```

`terminal` sets the terminal command (Konsole by default). An agent's `args` list adds extra
arguments to its command line. `muted` lists programs whose crashes don't notify;
`desktop-agent mute <exe>` adds to it.

## How it works

| Piece | File |
| --- | --- |
| CLI: status JSON, launcher, watcher, settings | `bin/desktop-agent` (Python, stdlib only) |
| Panel widget and settings page | `plasmoid/` (QML; runs `desktop-agent status` every minute) |
| Crash and usage watcher | `systemd/desktop-agent.service` |
| Agent instructions | `workspace/AGENTS.md` |

Plan usage comes from the endpoints the CLIs themselves use (Claude Code's `/usage`, Codex's
`/status`), authenticated with each CLI's own login in `~/.claude/.credentials.json` and
`~/.codex/auth.json`. The widget never refreshes those tokens, because rotating one could sign the
CLI out. If a token has expired, the widget says so until that CLI's next session renews it. The
CLI caches the slow checks (`checkupdates`, `yay -Qua`, `pacdiff`) for an hour. The refresh button
forces a re-check.

## License

GPL-3.0-or-later. See [LICENSE](LICENSE).
