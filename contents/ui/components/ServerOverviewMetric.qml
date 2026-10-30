import QtQuick
import "../shared" as Shared
import "../IconNames.js" as IconNames
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import "." as Components

Item {
    id: root

    property string metricKey
    property var serverData
    property bool showImages: false
    property bool showVolumes: false
    readonly property bool isVisible: (metricKey !== "images" || showImages) && (metricKey !== "volumes" || showVolumes)
    Layout.fillWidth: true
    Layout.minimumWidth: 0
    implicitHeight: isVisible ? 22 : 0
    visible: isVisible

    function metricIcon() {
        switch (metricKey) {
        case "os": return IconNames.operatingSystem;
        case "kernel": return IconNames.kernelVersion;
        case "cores": return IconNames.cpuMetric;
        case "totalMemory": return IconNames.memory;
        case "nodes": return IconNames.server;
        case "arch": return IconNames.architecture;
        case "images": return IconNames.image;
        case "volumes": return IconNames.volume;
        case "rootDir": return IconNames.dockerRootDir;
        case "socket": return IconNames.dockerSocket;
        case "server": return IconNames.serverVersion;
        case "api": return IconNames.apiVersion;
        case "minApi": return IconNames.minApiVersion;
        default: return "";
        }
    }

    function metricText() {
        let label = "";
        let value = "—";
        switch (metricKey) {
        case "os": label = Shared.Strings.operatingSystem; value = serverData.operatingSystem; break;
        case "kernel": label = Shared.Strings.kernelVersion; value = serverData.kernelVersion; break;
        case "cores": label = Shared.Strings.cores; value = serverData.cores; break;
        case "totalMemory": label = Shared.Strings.totalMemory; value = serverData.totalMemory; break;
        case "nodes": label = Shared.Strings.nodes; value = serverData.nodes; break;
        case "arch": label = Shared.Strings.architecture; value = serverData.architecture; break;
        case "images": label = Shared.Strings.images; value = serverData.images; break;
        case "volumes": label = Shared.Strings.volumes; value = serverData.volumes; break;
        case "rootDir": label = Shared.Strings.dockerRootDir; value = serverData.dockerRootDir; break;
        case "socket": label = Shared.Strings.dockerSocket; value = serverData.dockerSocket; break;
        case "server": label = Shared.Strings.serverVersion; value = serverData.serverVersion; break;
        case "api": label = Shared.Strings.apiVersion; value = serverData.apiVersion; break;
        case "minApi": label = Shared.Strings.minApiVersion; value = serverData.minApiVersion; break;
        }
        return Shared.Strings.valueLabel(label, value);
    }

    Components.ServerMetric {
        anchors.fill: parent
        visible: root.metricKey !== "containers" && root.isVisible
        iconName: root.metricIcon()
        metricText: root.metricText()
        tooltipEnabled: root.metricKey === "os" || root.metricKey === "kernel" || root.metricKey === "totalMemory" || root.metricKey === "rootDir" || root.metricKey === "socket"
    }
    Components.ContainerSummaryMetric {
        anchors.fill: parent
        visible: root.metricKey === "containers"
        runningCount: root.serverData ? root.serverData.running : 0
        totalCount: root.serverData ? root.serverData.containers : 0
    }
}
