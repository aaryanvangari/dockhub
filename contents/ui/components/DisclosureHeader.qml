import QtQuick
import "../shared" as Shared
import "../IconNames.js" as IconNames
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.plasma.components 3.0 as PlasmaComponents
import org.kde.kirigami as Kirigami

Rectangle {
    id: header
    property string title
    property string iconName
    property bool expanded: false
    property string copyText: ""
    property var clipboard
    signal toggleRequested
    Layout.fillWidth: true
    implicitHeight: 50
    radius: 7
    color: Kirigami.Theme.alternateBackgroundColor
    border.color: Qt.alpha(Kirigami.Theme.textColor, 0.2)

    RowLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 8
        Kirigami.Icon {
            source: header.iconName
            Layout.preferredWidth: 20
            Layout.preferredHeight: 20
        }
        PlasmaComponents.Label {
            Layout.fillWidth: true
            text: header.title
            font.pixelSize: 15
            elide: Text.ElideRight
        }
        PlasmaComponents.ToolButton {
            icon.name: IconNames.copy
            display: QQC2.AbstractButton.IconOnly
            QQC2.ToolTip.text: Shared.Strings.copySection(header.title)
            QQC2.ToolTip.visible: hovered
            enabled: header.copyText !== ""
            onClicked: header.clipboard.content = header.copyText
        }
        Kirigami.Icon {
            source: header.expanded ? IconNames.collapse : IconNames.expand
            Layout.preferredWidth: 16
            Layout.preferredHeight: 16
        }
    }
    MouseArea {
        anchors.fill: parent
        z: -1
        cursorShape: Qt.PointingHandCursor
        onClicked: header.toggleRequested()
    }
}
