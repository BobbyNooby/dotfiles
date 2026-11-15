// The volume / brightness indicator: a small pill under the bar with an icon, a level bar and
// the %, shown for a moment whenever either changes. Switching typing language (Ctrl+Space,
// Input.qml) shows the languages in the same pill, with the new one lit.
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
import "Common.js" as Common

PanelWindow {
    id: win
    anchors.top: true
    margins.top: Theme.popupTop - 10
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-osd"
    color: "transparent"
    implicitWidth: Math.max(320, pill.width) + 40
    implicitHeight: 56 + 40
    mask: Region {} // never catches clicks
    visible: pill.opacity > 0

    property string kind: "volume"   // what's showing: "volume" | "brightness" | "language"
    property real level: 0           // 0..1
    property bool muted: false
    function show(k, v, m) {
        kind = k; level = v; muted = m ?? false;
        pill.shown = true;
        hide.restart();
    }
    Timer { id: hide; interval: 1400; onTriggered: pill.shown = false }

    // ---- typing language: Input.qml (not for the first reading at startup) ----
    property bool inputReady: false
    Timer { running: true; interval: 4000; onTriggered: win.inputReady = true }
    Connections {
        target: Input
        function onCurrentChanged() { if (win.inputReady) win.show("language", 0, false) }
    }

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
                const b = Common.brightness(text);
                if (b >= 0) win.show("brightness", b);
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
        width: win.kind === "language" ? langRow.implicitWidth + 36 : 320
        height: 56
        radius: Theme.r(20)
        color: Theme.alpha(Theme.bgLow, 0.96)
        opacity: shown ? 1 : 0
        scale: shown ? 1 : 0.94
        Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

        // Languages: each one's mark, the current one in a filled chip with its name
        RowLayout {
            id: langRow
            visible: win.kind === "language"
            anchors.centerIn: parent
            spacing: 6
            Icon { name: "keyboard"; size: 18; color: Theme.textDim; Layout.rightMargin: 6 }
            Repeater {
                model: Input.methods
                Rectangle {
                    required property string modelData
                    readonly property bool on: modelData === Input.current
                    implicitWidth: chipText.implicitWidth + 22
                    implicitHeight: 34
                    radius: height / 2
                    color: on ? Theme.accent : "transparent"
                    Txt {
                        id: chipText
                        anchors.centerIn: parent
                        text: parent.on ? Input.label(parent.modelData) + "  " + Input.title(parent.modelData) : Input.label(parent.modelData)
                        font.weight: Font.DemiBold
                        color: parent.on ? Theme.textOnAccent : Theme.textDim
                    }
                }
            }
        }

        RowLayout {
            visible: win.kind !== "language"
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
