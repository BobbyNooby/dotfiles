// The Settings window: Super+I (or "All settings" in Quick settings / the account popup).
// A centred window with a sidebar of pages; Esc or a click outside closes it.
//   qs ipc call settings toggle
//   qs ipc call settings open <page>   wifi bluetooth sound notifications keyboard appearance
//                                      clocks power about ("" = the last page)
//   qs ipc call settings set <key> <json> / reset <key> / nix <key>   (see the IpcHandler)
// Each page is its own file (Set<Name>Page.qml), loaded only while it's shown, so the
// commands a page runs (nmcli, fcitx5-remote, ...) only run while you look at it.
// Desktop settings changed here go to ~/.config/desktop/overrides.json (see Settings.qml).
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: win
    property bool open: false
    property string page: "wifi"
    readonly property var pages: [
        { id: "wifi",          label: "Wi-Fi & VPN",        icon: "wifi",      file: "SetWifiPage.qml" },
        { id: "bluetooth",     label: "Bluetooth",          icon: "bluetooth", file: "SetBluetoothPage.qml" },
        { id: "sound",         label: "Sound",              icon: "volume",    file: "SetSoundPage.qml" },
        { id: "notifications", label: "Notifications",      icon: "bell",      file: "SetNotificationsPage.qml" },
        { id: "keyboard",      label: "Keyboard & language", icon: "keyboard", file: "SetKeyboardPage.qml" },
        { id: "appearance",    label: "Appearance",         icon: "image",     file: "SetAppearancePage.qml" },
        { id: "clocks",        label: "Clocks & weather",   icon: "clock",     file: "SetClocksPage.qml" },
        { id: "power",         label: "Power",              icon: "battery",   file: "SetPowerPage.qml" },
        { id: "about",         label: "About",              icon: "info",      file: "SetAboutPage.qml" }
    ]
    readonly property var current: pages.find(p => p.id === page) ?? pages[0]

    function show(id) {
        if (id && pages.some(p => p.id === id)) page = id;
        Popups.close();
        open = true;
    }

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-settings"
    // Exclusive: the password and city boxes need the keyboard
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    color: "transparent"
    visible: open || card.opacity > 0
    onOpenChanged: if (open) keys.forceActiveFocus()

    IpcHandler {
        target: "settings"
        function open(page: string): void { win.show(page) }
        function toggle(): void { if (win.open) win.open = false; else win.show("") }
        function close(): void { win.open = false }
        function page(): string { return win.page } // which page it's on (for checking)
        // Desktop settings from a terminal (go to overrides.json like the pages' switches):
        //   qs ipc call settings set lockGlow '"soft"'    qs ipc call settings reset lockGlow
        //   qs ipc call settings nix cities               (the settings.nix line for it)
        // (qs ipc refuses a list of objects as one argument: edit overrides.json for cities)
        function set(key: string, json: string): void { Settings.set(key, JSON.parse(json)) }
        function reset(key: string): void { Settings.reset(key) }
        function nix(key: string): string { return Settings.nixSnippet(key) }
    }

    Rectangle { // dim the screen; click anywhere outside to close
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.35)
        opacity: card.opacity
        MouseArea { anchors.fill: parent; onClicked: win.open = false }
    }

    RectangularShadow {
        anchors.fill: card
        radius: card.radius
        offset.y: 18
        blur: 50
        color: Qt.rgba(0, 0, 0, 0.5 * card.opacity)
    }
    Rectangle {
        id: card
        anchors.centerIn: parent
        width: Math.min(parent.width - 80, 1040)
        height: Math.min(parent.height - 100, 720)
        radius: Theme.r(28)
        color: Theme.bgLow
        clip: true
        opacity: win.open ? 1 : 0
        scale: win.open ? 1 : 0.97
        Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        MouseArea { anchors.fill: parent; onClicked: keys.forceActiveFocus() } // clicks inside don't close it

        // Esc closes; ↑ ↓ (or Ctrl+Tab) step through the pages when no text box has the keys
        Item {
            id: keys
            anchors.fill: parent
            focus: true
            Keys.onPressed: e => {
                const i = win.pages.indexOf(win.current);
                if (e.key === Qt.Key_Escape) win.open = false;
                else if (keys.Window.activeFocusItem !== keys) return; // typing in a box
                else if (e.key === Qt.Key_Down || (e.key === Qt.Key_Tab && e.modifiers & Qt.ControlModifier)) win.page = win.pages[(i + 1) % win.pages.length].id;
                else if (e.key === Qt.Key_Up || e.key === Qt.Key_Backtab) win.page = win.pages[(i - 1 + win.pages.length) % win.pages.length].id;
                else return;
                e.accepted = true;
            }

            // ---- sidebar ----
            Rectangle {
                id: side
                width: 236
                anchors { top: parent.top; bottom: parent.bottom; left: parent.left }
                color: Theme.bgMid
                ColumnLayout {
                    anchors { fill: parent; margins: 14; topMargin: 22 }
                    spacing: 2
                    RowLayout {
                        Layout.leftMargin: 10
                        Layout.bottomMargin: 12
                        spacing: 10
                        Icon { name: "gear"; size: 20; color: Theme.accent }
                        Txt { heading: true; text: "Settings"; font.pixelSize: 20 }
                    }
                    Repeater {
                        model: win.pages
                        Clicky {
                            id: item
                            required property var modelData
                            readonly property bool on: win.current.id === modelData.id
                            Layout.fillWidth: true
                            implicitHeight: 42
                            radius: Theme.r(13)
                            base: on ? Theme.accentSoft : "transparent"
                            onClicked: { win.page = modelData.id; keys.forceActiveFocus() }
                            RowLayout {
                                anchors { fill: parent; leftMargin: 12; rightMargin: 10 }
                                spacing: 12
                                Icon { name: item.modelData.icon; size: 17; color: item.on ? Theme.textOnSoft : Theme.textDim }
                                Txt { Layout.fillWidth: true; text: item.modelData.label; font.pixelSize: 13; font.weight: item.on ? Font.DemiBold : Font.Normal; color: item.on ? Theme.textOnSoft : Theme.text; elide: Text.ElideRight }
                            }
                        }
                    }
                    Item { Layout.fillHeight: true }
                    Txt { Layout.leftMargin: 10; text: "Esc to close · ↑ ↓ pages"; font.pixelSize: 11; color: Theme.outline }
                }
            }

            // ---- the page ----
            Loader {
                id: pageLoader
                anchors { top: parent.top; bottom: parent.bottom; left: side.right; right: parent.right }
                active: win.visible
                source: win.current.file
                asynchronous: false
            }

            Clicky { // close button, top right
                anchors { top: parent.top; right: parent.right; margins: 14 }
                implicitWidth: 36
                implicitHeight: 36
                radius: 18
                onClicked: win.open = false
                Icon { anchors.centerIn: parent; name: "close"; size: 16; color: Theme.textDim }
            }
        }
    }
}
