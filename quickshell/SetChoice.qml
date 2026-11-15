// Pick one of a few: a row of segments (power profile, lock glow, popup time).
//   SetChoice { options: [{ value: "soft", label: "Soft", icon: "" }, ...]; current: x; onPicked: v => ... }
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: choice
    property var options: []
    property var current
    signal picked(var value)
    Layout.fillWidth: true
    implicitHeight: 46
    radius: Theme.r(15)
    color: Theme.bgHigh
    RowLayout {
        anchors { fill: parent; margins: 4 }
        spacing: 4
        Repeater {
            model: choice.options
            Clicky {
                id: seg
                required property var modelData
                readonly property bool on: choice.current === modelData.value
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 1
                radius: Theme.r(11)
                base: on ? Theme.accent : "transparent"
                onClicked: choice.picked(modelData.value)
                RowLayout {
                    anchors.centerIn: parent
                    spacing: 6
                    Icon { visible: !!seg.modelData.icon; name: seg.modelData.icon ?? ""; size: 15; stroke: 2; color: seg.on ? Theme.textOnAccent : Theme.textDim }
                    Txt { text: seg.modelData.label; font.pixelSize: 12; font.weight: Font.DemiBold; color: seg.on ? Theme.textOnAccent : Theme.textDim }
                }
            }
        }
    }
}
