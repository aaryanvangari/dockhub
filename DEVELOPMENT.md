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

### Main Components

#### `main.qml`
The main applet widget that:

- Handles compact and full representations
- Shows the dashboard when no server is selected
- Displays server list with a search bar
- Shows container list for a selected server
- Displays resource pages (stacks, images, networks, volumes, events)

#### `DockerApi.js`
A module providing HTTP request functions to the Docker daemon. It includes:

**Server Information:**

- `ping()` - Check if server is reachable
- `version()` - Get server version
- `info()` - Get server info
- `diskUsage()` - Get disk usage statistics

**Containers:**

- `containers()` - List containers
- `inspectContainer()` - Get container details
- `startContainer()`, `stopContainer()`, `restartContainer()`
- `pauseContainer()`, `unpauseContainer()`
- `removeContainer()`

**Container Statistics:**

- `containerStats()` - Get resource usage
- `containerLogs()` - Get container logs (handles TTY multiplexed format)

**Images:**

- `images()` - List images
- `inspectImage()` - Get image details
- `imageHistory()` - Get build history
- `removeImage()`

**Networks:**

- `networks()` - List networks
- `inspectNetwork()` - Get network details

**Volumes:**

- `volumes()` - List volumes
- `inspectVolume()` - Get volume details

**Events:**

- `events()` - Get real-time events stream

#### `DashboardController.qml`
Manages the applet's state, navigation, and data fetching:

- Tracks selected server and resource
- Filters containers based on search query
- Handles navigation between views
- Manages refresh timers and intervals
- Displays errors and notices

#### `Strings.qml`
Centralized translation strings and utility functions:

- All user-facing text (labels, messages, headings)
- Helper functions like `containerCount()`, `loadingResource()`, `resourceError()`

#### `Components/`
Reusable UI components organized by feature:

- `ServerListItem.qml` - Server entry in the list
- `ContainerListItem.qml` - Container entry with stats
- `ContainerDetail.qml` - Container detail view
- `ImageListItem.qml` - Image entry
- `VolumeListItem.qml` - Volume entry
- `NetworkListItem.qml` - Network entry
- `ServerOverviewMetric.qml` - Server summary card
- `ServerLegend.qml` - Resource legend
- `EventListItem.qml` - Event entry
- `ContainerSummaryMetric.qml` - Resource summary metric
- `ServerMetric.qml` - Individual metric widget
- `DashboardController.qml` - Navigation controller
- `ResourceItemsPage.qml` - Resource page container
- `DisclosureHeader.qml` - Expandable section header
- `StackListItem.qml` - Stack entry
- `ContainerData.js` - Container data processing

#### `config/`
Configuration page components:

- `ConfigGeneral.qml` - General settings
- `ConfigServers.qml` - Server list and management
- `ServerOverviewLayoutEditor.qml` - Layout editor

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

*List known issues here as they are discovered*

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Add translations if needed
6. Submit a pull request

## License

Dockhub is licensed under the GNU General Public License v3 or later. See the [LICENSE](LICENSE) file for details.
