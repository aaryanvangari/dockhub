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
    Layout.fillWidth: true
    Layout.fillHeight: true
    visible: controller.selectedServer !== null && controller.selectedResource !== ""
    spacing: 8

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
            required property var modelData
            width: ListView.view.width
            implicitHeight: controller.selectedResource === "Networks" ? networkItem.implicitHeight : controller.selectedResource === "Images" ? imageItem.implicitHeight : controller.selectedResource === "Stacks" ? stackItem.implicitHeight : controller.selectedResource === "Events" ? eventItem.implicitHeight : controller.selectedResource === "Volumes" ? volumeItem.implicitHeight : standardItem.implicitHeight
            NetworkListItem {
                id: networkItem
                width: parent.width
                visible: controller.selectedResource === "Networks"
                modelData: parent.modelData
                controller: resourcePage.controller
                clipboard: resourcePage.clipboard
            }
            ImageListItem {
                id: imageItem
                width: parent.width
                visible: controller.selectedResource === "Images"
                modelData: parent.modelData
                controller: resourcePage.controller
                clipboard: resourcePage.clipboard
            }
            StackListItem {
                id: stackItem
                width: parent.width
                visible: controller.selectedResource === "Stacks"
                modelData: parent.modelData
                controller: resourcePage.controller
                clipboard: resourcePage.clipboard
            }
            EventListItem {
                id: eventItem
                width: parent.width
                visible: controller.selectedResource === "Events"
                modelData: parent.modelData
            }
            VolumeListItem {
                id: volumeItem
                width: parent.width
                visible: controller.selectedResource === "Volumes"
                modelData: parent.modelData
                controller: resourcePage.controller
                clipboard: resourcePage.clipboard
            }
            Item {
                id: standardItem
                width: parent.width
                visible: controller.selectedResource !== "Networks" && controller.selectedResource !== "Images" && controller.selectedResource !== "Stacks" && controller.selectedResource !== "Events" && controller.selectedResource !== "Volumes"
                implicitHeight: standardContent.implicitHeight + 20
                RowLayout {
                    id: standardContent
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 10
                    spacing: 10
                    Kirigami.Icon {
                        source: controller.selectedResource === "Stacks" ? IconNames.stack : controller.selectedResource === "Volumes" ? IconNames.volume : IconNames.image
                        Layout.preferredWidth: 20
                        Layout.preferredHeight: 20
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        spacing: 2
                        PlasmaComponents.Label {
                            Layout.fillWidth: true
                            text: controller.resourceName(modelData)
                            font.bold: true
                            elide: Text.ElideRight
                        }
                        PlasmaComponents.Label {
                            Layout.fillWidth: true
                            text: controller.resourceDescription(modelData)
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
