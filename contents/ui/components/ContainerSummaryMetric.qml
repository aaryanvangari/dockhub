import QtQuick
import "../shared" as Shared
import "../IconNames.js" as IconNames
import QtQuick.Layouts
import org.kde.plasma.components 3.0 as PlasmaComponents
import org.kde.kirigami as Kirigami

RowLayout {
    property int runningCount: 0
    property int totalCount: 0

    Layout.fillWidth: true
    Layout.preferredHeight: 22
    spacing: 4

    Kirigami.Icon {
        source: IconNames.container
        Layout.preferredWidth: 15
        Layout.preferredHeight: 15
    }
    PlasmaComponents.Label {
        text: Shared.Strings.containerSummary(runningCount, totalCount)
        font.pixelSize: 12
        Layout.minimumWidth: 0
        elide: Text.ElideRight
    }
}
