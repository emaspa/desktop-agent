import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami

KCM.SimpleKCM {
    id: page

    // The config dialog checks this on every page.
    property bool unsavedChanges: false

    ColumnLayout {
        spacing: Kirigami.Units.largeSpacing

        Kirigami.Heading {
            level: 2
            text: "Support this project"
        }
        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            text: "Desktop Agent is free and open source. If it saves you time, you can support its development:"
        }
        RowLayout {
            spacing: Kirigami.Units.largeSpacing
            QQC2.Button {
                text: "Buy Me a Coffee"
                icon.name: "help-donate"
                onClicked: Qt.openUrlExternally("https://buymeacoffee.com/emaspa")
            }
            QQC2.Button {
                text: "Ko-fi"
                icon.name: "help-donate"
                onClicked: Qt.openUrlExternally("https://ko-fi.com/emaspa")
            }
        }
        Kirigami.UrlButton {
            Layout.topMargin: Kirigami.Units.largeSpacing
            text: "Report a bug or request a feature on GitHub"
            url: "https://github.com/emaspa/desktop-agent/issues"
        }
    }
}
