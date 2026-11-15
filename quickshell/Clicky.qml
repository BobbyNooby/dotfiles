// A rounded clickable area: lights up on hover, emits clicked(mouse) and scrolled(wheel).
// Put its content inside (it's a plain Rectangle, so lay things out with anchors or layouts).
import QtQuick

Rectangle {
    id: btn
    signal clicked(var mouse)
    signal scrolled(var wheel)
    property color base: "transparent"
    property color hoverColor: Theme.alpha(Theme.text, 0.08)
    property bool active: true
    readonly property bool hovered: area.containsMouse
    radius: Theme.r(10)
    color: area.containsMouse && active ? (base.a > 0 ? Qt.lighter(base, 1.12) : hoverColor) : base
    Behavior on color { ColorAnimation { duration: 140 } }

    MouseArea {
        id: area
        z: -1 // under the content, so buttons inside a button get their own clicks
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: btn.active ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: mouse => { if (btn.active) btn.clicked(mouse) }
        onWheel: wheel => btn.scrolled(wheel)
    }
}
