// The volume / brightness indicator: a small pill under the bar with an icon, a level bar and
// the %, shown for a moment whenever either changes.
//   volume:     watched straight from PipeWire (keys, the bar, any app)
//   brightness: the brightness keys run `qs ipc call osd brightness` after changing it
//               (the kernel's backlight file can't be watched for changes)
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pipewire

PanelWindow {
    id: win
    anchors.top: true
    margins.top: Theme.popupTop - 10
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-osd"
    color: "transparent"
    implicitWidth: 320 + 40
    implicitHeight: 56 + 40
    mask: Region {} // never catches clicks
    visible: pill.opacity > 0

    property string kind: "volume"   // what's showing: "volume" | "brightness"
    property real level: 0           // 0..1
    property bool muted: false
    function show(k, v, m) {
        kind = k; level = v; muted = m ?? false;
        pill.shown = true;
        hide.restart();
    }
    Timer { id: hide; interval: 1400; onTriggered: pill.shown = false }

    // ---- volume: PipeWire ----
    readonly property var sink: Pipewire.defaultAudioSink
    PwObjectTracker { objects: [win.sink] }
    property bool ready: false // not on startup, nor when the output device changes
    Timer { running: true; interval: 2000; onTriggered: win.ready = true }
    onSinkChanged: { ready = false; settle.restart() }
    Timer { id: settle; interval: 800; onTriggered: win.ready = true }
    Connections {
        target: win.sink?.audio ?? null
        function onVolumeChanged() { if (win.ready) win.show("volume", win.sink.audio.volume, win.sink.audio.muted) }
        function onMutedChanged() { if (win.ready) win.show("volume", win.sink.audio.volume, win.sink.audio.muted) }
    }

    // ---- brightness: asked for by the keys ----
    Process {
        id: bright
        command: ["brightnessctl", "-m"] // e.g. amdgpu_bl2,backlight,45875,70%,65535
        stdout: StdioCollector {
            onStreamFinished: {
                const f = text.trim().split(",");
                if (f.length >= 5) win.show("brightness", Number(f[2]) / Number(f[4]));
            }
        }
    }
    IpcHandler {
        target: "osd"
        function brightness(): void { bright.running = true }
        function volume(): void { if (win.sink?.audio) win.show("volume", win.sink.audio.volume, win.sink.audio.muted) }
    }

    RectangularShadow { anchors.fill: pill; radius: pill.radius; offset.y: 10; blur: 30; color: Qt.rgba(0, 0, 0, 0.45 * pill.opacity) }
    Rectangle {
        id: pill
        property bool shown: false
        anchors.centerIn: parent
        width: 320
        height: 56
        radius: Theme.r(20)
        color: Theme.alpha(Theme.bgLow, 0.96)
        opacity: shown ? 1 : 0
        scale: shown ? 1 : 0.94
        Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

        RowLayout {
            anchors { fill: parent; leftMargin: 18; rightMargin: 18 }
            spacing: 14
            Icon {
                name: win.kind === "brightness" ? "sun" : win.muted || win.level === 0 ? "mute" : "volume"
                size: 20
                color: win.muted ? Theme.textDim : Theme.accent
            }
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 8
                radius: 4
                color: Theme.bgHighest
                Rectangle {
                    height: parent.height
                    radius: 4
                    width: parent.width * Math.max(0, Math.min(1, win.level))
                    color: win.muted ? Theme.outline : Theme.accent
                    Behavior on width { NumberAnimation { duration: 90 } }
                }
            }
            Txt {
                Layout.preferredWidth: 46
                horizontalAlignment: Text.AlignRight
                text: win.muted ? "Muted" : Math.round(win.level * 100) + "%"
                font.weight: Font.DemiBold
                color: win.muted ? Theme.textDim : Theme.text
            }
        }
    }
}
