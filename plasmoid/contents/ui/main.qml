import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.plasma5support as P5Support
import org.kde.plasma.plasmoid

PlasmoidItem {
    id: root

    readonly property string cli: "\"$HOME/.local/bin/desktop-agent\""
    property var st: null
    property bool loading: false

    readonly property color levelColor: !st ? Kirigami.Theme.textColor
        : st.worst === "error" ? Kirigami.Theme.negativeTextColor
        : st.worst === "warn" ? Kirigami.Theme.neutralTextColor
        : Kirigami.Theme.textColor

    toolTipMainText: "Desktop Agent"
    toolTipSubText: {
        if (!st) return "Loading…"
        let lines = []
        for (const l of (st.usage.limits || [])) lines.push(l.label + ": " + l.detail)
        for (const c of st.checks) if (c.level === "error" || c.level === "warn") lines.push(c.title)
        lines.push("Middle-click to open the agent")
        return lines.join("\n")
    }

    Plasmoid.icon: Qt.resolvedUrl("../icons/agent.svg")
    Plasmoid.status: st && st.attention > 0 ? PlasmaCore.Types.ActiveStatus : PlasmaCore.Types.PassiveStatus

    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: "Open Agent"
            icon.name: "utilities-terminal"
            onTriggered: root.launch("")
        },
        PlasmaCore.Action {
            text: "Refresh"
            icon.name: "view-refresh"
            onTriggered: root.refresh(true)
        }
    ]

    // ------------------------------------------------------------ commands

    function shq(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'" }

    function refresh(force) {
        if (loading) return
        loading = true
        exec.connectSource(cli + " status" + (force ? " --refresh" : ""))
    }

    function launch(prompt) {
        // A timestamp keeps identical commands from being deduplicated by the data engine.
        exec.connectSource(cli + " launch -- " + shq(prompt || "") + " #" + Date.now())
        root.expanded = false
    }

    P5Support.DataSource {
        id: exec
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            disconnectSource(source)
            if (source.indexOf(" status") < 0) return
            root.loading = false
            try {
                root.st = JSON.parse(data["stdout"])
            } catch (e) {
                console.warn("desktop-agent status failed:", data["stderr"])
            }
        }
    }

    Timer {
        interval: 60 * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh(false)
    }

    onExpandedChanged: if (expanded) refresh(false)

    // ------------------------------------------------------------ panel icon

    compactRepresentation: MouseArea {
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        hoverEnabled: true
        onClicked: mouse => {
            if (mouse.button === Qt.MiddleButton) root.launch("")
            else root.expanded = !root.expanded
        }

        Kirigami.Icon {
            anchors.fill: parent
            source: Plasmoid.icon
            isMask: true
            color: root.levelColor
            active: parent.containsMouse
        }

        Rectangle {
            visible: root.st && root.st.attention > 0
            anchors.right: parent.right
            anchors.top: parent.top
            width: Math.max(height, badgeText.implicitWidth + 4)
            height: Math.round(parent.height * 0.45)
            radius: height / 2
            color: root.levelColor
            PlasmaComponents.Label {
                id: badgeText
                anchors.centerIn: parent
                text: root.st ? root.st.attention : ""
                font.pixelSize: parent.height * 0.75
                font.bold: true
                color: Kirigami.Theme.backgroundColor
            }
        }
    }

    // ------------------------------------------------------------ popup

    fullRepresentation: PlasmaExtras.Representation {
        Layout.preferredWidth: Kirigami.Units.gridUnit * 24
        Layout.preferredHeight: Kirigami.Units.gridUnit * 30
        Layout.minimumWidth: Kirigami.Units.gridUnit * 18
        collapseMarginsHint: true

        header: PlasmaExtras.PlasmoidHeading {
            RowLayout {
                anchors.fill: parent
                Kirigami.Heading {
                    level: 2
                    text: "Agent"
                    Layout.fillWidth: true
                }
                PlasmaComponents.Label {
                    text: root.st && root.st.usage.plan ? "Claude " + root.st.usage.plan : ""
                    opacity: 0.7
                }
                PlasmaComponents.ToolButton {
                    icon.name: "view-refresh"
                    enabled: !root.loading
                    onClicked: root.refresh(true)
                    PlasmaComponents.ToolTip { text: "Refresh (re-checks updates and usage)" }
                }
                PlasmaComponents.ToolButton {
                    icon.name: "configure"
                    onClicked: Plasmoid.internalAction("configure").trigger()
                    PlasmaComponents.ToolTip { text: "Settings and shortcuts" }
                }
                PlasmaComponents.ToolButton {
                    icon.name: "utilities-terminal"
                    onClicked: root.launch("")
                    PlasmaComponents.ToolTip { text: "Open the agent" }
                }
            }
        }

        PlasmaComponents.ScrollView {
            id: scroll
            anchors.fill: parent
            PlasmaComponents.ScrollBar.horizontal.policy: PlasmaComponents.ScrollBar.AlwaysOff

            ColumnLayout {
                x: Kirigami.Units.largeSpacing
                width: scroll.availableWidth - 2 * Kirigami.Units.largeSpacing
                spacing: Kirigami.Units.smallSpacing

                // ---- ask
                PlasmaComponents.TextField {
                    id: ask
                    Layout.fillWidth: true
                    Layout.topMargin: Kirigami.Units.largeSpacing
                    placeholderText: "Ask the agent to do something…"
                    onAccepted: if (text.trim()) { root.launch(text.trim()); text = "" }
                    Component.onCompleted: forceActiveFocus()
                    Connections {
                        target: root
                        function onExpandedChanged() { if (root.expanded) ask.forceActiveFocus() }
                    }
                }

                // ---- plan usage
                Kirigami.Heading { level: 5; text: "Usage"; opacity: 0.7; Layout.topMargin: Kirigami.Units.smallSpacing }
                PlasmaComponents.Label {
                    visible: !!(root.st && root.st.usage.error)
                    text: root.st ? (root.st.usage.error || "") : ""
                    wrapMode: Text.Wrap
                    opacity: 0.7
                    Layout.fillWidth: true
                }
                Repeater {
                    model: root.st ? root.st.usage.limits : []
                    delegate: ColumnLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 0
                        RowLayout {
                            PlasmaComponents.Label { text: modelData.label; Layout.fillWidth: true }
                            PlasmaComponents.Label { text: modelData.detail; opacity: 0.7 }
                        }
                        PlasmaComponents.ProgressBar {
                            Layout.fillWidth: true
                            from: 0; to: 100
                            value: modelData.percent
                        }
                    }
                }

                // ---- system checks
                Kirigami.Heading {
                    level: 5
                    text: "System" + (root.st ? " · checked " + root.st.updated : "")
                    opacity: 0.7
                    Layout.topMargin: Kirigami.Units.largeSpacing
                }
                Repeater {
                    model: root.st ? root.st.checks : []
                    delegate: RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: Kirigami.Units.smallSpacing
                        Kirigami.Icon {
                            source: modelData.icon
                            implicitWidth: Kirigami.Units.iconSizes.smallMedium
                            implicitHeight: implicitWidth
                            color: modelData.level === "error" ? Kirigami.Theme.negativeTextColor
                                 : modelData.level === "warn" ? Kirigami.Theme.neutralTextColor
                                 : Kirigami.Theme.textColor
                            isMask: modelData.level === "error" || modelData.level === "warn"
                            opacity: modelData.level === "ok" ? 0.6 : 1
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            PlasmaComponents.Label {
                                text: modelData.title
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                                opacity: modelData.level === "ok" ? 0.7 : 1
                            }
                            PlasmaComponents.Label {
                                visible: !!modelData.detail
                                text: modelData.detail || ""
                                font: Kirigami.Theme.smallFont
                                opacity: 0.6
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                        }
                        PlasmaComponents.Button {
                            visible: !!modelData.prompt
                            text: modelData.action || "Fix"
                            onClicked: root.launch(modelData.prompt)
                        }
                    }
                }

                // ---- quick actions
                Kirigami.Heading {
                    level: 5
                    text: "Tasks"
                    opacity: 0.7
                    Layout.topMargin: Kirigami.Units.largeSpacing
                }
                Flow {
                    Layout.fillWidth: true
                    Layout.bottomMargin: Kirigami.Units.smallSpacing
                    spacing: Kirigami.Units.smallSpacing
                    Repeater {
                        model: root.st ? root.st.actions : []
                        delegate: PlasmaComponents.Button {
                            required property var modelData
                            text: modelData.label
                            icon.name: modelData.icon || ""
                            onClicked: root.launch(modelData.prompt)
                        }
                    }
                }
            }
        }
    }
}
