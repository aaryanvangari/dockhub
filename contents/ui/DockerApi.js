.pragma library

.import "DockerLogParser.js" as DockerLogParser

// ------------------------------------------------------------------
// Transport abstraction
// ------------------------------------------------------------------

var unixRequestSequence = 0;
var unixStreamSequence = 0;

function isLocalServer(server) {
    const url = String(server && server.url || "");
    return !/^https?:\/\//i.test(url);
}

function makeRequestId(prefix) {
    return prefix + "-" + Date.now() + "-" +
           (++unixRequestSequence);
}

function makeStreamId() {
    return "dockhub-stream-" + Date.now() + "-" +
           (++unixStreamSequence);
}

function getEndpoint(server, endpoint) {
    const prefix = String(server && server.apiPrefix || "")
                       .replace(/\/+$/, "");

    return prefix +
           (String(endpoint).startsWith("/")
                ? endpoint
                : "/" + endpoint);
}

// ------------------------------------------------------------------
// Common request handler
// ------------------------------------------------------------------

function request(server, method, endpoint, body, callback,
                 unixSocketBridge) {
    const serverUrl = String(server && server.url || "");
    const serverLabel = String(server && server.name || "server");
    const resource = String(endpoint).split("?")[0]
                                      .split("/")
                                      .filter(Boolean)[0] || "unknown";

    const startedAt = Date.now();
    let completed = false;

    const finish = function(result, transportLabel) {
        if (completed)
            return;

        completed = true;

        console.log("[DockHub " + transportLabel + "] <- " +
                    serverLabel + " " + resource + " " +
                    (result.success ? result.status : "error") +
                    " " + (Date.now() - startedAt) + " ms");

        callback(result);
    };

    // --------------------------------------------------------------
    // Unix socket transport
    // --------------------------------------------------------------

    if (isLocalServer(server)) {
        if (!unixSocketBridge) {
            finish({
                success: false,
                status: 0,
                data: null,
                error: "UnixSocketBridge is unavailable"
            }, "Unix");

            return;
        }

        const requestId = makeRequestId("dockhub");
        const fullEndpoint = getEndpoint(server, endpoint);

        const encodedBody =
            body === null || body === undefined
                ? null
                : JSON.stringify(body);

        const onFinished = function(finishedId, result) {
            if (finishedId !== requestId)
                return;

            unixSocketBridge.requestFinished.disconnect(onFinished);

            finish(result, "Unix");
        };

        console.log("[DockHub Unix] -> " + serverLabel + " " +
                    resource + " " + method + " " + fullEndpoint);

        unixSocketBridge.requestFinished.connect(onFinished);

        try {
            unixSocketBridge.sendHttpRequest(
                serverUrl,
                method,
                fullEndpoint,
                encodedBody,
                requestId
            );
        } catch (error) {
            unixSocketBridge.requestFinished.disconnect(onFinished);

            finish({
                success: false,
                status: 0,
                data: null,
                error: String(error)
            }, "Unix");
        }

        return;
    }

    // --------------------------------------------------------------
    // HTTP/TCP transport
    // --------------------------------------------------------------

    const base = serverUrl.replace(/\/+$/, "");
    const url = base + getEndpoint(server, endpoint);

    const xhr = new XMLHttpRequest();

    console.log("[DockHub API] -> " + serverLabel + " " +
                resource + " " + method + " " + url);

    xhr.open(method, url);
    xhr.setRequestHeader("Accept", "application/json");

    if (body !== null && body !== undefined)
        xhr.setRequestHeader("Content-Type", "application/json");

    xhr.onreadystatechange = function() {
        if (xhr.readyState !== XMLHttpRequest.DONE)
            return;

        let data = xhr.responseText;

        try {
            data = data ? JSON.parse(data) : null;
        } catch (error) {
            // Some Docker endpoints return plain text or binary data.
        }

        finish({
            success: xhr.status >= 200 && xhr.status < 300,
            status: xhr.status,
            data: data,
            error: xhr.status === 0
                ? "Server unreachable"
                : (xhr.status >= 400 ? "HTTP " + xhr.status : "")
        }, "API");
    };

    xhr.onerror = function() {
        finish({
            success: false,
            status: xhr.status,
            data: null,
            error: "Network error"
        }, "API");
    };

    xhr.ontimeout = function() {
        finish({
            success: false,
            status: xhr.status,
            data: null,
            error: "Request timed out"
        }, "API");
    };

    xhr.timeout = 10000;

    xhr.send(
        body !== null && body !== undefined
            ? JSON.stringify(body)
            : null
    );
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
    request(
        server,
        "GET",
        "/containers/json?all=" + (all ? "1" : "0"),
        null,
        callback,
        unixSocketBridge
    );
}

