# Dockhub

A KDE Plasma applet that provides a comprehensive dashboard for managing multiple Docker server instances. Dockhub lets you connect to Docker daemons across different servers, monitor containers, images, networks, volumes, and receive real-time events—all from a single desktop widget.

## Features

### Multi-Server Support
- Connect to multiple Docker servers from different hosts
- Each server can have a custom name for easy identification
- Configure API URL, name, and enable/disable each server independently
- See server health status at a glance (online/offline/unreachable)

### Resource Monitoring
- **Containers**: View running and stopped containers with real-time stats (CPU, memory, block I/O, network I/O)
- **Images**: Inspect Docker images, view labels, environment and image history
- **Networks**: View network configurations, IPAM settings, and attached containers
- **Volumes**: Monitor storage usage and see which containers are using each volume
- **Events**: Real-time event stream from Docker daemon (container lifecycle events, image operations, etc.)

### Actions
- Start/stop/restart containers
- Copy container IDs, names, port mappings, and volume mappings to clipboard
- Search containers by name, image, port, or IP

### Dashboard Overview
- Quick metrics showing running vs. stopped containers per server
- Server information (version, architecture, kernel, OS)
- Disk usage statistics
- At-a-glance health indicators

### Customization
- Configurable dashboard refresh interval
- Choose which metrics to display on the server overview
- Set refresh interval for resource usage statistics
- Select which resource pages to show (stacks, images, networks, volumes, events)

## Requirements

- KDE Plasma 5.x or later
- Qt 5.x with QtQuick/QML support
- Network access to remote Docker API endpoints (if connecting to remote servers)

## Installation

### From KDE Store
1. Open **Discover** (KDE Store)
2. Search for "Dockhub"
3. Click **Install**

### From Source
1. Clone the repository:
```bash
git clone https://github.com/aaryanvangari/dockhub.git
cd dockhub
```

2. Install the applet:
```bash
plasma5-sdk install --install-from-directory contents
```

### Manual Installation
1. Copy the `contents` folder to your Plasma data directory:
```bash
cp -r contents ~/.local/share/plasma/plasmoids/com.opensquares.dockhub/
```

2. Reload the Plasmoid shell or reboot your system

## Usage

### Adding a Server
1. Right-click the applet and select **Configure Dockhub**
2. Go to the **Servers** tab
3. Click **Add Server**
4. Fill in:
   - **Name**: A friendly name for the server (e.g., "Production", "Dev")
   - **Host URL**: The Docker API endpoint (e.g., `http://localhost:2375` or `http://192.168.1.100:2375/v1.41`)
   - **Enabled**: Check to enable the server

### Connecting to Docker
- **Local Docker**: When connecting to `localhost`, Dockhub uses the Docker CLI to access the daemon
- **Remote Docker**: For remote servers, ensure:
  - The Docker API is exposed on the specified port
  - The host is accessible from your machine
  - TLS certificates are configured if the API uses HTTPS

### Using the Dashboard
- **Server List**: Shows all configured servers with status indicators and quick stats
- **Container List**: Searchable list with real-time resource metrics
- **Resource Pages**: Click on a server resource (stacks, images, networks, volumes, events) to view details

## Configuration Options

### General Settings
- **Refresh Dashboard Every**: Set interval (in seconds) for refreshing the main dashboard
- **Refresh Usage Every**: Set interval for updating resource usage statistics
- **Server Overview Columns**: Select which metrics to display on the server summary card

### Server Settings
- **Name**: Custom display name
- **Host URL**: Docker API endpoint
- **Enabled**: Toggle server visibility and data fetching

## Troubleshooting

### Server appears offline or unreachable
- Verify the Docker API is running on the specified host and port
- Check that the host is reachable (ping or network connectivity)
- Ensure no firewall is blocking the Docker API port
- For remote servers, verify TLS certificates if using HTTPS

### Cannot read container stats
- Docker stats require certain privileges
- Ensure Docker is running with appropriate permissions
- Check Docker daemon logs for errors

### Cannot connect to local Docker
- Verify Docker is running: `systemctl status docker`
- Ensure no other process is using port 2375
- Check Docker socket exists: `ls -l /var/run/docker.sock`

### Empty server list
- Go to Settings → Servers tab
- Add a server with a valid URL
- Click the refresh button after adding

## Screenshots

*Coming soon*

## License

Copyright (c) Aaryan Vangari

DockHub is licensed under the **GNU General Public License v3.0 or later**.

See [LICENSE](./LICENSE) for the full license text.

## Support and Bug Reports

For bug reports, feature requests, and questions, visit the [DockHub GitHub Issues](https://github.com/aaryanvangari/dockhub/issues) page.

## Contributing

Contributions are welcome! Please feel free to submit pull requests. Issues and feature requests can be submitted via GitHub issues.

[Developer guide](./DEVELOPMENT.md)

## Credits

- Original idea and implementation by Aaryan Vangari
- Based on KDE Plasma's Plasmoid framework
- Uses QtQuick/QML for UI

## Links

- [KDE Plasma Store](https://apps.kde.org/)
- [KDE Community](https://community.kde.org/)
- [Docker API Documentation](https://docs.docker.com/engine/api/v1.41/)
