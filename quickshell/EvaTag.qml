// A neon label from the Eva lock screen: rounded outline, glowing text, an optional Japanese
// word in front ("時刻 LOCAL TIME"). `fill` gives it a solid background (to sit over lines).
import QtQuick
import QtQuick.Effects

Rectangle {
    id: tag
    property string text
    property string jp: ""
    property color tint: EvaStyle.orange
    property int size: 18
    property bool round: false // the cyan "pill" style (radius 9 instead of 7)
    property color fill: "transparent"
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
        Text { visible: tag.jp !== ""; anchors.verticalCenter: parent.verticalCenter; text: tag.jp; color: tag.tint; font.family: EvaStyle.jp; font.weight: Font.ExtraBold; font.pixelSize: Math.round(tag.size * 0.82) }
        Text { anchors.verticalCenter: parent.verticalCenter; text: tag.text.toUpperCase(); color: tag.tint; font.family: EvaStyle.sans; font.bold: true; font.pixelSize: tag.size }
    }

    layer.enabled: EvaStyle.halo > 0
    layer.effect: MultiEffect {
        shadowEnabled: true
        shadowColor: tag.tint
        shadowBlur: 0.5 * EvaStyle.halo
        shadowOpacity: 0.9
        shadowHorizontalOffset: 0
        shadowVerticalOffset: 0
    }
}
