import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

ColumnLayout {
    id: editor

    property int columns: 2
    property string layoutJson: ""
    signal layoutEdited(string json)

    readonly property var metrics: [
        { key: "os", label: i18n("OS") },
        { key: "kernel", label: i18n("Kernel") },
        { key: "cores", label: i18n("Cores") },
        { key: "totalMemory", label: i18n("Total Memory") },
        { key: "containers", label: i18n("Containers") },
        { key: "nodes", label: i18n("Nodes") },
        { key: "arch", label: i18n("Arch") },
        { key: "images", label: i18n("Images") },
        { key: "volumes", label: i18n("Volumes") },
        { key: "rootDir", label: i18n("Root Dir") },
        { key: "socket", label: i18n("Socket") },
        { key: "server", label: i18n("Server") },
        { key: "api", label: i18n("API") },
        { key: "minApi", label: i18n("Min API") }
    ]
    readonly property string availableTitle: i18n("Available labels")
    readonly property string columnTitle: i18n("Column %1")

    function defaultLayout() {
        return {
            "2": [["os", "kernel", "rootDir", "socket", "server", "api", "minApi"], ["cores", "arch", "nodes", "totalMemory", "images", "volumes", "containers"]],
            "3": [["os", "kernel", "totalMemory", "rootDir", "socket"], ["server", "api", "minApi", "cores", "images"], ["nodes", "arch", "volumes", "containers"]]
        };
    }

    function parsedLayout() {
        try {
            const parsed = JSON.parse(layoutJson || "{}");
            const fallback = defaultLayout();
            if (!Array.isArray(parsed["2"]) || parsed["2"].length !== 2)
                parsed["2"] = fallback["2"];
            if (!Array.isArray(parsed["3"]) || parsed["3"].length !== 3)
                parsed["3"] = fallback["3"];
            return parsed;
        } catch (error) {
            return defaultLayout();
        }
    }

    function activeColumns() {
        return parsedLayout()[String(columns)] || defaultLayout()[String(columns)];
    }

    function labelsForColumn(columnIndex) {
        const layout = activeColumns();
        return layout[columnIndex] || [];
    }

    function availableMetrics() {
        const assigned = [];
        const columnsData = activeColumns();
        for (let i = 0; i < columnsData.length; ++i)
            for (let j = 0; j < columnsData[i].length; ++j)
                assigned.push(columnsData[i][j]);
        return metrics.filter(function (metric) {
            return assigned.indexOf(metric.key) < 0;
        });
    }

    function metricLabel(key) {
        for (let i = 0; i < metrics.length; ++i)
            if (metrics[i].key === key)
                return metrics[i].label;
        return key;
    }

    function placeMetric(key, destination) {
        const layout = parsedLayout();
        const current = layout[String(columns)];
        for (let i = 0; i < current.length; ++i)
            current[i] = current[i].filter(function (entry) {
                return entry !== key;
            });
        current[destination].push(key);
        layoutEdited(JSON.stringify(layout));
    }

    function removeMetric(key) {
        const layout = parsedLayout();
        const current = layout[String(columns)];
        for (let i = 0; i < current.length; ++i)
            current[i] = current[i].filter(function (entry) {
                return entry !== key;
            });
        layoutEdited(JSON.stringify(layout));
    }

    Flow {
        id: availablePool
        Layout.fillWidth: true
        spacing: Kirigami.Units.smallSpacing

        DropArea {
            anchors.fill: parent
            keys: ["server-overview-metric"]
            onDropped: function (drop) {
                if (drop.source && drop.source.metricKey)
                    editor.removeMetric(drop.source.metricKey);
            }
        }

        Repeater {
            model: editor.columns

            delegate: Rectangle {
                id: metricColumn
                required property int index
                property int columnIndex: index
                Layout.fillWidth: true
                Layout.minimumWidth: 120
                Layout.preferredWidth: 1
                implicitHeight: columnContents.implicitHeight + 20
                radius: Kirigami.Units.cornerRadius
                color: Kirigami.Theme.alternateBackgroundColor
                border.width: 1
                border.color: dropArea.containsDrag ? Kirigami.Theme.highlightColor : Qt.alpha(Kirigami.Theme.textColor, 0.2)

                DropArea {
                    id: dropArea
                    anchors.fill: parent
                    keys: ["server-overview-metric"]
                    onDropped: function (drop) {
                        if (drop.source && drop.source.metricKey)
                            editor.placeMetric(drop.source.metricKey, metricColumn.columnIndex);
                    }
                }

                ColumnLayout {
                    id: columnContents
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: Kirigami.Units.smallSpacing

                    QQC2.Label {
                        text: editor.columnTitle.arg(metricColumn.columnIndex + 1)
                        font.bold: true
                    }

                    Repeater {
                        model: editor.labelsForColumn(metricColumn.columnIndex)

                        delegate: Rectangle {
                            required property string modelData
                            property string metricKey: modelData
                            Layout.fillWidth: true
                            implicitHeight: chipLabel.implicitHeight + 12
                            radius: Kirigami.Units.smallSpacing
                            color: Kirigami.Theme.backgroundColor
                            border.width: 1
                            border.color: Qt.alpha(Kirigami.Theme.textColor, 0.15)
                            Drag.active: chipMouse.drag.active
                            Drag.keys: ["server-overview-metric"]
                            Drag.hotSpot.x: width / 2
                            Drag.hotSpot.y: height / 2

                            QQC2.Label {
                                id: chipLabel
                                anchors.fill: parent
                                anchors.margins: 6
                                text: editor.metricLabel(parent.metricKey)
                                elide: Text.ElideRight
                            }
                            MouseArea {
                                id: chipMouse
                                anchors.fill: parent
                                drag.target: null
                            }
                        }
                    }
                }
            }
        }
    }

    QQC2.Label {
        text: editor.availableTitle
        font.bold: true
        Layout.topMargin: Kirigami.Units.smallSpacing
    }

    Flow {
        Layout.fillWidth: true
        spacing: Kirigami.Units.smallSpacing

        Repeater {
            model: editor.availableMetrics()

            delegate: Rectangle {
                required property var modelData
                property string metricKey: modelData.key
                implicitWidth: poolChipLabel.implicitWidth + 20
                implicitHeight: poolChipLabel.implicitHeight + 12
                radius: Kirigami.Units.smallSpacing
                color: Kirigami.Theme.alternateBackgroundColor
                border.width: 1
                border.color: Qt.alpha(Kirigami.Theme.textColor, 0.2)
                z: 2
                Drag.active: poolChipMouse.drag.active
                Drag.keys: ["server-overview-metric"]
                Drag.hotSpot.x: width / 2
                Drag.hotSpot.y: height / 2

                QQC2.Label {
                    id: poolChipLabel
                    anchors.centerIn: parent
                    text: editor.metricLabel(parent.metricKey)
                }
                MouseArea {
                    id: poolChipMouse
                    anchors.fill: parent
                    drag.target: null
                }
            }
        }
    }
}
