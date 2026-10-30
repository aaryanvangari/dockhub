pragma ComponentBehavior: Bound

import QtQuick
import "../shared" as Shared
import "../DockerApi.js" as DockerApi
import "ContainerData.js" as ContainerData

Item {
    id: page
    width: 0
    height: 0
    property var configuration

    property var servers: []
    property var selectedServer: null
    property string selectedResource: ""
    property var resourceItems: []
    property var resourceCache: ({})
    property var resourceRequests: ({})
    property var pendingResourceLoad: null
    property var pendingStatsQueue: []
    property var statsServer: null
    property var activeStatsRequests: []
    readonly property int maxConcurrentStatsRequests: 5
    property bool resourceLoading: false
    property string resourceError: ""
    property int resourcePage: 0
    property int resourcePageSize: 10
    property var containers: []
    property string containerSearchQuery: ""
    readonly property var filteredContainers: page.filterContainers(page.containers, page.containerSearchQuery)
    property var serverSummary: ({
            stacks: 0,
            containers: 0,
            images: 0,
            volumes: 0,
            networks: 0,
            events: 0,
            running: 0,
            stopped: 0,
            healthy: 0,
            unhealthy: 0
        })
    property string errorText: ""
    property string noticeText: ""
    property int detailTab: 0
    property string expandedId: ""
    property string expandedNetworkId: ""
    property string expandedVolumeName: ""
    property string expandedImageId: ""
    property string expandedStackName: ""

    function loadServers() {
        try {
            const configured = JSON.parse(page.configuration.servers || "[]");
            page.servers = configured.filter(function (s) {
                return s.enabled && s.name && s.host;
            }).map(function (s) {
                return {
                    name: s.name,
                    url: s.host,
                    apiPrefix: "",
                    online: false,
                    running: 0,
                    containers: 0,
                    images: "—",
                    volumes: "—",
                    nodes: "—",
                    cores: "—",
                    totalMemory: "—",
                    operatingSystem: "—",
                    kernelVersion: "—",
                    architecture: "—",
                    dockerRootDir: "—",
                    dockerSocket: "—",
                    serverVersion: "—",
                    apiVersion: "—",
                    minApiVersion: "—"
                };
            });
            page.refreshDashboard();
        } catch (e) {
            page.servers = [];
            page.errorText = Shared.Strings.couldNotReadSavedServerSettings;
        }
    }
    function updateDashboardServer(index, url, values) {
        const copy = page.servers.slice();
        if (!copy[index] || copy[index].url !== url)
            return;
        copy[index] = Object.assign({}, copy[index], values);
        page.servers = copy;
    }
    function mergeResourceItems(resource, incomingItems, previousItems) {
        if (!Array.isArray(previousItems) || previousItems.length === 0)
            return incomingItems;
        const previousById = ({});
        for (let i = 0; i < previousItems.length; ++i) {
            const item = previousItems[i] || {};
            const id = resource === "Volumes" ? (item.Name || item.name) : (item.Id || item.ID);
            if (id)
                previousById[String(id)] = item;
        }
        return incomingItems.map(function (item) {
            const id = resource === "Volumes" ? (item.Name || item.name) : (item.Id || item.ID);
            const previous = id ? previousById[String(id)] : null;
            return previous ? Object.assign({}, previous, item) : item;
        });
    }
    function requestResourceData(server, resource, callback, forceRefresh) {
        const key = server.url + "|" + resource;
        const cached = page.resourceCache[key];
        if (!forceRefresh && cached) {
            callback({
                success: true,
                data: cached.data
            });
            return;
        }
        const existing = page.resourceRequests[key];
        if (existing) {
            existing.callbacks.push(callback);
            return;
        }
        const requests = Object.assign({}, page.resourceRequests);
        requests[key] = {
            callbacks: [callback]
        };
        page.resourceRequests = requests;

        const finish = function (result) {
            let items = [];
            if (result.success) {
                if (resource === "Images")
                    items = result.data || [];
                else if (resource === "Volumes")
                    items = result.data && result.data.Volumes || [];
                else if (resource === "Networks")
                    items = result.data || [];
                else if (resource === "Events")
                    items = page.parseEvents(result.data);

                const cachedResource = page.resourceCache[key];
                const previousItems = page.selectedServer && page.selectedServer.url === server.url && page.selectedResource === resource ? page.resourceItems : (cachedResource ? cachedResource.data : []);
                items = page.mergeResourceItems(resource, items, previousItems);

                const cache = Object.assign({}, page.resourceCache);
                cache[key] = {
                    data: items,
                    updatedAt: Date.now()
                };
                page.resourceCache = cache;
                if (page.selectedServer && page.selectedServer.url === server.url && page.selectedResource === resource) {
                    page.resourceItems = items;
                    page.resourceLoading = false;
                    page.resourceError = "";
                }
            }
            const pending = page.resourceRequests[key];
            const callbacks = pending ? pending.callbacks.slice() : [callback];
            const remaining = Object.assign({}, page.resourceRequests);
            delete remaining[key];
            page.resourceRequests = remaining;
            const normalized = {
                success: result.success,
                data: items,
                error: result.error
            };
            for (let i = 0; i < callbacks.length; ++i)
                callbacks[i](normalized);
        };

        if (resource === "Images")
            DockerApi.images(server, finish);
        else if (resource === "Volumes")
            DockerApi.volumes(server, finish);
        else if (resource === "Networks")
            DockerApi.networks(server, finish);
        else if (resource === "Events") {
            const now = Math.floor(Date.now() / 1000);
            DockerApi.events(server, now - 86400, now + 1, finish);
        } else
            finish({
                success: false,
                error: Shared.Strings.resourceError(resource)
            });
    }
    function refreshDashboard() {
        for (let i = 0; i < servers.length; ++i) {
            const server = servers[i];
            const serverIndex = i;
            DockerApi.info(server, function (result) {
                if (result.success && result.data) {
                    const info = result.data;
                    page.updateDashboardServer(serverIndex, server.url, {
                        online: true,
                        containers: info.Containers !== undefined ? Number(info.Containers) : 0,
                        running: info.ContainersRunning !== undefined ? Number(info.ContainersRunning) : 0,
                        images: info.Images !== undefined ? String(info.Images) : "—",
                        nodes: info.Swarm && info.Swarm.Nodes !== undefined ? String(info.Swarm.Nodes) : "0",
                        cores: info.NCPU !== undefined ? String(info.NCPU) : "—",
                        totalMemory: info.MemTotal ? ContainerData.formatBytes(info.MemTotal) : "—",
                        operatingSystem: info.OperatingSystem || "—",
                        kernelVersion: info.KernelVersion || "—",
                        architecture: info.Architecture || "—",
                        dockerRootDir: info.DockerRootDir || "—",
                        dockerSocket: info.Containerd && info.Containerd.Address ? info.Containerd.Address : "—",
                        serverVersion: info.ServerVersion || "—"
                    });
                } else {
                    page.updateDashboardServer(serverIndex, server.url, {
                        online: false
                    });
                }
            });
            DockerApi.version(server, function (result) {
                if (!result.success || !result.data)
                    return;
                page.updateDashboardServer(serverIndex, server.url, {
                    apiVersion: result.data.ApiVersion || "—",
                    minApiVersion: result.data.MinAPIVersion || "—"
                });
            });
            if (page.configuration.showServerImages) {
                DockerApi.images(server, function (result) {
                    if (result.success && Array.isArray(result.data))
                        page.updateDashboardServer(serverIndex, server.url, {
                            images: String(result.data.length)
                        });
                });
            } else {
                page.updateDashboardServer(serverIndex, server.url, { images: "—" });
            }
            if (page.configuration.showServerVolumes) {
                DockerApi.volumes(server, function (result) {
                    const volumes = result.success && result.data && Array.isArray(result.data.Volumes) ? result.data.Volumes : [];
                    if (result.success)
                        page.updateDashboardServer(serverIndex, server.url, {
                            volumes: String(volumes.length)
                        });
                });
            } else {
                page.updateDashboardServer(serverIndex, server.url, { volumes: "—" });
            }
        }
    }
    function openServer(server) {
        selectedServer = server;
        selectedResource = "";
        containerSearchQuery = "";
        errorText = "";
        noticeText = "";
        expandedId = "";
        serverSummary = ({
                stacks: 0,
                containers: 0,
                images: 0,
                volumes: 0,
                networks: 0,
                events: 0,
                running: 0,
                stopped: 0,
                healthy: 0,
                unhealthy: 0
            });
        refreshContainers();
    }
    function openResource(resource, forceRefresh) {
        if (!selectedServer)
            return;
        const server = selectedServer;
        const cacheKey = server.url + "|" + resource;
        const cached = page.resourceCache[cacheKey];
        const refreshInterval = Math.max(1, Number(page.configuration.updateInterval || 30)) * 1000;
        const cacheIsFresh = cached && Date.now() - Number(cached.updatedAt || 0) < refreshInterval;
        selectedResource = resource;
        resourcePage = 0;
        expandedNetworkId = "";
        expandedVolumeName = "";
        expandedImageId = "";
        expandedStackName = "";
        resourceItems = cached ? cached.data : [];
        resourceError = "";
        resourceLoading = !cached;
        const applyResult = function (result) {
            if (!page.selectedServer || page.selectedServer.url !== server.url || page.selectedResource !== resource)
                return;
            page.resourceLoading = false;
            if (!result.success) {
                page.resourceError = result.error || Shared.Strings.resourceError(resource);
                return;
            }
            page.resourceItems = result.data || [];
        };
        if (resource === "Stacks") {
            page.resourceItems = page.buildStackItems(page.containers);
            page.resourceLoading = false;
        } else if (forceRefresh || !cacheIsFresh) {
            page.pendingResourceLoad = {
                server: server,
                resource: resource,
                callback: applyResult,
                force: !!forceRefresh
            };
            resourceRequestStartTimer.restart();
        }
    }
    function refreshCurrentResource() {
        if (!page.selectedServer || page.selectedResource === "")
            return;
        if (page.selectedResource === "Stacks") {
            page.refreshContainers(false, false, false);
            return;
        }
        const server = page.selectedServer;
        const resource = page.selectedResource;
        page.requestResourceData(server, resource, function (result) {
            if (!page.selectedServer || page.selectedServer.url !== server.url || page.selectedResource !== resource)
                return;
            if (!result.success) {
                page.resourceError = result.error || Shared.Strings.resourceError(resource);
                return;
            }
            page.resourceError = "";
            page.resourceItems = result.data || [];
        }, true);
    }
    function parseEvents(data) {
        let events = [];
        if (Array.isArray(data))
            events = data;
        else if (typeof data === "string") {
            const lines = data.split(/\r?\n/);
            for (let i = 0; i < lines.length; ++i) {
                if (!lines[i].trim())
                    continue;
                try {
                    events.push(JSON.parse(lines[i]));
                } catch (e) {}
            }
        } else if (data && typeof data === "object")
            events = [data];

        return events.sort(function (left, right) {
            const leftTime = Number(left.time || left.Time || 0);
            const rightTime = Number(right.time || right.Time || 0);
            return rightTime - leftTime;
        });
    }
    function buildStackItems(containerList) {
        const stacks = ({});
        for (let i = 0; i < containerList.length; ++i) {
            const container = containerList[i];
            const labels = container.Labels || {};
            const name = labels["com.docker.compose.project"] || labels["com.docker.stack.namespace"];
            if (!name)
                continue;
            if (!stacks[name])
                stacks[name] = {
                    name: name,
                    containers: 0,
                    running: 0,
                    containerItems: []
                };
            ++stacks[name].containers;
            stacks[name].containerItems.push(container);
            if (container.State === "running")
                ++stacks[name].running;
        }
        return Object.keys(stacks).sort().map(function (name) {
            return stacks[name];
        });
    }
    function setContainers(containerList) {
        page.containers = containerList;
        if (page.selectedResource === "Stacks")
            page.resourceItems = page.buildStackItems(containerList);
    }
    function requestContainerSearch() {
        if (page.selectedResource === "" && page.containerSearchQuery.trim() !== "")
            searchMetadataTimer.restart();
    }
    function filterContainers(containerList, searchText) {
        const query = String(searchText || "").trim().toLowerCase();
        if (query === "")
            return containerList;
        return containerList.filter(function (container) {
            const values = [ContainerData.containerName(container), container.Id || container.ID || "", container.Image || ""];
            const inspect = container.inspect || {};
            const config = inspect.Config || {};
            values.push(config.Image || "", inspect.ContainerConfig && inspect.ContainerConfig.Image || "");

            const ports = container.Ports || [];
            for (let i = 0; i < ports.length; ++i)
                values.push(ports[i].IP || "", ports[i].PublicPort || "", ports[i].PrivatePort || "", ports[i].Type || "");

            const networkSettings = inspect.NetworkSettings || container.NetworkSettings || {};
            values.push(networkSettings.IPAddress || "", networkSettings.GlobalIPv6Address || "");
            const networks = networkSettings.Networks || {};
            const names = Object.keys(networks);
            for (let i = 0; i < names.length; ++i) {
                const network = networks[names[i]] || {};
                values.push(network.IPAddress || "", network.GlobalIPv6Address || "");
            }
            const portBindings = networkSettings.Ports || {};
            const portNames = Object.keys(portBindings);
            for (let i = 0; i < portNames.length; ++i) {
                values.push(portNames[i]);
                const bindings = portBindings[portNames[i]] || [];
                for (let j = 0; j < bindings.length; ++j)
                    values.push(bindings[j].HostIp || "", bindings[j].HostPort || "");
            }
            return values.join(" ").toLowerCase().indexOf(query) >= 0;
        });
    }
    function loadContainerSearchMetadata() {
        if (!page.selectedServer || page.selectedResource !== "" || page.containerSearchQuery.trim() === "")
            return;
        const server = page.selectedServer;
        const pendingIds = [];
        const updated = page.containers.slice();
        for (let i = 0; i < updated.length; ++i) {
            const container = updated[i];
            if (container.inspect || container.inspectLoading)
                continue;
            updated[i] = Object.assign({}, container, {
                inspectLoading: true
            });
            pendingIds.push(container.Id);
        }
        if (pendingIds.length === 0)
            return;
        page.setContainers(updated);
        let nextIndex = 0;
        let activeRequests = 0;
        const startNext = function () {
            while (activeRequests < 4 && nextIndex < pendingIds.length) {
                const id = pendingIds[nextIndex++];
                ++activeRequests;
                DockerApi.inspectContainer(server, id, function (result) {
                    if (!page.selectedServer || page.selectedServer.url !== server.url)
                        return;
                    const current = page.containers.slice();
                    for (let j = 0; j < current.length; ++j) {
                        if (current[j].Id === id) {
                            current[j] = Object.assign({}, current[j], {
                                inspect: result.success ? result.data : null,
                                inspectLoading: false
                            });
                            page.setContainers(current);
                            break;
                        }
                    }
                    --activeRequests;
                    startNext();
                });
            }
        };
        startNext();
    }
    function toggleStackExpanded(stack) {
        page.expandedStackName = page.expandedStackName === stack.name ? "" : stack.name;
    }
    function resourceName(item) {
        if (selectedResource === "Stacks" || selectedResource === "Volumes")
            return String(item.name || item.Name || "—");
        if (selectedResource === "Images") {
            const tags = item.RepoTags || [];
            return tags.length && tags[0] !== "<none>:<none>" ? tags[0] : String(item.Id || "—").slice(0, 19);
        }
        return String(item.Name || "—");
    }
    function resourceDescription(item) {
        if (selectedResource === "Stacks")
            return Shared.Strings.stackSummary(item.running, item.containers);
        if (selectedResource === "Images")
            return Shared.Strings.imageDescription(String(item.Id || "").slice(7, 19), ContainerData.formatBytes(item.Size));
        if (selectedResource === "Volumes")
            return Shared.Strings.dotSeparated(item.Driver || "—", item.Mountpoint || "—");
        if (selectedResource === "Networks") {
            const subnets = item.IPAM && item.IPAM.Config ? item.IPAM.Config.map(function (config) {
                return config.Subnet;
            }).filter(Boolean).join(", ") : "";
            return [item.Driver, item.Scope, subnets].filter(Boolean).join(" · ") || "—";
        }
        return "";
    }
    function toggleNetworkExpanded(network) {
        if (page.expandedNetworkId === network.Id) {
            page.expandedNetworkId = "";
            return;
        }
        page.expandedNetworkId = network.Id;
        if (network.inspect)
            return;
        const server = page.selectedServer;
        DockerApi.inspectNetwork(server, network.Id, function (result) {
            if (!result.success || !page.selectedServer || page.selectedServer.url !== server.url || page.expandedNetworkId !== network.Id || page.selectedResource !== "Networks")
                return;
            const updated = page.resourceItems.slice();
            for (let i = 0; i < updated.length; ++i) {
                if (updated[i].Id === network.Id) {
                    updated[i] = Object.assign({}, updated[i], {
                        inspect: result.data
                    });
                    break;
                }
            }
            page.resourceItems = updated;
        });
    }
    function toggleVolumeExpanded(volume) {
        const name = volume.Name || volume.name;
        if (page.expandedVolumeName === name) {
            page.expandedVolumeName = "";
            return;
        }
        page.expandedVolumeName = name;
        if (volume.inspect && !volume.attachedLoading)
            return;

        const server = page.selectedServer;
        page.updateResourceVolume(name, {
            inspectLoading: true,
            inspectError: "",
            attachedLoading: true,
            attachedError: "",
            attachedContainers: []
        });
        DockerApi.inspectVolume(server, name, function (result) {
            if (!page.selectedServer || page.selectedServer.url !== server.url || page.selectedResource !== "Volumes")
                return;
            page.updateResourceVolume(name, {
                inspectLoading: false,
                inspect: result.success ? result.data : null,
                inspectError: result.success ? "" : (result.error || Shared.Strings.couldNotLoadVolumeDetails)
            });
        });
        DockerApi.containers(server, true, function (result) {
            if (!page.selectedServer || page.selectedServer.url !== server.url || page.selectedResource !== "Volumes")
                return;
            if (!result.success) {
                page.updateResourceVolume(name, {
                    attachedLoading: false,
                    attachedError: result.error || Shared.Strings.couldNotLoadVolumeContainers
                });
                return;
            }
            const containers = result.data || [];
            if (containers.length === 0) {
                page.updateResourceVolume(name, {
                    attachedLoading: false,
                    attachedContainers: []
                });
                return;
            }
            let pending = containers.length;
            const attached = [];
            const finishContainer = function (container, inspect) {
                const mounts = inspect && inspect.Mounts || [];
                for (let j = 0; j < mounts.length; ++j) {
                    const mount = mounts[j];
                    if (mount.Type !== "volume" || (mount.Name !== name && mount.Source !== (volume.Mountpoint || "")))
                        continue;
                    attached.push({
                        Id: container.Id,
                        Name: inspect.Name ? String(inspect.Name).replace(/^\/+/, "") : ((container.Names || []).length ? String(container.Names[0]).replace(/^\/+/, "") : String(container.Id || "").slice(0, 12)),
                        Destination: mount.Destination || "—",
                        RW: mount.RW !== false
                    });
                    break;
                }
                --pending;
                if (pending === 0)
                    page.updateResourceVolume(name, {
                        attachedLoading: false,
                        attachedContainers: attached
                    });
            };
            for (let i = 0; i < containers.length; ++i) {
                const container = containers[i];
                DockerApi.inspectContainer(server, container.Id, function (inspectResult) {
                    finishContainer(container, inspectResult.success ? inspectResult.data : null);
                });
            }
        });
    }
    function updateResourceVolume(name, values) {
        const updated = page.resourceItems.slice();
        for (let i = 0; i < updated.length; ++i) {
            if ((updated[i].Name || updated[i].name) === name) {
                updated[i] = Object.assign({}, updated[i], values);
                page.resourceItems = updated;
                return;
            }
        }
    }
    function toggleImageExpanded(image) {
        if (page.expandedImageId === image.Id) {
            page.expandedImageId = "";
            return;
        }
        page.expandedImageId = image.Id;
        if (image.inspect || image.inspectLoading)
            return;
        const server = page.selectedServer;
        page.updateResourceImage(image.Id, {
            inspectLoading: true,
            inspectError: "",
            historyLoading: true,
            historyError: ""
        });
        DockerApi.inspectImage(server, image.Id, function (result) {
            if (!page.selectedServer || page.selectedServer.url !== server.url || page.selectedResource !== "Images")
                return;
            page.updateResourceImage(image.Id, {
                inspectLoading: false,
                inspect: result.success ? result.data : null,
                inspectError: result.success ? "" : (result.error || Shared.Strings.couldNotLoadImageDetails)
            });
        });
        DockerApi.imageHistory(server, image.Id, function (result) {
            if (!page.selectedServer || page.selectedServer.url !== server.url || page.selectedResource !== "Images")
                return;
            page.updateResourceImage(image.Id, {
                historyLoading: false,
                history: result.success && Array.isArray(result.data) ? result.data : [],
                historyError: result.success ? "" : (result.error || Shared.Strings.couldNotLoadImageHistory)
            });
        });
    }
    function updateResourceImage(id, values) {
        const updated = page.resourceItems.slice();
        for (let i = 0; i < updated.length; ++i) {
            if (updated[i].Id === id) {
                updated[i] = Object.assign({}, updated[i], values);
                page.resourceItems = updated;
                return;
            }
        }
    }
    function refreshServerSummary(server, containerList, forceResourceRefresh) {
        const summary = {
            stacks: 0,
            containers: containerList.length,
            images: 0,
            volumes: 0,
            networks: 0,
            events: 0,
            running: 0,
            stopped: 0,
            healthy: 0,
            unhealthy: 0
        };
        const stacks = ({});
        for (let i = 0; i < containerList.length; ++i) {
            const c = containerList[i];
            const labels = c.Labels || {};
            const project = labels["com.docker.compose.project"] || labels["com.docker.stack.namespace"];
            if (project)
                stacks[project] = true;
            if (c.State === "running")
                ++summary.running;
            else
                ++summary.stopped;
            const status = String(c.Status || "").toLowerCase();
            if (status.indexOf("(unhealthy)") >= 0)
                ++summary.unhealthy;
            else if (status.indexOf("(healthy)") >= 0)
                ++summary.healthy;
        }
        summary.stacks = Object.keys(stacks).length;
        page.serverSummary = summary;
        page.requestResourceData(server, "Images", function (result) {
            if (result.success && page.selectedServer && page.selectedServer.url === server.url)
                page.serverSummary = Object.assign({}, page.serverSummary, {
                    images: result.data.length
                });
        }, !!forceResourceRefresh);
        page.requestResourceData(server, "Volumes", function (result) {
            if (result.success && page.selectedServer && page.selectedServer.url === server.url)
                page.serverSummary = Object.assign({}, page.serverSummary, {
                    volumes: result.data.length
                });
        }, !!forceResourceRefresh);
        page.requestResourceData(server, "Networks", function (result) {
            if (result.success && page.selectedServer && page.selectedServer.url === server.url)
                page.serverSummary = Object.assign({}, page.serverSummary, {
                    networks: result.data.length
                });
        }, !!forceResourceRefresh);
        page.requestResourceData(server, "Events", function (result) {
            if (!result.success || !page.selectedServer || page.selectedServer.url !== server.url)
                return;
            page.serverSummary = Object.assign({}, page.serverSummary, {
                events: result.data.length
            });
        }, !!forceResourceRefresh);
    }
    function refreshContainers(forceResourceRefresh, refreshStats, refreshSummary) {
        if (!selectedServer)
            return;
        const shouldRefreshStats = refreshStats !== false;
        const shouldRefreshSummary = refreshSummary !== false;
        const previouslyShown = page.containers;
        DockerApi.containers(selectedServer, true, function (result) {
            if (!page.selectedServer || page.selectedServer.url !== selectedServer.url)
                return;
            if (result.success) {
                page.errorText = "";
                page.setContainers(result.data.map(function (c) {
                    let previous = null;
                    for (let j = 0; j < previouslyShown.length; ++j)
                        if (previouslyShown[j].Id === c.Id) {
                            previous = previouslyShown[j];
                            break;
                        }
                    return Object.assign({}, c, {
                        stats: previous ? previous.stats : null,
                        inspect: previous ? previous.inspect : null,
                        inspectLoading: previous ? previous.inspectLoading : false,
                        logs: previous ? previous.logs : ""
                    });
                }));
                if (page.containerSearchQuery.trim() !== "")
                    page.requestContainerSearch();
                if (shouldRefreshSummary)
                    page.refreshServerSummary(selectedServer, result.data, !!forceResourceRefresh);
                if (!shouldRefreshStats || page.selectedResource !== "")
                    return;
                page.queueContainerStats(selectedServer, page.containers);
            } else
                page.errorText = result.error || Shared.Strings.couldNotLoadContainers;
        });
    }
    function queueContainerStats(server, containerList) {
        if (!server || page.selectedResource !== "")
            return;
        const sameServer = page.statsServer && page.statsServer.url === server.url;
        if (sameServer && page.pendingStatsQueue.length > 0)
            return;
        page.statsServer = server;
        page.pendingStatsQueue = containerList.filter(function (container) {
            if (container.State !== "running")
                return false;
            return !page.activeStatsRequests.some(function (request) {
                return request.url === server.url && request.id === container.Id;
            });
        }).map(function (container) {
            return container.Id;
        });
        statsRefreshTimer.restart();
    }
    function requestNextContainerStats() {
        if (!page.selectedServer || page.selectedResource !== "" || !page.statsServer || page.selectedServer.url !== page.statsServer.url) {
            page.pendingStatsQueue = [];
            page.statsServer = null;
            return;
        }
        const server = page.statsServer;
        while (page.activeStatsRequests.length < page.maxConcurrentStatsRequests && page.pendingStatsQueue.length > 0) {
            const id = page.pendingStatsQueue.shift();
            page.activeStatsRequests = page.activeStatsRequests.concat([{
                url: server.url,
                id: id
            }]);
            DockerApi.containerStats(server, id, function (stats) {
                page.activeStatsRequests = page.activeStatsRequests.filter(function (request) {
                    return request.url !== server.url || request.id !== id;
                });
                if (stats.success && page.selectedServer && page.selectedServer.url === server.url && page.selectedResource === "") {
                    const updated = page.containers.slice();
                    for (let i = 0; i < updated.length; ++i)
                        if (updated[i].Id === id)
                            updated[i] = Object.assign({}, updated[i], {
                                stats: stats.data
                            });
                    page.setContainers(updated);
                }
                if (page.selectedResource === "" && page.selectedServer && page.statsServer && page.selectedServer.url === page.statsServer.url && page.pendingStatsQueue.length > 0)
                    statsRefreshTimer.restart();
            });
        }
    }
    function toggleExpanded(container) {
        if (page.expandedId === container.Id) {
            page.expandedId = "";
            return;
        }

        page.expandedId = container.Id;
        page.detailTab = 0;
        const server = page.selectedServer;
        DockerApi.inspectContainer(server, container.Id, function (result) {
            if (!result.success || page.expandedId !== container.Id)
                return;
            const updated = page.containers.slice();
            for (let i = 0; i < updated.length; ++i) {
                if (updated[i].Id === container.Id) {
                    updated[i] = Object.assign({}, updated[i], {
                        inspect: result.data
                    });
                    break;
                }
            }
            page.setContainers(updated);
        });
        page.loadLogs(container.Id);
    }
    function loadLogs(id) {
        const server = page.selectedServer;
        if (!server || !id)
            return;
        DockerApi.containerLogs(server, id, function (result) {
            if (!result.success || page.expandedId !== id)
                return;
            const updated = page.containers.slice();
            for (let i = 0; i < updated.length; ++i) {
                if (updated[i].Id === id) {
                    updated[i] = Object.assign({}, updated[i], {
                        logs: result.data || ""
                    });
                    break;
                }
            }
            page.setContainers(updated);
        });
    }
    function setContainerState(container, start) {
        const server = page.selectedServer;
        if (!server)
            return;
        const callback = function (result) {
            page.noticeText = result.success ? (start ? Shared.Strings.containerStarted : Shared.Strings.containerStopped) : (result.error || Shared.Strings.actionFailed);
            if (result.success) {
                if (page.selectedResource === "")
                    page.refreshContainers();
                else if (page.selectedResource === "Stacks")
                    page.refreshContainers(false, false, false);
                else
                    page.refreshCurrentResource();
            }
        };
        if (start)
            DockerApi.startContainer(server, container.Id, callback);
        else
            DockerApi.stopContainer(server, container.Id, callback);
    }

    Timer {
        interval: Math.max(1, page.configuration.updateInterval || 30) * 1000
        running: page.selectedServer !== null
        repeat: true
        onTriggered: {
            if (page.selectedResource === "")
                page.refreshContainers(true);
            else
                page.refreshCurrentResource();
        }
    }
    Timer {
        interval: Math.max(1, page.configuration.serverOverviewRefreshInterval || 45) * 1000
        running: page.selectedServer === null
        repeat: true
        onTriggered: page.refreshDashboard()
    }
    Timer {
        interval: 10000
        running: page.expandedId !== "" && page.detailTab === 1
        repeat: true
        onTriggered: page.loadLogs(page.expandedId)
    }
    Timer {
        id: searchMetadataTimer
        interval: 300
        repeat: false
        onTriggered: page.loadContainerSearchMetadata()
    }
    Timer {
        id: resourceRequestStartTimer
        interval: 50
        repeat: false
        onTriggered: {
            const pending = page.pendingResourceLoad;
            page.pendingResourceLoad = null;
            if (!pending || !page.selectedServer || page.selectedServer.url !== pending.server.url || page.selectedResource !== pending.resource)
                return;
            page.requestResourceData(pending.server, pending.resource, pending.callback, pending.force);
        }
    }
    Timer {
        id: statsRefreshTimer
        interval: 50
        repeat: false
        onTriggered: page.requestNextContainerStats()
    }
    Connections {
        target: page.configuration
        function onServersChanged() {
            page.selectedServer = null;
            page.selectedResource = "";
            page.loadServers();
        }
        function onShowServerImagesChanged() {
            page.refreshDashboard();
        }
        function onShowServerVolumesChanged() {
            page.refreshDashboard();
        }
    }
    Connections {
        target: page
        function onSelectedResourceChanged() {
            if (page.selectedResource !== "") {
                page.pendingStatsQueue = [];
                page.statsServer = null;
                statsRefreshTimer.stop();
            }
        }
    }
    Component.onCompleted: loadServers()
}
