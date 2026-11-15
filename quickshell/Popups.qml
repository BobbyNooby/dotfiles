// Which dropdown under the bar is open: "account", "memory", "music", "wifi", "bluetooth", "volume", "battery", "notifs" or "".
// Only one at a time. The bar's buttons call toggle(name, x) with their centre, so the popup
// opens right under the button. From a terminal or keybind:
//   qs ipc call popups toggle wifi      qs ipc call popups close
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property string open: ""
    property real anchorX: -1        // screen x the popup centres on (-1: its default spot)
    property int faceVersion: 0      // bumped when your account picture changes (Avatar.qml)
    property string closedName: ""   // closed by a click outside...
    property real closedAt: 0        // ...at this time (see toggle)

    // A click outside closes the popup a moment before the click reaches the bar button.
    // Without this, clicking the same button again would close it and reopen it at once.
    function toggle(name, x) {
        if (open === name) { open = ""; return }
        if (name === closedName && Date.now() - closedAt < 350) { closedName = ""; return }
        anchorX = x ?? -1;
        open = name;
    }
    function close(name) {
        if (name && open !== name) return;
        closedName = open;
        closedAt = Date.now();
        open = "";
    }

    IpcHandler {
        target: "popups"
        function toggle(name: string): void { root.toggle(name) }
        function close(): void { root.close() }
        function faceChanged(): void { root.faceVersion++ } // scripts/pick-avatar
    }
}
