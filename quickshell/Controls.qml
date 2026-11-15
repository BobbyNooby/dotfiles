// Quick settings (ControlCenter.qml) is one of the dropdowns (Popups.qml, name "controls").
// This keeps the old entry points working: Super + , runs `qs ipc call controls toggle`.
pragma Singleton
import QtQuick
import Quickshell

Singleton {
    id: root
    readonly property bool open: Popups.open === "controls"
    function toggle() { Popups.toggle("controls", -1) }
    // (`qs ipc call controls toggle` lives in ControlCenter.qml: a singleton only exists once
    // something uses it, so its IPC wouldn't be there in time)
}
