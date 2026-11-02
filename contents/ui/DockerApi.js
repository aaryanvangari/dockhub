.pragma library

// ------------------------------------------------------------------
// Transport abstraction
// ------------------------------------------------------------------
//
// Servers can connect via two transports:
//   1. HTTP/TCP   (server.url is an HTTP URL like "http://host:2375")
//   2. Unix socket (server.url is a Unix domain socket path like
//      "/var/run/docker.sock" or "/run/user/1000/docker.sock")
//
// The request() function detects the transport based on server type
// and routes accordingly.  All Docker API operations remain the same —
// only the transport changes.
//
// Unix socket transport uses a C++ plugin (UnixSocketBridge) for
// native AF_UNIX socket communication — no Python dependency required.

function isLocalServer(server) {
    const url = String(server && server.url || "");
    return !/^https?:\/\//i.test(url);
}

// ------------------------------------------------------------------
// HTTP request handler (TCP and Unix socket transports)
// ------------------------------------------------------------------

var unixRequestSequence = 0;

function request(server, method, endpoint, body, callback, unixSocketBridge) {
    const serverUrl = String(server && server.url || "");
    const prefix = String(server && server.apiPrefix || "").replace(/\/+$/, "");
    const resource = String(endpoint).split("?")[0].split("/").filter(Boolean)[0] || "unknown";
    const serverLabel = String(server && server.name || "server");
    const startedAt = Date.now();
    let completed = false;

    const finish = function (result, transportLabel) {
        if (completed)
            return;
        completed = true;
        console.log("[DockHub " + transportLabel + "] <- " + serverLabel + " " + resource + " " +
                    (result.success ? result.status : "error") + " " + (Date.now() - startedAt) + " ms");
        callback(result);
    };
    

    if (isLocalServer(server)) {
        if (!unixSocketBridge) {
            finish({ success: false, status: 0, data: null, error: "UnixSocketBridge is unavailable" }, "Unix");
            return;
        }

        const requestId = "dockhub-" + Date.now() + "-" + (++unixRequestSequence);
        const fullEndpoint = prefix + (String(endpoint).startsWith("/") ? endpoint : "/" + endpoint);
        const encodedBody = body === null || body === undefined ? null : JSON.stringify(body);
        const onFinished = function (finishedId, result) {
            if (finishedId !== requestId)
                return;
        
            // console.log("[DockHub Unix] Response received:", JSON.stringify(result));
        
            unixSocketBridge.requestFinished.disconnect(onFinished);
            finish(result, "Unix");
        };

        console.log("[DockHub Unix] -> " + serverLabel + " " + resource + " " + method + " " + fullEndpoint);
        unixSocketBridge.requestFinished.connect(onFinished);
        try {
            unixSocketBridge.sendHttpRequest(serverUrl, method, fullEndpoint, encodedBody, requestId);
        } catch (error) {
            // console.error("[DockHub] Request failed:", error);
            // console.error("[DockHub] Error details:", JSON.stringify(error));
            unixSocketBridge.requestFinished.disconnect(onFinished);
            finish({ success: false, status: 0, data: null, error: String(error) }, "Unix");
        }
        return;
    }

    // HTTP/TCP transport via XMLHttpRequest.
    const base = serverUrl.replace(/\/+$/, "");
    const xhr = new XMLHttpRequest();
    const url = base + prefix + (String(endpoint).startsWith("/") ? endpoint : "/" + endpoint);

    console.log("[DockHub API] -> " + serverLabel + " " + resource + " " + method + " " + url);

    xhr.open(method, url);
    xhr.setRequestHeader("Accept", "application/json");
    if (body !== null && body !== undefined)
        xhr.setRequestHeader("Content-Type", "application/json");

    xhr.onreadystatechange = function () {
        if (xhr.readyState !== XMLHttpRequest.DONE)
            return;

        let data = xhr.responseText;
        try {
            data = data ? JSON.parse(data) : null;
        } catch (e) {
            // Some Docker endpoints return plain text or multiplexed log data.
        }
        finish({
            success: xhr.status >= 200 && xhr.status < 300,
            status: xhr.status,
            data: data,
            error: xhr.status === 0 ? "Server unreachable" :
                   (xhr.status >= 400 ? "HTTP " + xhr.status : "")
        }, "API");
    };

    xhr.onerror = function () {
        finish({ success: false, status: xhr.status, data: null, error: "Network error" }, "API");
    };
    xhr.ontimeout = function () {
        finish({ success: false, status: xhr.status, data: null, error: "Request timed out" }, "API");
    };
    xhr.timeout = 10000;
    xhr.send(body !== null && body !== undefined ? JSON.stringify(body) : null);
}

// ------------------------------------------------------------------
// Docker server information
// ------------------------------------------------------------------

function ping(server, callback, unixSocketBridge) {
    request(server, "GET", "/_ping", null, callback, unixSocketBridge);
}

function version(server, callback, unixSocketBridge) {
    request(server, "GET", "/version", null, callback, unixSocketBridge);
}

function info(server, callback, unixSocketBridge) {
    request(server, "GET", "/info", null, callback, unixSocketBridge);
}

