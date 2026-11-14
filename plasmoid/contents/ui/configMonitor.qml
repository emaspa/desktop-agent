import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasma5support as P5Support

// The switches live in desktop-agent's config.json, because the watch service reads them too.
KCM.SimpleKCM {
    id: page

    readonly property string cli: "\"$HOME/.local/bin/desktop-agent\""

    readonly property var checks: [
        { key: "usage", label: "Plan usage", detail: "Claude and ChatGPT limits at the top of the popup" },
        { key: "updates", label: "Updates", detail: "Repo and AUR packages waiting to install" },
        { key: "pacnew", label: ".pacnew files", detail: "Config files an update left for you to merge" },
        { key: "reboot", label: "Pending reboot", detail: "The running kernel is no longer installed" },
        { key: "units", label: "Failed services", detail: "System and user systemd units" },
        { key: "disks", label: "Disk space", detail: "/ and /home; change the list with disk_mounts in config.json" },
        { key: "crashes", label: "Crashes", detail: "Core dumps in the last 24 hours" },
        { key: "journal", label: "Boot errors", detail: "Error lines in this boot's journal" }
    ]
    readonly property var notifications: [
        { key: "crash_notifications", label: "A program crashes", detail: "With Diagnose and Mute buttons" },
        { key: "usage_notifications", label: "A plan limit passes 90%", detail: "Once per limit and reset" }
    ]

    property var saved: ({})
    property var current: ({})
    property bool loaded: false
    property string error: ""
    property bool unsavedChanges: false

    function set(key, value) {
        const next = Object.assign({}, current)
        next[key] = value
        current = next
        unsavedChanges = Object.keys(current).some(k => current[k] !== saved[k])
    }

    function saveConfig() {
        const changes = {}
        for (const k of Object.keys(current))
            if (current[k] !== saved[k]) changes[k] = current[k]
        if (Object.keys(changes).length === 0) return
        const json = JSON.stringify(changes).replace(/'/g, "'\\''")
        exec.connectSource(cli + " monitor set '" + json + "'")
        unsavedChanges = false
    }

    P5Support.DataSource {
        id: exec
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            disconnectSource(source)
            if (data["exit code"] !== 0) {
                page.error = (data["stderr"] || "desktop-agent failed").trim()
                return
            }
            page.error = ""
            const state = JSON.parse(data["stdout"])
            page.saved = state
            page.current = Object.assign({}, state)
            page.loaded = true
            page.unsavedChanges = false
        }
    }

    Component.onCompleted: exec.connectSource(cli + " monitor")

    header: Kirigami.InlineMessage {
        visible: page.error !== ""
        type: Kirigami.MessageType.Error
        text: page.error
    }

    Kirigami.FormLayout {
        enabled: page.loaded

        Repeater {
            model: page.checks
            delegate: QQC2.CheckBox {
                required property var modelData
                required property int index
                Kirigami.FormData.label: index === 0 ? "Show in the popup:" : ""
                text: modelData.label
                checked: !!page.current[modelData.key]
                onToggled: page.set(modelData.key, checked)
                QQC2.ToolTip.text: modelData.detail
                QQC2.ToolTip.visible: hovered
                QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
            }
        }
        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            wrapMode: Text.Wrap
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            text: "Checks you turn off leave the popup and no longer count toward the badge on the panel icon."
        }

        Item { Kirigami.FormData.isSection: true }

        Repeater {
            model: page.notifications
            delegate: QQC2.CheckBox {
                required property var modelData
                required property int index
                Kirigami.FormData.label: index === 0 ? "Notify me when:" : ""
                text: modelData.label
                checked: !!page.current[modelData.key]
                onToggled: page.set(modelData.key, checked)
                QQC2.ToolTip.text: modelData.detail
                QQC2.ToolTip.visible: hovered
                QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
            }
        }
    }
}
