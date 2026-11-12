# Desktop Agent

[![Buy me a coffee](https://img.shields.io/badge/Buy%20me%20a%20coffee-emaspa-FFDD00?logo=buymeacoffee&logoColor=black)](https://buymeacoffee.com/emaspa)
[![Ko-fi](https://img.shields.io/badge/Ko--fi-emaspa-FF5E5B?logo=kofi&logoColor=white)](https://ko-fi.com/emaspa)
[![Sponsor](https://img.shields.io/badge/Sponsor-GitHub-EA4AAA?logo=githubsponsors&logoColor=white)](https://github.com/sponsors/emaspa)

A KDE Plasma panel widget that turns Claude Code or OpenAI Codex into a system administrator for
your desktop, modeled on Omarchy's agents panel. Built for CachyOS; it works on any Arch-based
distro with Plasma 6.

- **Panel icon.** Click opens the popup, middle-click opens the agent. The icon turns
  orange or red and shows a count when something needs attention.
- **Popup:**
  - an agent switcher in the header
  - a prompt box ("Ask the agent to do something…")
  - plan limits with reset times for every login on the machine (Claude, ChatGPT)
  - health checks: updates, .pacnew files, failed units, disk space, crashes in the last 24h,
    pending reboot, and error count for this boot. Each one has a button that hands the problem
    to the agent. When you close the agent's window, the checks run again, so a merged .pacnew
    or a finished update drops off the list right away.
  - task buttons: update, health check, disk cleanup, boot errors
- **Several agents.** Each agent has a name, a program (Claude Code or Codex), a model and a
  permission level. Two come preconfigured, and you can add more: a "Claude · GPT-5.5" that runs
  Claude Code on a gateway model, say, or a read-only Codex for questions. The one you pick in
  the popup handles the prompt box, the buttons and the hotkey.
- **Crash capture.** When something core dumps you get a notification with *Diagnose* (launches
  the agent on the core dump) and *Mute* buttons.
- **Usage alerts.** You get one notification when a plan limit passes 90%.
- **Hotkeys.** Meta+A toggles the popup and Meta+Shift+A opens the agent.

## Requirements

- **KDE Plasma 6** on an Arch-based distro. The update and .pacnew checks use pacman's tools;
  on other distros the widget runs but those two checks stay empty.
- **Packages:**

  ```sh
  sudo pacman -S --needed python kpackage qt6-tools glib2 libnotify pacman-contrib konsole
  ```

  The installer checks for these and prints the command for anything missing. `yay` or `paru`
  is optional; with one installed, the update count includes AUR packages.
- **At least one agent**, installed and signed in:

  | Agent | Install | Sign in | Account |
  | --- | --- | --- | --- |
  | [Claude Code](https://code.claude.com/docs/en/setup) | `curl -fsSL https://claude.ai/install.sh \| bash` | `claude auth login` | Claude Pro or Max, or an API key |
  | [Codex](https://developers.openai.com/codex/cli) | `curl -fsSL https://chatgpt.com/codex/install.sh \| sh` | `codex login` | ChatGPT plan, or an API key |

  Plan limits show in the popup only for subscription logins, since API keys have no plan
  limits to show. You can install both and switch between them.

## Install

1. Download `desktop-agent-<version>.tar.gz` from the
   [latest release](https://github.com/emaspa/desktop-agent/releases/latest) and unpack it:

   ```sh
   tar xzf desktop-agent-*.tar.gz
   cd desktop-agent-*/
   ```

2. Run the installer from your Plasma session:

   ```sh
   ./install.sh
   ```

   It copies the app to `~/.local/share/desktop-agent/app` (you can delete the download
   afterwards), puts `desktop-agent` in `~/.local/bin`, adds the widget to the panel that holds
   your system tray, starts the `desktop-agent` user service, and sets the hotkeys. Plasma
   binds Meta+A and Meta+Shift+A to switching activities by default, so the first install
   unbinds them there.

3. Press Meta+Shift+A, or middle-click the icon. The first time, Claude Code and Codex each ask
   you to trust the agent's folder; answer yes.

To install from git instead, clone the repo and run `./install.sh` in the checkout. The
installed files then link to the checkout, so `git pull` updates the CLI right away; re-run the
installer to update the widget and service.

### Update

Download the new release and run its `./install.sh`. Your agents, hotkeys and notes are kept.
If the widget changed, restart Plasma's shell to load it:
`systemctl --user restart plasma-plasmashell`.

### Uninstall

```sh
~/.local/share/desktop-agent/app/install.sh --uninstall
```

From a git checkout, run `./install.sh --uninstall` there. This removes the widget, service,
hotkey and CLI. It keeps `~/.config/desktop-agent` (your settings) and
`~/.local/share/desktop-agent` (the agents' change log and your notes); delete them to remove
everything.

## Configure

### In the widget

Click the gear in the popup, or right-click the icon and pick *Configure Desktop Agent*. The
*Agent* page has:

- **Agents**: name, model, permissions, and which agent is active. Type a model name or pick one
  from Claude Code's model picker or Codex's model list; leave it empty for the program's
  default. Add and remove agents here.
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

### The agents' instructions

Agents run in Konsole from `~/.local/share/desktop-agent/workspace`. `AGENTS.md` there (which
`CLAUDE.md` imports) describes the system and sets ground rules: snapshot before risky changes,
never reboot without asking, log every change to `~/.local/share/desktop-agent/changes.md`. The
launcher refreshes both files from the app on every launch, so put your own notes in
`local.md` in the same folder: both agents read it. See `workspace/local.md.example`. It's the
place for things like a sudo wrapper, since a terminal-less agent can't answer a password
prompt.

### Config file and CLI

`desktop-agent config` prints the effective config. Override any key in
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

Everything in the settings page is scriptable too: `desktop-agent agents`,
`desktop-agent use codex`, `desktop-agent launch --agent codex "check my disks"`,
`desktop-agent shortcut "Meta+Ctrl+A"`. Run `desktop-agent --help` for the full list.

## How it works

| Piece | File |
| --- | --- |
| CLI: status JSON, launcher, watcher, settings | `bin/desktop-agent` (Python, stdlib only) |
| Panel widget and settings pages | `plasmoid/` (QML; runs `desktop-agent status` every minute) |
| Crash and usage watcher | `systemd/desktop-agent.service` |
| Agent instructions | `workspace/AGENTS.md` |

Plan usage comes from the endpoints the CLIs themselves use (Claude Code's `/usage`, Codex's
`/status`), authenticated with each CLI's own login in `~/.claude/.credentials.json` and
`~/.codex/auth.json`. Those tokens only go to Anthropic and OpenAI. The widget never refreshes
them, because rotating one could sign the CLI out; if a token has expired, the widget says so
until that CLI's next session renews it. The CLI caches the slow checks (`checkupdates`,
`yay -Qua`, `pacdiff`) for an hour, and the refresh button forces a re-check.

A *Support this project* page in the widget's settings has the Buy Me a Coffee and Ko-fi links.

## License

GPL-3.0-or-later. See [LICENSE](LICENSE).

If you find Desktop Agent useful, consider
[buying me a coffee](https://buymeacoffee.com/emaspa) or supporting it on
[Ko-fi](https://ko-fi.com/emaspa).
