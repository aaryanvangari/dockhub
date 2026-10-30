import QtQuick
import "../shared" as Shared
import "../IconNames.js" as IconNames
import "ContainerData.js" as ContainerData
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.plasma.components 3.0 as PlasmaComponents
import org.kde.kirigami as Kirigami

Item {
    id: imageRow
    required property var modelData
    property var controller
    property var clipboard
    property bool labelsExpanded: false
    property bool environmentExpanded: false
    property bool layersExpanded: false
    readonly property bool expanded: controller.expandedImageId === modelData.Id
    readonly property var details: modelData.inspect || ({})
    readonly property var config: details.Config || ({})
    readonly property var labels: {
        const values = config.Labels || {};
        return Object.keys(values).sort().map(function (key) {
            return {
                key: key,
                value: values[key]
            };
        });
    }
    readonly property var environment: (config.Env || []).map(function (entry) {
        const separator = entry.indexOf("=");
        return separator < 0 ? {
            key: entry,
            value: ""
        } : {
            key: entry.slice(0, separator),
            value: entry.slice(separator + 1)
        };
    })
    readonly property var history: modelData.history || []
    readonly property string labelsText: labels.map(function (entry) {
        return entry.key + ": " + entry.value;
    }).join("\n")
    readonly property string environmentText: environment.map(function (entry) {
        return entry.key + "=" + entry.value;
    }).join("\n")
    readonly property string historyText: history.map(function (entry) {
        return Shared.Strings.historyEntry(imageRow.historySize(entry.Size), entry.CreatedBy || "—");
    }).join("\n\n")
    readonly property string imageName: {
        const tags = modelData.RepoTags || [];
        return tags.length && tags[0] !== "<none>:<none>" ? tags[0] : String(modelData.Id || "—").replace(/^sha256:/, "").slice(0, 12);
    }
    readonly property string shortId: String(modelData.Id || "").replace(/^sha256:/, "").slice(0, 12)
    width: ListView.view.width
    implicitHeight: content.implicitHeight + 8

    function historySize(size) {
        return size === undefined || size === null || size === "" || Number(size) === 0 ? "0 B" : ContainerData.formatBytes(size);
    }

    ColumnLayout {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: 8

        Item {
            id: headingRow
            Layout.fillWidth: true
            implicitHeight: heading.implicitHeight + 12
            RowLayout {
                id: heading
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10
                Kirigami.Icon {
                    source: IconNames.image
                    Layout.preferredWidth: 20
                    Layout.preferredHeight: 20
                }
                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    text: imageRow.imageName
                    font.bold: true
                    elide: Text.ElideRight
                }
                Kirigami.Icon {
                    source: imageRow.expanded ? IconNames.collapse : IconNames.expand
                    Layout.preferredWidth: 16
                    Layout.preferredHeight: 16
                }
            }
        }

        RowLayout {
            id: summaryRow
            Layout.fillWidth: true
            spacing: 16
            RowLayout {
                Layout.preferredWidth: (imageRow.width - parent.spacing) / 2
                Layout.minimumWidth: (imageRow.width - parent.spacing) / 2
                Layout.maximumWidth: (imageRow.width - parent.spacing) / 2
                spacing: 6
                Kirigami.Icon {
                    source: IconNames.id
                    Layout.preferredWidth: 16
                    Layout.preferredHeight: 16
                }
                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    text: Shared.Strings.valueLabel(Shared.Strings.idLabel, imageRow.shortId || "—")
                    elide: Text.ElideRight
                }
                PlasmaComponents.ToolButton {
                    icon.name: IconNames.copy
                    display: QQC2.AbstractButton.IconOnly
                    QQC2.ToolTip.text: Shared.Strings.copyFullImageId
                    QQC2.ToolTip.visible: hovered
                    onClicked: clipboard.content = String(modelData.Id || "")
                }
            }
            RowLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: 6
                Kirigami.Icon {
                    source: IconNames.size
                    Layout.preferredWidth: 16
                    Layout.preferredHeight: 16
                }
                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    text: Shared.Strings.valueLabel(Shared.Strings.size, ContainerData.formatBytes(modelData.Size))
                    elide: Text.ElideRight
                }
            }
        }

        ColumnLayout {
            visible: imageRow.expanded
            Layout.fillWidth: true
            spacing: 8
            PlasmaComponents.Label {
                Layout.fillWidth: true
                visible: Boolean(modelData.inspectLoading)
                text: Shared.Strings.loadingImageDetails
            }
            PlasmaComponents.Label {
                Layout.fillWidth: true
                visible: Boolean(modelData.inspectError)
                text: modelData.inspectError || ""
                color: Kirigami.Theme.negativeTextColor
                wrapMode: Text.Wrap
            }

            Rectangle {
                Layout.fillWidth: true
                visible: Boolean(modelData.inspect)
                implicitHeight: overview.implicitHeight + 20
                radius: 7
                color: Kirigami.Theme.alternateBackgroundColor
                ColumnLayout {
                    id: overview
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 10
                    spacing: 6
                    PlasmaComponents.Label {
                        Layout.fillWidth: true
                        text: Shared.Strings.imageInformation
                        font.bold: true
                    }
                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2
                        columnSpacing: 12
                        rowSpacing: 4
                        PlasmaComponents.Label {
                            text: Shared.Strings.fullId
                            opacity: 0.7
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            PlasmaComponents.Label {
                                Layout.fillWidth: true
                                text: details.Id || modelData.Id || "—"
                                elide: Text.ElideMiddle
                            }
                            PlasmaComponents.ToolButton {
                                icon.name: IconNames.copy
                                display: QQC2.AbstractButton.IconOnly
                                QQC2.ToolTip.text: Shared.Strings.copyFullImageId
                                QQC2.ToolTip.visible: hovered
                                onClicked: clipboard.content = String(details.Id || modelData.Id || "")
                            }
                        }
                        PlasmaComponents.Label {
                            text: Shared.Strings.size
                            opacity: 0.7
                        }
                        PlasmaComponents.Label {
                            Layout.fillWidth: true
                            text: ContainerData.formatBytes(details.Size === undefined ? modelData.Size : details.Size)
                        }
                        PlasmaComponents.Label {
                            text: Shared.Strings.created
                            opacity: 0.7
                        }
                        PlasmaComponents.Label {
                            Layout.fillWidth: true
                            text: details.Created || "—"
                            wrapMode: Text.Wrap
                        }
                        PlasmaComponents.Label {
                            text: Shared.Strings.build
                            opacity: 0.7
                        }
                        PlasmaComponents.Label {
                            Layout.fillWidth: true
                            text: details.DockerVersion || "—"
                            wrapMode: Text.Wrap
                        }
                        PlasmaComponents.Label {
                            text: Shared.Strings.command
                            opacity: 0.7
                        }
                        PlasmaComponents.Label {
                            Layout.fillWidth: true
                            text: (config.Cmd || []).join(" ") || "—"
                            wrapMode: Text.Wrap
                        }
                        PlasmaComponents.Label {
                            text: Shared.Strings.entryPoint
                            opacity: 0.7
                        }
                        PlasmaComponents.Label {
                            Layout.fillWidth: true
                            text: (config.Entrypoint || []).join(" ") || "—"
                            wrapMode: Text.Wrap
                        }
                    }
                }
            }

            ColumnLayout {
                visible: Boolean(modelData.inspect)
                Layout.fillWidth: true
                DisclosureHeader {
                    title: Shared.Strings.countTitle(Shared.Strings.labels, labels.length)
                    iconName: IconNames.tag
                    expanded: imageRow.labelsExpanded
                    copyText: imageRow.labelsText
                    clipboard: imageRow.clipboard
                    onToggleRequested: {
                        imageRow.labelsExpanded = !imageRow.labelsExpanded;
                        if (imageRow.labelsExpanded) {
                            imageRow.environmentExpanded = false;
                            imageRow.layersExpanded = false;
                        }
                    }
                }
                Rectangle {
                    Layout.fillWidth: true
                    visible: imageRow.labelsExpanded
                    implicitHeight: labelsContent.implicitHeight + 20
                    radius: 7
                    color: Kirigami.Theme.alternateBackgroundColor
                    ColumnLayout {
                        id: labelsContent
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 10
                        spacing: 4
                        PlasmaComponents.Label {
                            visible: labels.length === 0
                            text: Shared.Strings.noLabels
                        }
                        Repeater {
                            model: labels
                            delegate: ColumnLayout {
                                required property var modelData
                                Layout.fillWidth: true
                                PlasmaComponents.Label {
                                    Layout.fillWidth: true
                                    text: modelData.key
                                    font.bold: true
                                    wrapMode: Text.Wrap
                                }
                                PlasmaComponents.Label {
                                    Layout.fillWidth: true
                                    text: modelData.value
                                    wrapMode: Text.Wrap
                                }
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 1
                                    color: Qt.alpha(Kirigami.Theme.textColor, 0.15)
                                }
                            }
                        }
                    }
                }
            }

            ColumnLayout {
                visible: Boolean(modelData.inspect)
                Layout.fillWidth: true
                DisclosureHeader {
                    title: Shared.Strings.countTitle(Shared.Strings.environment, environment.length)
                    iconName: IconNames.settings
                    expanded: imageRow.environmentExpanded
                    copyText: imageRow.environmentText
                    clipboard: imageRow.clipboard
                    onToggleRequested: {
                        imageRow.environmentExpanded = !imageRow.environmentExpanded;
                        if (imageRow.environmentExpanded) {
                            imageRow.labelsExpanded = false;
                            imageRow.layersExpanded = false;
                        }
                    }
                }
                Rectangle {
                    Layout.fillWidth: true
                    visible: imageRow.environmentExpanded
                    implicitHeight: environmentContent.implicitHeight + 20
                    radius: 7
                    color: Kirigami.Theme.alternateBackgroundColor
                    ColumnLayout {
                        id: environmentContent
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 10
                        spacing: 4
                        PlasmaComponents.Label {
                            visible: environment.length === 0
                            text: Shared.Strings.noEnvironmentVariables
                        }
                        Repeater {
                            model: environment
                            delegate: ColumnLayout {
                                required property var modelData
                                Layout.fillWidth: true
                                PlasmaComponents.Label {
                                    Layout.fillWidth: true
                                    text: modelData.key
                                    font.bold: true
                                    wrapMode: Text.Wrap
                                }
                                PlasmaComponents.Label {
                                    Layout.fillWidth: true
                                    text: modelData.value
                                    wrapMode: Text.Wrap
                                }
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 1
                                    color: Qt.alpha(Kirigami.Theme.textColor, 0.15)
                                }
                            }
                        }
                    }
                }
            }

            ColumnLayout {
                visible: Boolean(modelData.inspect)
                Layout.fillWidth: true
                DisclosureHeader {
                    title: Shared.Strings.countTitle(Shared.Strings.imageHistory, modelData.historyLoading ? "…" : history.length)
                    iconName: IconNames.events
                    expanded: imageRow.layersExpanded
                    copyText: imageRow.historyText
                    clipboard: imageRow.clipboard
                    onToggleRequested: {
                        imageRow.layersExpanded = !imageRow.layersExpanded;
                        if (imageRow.layersExpanded) {
                            imageRow.labelsExpanded = false;
                            imageRow.environmentExpanded = false;
                        }
                    }
                }
                Rectangle {
                    Layout.fillWidth: true
                    visible: imageRow.layersExpanded
                    implicitHeight: historyContent.implicitHeight + 20
                    radius: 7
                    color: Kirigami.Theme.alternateBackgroundColor
                    ColumnLayout {
                        id: historyContent
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 10
                        spacing: 4
                        PlasmaComponents.Label {
                            visible: Boolean(modelData.historyLoading)
                            text: Shared.Strings.loadingImageHistory
                        }
                        PlasmaComponents.Label {
                            visible: Boolean(modelData.historyError)
                            text: modelData.historyError || ""
                            color: Kirigami.Theme.negativeTextColor
                            wrapMode: Text.Wrap
                        }
                        PlasmaComponents.Label {
                            visible: !modelData.historyLoading && !modelData.historyError && history.length === 0
                            text: Shared.Strings.noImageHistory
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12
                            PlasmaComponents.Label {
                                Layout.preferredWidth: historyContent.width * 0.15
                                Layout.minimumWidth: historyContent.width * 0.15
                                Layout.maximumWidth: historyContent.width * 0.15
                                text: Shared.Strings.size
                                font.bold: true
                            }
                            PlasmaComponents.Label {
                                Layout.fillWidth: true
                                text: Shared.Strings.layer
                                font.bold: true
                            }
                        }
                        Repeater {
                            model: history
                            delegate: ColumnLayout {
                                required property var modelData
                                Layout.fillWidth: true
                                spacing: 4
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 12
                                    ColumnLayout {
                                        Layout.preferredWidth: historyContent.width * 0.15
                                        Layout.minimumWidth: historyContent.width * 0.15
                                        Layout.maximumWidth: historyContent.width * 0.15
                                        PlasmaComponents.Label {
                                            Layout.fillWidth: true
                                            text: imageRow.historySize(modelData.Size)
                                            wrapMode: Text.Wrap
                                        }
                                    }
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        Layout.minimumWidth: 0
                                        PlasmaComponents.Label {
                                            Layout.fillWidth: true
                                            text: modelData.CreatedBy || "—"
                                            wrapMode: Text.Wrap
                                        }
                                    }
                                }
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 1
                                    color: Qt.alpha(Kirigami.Theme.textColor, 0.15)
                                }
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Qt.alpha(Kirigami.Theme.textColor, 0.25)
        }
    }

    MouseArea {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: imageRow.expanded ? headingRow.height : headingRow.height + summaryRow.height
        z: -1
        cursorShape: Qt.PointingHandCursor
        onClicked: controller.toggleImageExpanded(modelData)
    }
}
