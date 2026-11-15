// The player: click the music pill in the bar. Cover art, EasyEffects presets, a dotted
// visualiser (cava, only runs while this is open and playing), a wavy seek bar, the lyrics
// switch and the output device.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Services.Pipewire

Dropdown {
    id: win
    name: "music"
    panelWidth: 520
    centred: true
    padding: 24
    cardRadius: 32
    spacing: 18

    readonly property var sink: Pipewire.defaultAudioSink
    PwObjectTracker { objects: [win.sink] }

    // ---- EasyEffects presets (output): the files in its presets folder ----
    property var presets: []
    property string preset: ""
    onOpened: presetList.running = true
    Process {
        id: presetList
        command: ["sh", "-c", "for d in \"$HOME/.local/share/easyeffects/output\" \"$HOME/.config/easyeffects/output\"; do [ -d \"$d\" ] && ls \"$d\"; done | sed -n 's/\\.json$//p' | sort -u"]
        stdout: StdioCollector { onStreamFinished: win.presets = text.split("\n").filter(x => x) }
    }

    // ---- visualiser: cava prints 10 numbers 0..9 per frame ----
    property var levels: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    Process {
        running: win.shown && Media.playing
        command: ["cava", "-p", Quickshell.shellDir + "/cava.conf"]
        stdout: SplitParser {
            onRead: line => {
                const v = line.split(";").filter(x => x !== "").map(Number);
                if (v.length === 10) win.levels = v;
            }
        }
        onRunningChanged: if (!running) win.levels = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    }

    // ---------------- art + title ----------------
    RowLayout {
        Layout.fillWidth: true
        spacing: 20
        Item { // the icon sits outside the clip: ClippingRectangle darkens what it draws
            implicitWidth: children[0].implicitWidth
            implicitHeight: children[0].implicitHeight
            ClippingRectangle {
                implicitWidth: 144
                implicitHeight: 144
                radius: Theme.r(30)
                color: Theme.accentSoft
                Image { id: bigArt; anchors.fill: parent; source: Media.art; fillMode: Image.PreserveAspectCrop; asynchronous: true; sourceSize.width: 288 }
            }
            Icon { anchors.centerIn: parent; name: "music"; size: 48; color: Theme.textOnSoft; visible: bigArt.status !== Image.Ready }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6
            Txt {
                text: "NOW PLAYING" + (Media.app ? " · " + Media.app.toUpperCase() : "")
                font.pixelSize: 12
                font.weight: Font.DemiBold
                font.letterSpacing: 0.5
                color: Theme.accent
            }
            Txt { Layout.fillWidth: true; heading: true; text: Media.title || "Nothing playing"; font.pixelSize: 26; wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight }
            Txt { Layout.fillWidth: true; text: [Media.artist, Media.album].filter(x => x).join(" · "); font.pixelSize: 14; color: Theme.textDim; elide: Text.ElideRight }
        }
    }

    // ---------------- EQ presets ----------------
    Flow {
        Layout.fillWidth: true
        spacing: 6
        visible: win.presets.length > 0
        Repeater {
            model: win.presets
            Clicky {
                id: chip
                required property string modelData
                readonly property bool on: win.preset === modelData
                width: chipText.implicitWidth + 24
                height: 32
                radius: Theme.r(10)
                base: on ? Theme.accentSoft : "transparent"
                border.color: on ? Theme.accentSoft : Theme.border
                border.width: 1
                onClicked: { win.preset = modelData; Quickshell.execDetached(["easyeffects", "-l", modelData]) }
                Txt { id: chipText; anchors.centerIn: parent; text: chip.modelData; font.weight: Font.Medium; color: chip.on ? Theme.textOnSoft : Theme.textDim }
            }
        }
    }
    Txt {
        visible: win.presets.length === 0
        Layout.fillWidth: true
        text: "No EasyEffects presets yet: EQ opens EasyEffects, save a few there and they show up here."
        wrapMode: Text.Wrap
        font.pixelSize: 12
        color: Theme.textDim
    }

    // ---------------- visualiser ----------------
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 8
        RowLayout {
            Layout.fillWidth: true
            spacing: 4
            Repeater {
                model: 10
                Column {
                    id: col
                    required property int index
                    Layout.fillWidth: true
                    spacing: 5
                    Repeater {
                        model: 9
                        Rectangle {
                            required property int index
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 7
                            height: 7
                            radius: 4
                            // lit from the bottom up; always at least one dot
                            color: 8 - index < Math.max(1, win.levels[col.index]) ? Theme.accent : Theme.bgHighest
                            Behavior on color { ColorAnimation { duration: 120 } }
                        }
                    }
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 4
            Repeater {
                model: ["32", "64", "125", "250", "500", "1k", "2k", "4k", "8k", "16k"]
                Txt { required property string modelData; Layout.fillWidth: true; Layout.preferredWidth: 1; horizontalAlignment: Text.AlignHCenter; text: modelData; font.pixelSize: 10; color: Theme.outline }
            }
        }
    }

    // ---------------- seek bar: a wave up to where you are ----------------
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 6
        Canvas {
            id: wave
            Layout.fillWidth: true
            implicitHeight: 20
            property real phase: 0
            property real progress: Media.progress
            onProgressChanged: requestPaint()
            Timer { interval: 50; repeat: true; running: win.shown && Media.playing; onTriggered: { wave.phase += 0.35; wave.requestPaint() } }
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                const w = width, px = Math.max(0, Math.min(w, progress * w));
                const y = x => 10 + 3.5 * Math.sin((x / w) * Math.PI * 2 * 14 + phase);
                ctx.lineWidth = 3;
                ctx.lineCap = "round";
                ctx.lineJoin = "round";
                ctx.strokeStyle = Theme.border.toString();
                ctx.beginPath(); ctx.moveTo(px, 10); ctx.lineTo(w, 10); ctx.stroke();
                ctx.strokeStyle = Theme.accent.toString();
                ctx.beginPath(); ctx.moveTo(0, y(0));
                for (let x = 2; x <= px; x += 2) ctx.lineTo(x, y(x));
                ctx.stroke();
                ctx.fillStyle = Theme.accent.toString();
                ctx.beginPath(); ctx.arc(px, y(px), 6, 0, Math.PI * 2); ctx.fill();
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: m => Media.seek(m.x / width)
            }
        }
        RowLayout {
            Layout.fillWidth: true
            Txt { Layout.fillWidth: true; text: Media.time(Media.position); font.pixelSize: 12; color: Theme.textDim }
            Txt { text: Media.length > 0 ? Media.time(Media.length) : ""; font.pixelSize: 12; color: Theme.textDim }
        }
    }

    // ---------------- buttons ----------------
    RowLayout {
        Layout.fillWidth: true
        Clicky {
            implicitWidth: lyrRow.implicitWidth + 28
            implicitHeight: 44
            radius: Theme.r(14)
            base: Media.showLyrics ? Theme.accentSoft : Theme.bgHigh
            onClicked: Media.showLyrics = !Media.showLyrics
            RowLayout {
                id: lyrRow
                anchors.centerIn: parent
                spacing: 6
                Icon { name: "lyrics"; size: 16; stroke: 1.9; color: Media.showLyrics ? Theme.textOnSoft : Theme.text }
                Txt { text: "Lyrics"; font.weight: Font.DemiBold; color: Media.showLyrics ? Theme.textOnSoft : Theme.text }
            }
        }
        Item { Layout.fillWidth: true }
        RowLayout {
            spacing: 14
            Clicky { implicitWidth: 48; implicitHeight: 48; radius: Theme.r(24); base: Theme.bgHigh; onClicked: Media.previous(); Icon { anchors.centerIn: parent; name: "prev"; size: 20 } }
            Clicky {
                implicitWidth: 72
                implicitHeight: 60
                radius: Theme.r(20)
                base: Theme.accent
                onClicked: Media.toggle()
                Icon { anchors.centerIn: parent; name: Media.playing ? "pause" : "play"; size: 24; color: Theme.textOnAccent }
            }
            Clicky { implicitWidth: 48; implicitHeight: 48; radius: Theme.r(24); base: Theme.bgHigh; onClicked: Media.next(); Icon { anchors.centerIn: parent; name: "next"; size: 20 } }
        }
        Item { Layout.fillWidth: true }
        Clicky {
            implicitWidth: eqRow.implicitWidth + 28
            implicitHeight: 44
            radius: Theme.r(14)
            base: Theme.bgHigh
            onClicked: { Popups.close(); Quickshell.execDetached(["easyeffects"]) }
            RowLayout {
                id: eqRow
                anchors.centerIn: parent
                spacing: 6
                Icon { name: "eq"; size: 16; stroke: 1.9; cutout: Theme.bgHigh }
                Txt { text: "EQ"; font.weight: Font.DemiBold }
            }
        }
    }

    // ---------------- output device (click: the volume popup) ----------------
    Clicky {
        Layout.fillWidth: true
        implicitHeight: outRow.implicitHeight + 20
        radius: Theme.r(18)
        base: Theme.bgMid
        onClicked: Popups.toggle("volume", -1)
        RowLayout {
            id: outRow
            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 14; rightMargin: 14 }
            spacing: 12
            readonly property bool bt: (win.sink?.name ?? "").startsWith("bluez")
            Icon { name: outRow.bt ? "headphones" : "speaker"; size: 20; color: Theme.accent }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Txt { Layout.fillWidth: true; text: win.sink?.description || win.sink?.nickname || "No output"; font.pixelSize: 14; font.weight: Font.DemiBold; elide: Text.ElideRight }
                Txt { text: (outRow.bt ? "Bluetooth" : "Built-in") + " · " + Math.round((win.sink?.audio?.volume ?? 0) * 100) + "%"; font.pixelSize: 12; color: Theme.textDim }
            }
            Txt { text: "Output"; font.pixelSize: 12; color: Theme.textDim }
        }
    }
}
