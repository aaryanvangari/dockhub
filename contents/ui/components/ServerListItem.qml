import QtQuick
import "../shared" as Shared
import "../IconNames.js" as IconNames
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.plasma.components 3.0 as PlasmaComponents
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami
import "." as Components

QQC2.ItemDelegate {
    id: delegateRoot
    property var controller
    required property var modelData
    width: ListView.view.width
    padding: 0
    background: Rectangle {
        color: delegateRoot.hovered ? Qt.alpha(Kirigami.Theme.highlightColor, 0.12) : Kirigami.Theme.backgroundColor
        border.color: delegateRoot.hovered ? Kirigami.Theme.highlightColor : Qt.alpha(Kirigami.Theme.textColor, 0.2)
        border.width: 1
        radius: 8
    }
    onClicked: controller.openServer(modelData)

    contentItem: Item {
        implicitHeight: serverEntryContent.implicitHeight + 20
        ColumnLayout {
            id: serverEntryContent
            x: 10
            y: 10
            width: Math.max(0, parent.width - 20)
            spacing: 2

            RowLayout {
                Layout.fillWidth: true
                Kirigami.Icon {
                    source: modelData.online ? IconNames.serverConnected : IconNames.serverDisconnected
                    Layout.preferredWidth: 20
                    Layout.preferredHeight: 20
                }
                PlasmaComponents.Label {
                    text: modelData.name
                    font.bold: true
                    font.pixelSize: 16
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }
                Kirigami.Icon {
                    source: IconNames.next
                    Layout.preferredWidth: 16
                    Layout.preferredHeight: 16
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                visible: modelData.online
                spacing: 1

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    ColumnLayout {
                        visible: Number(Plasmoid.configuration.serverEntryColumns) === 3
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        Layout.preferredWidth: 1
                        Layout.horizontalStretchFactor: 4
                        spacing: 2
                        Components.ServerMetric {
                            iconName: IconNames.operatingSystem
                            metricText: Shared.Strings.valueLabel(Shared.Strings.operatingSystem, delegateRoot.modelData.operatingSystem)
                            tooltipEnabled: true
                        }
                        Components.ServerMetric {
                            iconName: IconNames.kernelVersion
                            metricText: Shared.Strings.valueLabel(Shared.Strings.kernelVersion, delegateRoot.modelData.kernelVersion)
                            tooltipEnabled: true
                        }
                        Components.ServerMetric {
                            iconName: IconNames.memory
                            metricText: Shared.Strings.valueLabel(Shared.Strings.totalMemory, delegateRoot.modelData.totalMemory)
                            tooltipEnabled: true
                        }
                        Components.ServerMetric {
                            iconName: IconNames.dockerRootDir
                            metricText: Shared.Strings.valueLabel(Shared.Strings.dockerRootDir, delegateRoot.modelData.dockerRootDir)
                            tooltipEnabled: true
                        }
                        Components.ServerMetric {
                            iconName: IconNames.dockerSocket
                            metricText: Shared.Strings.valueLabel(Shared.Strings.dockerSocket, delegateRoot.modelData.dockerSocket)
                            tooltipEnabled: true
                        }
                    }
                    ColumnLayout {
                        visible: Number(Plasmoid.configuration.serverEntryColumns) === 3
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        Layout.preferredWidth: 1
                        Layout.horizontalStretchFactor: 3
                        spacing: 2
                        Components.ServerMetric {
                            iconName: IconNames.serverVersion
                            metricText: Shared.Strings.valueLabel(Shared.Strings.serverVersion, delegateRoot.modelData.serverVersion)
                        }
                        Components.ServerMetric {
                            iconName: IconNames.apiVersion
                            metricText: Shared.Strings.valueLabel(Shared.Strings.apiVersion, delegateRoot.modelData.apiVersion)
                        }
                        Components.ServerMetric {
                            iconName: IconNames.minApiVersion
                            metricText: Shared.Strings.valueLabel(Shared.Strings.minApiVersion, delegateRoot.modelData.minApiVersion)
                        }
                        Components.ServerMetric {
                            iconName: IconNames.cpuMetric
                            metricText: Shared.Strings.valueLabel(Shared.Strings.cores, delegateRoot.modelData.cores)
                        }
                        Components.ServerMetric {
                            visible: Plasmoid.configuration.showServerImages
                            iconName: IconNames.image
                            metricText: Shared.Strings.valueLabel(Shared.Strings.images, delegateRoot.modelData.images)
                        }
                    }
                    ColumnLayout {
                        visible: Number(Plasmoid.configuration.serverEntryColumns) === 3
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        Layout.preferredWidth: 1
                        Layout.horizontalStretchFactor: 3
                        spacing: 2
                        Components.ServerMetric {
                            iconName: IconNames.server
                            metricText: Shared.Strings.valueLabel(Shared.Strings.nodes, delegateRoot.modelData.nodes)
                        }
                        Components.ServerMetric {
                            iconName: IconNames.architecture
                            metricText: Shared.Strings.valueLabel(Shared.Strings.architecture, delegateRoot.modelData.architecture)
                        }
                        Components.ServerMetric {
                            visible: Plasmoid.configuration.showServerVolumes
                            iconName: IconNames.volume
                            metricText: Shared.Strings.valueLabel(Shared.Strings.volumes, delegateRoot.modelData.volumes)
                        }
                        Components.ContainerSummaryMetric {
                            runningCount: delegateRoot.modelData.running
                            totalCount: delegateRoot.modelData.containers
                        }
                    }

                    ColumnLayout {
                        visible: Number(Plasmoid.configuration.serverEntryColumns) === 2
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        Layout.preferredWidth: 1
                        spacing: 2
                        Components.ServerMetric {
                            iconName: IconNames.operatingSystem
                            metricText: Shared.Strings.valueLabel(Shared.Strings.operatingSystem, delegateRoot.modelData.operatingSystem)
                            tooltipEnabled: true
                        }
                        Components.ServerMetric {
                            iconName: IconNames.kernelVersion
                            metricText: Shared.Strings.valueLabel(Shared.Strings.kernelVersion, delegateRoot.modelData.kernelVersion)
                            tooltipEnabled: true
                        }
                        Components.ServerMetric {
                            iconName: IconNames.dockerRootDir
                            metricText: Shared.Strings.valueLabel(Shared.Strings.dockerRootDir, delegateRoot.modelData.dockerRootDir)
                            tooltipEnabled: true
                        }
                        Components.ServerMetric {
                            iconName: IconNames.dockerSocket
                            metricText: Shared.Strings.valueLabel(Shared.Strings.dockerSocket, delegateRoot.modelData.dockerSocket)
                            tooltipEnabled: true
                        }
                        Components.ServerMetric {
                            iconName: IconNames.serverVersion
                            metricText: Shared.Strings.valueLabel(Shared.Strings.serverVersion, delegateRoot.modelData.serverVersion)
                        }
                        Components.ServerMetric {
                            iconName: IconNames.apiVersion
                            metricText: Shared.Strings.valueLabel(Shared.Strings.apiVersion, delegateRoot.modelData.apiVersion)
                        }
                        Components.ServerMetric {
                            iconName: IconNames.minApiVersion
                            metricText: Shared.Strings.valueLabel(Shared.Strings.minApiVersion, delegateRoot.modelData.minApiVersion)
                        }
                    }
                    ColumnLayout {
                        visible: Number(Plasmoid.configuration.serverEntryColumns) === 2
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        Layout.preferredWidth: 1
                        spacing: 2
                        Components.ServerMetric {
                            iconName: IconNames.cpuMetric
                            metricText: Shared.Strings.valueLabel(Shared.Strings.cores, delegateRoot.modelData.cores)
                        }
                        Components.ServerMetric {
                            iconName: IconNames.architecture
                            metricText: Shared.Strings.valueLabel(Shared.Strings.architecture, delegateRoot.modelData.architecture)
                        }
                        Components.ServerMetric {
                            iconName: IconNames.server
                            metricText: Shared.Strings.valueLabel(Shared.Strings.nodes, delegateRoot.modelData.nodes)
                        }
                        Components.ServerMetric {
                            iconName: IconNames.memory
                            metricText: Shared.Strings.valueLabel(Shared.Strings.totalMemory, delegateRoot.modelData.totalMemory)
                            tooltipEnabled: true
                        }
                        Components.ServerMetric {
                            visible: Plasmoid.configuration.showServerImages
                            iconName: IconNames.image
                            metricText: Shared.Strings.valueLabel(Shared.Strings.images, delegateRoot.modelData.images)
                        }
                        Components.ServerMetric {
                            visible: Plasmoid.configuration.showServerVolumes
                            iconName: IconNames.volume
                            metricText: Shared.Strings.valueLabel(Shared.Strings.volumes, delegateRoot.modelData.volumes)
                        }
                        Components.ContainerSummaryMetric {
                            runningCount: delegateRoot.modelData.running
                            totalCount: delegateRoot.modelData.containers
                        }
                    }
                }
            }

            PlasmaComponents.Label {
                visible: !modelData.online
                text: Shared.Strings.offlineOrUnreachable
                opacity: 0.75
                font.pixelSize: 12
            }
        }
    }
}
