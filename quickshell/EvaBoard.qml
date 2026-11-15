// The Eva 7 "Signal board": the lock screen's whole picture (LockScreen.qml puts it on every
// screen and does the unlocking). Drawn at 1600×900 like the design (Login-EvaSignal.dc.html)
// and scaled to fit the screen. Uses the desktop's own data: Weather, Stats, Media, Vpn, Net,
// Notifs. Colours and fonts: EvaStyle.qml.
//
//   time        7-segment clock (home) over drifting contour lines, your second city below
//   operator    your picture (~/.face.icon), name, session, host
//   weather     both cities: 12-hour temperature step line + rain bars
//   auth        SEG.1–8 steps light up as you type, the BORDER LINE clears at 4, passcode box
//   system      LED stacks: CPU, temperature, memory, battery, Wi-Fi, volume, NVIDIA
//   audio       what's playing + the current lyric; a red X "MUSIC OFFLINE" when nothing is
//   tailnet     your Tailscale devices on a circuit board
//   power       suspend / restart / shut down (restart and shut down need a second press)
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower

Item {
    id: board
    width: 1600
    height: 900

    // ---- set by LockScreen.qml ----
    property string phase: "idle"     // idle | verify | granted | denied
    property string message: ""       // PAM's own message, if it has one
    property bool caps: false
    signal submit(string password)
    function focusInput() { pass.forceActiveFocus() }
    function clearInput() { pass.text = "" }

    readonly property var st: ({
        idle:    { jp: "待機",   en: "STANDBY",   c: EvaStyle.orange, blink: false },
        verify:  { jp: "照合中", en: "VERIFYING", c: EvaStyle.yellow, blink: true },
        granted: { jp: "承認",   en: "GRANTED",   c: EvaStyle.green,  blink: false },
        denied:  { jp: "拒否",   en: "DENIED",    c: EvaStyle.red,    blink: true }
    })[phase]
    readonly property color accent: st.c
    readonly property int typed: pass.text.length

    // ---- clock ----
    SystemClock { id: clock; precision: SystemClock.Seconds }
    function pad(n) { return (n < 10 ? "0" : "") + n }
    readonly property var days: ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]
    readonly property var months: ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]
    // Your cities (Settings → settings.nix): home is the big clock, the second one sits under it
    readonly property var homeCity: Weather.cityList[0] ?? null
    readonly property var awayCity: Weather.cityList[1] ?? null
    function cityHm(c) { clock.date; return c ? Weather.hm(c.id) : "" }

    // ---- small helpers ----
    readonly property string user: (Quickshell.env("USER") || "user").toUpperCase()
    property string host: ""
    property string generation: ""
    FileView { path: "/etc/hostname"; watchChanges: true; onFileChanged: reload(); printErrors: false; onLoaded: board.host = text().trim().toUpperCase() } // configured name
    Process { // the NixOS generation in use: /nix/var/nix/profiles/system → system-142-link
        running: true
        command: ["readlink", "/nix/var/nix/profiles/system"]
        stdout: StdioCollector { onStreamFinished: board.generation = (text.match(/system-(\d+)-link/) ?? ["", ""])[1] }
    }

    component Panel: Rectangle {
        color: "transparent"
        border.color: EvaStyle.line
        border.width: 1
        clip: true
    }
    component Glowing: Text { // big glowing readings
        color: EvaStyle.white
        font.family: EvaStyle.sans
        font.bold: true
        layer.enabled: EvaStyle.halo > 0
        layer.effect: MultiEffect { shadowEnabled: true; shadowColor: "white"; shadowBlur: 0.45 * EvaStyle.halo; shadowOpacity: 0.7; shadowHorizontalOffset: 0; shadowVerticalOffset: 0 }
    }
    component Plain: Text {
        color: EvaStyle.orange
        font.family: EvaStyle.sans
        font.bold: true
    }

    Rectangle { anchors.fill: parent; color: EvaStyle.bg }

    // Wherever the keyboard focus is, typing lands in the passcode box (a lock screen has
    // nothing else to type into), and a click anywhere puts the focus back there.
    focus: true
    Keys.onPressed: e => {
        if (pass.activeFocus) return;
        pass.forceActiveFocus();
        if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) board.submit(pass.text);
        else if (e.key === Qt.Key_Backspace) pass.remove(pass.length - 1, pass.length);
        else if (e.text && !pass.readOnly) pass.insert(pass.length, e.text);
        e.accepted = true;
    }
    MouseArea { anchors.fill: parent; z: -1; onPressed: m => { pass.forceActiveFocus(); m.accepted = false } }

    // ================= time =================
    Panel {
        x: 24; y: 24; width: 616; height: 276

        Canvas { // contour lines (green above, red below), drifting left
            id: contour
            width: 700; height: 276
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                ctx.lineWidth = 1.4;
                for (const [col, base, f, ph, sign] of [["rgba(45,225,122,0.55)", 12, 55, 0.4, 1], ["rgba(255,59,42,0.55)", 150, 48, 0.5, -1]]) {
                    ctx.strokeStyle = col;
                    for (let i = 0; i < 13; i++) {
                        ctx.beginPath();
                        for (let x = 0; x <= 700; x += 6) {
                            const bump = Math.exp(-Math.pow((x - 330) / 110, 2));
                            const yy = base + i * 9.5 + 7 * Math.sin(x / f + i * ph + (sign < 0 ? 2 : 0)) + sign * 16 * bump * Math.sin(i * (sign > 0 ? 0.55 : 0.5) + (sign > 0 ? 0.8 : 1.4));
                            x ? ctx.lineTo(x, yy) : ctx.moveTo(x, yy);
                        }
                        ctx.stroke();
                    }
                }
            }
            NumberAnimation on x { from: 0; to: -80; duration: board.phase === "verify" ? 1000 : 6000; loops: Animation.Infinite }
        }
        Rectangle { y: 138; width: parent.width; height: 1; color: EvaStyle.white; opacity: 0.5 }

        Canvas { // 7-segment clock: HH MM SS, slanted, unlit segments faintly visible
            id: seven
            x: 26; y: 92; width: 440; height: 90 // 14 px to the left: the slant reaches past the first digit's box
            property string digits: { const d = clock.date; return board.pad(d.getHours()) + board.pad(d.getMinutes()) + board.pad(d.getSeconds()) }
            onDigitsChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                const w = 48, h = 88, t = 10, gp = 2, L = t / 2, R = w - t / 2, T = t / 2, M = h / 2, B = h - t / 2;
                const hz = (yc, x1, x2) => [[x1, yc], [x1 + t / 2, yc - t / 2], [x2 - t / 2, yc - t / 2], [x2, yc], [x2 - t / 2, yc + t / 2], [x1 + t / 2, yc + t / 2]];
                const vt = (xc, y1, y2) => [[xc, y1], [xc + t / 2, y1 + t / 2], [xc + t / 2, y2 - t / 2], [xc, y2], [xc - t / 2, y2 - t / 2], [xc - t / 2, y1 + t / 2]];
                const SEG = { a: hz(T, L + gp, R - gp), g: hz(M, L + gp, R - gp), d: hz(B, L + gp, R - gp),
                              f: vt(L, T + gp, M - gp), b: vt(R, T + gp, M - gp), e: vt(L, M + gp, B - gp), c: vt(R, M + gp, B - gp) };
                const MAP = ["abcdef", "bc", "abged", "abgcd", "fgbc", "afgcd", "afgedc", "abc", "abcdefg", "abcdfg"];
                const xs = [0, 56, 136, 192, 272, 328];
                const on = EvaStyle.orange.toString(), off = EvaStyle.segOff.toString();
                for (let i = 0; i < 6; i++) {
                    const n = Number(digits[i] ?? 0);
                    ctx.save();
                    ctx.translate(xs[i] + 14, 0);
                    ctx.transform(1, 0, Math.tan(-8 * Math.PI / 180), 1, 0, 0); // skewX(-8°)
                    for (const k of "abcdefg") {
                        const p = SEG[k];
                        ctx.fillStyle = MAP[n].includes(k) ? on : off;
                        ctx.beginPath();
                        ctx.moveTo(p[0][0], p[0][1]);
                        for (let j = 1; j < p.length; j++) ctx.lineTo(p[j][0], p[j][1]);
                        ctx.closePath();
                        ctx.fill();
                    }
                    ctx.restore();
                }
                ctx.fillStyle = on; // the colons
                for (const [x, y] of [[116, 24], [112, 56], [252, 24], [248, 56]]) ctx.fillRect(x + 14, y, 9, 9);
            }
            layer.enabled: EvaStyle.halo > 0
            layer.effect: MultiEffect { shadowEnabled: true; shadowColor: EvaStyle.orange; shadowBlur: 0.55 * EvaStyle.halo; shadowOpacity: 0.85; shadowHorizontalOffset: 0; shadowVerticalOffset: 0 }
        }

        EvaTag { x: 14; y: 14; jp: "時刻"; text: "LOCAL TIME" + (board.homeCity && Weather.zoneName(board.homeCity.id) ? " · " + Weather.zoneName(board.homeCity.id) : ""); fill: EvaStyle.bg }
        Glowing { anchors { right: parent.right; top: parent.top; rightMargin: 16; topMargin: 10 } text: "+" + String(Math.floor(clock.date.getTime() / 1000)).slice(-8); font.pixelSize: 30 }
        Glowing { anchors { right: parent.right; bottom: parent.bottom; rightMargin: 16; bottomMargin: 8 } text: "+" + ("00000000" + (Math.floor(clock.date.getTime() / 1000) % 86400 * 37)).slice(-8); font.pixelSize: 30 }
        EvaTag {
            x: 14; anchors.bottom: parent.bottom; anchors.bottomMargin: 14
            round: true; tint: EvaStyle.cyan; fill: EvaStyle.bg
            text: (board.awayCity ? (board.awayCity.short || board.awayCity.name) + " " + board.cityHm(board.awayCity) + " " + Weather.zoneText(board.awayCity.id) + " · " : "")
                + board.days[clock.date.getDay()] + " " + board.pad(clock.date.getDate()) + " " + board.months[clock.date.getMonth()]
        }
    }

    // ================= operator =================
    Panel {
        x: 656; y: 24; width: 504; height: 276

        EvaTag { x: 16; y: 14; jp: "操縦者"; text: "OPERATOR"; size: 16 }
        Item { // your picture, framed; the outline figure if there's none
            x: 16; y: 52; width: 132; height: 132
            Rectangle { anchors.fill: parent; radius: 8; color: "#140b02"; border.color: EvaStyle.orange; border.width: 2 }
            ClippingRectangle {
                anchors { fill: parent; margins: 2 }
                radius: 7
                color: "transparent"
                Image {
                    id: face
                    anchors.fill: parent
                    source: Theme.fileUrl(Quickshell.env("HOME") + "/.face.icon")
                    fillMode: Image.PreserveAspectCrop
                    sourceSize.width: 264
                    asynchronous: true
                    cache: false
                }
            }
            Canvas { // no picture: the outline figure
                anchors.fill: parent
                visible: face.status !== Image.Ready
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.strokeStyle = EvaStyle.orange.toString();
                    ctx.lineWidth = 3;
                    ctx.beginPath(); ctx.arc(66, 52, 23, 0, Math.PI * 2); ctx.stroke();
                    ctx.beginPath(); ctx.moveTo(22, 124); ctx.bezierCurveTo(28, 92, 104, 92, 110, 124); ctx.stroke();
                }
            }
            Repeater { // scanlines over the picture
                model: 43
                Rectangle { required property int index; y: 2 + index * 3; width: 132; height: 1; color: EvaStyle.bg; opacity: 0.55 }
            }
        }
        Text { x: 16; y: 190; text: "~/.face.icon"; color: EvaStyle.dim; font.family: EvaStyle.mono; font.pixelSize: 10 }
        Glowing { x: 166; y: 40; width: 280; text: board.user; color: EvaStyle.orange; font.pixelSize: 76; elide: Text.ElideRight; fontSizeMode: Text.HorizontalFit; minimumPixelSize: 36 }
        Column {
            x: 166; y: 124
            spacing: 6
            Repeater {
                model: [
                    { t: board.phase === "granted" ? "ACCESS GRANTED" : board.phase === "denied" ? "ACCESS DENIED" : "AUTHENTICATION REQUIRED", c: board.accent, op: 1 },
                    { t: "SESSION · HYPRLAND", c: EvaStyle.orange, op: 0.9 },
                    { t: "HOST · " + (board.host || "NIXOS") + " · NIXOS", c: EvaStyle.orange, op: 0.6 }
                ]
                Row {
                    required property var modelData
                    spacing: 6
                    EvaTag { width: 250; text: parent.modelData.t; tint: parent.modelData.c; size: 17 }
                    Rectangle { width: 12; height: 26; radius: 4; color: parent.modelData.c; opacity: parent.modelData.op }
                }
            }
        }
        Text { // 認証 written top to bottom
            anchors { right: parent.right; top: parent.top; rightMargin: 14; topMargin: 16 }
            width: 70
            text: "認\n証"
            lineHeight: 0.95
            horizontalAlignment: Text.AlignHCenter
            color: EvaStyle.white
            font.family: EvaStyle.jp
            font.weight: Font.ExtraBold
            font.pixelSize: 64
        }
    }

    // ================= weather =================
    Panel {
        x: 1176; y: 24; width: 400; height: 276

        Repeater {
            model: [
                ...Weather.cityList.map((c, i) => ({ id: c.id, name: (c.short || c.name).toUpperCase(), top: i * 138, color: i ? EvaStyle.cyan : EvaStyle.orange }))
            ]
            Item {
                id: wc
                required property var modelData
                readonly property var w: Weather.city(modelData.id)
                // the next 12 hours (fewer if the forecast ends sooner)
                readonly property var next: w && !w.offline ? w.hours.slice(w.nowH, w.nowH + 12) : []
                y: modelData.top
                width: 400; height: 138

                Canvas {
                    anchors.fill: parent
                    property var data: wc.next
                    onDataChanged: requestPaint()
                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.reset();
                        const cy = EvaStyle.cyan.toString(), or = EvaStyle.orange.toString();
                        ctx.strokeStyle = cy; ctx.globalAlpha = 0.7; ctx.lineWidth = 1; // + marks
                        for (let x = 40; x <= 380; x += 40) for (let y = 40; y <= 100; y += 30) {
                            ctx.beginPath(); ctx.moveTo(x - 4, y); ctx.lineTo(x + 4, y); ctx.moveTo(x, y - 4); ctx.lineTo(x, y + 4); ctx.stroke();
                        }
                        ctx.globalAlpha = 0.45;
                        for (const x of [70, 170, 270, 370]) { ctx.beginPath(); ctx.moveTo(x, 30); ctx.lineTo(x, 112); ctx.stroke() }
                        ctx.globalAlpha = 1;
                        const d = data ?? [];
                        if (d.length) {
                            ctx.fillStyle = cy; ctx.globalAlpha = 0.25; // rain bars
                            d.forEach((h, i) => { const r = Number(String(h.rainText).replace("%", "")) || 0; ctx.fillRect(20 + i * 31, 116 - r * 0.5, 22, r * 0.5) });
                            ctx.globalAlpha = 1;
                            const temps = d.map(h => h.temp);
                            const lo = Math.min(...temps) - 2, hi = Math.max(...temps) + 2;
                            ctx.strokeStyle = or; ctx.lineWidth = 2; ctx.beginPath(); // temperature, as steps
                            let lastY = 0;
                            temps.forEach((t, i) => {
                                const x = 20 + i * 31, y = 108 - ((t - lo) / (hi - lo)) * 70;
                                if (i === 0) ctx.moveTo(x, y); else { ctx.lineTo(x, lastY); ctx.lineTo(x, y) }
                                lastY = y;
                            });
                            ctx.lineTo(390, lastY);
                            ctx.stroke();
                        }
                        ctx.strokeStyle = or; ctx.lineWidth = 1; ctx.beginPath(); // scale
                        for (let x = 20; x <= 390; x += 5) { ctx.moveTo(x, 116); ctx.lineTo(x, x % 50 === 20 ? 108 : 113) }
                        ctx.moveTo(20, 116); ctx.lineTo(390, 116);
                        ctx.stroke();
                    }
                }
                EvaTag {
                    x: 12; y: 6; size: 16; fill: EvaStyle.bg
                    text: wc.modelData.name + " · " + board.cityHm(wc.modelData)
                }
                Glowing { anchors { right: parent.right; rightMargin: 14 } y: 0; text: wc.w && !wc.w.offline ? wc.w.temp + "°" : "--°"; color: wc.modelData.color; font.pixelSize: 34 }
                Plain {
                    anchors { right: parent.right; rightMargin: 14 } y: 40
                    width: 220; horizontalAlignment: Text.AlignRight; elide: Text.ElideRight
                    text: (wc.w === null ? "NO FORECAST" : wc.w.offline ? "OFFLINE · " + wc.w.since : wc.w.cond).toUpperCase()
                    color: EvaStyle.white; font.pixelSize: 13
                }
                Row { // hour marks under the graph
                    x: 14; y: 118
                    width: 376
                    Repeater {
                        model: 5
                        Plain {
                            required property int index
                            width: index < 4 ? 376 / 4.4 : 40
                            text: wc.next.length > index * 3 ? "+" + board.pad(wc.next[index * 3].hour) : ""
                            font.pixelSize: 12
                        }
                    }
                }
            }
        }
    }

    // ================= auth =================
    Panel {
        x: 24; y: 316; width: 836; height: 284

        EvaTag { x: 14; y: 14; jp: "認証"; text: "AUTH SEQUENCE" }
        Repeater { // SEG.1–8: one more lights up with each character, climbing like stairs
            model: 8
            Column {
                required property int index
                readonly property bool on: board.phase === "granted" || index < board.typed
                readonly property color col: board.phase === "denied" ? EvaStyle.red : board.phase === "granted" ? EvaStyle.green : EvaStyle.orange
                x: 30 + index * 96
                y: 172 - index * 13
                spacing: 2
                Plain { text: "SEG." + (parent.index + 1); font.pixelSize: 12; color: parent.on ? parent.col : EvaStyle.dark }
                Rectangle {
                    width: 96; height: 20; radius: 5
                    border.width: 2
                    border.color: parent.on ? parent.col : EvaStyle.line
                    color: parent.on ? parent.col : "transparent"
                    layer.enabled: parent.on && EvaStyle.halo > 0
                    layer.effect: MultiEffect { shadowEnabled: true; shadowColor: parent.col; shadowBlur: 0.6 * EvaStyle.halo; shadowOpacity: 0.9; shadowHorizontalOffset: 0; shadowVerticalOffset: 0 }
                }
            }
        }
        readonly property bool clear: board.typed >= 4 || board.phase === "granted"
        Rectangle { y: 214; width: parent.width; height: 2; color: parent.clear ? EvaStyle.green : EvaStyle.cyan }
        EvaTag { x: 340; y: 203; round: true; size: 16; fill: EvaStyle.bg; tint: parent.clear ? EvaStyle.green : EvaStyle.cyan; text: "BORDER LINE" + (parent.clear ? " · CLEAR" : "") }

        // status, top right
        Column {
            anchors { right: parent.right; top: parent.top; rightMargin: 16; topMargin: 14 }
            spacing: 4
            EvaTag {
                anchors.right: parent.right
                jp: board.st.jp; text: board.st.en; tint: board.accent; size: 30
                SequentialAnimation on opacity { running: board.st.blink; loops: Animation.Infinite; alwaysRunToEnd: true
                    PropertyAction { value: 1 } PauseAnimation { duration: 350 } PropertyAction { value: 0.15 } PauseAnimation { duration: 350 } }
            }
            Plain {
                anchors.right: parent.right
                text: board.message ? board.message.toUpperCase() : board.caps ? "▲ CAPS LOCK ON" : "LAYOUT EN · CAPS OFF"
                color: board.caps && !board.message ? EvaStyle.yellow : board.message ? board.accent : EvaStyle.dim
                font.pixelSize: 14
            }
        }

        // passcode
        Row {
            x: 14; y: 228
            spacing: 8
            EvaTag { anchors.verticalCenter: parent.verticalCenter; text: "PASSCODE"; size: 16 }
            Rectangle {
                width: 806 - 120 - 8 * 2 - 110; height: 44
                radius: 7
                color: "#0d0702"
                border.color: board.accent
                border.width: 2
                TextInput {
                    id: pass
                    anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                    verticalAlignment: TextInput.AlignVCenter
                    echoMode: TextInput.Password
                    passwordCharacter: "●"
                    color: board.accent
                    font.family: EvaStyle.sans
                    font.bold: true
                    font.pixelSize: 26
                    font.letterSpacing: 10
                    focus: true
                    readOnly: board.phase === "verify" || board.phase === "granted"
                    clip: true
                    onAccepted: board.submit(text)
                    Keys.onEscapePressed: text = ""
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: pass.text === ""
                        text: "ENTER PASSCODE"
                        color: EvaStyle.dark
                        font.family: EvaStyle.sans
                        font.bold: true
                        font.pixelSize: 22
                        font.letterSpacing: 4
                    }
                }
            }
            Rectangle {
                width: 120; height: 44; radius: 7
                color: board.accent
                Plain { anchors.centerIn: parent; text: "ENTER"; color: EvaStyle.bg; font.pixelSize: 22; font.letterSpacing: 2 }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: board.submit(pass.text) }
            }
        }
    }

    // ================= system =================
    Panel {
        x: 876; y: 316; width: 700; height: 284

        readonly property var batt: UPower.displayDevice
        readonly property var sink: Pipewire.defaultAudioSink
        PwObjectTracker { objects: [parent.sink] }

        EvaTag { x: 14; y: 14; jp: "状態"; text: "SYSTEM STATUS" }
        EvaTag {
            anchors { right: parent.right; top: parent.top; rightMargin: 14; topMargin: 14 }
            round: true; size: 16
            readonly property bool hot: Stats.cpu > 0.85 || Stats.cpuTemp > 85 || ((parent.batt?.percentage ?? 1) < 0.15 && parent.batt?.state !== UPowerDeviceState.Charging)
            tint: hot ? EvaStyle.red : EvaStyle.cyan
            text: hot ? "CHECK SYSTEMS" : "SYSTEMS ARE GREEN"
        }
        Row {
            x: 20; y: 56
            spacing: 22
            Repeater {
                model: [
                    { k: "CPU",  f: Stats.cpu, v: Math.round(Stats.cpu * 100) + "%" },
                    { k: "TEMP", f: Stats.cpuTemp / 100, v: Stats.cpuTemp ? Stats.cpuTemp + "°C" : "--" },
                    { k: "MEM",  f: Stats.mem, v: Stats.memUsedGb.toFixed(1) + "G" },
                    { k: "BATT", f: parent.parent.batt?.percentage ?? 0, v: parent.parent.batt?.isLaptopBattery ? Math.round(parent.parent.batt.percentage * 100) + "%" : "AC" },
                    { k: "WLAN", f: Net.online ? Net.signal / 100 : 0, v: Net.wired ? "WIRED" : Net.ssid ? Net.signal + "%" : "OFF" },
                    { k: "VOL",  f: parent.parent.sink?.audio?.muted ? 0 : (parent.parent.sink?.audio?.volume ?? 0), v: parent.parent.sink?.audio?.muted ? "MUTE" : Math.round((parent.parent.sink?.audio?.volume ?? 0) * 100) + "%" },
                    { k: "GPU",  f: Stats.gpuAsleep ? 0 : 1, v: !Stats.hasGpu ? "--" : Stats.gpuAsleep ? "SLEEP" : "AWAKE" }
                ]
                Column {
                    id: meter
                    required property var modelData
                    readonly property int lit: Math.max(0, Math.min(10, Math.round(modelData.f * 10)))
                    spacing: 5
                    Plain { anchors.horizontalCenter: parent.horizontalCenter; text: meter.modelData.k; color: EvaStyle.cyan; font.pixelSize: 13 }
                    Column { // 10 LEDs, filled from the bottom; the top two turn red
                        spacing: 4
                        Repeater {
                            model: 10
                            Rectangle {
                                required property int index
                                readonly property int level: 9 - index
                                readonly property bool on: level < meter.lit
                                width: 72; height: 11; radius: 3
                                color: on ? (level >= 8 ? EvaStyle.hot : EvaStyle.cyan) : EvaStyle.ledOff
                                layer.enabled: on && EvaStyle.halo > 0
                                layer.effect: MultiEffect { shadowEnabled: true; shadowColor: color; shadowBlur: 0.4 * EvaStyle.halo; shadowOpacity: 0.9; shadowHorizontalOffset: 0; shadowVerticalOffset: 0 }
                            }
                        }
                    }
                    Glowing { anchors.horizontalCenter: parent.horizontalCenter; text: meter.modelData.v; font.pixelSize: 20 }
                }
            }
        }
    }

    // ================= audio =================
    Panel {
        id: audio
        x: 24; y: 616; width: 736; height: 260

        EvaTag { x: 14; y: 14; jp: "音響"; text: "AUDIO · " + (Media.hasPlayer ? (Media.app || "PLAYER") : "OFFLINE"); z: 2 }

        Row {
            visible: Media.hasPlayer
            x: 14; y: 52
            spacing: 16
            Item {
                width: 132; height: 132
                Rectangle { anchors.fill: parent; radius: 8; color: "#140b02"; border.color: EvaStyle.cyan; border.width: 2 }
                ClippingRectangle {
                    anchors { fill: parent; margins: 2 }
                    radius: 7
                    color: "transparent"
                    Image { anchors.fill: parent; source: Media.art; fillMode: Image.PreserveAspectCrop; sourceSize.width: 264; asynchronous: true }
                }
                Repeater { model: 43; Rectangle { required property int index; y: 2 + index * 3; width: 132; height: 1; color: EvaStyle.bg; opacity: 0.5 } }
            }
            Column {
                width: 736 - 28 - 132 - 16
                spacing: 6
                Glowing { width: parent.width; text: (Media.title || "UNKNOWN").toUpperCase(); font.pixelSize: 44; elide: Text.ElideRight }
                Plain { width: parent.width; text: [Media.artist, Media.album].filter(x => x).join(" · ").toUpperCase(); font.pixelSize: 18; font.letterSpacing: 2; elide: Text.ElideRight }
                Item { // ticks + progress
                    width: 560; height: 24
                    Canvas {
                        anchors.fill: parent
                        onPaint: {
                            const ctx = getContext("2d");
                            ctx.strokeStyle = EvaStyle.orange.toString();
                            ctx.beginPath();
                            for (let x = 0; x <= 560; x += 4) { ctx.moveTo(x, 10); ctx.lineTo(x, x % 40 === 0 ? 2 : 7) }
                            ctx.stroke();
                        }
                    }
                    Rectangle { y: 12; height: 8; radius: 3; width: 560 * Media.progress; color: EvaStyle.orange }
                }
                RowLayout {
                    width: parent.width
                    spacing: 8
                    Text { text: Media.time(Media.position) + " / " + (Media.length > 0 ? Media.time(Media.length) : "--:--"); color: EvaStyle.cyan; font.family: EvaStyle.mono; font.pixelSize: 13 }
                    Item { Layout.fillWidth: true }
                    EvaTag { text: "PREV"; size: 16; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Media.previous() } }
                    Rectangle {
                        implicitWidth: playWord.implicitWidth + 36; implicitHeight: 34; radius: 7; color: EvaStyle.orange
                        Plain { id: playWord; anchors.centerIn: parent; text: Media.playing ? "PAUSE" : "PLAY"; color: EvaStyle.bg; font.pixelSize: 18 }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Media.toggle() }
                    }
                    EvaTag { text: "NEXT"; size: 16; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Media.next() } }
                }
                Text {
                    width: parent.width
                    text: !Media.playing ? "— PAUSED —" : Media.hasLyrics ? (Media.lyricNow || "· · ·") : "· · ·"
                    color: Media.playing ? EvaStyle.white : EvaStyle.dark
                    font.family: EvaStyle.jp
                    font.weight: Font.ExtraBold
                    font.pixelSize: 22
                    elide: Text.ElideRight
                }
            }
        }

        // nothing playing: hazard stripes, a red X, MUSIC OFFLINE
        Item {
            anchors.fill: parent
            visible: !Media.hasPlayer
            Canvas {
                anchors.fill: parent
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.fillStyle = "rgba(90,50,16,0.3)";
                    for (let k = -height; k < width + height; k += 12) {
                        ctx.beginPath(); ctx.moveTo(k, 0); ctx.lineTo(k + 6, 0); ctx.lineTo(k + 6 - height, height); ctx.lineTo(k - height, height); ctx.closePath(); ctx.fill();
                    }
                    ctx.strokeStyle = EvaStyle.red.toString(); ctx.lineWidth = 3;
                    ctx.beginPath(); ctx.moveTo(2, 2); ctx.lineTo(width - 2, height - 2); ctx.moveTo(width - 2, 2); ctx.lineTo(2, height - 2); ctx.stroke();
                }
            }
            Column {
                anchors.centerIn: parent
                spacing: 4
                EvaTag {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "MUSIC OFFLINE"; tint: EvaStyle.red; size: 44; fill: EvaStyle.bg
                    SequentialAnimation on opacity { loops: Animation.Infinite
                        PropertyAction { value: 1 } PauseAnimation { duration: 350 } PropertyAction { value: 0.15 } PauseAnimation { duration: 350 } }
                }
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: jpOff.implicitWidth + 20; height: jpOff.implicitHeight; color: EvaStyle.bg
                    Text { id: jpOff; anchors.centerIn: parent; text: "音響 停止"; color: EvaStyle.white; font.family: EvaStyle.jp; font.weight: Font.ExtraBold; font.pixelSize: 20 }
                }
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: offNote.implicitWidth + 16; height: offNote.implicitHeight; color: EvaStyle.bg
                    Text { id: offNote; anchors.centerIn: parent; text: "NO PLAYER RUNNING"; color: EvaStyle.dim; font.family: EvaStyle.mono; font.pixelSize: 11 }
                }
            }
        }
    }

    // ================= tailnet =================
    Rectangle {
        x: 776; y: 616; width: 484; height: 260
        color: EvaStyle.board
        border.color: EvaStyle.line
        clip: true

        Canvas { // traces, vias and chips
            anchors.fill: parent
            onPaint: {
                const ctx = getContext("2d");
                const ink = EvaStyle.boardInk.toString();
                ctx.strokeStyle = ink; ctx.fillStyle = ink; ctx.lineWidth = 2;
                for (let i = 0; i < 11; i++) {
                    const sx = -40 + i * 34, sy = 270, bx = sx + 150, by = sy - 150;
                    ctx.beginPath(); ctx.moveTo(sx, sy); ctx.lineTo(bx, by); ctx.lineTo(500, by); ctx.stroke();
                    ctx.beginPath(); ctx.arc(bx, by, 5, 0, Math.PI * 2); ctx.fill();
                }
                for (let i = 0; i < 6; i++) { ctx.beginPath(); ctx.moveTo(-20 + i * 30, 0); ctx.lineTo(120 + i * 30, 140); ctx.stroke() }
                ctx.font = "10px '" + EvaStyle.mono + "'";
                ctx.textAlign = "center";
                for (let i = 0; i < 8; i++) {
                    const t = 0.32 + (i % 3) * 0.12, x = -40 + i * 34 + 150 * t, y = 270 - 150 * t;
                    ctx.save(); ctx.translate(x, y); ctx.rotate(-Math.PI / 4);
                    ctx.fillStyle = "#140b02"; ctx.fillRect(-26, -8, 52, 16);
                    ctx.fillStyle = EvaStyle.green.toString(); ctx.fillText("00" + (128 + i), 0, 4);
                    ctx.restore();
                }
            }
        }
        EvaTag {
            x: 12; y: 12; size: 16; tint: "#140b02"; fill: "#ff9a3a"; layer.enabled: false
            jp: "回線"; text: "TAILNET " + (Vpn.tsOn ? Vpn.peersOnline + "/" + Vpn.peers.length : Vpn.tsState === "NeedsLogin" ? "SIGN IN" : "OFF")
        }
        Column {
            anchors { right: parent.right; top: parent.top; rightMargin: 12; topMargin: 54 }
            spacing: 6
            Repeater {
                model: [...Vpn.peers.slice(0, 3).map((p, i) => ({
                            n: "00" + (227 + i * 3), name: p.name.toUpperCase(),
                            s: p.online ? (p.direct ? "DIRECT" : "RELAY") : "OFF" + (p.seen ? " " + p.seen.replace(/ ago| min/g, m => m === " min" ? "M" : "").replace(" h", "H").replace(" d", "D") : ""),
                            c: p.online ? EvaStyle.green : EvaStyle.red })),
                        { n: "00236", name: "SURFSHARK VPN", s: Vpn.vpnOn ? "ON" : Vpn.vpnName ? "OFF" : "NOT SET UP", c: Vpn.vpnOn ? EvaStyle.green : EvaStyle.dim }]
                Rectangle {
                    required property var modelData
                    width: 236; height: 30
                    color: "#140b02"
                    RowLayout {
                        anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                        spacing: 8
                        Text { text: modelData.n; color: EvaStyle.dim; font.family: EvaStyle.mono; font.pixelSize: 11 }
                        Plain { Layout.fillWidth: true; text: modelData.name; color: modelData.c; font.pixelSize: 15; elide: Text.ElideRight }
                        Text { text: modelData.s; color: modelData.c; font.family: EvaStyle.mono; font.pixelSize: 10 }
                    }
                }
            }
        }
    }

    // ================= power =================
    Panel {
        x: 1276; y: 616; width: 300; height: 260

        property string armed: "" // restart / shut down wait for a second press
        Timer { id: disarm; interval: 4000; onTriggered: parent.armed = "" }

        EvaTag { x: 14; y: 14; jp: "電源"; text: "POWER" }
        Column {
            x: 14; y: 54
            spacing: 8
            Repeater {
                model: [
                    { id: "suspend",  jp: "休止",   en: "SUSPEND",   cmd: "systemctl suspend", confirm: false },
                    { id: "reboot",   jp: "再起動", en: "RESTART",   cmd: "systemctl reboot", confirm: true },
                    { id: "poweroff", jp: "停止",   en: "SHUT DOWN", cmd: "systemctl poweroff", confirm: true }
                ]
                Rectangle {
                    id: pb
                    required property var modelData
                    readonly property bool armed: parent.parent.armed === modelData.id
                    width: 272; height: 40; radius: 7
                    color: armed ? EvaStyle.red : "transparent"
                    border.color: armed ? EvaStyle.red : EvaStyle.orange
                    border.width: 2
                    RowLayout {
                        anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                        Text { text: pb.modelData.jp; color: pb.armed ? EvaStyle.bg : EvaStyle.orange; font.family: EvaStyle.jp; font.weight: Font.ExtraBold; font.pixelSize: 15 }
                        Item { Layout.fillWidth: true }
                        Plain { text: pb.armed ? "PRESS AGAIN" : pb.modelData.en; color: pb.armed ? EvaStyle.bg : EvaStyle.orange; font.pixelSize: 20 }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            const panel = pb.parent.parent;
                            if (pb.modelData.confirm && panel.armed !== pb.modelData.id) { panel.armed = pb.modelData.id; disarm.restart(); return }
                            panel.armed = "";
                            Quickshell.execDetached(["sh", "-c", pb.modelData.cmd]);
                        }
                    }
                }
            }
        }
        RowLayout {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 14 }
            EvaTag { round: true; tint: EvaStyle.cyan; size: 15; text: Notifs.count ? "MESSAGES " + board.pad(Notifs.count) : "NO MESSAGES" }
            Item { Layout.fillWidth: true }
            Glowing { text: board.generation ? "NIX GEN " + board.generation : "NIXOS"; font.pixelSize: 15 }
        }
    }

    // ================= CRT: scanlines, vignette, a faint flicker =================
    Item {
        anchors.fill: parent
        visible: EvaStyle.glow !== "off"
        opacity: EvaStyle.glow === "soft" ? 0.45 : 1
        Canvas {
            id: crt
            anchors.fill: parent
            onPaint: {
                const ctx = getContext("2d");
                ctx.fillStyle = "rgba(0,0,0,0.28)";
                for (let y = 0; y < height; y += 3) ctx.fillRect(0, y, width, 1);

            }
        }
        Shape { // vignette: darker towards the edges (a Shape: Canvas's radial gradient went all black)
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeWidth: 0
                strokeColor: "transparent"
                fillGradient: RadialGradient {
                    centerX: 800; centerY: 450; centerRadius: 990
                    focalX: 800; focalY: 450
                    GradientStop { position: 0.45; color: "transparent" }
                    GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.55) }
                }
                startX: 0; startY: 0
                PathLine { x: 1600; y: 0 }
                PathLine { x: 1600; y: 900 }
                PathLine { x: 0; y: 900 }
                PathLine { x: 0; y: 0 }
            }
        }
        SequentialAnimation { // the flicker, on the scanlines only (the Item's opacity is the glow level)
            running: parent.visible
            loops: Animation.Infinite
            NumberAnimation { target: crt; property: "opacity"; to: 0.94; duration: 1900 }
            NumberAnimation { target: crt; property: "opacity"; to: 0.86; duration: 80 }
            NumberAnimation { target: crt; property: "opacity"; to: 0.96; duration: 80 }
            NumberAnimation { target: crt; property: "opacity"; to: 1; duration: 1900 }
        }
    }
}
