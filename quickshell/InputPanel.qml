// Typing language: click the keyboard indicator in the bar. Every input method from
// settings.nix `input.methods` (Input.qml); click one to switch. Ctrl+Space cycles anywhere.
import QtQuick
import QtQuick.Layouts
import Quickshell

Dropdown {
    id: win
    name: "input"
    panelWidth: 300
    spacing: 6

    Txt { Layout.leftMargin: 4; heading: true; text: "Typing language"; font.pixelSize: 17 }

    Repeater {
        model: Input.methods
        Clicky {
            id: row
            required property string modelData
            readonly property bool on: modelData === Input.current
            Layout.fillWidth: true
            implicitHeight: 48
            radius: Theme.r(14)
            base: on ? Theme.accentSoft : "transparent"
            onClicked: Input.set(modelData)
            RowLayout {
                anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                spacing: 12
                Txt { Layout.preferredWidth: 26; horizontalAlignment: Text.AlignHCenter; text: Input.label(row.modelData); font.pixelSize: 16; font.weight: Font.DemiBold; color: row.on ? Theme.textOnSoft : Theme.text }
                Txt { Layout.fillWidth: true; text: Input.title(row.modelData); font.pixelSize: 14; color: row.on ? Theme.textOnSoft : Theme.text }
            }
        }
    }

    // Before the rebuild that installs fcitx5 there's only English, and switching can't work yet
    Txt {
        Layout.fillWidth: true
        Layout.leftMargin: 4
        Layout.topMargin: 4
        wrapMode: Text.Wrap
        text: Input.available ? "Ctrl+Space switches to the next one, anywhere."
            : "Japanese, Mandarin and Cantonese arrive with your next rebuild (fcitx5 isn't installed yet)."
        font.pixelSize: 12
        color: Theme.textDim
    }

    Clicky {
        Layout.fillWidth: true
        implicitHeight: 36
        onClicked: { Popups.close(); Quickshell.execDetached(["qs", "ipc", "call", "settings", "open", "keyboard"]) }
        Txt { anchors.centerIn: parent; text: "Keyboard settings"; font.weight: Font.DemiBold; color: Theme.accent }
    }
}
