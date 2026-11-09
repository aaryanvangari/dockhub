# Development Guide

This guide is for developers who want to contribute to Dockhub, add new features, or understand the codebase.

## Project Structure

```
dockhub/
├── contents/
│   ├── config/
│   │   ├── config.qml          # Configuration page entry point
│   │   └── translations/        # Translation files
│   ├── ui/
│   │   ├── main.qml            # Main applet widget
│   │   ├── DockerApi.js        # Docker API wrapper functions
│   │   ├── shared/
│   │   │   └── Strings.qml     # Shared translations and utility functions
│   │   ├── components/         # Reusable UI components
│   │   └── config/             # Configuration page components
├── LICENSE
├── metadata.json               # KDE Plasma applet metadata
└── README.md
```

## Building from Source

### Prerequisites

- Qt 5.x with QtQuick/QML
- KDE Plasma SDK (`plasma5-sdk`)
- CMake and build tools

### Build Commands

```bash
# Install KDE development tools
sudo apt install plasma5-sdk  # Debian/Ubuntu
# or
sudo dnf install plasma-sdk   # Fedora

# Install from source directory
plasma5-sdk install --install-from-directory contents

# Or build manually with cmake
mkdir build && cd build
cmake ..
make
sudo make install
```

## Architecture

DockHub follows a layered architecture with four distinct tiers. All Docker API logic resides in the backend layers; QML never implements network communication directly.

```
┌──────────────────────────────────────────────────────────────┐
│  Layer 1: QML Presentation (contents/ui/components/)        │
│  ── UI rendering, user interaction, navigation               │
├──────────────────────────────────────────────────────────────┤
│  Layer 2: JavaScript API (contents/ui/)                      │
│  ── DockerApi.js, DockerLogParser.js                          │
├──────────────────────────────────────────────────────────────┤
│  Layer 3: C++ Native Plugin (src/)                           │
│  ── UnixSocketBridge (local Unix socket)                      │
│  ── DockerClient (remote HTTP)                               │
├──────────────────────────────────────────────────────────────┤
│  Layer 4: Docker Engine API                                  │
│  ── HTTP API / Unix domain sockets                            │
└──────────────────────────────────────────────────────────────┘
```

### Layer 1 — QML Presentation Layer

Location: `contents/ui/components/`

Responsibilities:

- Render Docker servers, containers, images, networks, volumes, stacks, and events.
- Display container status and resource statistics (CPU, memory, block I/O, network I/O).
- Handle user interactions (click, expand/collapse, log streaming, container actions).
- Manage real-time log viewing with auto-follow scrolling.

Central Controller:

- **`DashboardController.qml`** — Manages all data fetching, state, navigation, caching, stats polling, log streaming, search filtering, and stack grouping. Exposes signals and properties used by all UI components.

Component groups:

- **Server display:** `ServerListItem.qml`, `ServerOverviewMetric.qml`, `ServerMetric.qml`, `ContainerSummaryMetric.qml`
- **Container display:** `ContainerListItem.qml`, `ContainerDetail.qml`, `ContainerLogsPage.qml`
- **Resource detail:** `ImageListItem.qml`, `NetworkListItem.qml`, `VolumeListItem.qml`, `StackListItem.qml`
- **Helper widgets:** `LegendCard.qml`, `ServerLegend.qml`, `DisclosureHeader.qml`, `EventListItem.qml`
- **Navigation:** `ResourceItemsPage.qml` — paginated resource list dispatching to type-specific components

#### UI Components Summary

| # | File | Summary |
|---|------|---------|
| 1 | `StackListItem.md` | Expandable stack list item showing container count and nested containers |
| 2 | `ServerLegend.md` | Grid overview of server resource counts (stacks, volumes, images, networks, containers) |
| 3 | `DisclosureHeader.md` | Reusable collapsible accordion header for detail sections |
| 4 | `NetworkListItem.md` | Expandable network detail view with IPAM and attached containers |
| 5 | `LegendCard.md` | Clickable card widget for showing label-value pairs |
| 6 | `ImageListItem.md` | Expandable image detail with labels, environment, and layer history |
| 7 | `ResourceItemsPage.md` | Paginated resource list page dispatching to type-specific components |
| 8 | `VolumeListItem.md` | Expandable volume detail with mounted containers |
| 9 | `DashboardController.md` | Central backend managing all data fetching, caching, stats, logs, and navigation |
| 10 | `ServerOverviewMetric.md` | Mapper wrapper delegating to ServerMetric or ContainerSummaryMetric |
| 11 | `EventListItem.md` | Read-only event display with timestamp, type, and details |
| 12 | `ContainerLogsPage.md` | Scrollable real-time log viewer with auto-follow behavior |
| 13 | `ContainerSummaryMetric.md` | Compact running/total container summary line |
| 14 | `ContainerDetail.md` | Expanded container detail panel with CPU, memory, ports, volumes, networks |
| 15 | `ServerMetric.md` | Single metric label-value row with optional hover tooltip |
| 16 | `ContainerListItem.md` | Main container list item with name, CPU, memory, ID, and expand/collapse |
| 17 | `ServerListItem.md` | Clickable server entry card with multi-column stats layout |

