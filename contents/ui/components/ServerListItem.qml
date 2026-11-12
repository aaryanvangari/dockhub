import QtQuick
import "../shared" as Shared
import "../IconNames.js" as IconNames
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.plasma.components 3.0 as PlasmaComponents
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami
import "." as Components

QQC2.ItemDelegate {
    id: delegateRoot
    property var controller
    required property var modelData
    width: ListView.view.width
    padding: 0
    background: Rectangle {
        color: delegateRoot.hovered ? Qt.alpha(Kirigami.Theme.highlightColor, 0.12) : Kirigami.Theme.backgroundColor
        border.color: delegateRoot.hovered ? Kirigami.Theme.highlightColor : Qt.alpha(Kirigami.Theme.textColor, 0.2)
        border.width: 1
        radius: 8
    }
    onClicked: controller.openServer(modelData)

    contentItem: Item {
        implicitHeight: serverEntryContent.implicitHeight + 20
        ColumnLayout {
            id: serverEntryContent
            x: 10
            y: 10
            width: Math.max(0, parent.width - 20)
            spacing: 2

            RowLayout {
                Layout.fillWidth: true
                Kirigami.Icon {
                    source: modelData.online ? IconNames.serverConnected : IconNames.serverDisconnected
                    Layout.preferredWidth: 20
                    Layout.preferredHeight: 20
                    color: modelData.online ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.negativeTextColor
                }
                PlasmaComponents.Label {
                    text: modelData.name
                    font.bold: true
                    font.pixelSize: 16
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }
                Kirigami.Icon {
                    source: IconNames.next
                    Layout.preferredWidth: 16
                    Layout.preferredHeight: 16
                }
            }

            Components.IconsLayout {
                modelData: delegateRoot.modelData
                visible: Number(Plasmoid.configuration.serverLayout) === 0
            }
            
            Components.TwoColumnLayout {
                modelData: delegateRoot.modelData
                visible: Number(Plasmoid.configuration.serverLayout) === 1
            }
            
            Components.ThreeColumnLayout {
                modelData: delegateRoot.modelData
                visible: Number(Plasmoid.configuration.serverLayout) === 2
            }

            PlasmaComponents.Label {
                visible: !modelData.online
                text: Shared.Strings.offlineOrUnreachable
                opacity: 0.75
                font.pixelSize: 12
            }
        }
    }
}
