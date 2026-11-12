#!/usr/bin/env bash
# Install, update or remove Desktop Agent for the current user. Safe to re-run.
#
#   ./install.sh               install, or update to this version
#   ./install.sh --uninstall   remove it; keeps your settings and agent notes
set -euo pipefail

src="$(cd "$(dirname "$0")" && pwd)"
bin="$HOME/.local/bin/desktop-agent"
data="${XDG_DATA_HOME:-$HOME/.local/share}/desktop-agent"
app="$data/app"
apps="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
unit="$HOME/.config/systemd/user/desktop-agent.service"
plasmoid_id="dev.desktopagent.panel"
launch_action="['desktop-agent.desktop','_launch','Desktop Agent','Desktop Agent']"
# Default hotkeys, applied only when none is set. Change them later in the widget's settings.
agent_keys="Meta+Shift+A"
panel_keys="Meta+A"

kga() { gdbus call --session --dest org.kde.kglobalaccel --object-path /kglobalaccel \
            --method "org.kde.KGlobalAccel.$1" "${@:2}" >/dev/null; }
plasma_script() { qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$1" >/dev/null; }

# ------------------------------------------------------------------ uninstall

if [ "${1:-}" = "--uninstall" ]; then
    echo "• Stopping the watch service"
    systemctl --user disable --now desktop-agent.service 2>/dev/null || true
    rm -f "$unit"
    systemctl --user daemon-reload

    echo "• Removing the widget"
    plasma_script "panels().forEach(function (p) { p.widgets().forEach(function (w) {
        if (w.type === '$plasmoid_id') w.remove(); }); });" || true
    kpackagetool6 -t Plasma/Applet -r "$plasmoid_id" >/dev/null 2>&1 || true

    echo "• Removing the hotkey, launcher entry and CLI"
    kga setShortcut "$launch_action" "@ai []" 6 2>/dev/null || true
    gdbus call --session --dest org.kde.kglobalaccel --object-path /kglobalaccel \
        --method org.kde.KGlobalAccel.unregister desktop-agent.desktop _launch >/dev/null 2>&1 || true
    rm -f "$apps/desktop-agent.desktop" "$bin"
    rm -f "$data/workspace/AGENTS.md" "$data/workspace/CLAUDE.md"
    rm -rf "${XDG_CACHE_HOME:-$HOME/.cache}/desktop-agent"
    # Last, because this script may be running from inside it.
    rm -rf "$app"

    cat <<EOF