### Layer 2 — JavaScript API Layer

Location: `contents/ui/`

#### `DockerApi.js`

A JavaScript API wrapper over the C++ `DockerClient` component. Provides a QML-friendly interface for all Docker Engine interactions. Delegates actual network transport to C++ helpers (`makeHttpRequest`, `UnixSocketBridge`).

Key responsibilities:

- Route requests to the correct connection type (local Unix socket vs. remote HTTP) via `isLocalServer()` and `getEndpoint()`.
- Generate unique `requestId` and `streamId` strings for traceability.
- Manage WebSocket-style log streaming with multiplexed stdout/stderr support.
- Classify C++ errors into four categories: connection, request, HTTP, and timeout.

Exposed API functions:

| Category          | Functions                                                                                                                                        |
| ----------------- | ------------------------------------------------------------------------------------------------------------------------------------------------ |
| Server info       | `ping()`, `version()`, `info()`, `diskUsage()`                                                                                                   |
| Container list    | `containers()`                                                                                                                                   |
| Container actions | `inspectContainer()`, `startContainer()`, `stopContainer()`, `restartContainer()`, `pauseContainer()`, `unpauseContainer()`, `removeContainer()` |
| Resource usage    | `containerStats()`, `containerLogs()`                                                                                                            |
| Log streaming     | `streamContainerLogs()`, `stopContainerLogs()`                                                                                                   |
| Images            | `images()`, `inspectImage()`, `imageHistory()`, `removeImage()`                                                                                  |
| Networks          | `networks()`, `inspectNetwork()`                                                                                                                 |
| Volumes           | `volumes()`, `inspectVolume()`                                                                                                                   |
| Events            | `events()`                                                                                                                                       |
##### API Endpoints

| Function | Line | Docker API Endpoint | Description |
|---|---|---|---|
| `ping()` | `/ping` | Checks Docker Engine reachability. |
| `version()` | `/version` | Returns engine version info. |
| `info()` | `/info` | Returns daemon system info. |
| `diskUsage()` | `/info` with `diskUsage=1` | Returns disk usage stats. |
| `containers()` | `/containers/json` | Lists containers (supports `all`, `filters`, `limit`). |
| `inspectContainer()` | `/containers/{id}/inspect` | Inspects a single container's metadata. |
| `startContainer()` | `/containers/{id}/start` | Starts a stopped container. |
| `stopContainer()` | `/containers/{id}/stop` | Stops a running container. |
| `restartContainer()` | `/containers/{id}/restart` | Restarts a container. |
| `pauseContainer()` | `/containers/{id}/pause` | Pauses a container (cgroups). |
| `unpauseContainer()` | `/containers/{id}/unpause` | Unpauses a previously paused container. |
| `removeContainer()` | `/containers/{id}` | Removes a container (supports `force`, `volumes`). |
| `containerStats()` | `/containers/{id}/stats` | One-shot container resource usage snapshot. |
| `containerLogs()` | `/containers/{id}/logs` | Fetches complete log text (supports `since`, `timestamps`, `follow`). |
| `streamContainerLogs()` | WebSocket via `UnixSocketBridge` | Opens a live log WebSocket with multiplexed stdout/stderr support. |
| `stopContainerLogs()` | — | Closes an active log stream by `streamId`. |
| `images()` | `/images/json` | Lists images. |
| `inspectImage()` | `/images/{id}/inspect` | Inspects a single image. |
| `imageHistory()` | `/images/{id}/history` | Returns image layer history. |
| `removeImage()` | `/images/{id}` | Removes an image. |
| `networks()` | `/networks` | Lists networks. |
| `inspectNetwork()` | `/networks/{id}` | Inspects a network. |
| `volumes()` | `/volumes` | Lists volumes. |
| `inspectVolume()` | `/volumes/{name}` | Inspects a volume. |
| `events()` | `/events` | Subscribes to Docker daemon events (supports `since`, `until`, `filters`). |


