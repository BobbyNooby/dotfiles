// A slider row (Quick settings): icon (click = iconClicked, e.g. mute), the bar, the %.
// The wheel nudges it by 5 %.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

RowLayout {
    id: lvl
    property string icon
    property real value
    property bool dim: false
    signal moved(real v)
    signal iconClicked()
    Layout.fillWidth: true
    spacing: 10
    Clicky {
        implicitWidth: 40
        implicitHeight: 40
        radius: Theme.r(12)
        onClicked: lvl.iconClicked()
        Icon { anchors.centerIn: parent; name: lvl.icon; size: 18; color: lvl.dim ? Theme.textDim : Theme.text }
    }
    Slider {
        id: sl
        Layout.fillWidth: true
        from: 0
        to: 1
        value: lvl.value
        onMoved: lvl.moved(value)
        background: Rectangle {
            x: sl.leftPadding
            y: sl.topPadding + sl.availableHeight / 2 - height / 2
            width: sl.availableWidth
            height: 8
            radius: 4
            color: Theme.bgHighest
            Rectangle { width: sl.visualPosition * parent.width; height: parent.height; radius: 4; color: lvl.dim ? Theme.outline : Theme.accent }
        }
        handle: Rectangle {
            x: sl.leftPadding + sl.visualPosition * (sl.availableWidth - width)
            y: sl.topPadding + sl.availableHeight / 2 - height / 2
            width: 18
            height: 18
            radius: 9
            color: lvl.dim ? Theme.outline : Theme.accent
        }
        WheelHandler { onWheel: e => lvl.moved(Math.max(0, Math.min(1, lvl.value + (e.angleDelta.y > 0 ? 0.05 : -0.05)))) }
    }
    Txt { Layout.preferredWidth: 38; horizontalAlignment: Text.AlignRight; text: Math.round(lvl.value * 100) + "%"; font.pixelSize: 12; color: Theme.textDim }
}
