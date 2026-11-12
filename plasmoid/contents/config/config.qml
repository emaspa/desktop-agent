import QtQuick
import org.kde.plasma.configuration

ConfigModel {
    ConfigCategory {
        name: "Agent"
        icon: "utilities-terminal"
        source: "configAgent.qml"
    }
    ConfigCategory {
        name: "Support this project"
        icon: "help-donate"
        source: "configSupport.qml"
    }
}
