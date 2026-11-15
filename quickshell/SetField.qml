// A text box for settings pages (Wi-Fi password, city names). Enter emits accepted().
import QtQuick
import QtQuick.Controls

TextField {
    id: field
    implicitHeight: 36
    font.family: Theme.font
    font.pixelSize: 13
    color: Theme.text
    placeholderTextColor: Theme.outline
    selectionColor: Theme.accent
    selectedTextColor: Theme.textOnAccent
    leftPadding: 12
    rightPadding: 12
    background: Rectangle {
        radius: Theme.r(11)
        color: Theme.bgHigh
        border.width: field.activeFocus ? 1.5 : 0
        border.color: Theme.accent
    }
}