#### `DockerLogParser.js`

A QML-compatible parser for Docker's non-TTY multiplexed log streams. Receives raw byte data from `UnixSocketBridge` and decodes the 8-byte Docker stream headers to separate stdout, stderr, and plain-text output.

Docker multiplex header format:

| Bytes | Field          | Description                             |
| ----- | -------------- | --------------------------------------- |
| 0     | Stream type    | `0` = stdin, `1` = stdout, `2` = stderr |
| 1–3   | Reserved       | Always zero                             |
| 4–7   | Payload length | Unsigned 32-bit big-endian integer      |

Supported stream modes:

- **`detect`** — Inspects first 8 bytes to decide between multiplexed and plain.
- **`multiplexed`** — Parses 8-byte headers and extracts stdout/stderr frames.
- **`plain`** — TTY fallback; treats all data as plain stdout text.

Error resilience: invalid UTF-8 falls back to raw bytes; malformed headers mid-stream trigger graceful fallback to plain mode.

### Layer 3 — C++ Communication Layer

#### `UnixSocketBridge` (local connections)

Location: `src/UnixSocketBridge.h`, `src/UnixSocketBridge.cpp`

A `QObject` subclass registered as a QML element via `QML_ELEMENT`. Bridges the UI layer to the Docker daemon.

QML-exposed methods:

| Method                                                                 | Purpose                                                        |
| ---------------------------------------------------------------------- | -------------------------------------------------------------- |
| `startHttpStreamingRequest(url, requestId)`                            | Start persistent Docker log stream over HTTP/HTTPS             |
| `sendHttpRequest(socketPath, method, endpoint, body, requestId)`       | One-shot Docker Engine API request over Unix socket            |
| `startStreamingRequest(socketPath, method, endpoint, body, requestId)` | Persistent chunked/length-delimited streaming over Unix socket |
| `stopStreamingRequest(requestId)`                                      | Cancel and clean up any active stream                          |

Signals:

- `requestFinished(requestId, result)` — One-shot request completion.
- `streamingData(requestId, data)` — Incremental data chunks as they arrive.
- `streamingFinished(requestId, result)` — Stream completion (success or error).

Key design behaviors:

- **Timeouts:** 10-second connection timeout; no total-duration timeout for streaming.
- **Size limits:** 64 KiB headers, 64 MiB total responses, 1 MiB error bodies.
- **Chunked decoding:** RFC 7230 state machine — `ReadingChunkSize` → `ReadingChunkData` → `ReadingChunkTerminator` → `ReadingTrailers` → `ChunkStreamFinished`.
- **Lifecycle safety:** State objects removed before emitting completion signals; deferred cleanup via `deleteLater()`.
- **Reusing IDs:** Calling `startStreamingRequest` with an existing ID cancels and replaces the previous stream.

#### DockerClient (remote connections)

Location: Referenced in the C++ plugin build (`CMakeLists.txt`).

Responsibilities:

- Manage Docker server connections.
- Handle HTTP requests for remote Docker API endpoints.
- Convert Docker responses into application data.

### Layer 4 — Docker Engine API Layer

All Docker interactions use the standard Docker Engine API.

- **Remote:** HTTP API over TCP (`DockerClient`). Endpoints include `/ping`, `/info`, `/version`, `/containers/json`, `/images/json`, `/networks`, `/volumes`, `/events`, `/stats`, `/logs`, `/inspect`, and lifecycle actions.
- **Local:** Unix domain socket via `QLocalSocket` (`UnixSocketBridge`). Communicates via `/var/run/docker.sock` (rootful) or `/run/user/<UID>/docker.sock` (rootful rootless).

### Data Flow

**Example: Fetching containers**

1. QML component (e.g., `DashboardController`) requests container information.
2. JavaScript `DockerApi.js` routes the request, selecting the correct connection type.
3. C++ backend receives the request via `UnixSocketBridge` (local) or `DockerClient` (remote).
4. Docker API request is executed over the correct transport.
5. Docker response is parsed.
6. C++ emits signals (`streamingData`, `requestFinished`, `streamingFinished`).
7. JavaScript wrapper processes results and passes to QML.
8. QML updates the interface.

