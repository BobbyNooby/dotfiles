// The login screen: the Eva 7 "Signal board" (same look as the Quickshell lock screen,
// dotfiles/quickshell/EvaBoard.qml). Drawn at 1600×900 and scaled to the screen.
//
// SDDM can't run commands or read your home folder, so live data comes from
// /run/greeter-status.json (battery, Tailscale, weather, meters), written every minute by the
// greeter-status service (modules/login-screen.nix), and your picture from /run/greeter-face.
// The UK-style second clock comes from the forecast's UTC offset (refreshed every minute), with
// the fixed UK daylight-saving rule as a fallback. Music is always offline before login.
//
// Test without logging out: sddm-greeter-qt6 --test-mode --theme <this folder>
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Shapes

Rectangle {
    id: root
    width: 1920
    height: 1080
    color: c.bg

    // ---- palette and type (fixed: the Eva look) ----
    QtObject {
        id: c
        readonly property color bg: "#050505"
        readonly property color orange: "#ff8a1e"
        readonly property color cyan: "#2de1c2"
        readonly property color green: "#3cff7a"
        readonly property color red: "#ff3b2a"
        readonly property color yellow: "#ffd400"
        readonly property color white: "#f4f1ea"
        readonly property color dim: "#8a5a2a"
        readonly property color dark: "#5a3210"
        readonly property color line: "#3a2008"
        readonly property color segOff: "#221204"
        readonly property color ledOff: "#0c2622"
        readonly property color hot: "#ff3b5c"
        readonly property color boardFill: "#b85f10"
        readonly property color boardInk: "#2a1404"
        readonly property string sans: "TeX Gyre Heros Cn"
        readonly property string jp: "Shippori Mincho B1"
        readonly property string mono: "Share Tech Mono"
    }
    readonly property string glow: (typeof config !== "undefined" && config.glow) ? config.glow : "strong"
    readonly property real halo: glow === "strong" ? 1 : glow === "soft" ? 0.45 : 0

    // ---- status file ----
    property var st: ({})
    function loadStatus() {
        const x = new XMLHttpRequest();
        x.onreadystatechange = () => {
            if (x.readyState !== XMLHttpRequest.DONE) return;
            try { if (x.responseText) root.st = JSON.parse(x.responseText) } catch (e) {}
        };
        x.open("GET", "file://" + ((typeof config !== "undefined" && config.statusFile) || "/run/greeter-status.json"));
        x.send();
    }
    Timer { interval: 20000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.loadStatus() }

    // ---- time ----
    property date now: new Date()
    Timer { interval: 1000; running: true; repeat: true; onTriggered: root.now = new Date() }
    function pad(n) { return (n < 10 ? "0" : "") + n }
    readonly property var days: ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]
    readonly property var months: ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]
    readonly property var cities: st.cities ?? []
    readonly property var home: cities[0] ?? null
    readonly property var away: cities[1] ?? null
    // UK daylight saving: last Sunday of March to last Sunday of October, 01:00 UTC
    function ukOffsetMin(d) {
        const y = d.getUTCFullYear();
        const lastSun = m => { const t = new Date(Date.UTC(y, m + 1, 0, 1)); t.setUTCDate(t.getUTCDate() - t.getUTCDay()); return t };
        return d >= lastSun(2) && d < lastSun(9) ? 60 : 0;
    }
    // A city's UTC offset in minutes: from its forecast, else the UK rule for London, else none
    function offsetMin(city) {
        const w = city ? st.weather?.[city.id] : null;
        if (w && w.utc_offset_seconds !== undefined) return w.utc_offset_seconds / 60;
        if (city?.tz === "Europe/London") return ukOffsetMin(now);
        return null;
    }
    function cityDate(city) { now; const o = offsetMin(city); return o === null ? null : new Date(now.getTime() + o * 60000) }
    function cityHm(city) { const d = cityDate(city); return d ? pad(d.getUTCHours()) + ":" + pad(d.getUTCMinutes()) : "--:--" }
    function zoneName(city) {
        if (!city) return "";
        if (city.zone) return city.zone;
        if (city.tz === "Europe/London") return ukOffsetMin(now) ? "BST" : "GMT";
        return "";
    }
    function awayRel() {
        const a = offsetMin(away), h = -now.getTimezoneOffset();
        if (a === null) return "";
        const diff = Math.round((a - h) / 60);
        return diff === 0 ? "SAME TIME" : (diff > 0 ? "+" : "−") + Math.abs(diff) + "H";
    }

    // ---- login state ----
    property string phase: "idle" // idle | verify | granted | denied
    readonly property var phaseInfo: ({
        idle:    { jp: "待機",   en: "STANDBY",   col: c.orange, blink: false },
        verify:  { jp: "照合中", en: "VERIFYING", col: c.yellow, blink: true },
        granted: { jp: "承認",   en: "GRANTED",   col: c.green,  blink: false },
        denied:  { jp: "拒否",   en: "DENIED",    col: c.red,    blink: true }
    })[phase]
    readonly property color accent: phaseInfo.col
    // who logs in: the last user, else the first one SDDM lists (first boot)
    property var userNames: []
    readonly property string userName: userModel.lastUser || userNames[0] || ""
    Repeater {
        model: userModel
        Item { required property int index; required property string name; Component.onCompleted: { const n = root.userNames.slice(); n[index] = name; root.userNames = n } }
    }
    property int sessionIndex: sessionModel.lastIndex >= 0 ? sessionModel.lastIndex : 0
    property var sessionNames: []
    Repeater { // read the session names (SDDM only offers them as a model)
        model: sessionModel
        Item { required property int index; required property string name; Component.onCompleted: { const n = root.sessionNames.slice(); n[index] = name; root.sessionNames = n } }
    }
    function submit() {
        if (phase === "verify" || phase === "granted" || pass.text === "") return;
        phase = "verify";
        sddm.login(userName, pass.text, sessionIndex);
    }
    Connections {
        target: sddm
        function onLoginFailed() { root.phase = "denied"; pass.text = ""; back.restart() }
        function onLoginSucceeded() { root.phase = "granted" }
    }
    Timer { id: back; interval: 2200; onTriggered: if (root.phase === "denied") { root.phase = "idle"; pass.forceActiveFocus() } }

    // ===================================================================
    Item {
        id: board
        width: 1600
        height: 900
        anchors.centerIn: parent
        scale: Math.min(root.width / width, root.height / height)

        component Panel: Rectangle { color: "transparent"; border.color: "#3a2008"; border.width: 1; clip: true }
        component Big: Text {
            color: "#f4f1ea"; font.family: "TeX Gyre Heros Cn"; font.bold: true
            layer.enabled: root.halo > 0
            layer.effect: MultiEffect { shadowEnabled: true; shadowColor: "white"; shadowBlur: 0.45 * root.halo; shadowOpacity: 0.7; shadowHorizontalOffset: 0; shadowVerticalOffset: 0 }
        }
        component Plain: Text { color: "#ff8a1e"; font.family: "TeX Gyre Heros Cn"; font.bold: true }

        MouseArea { anchors.fill: parent; onPressed: m => { pass.forceActiveFocus(); m.accepted = false } }

        // ---------------- time ----------------
        Panel {
            x: 24; y: 24; width: 616; height: 276
            Canvas {
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
                NumberAnimation on x { from: 0; to: -80; duration: root.phase === "verify" ? 1000 : 6000; loops: Animation.Infinite }
            }
            Rectangle { y: 138; width: parent.width; height: 1; color: c.white; opacity: 0.5 }
            Canvas {
                x: 26; y: 92; width: 440; height: 90 // 14 px to the left: the slant reaches past the first digit's box
                property string digits: root.pad(root.now.getHours()) + root.pad(root.now.getMinutes()) + root.pad(root.now.getSeconds())
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
                    for (let i = 0; i < 6; i++) {
                        const n = Number(digits[i] ?? 0);
                        ctx.save();
                        ctx.translate(xs[i] + 14, 0);
                        ctx.transform(1, 0, Math.tan(-8 * Math.PI / 180), 1, 0, 0);
                        for (const k of "abcdefg") {
                            const p = SEG[k];
                            ctx.fillStyle = MAP[n].includes(k) ? "#ff8a1e" : "#221204";
                            ctx.beginPath();
                            ctx.moveTo(p[0][0], p[0][1]);
                            for (let j = 1; j < p.length; j++) ctx.lineTo(p[j][0], p[j][1]);
                            ctx.closePath();
                            ctx.fill();
                        }
                        ctx.restore();
                    }
                    ctx.fillStyle = "#ff8a1e";
                    for (const [x, y] of [[116, 24], [112, 56], [252, 24], [248, 56]]) ctx.fillRect(x + 14, y, 9, 9);
                }
                layer.enabled: root.halo > 0
                layer.effect: MultiEffect { shadowEnabled: true; shadowColor: "#ff8a1e"; shadowBlur: 0.55 * root.halo; shadowOpacity: 0.85; shadowHorizontalOffset: 0; shadowVerticalOffset: 0 }
            }
            EvaTag { x: 14; y: 14; jp: "時刻"; text: "LOCAL TIME" + (root.zoneName(root.home) ? " · " + root.zoneName(root.home) : ""); fill: c.bg; halo: root.halo }
            Big { anchors { right: parent.right; top: parent.top; rightMargin: 16; topMargin: 10 } text: "+" + String(Math.floor(root.now.getTime() / 1000)).slice(-8); font.pixelSize: 30 }
            Big { anchors { right: parent.right; bottom: parent.bottom; rightMargin: 16; bottomMargin: 8 } text: "+" + ("00000000" + (Math.floor(root.now.getTime() / 1000) % 86400 * 37)).slice(-8); font.pixelSize: 30 }
            EvaTag {
                x: 14; anchors.bottom: parent.bottom; anchors.bottomMargin: 14
                round: true; tint: c.cyan; fill: c.bg; halo: root.halo
                text: (root.away ? (root.away.short || root.away.name) + " " + root.cityHm(root.away) + " " + root.zoneName(root.away) + " " + root.awayRel() + " · " : "")
                    + root.days[root.now.getDay()] + " " + root.pad(root.now.getDate()) + " " + root.months[root.now.getMonth()]
            }
        }

        // ---------------- operator ----------------
        Panel {
            x: 656; y: 24; width: 504; height: 276
            EvaTag { x: 16; y: 14; jp: "操縦者"; text: "OPERATOR"; size: 16; halo: root.halo }
            Item {
                x: 16; y: 52; width: 132; height: 132
                Rectangle { anchors.fill: parent; radius: 8; color: "#140b02"; border.color: c.orange; border.width: 2 }
                Image {
                    id: face
                    anchors { fill: parent; margins: 3 }
                    source: "file://" + ((typeof config !== "undefined" && config.faceFile) || "/run/greeter-face")
                    fillMode: Image.PreserveAspectCrop
                    sourceSize.width: 264
                    cache: false
                }
                Canvas {
                    anchors.fill: parent
                    visible: face.status !== Image.Ready
                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.strokeStyle = "#ff8a1e"; ctx.lineWidth = 3;
                        ctx.beginPath(); ctx.arc(66, 52, 23, 0, Math.PI * 2); ctx.stroke();
                        ctx.beginPath(); ctx.moveTo(22, 124); ctx.bezierCurveTo(28, 92, 104, 92, 110, 124); ctx.stroke();
                    }
                }
                Repeater { model: 43; Rectangle { required property int index; y: 2 + index * 3; width: 132; height: 1; color: "#050505"; opacity: 0.55 } }
            }
            Big { x: 166; y: 40; width: 280; text: root.userName.toUpperCase(); color: c.orange; font.pixelSize: 76; elide: Text.ElideRight; fontSizeMode: Text.HorizontalFit; minimumPixelSize: 36 }
            Column {
                x: 166; y: 124
                spacing: 6
                Repeater {
                    model: [
                        { t: root.phase === "granted" ? "ACCESS GRANTED" : root.phase === "denied" ? "ACCESS DENIED" : "AUTHENTICATION REQUIRED", col: root.accent, op: 1 },
                        { t: "SESSION · " + (root.sessionNames[root.sessionIndex] || "—").replace(/ \(.*\)$/, "").toUpperCase(), col: c.orange, op: 0.9, session: true },
                        { t: "HOST · " + (root.st.host || "NIXOS").toUpperCase() + " · NIXOS", col: c.orange, op: 0.6 }
                    ]
                    Row {
                        id: lab
                        required property var modelData
                        spacing: 6
                        EvaTag {
                            width: 250; text: lab.modelData.t; tint: lab.modelData.col; size: 17; halo: root.halo
                            MouseArea { // click the session line to pick the next session
                                anchors.fill: parent
                                enabled: !!lab.modelData.session
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: root.sessionIndex = (root.sessionIndex + 1) % Math.max(1, root.sessionNames.length)
                            }
                        }
                        Rectangle { width: 12; height: 26; radius: 4; color: lab.modelData.col; opacity: lab.modelData.op }
                    }
                }
            }
            Text { anchors { right: parent.right; top: parent.top; rightMargin: 14; topMargin: 16 } width: 70; text: "認\n証"; lineHeight: 0.95; horizontalAlignment: Text.AlignHCenter; color: c.white; font.family: c.jp; font.weight: Font.ExtraBold; font.pixelSize: 64 }
        }

        // ---------------- weather ----------------
        Panel {
            x: 1176; y: 24; width: 400; height: 276
            Repeater {
                model: root.cities.slice(0, 2)
                Item {
                    id: wc
                    required property var modelData
                    required property int index
                    readonly property var w: root.st.weather?.[modelData.id] ?? null
                    // the next 12 hours, from this hour in the city's own time
                    readonly property var next: {
                        if (!w?.hourly) return [];
                        const d = root.cityDate(modelData);
                        if (!d) return [];
                        const key = d.getUTCFullYear() + "-" + root.pad(d.getUTCMonth() + 1) + "-" + root.pad(d.getUTCDate()) + "T" + root.pad(d.getUTCHours()) + ":00";
                        const i = w.hourly.time.indexOf(key);
                        if (i < 0) return [];
                        const out = [];
                        for (let k = i; k < Math.min(i + 12, w.hourly.time.length); k++)
                            out.push({ hour: Number(w.hourly.time[k].slice(11, 13)), temp: Math.round(w.hourly.temperature_2m[k]), rain: w.hourly.precipitation_probability[k] ?? 0, code: w.hourly.weather_code[k] });
                        return out;
                    }
                    function cond(code) {
                        if (code === undefined) return "";
                        if (code <= 1) return "CLEAR"; if (code === 2) return "PARTLY CLOUDY"; if (code === 3) return "CLOUDY";
                        if (code === 45 || code === 48) return "FOG"; if (code >= 95) return "THUNDERSTORMS";
                        if ((code >= 71 && code <= 77) || code === 85 || code === 86) return "SNOW";
                        if (code >= 51 && code <= 57) return "DRIZZLE"; return "RAIN";
                    }
                    y: index * 138
                    width: 400; height: 138
                    Canvas {
                        anchors.fill: parent
                        property var data: wc.next
                        onDataChanged: requestPaint()
                        onPaint: {
                            const ctx = getContext("2d");
                            ctx.reset();
                            ctx.strokeStyle = "#2de1c2"; ctx.globalAlpha = 0.7; ctx.lineWidth = 1;
                            for (let x = 40; x <= 380; x += 40) for (let y = 40; y <= 100; y += 30) { ctx.beginPath(); ctx.moveTo(x - 4, y); ctx.lineTo(x + 4, y); ctx.moveTo(x, y - 4); ctx.lineTo(x, y + 4); ctx.stroke() }
                            ctx.globalAlpha = 0.45;
                            for (const x of [70, 170, 270, 370]) { ctx.beginPath(); ctx.moveTo(x, 30); ctx.lineTo(x, 112); ctx.stroke() }
                            ctx.globalAlpha = 1;
                            const d = data ?? [];
                            if (d.length) {
                                ctx.fillStyle = "#2de1c2"; ctx.globalAlpha = 0.25;
                                d.forEach((h, i) => ctx.fillRect(20 + i * 31, 116 - h.rain * 0.5, 22, h.rain * 0.5));
                                ctx.globalAlpha = 1;
                                const temps = d.map(h => h.temp), lo = Math.min(...temps) - 2, hi = Math.max(...temps) + 2;
                                ctx.strokeStyle = "#ff8a1e"; ctx.lineWidth = 2; ctx.beginPath();
                                let lastY = 0;
                                temps.forEach((t, i) => { const x = 20 + i * 31, y = 108 - ((t - lo) / (hi - lo)) * 70; if (i === 0) ctx.moveTo(x, y); else { ctx.lineTo(x, lastY); ctx.lineTo(x, y) } lastY = y });
                                ctx.lineTo(390, lastY); ctx.stroke();
                            }
                            ctx.strokeStyle = "#ff8a1e"; ctx.lineWidth = 1; ctx.beginPath();
                            for (let x = 20; x <= 390; x += 5) { ctx.moveTo(x, 116); ctx.lineTo(x, x % 50 === 20 ? 108 : 113) }
                            ctx.moveTo(20, 116); ctx.lineTo(390, 116); ctx.stroke();
                        }
                    }
                    EvaTag { x: 12; y: 6; size: 16; fill: c.bg; halo: root.halo; text: (wc.modelData.short || wc.modelData.name) + " · " + root.cityHm(wc.modelData) }
                    Big { anchors { right: parent.right; rightMargin: 14 } y: 0; text: wc.next.length ? wc.next[0].temp + "°" : "--°"; color: wc.index ? c.cyan : c.orange; font.pixelSize: 34 }
                    Plain { anchors { right: parent.right; rightMargin: 14 } y: 40; text: wc.next.length ? wc.cond(wc.next[0].code) : "NO FORECAST YET"; color: c.white; font.pixelSize: 13 }
                    Row {
                        x: 14; y: 118
                        Repeater {
                            model: 5
                            Plain { required property int index; width: index < 4 ? 376 / 4.4 : 40; text: wc.next.length > index * 3 ? "+" + root.pad(wc.next[index * 3].hour) : ""; font.pixelSize: 12 }
                        }
                    }
                }
            }
        }

        // ---------------- auth ----------------
        Panel {
            x: 24; y: 316; width: 836; height: 284
            EvaTag { x: 14; y: 14; jp: "認証"; text: "AUTH SEQUENCE"; halo: root.halo }
            Repeater {
                model: 8
                Column {
                    id: seg
                    required property int index
                    readonly property bool on: root.phase === "granted" || index < pass.text.length
                    readonly property color col: root.phase === "denied" ? c.red : root.phase === "granted" ? c.green : c.orange
                    x: 30 + index * 96; y: 172 - index * 13
                    spacing: 2
                    Plain { text: "SEG." + (seg.index + 1); font.pixelSize: 12; color: seg.on ? seg.col : c.dark }
                    Rectangle {
                        width: 96; height: 20; radius: 5; border.width: 2
                        border.color: seg.on ? seg.col : c.line
                        color: seg.on ? seg.col : "transparent"
                        layer.enabled: seg.on && root.halo > 0
                        layer.effect: MultiEffect { shadowEnabled: true; shadowColor: seg.col; shadowBlur: 0.6 * root.halo; shadowOpacity: 0.9; shadowHorizontalOffset: 0; shadowVerticalOffset: 0 }
                    }
                }
            }
            readonly property bool clear: pass.text.length >= 4 || root.phase === "granted"
            Rectangle { y: 214; width: parent.width; height: 2; color: parent.clear ? c.green : c.cyan }
            EvaTag { x: 340; y: 203; round: true; size: 16; fill: c.bg; halo: root.halo; tint: parent.clear ? c.green : c.cyan; text: "BORDER LINE" + (parent.clear ? " · CLEAR" : "") }
            Column {
                anchors { right: parent.right; top: parent.top; rightMargin: 16; topMargin: 14 }
                spacing: 4
                EvaTag {
                    anchors.right: parent.right
                    jp: root.phaseInfo.jp; text: root.phaseInfo.en; tint: root.accent; size: 30; halo: root.halo
                    SequentialAnimation on opacity { running: root.phaseInfo.blink; loops: Animation.Infinite; alwaysRunToEnd: true
                        PropertyAction { value: 1 } PauseAnimation { duration: 350 } PropertyAction { value: 0.15 } PauseAnimation { duration: 350 } }
                }
                Plain {
                    anchors.right: parent.right
                    text: keyboard.capsLock ? "▲ CAPS LOCK ON" : "LAYOUT " + ((keyboard.layouts?.[keyboard.currentLayout]?.shortName) || "EN").toUpperCase() + " · CAPS OFF"
                    color: keyboard.capsLock ? c.yellow : c.dim
                    font.pixelSize: 14
                }
            }
            Row {
                x: 14; y: 228
                spacing: 8
                EvaTag { anchors.verticalCenter: parent.verticalCenter; text: "PASSCODE"; size: 16; halo: root.halo }
                Rectangle {
                    width: 806 - 120 - 16 - 110; height: 44; radius: 7
                    color: "#0d0702"; border.color: root.accent; border.width: 2
                    TextInput {
                        id: pass
                        anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                        verticalAlignment: TextInput.AlignVCenter
                        echoMode: TextInput.Password
                        passwordCharacter: "●"
                        color: root.accent
                        font.family: c.sans; font.bold: true; font.pixelSize: 26; font.letterSpacing: 10
                        focus: true
                        readOnly: root.phase === "verify" || root.phase === "granted"
                        clip: true
                        onAccepted: root.submit()
                        Keys.onEscapePressed: text = ""
                        Component.onCompleted: forceActiveFocus()
                        Text { anchors.verticalCenter: parent.verticalCenter; visible: pass.text === ""; text: "ENTER PASSCODE"; color: c.dark; font.family: c.sans; font.bold: true; font.pixelSize: 22; font.letterSpacing: 4 }
                    }
                }
                Rectangle {
                    width: 120; height: 44; radius: 7; color: root.accent
                    Plain { anchors.centerIn: parent; text: "ENTER"; color: c.bg; font.pixelSize: 22; font.letterSpacing: 2 }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.submit() }
                }
            }
        }

        // ---------------- system ----------------
        Panel {
            x: 876; y: 316; width: 700; height: 284
            readonly property var sys: root.st.system ?? {}
            readonly property var bat: root.st.battery ?? {}
            EvaTag { x: 14; y: 14; jp: "状態"; text: "SYSTEM STATUS"; halo: root.halo }
            EvaTag { anchors { right: parent.right; top: parent.top; rightMargin: 14; topMargin: 14 } round: true; size: 16; tint: c.cyan; halo: root.halo; text: root.st.updated ? "SYSTEMS ARE GREEN" : "WAITING FOR STATUS" }
            Row {
                x: 20; y: 56
                spacing: 34
                Repeater {
                    model: {
                        const s = parent.parent.sys, b = parent.parent.bat;
                        const memUsed = s.memTotalKb ? (s.memTotalKb - s.memAvailKb) / s.memTotalKb : 0;
                        return [
                            { k: "TEMP", f: (s.temp ?? 0) / 100, v: s.temp ? s.temp + "°C" : "--" },
                            { k: "MEM",  f: memUsed, v: s.memTotalKb ? ((s.memTotalKb - s.memAvailKb) / 1048576).toFixed(1) + "G" : "--" },
                            { k: "BATT", f: (b.capacity ?? 0) / 100, v: b.capacity !== undefined && b.capacity !== null ? b.capacity + "%" : "AC" },
                            { k: "WLAN", f: (s.wifi ?? 0) / 100, v: s.wifi ? s.wifi + "%" : "OFF" },
                            { k: "TAILNET", f: root.st.tailnet?.peers?.length ? root.st.tailnet.peers.filter(p => p.online).length / root.st.tailnet.peers.length : 0, v: root.st.tailnet?.state === "Running" ? root.st.tailnet.peers.filter(p => p.online).length + "/" + root.st.tailnet.peers.length : "OFF" },
                            { k: "GPU",  f: s.gpu === "active" ? 1 : 0, v: s.gpu === "suspended" ? "SLEEP" : s.gpu === "active" ? "AWAKE" : "--" }
                        ];
                    }
                    Column {
                        id: meter
                        required property var modelData
                        readonly property int lit: Math.max(0, Math.min(10, Math.round(modelData.f * 10)))
                        spacing: 5
                        Plain { anchors.horizontalCenter: parent.horizontalCenter; text: meter.modelData.k; color: c.cyan; font.pixelSize: 13 }
                        Column {
                            spacing: 4
                            Repeater {
                                model: 10
                                Rectangle {
                                    required property int index
                                    readonly property int level: 9 - index
                                    readonly property bool on: level < meter.lit
                                    width: 72; height: 11; radius: 3
                                    color: on ? (level >= 8 ? c.hot : c.cyan) : c.ledOff
                                }
                            }
                        }
                        Big { anchors.horizontalCenter: parent.horizontalCenter; text: meter.modelData.v; font.pixelSize: 20 }
                    }
                }
            }
        }

        // ---------------- audio: always offline before login ----------------
        Panel {
            x: 24; y: 616; width: 736; height: 260
            Canvas {
                anchors.fill: parent
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.fillStyle = "rgba(90,50,16,0.3)";
                    for (let k = -height; k < width + height; k += 12) { ctx.beginPath(); ctx.moveTo(k, 0); ctx.lineTo(k + 6, 0); ctx.lineTo(k + 6 - height, height); ctx.lineTo(k - height, height); ctx.closePath(); ctx.fill() }
                    ctx.strokeStyle = "#ff3b2a"; ctx.lineWidth = 3;
                    ctx.beginPath(); ctx.moveTo(2, 2); ctx.lineTo(width - 2, height - 2); ctx.moveTo(width - 2, 2); ctx.lineTo(2, height - 2); ctx.stroke();
                }
            }
            EvaTag { x: 14; y: 14; jp: "音響"; text: "AUDIO · OFFLINE"; fill: c.bg; halo: root.halo }
            Column {
                anchors.centerIn: parent
                spacing: 4
                EvaTag {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "MUSIC OFFLINE"; tint: c.red; size: 44; fill: c.bg; halo: root.halo
                    SequentialAnimation on opacity { loops: Animation.Infinite
                        PropertyAction { value: 1 } PauseAnimation { duration: 350 } PropertyAction { value: 0.15 } PauseAnimation { duration: 350 } }
                }
                Rectangle { anchors.horizontalCenter: parent.horizontalCenter; width: jpOff.implicitWidth + 20; height: jpOff.implicitHeight; color: c.bg
                    Text { id: jpOff; anchors.centerIn: parent; text: "音響 停止"; color: c.white; font.family: c.jp; font.weight: Font.ExtraBold; font.pixelSize: 20 } }
                Rectangle { anchors.horizontalCenter: parent.horizontalCenter; width: note.implicitWidth + 16; height: note.implicitHeight; color: c.bg
                    Text { id: note; anchors.centerIn: parent; text: "NOTHING PLAYS BEFORE LOGIN"; color: c.dim; font.family: c.mono; font.pixelSize: 11 } }
            }
        }

        // ---------------- tailnet ----------------
        Rectangle {
            x: 776; y: 616; width: 484; height: 260
            color: c.boardFill; border.color: c.line; clip: true
            Canvas {
                anchors.fill: parent
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.strokeStyle = "#2a1404"; ctx.fillStyle = "#2a1404"; ctx.lineWidth = 2;
                    for (let i = 0; i < 11; i++) {
                        const sx = -40 + i * 34, sy = 270, bx = sx + 150, by = sy - 150;
                        ctx.beginPath(); ctx.moveTo(sx, sy); ctx.lineTo(bx, by); ctx.lineTo(500, by); ctx.stroke();
                        ctx.beginPath(); ctx.arc(bx, by, 5, 0, Math.PI * 2); ctx.fill();
                    }
                    for (let i = 0; i < 6; i++) { ctx.beginPath(); ctx.moveTo(-20 + i * 30, 0); ctx.lineTo(120 + i * 30, 140); ctx.stroke() }
                    ctx.font = "10px 'Share Tech Mono'"; ctx.textAlign = "center";
                    for (let i = 0; i < 8; i++) {
                        const t = 0.32 + (i % 3) * 0.12, x = -40 + i * 34 + 150 * t, y = 270 - 150 * t;
                        ctx.save(); ctx.translate(x, y); ctx.rotate(-Math.PI / 4);
                        ctx.fillStyle = "#140b02"; ctx.fillRect(-26, -8, 52, 16);
                        ctx.fillStyle = "#3cff7a"; ctx.fillText("00" + (128 + i), 0, 4);
                        ctx.restore();
                    }
                }
            }
            readonly property var tn: root.st.tailnet ?? { state: "", peers: [] }
            EvaTag {
                x: 12; y: 12; size: 16; tint: "#140b02"; fill: "#ff9a3a"; halo: 0
                jp: "回線"; text: "TAILNET " + (parent.tn.state === "Running" ? parent.tn.peers.filter(p => p.online).length + "/" + parent.tn.peers.length : parent.tn.state === "NeedsLogin" ? "SIGN IN" : "OFF")
            }
            Column {
                anchors { right: parent.right; top: parent.top; rightMargin: 12; topMargin: 54 }
                spacing: 6
                Repeater {
                    model: (parent.parent.tn.peers ?? []).slice(0, 4)
                    Rectangle {
                        id: dev
                        required property var modelData
                        required property int index
                        width: 236; height: 30; color: "#140b02"
                        RowLayout {
                            anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                            spacing: 8
                            Text { text: "00" + (227 + dev.index * 3); color: c.dim; font.family: c.mono; font.pixelSize: 11 }
                            Plain { Layout.fillWidth: true; text: String(dev.modelData.name).toUpperCase(); color: dev.modelData.online ? c.green : c.red; font.pixelSize: 15; elide: Text.ElideRight }
                            Text { text: dev.modelData.online ? (dev.modelData.direct ? "DIRECT" : "RELAY") : "OFF"; color: dev.modelData.online ? c.green : c.red; font.family: c.mono; font.pixelSize: 10 }
                        }
                    }
                }
            }
        }

        // ---------------- power ----------------
        Panel {
            id: power
            x: 1276; y: 616; width: 300; height: 260
            property string armed: ""
            Timer { id: disarm; interval: 4000; onTriggered: power.armed = "" }
            EvaTag { x: 14; y: 14; jp: "電源"; text: "POWER"; halo: root.halo }
            Column {
                x: 14; y: 54
                spacing: 8
                Repeater {
                    model: [
                        { id: "suspend",  jp: "休止",   en: "SUSPEND",   ok: sddm.canSuspend,  confirm: false },
                        { id: "reboot",   jp: "再起動", en: "RESTART",   ok: sddm.canReboot,   confirm: true },
                        { id: "poweroff", jp: "停止",   en: "SHUT DOWN", ok: sddm.canPowerOff, confirm: true }
                    ]
                    Rectangle {
                        id: pb
                        required property var modelData
                        readonly property bool armed: power.armed === modelData.id
                        visible: modelData.ok
                        width: 272; height: 40; radius: 7
                        color: armed ? c.red : "transparent"
                        border.color: armed ? c.red : c.orange; border.width: 2
                        RowLayout {
                            anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                            Text { text: pb.modelData.jp; color: pb.armed ? c.bg : c.orange; font.family: c.jp; font.weight: Font.ExtraBold; font.pixelSize: 15 }
                            Item { Layout.fillWidth: true }
                            Plain { text: pb.armed ? "PRESS AGAIN" : pb.modelData.en; color: pb.armed ? c.bg : c.orange; font.pixelSize: 20 }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (pb.modelData.confirm && power.armed !== pb.modelData.id) { power.armed = pb.modelData.id; disarm.restart(); return }
                                power.armed = "";
                                if (pb.modelData.id === "suspend") sddm.suspend();
                                else if (pb.modelData.id === "reboot") sddm.reboot();
                                else sddm.powerOff();
                            }
                        }
                    }
                }
            }
            RowLayout {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 14 }
                EvaTag { round: true; tint: c.cyan; size: 15; halo: root.halo; text: "MESSAGES · AFTER LOGIN" }
                Item { Layout.fillWidth: true }
                Big { text: root.st.generation ? "NIX GEN " + root.st.generation : "NIXOS"; font.pixelSize: 15 }
            }
        }

        // ---------------- CRT: scanlines, vignette, flicker ----------------
        Item {
            anchors.fill: parent
            visible: root.glow !== "off"
            opacity: root.glow === "soft" ? 0.45 : 1
            Canvas {
                id: crt
                anchors.fill: parent
                onPaint: { const ctx = getContext("2d"); ctx.fillStyle = "rgba(0,0,0,0.28)"; for (let y = 0; y < height; y += 3) ctx.fillRect(0, y, width, 1) }
            }
            Shape {
                anchors.fill: parent
                ShapePath {
                    strokeWidth: 0; strokeColor: "transparent"
                    fillGradient: RadialGradient {
                        centerX: 800; centerY: 450; centerRadius: 990; focalX: 800; focalY: 450
                        GradientStop { position: 0.45; color: "transparent" }
                        GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.55) }
                    }
                    startX: 0; startY: 0
                    PathLine { x: 1600; y: 0 } PathLine { x: 1600; y: 900 } PathLine { x: 0; y: 900 } PathLine { x: 0; y: 0 }
                }
            }
            SequentialAnimation {
                running: parent.visible; loops: Animation.Infinite
                NumberAnimation { target: crt; property: "opacity"; to: 0.94; duration: 1900 }
                NumberAnimation { target: crt; property: "opacity"; to: 0.86; duration: 80 }
                NumberAnimation { target: crt; property: "opacity"; to: 0.96; duration: 80 }
                NumberAnimation { target: crt; property: "opacity"; to: 1; duration: 1900 }
            }
        }
    }
}
