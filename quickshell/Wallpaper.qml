// The wallpaper, drawn by Quickshell itself (no hyprpaper needed).
// `setwall <image>` writes the image's path to ~/.local/state/wallpaper/path; this window
// watches that file, so the wallpaper (and, via matugen, every colour) changes at once.
//
// Changing wallpaper plays a transition (set `transition` below):
//   "sketch"  the new picture's outlines are drawn in your accent colour, then its colours
//             fill in behind them (shaders/sketch.frag)
//   "fade"    a plain cross-fade
// Two pictures take turns being in front, so the new one is fully loaded before it shows.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: win
    required property var modelData
    screen: modelData

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore // cover the whole screen, under the bar too
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "qs-wallpaper"
    color: Theme.bg

    property string path: ""

    FileView {
        id: pathFile
        path: Quickshell.env("HOME") + "/.local/state/wallpaper/path"
        watchChanges: true
        onFileChanged: reload()
        // setwall rewrites the file in two steps (empty it, then write the path). Reading it in
        // between gave "" and the wallpaper vanished until the next restart. So an empty read
        // keeps the current wallpaper and checks again shortly (a few times, then gives up).
        onLoaded: {
            const p = text().trim();
            if (p) {
                win.path = p;
                recheck.tries = 0;
            } else if (recheck.tries < 5) {
                recheck.tries++;
                recheck.restart();
            }
        }
        printErrors: false
    }
    Timer {
        id: recheck
        property int tries: 0
        interval: 300
        onTriggered: pathFile.reload()
    }

    readonly property string transition: "sketch" // "sketch" or "fade"
    readonly property int duration: 2400            // ms for the whole transition

    // ---- two pictures taking turns ----
    property int front: 0           // which of the two is showing (0 = a, 1 = b)
    readonly property var pics: [a, b]
    readonly property var frontPic: pics[front]
    readonly property var backPic: pics[1 - front]

    // A new path: load it into the back picture; first one ever just shows
    onPathChanged: {
        if (!path) return;
        if (!frontPic.source.toString()) { frontPic.source = Theme.fileUrl(path); return }
        if (frontPic.source.toString() === Theme.fileUrl(path)) return;
        anim.stop();
        backPic.source = Theme.fileUrl(path);
    }
    function backReady() {
        if (backPic.status !== Image.Ready || !backPic.source.toString()) return;
        fx.progress = 0;
        anim.start();
    }

    // No wallpaper chosen yet: a soft gradient in the theme colours
    Rectangle {
        anchors.fill: parent
        visible: win.frontPic.status !== Image.Ready
        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.bgHigh }
            GradientStop { position: 1.0; color: Theme.bg }
        }
    }

    Image {
        id: a
        anchors.fill: parent
        visible: win.front === 0 && !anim.running
        fillMode: Image.PreserveAspectCrop
        sourceSize.width: win.width   // decode at screen size, not the photo's full size
        sourceSize.height: win.height
        asynchronous: true
        cache: false
        onStatusChanged: if (win.front === 1) win.backReady()
    }
    Image {
        id: b
        anchors.fill: parent
        visible: win.front === 1 && !anim.running
        fillMode: Image.PreserveAspectCrop
        sourceSize.width: win.width
        sourceSize.height: win.height
        asynchronous: true
        cache: false
        onStatusChanged: if (win.front === 0) win.backReady()
    }

    // The transition: old (front) → new (back), drawn by the shader or as a fade
    ShaderEffectSource { id: oldSrc; sourceItem: win.frontPic; hideSource: anim.running; live: false; visible: false }
    ShaderEffectSource { id: newSrc; sourceItem: win.backPic; hideSource: anim.running; live: false; visible: false }
    ShaderEffect {
        id: fx
        anchors.fill: parent
        visible: anim.running && win.transition === "sketch"
        property real progress: 0
        property var oldTex: oldSrc
        property var newTex: newSrc
        property size texel: Qt.size(1 / Math.max(1, width), 1 / Math.max(1, height))
        property color ink: Theme.accent
        fragmentShader: Quickshell.shellDir + "/shaders/sketch.frag.qsb"
    }
    Item { // the plain fade
        anchors.fill: parent
        visible: anim.running && win.transition !== "sketch"
        ShaderEffectSource { anchors.fill: parent; sourceItem: oldSrc.sourceItem; live: false }
        ShaderEffectSource { anchors.fill: parent; sourceItem: newSrc.sourceItem; live: false; opacity: fx.progress }
    }
    NumberAnimation {
        id: anim
        target: fx
        property: "progress"
        from: 0
        to: 1
        duration: win.transition === "sketch" ? win.duration : 600
        easing.type: Easing.InOutSine
        onStarted: { oldSrc.scheduleUpdate(); newSrc.scheduleUpdate() }
        onFinished: { win.front = 1 - win.front; win.backPic.source = "" } // the new one is in front now
    }
}
