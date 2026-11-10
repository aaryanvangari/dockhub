import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.plasma.components 3.0 as PlasmaComponents
import org.kde.kirigami as Kirigami
import "../DockerApi.js" as DockerApi

ColumnLayout {
    id: logsPage

    property var server: null
    property string containerId: ""
    property string containerName: ""
    property var unixSocketBridge
    property var configuration
    property bool active: false

    property bool followOutput: true
    property string logText: ""
    property string logStreamError: ""
    property string activeLogStreamId: ""
    property string pendingLogText: ""
    property int streamGeneration: 0

    Layout.fillWidth: true
    Layout.fillHeight: true
    spacing: 6

    function appendLogText(text) {
        if (!active || text === undefined || text === null || text === "")
            return;

        pendingLogText += String(text);

        if (!logUpdateTimer.running)
            logUpdateTimer.start();
    }

    function flushPendingLogs() {
        if (pendingLogText === "")
            return;

        const incoming = pendingLogText;
        pendingLogText = "";

        let updated = logText + incoming;

        if (updated.length > 250000)
            updated = updated.slice(-250000);

        logText = updated;
    }

    function stopLogStream() {
        ++streamGeneration;

        const requestId = activeLogStreamId;
        activeLogStreamId = "";

        logUpdateTimer.stop();
        pendingLogText = "";

        if (requestId && unixSocketBridge)
            DockerApi.stopContainerLogs(unixSocketBridge, requestId);
    }

    function startLogStream() {
        if (!active || !server || !containerId || !unixSocketBridge)
            return;

        stopLogStream();

        logText = "";
        logStreamError = "";
        followOutput = true;

        const streamServer = server;
        const streamServerUrl = String(server.url || "");
        const streamContainerId = containerId;
        const generation = streamGeneration;

        let requestId = "";

        requestId = DockerApi.streamContainerLogs(
            streamServer,
            streamContainerId,
            unixSocketBridge,

            function(entry) {
                if (!logsPage.active ||
                    logsPage.streamGeneration !== generation ||
                    logsPage.containerId !== streamContainerId ||
                    !logsPage.server ||
                    String(logsPage.server.url || "") !== streamServerUrl) {
                    return;
                }

                if (entry && entry.data !== undefined)
                    logsPage.appendLogText(entry.data);
            },

            function(result) {
                if (logsPage.streamGeneration !== generation ||
                    !logsPage.active ||
                    logsPage.containerId !== streamContainerId ||
                    !logsPage.server ||
                    String(logsPage.server.url || "") !== streamServerUrl) {
                    return;
                }

                logsPage.activeLogStreamId = "";

                if (!result || !result.success) {
                    logsPage.logStreamError =
                            (result && result.error) ||
                            "Log stream ended unexpectedly";
                }
            }
        );

        if (requestId) {
            activeLogStreamId = requestId;
        } else {
            logStreamError = "Could not start container log stream";
        }
    }

    onActiveChanged: {
        if (active)
            startLogStream();
        else {
            stopLogStream();
            logText = "";
            logStreamError = "";
        }
    }

    onServerChanged: {
        if (active)
            startLogStream();
    }

    onContainerIdChanged: {
        if (active)
            startLogStream();
    }

    Timer {
        id: logUpdateTimer
        interval: 50
        repeat: false
        onTriggered: logsPage.flushPendingLogs()
    }

    PlasmaComponents.Label {
        Layout.fillWidth: true
        visible: logsPage.logStreamError !== ""
        text: logsPage.logStreamError
        color: Kirigami.Theme.negativeTextColor
        wrapMode: Text.Wrap
    }

    Rectangle {
        id: logPanel

        Layout.fillWidth: true
        Layout.fillHeight: true

        radius: 6
        color: Kirigami.Theme.alternateBackgroundColor
        border.width: 1
        border.color: Qt.alpha(Kirigami.Theme.textColor, 0.15)

        clip: true

        Flickable {
            id: logFlickable

            anchors.fill: parent
            anchors.margins: 1

            clip: true
            contentWidth: width
            contentHeight: logOutput.implicitHeight

            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.VerticalFlick

            QQC2.ScrollBar.vertical: QQC2.ScrollBar {
                id: logScrollBar

                policy: QQC2.ScrollBar.AsNeeded
            }

            TextEdit {
                id: logOutput

                width: logFlickable.width - 10

                readOnly: true
                selectByMouse: true
                text: logsPage.logText

                font.family: "monospace"

                font.pixelSize: {
                    const size = logsPage.configuration
                                 ? logsPage.configuration.logSize : 1;

                    switch (size) {
                    case 0: return 10;
                    case 1: return 12;
                    case 2: return 14;
                    case 3: return 16;
                    default: return 12;
                    }
                }

                color: Kirigami.Theme.textColor
                wrapMode: TextEdit.WrapAnywhere
                selectByKeyboard: true
                padding: 8

                onTextChanged: {
                    if (logsPage.followOutput) {
                        Qt.callLater(function() {
                            logFlickable.contentY = Math.max(
                                0,
                                logFlickable.contentHeight -
                                logFlickable.height
                            );
                        });
                    }
                }
            }

            onMovementEnded: {
                const distanceFromBottom =
                        contentHeight - (contentY + height);

                logsPage.followOutput = distanceFromBottom <= 24;
            }

            onContentHeightChanged: {
                if (logsPage.followOutput) {
                    Qt.callLater(function() {
                        logFlickable.contentY = Math.max(
                            0,
                            logFlickable.contentHeight -
                            logFlickable.height
                        );
                    });
                }
            }
        }

        PlasmaComponents.Label {
            anchors.centerIn: parent

            visible: logsPage.logText === "" &&
                     logsPage.logStreamError === ""

            text: "Waiting for container logs..."
            opacity: 0.7
        }
    }

    Component.onDestruction: stopLogStream()
}