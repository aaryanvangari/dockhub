pragma ComponentBehavior: Bound

import QtQuick
import "shared" as Shared
import "IconNames.js" as IconNames
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.components 3.0 as PlasmaComponents
import org.kde.kquickcontrolsaddons as KQuickControlsAddons
import org.kde.kirigami as Kirigami
import "components" as Components

PlasmoidItem {
    id: root
    Plasmoid.icon: IconNames.app
    property alias sharedClipboard: clipboard

    KQuickControlsAddons.Clipboard {
        id: clipboard
    }
    compactRepresentation: PlasmaComponents.ToolButton {
        icon.name: IconNames.app
        display: QQC2.AbstractButton.IconOnly
        onClicked: root.expanded = !root.expanded
    }

    fullRepresentation: Item {
        id: fullView
        Layout.minimumWidth: 460
        Layout.preferredWidth: 460
        Layout.minimumHeight: 600
        Layout.preferredHeight: 760
        implicitWidth: 460
        implicitHeight: 760
        Components.DashboardController {
            id: page
            configuration: Plasmoid.configuration
        }
        RowLayout {
            id: topBar
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 10
            height: Math.max(implicitHeight, Kirigami.Units.gridUnit * 2)
            PlasmaComponents.ToolButton {
                visible: page.selectedServer !== null
                icon.name: IconNames.back
                display: QQC2.AbstractButton.IconOnly
                QQC2.ToolTip.text: page.selectedResource !== "" ? Shared.Strings.backToServer : Shared.Strings.backToServers
                QQC2.ToolTip.visible: hovered
                onClicked: {
                    if (page.selectedResource !== "") {
                        page.selectedResource = "";
                        page.resourceError = "";
                        page.requestContainerSearch();
                        page.refreshContainers(true);
                    } else {
                        page.selectedServer = null;
                        page.errorText = "";
                        page.noticeText = "";
                        page.refreshDashboard();
                    }
                }
            }
            Kirigami.Heading {
                Layout.fillWidth: true
                level: 2
                text: page.selectedResource !== "" ? page.selectedServer.name + " · " + page.selectedResource : page.selectedServer ? page.selectedServer.name : Shared.Strings.dockhub
                font.bold: true
                elide: Text.ElideRight
            }
            PlasmaComponents.ToolButton {
                icon.name: IconNames.refresh
                display: QQC2.AbstractButton.IconOnly
                QQC2.ToolTip.text: Shared.Strings.refresh
                QQC2.ToolTip.visible: hovered
                onClicked: {
                    if (page.selectedResource !== "")
                        page.refreshCurrentResource();
                    else if (page.selectedServer)
                        page.refreshContainers(true);
                    else
                        page.refreshDashboard();
                }
            }
            PlasmaComponents.ToolButton {
                icon.name: IconNames.settings
                text: Shared.Strings.settings
                display: QQC2.AbstractButton.IconOnly
                onClicked: Plasmoid.internalAction("configure").trigger()
            }
        }
        ColumnLayout {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: topBar.bottom
            anchors.bottom: parent.bottom
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            anchors.bottomMargin: 10
            anchors.topMargin: 10
            spacing: 10
            PlasmaComponents.Label {
                Layout.fillWidth: true
                visible: page.errorText !== "" || page.noticeText !== ""
                text: page.errorText || page.noticeText
                color: page.errorText ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.textColor
                wrapMode: Text.Wrap
            }
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: page.selectedServer === null
                ListView {
                    anchors.fill: parent
                    clip: true
                    spacing: 4
                    model: page.servers
                    delegate: Components.ServerListItem {
                        controller: page
                    }
                }
                PlasmaComponents.Label {
                    anchors.centerIn: parent
                    visible: page.servers.length === 0
                    text: Shared.Strings.noEnabledServersConfiguredOpenSettingsToAddOne
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: page.selectedServer !== null && page.selectedResource === ""
                QQC2.TextField {
                    id: containerSearchField
                    Layout.fillWidth: true
                    text: page.containerSearchQuery
                    placeholderText: Shared.Strings.searchByNameImagePortOrIP
                    Accessible.name: Shared.Strings.searchByNameImagePortOrIP
                    onTextEdited: {
                        page.containerSearchQuery = text;
                        page.requestContainerSearch();
                    }
                }
                Connections {
                    target: page
                    function onContainerSearchQueryChanged() {
                        if (containerSearchField.text !== page.containerSearchQuery)
                            containerSearchField.text = page.containerSearchQuery;
                    }
                }
                Components.ServerLegend {
                    Layout.fillWidth: true
                    summary: page.serverSummary
                    onResourceSelected: resource => page.openResource(resource)
                }
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    ListView {
                        id: containerList
                        anchors.fill: parent
                        clip: true
                        spacing: 6
                        model: page.filteredContainers
                        delegate: Components.ContainerListItem {
                            controller: page
                            clipboard: root.sharedClipboard
                        }
                    }
                    PlasmaComponents.Label {
                        anchors.centerIn: parent
                        visible: page.containers.length > 0 && page.filteredContainers.length === 0
                        text: Shared.Strings.noMatchingContainers
                    }
                }
            }
            Components.ResourceItemsPage {
                Layout.fillWidth: true
                Layout.fillHeight: true
                controller: page
                clipboard: root.sharedClipboard
            }
        }
    }
}
