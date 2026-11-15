// An on/off switch: a rounded track with a knob. `small` is the 36×20 one on the tiles.
import QtQuick

Rectangle {
    id: sw
    property bool on: false
    property bool small: false
    property color onTrack: Theme.accent
    property color onKnob: Theme.textOnAccent
    implicitWidth: small ? 36 : 44
    implicitHeight: small ? 20 : 24
    radius: height / 2
    color: on ? onTrack : Theme.border
    Behavior on color { ColorAnimation { duration: 160 } }
    Rectangle {
        readonly property int pad: sw.small ? 3 : 4
        width: sw.height - 2 * pad
        height: width
        radius: width / 2
        y: pad
        x: sw.on ? sw.width - width - pad : pad
        color: sw.on ? sw.onKnob : Theme.outline
        Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
    }
}
