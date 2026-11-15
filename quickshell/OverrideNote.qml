// Shown under a setting changed in this window: it now differs from settings.nix (it lives in
// ~/.config/desktop/overrides.json). "Copy for settings.nix" puts the Nix line on the clipboard
// to paste into hosts/<host>/settings.nix; "Use settings.nix" drops the change.
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: note
    property string key
    property bool copied: false
    visible: Settings.differs(key)
    Layout.fillWidth: true
    implicitHeight: row.implicitHeight + 16
    radius: Theme.r(14)
    color: Theme.alpha(Theme.accent, 0.12)
    border.width: 1
    border.color: Theme.alpha(Theme.accent, 0.3)
    onVisibleChanged: copied = false
    Timer { id: unflag; interval: 2500; onTriggered: note.copied = false }

    RowLayout {
        id: row
        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 12; rightMargin: 8 }
        spacing: 8
        Icon { name: "info"; size: 16; color: Theme.accent }
        Txt {
            Layout.fillWidth: true
            text: note.copied ? "Copied. Paste it into desktop = { … } in settings.nix, then rebuild."
                : "Changed here, differs from settings.nix (kept in overrides.json)."
            font.pixelSize: 12
            color: Theme.text
            wrapMode: Text.Wrap
        }
        SetButton { text: "Copy for settings.nix"; onClicked: { Settings.copyNix(note.key); note.copied = true; unflag.restart() } }
        SetButton { text: "Use settings.nix"; onClicked: Settings.reset(note.key) }
    }
}
