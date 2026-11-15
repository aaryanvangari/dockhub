pragma ComponentBehavior: Bound

import QtQuick
import "../IconNames.js" as IconNames
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.plasma.configuration
import org.kde.kirigami as Kirigami

Kirigami.ScrollablePage {
    id: rootPage

    property alias cfg_servers: serializedServers.text
    property alias cfg_connectionType: serializedConnectionType.text

    // Settings owned by the General page.
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
    property bool cfg_compactLayout: false
    property bool cfg_compactLayoutDefault: false
    property int cfg_logSize: 1
    property int cfg_logSizeDefault: 1
    property int cfg_serverLayout: 0
    property int cfg_serverLayoutDefault: 0
    property string cfg_connectionTypeDefault: "[]"
    property string cfg_serversDefault: "[]"

    readonly property string serversLabel: i18n("Servers")
    readonly property string serverLabel: i18n("Server")
    readonly property string nameLabel: i18n("Name")
    readonly property string hostUrlLabel: i18n("Host URL")
    readonly property string socketPathLabel: i18n("Unix Socket Path")
    readonly property string exampleProduction: i18n("For example, Production")
    readonly property string connectionTypeLabel: i18n("Connection Type")
    readonly property string enabledLabel: i18n("Enabled")
    readonly property string deleteServerTooltip: i18n("Delete server")
    readonly property string addServerLabel: i18n("Add Server")
    readonly property string connectionHttp: i18n("HTTP / TCP")
    readonly property string connectionSocket: i18n("Unix Socket")

    readonly property string connectionSsh: i18n("SSH")
    readonly property string sshHostLabel: i18n("SSH Host")
    readonly property string sshPortLabel: i18n("SSH Port")
    readonly property string sshUserLabel: i18n("SSH Username")
    readonly property string sshIdentityFileLabel: i18n("SSH Identity File")
    readonly property string sshSocketPathLabel: i18n("Remote Docker Socket")

    function serverNumber(number) {
        return serverLabel + " " + String(number);
    }

    function loadServers() {
        serversModel.clear();

        try {
            const serverEntries = JSON.parse(serializedServers.text || "[]");
            const connEntries = JSON.parse(serializedConnectionType.text || "[]");
            const maxLen = Math.max(serverEntries.length, connEntries.length);

            for (let i = 0; i < maxLen; ++i) {
                serversModel.append({
                    name: (serverEntries[i] || {}).name || "",
                    host: (serverEntries[i] || {}).host || "",
                    active: (serverEntries[i] || {}).enabled !== false,
                    connectionType: (connEntries[i] || {}).connectionType || "http",
                
                    sshHost: (connEntries[i] || {}).sshHost || "",
                    sshPort: Number((connEntries[i] || {}).sshPort) || 22,
                    sshUser: (connEntries[i] || {}).sshUser || "",
                    sshIdentityFile: (connEntries[i] || {}).sshIdentityFile || "",
                    sshSocketPath: (connEntries[i] || {}).sshSocketPath || ""
                });
            }
        } catch (e) {
            // An invalid saved value starts with an empty editable list.
        }
    }

    function saveServers() {
        const serverEntries = [];
        const connEntries = [];

        for (let i = 0; i < serversModel.count; ++i) {
            const entry = serversModel.get(i);

            serverEntries.push({
                name: entry.name,
                host: entry.host,
                enabled: entry.active
            });

            connEntries.push({
                connectionType: entry.connectionType || "http",
            
                sshHost: entry.sshHost,
                sshPort: entry.sshPort,
                sshUser: entry.sshUser,
                sshIdentityFile: entry.sshIdentityFile,
                sshSocketPath: entry.sshSocketPath
            });
        }

        serializedServers.text = JSON.stringify(serverEntries);
        serializedConnectionType.text = JSON.stringify(connEntries);
    }

    ListModel {
        id: serversModel
    }

    // Keep the delegate in the page's component context.
    // This allows it to access rootPage and serversModel directly.
    Component {
        id: serverDelegateComponent

        ColumnLayout {
            id: serverDelegate

            required property int index
            required property string name
            required property string host
            required property string connectionType
            required property bool active

            required property string sshHost
            required property int sshPort
            required property string sshUser
            required property string sshIdentityFile
            required property string sshSocketPath

            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            QQC2.Label {
                text: rootPage.serverNumber(serverDelegate.index + 1)
                font.bold: true
            }

            // First row: Name and connection type.
            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    QQC2.Label {
                        text: rootPage.nameLabel
                    }

                    QQC2.TextField {
                        Layout.fillWidth: true
                        placeholderText: rootPage.exampleProduction
                        text: serverDelegate.name

                        onTextEdited: {
                            serversModel.setProperty(serverDelegate.index, "name", text);
                            rootPage.saveServers();
                        }
                    }
                }

                ColumnLayout {
                    Layout.preferredWidth: 180
                    spacing: 2

                    QQC2.Label {
                        text: rootPage.connectionTypeLabel
                    }

                    QQC2.ComboBox {
                        Layout.fillWidth: true

                        model: [
                            rootPage.connectionHttp,
                            rootPage.connectionSocket,
                            rootPage.connectionSsh
                        ]
                        
                        currentIndex: {
                            switch (serverDelegate.connectionType) {
                            case "socket":
                                return 1;
                            case "ssh":
                                return 2;
                            default:
                                return 0;
                            }
                        }
                        
                        onActivated: function(comboIndex) {
                            const types = ["http", "socket", "ssh"];
                        
                            serversModel.setProperty(
                                serverDelegate.index,
                                "connectionType",
                                types[comboIndex]
                            );
                        
                            rootPage.saveServers();
                        }
                    }
                }
            }

            // HTTP / Unix socket connection details.
            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing
                visible: serverDelegate.connectionType !== "ssh"
            
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
            
                    QQC2.Label {
                        text: serverDelegate.connectionType === "socket"
                              ? rootPage.socketPathLabel
                              : rootPage.hostUrlLabel
                    }
            
                    QQC2.TextField {
                        Layout.fillWidth: true
            
                        placeholderText: serverDelegate.connectionType === "socket"
                                         ? "/run/user/1000/docker.sock"
                                         : "http://host:2375"
            
                        text: serverDelegate.host
            
                        inputMethodHints: serverDelegate.connectionType === "http"
                                          ? Qt.ImhUrlCharactersOnly
                                          : Qt.ImhNone
            
                        onTextEdited: {
                            serversModel.setProperty(serverDelegate.index, "host", text);
                            rootPage.saveServers();
                        }
                    }
                }
            }
            
            // SSH host and port.
            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing
                visible: serverDelegate.connectionType === "ssh"
            
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
            
                    QQC2.Label {
                        text: rootPage.sshHostLabel
                    }
            
                    QQC2.TextField {
                        Layout.fillWidth: true
                        placeholderText: "Server Name or IP"
                        text: serverDelegate.sshHost
            
                        onTextEdited: {
                            serversModel.setProperty(serverDelegate.index, "sshHost", text);
                            rootPage.saveServers();
                        }
                    }
                }
            
                ColumnLayout {
                    Layout.preferredWidth: 100
                    spacing: 2
            
                    QQC2.Label {
                        text: rootPage.sshPortLabel
                    }
            
                    QQC2.SpinBox {
                        Layout.fillWidth: true
                        from: 1
                        to: 65535
                        value: serverDelegate.sshPort
            
                        onValueModified: {
                            serversModel.setProperty(serverDelegate.index, "sshPort", value);
                            rootPage.saveServers();
                        }
                    }
                }
            }
            
            // SSH username and identity file.
            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing
                visible: serverDelegate.connectionType === "ssh"
            
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
            
                    QQC2.Label {
                        text: rootPage.sshUserLabel
                    }
            
                    QQC2.TextField {
                        Layout.fillWidth: true
                        placeholderText: "john"
                        text: serverDelegate.sshUser
            
                        onTextEdited: {
                            serversModel.setProperty(serverDelegate.index, "sshUser", text);
                            rootPage.saveServers();
                        }
                    }
                }
            
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
            
                    QQC2.Label {
                        text: rootPage.sshIdentityFileLabel
                    }
            
                    QQC2.TextField {
                        Layout.fillWidth: true
                        placeholderText: "~/.ssh/id_ed25519"
                        text: serverDelegate.sshIdentityFile
            
                        onTextEdited: {
                            serversModel.setProperty(
                                serverDelegate.index,
                                "sshIdentityFile",
                                text
                            );
                            rootPage.saveServers();
                        }
                    }
                }
            }
            
            // Remote Docker socket.
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                visible: serverDelegate.connectionType === "ssh"
            
                QQC2.Label {
                    text: rootPage.sshSocketPathLabel
                }
            
                QQC2.TextField {
                    Layout.fillWidth: true
                    placeholderText: "/var/run/docker.sock"
                    text: serverDelegate.sshSocketPath
            
                    onTextEdited: {
                        serversModel.setProperty(
                            serverDelegate.index,
                            "sshSocketPath",
                            text
                        );
                        rootPage.saveServers();
                    }
                }
            }
            
            // Common server controls.
            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing
            
                Item {
                    Layout.fillWidth: true
                }
            
                QQC2.CheckBox {
                    text: rootPage.enabledLabel
                    checked: serverDelegate.active
                    Layout.alignment: Qt.AlignVCenter
            
                    onToggled: {
                        serversModel.setProperty(serverDelegate.index, "active", checked);
                        rootPage.saveServers();
                    }
                }
            
                QQC2.ToolButton {
                    icon.name: IconNames.remove
                    display: QQC2.AbstractButton.IconOnly
                    Layout.alignment: Qt.AlignVCenter
            
                    QQC2.ToolTip.text: rootPage.deleteServerTooltip
                    QQC2.ToolTip.visible: hovered
            
                    onClicked: {
                        serversModel.remove(serverDelegate.index);
                        rootPage.saveServers();
                    }
                }
            }

            Kirigami.Separator {
                Layout.fillWidth: true
                Layout.topMargin: Kirigami.Units.smallSpacing
                Layout.bottomMargin: Kirigami.Units.smallSpacing
            }
        }
    }

    // KConfig-backed properties used by Plasma's configuration dialog.
    QQC2.TextField {
        id: serializedServers
        visible: false
    }

    QQC2.TextField {
        id: serializedConnectionType
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
                text: rootPage.serversLabel
                level: 2
            }

            Kirigami.Separator {
                Layout.fillWidth: true
            }

            Repeater {
                model: serversModel
                delegate: serverDelegateComponent
            }
        }

        QQC2.Button {
            text: rootPage.addServerLabel
            icon.name: IconNames.add
            Layout.alignment: Qt.AlignLeft

            onClicked: {
                serversModel.append({
                    name: "",
                    host: "",
                    connectionType: "http",
                    active: true,
                
                    sshHost: "",
                    sshPort: 22,
                    sshUser: "",
                    sshIdentityFile: "",
                    sshSocketPath: ""
                });

                rootPage.saveServers();
            }
        }
    }
}