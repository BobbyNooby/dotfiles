// Alt+Tab window switcher. Hold Alt: Tab steps through your windows, most recently used first
// (Shift+Tab goes back), minimized windows (Super+M) at the end; let go of Alt to jump to the highlighted one, on whatever workspace it's on.
// Hyprland's binds call it (hyprland.lua):
//   qs ipc call switcher next | prev      open / step
//   qs ipc call switcher commit           Alt released: focus the choice
//   qs ipc call switcher cancel           close without switching
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets

PanelWindow {
    id: win
    property bool open: false
    property var windows: []   // [{ address, cls, title, ws }], most recent first
    property int index: 0
    property int pending: 0    // steps pressed before the window list arrived

    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-switcher"
    color: "transparent"
    implicitWidth: Math.min((screen?.width ?? 1920) - 80, row.implicitWidth + 32 + 60)
    implicitHeight: 200
    mask: Region { item: card }
    visible: open && windows.length > 1

    function step(d) {
        if (!open) { open = true; pending = d; list.running = true; return }
        if (windows.length === 0) { pending += d; return }
        index = (index + d + windows.length) % windows.length;
        idle.restart();
    }
    function commit() {
        if (!open) return;
        const w = windows[index];
        if (w?.hidden) Quickshell.execDetached([Quickshell.env("HOME") + "/.config/hypr/scripts/minimize", "restore", w.address]);
        else if (w && index !== 0) Hyprland.dispatch("hl.dsp.focus({ window = \"address:" + w.address + "\" })");
        close();
    }
    function close() { open = false; windows = []; index = 0; idle.stop() }

    // In case the Alt release never arrives (e.g. focus was grabbed): switch after a while anyway
    Timer { id: idle; interval: 4000; onTriggered: win.commit() }

    Process {
        id: list
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!win.open) return;
                try {
                    win.windows = JSON.parse(text)
                        .filter(c => c.mapped && (c.workspace?.id > 0 || c.workspace?.name === "special:minimized"))
                        .map(c => ({ address: c.address, cls: c.class, title: c.title, ws: c.workspace.id,
                                     hidden: c.workspace.name === "special:minimized", order: c.focusHistoryID }))
                        // minimized windows go after the others
                        .sort((a, b) => (a.hidden - b.hidden) || (a.order - b.order));
                } catch (e) { win.windows = [] }
                if (win.windows.length < 2) { win.close(); return }
                win.index = ((win.pending % win.windows.length) + win.windows.length) % win.windows.length;
                idle.restart();
            }
        }
    }

    IpcHandler {
        target: "switcher"
        function next(): void { win.step(1) }
        function prev(): void { win.step(-1) }
        function commit(): void { win.commit() }
        function cancel(): void { win.close() }
    }

    function iconFor(cls) {
        const e = DesktopEntries.heuristicLookup(cls);
        return Quickshell.iconPath(e?.icon ?? cls, "application-x-executable");
    }

    RectangularShadow {
        anchors.fill: card
        radius: card.radius
        offset.y: 18
        blur: 50
        color: Qt.rgba(0, 0, 0, 0.5)
    }
    Rectangle {
        id: card
        anchors.centerIn: parent
        width: parent.width - 60
        height: 160
        radius: Theme.r(32)
        color: Theme.alpha(Theme.bgLow, 0.96)
        clip: true

        Flickable {
            id: flick
            anchors { fill: parent; margins: 16 }
            contentWidth: row.implicitWidth
            interactive: false
            // keep the highlighted window in view
            contentX: Math.max(0, Math.min(contentWidth - width, win.index * 140 - width / 2 + 70))
            Behavior on contentX { NumberAnimation { duration: 120 } }

            Row {
                id: row
                spacing: 8
                Repeater {
                    model: win.windows
                    Rectangle {
                        id: tile
                        required property var modelData
                        required property int index
                        readonly property bool on: index === win.index
                        width: 132
                        height: 128
                        radius: Theme.r(20)
                        color: on ? Theme.accentSoft : "transparent"
                        border.color: on ? Theme.accent : "transparent"
                        border.width: 2
                        Behavior on color { ColorAnimation { duration: 100 } }
                        ColumnLayout {
                            anchors { fill: parent; margins: 10 }
                            spacing: 6
                            IconImage {
                                Layout.alignment: Qt.AlignHCenter
                                implicitSize: 52
                                source: win.iconFor(tile.modelData.cls)
                            }
                            Txt {
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                                text: tile.modelData.title || tile.modelData.cls
                                elide: Text.ElideRight
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                                color: tile.on ? Theme.textOnSoft : Theme.text
                            }
                            Txt {
                                Layout.alignment: Qt.AlignHCenter
                                text: tile.modelData.hidden ? "minimized" : "workspace " + tile.modelData.ws
                                font.pixelSize: 11
                                color: tile.on ? Theme.textOnSoft : Theme.textDim
                            }
                        }
                    }
                }
            }
        }
    }
}
