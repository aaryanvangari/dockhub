import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.plasma.configuration
import org.kde.kirigami as Kirigami

Kirigami.ScrollablePage {
    id: page

    property alias cfg_updateInterval: updateIntervalSpin.value
    property alias cfg_serverOverviewRefreshInterval: serverOverviewRefreshSpin.value
    property alias cfg_usageInterval: usageIntervalSpin.value
    property alias cfg_serverEntryColumns: serverListColumns.value
    property alias cfg_showServerImages: serverImagesCheck.checked
    property alias cfg_showServerVolumes: serverVolumesCheck.checked
    property alias cfg_servers: serializedServers.text
    property int cfg_updateIntervalDefault: 30
    property int cfg_serverOverviewRefreshIntervalDefault: 45
    property int cfg_usageIntervalDefault: 5
    property int cfg_serverEntryColumnsDefault: 2
    property bool cfg_showServerImagesDefault: false
    property bool cfg_showServerVolumesDefault: false
    property string cfg_serversDefault: "[]"
    readonly property string generalLabel: i18n("General")
    readonly property string refreshDashboardEveryLabel: i18n("Refresh dashboard every")
    readonly property string refreshServerOverviewEveryLabel: i18n("Refresh server overview every")
    readonly property string refreshUsageEveryLabel: i18n("Refresh usage every")
    readonly property string secondsSuffix: i18n(" seconds")
    readonly property string serverLabel: i18n("Server")
    readonly property string serverOverviewColumnsLabel: i18n("Server overview")
    readonly property string columnsSuffix: i18n("columns")
    readonly property string extraServerCallsNote: i18n("Showing Images and Volumes adds API calls to each server overview refresh.")
    readonly property string imagesLabel: i18n("Images")
    readonly property string volumesLabel: i18n("Volumes")

    ColumnLayout {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.right: parent.right
        spacing: Kirigami.Units.largeSpacing

        Kirigami.FormLayout {
            Layout.fillWidth: true
            Kirigami.Separator {
                Kirigami.FormData.isSection: true
                Kirigami.FormData.label: page.generalLabel
            }
            QQC2.SpinBox {
                id: updateIntervalSpin
                Kirigami.FormData.label: page.refreshDashboardEveryLabel
                from: 1
                to: 3600
                editable: true
                textFromValue: function (value) {
                    return value + page.secondsSuffix;
                }
                valueFromText: function (text) {
                    return parseInt(text);
                }
            }
            QQC2.SpinBox {
                id: usageIntervalSpin
                Kirigami.FormData.label: page.refreshUsageEveryLabel
                from: 1
                to: 3600
                editable: true
                textFromValue: function (value) {
                    return value + page.secondsSuffix;
                }
                valueFromText: function (text) {
                    return parseInt(text);
                }
            }
        }

        Kirigami.FormLayout {
            Layout.fillWidth: true

            Kirigami.Separator {
                Kirigami.FormData.isSection: true
                Kirigami.FormData.label: page.serverLabel
            }

            QQC2.SpinBox {
                id: serverOverviewRefreshSpin
                Kirigami.FormData.label: page.refreshServerOverviewEveryLabel
                from: 1
                to: 3600
                editable: true
                textFromValue: function (value) {
                    return value + page.secondsSuffix;
                }
                valueFromText: function (text) {
                    return parseInt(text);
                }
            }

            QQC2.SpinBox {
                id: serverListColumns
                Kirigami.FormData.label: page.serverOverviewColumnsLabel
                from: 2
                to: 3
                editable: false
                textFromValue: function (value) {
                    return String(value) + " " + page.columnsSuffix;
                }
            }

            QQC2.CheckBox {
                id: serverImagesCheck
                Kirigami.FormData.label: " "
                text: page.imagesLabel
            }

            QQC2.CheckBox {
                id: serverVolumesCheck
                Kirigami.FormData.label: " "
                text: page.volumesLabel
            }

            QQC2.Label {
                Layout.fillWidth: true
                Kirigami.FormData.label: " "
                text: page.extraServerCallsNote
                wrapMode: Text.WordWrap
                opacity: 0.75
            }
        }
        QQC2.TextField {
            id: serializedServers
            visible: false
        }
    }
}
