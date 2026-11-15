import QtQuick
import "../shared" as Shared
import "../IconNames.js" as IconNames
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.plasma.components 3.0 as PlasmaComponents
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami
import "." as Components

ColumnLayout {
    id: root

    property var modelData
    property bool showMoreDetails: false

    Layout.fillWidth: true

    visible: modelData.online
    spacing: 10

    GridLayout {
        Layout.fillWidth: true
        columns: 3
        columnSpacing: 12
        rowSpacing: 4

        Components.ServerIconMetric {
            iconName: IconNames.cpuMetric
            fullText: Shared.Strings.valueLabel(Shared.Strings.cores, modelData.cores)
            metricText: modelData.cores
            tooltipEnabled: true
        }

        Components.ServerIconMetric {
            iconName: IconNames.architecture
            fullText: Shared.Strings.valueLabel(Shared.Strings.architecture, modelData.architecture)
            metricText: modelData.architecture
            tooltipEnabled: true
        }

        Components.ServerIconMetric {
            iconName: IconNames.server
            fullText: Shared.Strings.valueLabel(Shared.Strings.nodes, modelData.nodes)
            metricText: modelData.nodes
            tooltipEnabled: true
        }

        Components.ServerIconMetric {
            visible: Plasmoid.configuration.showServerImages
            iconName: IconNames.image
            fullText: Shared.Strings.valueLabel(Shared.Strings.images, modelData.images)
            metricText: modelData.images
            tooltipEnabled: true
        }

        Components.ServerIconMetric {
            visible: Plasmoid.configuration.showServerVolumes
            iconName: IconNames.volume
            fullText: Shared.Strings.valueLabel(Shared.Strings.volumes, modelData.volumes)
            metricText: modelData.volumes
            tooltipEnabled: true
        }

        Components.ServerIconMetric {
            iconName: IconNames.memory
            fullText: Shared.Strings.valueLabel(Shared.Strings.totalMemory, modelData.totalMemory)
            metricText: modelData.totalMemory
            tooltipEnabled: true
        }

        Components.ServerIconMetric {
            iconName: IconNames.container
            fullText: Shared.Strings.valueLabel(
                Shared.Strings.containersLabel,
                root.modelData.running + "/" + root.modelData.containers
            )
            metricText: root.modelData.running + "/" + root.modelData.containers
            tooltipEnabled: true
        }

        PlasmaComponents.ToolButton {
            text: "..."
            display: QQC2.AbstractButton.TextOnly
            QQC2.ToolTip.text: Shared.Strings.more
            QQC2.ToolTip.visible: hovered

            onClicked: root.showMoreDetails = !root.showMoreDetails
        }
    }

    Loader {
        Layout.fillWidth: true

        active: root.showMoreDetails
        visible: active

        sourceComponent: Component {
            GridLayout {
                Layout.fillWidth: true

                columns: 2
                columnSpacing: 12
                rowSpacing: 4

                Components.ServerMetric {
                    iconName: IconNames.operatingSystem
                    metricText: Shared.Strings.valueLabel(
                        Shared.Strings.operatingSystem,
                        root.modelData.operatingSystem
                    )
                }

                Components.ServerMetric {
                    iconName: IconNames.kernelVersion
                    metricText: Shared.Strings.valueLabel(
                        Shared.Strings.kernelVersion,
                        root.modelData.kernelVersion
                    )
                }

                Components.ServerMetric {
                    iconName: IconNames.driver
                    metricText: Shared.Strings.valueLabel(
                        Shared.Strings.driver,
                        root.modelData.driver
                    )
                }

                Components.ServerMetric {
                    iconName: IconNames.logDriver
                    metricText: Shared.Strings.valueLabel(
                        Shared.Strings.logDriver,
                        root.modelData.logDriver
                    )
                }

                Components.ServerMetric {
                    iconName: IconNames.dockerRootDir
                    metricText: Shared.Strings.valueLabel(
                        Shared.Strings.dockerRootDir,
                        root.modelData.dockerRootDir
                    )
                    tooltipEnabled: true
                }

                Components.ServerMetric {
                    iconName: IconNames.serverVersion
                    metricText: Shared.Strings.valueLabel(
                        Shared.Strings.serverVersion,
                        root.modelData.serverVersion
                    )
                }

                Components.ServerMetric {
                    iconName: IconNames.apiVersion
                    metricText: Shared.Strings.valueLabel(
                        Shared.Strings.apiVersion,
                        root.modelData.apiVersion
                    )
                }

                Components.ServerMetric {
                    iconName: IconNames.minApiVersion
                    metricText: Shared.Strings.valueLabel(
                        Shared.Strings.minApiVersion,
                        root.modelData.minApiVersion
                    )
                }
            }
        }
    }
}
