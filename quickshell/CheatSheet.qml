// Cheat sheet over everything: Super + / (or `qs ipc call cheatsheet toggle`).
// Hyprland keys, terminal and tmux keys, and your aliases side by side. Esc or a click closes it.
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: win
    property bool open: false
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-cheatsheet"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    color: "transparent"
    visible: open || sheet.opacity > 0
    onOpenChanged: if (open) { Shortcuts.refresh(); keys.forceActiveFocus() }

    IpcHandler {
        target: "cheatsheet"
        function toggle(): void { win.open = !win.open }
        function close(): void { win.open = false }
    }

    Rectangle { // dim the screen; click anywhere to close
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.35)
        opacity: sheet.opacity
        MouseArea { anchors.fill: parent; onClicked: win.open = false }
    }
    Item {
        id: keys
        focus: true
        Keys.onPressed: e => { if (e.key === Qt.Key_Escape || e.key === Qt.Key_Slash) { win.open = false; e.accepted = true } }
    }

    RectangularShadow {
        anchors.fill: sheet
        radius: sheet.radius
        offset.y: 18
        blur: 50
        color: Qt.rgba(0, 0, 0, 0.5 * sheet.opacity)
    }
    Rectangle {
        id: sheet
        anchors.centerIn: parent
        width: Math.min(parent.width - 80, 1500)
        height: Math.min(parent.height - 120, cols.implicitHeight + 90)
        radius: Theme.r(32)
        color: Theme.bgLow
        opacity: win.open ? 1 : 0
        scale: win.open ? 1 : 0.97
        Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        MouseArea { anchors.fill: parent } // clicks inside don't close it

        RowLayout {
            x: 28
            y: 24
            width: parent.width - 56
            Txt { heading: true; text: "Shortcuts"; font.pixelSize: 22; Layout.fillWidth: true }
            Txt { text: "Esc to close · aliases come from ~/aliases"; font.pixelSize: 12; color: Theme.textDim }
        }

        Flickable {
            id: sheetFlick
            SmoothWheel { flick: sheetFlick }
            x: 28
            y: 70
            width: parent.width - 56
            height: parent.height - 90
            contentHeight: cols.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            clip: true
            RowLayout {
                id: cols
                width: parent.width
                spacing: 36
                KeyList { Layout.alignment: Qt.AlignTop; Layout.fillWidth: true; Layout.preferredWidth: 1; rows: Shortcuts.hyprland; keyWidth: 150 }
                KeyList { Layout.alignment: Qt.AlignTop; Layout.fillWidth: true; Layout.preferredWidth: 1; rows: Shortcuts.terminal; keyWidth: 150 }
                KeyList { Layout.alignment: Qt.AlignTop; Layout.fillWidth: true; Layout.preferredWidth: 1; rows: [["Aliases"], ...Shortcuts.aliases]; keyWidth: 110; mono: true }
            }
        }
    }
}
