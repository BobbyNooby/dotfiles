// Quick settings: Super + , (or "Settings" in the account popup, right-click the Wi-Fi icon,
// or `qs ipc call controls toggle`). The everyday switches in one place:
//   tiles     Wi-Fi, Bluetooth, Do not disturb, Sound (click to switch; › opens its full popup)
//   sliders   volume and screen brightness
//   power     Saver / Balanced / Performance
//   footer    All settings (the Settings window, Super+I), lock, and the account popup (sleep, restart, shut down)
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower

Dropdown {
    id: win
    name: "controls"
    panelWidth: 380
    alignRight: true
    spacing: 14

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var btConnected: Bluetooth.devices.values.filter(d => d.connected)
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool muted: sink?.audio?.muted ?? false
    PwObjectTracker { objects: [win.sink] }

    onOpened: { Net.refresh(); bright.running = true }

    IpcHandler { // Super + , runs this
        target: "controls"
        function toggle(): void { Popups.toggle("controls", -1) }
        function close(): void { Popups.close("controls") }
    }
    // Open another popup instead (the tile's ›): it takes this one's place
    function more(popup) { Popups.toggle(popup, -1) }

    // Screen brightness (brightnessctl): read when opened, set while dragging
    property real brightness: 0.5
    property bool hasBacklight: true
    Process {
        id: bright
        command: ["brightnessctl", "-m"] // e.g. amdgpu_bl2,backlight,45875,70%,65535
        stdout: StdioCollector {
            onStreamFinished: {
                const f = text.trim().split(",");
                win.hasBacklight = f.length >= 5;
                if (win.hasBacklight) win.brightness = Number(f[2]) / Number(f[4]);
            }
        }
    }
    Timer { // don't start a process for every pixel of a drag
        id: setBright
        interval: 40
        onTriggered: Quickshell.execDetached(["brightnessctl", "-q", "set", Math.round(win.brightness * 100) + "%"])
    }



    // ---------------- the panel ----------------
    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: 4
        Txt { Layout.fillWidth: true; heading: true; text: "Quick settings"; font.pixelSize: 17 }
        Txt { text: Stats.uptimeText; font.pixelSize: 12; color: Theme.textDim }
    }

    GridLayout {
        Layout.fillWidth: true
        columns: 2
        rowSpacing: 8
        columnSpacing: 8
        QuickTile {
            icon: "wifi"
            title: "Wi-Fi"
            status: Net.label
            on: Net.wifiOn
            popup: "wifi"
            onMore: win.more(popup)
            onClicked: Net.setWifi(!Net.wifiOn)
        }
        QuickTile {
            icon: "bluetooth"
            title: "Bluetooth"
            status: !win.adapter ? "No adapter" : !win.adapter.enabled ? "Off"
                : win.btConnected.length ? win.btConnected.map(d => d.name).join(", ") : "On"
            on: win.adapter?.enabled ?? false
            popup: "bluetooth"
            onMore: win.more(popup)
            onClicked: if (win.adapter) win.adapter.enabled = !win.adapter.enabled
        }
        QuickTile {
            icon: "bell"
            title: "Do not disturb"
            status: Notifs.dnd ? "Popups hidden" : "Off"
            on: Notifs.dnd
            onClicked: Notifs.dnd = !Notifs.dnd
        }
        QuickTile {
            icon: win.muted ? "mute" : "volume"
            title: "Sound"
            status: !win.sink ? "No output" : win.muted ? "Muted" : (win.sink.description || win.sink.nickname || "On")
            on: !!win.sink && !win.muted
            popup: "volume"
            onMore: win.more(popup)
            onClicked: if (win.sink?.audio) win.sink.audio.muted = !win.muted
        }
    }

    LevelSlider {
        icon: win.muted ? "mute" : "volume"
        value: win.sink?.audio?.volume ?? 0
        dim: win.muted || !win.sink
        onMoved: v => { if (!win.sink?.audio) return; win.sink.audio.volume = v; if (v > 0) win.sink.audio.muted = false }
        onIconClicked: if (win.sink?.audio) win.sink.audio.muted = !win.muted
    }
    LevelSlider {
        visible: win.hasBacklight
        icon: "sun"
        value: win.brightness
        onMoved: v => { win.brightness = Math.max(0.01, v); setBright.restart() } // never fully black
    }

    // Power profile (power-profiles-daemon)
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 52
        radius: Theme.r(16)
        color: Theme.bgMid
        RowLayout {
            anchors { fill: parent; margins: 4 }
            spacing: 4
            Repeater {
                model: [
                    { p: PowerProfile.PowerSaver,  icon: "saver",    label: "Saver" },
                    { p: PowerProfile.Balanced,    icon: "balanced", label: "Balanced" },
                    { p: PowerProfile.Performance, icon: "boltLine", label: "Performance" }
                ]
                Clicky {
                    id: prof
                    required property var modelData
                    readonly property bool on: PowerProfiles.profile === modelData.p
                    visible: modelData.p !== PowerProfile.Performance || PowerProfiles.hasPerformanceProfile
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 1
                    radius: Theme.r(12)
                    base: on ? Theme.accent : "transparent"
                    onClicked: PowerProfiles.profile = modelData.p
                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 6
                        Icon { name: prof.modelData.icon; size: 15; stroke: 2; color: prof.on ? Theme.textOnAccent : Theme.textDim }
                        Txt { text: prof.modelData.label; font.pixelSize: 12; font.weight: Font.DemiBold; color: prof.on ? Theme.textOnAccent : Theme.textDim }
                    }
                }
            }
        }
    }

    // Footer
    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        // the full Settings window (Super+I); the network editor is under its Wi-Fi page
        IconButton { icon: "gear"; label: "All settings"; onClicked: Quickshell.execDetached(["qs", "ipc", "call", "settings", "open", ""]) }
        Item { Layout.fillWidth: true }
        IconButton { icon: "lock"; label: "Lock"; onClicked: { Popups.close(); Quickshell.execDetached(["loginctl", "lock-session"]) } }
        IconButton { icon: "power"; label: ""; onClicked: win.more("account") }
    }
}
