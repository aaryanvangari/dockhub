# DockHub Architecture

## Overview

DockHub uses a layered architecture with four distinct tiers:

1. **Presentation Layer** — QML UI components
2. **JavaScript API Layer** — DockerApi.js and DockerLogParser.js
3. **C++ Communication Layer** — UnixSocketBridge and DockerClient
4. **Docker Engine API Layer** — Docker HTTP API and Unix sockets

## 1. Presentation Layer (QML)

Location:

`package/contents/ui/components/`

Responsibilities:

- Display Docker servers, containers, images, networks, volumes, stacks, and events.
- Display container status and resource statistics (CPU, memory, block I/O, network I/O).
- Handle user interactions (click, expand/collapse, log streaming, container actions).
- Display server configuration and settings.
- Manage real-time log viewing with auto-follow scrolling.

Key UI Components:

- **DashboardController** — Central backend managing all data fetching, caching, stats polling, log streaming, search filtering, and navigation logic.
- **ServerListItem / ServerOverviewMetric / ServerMetric / ContainerSummaryMetric** — Server display widgets.
- **ContainerListItem / ContainerDetail / ContainerLogsPage** — Container display, expansion, and log streaming.
- **ImageListItem / NetworkListItem / VolumeListItem / StackListItem** — Resource detail views.
- **LegendCard / ServerLegend / DisclosureHeader / EventListItem** — Helper and overview widgets.
- **ResourceItemsPage** — Paginated resource list dispatching to type-specific components.

QML must not implement Docker HTTP communication directly.

## 2. JavaScript API Layer

Location:

`package/contents/ui/`

### `DockerApi.js`

A JavaScript API wrapper over the C++ `DockerClient` component, providing a QML-friendly interface for Docker Engine interactions.

Responsibilities:

- Route requests to the correct connection type (local Unix socket vs. remote HTTP).
- Generate unique request IDs and stream IDs for traceability.
- Build and dispatch all Docker Engine API calls (containers, images, networks, volumes, events, logs, stats).
- Manage WebSocket-style log streaming with multiplexed stdout/stderr support.
- Handle four C++ error categories: connection, request, HTTP, and timeout.

Exposed API Functions:

- `ping()`, `version()`, `info()`, `diskUsage()` — Server info queries.
- `containers()`, `inspectContainer()`, `startContainer()`, `stopContainer()`, `restartContainer()`, `pauseContainer()`, `unpauseContainer()`, `removeContainer()` — Container lifecycle.
- `containerStats()`, `containerLogs()`, `streamContainerLogs()`, `stopContainerLogs()` — Resource usage and log access.
- `images()`, `inspectImage()`, `imageHistory()`, `removeImage()` — Image management.
- `networks()`, `inspectNetwork()`, `volumes()`, `inspectVolume()` — Network and volume queries.
- `events()` — Daemon event subscription.

### `DockerLogParser.js`

A parser for Docker's non-TTY multiplexed log streams.

Responsibilities:

- Decode 8-byte Docker stream headers (stream type, reserved bytes, payload length).
- Separate stdout, stderr, and plain-text output.
- Handle graceful degradation when headers are malformed.
- Guard against oversized frames (64 MiB limit).

Supported Stream Modes:

- **`detect`** — First 8 bytes determine multiplexed vs. plain mode.
- **`multiplexed`** — Parses 8-byte headers and extracts stdout/stderr frames.
- **`plain`** — TTY fallback; treats all data as plain stdout text.

## 3. C++ Communication Layer

The `UnixSocketBridge` exposes a small, QML-friendly surface (three request-initiation methods and one stop method) backed by three distinct code paths:

1. **One-shot Unix-socket HTTP** (`sendHttpRequest`) — request/response over `QLocalSocket` with full HTTP parsing.
2. **Persistent Unix-socket streaming** (`startStreamingRequest`) — incremental chunked/length-delimited decoder over `QLocalSocket`.
3. **HTTP/HTTPS streaming** (`startHttpStreamingRequest`) — Docker raw log stream via `QNetworkAccessManager`.

