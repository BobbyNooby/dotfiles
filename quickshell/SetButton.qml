// A small text button for settings pages. `accent` fills it with the accent colour,
// `danger` colours the text red (Forget, Remove).
import QtQuick

Clicky {
    id: btn
    property string text
    property bool accent: false
    property bool danger: false
    implicitWidth: label.implicitWidth + 26
    implicitHeight: 34
    radius: Theme.r(11)
    base: accent ? Theme.accent : Theme.bgHigh
    opacity: active ? 1 : 0.5
    Txt {
        id: label
        anchors.centerIn: parent
        text: btn.text
        font.pixelSize: 12
        font.weight: Font.DemiBold
        color: btn.accent ? Theme.textOnAccent : btn.danger ? Theme.danger : Theme.text
    }
}
