import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components 3.0 as PlasmaComponents
import org.kde.kirigami as Kirigami

Rectangle {
    property string iconName
    property string label
    property var value
    signal activated

    Layout.fillWidth: true
    implicitHeight: 54
    radius: 7
    color: Kirigami.Theme.alternateBackgroundColor
    border.color: Qt.alpha(Kirigami.Theme.textColor, 0.2)

    RowLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 5
        Kirigami.Icon {
            source: iconName
            Layout.preferredWidth: 20
            Layout.preferredHeight: 20
        }
        PlasmaComponents.Label {
            text: label
            Layout.fillWidth: true
            elide: Text.ElideRight
            font.pixelSize: 16
        }
        PlasmaComponents.Label {
            text: String(value)
            font.bold: true
            font.pixelSize: 16
        }
    }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: parent.activated()
    }
}
