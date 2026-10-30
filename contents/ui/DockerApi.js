.pragma library

// ------------------------------------------------------------------
// HTTP request handler
// ------------------------------------------------------------------

function request(server, method, endpoint, body, callback) {
    const xhr = new XMLHttpRequest();

    const base = String(server.url).replace(/\/+$/, "");
    const prefix = server.apiPrefix || "";
    const path = String(endpoint).split("?")[0];
    const resource = path.split("/").filter(Boolean)[0] || "unknown";
    const serverLabel = String(server.name || "server");
    const startedAt = Date.now();
    let completed = false;

    console.log("[Dockhub API] -> " + serverLabel + " " + resource + " " + method + " " + path);

    const finish = function (result) {
        if (completed)
            return;
        completed = true;
        console.log("[Dockhub API] <- " + serverLabel + " " + resource + " " + result.status + " " + (Date.now() - startedAt) + " ms");
        callback(result);
    };

    xhr.open(method, base + prefix + endpoint);

    xhr.setRequestHeader("Accept", "application/json");

    if (body !== null && body !== undefined) {
        xhr.setRequestHeader("Content-Type", "application/json");
    }

    xhr.onreadystatechange = function () {
        if (xhr.readyState !== XMLHttpRequest.DONE)
            return;

        let data = xhr.responseText;

        try {
            data = data ? JSON.parse(data) : null;
        } catch (e) {
            // Some Docker endpoints return plain text or streams.
        }

        finish({
            success: xhr.status >= 200 && xhr.status < 300,
            status: xhr.status,
            data: data,
            error: xhr.status === 0 ? "Server unreachable" : xhr.statusText
        });
    };

    xhr.onerror = function () {
        finish({
            success: false,
            status: xhr.status,
            data: null,
            error: "Network error"
        });
    };

    xhr.ontimeout = function () {
        finish({
            success: false,
            status: xhr.status,
            data: null,
            error: "Request timed out"
        });
    };

    xhr.timeout = 10000;

    if (body !== null && body !== undefined)
        xhr.send(JSON.stringify(body));
    else
        xhr.send();
}

// ------------------------------------------------------------------
// Docker server information
// ------------------------------------------------------------------

function ping(server, callback) {
    request(server, "GET", "/_ping", null, callback);
}

function version(server, callback) {
    request(server, "GET", "/version", null, callback);
}

function info(server, callback) {
    request(server, "GET", "/info", null, callback);
}

function diskUsage(server, callback) {
    request(server, "GET", "/system/df", null, callback);
}

// ------------------------------------------------------------------
// Containers
// ------------------------------------------------------------------

function containers(server, all, callback) {
    request(server, "GET", "/containers/json?all=" + (all ? "1" : "0"), null, callback);
}

function inspectContainer(server, id, callback) {
    request(server, "GET", "/containers/" + encodeURIComponent(id) + "/json?size=true", null, callback);
}

function startContainer(server, id, callback) {
    request(server, "POST", "/containers/" + encodeURIComponent(id) + "/start", null, callback);
}

function stopContainer(server, id, callback) {
    request(server, "POST", "/containers/" + encodeURIComponent(id) + "/stop", null, callback);
}

function restartContainer(server, id, callback) {
    request(server, "POST", "/containers/" + encodeURIComponent(id) + "/restart", null, callback);
}

function pauseContainer(server, id, callback) {
    request(server, "POST", "/containers/" + encodeURIComponent(id) + "/pause", null, callback);
}

function unpauseContainer(server, id, callback) {
    request(server, "POST", "/containers/" + encodeURIComponent(id) + "/unpause", null, callback);
}

function removeContainer(server, id, callback) {
    request(server, "DELETE", "/containers/" + encodeURIComponent(id) + "?force=false", null, callback);
}

// ------------------------------------------------------------------
// Container statistics
// ------------------------------------------------------------------

function containerStats(server, id, callback) {
    request(server, "GET", "/containers/" + encodeURIComponent(id) + "/stats?stream=false", null, callback);
}

function containerLogs(server, id, callback) {
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
    });
}

// ------------------------------------------------------------------
// Images
// ------------------------------------------------------------------

function images(server, callback) {
    request(server, "GET", "/images/json", null, callback);
}

function inspectImage(server, id, callback) {
    request(server, "GET", "/images/" + encodeURIComponent(id) + "/json", null, callback);
}

function imageHistory(server, id, callback) {
    request(server, "GET", "/images/" + encodeURIComponent(id) + "/history", null, callback);
}

function removeImage(server, id, callback) {
    request(server, "DELETE", "/images/" + encodeURIComponent(id), null, callback);
}

// ------------------------------------------------------------------
// Networks
// ------------------------------------------------------------------

function networks(server, callback) {
    request(server, "GET", "/networks", null, callback);
}

function inspectNetwork(server, id, callback) {
    request(server, "GET", "/networks/" + encodeURIComponent(id), null, callback);
}

// ------------------------------------------------------------------
// Volumes
// ------------------------------------------------------------------

function volumes(server, callback) {
    request(server, "GET", "/volumes", null, callback);
}

function inspectVolume(server, name, callback) {
    request(server, "GET", "/volumes/" + encodeURIComponent(name), null, callback);
}

// ------------------------------------------------------------------
// Docker events
// ------------------------------------------------------------------

function events(server, since, until, callback) {
    request(server, "GET", "/events?since=" + encodeURIComponent(since) + "&until=" + encodeURIComponent(until), null, callback);
}
