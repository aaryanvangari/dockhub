import QtQuick
import "../shared" as Shared
import "../IconNames.js" as IconNames
import QtQuick.Layouts
import org.kde.plasma.components 3.0 as PlasmaComponents
import org.kde.kirigami as Kirigami

Item {
    id: stackRow
    required property var modelData
    property var controller
    property var clipboard
    readonly property bool expanded: controller.expandedStackName === modelData.name
    width: ListView.view ? ListView.view.width : parent.width
    implicitHeight: content.implicitHeight + 8

    ColumnLayout {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: 8

        Item {
            Layout.fillWidth: true
            implicitHeight: heading.implicitHeight + 12
            RowLayout {
                id: heading
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10
                Kirigami.Icon {
                    source: IconNames.stack
                    Layout.preferredWidth: 20
                    Layout.preferredHeight: 20
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    spacing: 2
                    PlasmaComponents.Label {
                        Layout.fillWidth: true
                        text: modelData.name || "—"
                        font.bold: true
                        elide: Text.ElideRight
                    }
                    PlasmaComponents.Label {
                        Layout.fillWidth: true
                        text: String(modelData.containers) + " " + (modelData.containers === 1 ? Shared.Strings.container : Shared.Strings.containersLower) + " · " + String(modelData.running) + " " + Shared.Strings.runningLower
                        opacity: 0.8
                        font.pixelSize: 12
                    }
                }
                Kirigami.Icon {
                    source: stackRow.expanded ? IconNames.collapse : IconNames.expand
                    Layout.preferredWidth: 16
                    Layout.preferredHeight: 16
                }
            }
            MouseArea {
                anchors.fill: parent
                z: -1
                cursorShape: Qt.PointingHandCursor
                onClicked: controller.toggleStackExpanded(modelData)
            }
        }

        ColumnLayout {
            visible: stackRow.expanded
            Layout.fillWidth: true
            spacing: 0
            Repeater {
                model: modelData.containerItems || []
                delegate: Item {
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: containerItem.implicitHeight
                    ContainerListItem {
                        id: containerItem
                        width: parent.width
                        modelData: parent.modelData
                        controller: stackRow.controller
                        clipboard: stackRow.clipboard
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Qt.alpha(Kirigami.Theme.textColor, 0.25)
        }
    }
}
