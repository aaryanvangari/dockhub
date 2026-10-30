import QtQuick
import "../shared" as Shared
import "../IconNames.js" as IconNames
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.plasma.components 3.0 as PlasmaComponents
import org.kde.kirigami as Kirigami

Item {
    id: networkRow
    required property var modelData
    property var controller
    property var clipboard
    readonly property var details: modelData.inspect || modelData
    readonly property var attachedContainers: {
        const attached = details.Containers || {};
        return Object.keys(attached).map(function (id) {
            return Object.assign({
                Id: id
            }, attached[id]);
        });
    }
    readonly property var ipamConfigs: details.IPAM && details.IPAM.Config ? details.IPAM.Config : []
    readonly property bool expanded: controller.expandedNetworkId === modelData.Id
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
            implicitHeight: header.implicitHeight + 12

            RowLayout {
                id: header
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10
                Kirigami.Icon {
                    source: IconNames.network
                    Layout.preferredWidth: 20
                    Layout.preferredHeight: 20
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    spacing: 2
                    PlasmaComponents.Label {
                        Layout.fillWidth: true
                        text: modelData.Name || "—"
                        font.bold: true
                        elide: Text.ElideRight
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 5
                        PlasmaComponents.Label {
                            text: Shared.Strings.valueLabel(Shared.Strings.idLabel, String(modelData.Id || "").slice(0, 12) || "—")
                            opacity: 0.8
                            font.pixelSize: 14
                        }
                        PlasmaComponents.ToolButton {
                            icon.name: IconNames.copy
                            display: QQC2.AbstractButton.IconOnly
                            implicitWidth: 24
                            implicitHeight: 24
                            QQC2.ToolTip.text: Shared.Strings.copyShortNetworkID
                            QQC2.ToolTip.visible: hovered
                            onClicked: clipboard.content = String(modelData.Id || "").slice(0, 12)
                        }
                        PlasmaComponents.Label {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            text: Shared.Strings.valueLabel(Shared.Strings.driver, modelData.Driver || "—")
                            opacity: 0.8
                            font.pixelSize: 14
                            elide: Text.ElideRight
                        }
                        PlasmaComponents.Label {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            text: Shared.Strings.valueLabel(Shared.Strings.scope, modelData.Scope || "—")
                            opacity: 0.8
                            font.pixelSize: 14
                            elide: Text.ElideRight
                        }
                    }
                }
                PlasmaComponents.Label {
                    visible: details.Containers !== undefined && details.Containers !== null
                    text: Shared.Strings.containerCount(attachedContainers.length)
                    opacity: 0.8
                }
                Kirigami.Icon {
                    source: expanded ? IconNames.collapse : IconNames.expand
                    Layout.preferredWidth: 16
                    Layout.preferredHeight: 16
                }
            }
            MouseArea {
                anchors.fill: parent
                z: -1
                cursorShape: Qt.PointingHandCursor
                onClicked: controller.toggleNetworkExpanded(modelData)
            }
        }

        ColumnLayout {
            visible: expanded
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: networkInfo.implicitHeight + 20
                radius: 7
                color: Kirigami.Theme.alternateBackgroundColor
                ColumnLayout {
                    id: networkInfo
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true
                        Kirigami.Icon {
                            source: IconNames.network
                            Layout.preferredWidth: 18
                            Layout.preferredHeight: 18
                        }
                        PlasmaComponents.Label {
                            Layout.fillWidth: true
                            text: Shared.Strings.networkInformation
                            font.bold: true
                        }
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
                                text: String(details.Id || modelData.Id || "—").slice(0, 12)
                                font.bold: true
                                elide: Text.ElideMiddle
                            }
                            PlasmaComponents.ToolButton {
                                icon.name: IconNames.copy
                                display: QQC2.AbstractButton.IconOnly
                                QQC2.ToolTip.text: Shared.Strings.copyFullNetworkId
                                QQC2.ToolTip.visible: hovered
                                onClicked: clipboard.content = String(details.Id || modelData.Id || "")
                            }
                        }
                        PlasmaComponents.Label {
                            text: Shared.Strings.name
                            opacity: 0.7
                        }
                        PlasmaComponents.Label {
                            Layout.fillWidth: true
                            text: details.Name || "—"
                            elide: Text.ElideRight
                        }
                        PlasmaComponents.Label {
                            text: Shared.Strings.driver
                            opacity: 0.7
                        }
                        PlasmaComponents.Label {
                            Layout.fillWidth: true
                            text: details.Driver || "—"
                        }
                        PlasmaComponents.Label {
                            text: Shared.Strings.scope
                            opacity: 0.7
                        }
                        PlasmaComponents.Label {
                            Layout.fillWidth: true
                            text: details.Scope || "—"
                        }
                        PlasmaComponents.Label {
                            text: Shared.Strings.internal
                            opacity: 0.7
                        }
                        PlasmaComponents.Label {
                            Layout.fillWidth: true
                            text: details.Internal ? Shared.Strings.yes : Shared.Strings.no
                        }
                        PlasmaComponents.Label {
                            text: Shared.Strings.attachable
                            opacity: 0.7
                        }
                        PlasmaComponents.Label {
                            Layout.fillWidth: true
                            text: details.Attachable ? Shared.Strings.yes : Shared.Strings.no
                        }
                        PlasmaComponents.Label {
                            text: Shared.Strings.ingress
                            opacity: 0.7
                        }
                        PlasmaComponents.Label {
                            Layout.fillWidth: true
                            text: details.Ingress ? Shared.Strings.yes : Shared.Strings.no
                        }
                        PlasmaComponents.Label {
                            text: Shared.Strings.ipam
                            opacity: 0.7
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            PlasmaComponents.Label {
                                Layout.fillWidth: true
                                visible: ipamConfigs.length === 0
                                text: "—"
                            }
                            Repeater {
                                model: ipamConfigs
                                delegate: ColumnLayout {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    spacing: 2
                                    RowLayout {
                                        Layout.fillWidth: true
                                        PlasmaComponents.Label {
                                            Layout.fillWidth: true
                                            text: Shared.Strings.valueLabel(Shared.Strings.subnet, modelData.Subnet || "—")
                                            wrapMode: Text.Wrap
                                        }
                                        PlasmaComponents.ToolButton {
                                            icon.name: IconNames.copy
                                            display: QQC2.AbstractButton.IconOnly
                                            QQC2.ToolTip.text: Shared.Strings.copySubnet
                                            QQC2.ToolTip.visible: hovered
                                            enabled: Boolean(modelData.Subnet)
                                            onClicked: clipboard.content = String(modelData.Subnet || "")
                                        }
                                    }
                                    RowLayout {
                                        Layout.fillWidth: true
                                        PlasmaComponents.Label {
                                            Layout.fillWidth: true
                                            text: Shared.Strings.valueLabel(Shared.Strings.gateway, modelData.Gateway || "—")
                                            wrapMode: Text.Wrap
                                        }
                                        PlasmaComponents.ToolButton {
                                            icon.name: IconNames.copy
                                            display: QQC2.AbstractButton.IconOnly
                                            QQC2.ToolTip.text: Shared.Strings.copyGateway
                                            QQC2.ToolTip.visible: hovered
                                            enabled: Boolean(modelData.Gateway)
                                            onClicked: clipboard.content = String(modelData.Gateway || "")
                                        }
                                    }
                                    RowLayout {
                                        Layout.fillWidth: true
                                        PlasmaComponents.Label {
                                            Layout.fillWidth: true
                                            text: Shared.Strings.valueLabel(Shared.Strings.range, modelData.IPRange || "—")
                                            wrapMode: Text.Wrap
                                        }
                                        PlasmaComponents.ToolButton {
                                            icon.name: IconNames.copy
                                            display: QQC2.AbstractButton.IconOnly
                                            QQC2.ToolTip.text: Shared.Strings.copyIPRange
                                            QQC2.ToolTip.visible: hovered
                                            enabled: Boolean(modelData.IPRange)
                                            onClicked: clipboard.content = String(modelData.IPRange || "")
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: attachedContent.implicitHeight + 20
                radius: 7
                color: Kirigami.Theme.alternateBackgroundColor
                ColumnLayout {
                    id: attachedContent
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 6
                    RowLayout {
                        Layout.fillWidth: true
                        Kirigami.Icon {
                            source: IconNames.server
                            Layout.preferredWidth: 18
                            Layout.preferredHeight: 18
                        }
                        PlasmaComponents.Label {
                            Layout.fillWidth: true
                            text: Shared.Strings.containersOnThisNetwork
                            font.bold: true
                        }
                    }
                    PlasmaComponents.Label {
                        Layout.fillWidth: true
                        visible: attachedContainers.length === 0
                        text: Shared.Strings.noContainersAttached
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
                            RowLayout {
                                Layout.fillWidth: true
                                Kirigami.Icon {
                                    source: IconNames.container
                                    Layout.preferredWidth: 16
                                    Layout.preferredHeight: 16
                                }
                                PlasmaComponents.Label {
                                    Layout.fillWidth: true
                                    text: modelData.Name || String(modelData.Id).slice(0, 12)
                                    font.bold: true
                                    elide: Text.ElideRight
                                }
                                PlasmaComponents.ToolButton {
                                    icon.name: IconNames.copy
                                    display: QQC2.AbstractButton.IconOnly
                                    QQC2.ToolTip.text: Shared.Strings.copyContainerNameIDAndNetworkAddresses
                                    QQC2.ToolTip.visible: hovered
                                    onClicked: clipboard.content = [Shared.Strings.valueLabel(Shared.Strings.name, modelData.Name || "—"), Shared.Strings.valueLabel(Shared.Strings.idLabel, modelData.Id || "—"), Shared.Strings.valueLabel("IPv4", modelData.IPv4Address || "—"), Shared.Strings.valueLabel("IPv6", modelData.IPv6Address || "—"), Shared.Strings.valueLabel("MAC", modelData.MacAddress || "—")].join("\n")
                                }
                            }
                            GridLayout {
                                Layout.fillWidth: true
                                columns: 2
                                columnSpacing: 12
                                rowSpacing: 6
                                RowLayout {
                                    Layout.fillWidth: true
                                    Kirigami.Icon {
                                        source: IconNames.id
                                        Layout.preferredWidth: 16
                                        Layout.preferredHeight: 16
                                    }
                                    PlasmaComponents.Label {
                                        Layout.fillWidth: true
                                        text: Shared.Strings.valueLabel(Shared.Strings.idLabel, String(modelData.Id || "").slice(0, 12) || "—")
                                        elide: Text.ElideRight
                                    }
                                    PlasmaComponents.ToolButton {
                                        icon.name: IconNames.copy
                                        display: QQC2.AbstractButton.IconOnly
                                        QQC2.ToolTip.text: Shared.Strings.copyFullContainerId
                                        QQC2.ToolTip.visible: hovered
                                        onClicked: clipboard.content = String(modelData.Id || "")
                                    }
                                }
                                RowLayout {
                                    Layout.fillWidth: true
                                    Kirigami.Icon {
                                        source: IconNames.networkWired
                                        Layout.preferredWidth: 16
                                        Layout.preferredHeight: 16
                                    }
                                    PlasmaComponents.Label {
                                        Layout.fillWidth: true
                                        text: Shared.Strings.valueLabel("MAC", modelData.MacAddress || "—")
                                        elide: Text.ElideRight
                                    }
                                }
                                RowLayout {
                                    Layout.fillWidth: true
                                    Kirigami.Icon {
                                        source: IconNames.network
                                        Layout.preferredWidth: 16
                                        Layout.preferredHeight: 16
                                    }
                                    PlasmaComponents.Label {
                                        Layout.fillWidth: true
                                        text: Shared.Strings.valueLabel("IPv4", modelData.IPv4Address || "—")
                                        elide: Text.ElideRight
                                    }
                                }
                                RowLayout {
                                    Layout.fillWidth: true
                                    Kirigami.Icon {
                                        source: IconNames.network
                                        Layout.preferredWidth: 16
                                        Layout.preferredHeight: 16
                                    }
                                    PlasmaComponents.Label {
                                        Layout.fillWidth: true
                                        text: Shared.Strings.valueLabel("IPv6", modelData.IPv6Address || "—")
                                        elide: Text.ElideRight
                                    }
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