All three paths funnel completion into the same `streamingData`/`streamingFinished` (or `requestFinished` for one-shot) signal contract, so the QML layer has a single way to observe results regardless of transport.


## Files

| File | Role |
|---|---|
| `src/UnixSocketBridge.h` | Public header declaring the `UnixSocketBridge` QObject, its QML-exposed API, signals, and member state. |
| `src/UnixSocketBridge.cpp` | Implementation: HTTP request construction, header/body parsing, chunked-transfer decoding, Unix-socket streaming state machine, and HTTP(S) streaming via `QNetworkAccessManager`. |

## `UnixSocketBridge` Class

A `QObject` subclass (registered as a QML element via `QML_ELEMENT`) that acts as the bridge between the UI layer and the Docker daemon.

### Public API (Q_INVOKABLE) - QML-exposed

- `QString startHttpStreamingRequest(const QString &url, const QString &requestId)` — starts a persistent Docker log stream over HTTP/HTTPS using `QNetworkAccessManager`. Returns the request ID (or an empty string on validation failure).
- `void sendHttpRequest(socketPath, method, endpoint, body, requestId)` — performs a one-shot Docker Engine API request over a Unix socket.
- `QString startStreamingRequest(socketPath, method, endpoint, body, requestId)` — starts a persistent, chunked or length-delimited Docker API stream over a Unix socket.
- `void stopStreamingRequest(requestId)` — cancels and cleans up any active stream (Unix-socket or HTTP) with the given ID.

### Signals

- `void requestFinished(const QString &requestId, const QVariantMap &result)` — emitted when a one-shot request completes.
- `void streamingData(const QString &requestId, const QString &data)` — emits decoded HTTP response-body bytes as they arrive. Docker's own multiplexed log frames are passed through untouched.
- `void streamingFinished(const QString &requestId, const QVariantMap &result)` — emitted when a streaming request finishes (success or error).

### Member State

- `QHash<QString, StreamingRequestState *> m_activeStreamingRequests` — tracks in-flight Unix-socket streaming requests.
- `QNetworkAccessManager *m_networkAccessManager` — used for HTTP/HTTPS log streaming.
- `QHash<QString, QPointer<QNetworkReply>> m_activeHttpStreamingRequests` — tracks in-flight HTTP streaming requests.

## Internal / Helper Types

### `StreamingRequestState` (defined in the `.cpp`)
Per-request state object for Unix-socket streaming:

- Owns a `QLocalSocket`, a one-shot connection `QTimer`, and header/body buffers.
- Tracks the HTTP status, whether headers have been received, and transfer-encoding flags (`chunked`, `hasContentLength`).
- Implements a chunked-transfer decoder state machine:
  - `ReadingChunkSize` → `ReadingChunkData` → `ReadingChunkTerminator` → `ReadingTrailers` → `ChunkStreamFinished`
- Accumulates error-response bodies in `errorBody` for bounded error reporting.

### Free helpers (anonymous namespace)
- `failure(message, status)` — builds a standardized `QVariantMap` failure result.
- `jsonValueToVariant(value)` — recursively converts `QJsonValue` to `QVariant`.
- `headerValue(headers, name)` — case-insensitive lookup of an HTTP header.
- `HttpHeaders` — small struct holding parsed status, chunked flag, and `Content-Length`.
- `parseHeaders(raw, out, error)` — parses a raw HTTP response head, validating the status line with a regex.
- `makeRequest(method, endpoint, body, keepAlive)` — serializes an HTTP/1.1 request with `Content-Length`, `Accept: application/json`, and optional `Connection: keep-alive`.
- `decodeChunkedBody(body)` — one-shot chunked-body decoder (used by one-shot requests).
- `validRequest(...)` — input validation for socket path, method, and endpoint.

## Key Behaviors and Design Notes