**Example: Streaming container logs**

1. QML opens `ContainerLogsPage`.
2. `DockerApi.js::streamContainerLogs()` detects local vs. remote server.
3. For local servers, `UnixSocketBridge::startStreamingRequest()` opens a Unix socket connection.
4. `DockerLogParser.js` decodes 8-byte multiplex headers to separate stdout/stderr.
5. Decoded log data flows back to QML for display.

### Design Constraints

- Multiple servers must work independently.
- Connection handling must remain isolated.
- QML should not contain Docker API logic.
- Backend communication should remain reusable.
- Log streams must handle multiplexed stdout/stderr correctly.
- Chunked transfer decoding must follow RFC 7230 for streaming responses.
- All streaming state must be safe for synchronous cancellation.

### Configuration Components

Location: `contents/ui/config/`

- `ConfigGeneral.qml` — General settings (refresh intervals, visibility toggles).
- `ConfigServers.qml` — Server list and management (add, remove, edit, enable/disable).
- `ServerOverviewLayoutEditor.qml` — Layout editor for server overview metrics.

## Adding a New Feature

### Step 1: Add API Functions

If the feature requires Docker API calls, add functions to `DockerApi.js` following the existing pattern:

```javascript
// Example: New feature endpoint
function myFeature(server, callback) {
  request(server, "GET", "/my/feature", null, callback);
}
```

### Step 2: Create UI Components

Create QML components in `components/`:

```qml
pragma ComponentBehavior: Bound

import QtQuick

// Example: New feature component
Component {
    id: myFeatureComponent

    property var controller

    Rectangle {
        width: controller.width
        height: controller.height

        // Component content
    }
}
```

### Step 3: Update Dashboard Controller

Modify `DashboardController.qml` to handle new data:

```qml
// Example: Handle new resource
if (resource === "myFeature") {
    myFeatureComponent.visible = true
    myFeatureComponent.controller = page
}
```

### Step 4: Add Translations

Add strings to `Strings.qml`:

```qml
readonly property string myFeatureTitle: i18n("My Feature")
```

### Step 5: Wire Everything Up

Update `main.qml` to include the new component and connect signals/slots.

## Debugging Tips

### Enable Console Logging

The `DockerApi.js` module logs requests and responses:

```javascript
console.log("[Dockhub API] -> " + serverLabel + " " + resource + " " + method + " " + path);
console.log("[Dockhub API] <- " + serverLabel + " " + resource + " " + result.status + " " + (Date.now() - startedAt) + " ms");
```

### Check Docker API

Verify Docker is accessible:

```bash
curl http://localhost:2375/version
```

### View QML Errors

- Check system logs: `journalctl -f | grep dockhub`
- Use `qmlviewer` from Qt to inspect UI

### Test with Mock Data

Create test servers with mock data to verify features without needing Docker running.

## Code Style

### QML Style

- Use `pragma ComponentBehavior: Bound` for reusable components
- Use explicit imports (`import "path" as Alias`)
- Use descriptive component IDs
- Use `Layout.fillWidth/Height` for containers

### JavaScript Style

- Use `// ------------------------------------------------------------------` for section comments
- Use descriptive function names
- Handle errors gracefully (e.g., JSON parsing)

### Translation Style

- Use `i18n("string")` for all user-facing text
- Use `QString.arg()` for formatting values
- Keep strings concise but descriptive

## Testing

### Manual Testing Checklist

- [ ] Add a new server and verify it appears in the list
- [ ] View containers and verify stats update
- [ ] Search containers by name/image/port/IP
- [ ] View a container detail page
- [ ] Copy container ID/name/port mappings
- [ ] View images, networks, volumes, events
- [ ] Configure refresh intervals
- [ ] Test all context menu actions
- [ ] Test with an unreachable server
- [ ] Test with Docker not running

### Edge Cases

- Empty container list
- Server with no containers
- Very large number of containers
- Slow/unresponsive Docker API
- Docker API returning malformed JSON
- Network timeouts

## Known Issues

_List known issues here as they are discovered_

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Add translations if needed
6. Submit a pull request

## License

Dockhub is licensed under the GNU General Public License v3 or later. See the [LICENSE](LICENSE) file for details.
