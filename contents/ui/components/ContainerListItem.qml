import QtQuick
import "../shared" as Shared
import "../IconNames.js" as IconNames
import "ContainerData.js" as ContainerData
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.plasma.components 3.0 as PlasmaComponents
import org.kde.kirigami as Kirigami

QQC2.Frame {
    id: delegateRoot
    property var clipboard
    required property var modelData
    property var controller
    width: ListView.view ? ListView.view.width : parent.width
    padding: 8
    background: Rectangle {
        color: Kirigami.Theme.backgroundColor
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 1
            color: Qt.alpha(Kirigami.Theme.textColor, 0.25)
        }
    }
    ColumnLayout {
        anchors.fill: parent
        spacing: 6
        Item {
            Layout.fillWidth: true
            implicitHeight: rowContent.implicitHeight
            MouseArea {
                anchors.fill: parent
                onClicked: controller.toggleExpanded(modelData)
                cursorShape: Qt.PointingHandCursor
            }
            ColumnLayout {
                id: rowContent
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                spacing: 3
                RowLayout {
                    Layout.fillWidth: true
                    PlasmaComponents.Label {
                        Layout.fillWidth: true
                        text: ContainerData.containerName(modelData)
                        color: ContainerData.isRunning(modelData) ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.negativeTextColor
                        font.bold: true
                        elide: Text.ElideRight
                    }
                    PlasmaComponents.ToolButton {
                        icon.name: ContainerData.isRunning(modelData) ? IconNames.containerStop : IconNames.containerStart
                        text: ContainerData.isRunning(modelData) ? Shared.Strings.stop : Shared.Strings.start
                        display: QQC2.AbstractButton.TextBesideIcon
                        QQC2.ToolTip.text: ContainerData.isRunning(modelData) ? Shared.Strings.stopContainer : Shared.Strings.startContainer
                        QQC2.ToolTip.visible: hovered
                        onClicked: controller.setContainerState(modelData, !ContainerData.isRunning(modelData))
                    }
                }
                Row {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 24
                    spacing: 10
                    Item {
                        width: (parent.width - parent.spacing) / 2
                        height: parent.height
                        RowLayout {
                            anchors.fill: parent
                            spacing: 4
                            Kirigami.Icon {
                                source: IconNames.cpu
                                Layout.preferredWidth: 20
                                Layout.preferredHeight: 20
                            }
                            PlasmaComponents.Label {
                                text: Shared.Strings.cpuLabel
                                opacity: 0.7
                            }
                            PlasmaComponents.Label {
                                text: ContainerData.cpu(modelData)
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                                opacity: 0.9
                            }
                        }
                    }
                    Item {
                        width: (parent.width - parent.spacing) / 2
                        height: parent.height
                        RowLayout {
                            anchors.fill: parent
                            spacing: 4
                            Kirigami.Icon {
                                source: IconNames.memory
                                Layout.preferredWidth: 20
                                Layout.preferredHeight: 20
                            }
                            PlasmaComponents.Label {
                                text: Shared.Strings.memory
                                opacity: 0.7
                            }
                            PlasmaComponents.Label {
                                text: ContainerData.memory(modelData) + " (" + ContainerData.memoryPercent(modelData) + ")"
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                                opacity: 0.9
                            }
                        }
                    }
                }
                Row {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 24
                    spacing: 10
                    Item {
                        width: (parent.width - parent.spacing) / 2
                        height: parent.height
                        RowLayout {
                            anchors.fill: parent
                            spacing: 4
                            Kirigami.Icon {
                                source: IconNames.id
                                Layout.preferredWidth: 20
                                Layout.preferredHeight: 20
                            }
                            PlasmaComponents.Label {
                                text: Shared.Strings.idLabel
                                opacity: 0.7
                            }
                            PlasmaComponents.Label {
                                text: ContainerData.shortId(modelData)
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                                opacity: 0.9
                            }
                            PlasmaComponents.ToolButton {
                                Layout.preferredWidth: 24
                                Layout.preferredHeight: 24
                                icon.name: IconNames.copy
                                display: QQC2.AbstractButton.IconOnly
                                QQC2.ToolTip.text: Shared.Strings.copyShortId
                                QQC2.ToolTip.visible: hovered
                                onClicked: clipboard.content = ContainerData.shortId(modelData)
                            }
                        }
                    }
                    Item {
                        width: (parent.width - parent.spacing) / 2
                        height: parent.height
                        RowLayout {
                            anchors.fill: parent
                            spacing: 4
                            Kirigami.Icon {
                                source: IconNames.containerDetails
                                Layout.preferredWidth: 20
                                Layout.preferredHeight: 20
                            }
                            PlasmaComponents.Label {
                                text: Shared.Strings.status
                                opacity: 0.7
                            }
                            PlasmaComponents.Label {
                                text: ContainerData.field(modelData.Status)
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                                opacity: 0.9
                            }
                        }
                    }
                }
            }
        }
        ContainerDetail {
            controller: delegateRoot.controller
            modelData: delegateRoot.modelData
            clipboard: delegateRoot.clipboard
        }
    }
}