function inspectContainer(server, id, callback, unixSocketBridge) {
    request(
        server,
        "GET",
        "/containers/" + encodeURIComponent(id) + "/json?size=true",
        null,
        callback,
        unixSocketBridge
    );
}

function startContainer(server, id, callback, unixSocketBridge) {
    request(
        server,
        "POST",
        "/containers/" + encodeURIComponent(id) + "/start",
        null,
        callback,
        unixSocketBridge
    );
}

function stopContainer(server, id, callback, unixSocketBridge) {
    request(
        server,
        "POST",
        "/containers/" + encodeURIComponent(id) + "/stop",
        null,
        callback,
        unixSocketBridge
    );
}

function restartContainer(server, id, callback, unixSocketBridge) {
    request(
        server,
        "POST",
        "/containers/" + encodeURIComponent(id) + "/restart",
        null,
        callback,
        unixSocketBridge
    );
}

function pauseContainer(server, id, callback, unixSocketBridge) {
    request(
        server,
        "POST",
        "/containers/" + encodeURIComponent(id) + "/pause",
        null,
        callback,
        unixSocketBridge
    );
}

function unpauseContainer(server, id, callback, unixSocketBridge) {
    request(
        server,
        "POST",
        "/containers/" + encodeURIComponent(id) + "/unpause",
        null,
        callback,
        unixSocketBridge
    );
}

function removeContainer(server, id, callback, unixSocketBridge) {
    request(
        server,
        "DELETE",
        "/containers/" + encodeURIComponent(id) + "?force=false",
        null,
        callback,
        unixSocketBridge
    );
}

// ------------------------------------------------------------------
// Container statistics
// ------------------------------------------------------------------

function containerStats(server, id, callback, unixSocketBridge) {
    request(
        server,
        "GET",
        "/containers/" + encodeURIComponent(id) + "/stats?stream=false",
        null,
        callback,
        unixSocketBridge
    );
}

// ------------------------------------------------------------------
// Container logs - one-shot request
// ------------------------------------------------------------------

function containerLogs(server, id, callback, unixSocketBridge) {
    request(
        server,
        "GET",
        "/containers/" + encodeURIComponent(id) +
            "/logs?stdout=1&stderr=1&tail=150&timestamps=1",
        null,
        function(result) {
            if (result.success && typeof result.data === "string") {
                result.data = DockerLogParser.decodeComplete(result.data);
            }

            callback(result);
        },
        unixSocketBridge
    );
}

// ------------------------------------------------------------------
// Container logs - persistent streaming request
// ------------------------------------------------------------------

/*
 * Starts a persistent log stream for a container.
 *
 * Parameters:
 *   server           Docker server configuration
 *   id               Container ID
 *   unixSocketBridge UnixSocketBridge QML object
 *   onData           Receives { stream, data }
 *   onFinished       Receives final result
 *
 * onData:
 *   { stream: "stdout", data: "..." }
 *   { stream: "stderr", data: "..." }
 *
 * Returns:
 *   request ID, or empty string if the stream could not be started.
 *
 * Note:
 *   The C++ UnixSocketBridge currently handles Unix socket streaming.
 *   TCP servers continue to use the existing one-shot log request.
 */

