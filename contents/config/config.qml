import QtQuick
import "../ui/IconNames.js" as IconNames
import org.kde.plasma.configuration

ConfigModel {
    ConfigCategory {
        name: i18n("General")
        icon: IconNames.settings
        source: "config/ConfigGeneral.qml"
    }
    ConfigCategory {
        name: i18n("Servers")
        icon: IconNames.server
        source: "config/ConfigServers.qml"
    }
}
