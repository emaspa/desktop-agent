import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami
import org.kde.kquickcontrols
import org.kde.plasma.plasma5support as P5Support
import org.kde.plasma.plasmoid

// Agents and shortcuts live outside the widget's own config (in desktop-agent's config.json and
// in kglobalaccel), so this page reads and writes them through the desktop-agent CLI.
KCM.SimpleKCM {
    id: page

    readonly property string cli: "\"$HOME/.local/bin/desktop-agent\""

    property var types: null          // per agent type: label, installed, models, permissions
    property string active: ""
    property string savedAgentKeys: ""
    property bool agentsLoaded: false
    property bool keysLoaded: false
    property bool agentsDirty: false
    property string error: ""

    readonly property bool clash: String(agentKeys.keySequence) !== ""
        && String(agentKeys.keySequence) === String(popupKeys.keySequence)

    property bool unsavedChanges: false

    function shq(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'" }

    function updateDirty() {
        unsavedChanges = agentsLoaded && keysLoaded && !clash && agentsModel.count > 0
            && (agentsDirty
                || String(agentKeys.keySequence) !== savedAgentKeys
                || String(popupKeys.keySequence) !== String(Plasmoid.globalShortcut))
    }

    function markAgentsDirty() { agentsDirty = true; updateDirty() }

    function loadAgents(info) {
        types = info.types
        active = info.active
        agentsModel.clear()
        for (const a of info.agents) {
            agentsModel.append({ aid: a.id, name: a.name, type: a.type, modelId: a.model,
                                 permissions: a.permissions, argsJson: JSON.stringify(a.args) })
        }
        agentsLoaded = true
        agentsDirty = false
        updateDirty()
    }

    function addAgent(type) {
        const id = type + "-" + Date.now().toString(36)
        agentsModel.append({ aid: id, name: types[type].label, type: type, modelId: "",
                             permissions: "", argsJson: "[]" })
        markAgentsDirty()
    }

    function removeAgent(index) {
        const removed = agentsModel.get(index).aid
        agentsModel.remove(index)
        if (removed === active && agentsModel.count > 0) active = agentsModel.get(0).aid
        markAgentsDirty()
    }

    function saveConfig() {
        if (clash || agentsModel.count === 0) return
        Plasmoid.globalShortcut = popupKeys.keySequence
        const keys = String(agentKeys.keySequence)
        if (keys !== savedAgentKeys) exec.connectSource(cli + " shortcut " + shq(keys))
        if (agentsDirty) {
            const agents = []
            for (let i = 0; i < agentsModel.count; i++) {
                const a = agentsModel.get(i)
                agents.push({ id: a.aid, name: a.name.trim(), type: a.type, model: a.modelId.trim(),
                              permissions: a.permissions, args: JSON.parse(a.argsJson) })
            }
            exec.connectSource(cli + " agents set " + shq(JSON.stringify({ active: active, agents: agents })))
        }
        unsavedChanges = false
    }

    ListModel { id: agentsModel }

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
            const out = data["stdout"].trim()
            if (source.indexOf(" agents") >= 0) {
                page.loadAgents(JSON.parse(out))
            } else if (source.indexOf(" shortcut") >= 0) {
                page.savedAgentKeys = out
                agentKeys.keySequence = out
                page.keysLoaded = true
                page.updateDirty()
            }
        }
    }

    Component.onCompleted: {
        exec.connectSource(cli + " agents")
        exec.connectSource(cli + " shortcut")
    }

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

    ColumnLayout {
        spacing: Kirigami.Units.largeSpacing

        Kirigami.Heading { level: 3; text: "Agents" }
        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            opacity: 0.7
            text: "The active agent answers the prompt box, the Fix buttons, the tasks and the hotkey. "
                + "Switch agents from the popup's header. Model and permissions left at their defaults "
                + "use the program's own settings."
        }

        Repeater {
            model: agentsModel
            delegate: Kirigami.AbstractCard {
                id: card
                required property int index
                required property string aid
                required property string name
                required property string type
                required property string modelId
                required property string permissions
                readonly property var typeInfo: page.types ? page.types[type] : null

                Layout.fillWidth: true

                contentItem: Kirigami.FormLayout {
                    QQC2.TextField {
                        Kirigami.FormData.label: "Name:"
                        text: card.name
                        onTextEdited: { agentsModel.setProperty(card.index, "name", text); page.markAgentsDirty() }
                    }
                    QQC2.Label {
                        Kirigami.FormData.label: "Program:"
                        text: card.typeInfo ? card.typeInfo.label + (card.typeInfo.installed ? "" : " (not installed)") : card.type
                    }
                    RowLayout {
                        Kirigami.FormData.label: "Model:"
                        QQC2.TextField {
                            id: modelField
                            text: card.modelId
                            placeholderText: "Default model"
                            Layout.preferredWidth: Kirigami.Units.gridUnit * 14
                            onTextEdited: { agentsModel.setProperty(card.index, "modelId", text); page.markAgentsDirty() }
                        }
                        QQC2.ToolButton {
                            icon.name: "view-list-details"
                            enabled: !!card.typeInfo && card.typeInfo.models.length > 0
                            onClicked: modelMenu.popup()
                            QQC2.ToolTip.text: "Pick a known model"
                            QQC2.ToolTip.visible: hovered
                            QQC2.Menu {
                                id: modelMenu
                                QQC2.MenuItem {
                                    text: "Default model"
                                    onTriggered: { modelField.text = ""; agentsModel.setProperty(card.index, "modelId", ""); page.markAgentsDirty() }
                                }
                                Instantiator {
                                    model: card.typeInfo ? card.typeInfo.models : []
                                    delegate: QQC2.MenuItem {
                                        required property var modelData
                                        text: modelData.label === modelData.id ? modelData.id : modelData.label + "  (" + modelData.id + ")"
                                        onTriggered: {
                                            modelField.text = modelData.id
                                            agentsModel.setProperty(card.index, "modelId", modelData.id)
                                            page.markAgentsDirty()
                                        }
                                    }
                                    onObjectAdded: (i, item) => modelMenu.insertItem(i + 1, item)
                                    onObjectRemoved: (i, item) => modelMenu.removeItem(item)
                                }
                            }
                        }
                    }
                    QQC2.ComboBox {
                        Kirigami.FormData.label: "Permissions:"
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 20
                        model: card.typeInfo ? card.typeInfo.permissions : []
                        textRole: "label"
                        Component.onCompleted: currentIndex = Math.max(0, model.findIndex(p => p.id === card.permissions))
                        onActivated: index => {
                            agentsModel.setProperty(card.index, "permissions", model[index].id)
                            page.markAgentsDirty()
                        }
                    }
                    RowLayout {
                        QQC2.RadioButton {
                            text: "Active agent"
                            checked: page.active === card.aid
                            onToggled: if (checked) { page.active = card.aid; page.markAgentsDirty() }
                        }
                        QQC2.Button {
                            text: "Remove"
                            icon.name: "list-remove"
                            enabled: agentsModel.count > 1
                            onClicked: page.removeAgent(card.index)
                        }
                    }
                }
            }
        }

        RowLayout {
            enabled: page.agentsLoaded
            QQC2.Label { text: "Add an agent:" }
            QQC2.Button {
                text: "Claude Code"
                icon.name: "list-add"
                onClicked: page.addAgent("claude")
            }
            QQC2.Button {
                text: "Codex"
                icon.name: "list-add"
                onClicked: page.addAgent("codex")
            }
        }

        Kirigami.Heading { level: 3; text: "Shortcuts"; Layout.topMargin: Kirigami.Units.largeSpacing }

        Kirigami.FormLayout {
            Layout.fillWidth: true

            KeySequenceItem {
                id: agentKeys
                Kirigami.FormData.label: "Open the agent:"
                enabled: page.keysLoaded
                patterns: ShortcutPattern.ModifierAndKey
                onKeySequenceModified: page.updateDirty()
            }
            QQC2.Label {
                text: "Opens the active agent in a terminal, in the agent workspace."
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
}
