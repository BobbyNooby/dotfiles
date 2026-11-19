// The floating lyrics on the desktop (Media.qml has the lines and the timing).
// A rolling drum: the lines sit around a cylinder lying on its side (like a revolver's
// cylinder seen from the side). The current line faces you; the ones before and after curve
// away, squashed and faded, and the drum turns one notch each time the song moves on.
//
// It has a small window of its own, on the same layer as the desktop widgets: the roll is an
// animation, and inside the widgets' full-screen window every frame of it redrew the whole
// screen-sized layer (~20 frames per lyric line). Here only this strip is redrawn.
// Clicks go straight through it. Where it sits comes from DesktopWidgets.qml (shell.qml joins
// the two), so it stays between the cards.
//
// Saver mode with the plain look (Pace.effects false): only the current line, swapped
// straight to the next one: no roll, no lines before/after.
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: win
    required property var modelData
    screen: modelData

    // From DesktopWidgets.qml, in whole-screen pixels
    property real drumTop: Math.round(modelData.height * 0.70) // top of the drum
    property real drumHeight: 220
    property real leftEdge: 0   // how far in from the left the cards beside the drum reach (0 = none)
    property real rightEdge: 0  // the same from the right

    // The lines are centred on the screen, so the room is twice the smaller side: from the
    // middle to the nearer card, less a 24 px gap. Never wider than before (screen − 600).
    readonly property int textWidth: Math.max(200, Math.min(modelData.width - 600,
        2 * Math.floor(modelData.width / 2 - Math.max(leftEdge, rightEdge) - 24)))
    readonly property int pad: 32 // room around the drum for the text's shadow

    visible: Settings.show("lyrics") && Media.showLyrics && Media.hasLyrics && Media.hasPlayer
    anchors { top: true; left: true }
    margins { top: Math.round(win.drumTop) - win.pad; left: Math.round((modelData.width - win.textWidth) / 2) - win.pad }
    exclusionMode: ExclusionMode.Ignore // whole-screen coordinates, like the widgets
    implicitWidth: textWidth + 2 * pad
    implicitHeight: drumHeight + 2 * pad
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "qs-lyrics" // not in hyprland.lua's blur list: nothing behind it to frost
    color: "transparent"
    mask: Region {} // never catches clicks

    Item {
        id: drum
        x: win.pad
        y: win.pad
        width: win.textWidth
        height: win.drumHeight
        layer.enabled: true
        layer.effect: MultiEffect { shadowEnabled: true; shadowColor: "black"; shadowOpacity: 0.6; shadowBlur: 0.8; shadowVerticalOffset: 2 }

        readonly property real step: 34     // degrees between neighbouring lines
        readonly property real radius: 88   // px: how big the drum is
        // where the drum points, eased between lines so it rolls instead of jumping
        // (plain look: no easing, it jumps)
        property real pos: Media.lineIndex
        Behavior on pos {
            enabled: Pace.effects
            NumberAnimation { duration: 340; easing.type: Easing.OutBack; easing.overshoot: 1.1 }
        }

        Repeater {
            model: 5 // two lines either side of the current one; the outer ones are nearly edge-on
            Txt {
                id: lyric
                required property int index
                readonly property int line: Math.round(drum.pos) - 2 + index
                readonly property real angle: (line - drum.pos) * drum.step
                readonly property real rad: angle * Math.PI / 180
                readonly property bool current: line === Media.lineIndex
                // plain look: the current line only
                visible: Math.abs(angle) < 88 && line >= 0 && line < Media.lines.length && (Pace.effects || current)
                width: drum.width
                horizontalAlignment: Text.AlignHCenter
                // A long line first shrinks to fit (down to 22 px), then ends in "…", so it
                // never runs past the drum onto the cards
                fontSizeMode: Text.HorizontalFit
                minimumPixelSize: 22
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
}
