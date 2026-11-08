import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.plasma.components 3.0 as PlasmaComponents
import org.kde.kirigami as Kirigami

ColumnLayout {
    id: logsPage

    property var controller

    Layout.fillWidth: true
    Layout.fillHeight: true
    spacing: 6

    property bool followOutput: true

    PlasmaComponents.Label {
        Layout.fillWidth: true
        visible: controller.logStreamError !== ""
        text: controller.logStreamError
        color: Kirigami.Theme.negativeTextColor
        wrapMode: Text.Wrap
    }

    Item {
        Layout.fillWidth: true
        Layout.fillHeight: true

        Flickable {
            id: logFlickable

            anchors.fill: parent
            clip: true

            contentWidth: width
            contentHeight: logOutput.implicitHeight

            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.VerticalFlick

            QQC2.ScrollBar.vertical: QQC2.ScrollBar {}

            TextEdit {
                id: logOutput

                width: logFlickable.width
                readOnly: true
                selectByMouse: true

                text: controller.logText || ""

                font.family: "monospace"
                font.pixelSize: {
                    switch (controller.configuration.logSize) {
                    case 0: return 10;  // Smaller
                    case 1: return 12;  // Small
                    case 2: return 14;  // Medium
                    case 3: return 16;  // Large
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
            visible: controller.logText === "" &&
                     controller.logStreamError === ""
            text: "Waiting for container logs..."
            opacity: 0.7
        }
    }
}