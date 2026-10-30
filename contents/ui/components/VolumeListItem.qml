import QtQuick
import "../shared" as Shared
import "../IconNames.js" as IconNames
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.plasma.components 3.0 as PlasmaComponents
import org.kde.kirigami as Kirigami

Item {
    id: volumeRow
    required property var modelData
    property var controller
    property var clipboard
    readonly property var details: modelData.inspect || modelData
    readonly property var attachedContainers: modelData.attachedContainers || []
    readonly property bool expanded: controller.expandedVolumeName === (modelData.Name || modelData.name)
    width: ListView.view.width
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
                    source: IconNames.volume
                    Layout.preferredWidth: 20
                    Layout.preferredHeight: 20
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    spacing: 2
                    PlasmaComponents.Label {
                        Layout.fillWidth: true
                        text: modelData.Name || modelData.name || "—"
                        font.bold: true
                        elide: Text.ElideRight
                    }
                    PlasmaComponents.Label {
                        Layout.fillWidth: true
                        text: Shared.Strings.driver + ": " + (modelData.Driver || "—")
                        opacity: 0.8
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }
                }
                Kirigami.Icon {
                    source: volumeRow.expanded ? IconNames.collapse : IconNames.expand
                    Layout.preferredWidth: 16
                    Layout.preferredHeight: 16
                }
            }
            MouseArea {
                anchors.fill: parent
                z: -1
                cursorShape: Qt.PointingHandCursor
                onClicked: controller.toggleVolumeExpanded(modelData)
            }
        }

        ColumnLayout {
            visible: volumeRow.expanded
            Layout.fillWidth: true
            spacing: 8
            PlasmaComponents.Label {
                Layout.fillWidth: true
                visible: Boolean(modelData.inspectLoading)
                text: Shared.Strings.loadingVolumeDetails
            }
            PlasmaComponents.Label {
                Layout.fillWidth: true
                visible: Boolean(modelData.inspectError)
                text: modelData.inspectError || ""
                color: Kirigami.Theme.negativeTextColor
                wrapMode: Text.Wrap
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: infoContent.implicitHeight + 20
                radius: 7
                color: Kirigami.Theme.alternateBackgroundColor
                ColumnLayout {
                    id: infoContent
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 10
                    spacing: 6
                    PlasmaComponents.Label {
                        Layout.fillWidth: true
                        text: Shared.Strings.volumeInformation
                        font.bold: true
                    }
                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2
                        columnSpacing: 12
                        rowSpacing: 4
                        PlasmaComponents.Label {
                            text: Shared.Strings.idLabel
                            opacity: 0.7
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            PlasmaComponents.Label {
                                Layout.fillWidth: true
                                text: details.Name || modelData.Name || modelData.name || "—"
                                elide: Text.ElideMiddle
                            }
                            PlasmaComponents.ToolButton {
                                icon.name: IconNames.copy
                                display: QQC2.AbstractButton.IconOnly
                                QQC2.ToolTip.text: Shared.Strings.copyVolumeId
                                QQC2.ToolTip.visible: hovered
                                onClicked: clipboard.content = String(details.Name || modelData.Name || modelData.name || "")
                            }
                        }
                        PlasmaComponents.Label {
                            text: Shared.Strings.created
                            opacity: 0.7
                        }
                        PlasmaComponents.Label {
                            Layout.fillWidth: true
                            text: details.CreatedAt || modelData.CreatedAt || "—"
                            wrapMode: Text.Wrap
                        }
                        PlasmaComponents.Label {
                            text: Shared.Strings.mountPath
                            opacity: 0.7
                        }
                        PlasmaComponents.Label {
                            Layout.fillWidth: true
                            text: details.Mountpoint || modelData.Mountpoint || "—"
                            wrapMode: Text.WrapAnywhere
                        }
                        PlasmaComponents.Label {
                            text: Shared.Strings.driver
                            opacity: 0.7
                        }
                        PlasmaComponents.Label {
                            Layout.fillWidth: true
                            text: details.Driver || modelData.Driver || "—"
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: containerContent.implicitHeight + 20
                radius: 7
                color: Kirigami.Theme.alternateBackgroundColor
                ColumnLayout {
                    id: containerContent
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 10
                    spacing: 6
                    RowLayout {
                        Layout.fillWidth: true
                        Kirigami.Icon {
                            source: IconNames.container
                            Layout.preferredWidth: 18
                            Layout.preferredHeight: 18
                        }
                        PlasmaComponents.Label {
                            Layout.fillWidth: true
                            text: Shared.Strings.containersUsingThisVolume
                            font.bold: true
                        }
                    }
                    PlasmaComponents.Label {
                        Layout.fillWidth: true
                        visible: Boolean(modelData.attachedLoading)
                        text: Shared.Strings.loadingContainerMounts
                    }
                    PlasmaComponents.Label {
                        Layout.fillWidth: true
                        visible: Boolean(modelData.attachedError)
                        text: modelData.attachedError || ""
                        color: Kirigami.Theme.negativeTextColor
                        wrapMode: Text.Wrap
                    }
                    PlasmaComponents.Label {
                        Layout.fillWidth: true
                        visible: !modelData.attachedLoading && !modelData.attachedError && attachedContainers.length === 0
                        text: Shared.Strings.noContainersAreUsingThisVolume
                        opacity: 0.75
                    }
                    Repeater {
                        model: attachedContainers
                        delegate: ColumnLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: 4
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 1
                                color: Qt.alpha(Kirigami.Theme.textColor, 0.18)
                            }
                            PlasmaComponents.Label {
                                Layout.fillWidth: true
                                text: modelData.Name || "—"
                                font.bold: true
                                elide: Text.ElideRight
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                PlasmaComponents.Label {
                                    Layout.fillWidth: true
                                    text: Shared.Strings.mountedAt + ": " + (modelData.Destination || "—")
                                    elide: Text.ElideRight
                                }
                                PlasmaComponents.Label {
                                    text: Shared.Strings.readOnly + ": " + (modelData.RW ? Shared.Strings.no : Shared.Strings.yes)
                                }
                            }
                        }
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
