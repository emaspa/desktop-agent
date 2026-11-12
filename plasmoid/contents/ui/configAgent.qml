import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami
import org.kde.kquickcontrols
import org.kde.plasma.plasma5support as P5Support
import org.kde.plasma.plasmoid

KCM.SimpleKCM {
    id: page

    readonly property string cli: "\"$HOME/.local/bin/desktop-agent\""
    // The open-agent hotkey belongs to kglobalaccel, not to this widget's config,
    // so it's read and written through the CLI.
    property string savedAgentKeys: ""
    property bool loaded: false
    property string error: ""

    readonly property bool clash: String(agentKeys.keySequence) !== ""
        && String(agentKeys.keySequence) === String(popupKeys.keySequence)

    property bool unsavedChanges: false

    function shq(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'" }

    function updateDirty() {
        unsavedChanges = loaded && !clash
            && (String(agentKeys.keySequence) !== savedAgentKeys
                || String(popupKeys.keySequence) !== String(Plasmoid.globalShortcut))
    }

    function saveConfig() {
        if (clash) return
        Plasmoid.globalShortcut = popupKeys.keySequence
        const keys = String(agentKeys.keySequence)
        if (keys !== savedAgentKeys) exec.connectSource(cli + " shortcut " + shq(keys))
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
            page.savedAgentKeys = data["stdout"].trim()
            agentKeys.keySequence = page.savedAgentKeys
            page.loaded = true
            page.updateDirty()
        }
    }

    Component.onCompleted: exec.connectSource(cli + " shortcut")

    header: Column {
        Kirigami.InlineMessage {
            width: parent.width
            visible: page.error !== ""
            type: Kirigami.MessageType.Error
            text: page.error
        }
        Kirigami.InlineMessage {
            width: parent.width
            visible: page.clash
            type: Kirigami.MessageType.Warning
            text: "Both actions can't use the same shortcut."
        }
    }

    Kirigami.FormLayout {
        KeySequenceItem {
            id: agentKeys
            Kirigami.FormData.label: "Open the agent:"
            enabled: page.loaded
            patterns: ShortcutPattern.ModifierAndKey
            onKeySequenceModified: page.updateDirty()
        }
        QQC2.Label {
            text: "Opens Claude in a terminal, in the agent workspace."
            font: Kirigami.Theme.smallFont
            opacity: 0.7
        }

        Item { Kirigami.FormData.isSection: true }

        KeySequenceItem {
            id: popupKeys
            Kirigami.FormData.label: "Show the panel:"
            keySequence: Plasmoid.globalShortcut
            patterns: ShortcutPattern.Modifier | ShortcutPattern.ModifierAndKey
            onKeySequenceModified: page.updateDirty()
        }
        QQC2.Label {
            text: "Opens or closes this widget's popup. Same setting as the Keyboard Shortcuts page."
            font: Kirigami.Theme.smallFont
            opacity: 0.7
        }
    }
}