Desktop Agent is removed. Kept, in case you reinstall:
  ~/.config/desktop-agent/          settings (agents, muted crashes)
  $data/   changes.md (the agents' change log) and workspace/local.md
Delete those two folders to remove everything.
EOF
    exit 0
fi

# ------------------------------------------------------------------ prerequisites

missing=() packages=()
need() {  # command, Arch package
    if ! command -v "$1" >/dev/null 2>&1; then missing+=("$1"); packages+=("$2"); fi
}
need python3 python
need kpackagetool6 kpackage
need qdbus6 qt6-tools
need gdbus glib2
need notify-send libnotify
need systemctl systemd
need journalctl systemd
if [ ${#missing[@]} -gt 0 ]; then
    echo "Missing: ${missing[*]}"
    echo "On Arch or CachyOS: sudo pacman -S --needed $(printf '%s\n' "${packages[@]}" | sort -u | tr '\n' ' ')"
    exit 1
fi
if ! qdbus6 org.kde.plasmashell >/dev/null 2>&1; then
    echo "Plasma isn't running in this session. Run the installer from a KDE Plasma 6 desktop."
    exit 1
fi

warnings=()
command -v checkupdates >/dev/null || warnings+=("pacman-contrib isn't installed: no update or .pacnew checks (sudo pacman -S pacman-contrib)")
command -v konsole >/dev/null || warnings+=("Konsole isn't installed: install it, or set \"terminal\" in ~/.config/desktop-agent/config.json")
if ! command -v claude >/dev/null && [ ! -x "$HOME/.local/bin/claude" ] \
   && ! command -v codex >/dev/null && [ ! -x "$HOME/.local/bin/codex" ]; then
    warnings+=("Neither Claude Code nor Codex is installed. Install at least one:
      Claude Code: curl -fsSL https://claude.ai/install.sh | bash   then: claude auth login
      Codex:       curl -fsSL https://chatgpt.com/codex/install.sh | sh   then: codex login")
fi

# ------------------------------------------------------------------ files

# From a git checkout, link to it so edits apply directly. From a release tarball, copy the files
# into $app so the download can be deleted afterwards.
if [ "$src" = "$app" ]; then
    root="$app"
elif [ -d "$src/.git" ]; then
    root="$src"
    rm -rf "$app"  # a copy left by an earlier tarball install
else
    root="$app"
    rm -rf "$app"
    mkdir -p "$app"
    cp -r "$src/bin" "$src/plasmoid" "$src/systemd" "$src/workspace" "$src/desktop-agent.desktop" \
          "$src/install.sh" "$app/"
fi

echo "• CLI → $bin"
mkdir -p "$HOME/.local/bin"
ln -sfn "$root/bin/desktop-agent" "$bin"

echo "• Agent workspace → $data/workspace"
# Real copies, refreshed on every launch: AGENTS.md is read by Codex, and CLAUDE.md imports it
# (and local.md) for Claude Code.
"$bin" workspace >/dev/null
touch "$data/changes.md"

echo "• Launcher entry and hotkey"
mkdir -p "$apps"
sed "s|^Exec=desktop-agent|Exec=$bin|" "$root/desktop-agent.desktop" > "$apps/desktop-agent.desktop"
first_setup=0
if [ -z "$("$bin" shortcut)" ]; then
    first_setup=1
    # Plasma binds Meta+A / Meta+Shift+A to walking through activities by default; free both.
    kga setShortcut "['plasmashell','next activity','plasmashell','Walk through activities']" "@ai []" 6
    kga setShortcut "['plasmashell','previous activity','plasmashell','Walk through activities (Reverse)']" "@ai []" 6
    "$bin" shortcut "$agent_keys" >/dev/null
fi

echo "• Watch service (crash notifications, usage alerts)"
mkdir -p "$(dirname "$unit")"
ln -sfn "$root/systemd/desktop-agent.service" "$unit"
systemctl --user daemon-reload
systemctl --user enable desktop-agent.service >/dev/null
systemctl --user restart desktop-agent.service

echo "• Plasma widget"
if kpackagetool6 -t Plasma/Applet -l 2>/dev/null | grep -qx "$plasmoid_id"; then
    kpackagetool6 -t Plasma/Applet -u "$root/plasmoid" >/dev/null
    updated=1
else
    kpackagetool6 -t Plasma/Applet -i "$root/plasmoid" >/dev/null
    updated=0
fi

# Put it on the panel that holds the system tray, unless it's already somewhere.
plasma_script "
var id = '$plasmoid_id', present = false, target = null;
panels().forEach(function (p) {
    p.widgets().forEach(function (w) {
        if (w.type === id) present = true;
        if (w.type === 'org.kde.plasma.systemtray') target = p;
    });
});
if (!present) {
    target = target || panels()[0];
    target.addWidget(id);
}
if ($first_setup) {
    panels().forEach(function (p) {
        p.widgets().forEach(function (w) { if (w.type === id) w.globalShortcut = '$panel_keys'; });
    });
}
"

cat <<EOF

Done. Desktop Agent is on the panel next to the system tray.
  Click the icon      open the popup
  Middle-click        open the active agent ($("$bin" shortcut))
  Settings            right-click the icon > Configure Desktop Agent (agents, permissions, hotkeys)
EOF
if [ "$updated" = 1 ]; then
    echo "  The widget was updated: run 'systemctl --user restart plasma-plasmashell' to load the new version."
fi
for w in "${warnings[@]}"; do printf '\nNote: %s\n' "$w"; done
exit 0
