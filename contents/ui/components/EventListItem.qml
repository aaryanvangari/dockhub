import QtQuick
import "../shared" as Shared
import QtQuick.Layouts
import org.kde.plasma.components 3.0 as PlasmaComponents
import org.kde.kirigami as Kirigami

Item {
    id: eventRow
    required property var modelData
    width: ListView.view.width
    implicitHeight: eventContent.implicitHeight + 16

    readonly property string detailsText: {
        const action = modelData.Action || modelData.action;
        if (action)
            return Shared.Strings.action + ": " + action;
        const status = modelData.status || modelData.Status;
        return status ? Shared.Strings.status + ": " + status : "—";
    }
    readonly property string dateText: {
        let timestamp = Number(modelData.time || modelData.Time || 0);
        if (!timestamp && modelData.timeNano)
            timestamp = Number(modelData.timeNano) / 1000000000;
        return timestamp > 0 ? Qt.formatDateTime(new Date(timestamp * 1000), "yyyy-MM-dd hh:mm:ss") : "—";
    }

    ColumnLayout {
        id: eventContent
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 8
        spacing: 4
        RowLayout {
            Layout.fillWidth: true
            PlasmaComponents.Label {
                Layout.fillWidth: true
                text: eventRow.dateText
                font.bold: true
                elide: Text.ElideRight
            }
            PlasmaComponents.Label {
                text: modelData.Type || modelData.type || "—"
                horizontalAlignment: Text.AlignRight
                opacity: 0.8
            }
        }
        PlasmaComponents.Label {
            Layout.fillWidth: true
            text: eventRow.detailsText
            wrapMode: Text.Wrap
        }
    }
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: Qt.alpha(Kirigami.Theme.textColor, 0.25)
    }
}
