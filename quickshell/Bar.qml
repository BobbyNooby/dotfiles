// The top bar, one per monitor. Floats 8 px below the screen edge, 44 px tall.
//   left:   your picture (account popup), then workspaces with icons of the apps open on them
//   centre: what's playing (click = the player, scroll = next/previous, ▶/⏸ = play/pause)
//   right:  tray apps · RAM · keyboard language · volume · Wi-Fi · Bluetooth · battery · notifications · time
// Each button opens its popup under it (Popups.qml). Save this file and the bar redraws.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Services.SystemTray
import Quickshell.Bluetooth

PanelWindow {
    id: bar
    required property var modelData
    screen: modelData

    anchors { top: true; left: true; right: true }
    implicitHeight: Theme.barTop + Theme.barHeight // windows start below this
    color: "transparent"
    WlrLayershell.namespace: "qs-bar" // hyprland.lua blurs this layer

    // Centre of an item in screen coordinates (the bar spans the whole width)
    function centreOf(item) { return item.mapToItem(null, item.width / 2, 0).x }
    function run(cmd) { Quickshell.execDetached(["sh", "-c", cmd]) }

    // App id → the little icon drawn on its workspace
    function kindOf(app) {
        app = (app ?? "").toLowerCase();
        if (/wezterm|kitty|alacritty|foot|terminal/.test(app)) return "term";
        if (/edge|firefox|chrom|brave|zen/.test(app)) return "web";
        if (/zed|code|codium|nvim|jetbrains|idea/.test(app)) return "code";
        if (/spotify|music|vlc|mpv/.test(app)) return "music";
        if (/discord|vesktop|telegram|slack|whatsapp|signal/.test(app)) return "chat";
        if (/nautilus|thunar|dolphin|files/.test(app)) return "folder";
        if (/obsidian/.test(app)) return "notes";
        return "window";
    }
    readonly property var appsByWs: {
        const m = {};
        for (const t of Hyprland.toplevels.values) {
            const ws = t.workspace?.id;
            if (!ws || ws < 1) continue;
            const k = kindOf(t.wayland?.appId || t.lastIpcObject?.class);
            m[ws] = m[ws] ?? [];
            if (!m[ws].includes(k) && m[ws].length < 3) m[ws].push(k);
        }
        return m;
    }

    // ---- keyboard language (Hyprland's active layout) ----
    property string layoutName: ""
    readonly property string layoutCode: {
        const n = layoutName.toLowerCase();
        if (/chinese|pinyin/.test(n)) return "中";
        if (/japan/.test(n)) return "日";
        if (/malay/.test(n)) return "MS";
        return n ? n.slice(0, 2).toUpperCase() : "EN";
    }
    Process {
        running: true
        command: ["hyprctl", "devices", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { bar.layoutName = JSON.parse(text).keyboards.find(k => k.main)?.active_keymap ?? "" } catch (e) {}
            }
        }
    }
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "activelayout") bar.layoutName = event.data.split(",").slice(1).join(",");
        }
    }

    // ---- audio / battery ----
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false
    PwObjectTracker { objects: [bar.sink] }

    readonly property var batt: UPower.displayDevice
    readonly property real battPct: batt?.percentage ?? 0 // 0..1
    readonly property bool charging: batt?.state === UPowerDeviceState.Charging || batt?.state === UPowerDeviceState.FullyCharged

    SystemClock { id: clock; precision: SystemClock.Minutes }

    // ---------------- the bar ----------------
    Rectangle {
        id: body
        anchors { fill: parent; topMargin: Theme.barTop; leftMargin: Theme.barSide; rightMargin: Theme.barSide }
        radius: Theme.r(16)
        color: Theme.alpha(Theme.bg, Theme.barOpacity)
        border.color: Theme.alpha(Theme.textDim, 0.08)
        border.width: 1

        // ---------- left: you, then workspaces ----------
        RowLayout {
            anchors { left: parent.left; leftMargin: 6; verticalCenter: parent.verticalCenter }
            spacing: 4

            // Your picture: click for the account popup (picture, lock, sleep, sign out, power)
            Clicky {
                id: accountBtn
                implicitWidth: 36
                implicitHeight: 32
                radius: Theme.r(12)
                base: Popups.open === "account" ? Theme.bgHighest : "transparent"
                onClicked: Popups.toggle("account", bar.centreOf(accountBtn))
                Avatar { anchors.centerIn: parent; size: 26 }
            }

            Repeater {
                // 1-5 always; more appear when you use them
                model: Math.max(5, ...Hyprland.workspaces.values.map(w => w.id))
                Clicky {
                    id: ws
                    required property int index
                    readonly property int wsId: index + 1
                    readonly property bool focused: Hyprland.focusedWorkspace?.id === wsId
                    readonly property var apps: bar.appsByWs[wsId] ?? []
                    implicitHeight: 32
                    implicitWidth: wsRow.implicitWidth + 20
                    radius: Theme.r(12)
                    base: focused ? Theme.accent : "transparent"
                    onClicked: Hyprland.dispatch("hl.dsp.focus({ workspace = " + wsId + " })")
                    onScrolled: wheel => Hyprland.dispatch("hl.dsp.focus({ workspace = \"e" + (wheel.angleDelta.y < 0 ? "+1" : "-1") + "\" })")
                    RowLayout {
                        id: wsRow
                        anchors.centerIn: parent
                        spacing: 6
                        Txt {
                            heading: true
                            text: ws.wsId
                            font.pixelSize: 14
                            color: ws.focused ? Theme.textOnAccent : ws.apps.length ? Theme.text : Theme.textDim
                        }
                        Repeater {
                            model: ws.apps
                            Icon {
                                required property string modelData
                                name: modelData
                                size: 15
                                stroke: 2
                                color: ws.focused ? Theme.textOnAccent : Theme.textDim
                            }
                        }
                    }
                }
            }
        }

        // ---------- centre: now playing ----------
        Rectangle {
            id: music
            visible: Media.hasPlayer
            anchors.centerIn: parent
            width: 460
            height: 32
            radius: Theme.r(12)
            color: Theme.bgMid
            clip: true

            Clicky {
                id: musicBtn
                anchors { left: parent.left; top: parent.top; bottom: parent.bottom; right: playBtn.left }
                radius: Theme.r(12)
                onClicked: Popups.toggle("music", bar.centreOf(music))
                onScrolled: wheel => wheel.angleDelta.y < 0 ? Media.next() : Media.previous()
                RowLayout {
                    anchors { fill: parent; leftMargin: 5; rightMargin: 8 }
                    spacing: 10
                    Item { // the icon sits outside the clip: ClippingRectangle darkens what it draws
                        implicitWidth: children[0].implicitWidth
                        implicitHeight: children[0].implicitHeight
                        ClippingRectangle {
                            implicitWidth: 22
                            implicitHeight: 22
                            radius: 11
                            color: Theme.accentSoft
                            Image { id: miniArt; anchors.fill: parent; source: Media.art; fillMode: Image.PreserveAspectCrop; asynchronous: true; sourceSize.width: 44 }
                        }
                        Icon { anchors.centerIn: parent; name: "music"; size: 12; color: Theme.textOnSoft; visible: miniArt.status !== Image.Ready }
                    }
                    Txt {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        textFormat: Text.StyledText
                        text: "<b>" + (Media.title || Media.app).replace(/&/g, "&amp;").replace(/</g, "&lt;") + "</b>"
                            + (Media.artist ? "<font color='" + Theme.textDim + "'> · " + Media.artist.replace(/&/g, "&amp;").replace(/</g, "&lt;") + "</font>" : "")
                    }
                    Txt { text: Media.time(Media.position); font.pixelSize: 12; color: Theme.textDim; visible: Media.length > 0 }
                }
            }
            Clicky {
                id: playBtn
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                width: 32
                height: 32
                radius: Theme.r(12)
                onClicked: Media.toggle()
                Icon { anchors.centerIn: parent; name: Media.playing ? "pause" : "play"; size: 16; color: Theme.accent }
            }
            Rectangle { // progress along the bottom edge
                anchors { left: parent.left; bottom: parent.bottom }
                height: 2
                width: parent.width * Media.progress
                color: Theme.accent
            }
        }

        // ---------- right ----------
        RowLayout {
            anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
            spacing: 2

            // Tray apps (Discord, Surfshark, Spotifast...): click = open, right-click = menu,
            // middle-click = close the app (scripts/tray-quit). Drawn in one colour
            // so they follow the wallpaper colours (TrayIcon.qml). The Wi-Fi and Bluetooth applets
            // stay running (they answer password / pairing prompts) but are hidden: the bar has its own.
            Repeater {
                model: SystemTray.items.values.filter(i => !/nm-applet|networkmanager|blueman/i.test(i.id + " " + i.title))
                Clicky {
                    id: trayBtn
                    required property var modelData
                    implicitWidth: 30
                    implicitHeight: 32
                    onClicked: mouse => {
                        if (mouse.button === Qt.RightButton || modelData.onlyMenu) {
                            if (modelData.hasMenu) {
                                const p = trayBtn.mapToItem(null, 0, trayBtn.height + 6);
                                modelData.display(bar, p.x, p.y);
                            }
                        } else if (mouse.button === Qt.MiddleButton) // middle-click: close the app
                            Quickshell.execDetached([Quickshell.shellDir + "/scripts/tray-quit", modelData.id]);
                        else modelData.activate();
                    }
                    TrayIcon { anchors.centerIn: parent; item: trayBtn.modelData }
                }
            }

            // RAM in use (the System card on the desktop has the details)
            RowLayout {
                Layout.leftMargin: 8
                Layout.rightMargin: 8
                spacing: 6
                Icon { name: "ram"; size: 16; color: Theme.textDim }
                Txt { text: "RAM " + Math.round(Stats.mem * 100) + "%"; font.pixelSize: 12; font.weight: Font.DemiBold }
            }

            // Keyboard language: click = next layout
            Clicky {
                implicitWidth: Math.max(40, kbRow.implicitWidth + 16)
                implicitHeight: 32
                onClicked: bar.run("hyprctl switchxkblayout main next")
                RowLayout {
                    id: kbRow
                    anchors.centerIn: parent
                    spacing: 6
                    Icon { name: "keyboard"; size: 16; color: Theme.textDim }
                    Txt { text: bar.layoutCode; font.pixelSize: 12; font.weight: Font.DemiBold }
                }
            }

            // Volume: click = popup, scroll = ±5%, middle-click = mute
            Clicky {
                id: volBtn
                implicitWidth: volRow.implicitWidth + 16
                implicitHeight: 32
                base: Popups.open === "volume" ? Theme.bgHighest : "transparent"
                onClicked: mouse => {
                    if (mouse.button === Qt.MiddleButton) { if (bar.sink?.audio) bar.sink.audio.muted = !bar.muted }
                    else if (mouse.button === Qt.RightButton) bar.run("pavucontrol");
                    else Popups.toggle("volume", bar.centreOf(volBtn));
                }
                onScrolled: wheel => {
                    if (bar.sink?.audio) bar.sink.audio.volume = Math.max(0, Math.min(1, bar.volume + (wheel.angleDelta.y > 0 ? 0.05 : -0.05)));
                }
                RowLayout {
                    id: volRow
                    anchors.centerIn: parent
                    spacing: 6
                    Icon { name: bar.muted ? "mute" : "volume"; size: 16 }
                    Txt { text: bar.muted ? "Muted" : Math.round(bar.volume * 100) + "%"; font.pixelSize: 12; font.weight: Font.DemiBold }
                }
            }

            // Wi-Fi: click = popup, right-click = Control Center
            Clicky {
                id: wifiBtn
                implicitWidth: 36
                implicitHeight: 32
                base: Popups.open === "wifi" ? Theme.bgHighest : "transparent"
                onClicked: mouse => mouse.button === Qt.RightButton ? Controls.toggle() : Popups.toggle("wifi", bar.centreOf(wifiBtn))
                Icon {
                    anchors.centerIn: parent
                    name: Net.wired && !Net.ssid ? "ethernet" : "wifi"
                    size: 17
                    stroke: 1.9
                    color: Net.online ? Theme.text : Theme.alpha(Theme.text, 0.4)
                }
            }

            // Bluetooth (dim when off): click = popup, right-click = Bluetooth manager
            Clicky {
                id: btBtn
                implicitWidth: 36
                implicitHeight: 32
                base: Popups.open === "bluetooth" ? Theme.bgHighest : "transparent"
                onClicked: mouse => mouse.button === Qt.RightButton ? bar.run("blueman-manager") : Popups.toggle("bluetooth", bar.centreOf(btBtn))
                Icon {
                    anchors.centerIn: parent
                    name: "bluetooth"
                    size: 17
                    stroke: 1.9
                    color: Bluetooth.defaultAdapter?.enabled ? Theme.text : Theme.alpha(Theme.text, 0.4)
                }
                Rectangle { // a dot when something is connected
                    visible: Bluetooth.devices.values.some(d => d.connected)
                    anchors { right: parent.right; bottom: parent.bottom; rightMargin: 8; bottomMargin: 6 }
                    width: 5; height: 5; radius: 3
                    color: Theme.accent
                }
            }

            // Battery: the percentage inside a battery shape; click = popup
            Clicky {
                id: battBtn
                visible: bar.batt?.isLaptopBattery ?? false
                implicitWidth: battRow.implicitWidth + 16
                implicitHeight: 32
                base: Popups.open === "battery" ? Theme.bgHighest : "transparent"
                onClicked: Popups.toggle("battery", bar.centreOf(battBtn))
                RowLayout {
                    id: battRow
                    anchors.centerIn: parent
                    spacing: 3
                    Rectangle {
                        implicitWidth: 40
                        implicitHeight: 20
                        radius: 6
                        color: "transparent"
                        border.color: Theme.textDim
                        border.width: 1.5
                        Rectangle {
                            x: 1.5; y: 1.5
                            height: parent.height - 3
                            width: (parent.width - 3) * bar.battPct
                            radius: 4
                            color: bar.battPct <= 0.2 && !bar.charging ? Theme.danger : Theme.accent
                        }
                        Txt {
                            anchors.centerIn: parent
                            text: Math.round(bar.battPct * 100)
                            font.pixelSize: 11
                            font.weight: Font.Bold
                            color: bar.battPct >= 0.55 ? Theme.textOnAccent : Theme.text
                        }
                    }
                    Rectangle { implicitWidth: 3; implicitHeight: 8; radius: 1; color: Theme.textDim }
                    Icon { visible: bar.charging; name: "bolt"; size: 14; color: Theme.accent; Layout.leftMargin: 2 }
                }
            }

            // Notifications: click = list, right-click = do not disturb
            Clicky {
                id: bellBtn
                implicitWidth: 36
                implicitHeight: 32
                base: Popups.open === "notifs" ? Theme.bgHighest : "transparent"
                onClicked: mouse => { if (mouse.button === Qt.RightButton) Notifs.dnd = !Notifs.dnd; else Popups.toggle("notifs", bar.centreOf(bellBtn)) }
                Icon { anchors.centerIn: parent; name: "bell"; size: 17; stroke: 1.9 }
                Icon { anchors.centerIn: parent; visible: Notifs.dnd; name: "slash"; size: 17; stroke: 2; color: Theme.danger }
                Rectangle {
                    visible: Notifs.unread > 0 && !Notifs.dnd
                    anchors { top: parent.top; right: parent.right; topMargin: 2; rightMargin: 2 }
                    width: Math.max(15, badge.implicitWidth + 8)
                    height: 15
                    radius: 8
                    color: Theme.accent
                    Txt { id: badge; anchors.centerIn: parent; text: Notifs.unread; font.pixelSize: 10; font.weight: Font.Bold; color: Theme.textOnAccent }
                }
            }

            // Time and date
            RowLayout {
                Layout.leftMargin: 8
                Layout.rightMargin: 8
                spacing: 8
                Txt { heading: true; text: Qt.formatDateTime(clock.date, "HH:mm"); font.pixelSize: 16 }
                Txt { text: Qt.formatDateTime(clock.date, "ddd d MMM"); font.pixelSize: 12; color: Theme.textDim }
            }
        }
    }
}
