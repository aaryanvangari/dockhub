import QtQuick
import "../shared" as Shared
import "../IconNames.js" as IconNames
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.plasma.components 3.0 as PlasmaComponents
import org.kde.kirigami as Kirigami
import "." as Components
import org.kde.plasma.plasmoid

GridLayout {
    property var summary

    signal resourceSelected(string resource)

    Layout.fillWidth: true
    columns: 3
    rowSpacing: 8
    columnSpacing: 8

    Components.LegendCard {
        Layout.row: 0
        Layout.column: 0
        Layout.preferredWidth: (parent.width - columnSpacing * 2) * 0.3
        iconName: IconNames.stack
        label: Shared.Strings.stacks
        value: summary.stacks
        onActivated: resourceSelected("Stacks")
    }

    Components.LegendCard {
        Layout.row: 1
        Layout.column: 0
        Layout.preferredWidth: (parent.width - columnSpacing * 2) * 0.3
        iconName: IconNames.volume
        label: Shared.Strings.volumes
        value: summary.volumes
        onActivated: resourceSelected("Volumes")
    }

    Components.LegendCard {
        Layout.row: 0
        Layout.column: 1
        Layout.preferredWidth: (parent.width - columnSpacing * 2) * 0.3
        iconName: IconNames.image
        label: Shared.Strings.images
        value: summary.images
        onActivated: resourceSelected("Images")
    }

    Components.LegendCard {
        Layout.row: 1
        Layout.column: 1
        Layout.preferredWidth: (parent.width - columnSpacing * 2) * 0.3
        iconName: IconNames.network
        label: Shared.Strings.networks
        value: summary.networks
        onActivated: resourceSelected("Networks")
    }

    Rectangle {
        id: containersCard

        Layout.row: 0
        Layout.column: 2
        Layout.preferredWidth: (parent.width - columnSpacing * 2) * 0.4
        Layout.minimumWidth: 0
        Layout.fillWidth: true

        radius: 7
        color: Kirigami.Theme.alternateBackgroundColor
        border.color: Qt.alpha(Kirigami.Theme.textColor, 0.2)

        property bool compactLayout: Plasmoid.configuration.compactLayout
        property bool manuallyExpanded: false
        property bool showDetails: !compactLayout || manuallyExpanded

        // Let the content determine the card height.
        implicitHeight: containersLegend.implicitHeight + 16

        // Reset temporary expansion when the layout setting changes.
        onCompactLayoutChanged: manuallyExpanded = false

        ColumnLayout {
            id: containersLegend

            anchors.fill: parent
            anchors.margins: 8
            spacing: 5

            // Container heading
            RowLayout {
                id: containersHeader

                Layout.fillWidth: true
                spacing: 8

                HoverHandler {
                    enabled: containersCard.compactLayout
                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    enabled: containersCard.compactLayout

                    onTapped: {
                        containersCard.manuallyExpanded =
                                !containersCard.manuallyExpanded
                    }
                }

                Kirigami.Icon {
                    source: IconNames.container
                    Layout.preferredWidth: 20
                    Layout.preferredHeight: 20
                }

                PlasmaComponents.Label {
                    text: Shared.Strings.containersLabel
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    elide: Text.ElideRight
                    font.pixelSize: 16
                }

                PlasmaComponents.Label {
                    text: String(summary.containers)
                    font.bold: true
                    font.pixelSize: 16
                }

                Kirigami.Icon {
                    visible: containersCard.compactLayout

                    source: containersCard.manuallyExpanded
                            ? "arrow-up"
                            : "arrow-down"

                    Layout.preferredWidth: 16
                    Layout.preferredHeight: 16
                    opacity: 0.7
                }
            }

            // Container status counts
            RowLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0

                visible: containersCard.showDetails

                spacing: Math.max(
                    2,
                    Math.min(7, containersLegend.width / 60)
                )

                Repeater {
                    model: [
                        {
                            icon: IconNames.containerStart,
                            count: summary.running,
                            label: Shared.Strings.runningUpper
                        },
                        {
                            icon: IconNames.containerStop,
                            count: summary.stopped,
                            label: Shared.Strings.stopped
                        },
                        {
                            icon: IconNames.legendHealthy,
                            count: summary.healthy,
                            label: Shared.Strings.healthy
                        },
                        {
                            icon: IconNames.legendUnhealthy,
                            count: summary.unhealthy,
                            label: Shared.Strings.unhealthy
                        }
                    ]

                    delegate: RowLayout {
                        required property var modelData

                        Layout.minimumWidth: 0

                        spacing: Math.max(
                            1,
                            Math.min(4, containersLegend.width / 55)
                        )

                        Kirigami.Icon {
                            source: modelData.icon

                            Layout.preferredWidth: Math.max(
                                12,
                                Math.min(18, containersLegend.width / 6)
                            )

                            Layout.preferredHeight: Math.max(
                                12,
                                Math.min(18, containersLegend.width / 6)
                            )

                            Layout.minimumWidth: 0
                            Layout.minimumHeight: 0

                            color: modelData.label === Shared.Strings.runningUpper ||
                                   modelData.label === Shared.Strings.healthy
                                   ? Kirigami.Theme.positiveTextColor
                                   : (modelData.label === Shared.Strings.stopped ||
                                      modelData.label === Shared.Strings.unhealthy
                                      ? Kirigami.Theme.negativeTextColor
                                      : Kirigami.Theme.textColor)

                            Accessible.name: modelData.label
                        }

                        PlasmaComponents.Label {
                            text: String(modelData.count)

                            Layout.minimumWidth: 0

                            font.pixelSize: Math.max(
                                9,
                                Math.min(14, containersLegend.width / 16)
                            )

                            font.bold: true

                            color: modelData.label === Shared.Strings.stopped ||
                                   modelData.label === Shared.Strings.unhealthy
                                   ? Kirigami.Theme.negativeTextColor
                                   : (modelData.label === Shared.Strings.healthy
                                      ? Kirigami.Theme.positiveTextColor
                                      : Kirigami.Theme.textColor)
                        }
                    }
                }
            }
        }
    }

    Components.LegendCard {
        Layout.row: 1
        Layout.column: 2
        Layout.preferredWidth: (parent.width - columnSpacing * 2) * 0.4
        iconName: IconNames.events
        label: Shared.Strings.events24h
        value: summary.events
        onActivated: resourceSelected("Events")
    }
}