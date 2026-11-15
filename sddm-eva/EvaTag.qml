// A neon label: rounded outline, glowing text, an optional Japanese word in front.
import QtQuick
import QtQuick.Effects

Rectangle {
    id: tag
    property string text
    property string jp: ""
    property color tint: "#ff8a1e"
    property int size: 18
    property bool round: false
    property color fill: "transparent"
    property real halo: 1
    implicitWidth: row.implicitWidth + 20
    implicitHeight: row.implicitHeight + 2
    radius: round ? 9 : 7
    color: fill
    border.color: tint
    border.width: 2
    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6
        Text { visible: tag.jp !== ""; anchors.verticalCenter: parent.verticalCenter; text: tag.jp; color: tag.tint; font.family: "Shippori Mincho B1"; font.weight: Font.ExtraBold; font.pixelSize: Math.round(tag.size * 0.82) }
        Text { anchors.verticalCenter: parent.verticalCenter; text: tag.text.toUpperCase(); color: tag.tint; font.family: "TeX Gyre Heros Cn"; font.bold: true; font.pixelSize: tag.size }
    }
    layer.enabled: halo > 0
    layer.effect: MultiEffect { shadowEnabled: true; shadowColor: tag.tint; shadowBlur: 0.5 * tag.halo; shadowOpacity: 0.9; shadowHorizontalOffset: 0; shadowVerticalOffset: 0 }
}
