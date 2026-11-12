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
    Layout.fillWidth: true
    visible: modelData.online
    spacing: 1

    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        ColumnLayout {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            Layout.preferredWidth: 1
            Layout.horizontalStretchFactor: 37
            spacing: 2
            Components.ServerMetric {
                iconName: IconNames.operatingSystem
                metricText: Shared.Strings.valueLabel(Shared.Strings.operatingSystem, modelData.operatingSystem)
                tooltipEnabled: true
            }
            Components.ServerMetric {
                iconName: IconNames.kernelVersion
                metricText: Shared.Strings.valueLabel(Shared.Strings.kernelVersion, modelData.kernelVersion)
                tooltipEnabled: true
            }
            Components.ServerMetric {
                iconName: IconNames.memory
                metricText: Shared.Strings.valueLabel(Shared.Strings.totalMemory, modelData.totalMemory)
                tooltipEnabled: true
            }
            Components.ServerMetric {
                iconName: IconNames.dockerRootDir
                metricText: Shared.Strings.valueLabel(Shared.Strings.dockerRootDir, modelData.dockerRootDir)
                tooltipEnabled: true
            }
            Components.ServerMetric {
                iconName: IconNames.driver
                metricText: Shared.Strings.valueLabel(Shared.Strings.driver, modelData.driver)
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            Layout.preferredWidth: 1
            Layout.horizontalStretchFactor: 30
            spacing: 2
            Components.ServerMetric {
                iconName: IconNames.serverVersion
                metricText: Shared.Strings.valueLabel(Shared.Strings.serverVersion, modelData.serverVersion)
            }
            Components.ServerMetric {
                iconName: IconNames.apiVersion
                metricText: Shared.Strings.valueLabel(Shared.Strings.apiVersion, modelData.apiVersion)
            }
            Components.ServerMetric {
                iconName: IconNames.minApiVersion
                metricText: Shared.Strings.valueLabel(Shared.Strings.minApiVersion, modelData.minApiVersion)
            }
            Components.ServerMetric {
                iconName: IconNames.cpuMetric
                metricText: Shared.Strings.valueLabel(Shared.Strings.cores, modelData.cores)
            }
            Components.ServerMetric {
                visible: Plasmoid.configuration.showServerImages
                iconName: IconNames.image
                metricText: Shared.Strings.valueLabel(Shared.Strings.images, modelData.images)
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            Layout.preferredWidth: 1
            Layout.horizontalStretchFactor: 33
            spacing: 2
            Components.ServerMetric {
                iconName: IconNames.server
                metricText: Shared.Strings.valueLabel(Shared.Strings.nodes, modelData.nodes)
            }
            Components.ServerMetric {
                iconName: IconNames.architecture
                metricText: Shared.Strings.valueLabel(Shared.Strings.architecture, modelData.architecture)
            }
            Components.ServerMetric {
                visible: Plasmoid.configuration.showServerVolumes
                iconName: IconNames.volume
                metricText: Shared.Strings.valueLabel(Shared.Strings.volumes, modelData.volumes)
            }
            Components.ContainerSummaryMetric {
                runningCount: modelData.running
                totalCount: modelData.containers
            }
            Components.ServerMetric {
                iconName: IconNames.logDriver
                metricText: Shared.Strings.valueLabel(Shared.Strings.logDriver, modelData.logDriver)
            }
        }
    }
}