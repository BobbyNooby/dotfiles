// A Quick settings tile: icon, name, state. Click switches it; when `popup` is set, a › on the
// right emits more(), to open that thing's full popup.
import QtQuick
import QtQuick.Layouts

Clicky {
    id: tile
    property string icon
    property string title
    property string status
    property bool on
    property string popup: ""
    signal more()
    Layout.fillWidth: true
    Layout.preferredWidth: 1
    implicitHeight: 64
    radius: Theme.r(18)
    base: on ? Theme.accentSoft : Theme.bgHigh
    readonly property color fg: on ? Theme.textOnSoft : Theme.text
    RowLayout {
        anchors { fill: parent; leftMargin: 14; rightMargin: 4 }
        spacing: 10
        Icon { name: tile.icon; size: 20; color: tile.fg }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1
            Txt { Layout.fillWidth: true; text: tile.title; font.weight: Font.DemiBold; color: tile.fg; elide: Text.ElideRight }
            Txt { Layout.fillWidth: true; text: tile.status; font.pixelSize: 11; color: tile.fg; opacity: 0.8; elide: Text.ElideRight }
        }
        Clicky {
            visible: tile.popup !== ""
            implicitWidth: 28
            implicitHeight: 44
            radius: Theme.r(10)
            onClicked: tile.more()
            Icon { anchors.centerIn: parent; name: "chevron"; size: 14; stroke: 2.2; color: tile.fg }
        }
    }
}