function diskUsage(server, callback, unixSocketBridge) {
    request(server, "GET", "/system/df", null, callback, unixSocketBridge);
}

// ------------------------------------------------------------------
// Containers
// ------------------------------------------------------------------

function containers(server, all, callback, unixSocketBridge) {
    request(server, "GET", "/containers/json?all=" + (all ? "1" : "0"), null, callback, unixSocketBridge);
}

function inspectContainer(server, id, callback, unixSocketBridge) {
    request(server, "GET", "/containers/" + encodeURIComponent(id) + "/json?size=true", null, callback, unixSocketBridge);
}

function startContainer(server, id, callback, unixSocketBridge) {
    request(server, "POST", "/containers/" + encodeURIComponent(id) + "/start", null, callback, unixSocketBridge);
}

function stopContainer(server, id, callback, unixSocketBridge) {
    request(server, "POST", "/containers/" + encodeURIComponent(id) + "/stop", null, callback, unixSocketBridge);
}

function restartContainer(server, id, callback, unixSocketBridge) {
    request(server, "POST", "/containers/" + encodeURIComponent(id) + "/restart", null, callback, unixSocketBridge);
}

function pauseContainer(server, id, callback, unixSocketBridge) {
    request(server, "POST", "/containers/" + encodeURIComponent(id) + "/pause", null, callback, unixSocketBridge);
}

function unpauseContainer(server, id, callback, unixSocketBridge) {
    request(server, "POST", "/containers/" + encodeURIComponent(id) + "/unpause", null, callback, unixSocketBridge);
}

function removeContainer(server, id, callback, unixSocketBridge) {
    request(server, "DELETE", "/containers/" + encodeURIComponent(id) + "?force=false", null, callback, unixSocketBridge);
}

// ------------------------------------------------------------------
// Container statistics
// ------------------------------------------------------------------

function containerStats(server, id, callback, unixSocketBridge) {
    request(server, "GET", "/containers/" + encodeURIComponent(id) + "/stats?stream=false", null, callback, unixSocketBridge);
}

function containerLogs(server, id, callback, unixSocketBridge) {
    request(server, "GET", "/containers/" + encodeURIComponent(id) + "/logs?stdout=1&stderr=1&tail=150&timestamps=1", null, function (result) {
        if (result.success && typeof result.data === "string") {
            // Non-TTY Docker logs are multiplexed into 8-byte headers plus payload frames.
            // Strip those headers when present; TTY logs are already plain text.
            var input = result.data;
            var output = "";
            var offset = 0;
            var framed = input.length >= 8 && input.charCodeAt(0) <= 2 && input.charCodeAt(1) === 0 && input.charCodeAt(2) === 0 && input.charCodeAt(3) === 0;
            while (framed && offset + 8 <= input.length) {
                var length = input.charCodeAt(offset + 4) * 16777216 + input.charCodeAt(offset + 5) * 65536 + input.charCodeAt(offset + 6) * 256 + input.charCodeAt(offset + 7);
                if (offset + 8 + length > input.length) {
                    framed = false;
                    break;
                }
                output += input.slice(offset + 8, offset + 8 + length);
                offset += 8 + length;
            }
            if (framed && offset === input.length)
                result.data = output;
        }
        callback(result);
    }, unixSocketBridge);
}

// ------------------------------------------------------------------
// Images
// ------------------------------------------------------------------

function images(server, callback, unixSocketBridge) {
    request(server, "GET", "/images/json", null, callback, unixSocketBridge);
}

function inspectImage(server, id, callback, unixSocketBridge) {
    request(server, "GET", "/images/" + encodeURIComponent(id) + "/json", null, callback, unixSocketBridge);
}

function imageHistory(server, id, callback, unixSocketBridge) {
    request(server, "GET", "/images/" + encodeURIComponent(id) + "/history", null, callback, unixSocketBridge);
}

function removeImage(server, id, callback, unixSocketBridge) {
    request(server, "DELETE", "/images/" + encodeURIComponent(id), null, callback, unixSocketBridge);
}

// ------------------------------------------------------------------
// Networks
// ------------------------------------------------------------------

function networks(server, callback, unixSocketBridge) {
    request(server, "GET", "/networks", null, callback, unixSocketBridge);
}

function inspectNetwork(server, id, callback, unixSocketBridge) {
    request(server, "GET", "/networks/" + encodeURIComponent(id), null, callback, unixSocketBridge);
}

// ------------------------------------------------------------------
// Volumes
// ------------------------------------------------------------------

function volumes(server, callback, unixSocketBridge) {
    request(server, "GET", "/volumes", null, callback, unixSocketBridge);
}

function inspectVolume(server, name, callback, unixSocketBridge) {
    request(server, "GET", "/volumes/" + encodeURIComponent(name), null, callback, unixSocketBridge);
}

// ------------------------------------------------------------------
// Docker events
// ------------------------------------------------------------------

function events(server, since, until, callback, unixSocketBridge) {
    request(server, "GET", "/events?since=" + encodeURIComponent(since) + "&until=" + encodeURIComponent(until), null, callback, unixSocketBridge);
}