function streamContainerLogs(server, id, unixSocketBridge,
                             onData, onFinished) {
    if (!server || !id) {
        if (onFinished) {
            onFinished({
                success: false,
                status: 0,
                data: null,
                error: "Missing server or container ID"
            });
        }

        return "";
    }

    if (!isLocalServer(server)) {
        if (onFinished) {
            onFinished({
                success: false,
                status: 0,
                data: null,
                error: "Persistent log streaming is currently supported only for Unix socket servers"
            });
        }

        return "";
    }

    if (!unixSocketBridge) {
        if (onFinished) {
            onFinished({
                success: false,
                status: 0,
                data: null,
                error: "UnixSocketBridge is unavailable"
            });
        }

        return "";
    }

    const serverUrl = String(server.url || "");
    const serverLabel = String(server.name || "server");
    const requestId = makeStreamId();

    const endpoint =
        getEndpoint(
            server,
            "/containers/" + encodeURIComponent(id) +
            "/logs?stdout=1&stderr=1&follow=1&tail=150&timestamps=1"
        );

    const parser = DockerLogParser.createParser();

    let completed = false;
    const startedAt = Date.now();

    let onStreamingData = null;
    let onStreamingFinished = null;

    const cleanup = function() {
        try {
            if (onStreamingData)
                unixSocketBridge.streamingData.disconnect(onStreamingData);
        } catch (error) {
        }

        try {
            if (onStreamingFinished)
                unixSocketBridge.streamingFinished.disconnect(onStreamingFinished);
        } catch (error) {
        }
    };

    onStreamingData = function(receivedId, bytes) {
        if (receivedId !== requestId || completed)
            return;

        DockerLogParser.push(
            parser,
            bytes,
            function(stream, data) {
                if (completed || !onData)
                    return;

                onData({
                    stream: stream,
                    data: data
                });
            }
        );
    };

    onStreamingFinished = function(receivedId, result) {
        if (receivedId !== requestId || completed)
            return;

        completed = true;

        DockerLogParser.finish(
            parser,
            function(stream, data) {
                if (onData) {
                    onData({
                        stream: stream,
                        data: data
                    });
                }
            }
        );

        cleanup();

        console.log(
            "[DockHub Unix Stream] <- " + serverLabel +
            " container logs " +
            (result.success ? result.status : "error") +
            " " + (Date.now() - startedAt) + " ms"
        );

        if (onFinished)
            onFinished(result);
    };

    console.log(
        "[DockHub Unix Stream] -> " + serverLabel +
        " container logs GET " + endpoint
    );

    unixSocketBridge.streamingData.connect(onStreamingData);
    unixSocketBridge.streamingFinished.connect(onStreamingFinished);

    try {
        const returnedId =
            unixSocketBridge.startStreamingRequest(
                serverUrl,
                "GET",
                endpoint,
                null,
                requestId
            );

        if (!returnedId) {
            completed = true;
            cleanup();

            if (onFinished) {
                onFinished({
                    success: false,
                    status: 0,
                    data: null,
                    error: "Could not start Docker log stream"
                });
            }

            return "";
        }
    } catch (error) {
        completed = true;
        cleanup();

        if (onFinished) {
            onFinished({
                success: false,
                status: 0,
                data: null,
                error: String(error)
            });
        }

        return "";
    }

    return requestId;
}

// ------------------------------------------------------------------
// Stop a persistent container log stream
// ------------------------------------------------------------------

function stopContainerLogs(unixSocketBridge, requestId) {
    if (!unixSocketBridge || !requestId)
        return;

    unixSocketBridge.stopStreamingRequest(requestId);
}

// ------------------------------------------------------------------
// Images
// ------------------------------------------------------------------

function images(server, callback, unixSocketBridge) {
    request(server, "GET", "/images/json", null, callback, unixSocketBridge);
}

function inspectImage(server, id, callback, unixSocketBridge) {
    request(
        server,
        "GET",
        "/images/" + encodeURIComponent(id) + "/json",
        null,
        callback,
        unixSocketBridge
    );
}

function imageHistory(server, id, callback, unixSocketBridge) {
    request(
        server,
        "GET",
        "/images/" + encodeURIComponent(id) + "/history",
        null,
        callback,
        unixSocketBridge
    );
}

function removeImage(server, id, callback, unixSocketBridge) {
    request(
        server,
        "DELETE",
        "/images/" + encodeURIComponent(id),
        null,
        callback,
        unixSocketBridge
    );
}

// ------------------------------------------------------------------
// Networks
// ------------------------------------------------------------------

function networks(server, callback, unixSocketBridge) {
    request(server, "GET", "/networks", null, callback, unixSocketBridge);
}

function inspectNetwork(server, id, callback, unixSocketBridge) {
    request(
        server,
        "GET",
        "/networks/" + encodeURIComponent(id),
        null,
        callback,
        unixSocketBridge
    );
}

// ------------------------------------------------------------------
// Volumes
// ------------------------------------------------------------------

function volumes(server, callback, unixSocketBridge) {
    request(server, "GET", "/volumes", null, callback, unixSocketBridge);
}

function inspectVolume(server, name, callback, unixSocketBridge) {
    request(
        server,
        "GET",
        "/volumes/" + encodeURIComponent(name),
        null,
        callback,
        unixSocketBridge
    );
}

// ------------------------------------------------------------------
// Docker events
// ------------------------------------------------------------------

function events(server, since, until, callback, unixSocketBridge) {
    request(
        server,
        "GET",
        "/events?since=" + encodeURIComponent(since) +
            "&until=" + encodeURIComponent(until),
        null,
        callback,
        unixSocketBridge
    );
}