- **Timeouts**: A 10-second connection timeout is applied to socket connect and HTTP streaming header arrival. Streaming requests have no total-duration timeout so long-running Docker log streams are not interrupted.
- **Size limits**:
  - `MaxHeaderBytes` = 64 KiB — bounds the HTTP header section.
  - `MaxResponseBytes` = 64 MiB — bounds total streaming/one-shot response body size.
  - `MaxErrorBodyBytes` = 1 MiB — bounds buffered HTTP error bodies.
- **Chunked decoding**: Both one-shot and streaming paths implement RFC 7230 chunked transfer decoding. The streaming decoder is an incremental state machine driven by `QLocalSocket::readyRead`, emitting decoded chunks via `streamingData` as they arrive.
- **Response completion**: For one-shot requests, completion is detected either by a terminal zero chunk (chunked) or by reaching `Content-Length`. For streaming requests, close-delimited, `Content-Length`-delimited, and chunked responses are all handled.
- **HTTP/HTTPS log streaming**: `startHttpStreamingRequest` uses `QNetworkAccessManager::get` with `Accept: application/vnd.docker.raw-stream`. A `StreamState` struct (held in a `QSharedPointer`) tracks whether the response has been accepted (2xx) and bounds error bodies.
- **Lifecycle safety**: State objects are removed from the active-request maps *before* emitting the completion signal, so QML handlers that call `stopStreamingRequest` synchronously are safe. All state objects use `deleteLater()` for deferred cleanup.
- **Reusing request IDs**: Calling `startStreamingRequest` or `startHttpStreamingRequest` with an existing ID cancels and replaces the previous stream for that ID.

### DockerClient (JavaScript)

Location: Referenced in `contents/ui`.

Responsibilities:

- Manage Docker server connections.
- Handle HTTP requests for remote Docker API endpoints.
- Convert Docker responses into application data.

## 4. Docker Engine API Layer

Remote connections:

- **DockerApi.js** — Uses Docker Engine HTTP API over TCP.
- Supports standard Docker API endpoints: `/ping`, `/info`, `/version`, `/containers/json`, `/images/json`, `/networks`, `/volumes`, `/events`, `/stats`, `/logs`, `/inspect`, lifecycle actions.

Local connections:

- **UnixSocketBridge.cpp** — Uses Unix domain sockets through `QLocalSocket`.
- Communicates via `/var/run/docker.sock` (rootful) or `/run/user/<UID>/docker.sock` (rootless).

## 5. Data Flow

Example: Fetching containers.

1. QML component (e.g., `DashboardController`) requests container information.
2. JavaScript `DockerApi.js` routes the request, selecting the correct connection type.
3. C++ backend receives the request via `UnixSocketBridge` or handled by `DockerApi.js` itself for http.
4. Backend selects the appropriate server connection.
5. Docker API request is executed over the correct transport (Unix socket or HTTP).
6. Docker response is parsed.
7. C++ emits signals (`streamingData`, `requestFinished`, `streamingFinished`).
8. JavaScript wrapper processes results and passes to QML.
9. QML updates the interface.

Example: Streaming container logs.

1. QML opens `ContainerLogsPage`.
2. `DockerApi.js::streamContainerLogs()` detects local vs. remote server.
3. For local servers, `UnixSocketBridge::startStreamingRequest()` opens a Unix socket WebSocket.
4. `DockerLogParser.js` decodes 8-byte multiplex headers to separate stdout/stderr.
5. Decoded log data flows back to QML for display.

## 6. Connection Responsibilities

Remote Docker servers:

- HTTP API over TCP.
- Socket proxy where configured.

Local Docker servers:

- Unix domain socket via `QLocalSocket`.

## 7. Important Design Constraints

- Multiple servers must work independently.
- Connection handling must remain isolated.
- QML should not contain Docker API logic.
- Backend communication should remain reusable.
- Log streams must handle multiplexed stdout/stderr correctly.
- Chunked transfer decoding must follow RFC 7230 for streaming responses.
- All streaming state must be safe for synchronous cancellation.
