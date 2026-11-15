// A row inside a SetCard: icon (optional), label and a dimmer line under it, and whatever you
// put inside on the right (a Toggle, buttons, a value). `toggle: true` adds a switch that
// emits switched(); clicking the row does the same.
import QtQuick
import QtQuick.Layouts

Clicky {
    id: row
    property string icon
    property string label
    property string sub
    property color fg: Theme.text
    property bool toggle: false
    property bool on: false
    property bool highlight: false
    default property alias trailing: tail.data
    signal switched()
    Layout.fillWidth: true
    implicitHeight: Math.max(52, body.implicitHeight + 18)
    radius: Theme.r(14)
    base: highlight ? Theme.accentSoft : "transparent"
    active: toggle
    hoverColor: toggle ? Theme.alpha(Theme.text, 0.06) : "transparent"
    onClicked: if (toggle) switched()
    readonly property color ink: highlight ? Theme.textOnSoft : fg

    RowLayout {
        id: body
        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 12; rightMargin: 10 }
        spacing: 12
        Icon { visible: row.icon !== ""; name: row.icon; size: 18; color: row.highlight ? row.ink : Theme.textDim }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1
            Txt { Layout.fillWidth: true; text: row.label; font.pixelSize: 14; font.weight: Font.DemiBold; color: row.ink; elide: Text.ElideRight }
            Txt { visible: row.sub !== ""; Layout.fillWidth: true; text: row.sub; font.pixelSize: 12; color: row.ink; opacity: 0.75; elide: Text.ElideRight }
        }
        RowLayout { id: tail; spacing: 6; Layout.fillWidth: false } // (layouts fill by default)
        Toggle { visible: row.toggle; on: row.on }
    }
}
