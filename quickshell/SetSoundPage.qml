// Settings → Sound: which device plays and which one records, their volumes, and the volume of
// each app that's playing or recording right now (PipeWire streams), and EasyEffects presets
// (like the player popup).
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

SetPage {
    id: page
    title: "Sound"
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    subtitle: sink ? "Playing through " + page.nameOf(sink) : "No output device"
    readonly property var nodes: Pipewire.nodes.values.filter(n => n.audio)
    readonly property var outputs: nodes.filter(n => n.isSink && !n.isStream)
    // Inputs: microphones (not the "monitor" of an output)
    readonly property var inputs: nodes.filter(n => !n.isSink && !n.isStream && !/\.monitor$/.test(n.name))
    readonly property var streams: nodes.filter(n => n.isStream)
    // Volumes only update for nodes something tracks
    PwObjectTracker { objects: [page.sink, page.source, ...page.streams] }

    function nameOf(n) { return n.description || n.nickname || n.name }
    function appOf(n) {
        const p = n.properties ?? {};
        return p["application.name"] || p["application.process.binary"] || n.description || n.name;
    }
    // A stream that records (Stream/Input/Audio) rather than plays
    function recording(n) { return (n.properties ?? {})["media.class"] === "Stream/Input/Audio" }
    function kindOf(n) { return n.name.startsWith("bluez") ? "Bluetooth" : /hdmi/i.test(n.name) ? "HDMI" : /usb/i.test(n.name) ? "USB" : "Built-in" }
    function setVol(n, v) { if (!n?.audio) return; n.audio.volume = v; if (v > 0) n.audio.muted = false }

    // ---- output ----
    SetCard {
        title: "Output"
        LevelSlider {
            Layout.leftMargin: 6
            Layout.rightMargin: 10
            icon: page.sink?.audio?.muted ? "mute" : "volume"
            value: page.sink?.audio?.volume ?? 0
            dim: !page.sink || (page.sink?.audio?.muted ?? false)
            onMoved: v => page.setVol(page.sink, v)
            onIconClicked: if (page.sink?.audio) page.sink.audio.muted = !page.sink.audio.muted
        }
        Repeater {
            model: page.outputs
            SetRow {
                id: out
                required property var modelData
                icon: modelData.name.startsWith("bluez") ? "headphones" : "speaker"
                label: page.nameOf(modelData)
                sub: page.kindOf(modelData)
                highlight: page.sink === modelData
                active: page.sink !== modelData
                hoverColor: Theme.alpha(Theme.text, 0.06)
                onClicked: Pipewire.preferredDefaultAudioSink = modelData
            }
        }
    }

    // ---- input ----
    SetCard {
        title: "Input"
        LevelSlider {
            visible: !!page.source
            Layout.leftMargin: 6
            Layout.rightMargin: 10
            icon: "mic"
            value: page.source?.audio?.volume ?? 0
            dim: page.source?.audio?.muted ?? false
            onMoved: v => page.setVol(page.source, v)
            onIconClicked: if (page.source?.audio) page.source.audio.muted = !page.source.audio.muted
        }
        Txt { visible: page.inputs.length === 0; Layout.margins: 12; text: "No microphones."; color: Theme.textDim }
        Repeater {
            model: page.inputs
            SetRow {
                required property var modelData
                icon: "mic"
                label: page.nameOf(modelData)
                sub: page.kindOf(modelData)
                highlight: page.source === modelData
                active: page.source !== modelData
                hoverColor: Theme.alpha(Theme.text, 0.06)
                onClicked: Pipewire.preferredDefaultAudioSource = modelData
            }
        }
    }

    // ---- apps ----
    SetCard {
        title: "Apps"
        Txt { visible: page.streams.length === 0; Layout.margins: 12; text: "Nothing is playing or recording."; color: Theme.textDim }
        Repeater {
            model: page.streams
            ColumnLayout {
                id: app
                required property var modelData
                Layout.fillWidth: true
                Layout.leftMargin: 12
                Layout.rightMargin: 10
                Layout.topMargin: 6
                spacing: 0
                Txt {
                    Layout.leftMargin: 50
                    text: page.appOf(app.modelData) + (page.recording(app.modelData) ? " · recording" : "")
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    color: Theme.textDim
                }
                LevelSlider {
                    icon: app.modelData.audio?.muted ? "mute" : page.recording(app.modelData) ? "mic" : "volume"
                    value: app.modelData.audio?.volume ?? 0
                    dim: app.modelData.audio?.muted ?? false
                    onMoved: v => page.setVol(app.modelData, v)
                    onIconClicked: if (app.modelData.audio) app.modelData.audio.muted = !app.modelData.audio.muted
                }
            }
        }
    }

    // ---- EasyEffects presets (output): the files in its presets folder, as in MusicPanel.qml ----
    property var presets: []
    property string preset: ""
    Process {
        running: true
        command: ["sh", "-c", "for d in \"$HOME/.local/share/easyeffects/output\" \"$HOME/.config/easyeffects/output\"; do [ -d \"$d\" ] && ls \"$d\"; done | sed -n 's/\\.json$//p' | sort -u"]
        stdout: StdioCollector { onStreamFinished: page.presets = text.split("\n").filter(x => x) }
    }
    SetCard {
        title: "Effects"
        SetRow {
            icon: "eq"
            label: "EasyEffects"
            sub: page.presets.length ? "Pick a preset to load it" : "No presets yet: save some in EasyEffects and they show up here"
            SetButton { text: "Open EasyEffects"; onClicked: Quickshell.execDetached(["easyeffects"]) }
        }
        Flow {
            visible: page.presets.length > 0
            Layout.fillWidth: true
            Layout.margins: 8
            spacing: 6
            Repeater {
                model: page.presets
                Clicky {
                    id: pre
                    required property string modelData
                    readonly property bool on: page.preset === modelData
                    implicitWidth: preText.implicitWidth + 28
                    implicitHeight: 34
                    radius: 17
                    base: on ? Theme.accent : Theme.bgHigh
                    onClicked: { page.preset = modelData; Quickshell.execDetached(["easyeffects", "-l", modelData]) }
                    Txt { id: preText; anchors.centerIn: parent; text: pre.modelData; font.pixelSize: 12; font.weight: Font.DemiBold; color: pre.on ? Theme.textOnAccent : Theme.text }
                }
            }
        }
    }
}
