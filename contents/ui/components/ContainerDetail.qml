import QtQuick
import "../shared" as Shared
import "../IconNames.js" as IconNames
import "ContainerData.js" as ContainerData
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.plasma.components 3.0 as PlasmaComponents
import org.kde.kirigami as Kirigami

ColumnLayout {
    property var controller
    property var clipboard
    required property var modelData
    Layout.fillWidth: true
    visible: controller.expandedId === modelData.Id
    PlasmaComponents.TabBar {
        Layout.fillWidth: true
        currentIndex: controller.detailTab
        onCurrentIndexChanged: controller.detailTab = currentIndex
        PlasmaComponents.TabButton {
            text: Shared.Strings.information
        }
        PlasmaComponents.TabButton {
            text: Shared.Strings.logs
        }
    }
    Flickable {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(Math.max(detailContent.height, 120), 300)
        contentHeight: detailContent.height
        clip: true

        Column {
            id: detailContent
            width: parent.width
            height: implicitHeight
            spacing: 8

            Rectangle {
                visible: controller.detailTab === 0
                width: parent.width
                height: nameCpuMemory.implicitHeight + 20
                radius: 7
                color: Kirigami.Theme.alternateBackgroundColor
                Column {
                    id: nameCpuMemory
                    x: 10
                    y: 10
                    width: parent.width - 20
                    spacing: 6
                    RowLayout {
                        width: parent.width
                        Kirigami.Icon {
                            source: IconNames.container
                            Layout.preferredWidth: 20
                            Layout.preferredHeight: 20
                        }
                        PlasmaComponents.Label {
                            text: Shared.Strings.name
                            opacity: 0.7
                            Layout.fillWidth: true
                        }
                        PlasmaComponents.ToolButton {
                            icon.name: IconNames.copy
                            display: QQC2.AbstractButton.IconOnly
                            QQC2.ToolTip.text: Shared.Strings.copyContainerName
                            QQC2.ToolTip.visible: hovered
                            onClicked: clipboard.content = ContainerData.containerName(modelData)
                        }
                    }
                    PlasmaComponents.Label {
                        width: parent.width
                        text: ContainerData.containerName(modelData)
                        font.bold: true
                        elide: Text.ElideRight
                    }
                    Row {
                        width: parent.width
                        spacing: 18
                        Column {
                            width: (parent.width - parent.spacing) / 2
                            spacing: 3
                            Row {
                                spacing: 6
                                Kirigami.Icon {
                                    source: IconNames.cpu
                                    width: 20
                                    height: 20
                                }
                                PlasmaComponents.Label {
                                    text: Shared.Strings.cpuLabel
                                    opacity: 0.7
                                }
                            }
                            PlasmaComponents.Label {
                                text: ContainerData.cpu(modelData)
                                font.bold: true
                            }
                        }
                        Column {
                            width: (parent.width - parent.spacing) / 2
                            spacing: 3
                            Row {
                                spacing: 6
                                Kirigami.Icon {
                                    source: IconNames.memory
                                    width: 20
                                    height: 20
                                }
                                PlasmaComponents.Label {
                                    text: Shared.Strings.memoryUsage
                                    opacity: 0.7
                                }
                            }
                            PlasmaComponents.Label {
                                width: parent.width
                                text: ContainerData.memoryUsage(modelData)
                                font.bold: true
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }

            Rectangle {
                visible: controller.detailTab === 0
                width: parent.width
                height: identityCard.implicitHeight + 20
                radius: 7
                color: Kirigami.Theme.alternateBackgroundColor
                Column {
                    id: identityCard
                    x: 10
                    y: 10
                    width: parent.width - 20
                    spacing: 6
                    Row {
                        width: parent.width
                        spacing: 12
                        Column {
                            width: (parent.width - parent.spacing) / 2
                            spacing: 3
                            Row {
                                width: parent.width
                                spacing: 5
                                Kirigami.Icon {
                                    source: IconNames.id
                                    width: 20
                                    height: 20
                                }
                                PlasmaComponents.Label {
                                    text: Shared.Strings.idLabel
                                    opacity: 0.7
                                    width: parent.width - 65
                                }
                                PlasmaComponents.ToolButton {
                                    icon.name: IconNames.copy
                                    display: QQC2.AbstractButton.IconOnly
                                    QQC2.ToolTip.text: Shared.Strings.copyFullContainerId
                                    QQC2.ToolTip.visible: hovered
                                    onClicked: clipboard.content = modelData.Id
                                }
                            }
                            PlasmaComponents.Label {
                                width: parent.width
                                text: ContainerData.shortId(modelData)
                                elide: Text.ElideRight
                            }
                        }
                        Column {
                            width: (parent.width - parent.spacing) / 2
                            spacing: 3
                            Row {
                                spacing: 5
                                Kirigami.Icon {
                                    source: IconNames.containerDetails
                                    width: 20
                                    height: 20
                                }
                                PlasmaComponents.Label {
                                    text: Shared.Strings.status
                                    opacity: 0.7
                                }
                            }
                            PlasmaComponents.Label {
                                width: parent.width
                                text: ContainerData.field(modelData.Status)
                                elide: Text.ElideRight
                            }
                        }
                    }
                    RowLayout {
                        width: parent.width
                        Kirigami.Icon {
                            source: IconNames.image
                            Layout.preferredWidth: 20
                            Layout.preferredHeight: 20
                        }
                        PlasmaComponents.Label {
                            text: Shared.Strings.image
                            opacity: 0.7
                            Layout.fillWidth: true
                        }
                        PlasmaComponents.ToolButton {
                            icon.name: IconNames.copy
                            display: QQC2.AbstractButton.IconOnly
                            QQC2.ToolTip.text: Shared.Strings.copyImageName
                            QQC2.ToolTip.visible: hovered
                            onClicked: clipboard.content = ContainerData.imageName(modelData)
                        }
                    }
                    PlasmaComponents.Label {
                        width: parent.width
                        text: ContainerData.imageName(modelData)
                        wrapMode: Text.WrapAnywhere
                    }
                }
            }

            Rectangle {
                visible: controller.detailTab === 0
                width: parent.width
                height: ioCard.implicitHeight + 20
                radius: 7
                color: Kirigami.Theme.alternateBackgroundColor
                Row {
                    id: ioCard
                    x: 10
                    y: 10
                    width: parent.width - 20
                    spacing: 18
                    Column {
                        width: (parent.width - parent.spacing) / 2
                        spacing: 3
                        Row {
                            spacing: 6
                            Kirigami.Icon {
                                source: IconNames.blockIo
                                width: 20
                                height: 20
                            }
                            PlasmaComponents.Label {
                                text: Shared.Strings.blockIo
                                opacity: 0.7
                            }
                        }
                        PlasmaComponents.Label {
                            text: ContainerData.ioValues(modelData, "block")
                            font.bold: true
                        }
                    }
                    Column {
                        width: (parent.width - parent.spacing) / 2
                        spacing: 3
                        Row {
                            spacing: 6
                            Kirigami.Icon {
                                source: IconNames.networkWired
                                width: 20
                                height: 20
                            }
                            PlasmaComponents.Label {
                                text: Shared.Strings.networkIO
                                opacity: 0.7
                            }
                        }
                        PlasmaComponents.Label {
                            text: ContainerData.ioValues(modelData, "network")
                            font.bold: true
                        }
                    }
                }
            }

            Rectangle {
                visible: controller.detailTab === 0
                width: parent.width
                height: networkCard.implicitHeight + 20
                radius: 7
                color: Kirigami.Theme.alternateBackgroundColor
                Column {
                    id: networkCard
                    x: 10
                    y: 10
                    width: parent.width - 20
                    spacing: 5
                    Row {
                        spacing: 6
                        Kirigami.Icon {
                            source: IconNames.network
                            width: 20
                            height: 20
                        }
                        PlasmaComponents.Label {
                            text: Shared.Strings.networkName
                            font.bold: true
                        }
                    }
                    Repeater {
                        model: ContainerData.networkNames(modelData)
                        delegate: PlasmaComponents.Label {
                            required property string modelData
                            width: networkCard.width
                            text: modelData
                            elide: Text.ElideRight
                        }
                    }
                    RowLayout {
                        width: parent.width
                        Kirigami.Icon {
                            source: IconNames.ports
                            Layout.preferredWidth: 20
                            Layout.preferredHeight: 20
                        }
                        PlasmaComponents.Label {
                            text: Shared.Strings.portsMapping
                            font.bold: true
                            Layout.fillWidth: true
                        }
                        PlasmaComponents.ToolButton {
                            icon.name: IconNames.copy
                            display: QQC2.AbstractButton.IconOnly
                            QQC2.ToolTip.text: Shared.Strings.copyPortMappings
                            QQC2.ToolTip.visible: hovered
                            onClicked: clipboard.content = ContainerData.portMappingsText(modelData)
                        }
                    }
                    Repeater {
                        model: ContainerData.portMappings(modelData)
                        delegate: Row {
                            required property var modelData
                            width: networkCard.width
                            height: 28
                            Item {
                                width: (parent.width - 22) / 2
                                height: parent.height
                                PlasmaComponents.Label {
                                    anchors.fill: parent
                                    text: modelData.source
                                    elide: Text.ElideRight
                                    font.family: "monospace"
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.NoButton
                                    QQC2.ToolTip.visible: containsMouse
                                    QQC2.ToolTip.text: modelData.source
                                }
                            }
                            PlasmaComponents.Label {
                                width: 22
                                height: parent.height
                                text: "→"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            Item {
                                width: (parent.width - 22) / 2
                                height: parent.height
                                PlasmaComponents.Label {
                                    anchors.fill: parent
                                    text: modelData.target
                                    elide: Text.ElideRight
                                    font.family: "monospace"
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.NoButton
                                    QQC2.ToolTip.visible: containsMouse
                                    QQC2.ToolTip.text: modelData.target
                                }
                            }
                        }
                    }
                    PlasmaComponents.Label {
                        visible: ContainerData.networkNames(modelData).length === 0 && ContainerData.portMappings(modelData).length === 0
                        text: "—"
                    }
                }
            }

            Rectangle {
                visible: controller.detailTab === 0
                width: parent.width
                height: volumeCard.implicitHeight + 20
                radius: 7
                color: Kirigami.Theme.alternateBackgroundColor
                Column {
                    id: volumeCard
                    x: 10
                    y: 10
                    width: parent.width - 20
                    spacing: 5
                    RowLayout {
                        width: parent.width
                        Kirigami.Icon {
                            source: IconNames.volume
                            Layout.preferredWidth: 20
                            Layout.preferredHeight: 20
                        }
                        PlasmaComponents.Label {
                            text: Shared.Strings.volumes
                            font.bold: true
                            Layout.fillWidth: true
                        }
                        PlasmaComponents.ToolButton {
                            icon.name: IconNames.copy
                            display: QQC2.AbstractButton.IconOnly
                            QQC2.ToolTip.text: Shared.Strings.copyVolumeMappings
                            QQC2.ToolTip.visible: hovered
                            onClicked: clipboard.content = ContainerData.volumeMappingsText(modelData)
                        }
                    }
                    Repeater {
                        model: ContainerData.volumeMappings(modelData)
                        delegate: Row {
                            required property var modelData
                            width: volumeCard.width
                            height: 28
                            Item {
                                width: (parent.width - 22) / 2
                                height: parent.height
                                PlasmaComponents.Label {
                                    anchors.fill: parent
                                    text: modelData.source
                                    elide: Text.ElideRight
                                    font.family: "monospace"
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.NoButton
                                    QQC2.ToolTip.visible: containsMouse
                                    QQC2.ToolTip.text: modelData.source
                                }
                            }
                            PlasmaComponents.Label {
                                width: 22
                                height: parent.height
                                text: "→"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            Item {
                                width: (parent.width - 22) / 2
                                height: parent.height
                                PlasmaComponents.Label {
                                    anchors.fill: parent
                                    text: modelData.target
                                    elide: Text.ElideRight
                                    font.family: "monospace"
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.NoButton
                                    QQC2.ToolTip.visible: containsMouse
                                    QQC2.ToolTip.text: modelData.target
                                }
                            }
                        }
                    }
                    PlasmaComponents.Label {
                        visible: ContainerData.volumeMappings(modelData).length === 0
                        text: "—"
                    }
                }
            }

            PlasmaComponents.Label {
                visible: controller.detailTab === 1
                width: parent.width
                text: modelData.logs || Shared.Strings.loadingLogs
                font.family: "monospace"
                wrapMode: Text.WrapAnywhere
                verticalAlignment: Text.AlignTop
            }
        }
    }
}
