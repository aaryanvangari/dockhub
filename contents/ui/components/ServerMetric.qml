import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.plasma.components 3.0 as PlasmaComponents
import org.kde.kirigami as Kirigami

RowLayout {
    property string iconName
    property string metricText
    property int iconSize: 15
    property int textPixelSize: 13
    property int rowSpacing: 4
    property bool tooltipEnabled: false

    Layout.fillWidth: true
    Layout.minimumWidth: 0
    Layout.preferredHeight: 22
    spacing: rowSpacing

    Kirigami.Icon {
        source: iconName
        Layout.preferredWidth: iconSize
        Layout.preferredHeight: iconSize
    }
    PlasmaComponents.Label {
        id: metricLabel
        text: metricText
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        font.pixelSize: textPixelSize
        elide: Text.ElideRight
        HoverHandler {
            id: metricHover
        }
        QQC2.ToolTip.text: metricText
        QQC2.ToolTip.visible: tooltipEnabled && metricHover.hovered
    }
}
