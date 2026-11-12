#!/usr/bin/env bash
# Install or update Desktop Agent for the current user. Safe to re-run.
set -euo pipefail

repo="$(cd "$(dirname "$0")" && pwd)"
bin="$HOME/.local/bin/desktop-agent"
data="${XDG_DATA_HOME:-$HOME/.local/share}/desktop-agent"
plasmoid_id="dev.desktopagent.panel"
# Default hotkeys, applied only when none is set. Change them later in the widget's settings.
agent_keys="Meta+Shift+A"
panel_keys="Meta+A"

echo "• CLI → $bin"
mkdir -p "$HOME/.local/bin"
ln -sfn "$repo/bin/desktop-agent" "$bin"

echo "• Agent workspace → $data/workspace"
mkdir -p "$data/workspace"
# AGENTS.md is read by Codex; CLAUDE.md just imports it for Claude Code.
for f in AGENTS.md CLAUDE.md; do ln -sfn "$repo/workspace/$f" "$data/workspace/$f"; done
touch "$data/changes.md"

echo "• Launcher entry"
apps="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
mkdir -p "$apps"
sed "s|^Exec=desktop-agent|Exec=$bin|" "$repo/desktop-agent.desktop" > "$apps/desktop-agent.desktop"

kga() { gdbus call --session --dest org.kde.kglobalaccel --object-path /kglobalaccel \
            --method "org.kde.KGlobalAccel.$1" "${@:2}" >/dev/null; }
first_setup=0
if [ -z "$("$bin" shortcut)" ]; then
    first_setup=1
    # Plasma binds Meta+A / Meta+Shift+A to walking through activities by default; free both.
    kga setShortcut "['plasmashell','next activity','plasmashell','Walk through activities']" "@ai []" 6
    kga setShortcut "['plasmashell','previous activity','plasmashell','Walk through activities (Reverse)']" "@ai []" 6
    "$bin" shortcut "$agent_keys" >/dev/null
fi

echo "• Watch service (crash notifications, usage alerts)"
mkdir -p "$HOME/.config/systemd/user"
ln -sfn "$repo/systemd/desktop-agent.service" "$HOME/.config/systemd/user/desktop-agent.service"
systemctl --user daemon-reload
systemctl --user enable desktop-agent.service >/dev/null
systemctl --user restart desktop-agent.service

echo "• Plasma widget"
if kpackagetool6 -t Plasma/Applet -l 2>/dev/null | grep -qx "$plasmoid_id"; then
    kpackagetool6 -t Plasma/Applet -u "$repo/plasmoid" >/dev/null
    reload=1
else
    kpackagetool6 -t Plasma/Applet -i "$repo/plasmoid" >/dev/null
    reload=0
fi

# Put it on the panel that holds the system tray, unless it's already somewhere.
qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "
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
" >/dev/null

if [ "$reload" = 1 ]; then
    echo "  Widget updated. QML changes show up after: systemctl --user restart plasma-plasmashell"
fi

cat <<EOF

Done.
  Panel widget   click: open panel · middle-click: open agent
  Hotkeys        $("$bin" shortcut) opens the agent; change both hotkeys under
                 right-click the widget > Configure Desktop Agent > Agent
  Config         desktop-agent config   (~/.config/desktop-agent/config.json)
EOF
