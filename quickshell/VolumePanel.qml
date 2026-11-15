// Volume: click the volume in the bar. Slider, mute, and which device plays the sound
// (every PipeWire output: speakers, headphones, Bluetooth, HDMI).
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire

Dropdown {
    id: win
    name: "volume"
    panelWidth: 300

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool muted: sink?.audio?.muted ?? false
    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property var outputs: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream && n.audio)
    PwObjectTracker { objects: [win.sink] }

    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: 4
        Layout.rightMargin: 4
        Txt { Layout.fillWidth: true; heading: true; text: "Volume"; font.pixelSize: 17 }
        Txt { text: win.muted ? "Muted" : Math.round(win.volume * 100) + "%"; font.pixelSize: 14; font.weight: Font.DemiBold; color: Theme.accent }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 10
        Clicky {
            implicitWidth: 44
            implicitHeight: 44
            radius: Theme.r(14)
            base: win.muted ? Theme.accentSoft : Theme.bgHigh
            onClicked: if (win.sink?.audio) win.sink.audio.muted = !win.muted
            Icon { anchors.centerIn: parent; name: win.muted ? "mute" : "volume"; size: 18; color: win.muted ? Theme.textOnSoft : Theme.text }
        }
        Slider {
            id: slider
            Layout.fillWidth: true
            from: 0
            to: 1
            value: win.volume
            onMoved: if (win.sink?.audio) { win.sink.audio.volume = value; if (value > 0) win.sink.audio.muted = false }
            background: Rectangle {
                x: slider.leftPadding
                y: slider.topPadding + slider.availableHeight / 2 - height / 2
                width: slider.availableWidth
                height: 8
                radius: 4
                color: Theme.bgHighest
                Rectangle { width: slider.visualPosition * parent.width; height: parent.height; radius: 4; color: win.muted ? Theme.outline : Theme.accent }
            }
            handle: Rectangle {
                x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
                y: slider.topPadding + slider.availableHeight / 2 - height / 2
                width: 20
                height: 20
                radius: Theme.r(10)
                color: win.muted ? Theme.outline : Theme.accent
            }
            WheelHandler {
                onWheel: e => { if (win.sink?.audio) win.sink.audio.volume = Math.max(0, Math.min(1, win.volume + (e.angleDelta.y > 0 ? 0.05 : -0.05))) }
            }
        }
    }

    Txt { Layout.leftMargin: 4; text: "Output"; font.pixelSize: 12; color: Theme.textDim }
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 4
        Repeater {
            model: win.outputs
            Clicky {
                id: out
                required property var modelData
                readonly property bool on: win.sink === modelData
                Layout.fillWidth: true
                implicitHeight: 44
                radius: Theme.r(14)
                base: on ? Theme.accentSoft : "transparent"
                onClicked: Pipewire.preferredDefaultAudioSink = modelData
                RowLayout {
                    anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                    spacing: 10
                    Txt { Layout.fillWidth: true; text: out.modelData.description || out.modelData.nickname || out.modelData.name; font.pixelSize: 14; font.weight: Font.DemiBold; elide: Text.ElideRight; color: out.on ? Theme.textOnSoft : Theme.text }
                    Txt { text: out.modelData.name.startsWith("bluez") ? "Bluetooth" : /hdmi/i.test(out.modelData.name) ? "HDMI" : "Built-in"; font.pixelSize: 12; opacity: 0.8; color: out.on ? Theme.textOnSoft : Theme.text }
                }
            }
        }
    }
}
