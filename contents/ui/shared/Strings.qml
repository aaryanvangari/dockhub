pragma Singleton

import QtQuick

// Shared translations for the plasmoid and its configuration pages.
// Apply placeholder values at the call site with QString.arg().
QtObject {
    id: strings
    readonly property string general: i18n("General")
    readonly property string servers: i18n("Servers")
    readonly property string backToServer: i18n("Back to server")
    readonly property string backToServers: i18n("Back to servers")
    readonly property string dockhub: i18n("Dockhub")
    readonly property string refresh: i18n("Refresh")
    readonly property string settings: i18n("Settings")
    readonly property string noEnabledServersConfiguredOpenSettingsToAddOne: i18n("No enabled servers configured. Open Settings to add one.")
    readonly property string name: i18n("Name")
    readonly property string forExampleProduction: i18n("For example, Production")
    readonly property string hostUrl: i18n("Host URL")
    readonly property string enabled: i18n("Enabled")
    readonly property string deleteServer: i18n("Delete server")
    readonly property string addServer: i18n("Add Server")
    readonly property string refreshDashboardEvery: i18n("Refresh dashboard every")
    readonly property string seconds: i18n(" seconds")
    readonly property string refreshUsageEvery: i18n("Refresh usage every")
    readonly property string server: i18n("Server")
    readonly property string serverOverviewColumns: i18n("Server overview columns")
    readonly property string offlineOrUnreachable: i18n("Offline or unreachable")
    readonly property string stop: i18n("Stop")
    readonly property string start: i18n("Start")
    readonly property string stopContainer: i18n("Stop container")
    readonly property string startContainer: i18n("Start container")
    readonly property string cpuLabel: i18n("CPU")
    readonly property string memory: i18n("Memory")
    readonly property string idLabel: i18n("ID")
    readonly property string copyShortId: i18n("Copy short ID")
    readonly property string status: i18n("Status")
    readonly property string information: i18n("Information")
    readonly property string logs: i18n("Logs")
    readonly property string copyContainerName: i18n("Copy container name")
    readonly property string memoryUsage: i18n("Memory Usage")
    readonly property string copyFullContainerId: i18n("Copy full container ID")
    readonly property string image: i18n("Image")
    readonly property string copyImageName: i18n("Copy image name")
    readonly property string blockIo: i18n("Block IO")
    readonly property string networkIO: i18n("Network IO")
    readonly property string networkName: i18n("Network Name")
    readonly property string portsMapping: i18n("Ports Mapping")
    readonly property string copyPortMappings: i18n("Copy port mappings")
    readonly property string volumes: i18n("Volumes")
    readonly property string copyVolumeMappings: i18n("Copy volume mappings")
    readonly property string loadingLogs: i18n("Loading logs…")
    readonly property string healthyUnhealthyContainers: i18n("Healthy / unhealthy containers")
    readonly property string action: i18n("Action")
    readonly property string couldNotReadSavedServerSettings: i18n("Could not read saved server settings")
    readonly property string runningLower: i18n("running")
    readonly property string runningUpper: i18n("Running")
    readonly property string container: i18n("container")
    readonly property string containersLower: i18n("containers")
    readonly property string containersLabel: i18n("Containers")
    readonly property string couldNotLoadVolumeDetails: i18n("Could not load volume details")
    readonly property string couldNotLoadVolumeContainers: i18n("Could not load volume containers")
    readonly property string couldNotLoadImageDetails: i18n("Could not load image details")
    readonly property string couldNotLoadImageHistory: i18n("Could not load image history")
    readonly property string couldNotLoadContainers: i18n("Could not load containers")
    readonly property string containerStarted: i18n("Container started")
    readonly property string containerStopped: i18n("Container stopped")
    readonly property string actionFailed: i18n("Action failed")
    readonly property string driver: i18n("Driver")
    readonly property string loadingVolumeDetails: i18n("Loading volume details…")
    readonly property string volumeInformation: i18n("Volume information")
    readonly property string copyVolumeId: i18n("Copy volume ID")
    readonly property string created: i18n("Created")
    readonly property string mountPath: i18n("Mount path")
    readonly property string containersUsingThisVolume: i18n("Containers using this volume")
    readonly property string loadingContainerMounts: i18n("Loading container mounts…")
    readonly property string noContainersAreUsingThisVolume: i18n("No containers are using this volume")
    readonly property string mountedAt: i18n("Mounted at")
    readonly property string readOnly: i18n("Read only")
    readonly property string no: i18n("No")
    readonly property string yes: i18n("Yes")
    readonly property string previous: i18n("Previous")
    readonly property string next: i18n("Next")
    readonly property string copyFullImageId: i18n("Copy full image ID")
    readonly property string loadingImageDetails: i18n("Loading image details…")
    readonly property string imageInformation: i18n("Image information")
    readonly property string fullId: i18n("Full ID")
    readonly property string size: i18n("Size")
    readonly property string build: i18n("Build")
    readonly property string command: i18n("Command")
    readonly property string entryPoint: i18n("Entry point")
    readonly property string noLabels: i18n("No labels")
    readonly property string noEnvironmentVariables: i18n("No environment variables")
    readonly property string loadingImageHistory: i18n("Loading image history…")
    readonly property string noImageHistory: i18n("No image history")
    readonly property string layer: i18n("Layer")
    readonly property string copyShortNetworkID: i18n("Copy short network ID")
    readonly property string networkInformation: i18n("Network information")
    readonly property string copyFullNetworkId: i18n("Copy full network ID")
    readonly property string scope: i18n("Scope")
    readonly property string internal: i18n("Internal")
    readonly property string attachable: i18n("Attachable")
    readonly property string ingress: i18n("Ingress")
    readonly property string ipam: i18n("IPAM")
    readonly property string ipv4: i18n("IPv4")
    readonly property string ipv6: i18n("IPv6")
    readonly property string mac: i18n("MAC")
    readonly property string copySubnet: i18n("Copy subnet")
    readonly property string copyGateway: i18n("Copy gateway")
    readonly property string copyIPRange: i18n("Copy IP range")
    readonly property string containersOnThisNetwork: i18n("Containers on this network")
    readonly property string noContainersAttached: i18n("No containers attached")
    readonly property string copyContainerNameIDAndNetworkAddresses: i18n("Copy container name, ID, and network addresses")
    readonly property string stacks: i18n("Stacks")
    readonly property string images: i18n("Images")
    readonly property string networks: i18n("Networks")
    readonly property string stopped: i18n("Stopped")
    readonly property string healthy: i18n("Healthy")
    readonly property string unhealthy: i18n("Unhealthy")
    readonly property string events24h: i18n("Events (24h)")
    readonly property string events: i18n("Events")
    readonly property string searchByNameImagePortOrIP: i18n("Search by name, ID, image, port or IP")
    readonly property string noMatchingContainers: i18n("No containers match your search")
    readonly property string copy: i18n("Copy")
    readonly property string columns: i18n("columns")
    readonly property string cores: i18n("Cores")
    readonly property string totalMemory: i18n("Total Memory")
    readonly property string nodes: i18n("Nodes")
    readonly property string operatingSystem: i18n("OS")
    readonly property string kernelVersion: i18n("Kernel")
    readonly property string architecture: i18n("Arch")
    readonly property string dockerRootDir: i18n("Root Dir")
    readonly property string dockerSocket: i18n("Socket")
    readonly property string serverVersion: i18n("Server")
    readonly property string apiVersion: i18n("API")
    readonly property string minApiVersion: i18n("Min API")
    readonly property string labels: i18n("Labels")
    readonly property string environment: i18n("Environment")
    readonly property string imageHistory: i18n("Image history")
    readonly property string subnet: i18n("Subnet")
    readonly property string gateway: i18n("Gateway")
    readonly property string range: i18n("Range")
    readonly property string couldNotLoad: i18n("Could not load")
    readonly property string loading: i18n("Loading")
    readonly property string found: i18n("found")
    readonly property string of: i18n("of")
    readonly property string page: i18n("Page")

    function valueLabel(label, value) {
        return label + ": " + String(value);
    }
    function copySection(title) {
        return copy + " " + title;
    }
    function countTitle(title, count) {
        return title + " (" + String(count) + ")";
    }
    function containerCount(count) {
        return String(count) + " " + (count === 1 ? container : containersLower);
    }
    function containerSummary(runningCount, totalCount) {
        return valueLabel(containersLabel, String(runningCount) + "/" + String(totalCount));
    }
    function pageText(current, total) {
        return page + " " + String(current) + " " + of + " " + String(total);
    }
    function resourceName(resource) {
        switch (String(resource).toLowerCase()) {
        case "stacks":
            return stacks;
        case "volumes":
            return volumes;
        case "images":
            return images;
        case "networks":
            return networks;
        case "events":
            return events;
        default:
            return String(resource);
        }
    }
    function loadingResource(resource) {
        return loading + " " + resourceName(resource).toLowerCase() + "…";
    }
    function emptyResource(resource) {
        return no + " " + resourceName(resource).toLowerCase() + " " + found;
    }
    function resourceError(resource) {
        return couldNotLoad + " " + resourceName(resource).toLowerCase();
    }
    function columnCount(count) {
        return String(count) + " " + columns;
    }
    function serverNumber(number) {
        return server + " " + String(number);
    }
    function historyEntry(sizeValue, layerValue) {
        return valueLabel(size, sizeValue) + "\n" + valueLabel(layer, layerValue);
    }
    function imageDescription(idValue, sizeValue) {
        return valueLabel(idLabel, idValue) + " · " + valueLabel(size, sizeValue);
    }
    function dotSeparated(first, second) {
        return String(first) + " · " + String(second);
    }
    function stackSummary(runningCount, totalCount) {
        return String(runningCount) + " " + runningLower + " · " + containerCount(totalCount);
    }
}
