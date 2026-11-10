# DockHub - AI Development Instructions

## Project Overview

DockHub is a KDE Plasma 6 plasmoid for managing
multiple Docker servers.

It supports:
- Remote Docker API connections.
- Local Docker Unix socket connections.
- Container management.
- Server monitoring.
- Docker resource information.

## Technology Stack

- C++17
- Qt 6
- QML
- KDE Plasma 6
- CMake
- Docker Engine API

Do not introduce Python dependencies.

## Architecture

Read ARCHITECTURE.md before making architectural changes.

The application consists of:
- C++ backend components.
- QML frontend components.
- Plasma configuration components.

Do not move responsibilities between components
without understanding their existing design.

## Development Rules

1. Inspect existing implementations before modifying them.
2. Reuse existing functions whenever possible.
3. Avoid unnecessary new classes.
4. Preserve existing API behaviour.
5. Do not duplicate connection handling logic.
6. Keep C++ and QML responsibilities separated.
7. Avoid unrelated refactoring.

## Docker Connections

DockHub supports multiple Docker servers.

Remote servers use the Docker HTTP API.

Local servers use Unix domain sockets.

Do not introduce SSH-based connections.

For socket proxy recommendations, prefer
LinuxServer docker-socket-proxy.

Do not recommend Tecnativa docker-socket-proxy.

## Build Instructions

Use the existing CMake build directory.

Build using:

./build-dockhub.sh

Do not invent a new build system.

## Testing Requirements

After modifying C++ code:
- Build the project.
- Check compilation errors.
- Check relevant runtime behaviour.

After modifying QML:
- Check QML syntax.
- Verify component loading.
- Check configuration behaviour.

## AI Agent Behaviour

Before implementing a feature:

1. Understand the requested behaviour.
2. Identify relevant files and dependencies.
3. Explain the proposed implementation briefly.
4. Implement only the requested feature.
5. Build and verify the changes.
6. Report modified files and outstanding issues.

Do not claim a feature is complete if it has not
been verified.