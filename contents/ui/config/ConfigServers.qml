import QtQuick
import "../IconNames.js" as IconNames
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.plasma.configuration
import org.kde.kirigami as Kirigami

Kirigami.ScrollablePage {
    id: page

    property alias cfg_servers: serializedServers.text
    // Plasma supplies the configuration values and defaults to each category page.
    // Declare the settings owned by the General page here too so page creation succeeds.
    property int cfg_updateInterval: 30
    property int cfg_updateIntervalDefault: 30
    property int cfg_serverOverviewRefreshInterval: 45
    property int cfg_serverOverviewRefreshIntervalDefault: 45
    property int cfg_usageInterval: 5
    property int cfg_usageIntervalDefault: 5
    property int cfg_serverEntryColumns: 2
    property int cfg_serverEntryColumnsDefault: 2
    property bool cfg_showServerImages: false
    property bool cfg_showServerImagesDefault: false
    property bool cfg_showServerVolumes: false
    property bool cfg_showServerVolumesDefault: false
    property string cfg_serversDefault: "[]"
    readonly property string serversLabel: i18n("Servers")
    readonly property string serverLabel: i18n("Server")
    readonly property string nameLabel: i18n("Name")
    readonly property string hostUrlLabel: i18n("Host URL")
    readonly property string exampleProduction: i18n("For example, Production")
    readonly property string enabledLabel: i18n("Enabled")
    readonly property string deleteServerTooltip: i18n("Delete server")
    readonly property string addServerLabel: i18n("Add Server")

    function serverNumber(number) {
        return serverLabel + " " + String(number);
    }

    function loadServers() {
        serversModel.clear();
        try {
            const entries = JSON.parse(serializedServers.text || "[]");
            for (let i = 0; i < entries.length; ++i) {
                serversModel.append({
                    name: entries[i].name || "",
                    host: entries[i].host || "",
                    active: entries[i].enabled !== false
                });
            }
        } catch (e) {
            // An invalid saved value starts with an empty editable list.
        }
    }

    function saveServers() {
        const entries = [];
        for (let i = 0; i < serversModel.count; ++i) {
            const entry = serversModel.get(i);
            entries.push({
                name: entry.name,
                host: entry.host,
                enabled: entry.active
            });
        }
        serializedServers.text = JSON.stringify(entries);
    }

    ListModel {
        id: serversModel
    }
    // This control is the KConfig-backed property used by Plasma's config dialog.
    QQC2.TextField {
        id: serializedServers
        visible: false
    }

    Component.onCompleted: loadServers()

    ColumnLayout {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.right: parent.right
        spacing: Kirigami.Units.largeSpacing

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.mediumSpacing

            Kirigami.Heading {
                text: page.serversLabel
                level: 2
            }
            Kirigami.Separator {
                Layout.fillWidth: true
            }

            Repeater {
                model: serversModel
                delegate: ColumnLayout {
                    required property int index
                    required property string name
                    required property string host
                    required property bool active
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing

                    QQC2.Label {
                        text: page.serverNumber(index + 1)
                        font.bold: true
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Kirigami.Units.smallSpacing

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            QQC2.Label {
                                text: page.nameLabel
                            }
                            QQC2.TextField {
                                Layout.fillWidth: true
                                placeholderText: page.exampleProduction
                                text: name
                                onTextEdited: {
                                    serversModel.setProperty(index, "name", text);
                                    page.saveServers();
                                }
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            QQC2.Label {
                                text: page.hostUrlLabel
                            }
                            QQC2.TextField {
                                Layout.fillWidth: true
                                placeholderText: "http://host:2375"
                                text: host
                                inputMethodHints: Qt.ImhUrlCharactersOnly
                                onTextEdited: {
                                    serversModel.setProperty(index, "host", text);
                                    page.saveServers();
                                }
                            }
                        }
                        QQC2.CheckBox {
                            text: page.enabledLabel
                            checked: active
                            Layout.alignment: Qt.AlignBottom
                            onToggled: {
                                serversModel.setProperty(index, "active", checked);
                                page.saveServers();
                            }
                        }
                        QQC2.ToolButton {
                            icon.name: IconNames.remove
                            display: QQC2.AbstractButton.IconOnly
                            Layout.alignment: Qt.AlignBottom
                            QQC2.ToolTip.text: page.deleteServerTooltip
                            QQC2.ToolTip.visible: hovered
                            onClicked: {
                                serversModel.remove(index);
                                page.saveServers();
                            }
                        }
                    }
                }
            }
        }
        QQC2.Button {
            text: page.addServerLabel
            icon.name: IconNames.add
            Layout.alignment: Qt.AlignLeft
            onClicked: {
                serversModel.append({
                    name: "",
                    host: "",
                    active: true
                });
                page.saveServers();
            }
        }
    }
}
