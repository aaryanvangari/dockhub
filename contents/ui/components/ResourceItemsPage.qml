import QtQuick
import "../shared" as Shared
import "../IconNames.js" as IconNames
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.plasma.components 3.0 as PlasmaComponents
import org.kde.kirigami as Kirigami

ColumnLayout {
    id: resourcePage
    property var controller
    property var clipboard
    property var unixSocketBridge
    Layout.fillWidth: true
    Layout.fillHeight: true
    visible: controller.selectedServer !== null &&
            controller.selectedResource !== ""
    spacing: 8

    Loader {
        Layout.fillWidth: true
        Layout.fillHeight: true
    
        active: controller.selectedResource === "Logs"
        visible: active
    
        sourceComponent: Component {
            ContainerLogsPage {
                anchors.fill: parent
    
                server: controller.selectedServer
                containerId: controller.logsContainerId
                containerName: controller.logsContainerName
                unixSocketBridge: resourcePage.unixSocketBridge
                configuration: controller.configuration
                active: true
            }
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: resourcePage.spacing
    
        visible: controller.selectedResource !== "Logs"
    
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: controller.resourceLoading && controller.resourceItems.length === 0
            QQC2.BusyIndicator {
                anchors.centerIn: parent
                running: parent.visible
            }
            PlasmaComponents.Label {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.verticalCenter
                anchors.topMargin: 36
                text: Shared.Strings.loadingResource(controller.selectedResource)
            }
        }
        PlasmaComponents.Label {
            visible: !controller.resourceLoading && controller.resourceError !== ""
            Layout.fillWidth: true
            text: controller.resourceError
            color: Kirigami.Theme.negativeTextColor
            wrapMode: Text.Wrap
        }
        PlasmaComponents.Label {
            visible: !controller.resourceLoading && controller.resourceError === "" && controller.resourceItems.length === 0
            Layout.fillWidth: true
            Layout.fillHeight: true
            text: Shared.Strings.emptyResource(controller.selectedResource)
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: controller.resourceItems.length > 0
            clip: true
            spacing: 0
            model: controller.resourceItems.slice(controller.resourcePage * controller.resourcePageSize, (controller.resourcePage + 1) * controller.resourcePageSize)
            delegate: Item {
                id: row
            
                required property var modelData
            
                width: ListView.view.width
                implicitHeight: rowLoader.implicitHeight
            
                Loader {
                    id: rowLoader
                    width: parent.width
            
                    sourceComponent: {
                        switch (controller.selectedResource) {
                        case "Networks":
                            return networkComponent;
                        case "Images":
                            return imageComponent;
                        case "Stacks":
                            return stackComponent;
                        case "Events":
                            return eventComponent;
                        case "Volumes":
                            return volumeComponent;
                        default:
                            return standardComponent;
                        }
                    }
                }
            
                Component {
                    id: networkComponent
            
                    NetworkListItem {
                        width: row.width
                        modelData: row.modelData
                        controller: resourcePage.controller
                        clipboard: resourcePage.clipboard
                    }
                }
            
                Component {
                    id: imageComponent
            
                    ImageListItem {
                        width: row.width
                        modelData: row.modelData
                        controller: resourcePage.controller
                        clipboard: resourcePage.clipboard
                    }
                }
            
                Component {
                    id: stackComponent
            
                    StackListItem {
                        width: row.width
                        modelData: row.modelData
                        controller: resourcePage.controller
                        clipboard: resourcePage.clipboard
                    }
                }
            
                Component {
                    id: eventComponent
            
                    EventListItem {
                        width: row.width
                        modelData: row.modelData
                    }
                }
            
                Component {
                    id: volumeComponent
            
                    VolumeListItem {
                        width: row.width
                        modelData: row.modelData
                        controller: resourcePage.controller
                        clipboard: resourcePage.clipboard
                    }
                }
            
                Component {
                    id: standardComponent
            
                    Item {
                        width: row.width
                        implicitHeight: standardContent.implicitHeight + 20
            
                        RowLayout {
                            id: standardContent
            
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 10
                            spacing: 10
            
                            Kirigami.Icon {
                                source: IconNames.image
                                Layout.preferredWidth: 20
                                Layout.preferredHeight: 20
                            }
            
                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                spacing: 2
            
                                PlasmaComponents.Label {
                                    Layout.fillWidth: true
                                    text: controller.resourceName(row.modelData)
                                    font.bold: true
                                    elide: Text.ElideRight
                                }
            
                                PlasmaComponents.Label {
                                    Layout.fillWidth: true
                                    text: controller.resourceDescription(row.modelData)
                                    opacity: 0.8
                                    font.pixelSize: 12
                                    elide: Text.ElideRight
                                }
                            }
                        }
            
                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: 1
                            color: Qt.alpha(Kirigami.Theme.textColor, 0.25)
                        }
                    }
                }
            }
        }
        RowLayout {
            visible: !controller.resourceLoading && controller.resourceItems.length > controller.resourcePageSize
            Layout.fillWidth: true
            PlasmaComponents.ToolButton {
                text: Shared.Strings.previous
                icon.name: IconNames.back
                enabled: controller.resourcePage > 0
                onClicked: --controller.resourcePage
            }
            Item {
                Layout.fillWidth: true
            }
            PlasmaComponents.Label {
                text: Shared.Strings.pageText(controller.resourcePage + 1, Math.ceil(controller.resourceItems.length / controller.resourcePageSize))
            }
            Item {
                Layout.fillWidth: true
            }
            PlasmaComponents.ToolButton {
                text: Shared.Strings.next
                icon.name: IconNames.next
                enabled: (controller.resourcePage + 1) * controller.resourcePageSize < controller.resourceItems.length
                onClicked: ++controller.resourcePage
            }
        }
    }
}
