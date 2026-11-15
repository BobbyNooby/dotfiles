// Widgets on the desktop itself (under your windows, above the wallpaper):
//   top left:     both cities' clocks with a 48-hour forecast (Weather.qml)
//   top right:    System (CPU, memory, NVIDIA asleep/awake, battery, power profile)
//                 and Connections (Tailscale + Surfshark switches, home devices)
//   bottom:       floating lyrics and a music controller you can drag anywhere (it remembers where)
// One see-through window covers the screen; Hyprland blurs only behind the cards.
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.UPower

PanelWindow {
    id: win
    required property var modelData
    screen: modelData

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore // whole-screen coordinates, under the bar too
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "qs-widgets"
    color: "transparent"

    readonly property int cardTop: Theme.popupTop + 12 // first row of cards, under the bar

    // Where the music controller was left (kept across restarts)
    FileView {
        id: stateFile
        path: Quickshell.statePath("widgets.json")
        printErrors: false
        adapter: JsonAdapter {
            id: saved
            property real playerX: -1
            property real playerY: -1
        }
    }

    // ---- battery / power, shared by the System card ----
    readonly property var batt: UPower.displayDevice
    readonly property bool charging: batt?.state === UPowerDeviceState.Charging
    function hmText(secs) {
        const m = Math.round(secs / 60);
        return Math.floor(m / 60) + " h " + (m % 60 < 10 ? "0" : "") + m % 60 + " m";
    }
    readonly property string battDetail: {
        if (!batt) return "";
        if (batt.state === UPowerDeviceState.FullyCharged) return "Full · plugged in";
        if (charging) return batt.timeToFull > 0 ? "Charging · full in about " + hmText(batt.timeToFull) : "Charging";
        return batt.timeToEmpty > 0 ? "On battery · about " + hmText(batt.timeToEmpty) + " left" : "On battery";
    }

                component Meter: ColumnLayout {
    id: meter
                    property string icon
                    property string label
                    property string value
                    property real fraction
                    Layout.fillWidth: true
                    spacing: 6
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        Icon { name: meter.icon; size: 18; color: Theme.accent }
                        Txt { Layout.fillWidth: true; text: meter.label; font.pixelSize: 14 }
                        Txt { text: meter.value; font.pixelSize: 14; font.weight: Font.DemiBold }
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 6
                        radius: 3
                        color: Theme.bgHighest
                        Rectangle {
                            height: parent.height
                            radius: 3
                            width: parent.width * Math.max(0, Math.min(1, meter.fraction))
                            color: meter.fraction > 0.9 ? Theme.danger : Theme.accent
                            Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                        }
                    }
                }

                component VpnTile: Clicky {
    id: tile
                    property string icon
                    property string title
                    property string status
                    property bool on
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    implicitHeight: 88
                    radius: Theme.r(22)
                    base: tile.on ? Theme.accentSoft : Theme.bgHigh
                    ColumnLayout {
                        anchors { fill: parent; margins: 12 }
                        RowLayout {
                            Layout.fillWidth: true
                            Icon { name: tile.icon; size: 22; color: tile.on ? Theme.textOnSoft : Theme.text }
                            Item { Layout.fillWidth: true }
                            Toggle { on: tile.on; small: true }
                        }
                        Item { Layout.fillHeight: true }
                        Txt { text: tile.title; font.pixelSize: 15; font.weight: Font.DemiBold; color: tile.on ? Theme.textOnSoft : Theme.text }
                        Txt { Layout.fillWidth: true; text: tile.status; font.pixelSize: 12; opacity: 0.85; elide: Text.ElideRight; color: tile.on ? Theme.textOnSoft : Theme.text }
                    }
                }

    // A frosted card on the desktop
    component Card: Rectangle {
        radius: Theme.r(24)
        color: Theme.alpha(Theme.bg, Theme.cardOpacity)
    }

    // ====================== time and weather ======================
    Card {
        id: weatherCard
        visible: Settings.show("weather") && Weather.cityList.length > 0
        x: 24
        y: win.cardTop
        width: 452
        implicitHeight: cities.implicitHeight + 26

        ColumnLayout {
            id: cities
            x: 16
            y: 16
            width: parent.width - 32
            spacing: 12

            Repeater {
                model: Weather.cityList
                ColumnLayout {
                    id: city
                    required property var modelData
                    required property int index
                    readonly property var w: Weather.city(modelData.id)
                    Layout.fillWidth: true
                    spacing: 8

                    Rectangle { // divider between the cities
                        visible: city.index > 0
                        Layout.fillWidth: true
                        Layout.bottomMargin: 6
                        implicitHeight: 1
                        color: Theme.alpha(Theme.textDim, 0.10)
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12
                        ColumnLayout {
                            Layout.preferredWidth: 132
                            Layout.alignment: Qt.AlignBottom
                            spacing: 3
                            Txt { text: city.modelData.name; color: Theme.textDim }
                            Txt { heading: true; text: Weather.hm(city.modelData.id); font.pixelSize: 34; lineHeight: 0.9 }
                            Txt { text: Weather.dateText(city.modelData.id) + " · " + Weather.zoneText(city.modelData.id); font.pixelSize: 12; color: Theme.textDim }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignBottom
                            Layout.bottomMargin: 2
                            spacing: 12
                            visible: city.w !== null && !city.w.offline
                            Icon {
                                name: city.w?.kind ?? "cloud"
                                size: 26
                                stroke: 1.7
                                color: { const k = city.w?.kind; return k === "sun" ? Theme.sun : k === "moon" ? Theme.moon : k === "rain" ? Theme.rain : Theme.textDim }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                Txt { heading: true; text: (city.w?.temp ?? "") + "°"; font.pixelSize: 22 }
                                Txt { Layout.fillWidth: true; text: city.w?.cond ?? ""; font.pixelSize: 12; color: Theme.textDim; wrapMode: Text.Wrap }
                            }
                        }
                        Txt {
                            visible: city.w === null || !!city.w.offline
                            Layout.fillWidth: true
                            text: city.w?.offline ? "Offline · last forecast " + city.w.since
                                : Weather.failed[city.modelData.id] ? (Net.online ? "Couldn't reach Open-Meteo · retrying every minute" : "Offline · the forecast loads when you're back online")
                                : "Loading the forecast…"
                            wrapMode: Text.Wrap
                            font.pixelSize: 12
                            color: Theme.textDim
                        }
                        ColumnLayout {
                            visible: city.w !== null && !city.w.offline
                            Layout.alignment: Qt.AlignBottom
                            Layout.bottomMargin: 2
                            spacing: 3
                            Txt { Layout.alignment: Qt.AlignRight; text: "H " + (city.w?.hi ?? "") + "° · L " + (city.w?.lo ?? "") + "°"; font.pixelSize: 12; color: Theme.textDim }
                            Txt { Layout.alignment: Qt.AlignRight; text: city.w?.sunLine ?? ""; font.pixelSize: 12; color: Theme.textDim }
                            Txt { // saved forecast, couldn't refresh (offline)
                                visible: !!city.w?.stale
                                Layout.alignment: Qt.AlignRight
                                text: "offline · " + (city.w?.stale ?? "")
                                font.pixelSize: 11
                                color: Theme.outline
                            }
                        }
                    }

                    // 48 hours, today and tomorrow; scroll sideways (wheel works too)
                    Flickable {
                        id: strip
                        visible: city.w !== null && !city.w.offline
                        Layout.fillWidth: true
                        implicitHeight: 104
                        contentWidth: hours.implicitWidth
                        flickableDirection: Flickable.HorizontalFlick
                        boundsBehavior: Flickable.StopAtBounds
                        clip: true
                        property bool scrolled: false
                        // Start with the hour before now at the left edge
                        onContentWidthChanged: if (!scrolled && city.w && contentWidth > width) {
                            contentX = Math.max(0, Math.min(contentWidth - width, (city.w.nowH - 1) * 47));
                            scrolled = true;
                        }

                        Row {
                            id: hours
                            spacing: 3
                            Repeater {
                                model: city.w?.hours ?? []
                                Rectangle {
                                    id: hr
                                    required property var modelData
                                    width: 44
                                    height: 96
                                    radius: Theme.r(12)
                                    color: hr.modelData.now ? Theme.alpha(Theme.accent, 0.16) : "transparent"
                                    opacity: hr.modelData.past ? 0.42 : 1
                                    Column {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        y: 5
                                        spacing: 3
                                        Txt { anchors.horizontalCenter: parent.horizontalCenter; height: 12; text: hr.modelData.tag; font.pixelSize: 10; font.weight: Font.DemiBold; color: Theme.accent }
                                        Txt { anchors.horizontalCenter: parent.horizontalCenter; text: hr.modelData.label; font.pixelSize: 11; color: Theme.textDim }
                                        Icon {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            name: hr.modelData.kind
                                            size: 20
                                            color: hr.modelData.kind === "sun" ? Theme.sun : hr.modelData.kind === "moon" ? Theme.moon : hr.modelData.kind === "rain" ? Theme.rain : Theme.textDim
                                        }
                                        Txt { anchors.horizontalCenter: parent.horizontalCenter; text: hr.modelData.temp + "°"; font.weight: Font.DemiBold }
                                        Txt { anchors.horizontalCenter: parent.horizontalCenter; height: 12; text: hr.modelData.rainText; font.pixelSize: 10; color: Theme.rain }
                                    }
                                }
                            }
                        }
                        MouseArea { // mouse wheel scrolls the hours sideways
                            anchors.fill: parent
                            acceptedButtons: Qt.NoButton
                            onWheel: wheel => {
                                const d = wheel.angleDelta.y || wheel.angleDelta.x;
                                strip.contentX = Math.max(0, Math.min(strip.contentWidth - strip.width, strip.contentX - d));
                            }
                        }
                    }
                    Rectangle { // thin scroll position bar
                        visible: city.w !== null && !city.w.offline
                        Layout.fillWidth: true
                        implicitHeight: 3
                        radius: 2
                        color: "transparent"
                        Rectangle {
                            height: 3
                            radius: 2
                            color: Theme.border
                            width: parent.width * Math.min(1, strip.width / Math.max(1, strip.contentWidth))
                            x: parent.width * strip.contentX / Math.max(1, strip.contentWidth)
                        }
                    }
                }
            }
        }
    }

    // ====================== shortcuts (Super + / shows them over everything) ======================
    Card {
        id: keysCard
        property string tab: "hyprland"
        x: 24
        y: weatherCard.visible ? weatherCard.y + weatherCard.height + 16 : win.cardTop
        width: 452
        // down to just above the music controller's default spot
        height: Math.min(keysCol.implicitHeight + 28, win.height - y - (Media.hasPlayer ? 124 : 24))
        visible: Settings.show("shortcuts") && height > 120
        clip: true

        ColumnLayout {
            id: keysCol
            x: 16
            y: 14
            width: parent.width - 32
            height: parent.height - 28
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 4
                Txt { text: "Shortcuts"; color: Theme.textDim; Layout.fillWidth: true }
                Repeater {
                    model: [["hyprland", "Hyprland"], ["terminal", "Terminal"], ["aliases", "Aliases"]]
                    Clicky {
                        id: tabBtn
                        required property var modelData
                        readonly property bool on: keysCard.tab === modelData[0]
                        implicitWidth: tabText.implicitWidth + 20
                        implicitHeight: 28
                        radius: Theme.r(10)
                        base: on ? Theme.accentSoft : "transparent"
                        onClicked: keysCard.tab = modelData[0]
                        Txt { id: tabText; anchors.centerIn: parent; text: tabBtn.modelData[1]; font.pixelSize: 12; font.weight: Font.DemiBold; color: tabBtn.on ? Theme.textOnSoft : Theme.textDim }
                    }
                }
            }
            Flickable {
                Layout.fillWidth: true
                Layout.fillHeight: true
                implicitHeight: list.implicitHeight
                contentHeight: list.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                clip: true
                KeyList {
                    id: list
                    width: parent.width
                    keyWidth: keysCard.tab === "aliases" ? 110 : 150
                    mono: keysCard.tab === "aliases"
                    rows: keysCard.tab === "hyprland" ? Shortcuts.hyprland : keysCard.tab === "terminal" ? Shortcuts.terminal : Shortcuts.aliases
                }
            }
            Txt { text: "Super + /  shows these over your windows"; font.pixelSize: 11; color: Theme.outline }
        }
    }

    // ====================== right column ======================
    ColumnLayout {
        x: win.width - 24 - 280
        y: win.cardTop
        width: 280
        spacing: 16

        // ---------- System ----------
        Card {
            visible: Settings.show("system")
            Layout.fillWidth: true
            implicitHeight: sys.implicitHeight + 30
            ColumnLayout {
                id: sys
                x: 16
                y: 14
                width: parent.width - 32
                spacing: 11

                RowLayout {
                    Layout.fillWidth: true
                    Txt { Layout.fillWidth: true; text: "System"; color: Theme.textDim }
                    Txt { text: Stats.uptimeText; font.pixelSize: 12; color: Theme.textDim }
                }

                Meter {
                    icon: "cpu"
                    label: "CPU"
                    value: Math.round(Stats.cpu * 100) + "%" + (Stats.cpuTemp ? " · " + Stats.cpuTemp + " °C" : "")
                    fraction: Stats.cpu
                }
                Meter {
                    icon: "ram"
                    label: "Memory"
                    value: Stats.memUsedGb.toFixed(1) + " / " + Math.round(Stats.memTotalGb) + " GB"
                    fraction: Stats.mem
                }

                // NVIDIA: asleep (0 W) unless something is using it
                RowLayout {
                    visible: Stats.hasGpu
                    Layout.fillWidth: true
                    spacing: 10
                    Icon { name: Stats.gpuAsleep ? "moon" : "gpu"; size: 18; color: Stats.gpuAsleep ? Theme.moon : Theme.second }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        Txt { text: "NVIDIA GPU"; font.pixelSize: 14 }
                        Txt { text: Stats.gpuAsleep ? "wakes on demand" : "in use (nvidia-offload)"; font.pixelSize: 12; color: Theme.textDim }
                    }
                    Rectangle {
                        implicitWidth: gpuChip.implicitWidth + 20
                        implicitHeight: 24
                        radius: Theme.r(10)
                        color: Stats.gpuAsleep ? Theme.accentSoft : Theme.alpha(Theme.second, 0.25)
                        Txt { id: gpuChip; anchors.centerIn: parent; text: Stats.gpuAsleep ? "Asleep · 0 W" : "Awake"; font.pixelSize: 12; font.weight: Font.DemiBold; color: Stats.gpuAsleep ? Theme.textOnSoft : Theme.text }
                    }
                }

                RowLayout {
                    visible: win.batt?.isLaptopBattery ?? false
                    Layout.fillWidth: true
                    spacing: 10
                    Icon { name: "battery"; size: 18; color: Theme.accent }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        Txt { text: "Battery"; font.pixelSize: 14 }
                        Txt { Layout.fillWidth: true; text: win.battDetail; font.pixelSize: 12; color: Theme.textDim; elide: Text.ElideRight }
                    }
                    Txt { text: Math.round((win.batt?.percentage ?? 0) * 100) + "%"; font.pixelSize: 14; font.weight: Font.DemiBold }
                }

                // Power profile (power-profiles-daemon)
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 60
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
                                readonly property bool on: PowerProfiles.profile === prof.modelData.p
                                visible: prof.modelData.p !== PowerProfile.Performance || PowerProfiles.hasPerformanceProfile
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Layout.preferredWidth: 1
                                radius: Theme.r(12)
                                base: on ? Theme.accent : "transparent"
                                onClicked: PowerProfiles.profile = prof.modelData.p
                                Column {
                                    anchors.centerIn: parent
                                    spacing: 3
                                    Icon { anchors.horizontalCenter: parent.horizontalCenter; name: prof.modelData.icon; size: 15; stroke: 2; color: prof.on ? Theme.textOnAccent : Theme.textDim }
                                    Txt { anchors.horizontalCenter: parent.horizontalCenter; text: prof.modelData.label; font.pixelSize: 11; font.weight: Font.DemiBold; color: prof.on ? Theme.textOnAccent : Theme.textDim }
                                }
                            }
                        }
                    }
                }
            }
        }

        // ---------- Connections ----------
        Card {
            visible: Settings.show("connections")
            Layout.fillWidth: true
            implicitHeight: conn.implicitHeight + 28
            ColumnLayout {
                id: conn
                x: 14
                y: 14
                width: parent.width - 28
                spacing: 12


                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    VpnTile {
                        icon: "tailscale"
                        title: "Tailscale"
                        status: Vpn.tsStatus
                        on: Vpn.tsOn
                        onClicked: Vpn.toggleTailscale()
                    }
                    VpnTile {
                        icon: "shield"
                        title: "Surfshark"
                        status: Vpn.vpnStatus
                        on: Vpn.vpnOn
                        onClicked: Vpn.toggleVpn()
                    }
                }

                // Surfshark location: click to show every imported location, click one to use it
                ColumnLayout {
                    id: locPicker
                    property bool open: false
                    visible: Vpn.vpns.length > 1
                    Layout.fillWidth: true
                    spacing: 6
                    Clicky {
                        Layout.fillWidth: true
                        implicitHeight: 36
                        radius: Theme.r(12)
                        base: Theme.bgHigh
                        onClicked: locPicker.open = !locPicker.open
                        RowLayout {
                            anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                            Icon { name: "shield"; size: 14; color: Theme.textDim }
                            Txt { Layout.fillWidth: true; text: "Location: " + (Vpn.current?.label ?? ""); font.pixelSize: 12; font.weight: Font.DemiBold; elide: Text.ElideRight }
                            Txt { text: locPicker.open ? "▴" : "▾"; color: Theme.textDim }
                        }
                    }
                    Flow {
                        visible: locPicker.open
                        Layout.fillWidth: true
                        spacing: 6
                        Repeater {
                            model: Vpn.vpns
                            Clicky {
                                id: loc
                                required property var modelData
                                readonly property bool on: Vpn.current?.name === modelData.name
                                width: locText.implicitWidth + 20
                                height: 30
                                radius: Theme.r(10)
                                base: on ? Theme.accentSoft : "transparent"
                                border.color: on ? Theme.accentSoft : Theme.border
                                border.width: 1
                                onClicked: { Vpn.choose(modelData.name); locPicker.open = false }
                                Txt { id: locText; anchors.centerIn: parent; text: loc.modelData.label; font.pixelSize: 12; color: loc.on ? Theme.textOnSoft : Theme.textDim }
                            }
                        }
                    }
                }

                // Your Tailscale devices (up to 5, online first)
                ColumnLayout {
                    visible: Vpn.tsOn && Vpn.peers.length > 0
                    Layout.fillWidth: true
                    Layout.leftMargin: 4
                    Layout.rightMargin: 4
                    spacing: 8
                    Repeater {
                        model: Vpn.peers.slice(0, 5)
                        RowLayout {
                            id: peer
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: 10
                            Rectangle { implicitWidth: 8; implicitHeight: 8; radius: 4; color: peer.modelData.online ? Theme.accent : Theme.outline }
                            Txt { Layout.fillWidth: true; text: peer.modelData.name; font.weight: Font.Medium; elide: Text.ElideRight }
                            Txt {
                                text: peer.modelData.online ? "online · " + (peer.modelData.direct ? "direct" : "relay")
                                    : "offline" + (peer.modelData.seen ? " · seen " + peer.modelData.seen : "")
                                font.pixelSize: 12
                                color: Theme.textDim
                            }
                        }
                    }
                }

                Rectangle {
                    visible: Vpn.tsOn && Vpn.vpnOn
                    Layout.fillWidth: true
                    implicitHeight: bothText.implicitHeight + 16
                    radius: Theme.r(12)
                    color: Theme.bgHigh
                    Txt {
                        id: bothText
                        x: 10
                        width: parent.width - 20
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Both on: home devices stay on Tailscale, everything else goes through Surfshark."
                        wrapMode: Text.Wrap
                        font.pixelSize: 12
                        lineHeight: 1.2
                        color: Theme.textDim
                    }
                }
            }
        }
    }

    // ====================== floating lyrics ======================
    // A rolling drum: the lines sit around a cylinder lying on its side (like a revolver's
    // cylinder seen from the side). The current line faces you; the ones before and after curve
    // away, squashed and faded, and the drum turns one notch each time the song moves on.
    Item {
        id: drum
        visible: Settings.show("lyrics") && Media.showLyrics && Media.hasLyrics && Media.hasPlayer
        anchors.horizontalCenter: parent.horizontalCenter
        y: win.height * 0.70
        width: win.width - 2 * 300
        height: 220
        layer.enabled: true
        layer.effect: MultiEffect { shadowEnabled: true; shadowColor: "black"; shadowOpacity: 0.6; shadowBlur: 0.8; shadowVerticalOffset: 2 }

        readonly property real step: 34     // degrees between neighbouring lines
        readonly property real radius: 88   // px: how big the drum is
        // where the drum points, eased between lines so it rolls instead of jumping
        property real pos: Media.lineIndex
        Behavior on pos { NumberAnimation { duration: 340; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }

        Repeater {
            model: 5 // two lines either side of the current one; the outer ones are nearly edge-on
            Txt {
                id: lyric
                required property int index
                readonly property int line: Math.round(drum.pos) - 2 + index
                readonly property real angle: (line - drum.pos) * drum.step
                readonly property real rad: angle * Math.PI / 180
                readonly property bool current: line === Media.lineIndex
                visible: Math.abs(angle) < 88 && line >= 0 && line < Media.lines.length
                width: drum.width
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                heading: true
                text: Media.lines[line]?.text || "· · ·"
                font.pixelSize: 34
                color: current ? Qt.lighter(Theme.text, 1.08) : Theme.text
                y: drum.height / 2 + drum.radius * Math.sin(rad) - height / 2
                opacity: Math.pow(Math.max(0, Math.cos(rad)), 2.5) * (current ? 1 : 0.55)
                transform: Rotation {
                    origin.x: lyric.width / 2
                    origin.y: lyric.height / 2
                    axis { x: 1; y: 0; z: 0 }
                    angle: -lyric.angle
                }
            }
        }
    }

    // ====================== music controller (drag it anywhere) ======================
    Rectangle {
        id: player
        visible: Settings.show("player") && Media.hasPlayer
        width: 280
        height: 76
        radius: Theme.r(24)
        x: saved.playerX >= 0 ? Math.min(saved.playerX, win.width - width - 8) : 24
        y: saved.playerY >= 0 ? Math.min(saved.playerY, win.height - height - 8) : win.height - height - 24
        color: Theme.alpha(Theme.bgMid, 0.92)

        RectangularShadow {
            z: -1
            anchors.fill: parent
            radius: parent.radius
            offset.y: drag.active ? 16 : 6
            blur: drag.active ? 40 : 20
            color: Qt.rgba(0, 0, 0, drag.active ? 0.55 : 0.25)
        }

        DragHandler {
            id: drag
            target: player
            xAxis { minimum: 8; maximum: win.width - player.width - 8 }
            yAxis { minimum: Theme.popupTop; maximum: win.height - player.height - 8 }
            cursorShape: active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
            onActiveChanged: if (!active) {
                saved.playerX = player.x;
                saved.playerY = player.y;
                stateFile.writeAdapter();
            }
        }

        RowLayout {
            anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
            spacing: 12
            Item { // the icon sits outside the clip: ClippingRectangle darkens what it draws
                implicitWidth: children[0].implicitWidth
                implicitHeight: children[0].implicitHeight
                ClippingRectangle {
                    implicitWidth: 52
                    implicitHeight: 52
                    radius: Theme.r(16)
                    color: Theme.accentSoft
                    Image { id: art; anchors.fill: parent; source: Media.art; fillMode: Image.PreserveAspectCrop; asynchronous: true; sourceSize.width: 104 }
                }
                Icon { anchors.centerIn: parent; name: "music"; size: 22; color: Theme.textOnSoft; visible: art.status !== Image.Ready }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3
                Txt { Layout.fillWidth: true; text: Media.title || Media.app; font.pixelSize: 14; font.weight: Font.DemiBold; elide: Text.ElideRight }
                Txt { Layout.fillWidth: true; text: Media.artist; font.pixelSize: 12; color: Theme.textDim; elide: Text.ElideRight }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    implicitHeight: 3
                    radius: 2
                    color: Theme.border
                    Rectangle { height: 3; radius: 2; width: parent.width * Media.progress; color: Theme.accent }
                }
            }
            RowLayout {
                spacing: 0
                Clicky { implicitWidth: 30; implicitHeight: 44; onClicked: Media.previous(); Icon { anchors.centerIn: parent; name: "prev"; size: 18 } }
                Clicky {
                    implicitWidth: 44
                    implicitHeight: 44
                    radius: Theme.r(14)
                    base: Theme.accent
                    onClicked: Media.toggle()
                    Icon { anchors.centerIn: parent; name: Media.playing ? "pause" : "play"; size: 18; color: Theme.textOnAccent }
                }
                Clicky { implicitWidth: 30; implicitHeight: 44; onClicked: Media.next(); Icon { anchors.centerIn: parent; name: "next"; size: 18 } }
            }
        }
    }

}
