.pragma library

// Pure helpers for formatting Docker container and statistics payloads.
// Kept separate from the dashboard controller so components can share them.

function isRunning(container) {
    return container.State === "running";
}

function shortId(container) {
    return String(container.Id || "").slice(0, 12);
}

function containerName(container) {
    if (container.inspect && container.inspect.Name)
        return String(container.inspect.Name).replace(/^\/+/, "");
    const names = container.Names || [];
    return names.length ? String(names[0]).replace(/^\/+/, "") : shortId(container);
}

function formatBytes(bytes) {
    if (bytes === undefined || bytes === null || isNaN(Number(bytes)))
        return "—";
    let value = Number(bytes), unit = "B";
    if (value >= 1000) {
        value /= 1000;
        unit = "kB";
    }
    if (value >= 1000) {
        value /= 1000;
        unit = "MB";
    }
    if (value >= 1000) {
        value /= 1000;
        unit = "GB";
    }
    const digits = unit === "B" ? 0 : 2;
    return value.toFixed(digits).replace(/\.?0+$/, "") + unit;
}

function cpu(container) {
    if (!container.stats || !container.stats.cpu_stats || !container.stats.precpu_stats)
        return "—";
    const stats = container.stats;
    const cpuDelta = stats.cpu_stats.cpu_usage.total_usage - stats.precpu_stats.cpu_usage.total_usage;
    const systemDelta = stats.cpu_stats.system_cpu_usage - stats.precpu_stats.system_cpu_usage;
    const count = stats.cpu_stats.online_cpus || (stats.cpu_stats.cpu_usage.percpu_usage || []).length || 1;
    return systemDelta > 0 ? ((cpuDelta / systemDelta) * count * 100).toFixed(1) + "%" : "—";
}

function memory(container) {
    return container.stats && container.stats.memory_stats ? formatBytes(container.stats.memory_stats.usage) : "—";
}

function memoryUsage(container) {
    const stats = container.stats && container.stats.memory_stats;
    return stats ? formatBytes(stats.usage) + " / " + formatBytes(stats.limit) + " · " + memoryPercent(container) : "—";
}

function memoryPercent(container) {
    const stats = container.stats && container.stats.memory_stats;
    const limit = stats ? Number(stats.limit || 0) : 0;
    return stats && limit > 0 ? (Number(stats.usage || 0) / limit * 100).toFixed(1) + "%" : "—";
}

function ioValues(container, kind) {
    const stats = container.stats || {};
    let first = 0, second = 0;
    if (kind === "block" && stats.blkio_stats) {
        const entries = stats.blkio_stats.io_service_bytes_recursive || stats.blkio_stats.io_serviced_recursive || [];
        for (let i = 0; i < entries.length; ++i) {
            if (entries[i].op === "Read")
                first += entries[i].value || 0;
            if (entries[i].op === "Write")
                second += entries[i].value || 0;
        }
    } else if (kind === "network" && stats.networks) {
        const names = Object.keys(stats.networks);
        for (let i = 0; i < names.length; ++i) {
            first += stats.networks[names[i]].rx_bytes || 0;
            second += stats.networks[names[i]].tx_bytes || 0;
        }
    }
    return formatBytes(first) + " / " + formatBytes(second);
}

function networkNames(container) {
    const networks = container.inspect && container.inspect.NetworkSettings ? container.inspect.NetworkSettings.Networks : null;
    return networks ? Object.keys(networks) : [];
}

function portMappings(container) {
    const ports = container.inspect && container.inspect.NetworkSettings ? container.inspect.NetworkSettings.Ports : null;
    const result = [];
    if (!ports)
        return result;
    const keys = Object.keys(ports);
    for (let i = 0; i < keys.length; ++i) {
        const bindings = ports[keys[i]] || [];
        if (bindings.length === 0)
            result.push({ source: "—", target: keys[i] });
        for (let j = 0; j < bindings.length; ++j)
            result.push({ source: (bindings[j].HostIp || "0.0.0.0") + ":" + bindings[j].HostPort, target: keys[i] });
    }
    return result;
}

function portMappingsText(container) {
    return portMappings(container).map(function (mapping) {
        return mapping.source + " -> " + mapping.target;
    }).join("\n") || "—";
}

function volumeMappings(container) {
    const mounts = container.inspect ? container.inspect.Mounts || [] : [];
    return mounts.map(function (mount) {
        return { source: mount.Source || mount.Name || "—", target: mount.Destination || "—" };
    });
}

function volumeMappingsText(container) {
    return volumeMappings(container).map(function (mapping) {
        return mapping.source + " -> " + mapping.target;
    }).join("\n") || "—";
}

function imageName(container) {
    return container.inspect && container.inspect.Config ? field(container.inspect.Config.Image) : field(container.Image);
}

function field(value) {
    return value === undefined || value === null || value === "" ? "—" : String(value);
}
