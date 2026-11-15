// Memory: click RAM in the bar. How much is used and free, swap, and the apps using the most,
// with their processes added together (a browser runs many). Quit closes an app (SIGTERM to all
// its processes, like choosing Quit); it asks for a second click first. Refreshes every 2 s.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Dropdown {
    id: win
    name: "memory"
    panelWidth: 340

    property var apps: []        // [{ comm, name, mb, count }], biggest first
    property string armed: ""    // the app whose Quit was pressed once

    // Friendlier names for what `ps` calls things
    readonly property var names: ({
        "msedge": "Microsoft Edge", "Discord": "Discord", "claude": "Claude Code", "quickshell": "Quickshell",
        "Hyprland": "Hyprland", "spotifast": "Spotifast", "soloist": "Spotify Soloist", "wezterm-gui": "WezTerm",
        "zed-editor": "Zed", "obsidian": "Obsidian", "nix": "Nix (building)", "Xwayland": "Xwayland"
    })
    // Never offered a Quit button: the desktop itself
    readonly property var keep: ["Hyprland", "quickshell", "hyprlock", "hypridle", "systemd", "pipewire", "pipewire-pulse",
        "wireplumber", "Xwayland", "dbus-broker", "nix-daemon", "xdg-desktop-portal", "xdg-desktop-po", "xdg-document-po",
        "xdg-permission-", "gvfsd", "polkit-agent", "hyprpolkitagent", "NetworkManager", "wpa_supplicant"]

    function clean(comm) { // ".Discord-wrappe" → "Discord"
        return comm.replace(/^\./, "").replace(/-(wrapped|wrappe|wrapp|wrap|wra|wr)$/, "");
    }

    Process {
        id: ps
        command: ["ps", "-eo", "rss=,comm="]
        stdout: StdioCollector {
            onStreamFinished: {
                const by = {};
                for (const line of text.split("\n")) {
                    const m = line.trim().match(/^(\d+)\s+(.+)$/);
                    if (!m) continue;
                    const comm = m[2], key = win.clean(comm);
                    by[key] = by[key] ?? { comm, key, kb: 0, count: 0 };
                    by[key].kb += Number(m[1]);
                    by[key].count++;
                }
                win.apps = Object.values(by).sort((a, b) => b.kb - a.kb).slice(0, 8)
                    .map(a => ({ comm: a.comm, key: a.key, name: win.names[a.key] ?? a.key, mb: a.kb / 1024, count: a.count }));
            }
        }
    }
    Timer { interval: 2000; repeat: true; triggeredOnStart: true; running: win.shown; onTriggered: ps.running = true }
    onShownChanged: armed = ""
    Timer { id: disarm; interval: 3000; onTriggered: win.armed = "" }

    function size(mb) { return mb >= 1024 ? (mb / 1024).toFixed(1) + " GB" : Math.round(mb) + " MB" }

    // ---- totals ----
    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: 4
        Txt { Layout.fillWidth: true; heading: true; text: "Memory"; font.pixelSize: 17 }
        Txt { text: Stats.memUsedGb.toFixed(1) + " / " + Math.round(Stats.memTotalGb) + " GB"; font.pixelSize: 14; font.weight: Font.DemiBold; color: Theme.accent }
    }
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 8
        radius: 4
        color: Theme.bgHighest
        Rectangle { height: parent.height; radius: 4; width: parent.width * Stats.mem; color: Stats.mem > 0.9 ? Theme.danger : Theme.accent }
    }
    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: 4
        Layout.rightMargin: 4
        Txt { Layout.fillWidth: true; text: (Stats.memTotalGb - Stats.memUsedGb).toFixed(1) + " GB available"; font.pixelSize: 12; color: Theme.textDim }
        Txt {
            visible: Stats.swapTotalGb > 0
            text: "Swap " + Stats.swapUsedGb.toFixed(1) + " / " + Math.round(Stats.swapTotalGb) + " GB"
            font.pixelSize: 12
            color: Stats.swapUsedGb > 1 ? Theme.danger : Theme.textDim
        }
    }

    // ---- the biggest apps ----
    Txt { Layout.leftMargin: 4; Layout.topMargin: 4; text: "Using the most"; font.pixelSize: 12; color: Theme.textDim }
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 4
        Txt { visible: win.apps.length === 0; Layout.margins: 8; text: "Reading…"; color: Theme.textDim }
        Repeater {
            model: win.apps
            Rectangle {
                id: row
                required property var modelData
                readonly property bool canQuit: !win.keep.includes(modelData.key)
                readonly property bool isArmed: win.armed === modelData.key
                Layout.fillWidth: true
                implicitHeight: 48
                radius: Theme.r(14)
                color: Theme.bgMid
                // share of all memory, as a faint bar behind the row
                Rectangle {
                    anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                    radius: parent.radius
                    width: parent.width * Math.min(1, row.modelData.mb / 1024 / Math.max(1, Stats.memTotalGb))
                    color: Theme.alpha(Theme.accent, 0.14)
                }
                RowLayout {
                    anchors { fill: parent; leftMargin: 12; rightMargin: 6 }
                    spacing: 8
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        Txt { Layout.fillWidth: true; text: row.modelData.name; font.weight: Font.DemiBold; elide: Text.ElideRight }
                        Txt { text: row.modelData.count > 1 ? row.modelData.count + " processes" : "1 process"; font.pixelSize: 11; color: Theme.textDim }
                    }
                    Txt { text: win.size(row.modelData.mb); font.weight: Font.DemiBold }
                    Clicky {
                        visible: row.canQuit
                        implicitWidth: quitText.implicitWidth + 18
                        implicitHeight: 32
                        radius: Theme.r(10)
                        base: row.isArmed ? Theme.danger : "transparent"
                        border.color: row.isArmed ? Theme.danger : Theme.border
                        border.width: 1
                        onClicked: {
                            if (!row.isArmed) { win.armed = row.modelData.key; disarm.restart(); return }
                            win.armed = "";
                            Quickshell.execDetached(["pkill", "-TERM", "-x", row.modelData.comm]);
                            ps.running = true;
                        }
                        Txt { id: quitText; anchors.centerIn: parent; text: row.isArmed ? "Sure?" : "Quit"; font.pixelSize: 12; font.weight: Font.DemiBold; color: row.isArmed ? Theme.textOnAccent : Theme.textDim }
                    }
                }
            }
        }
    }
}
