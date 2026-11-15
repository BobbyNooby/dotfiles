// Wallpaper switcher (Super+W, or `qs ipc call wallpicker toggle`), in the spirit of the old
// Xbox 360 dashboard:
//   tabs      your picture folders across the top: Tab / Shift+Tab (or Q / E), or click
//   compare   "Now" next to "New": both pictures with the colours each gives the whole desktop
//             (matugen --dry-run, nothing applied until you choose)
//   carousel  a floating, tilting row of pictures: ← → or the wheel to browse, click to pick
// Enter (or Apply) sets it through `setwall`, which recolours everything. Esc closes.
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets

PanelWindow {
    id: win
    property bool open: false
    property int tab: 0
    readonly property var tabs: [
        // your folders (settings.nix desktop.folders)
        { name: "Wallpapers",  folder: Settings.wallpapers },
        { name: "Pictures",    folder: Settings.pictures },
        { name: "Screenshots", folder: Settings.screenshots }
    ]

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-wallpicker"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    color: "transparent"
    visible: open || stage.opacity > 0

    IpcHandler {
        target: "wallpicker"
        function toggle(): void { win.open = !win.open }
        function open(): void { win.open = true }
        function close(): void { win.open = false }
    }
    onOpenChanged: if (open) { Popups.close(); images.refresh(); keys.forceActiveFocus() }

    // ---- data ----
    ImageList { id: images; folder: win.tabs[win.tab].folder }
    property string current: "" // the wallpaper in use (same file Wallpaper.qml watches)
    FileView {
        path: Quickshell.env("HOME") + "/.local/state/wallpaper/path"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: { const p = text().trim(); if (p) win.current = p }
        printErrors: false
    }
    readonly property string selected: images.files[carousel.currentIndex] ?? ""
    WallColors { id: nowPal; image: win.current }
    WallColors { id: newPal; image: win.selected }

    // Start on the wallpaper you have, when it's in this folder
    Connections {
        target: images
        function onFilesChanged() {
            const i = images.files.indexOf(win.current);
            carousel.currentIndex = i >= 0 ? i : 0;
        }
    }

    function switchTab(d) { tab = (tab + d + tabs.length) % tabs.length }
    function apply() {
        if (!selected) return;
        // setwall recolours everything; if it fails, say so with its last error line
        Quickshell.execDetached(["sh", "-c", "err=$(setwall \"$1\" 2>&1 >/dev/null) || notify-send -a Wallpaper 'Wallpaper not changed' \"$(printf '%s' \"$err\" | tail -1)\"", "sh", selected]);
        open = false;
    }

    Item {
        id: keys
        focus: true
        Keys.onPressed: e => {
            if (e.key === Qt.Key_Escape) win.open = false;
            else if (e.key === Qt.Key_Left) carousel.decrementCurrentIndex();
            else if (e.key === Qt.Key_Right) carousel.incrementCurrentIndex();
            else if (e.key === Qt.Key_Tab || e.key === Qt.Key_E) win.switchTab(1);
            else if (e.key === Qt.Key_Backtab || e.key === Qt.Key_Q) win.switchTab(-1);
            else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) win.apply();
            else return;
            e.accepted = true;
        }
    }

    // A big picture with its label and the colours it gives the desktop
    component Preview: ColumnLayout {
        id: pv
        property string label
        property string image
        property var colors: []
        property bool highlight: false
        spacing: 12
        Item {
            Layout.preferredWidth: 540
            Layout.preferredHeight: 304
            RectangularShadow { anchors.fill: frame; radius: frame.radius; offset.y: 18; blur: 40; color: Qt.rgba(0, 0, 0, 0.55) }
            ClippingRectangle {
                id: frame
                anchors.fill: parent
                radius: Theme.r(24)
                color: Theme.bgMid
                border.color: pv.highlight ? Theme.accent : "transparent"
                border.width: 3
                Image {
                    anchors.fill: parent
                    source: pv.image ? Theme.fileUrl(pv.image) : ""
                    fillMode: Image.PreserveAspectCrop
                    sourceSize.width: 1080
                    asynchronous: true
                }
            }
            Rectangle { // label chip
                anchors { left: parent.left; top: parent.top; margins: 14 }
                implicitWidth: chipText.implicitWidth + 22
                implicitHeight: 30
                radius: Theme.r(10)
                color: pv.highlight ? Theme.accent : Theme.alpha(Theme.bg, 0.8)
                Txt { id: chipText; anchors.centerIn: parent; text: pv.label; font.weight: Font.DemiBold; color: pv.highlight ? Theme.textOnAccent : Theme.text }
            }
        }
        RowLayout { // the colours it gives the desktop
            spacing: 8
            Repeater {
                model: pv.colors
                Rectangle { required property string modelData; implicitWidth: 26; implicitHeight: 26; radius: 13; color: modelData; border.color: Qt.rgba(1, 1, 1, 0.15); border.width: 1 }
            }
            Txt { visible: pv.colors.length === 0; text: "…"; color: Theme.textDim }
        }
    }

    // ---- the stage ----
    Item {
        id: stage
        anchors.fill: parent
        opacity: win.open ? 1 : 0
        scale: win.open ? 1 : 1.04
        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

        Rectangle { // dim the desktop; click empty space to close
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.6)
            MouseArea { anchors.fill: parent; onClicked: win.open = false }
        }

        ColumnLayout {
            anchors.centerIn: parent
            width: Math.min(parent.width - 120, 1400)
            spacing: 34

            // ---------- tabs ----------
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 44
                Repeater {
                    model: win.tabs
                    Item {
                        id: tabItem
                        required property var modelData
                        required property int index
                        readonly property bool on: win.tab === index
                        implicitWidth: tabText.implicitWidth
                        implicitHeight: 52
                        Txt {
                            id: tabText
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 10
                            heading: true
                            text: tabItem.modelData.name
                            font.pixelSize: tabItem.on ? 34 : 22
                            color: tabItem.on ? Theme.text : Theme.alpha(Theme.text, 0.45)
                            Behavior on font.pixelSize { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        }
                        Rectangle { // accent bar under the open tab
                            anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter }
                            height: 4
                            radius: 2
                            width: tabItem.on ? tabText.implicitWidth : 0
                            color: Theme.accent
                            Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.tab = tabItem.index }
                    }
                }
            }

            // ---------- Now vs New ----------

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 28
                Preview { label: "Now"; image: win.current; colors: nowPal.colors }
                Icon { Layout.alignment: Qt.AlignVCenter; Layout.bottomMargin: 38; name: "next"; size: 28; color: Theme.alpha(Theme.text, 0.6) }
                Preview { label: "New"; image: win.selected; colors: newPal.colors; highlight: true }
            }

            // ---------- the floating carousel ----------
            PathView {
                id: carousel
                Layout.fillWidth: true
                Layout.preferredHeight: 190
                model: images.files
                pathItemCount: 9
                preferredHighlightBegin: 0.5
                preferredHighlightEnd: 0.5
                highlightRangeMode: PathView.StrictlyEnforceRange
                highlightMoveDuration: 260
                snapMode: PathView.SnapOneItem
                path: Path {
                    startX: 0; startY: carousel.height / 2
                    PathAttribute { name: "turn"; value: 62 }
                    PathAttribute { name: "size"; value: 0.62 }
                    PathAttribute { name: "depth"; value: 0 }
                    PathAttribute { name: "fade"; value: 0.35 }
                    PathLine { x: carousel.width / 2; y: carousel.height / 2 }
                    PathAttribute { name: "turn"; value: 0 }
                    PathAttribute { name: "size"; value: 1.12 }
                    PathAttribute { name: "depth"; value: 100 }
                    PathAttribute { name: "fade"; value: 1 }
                    PathLine { x: carousel.width; y: carousel.height / 2 }
                    PathAttribute { name: "turn"; value: -62 }
                    PathAttribute { name: "size"; value: 0.62 }
                    PathAttribute { name: "depth"; value: 0 }
                    PathAttribute { name: "fade"; value: 0.35 }
                }
                delegate: Item {
                    id: card
                    required property string modelData
                    required property int index
                    width: 236
                    height: 140
                    z: PathView.depth ?? 0
                    scale: PathView.size ?? 1
                    opacity: PathView.fade ?? 1
                    transform: Rotation {
                        origin.x: card.width / 2
                        origin.y: card.height / 2
                        axis { x: 0; y: 1; z: 0 }
                        angle: card.PathView.turn ?? 0
                    }
                    ClippingRectangle {
                        anchors.fill: parent
                        radius: Theme.r(16)
                        color: Theme.bgMid
                        border.color: card.PathView.isCurrentItem ? Theme.accent : "transparent"
                        border.width: 3
                        Image {
                            anchors.fill: parent
                            source: Theme.fileUrl(card.modelData)
                            fillMode: Image.PreserveAspectCrop
                            sourceSize.width: 480
                            asynchronous: true
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: card.PathView.isCurrentItem ? win.apply() : carousel.currentIndex = card.index
                    }
                }
                MouseArea { // the wheel browses too
                    anchors.fill: parent
                    acceptedButtons: Qt.NoButton
                    onWheel: w => (w.angleDelta.y || w.angleDelta.x) < 0 ? carousel.incrementCurrentIndex() : carousel.decrementCurrentIndex()
                }
                Txt {
                    anchors.centerIn: parent
                    visible: images.files.length === 0
                    text: images.loading ? "Looking…" : "No pictures in " + win.tabs[win.tab].folder
                    font.pixelSize: 16
                    color: Theme.textDim
                }
            }

            // ---------- hints + apply ----------
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 18
                Txt {
                    text: (images.files.length ? (carousel.currentIndex + 1) + " / " + images.files.length + "   ·   " : "")
                        + "← → browse   ·   Tab folder   ·   Enter apply   ·   Esc close"
                    font.pixelSize: 13
                    color: Theme.alpha(Theme.text, 0.7)
                }
                Clicky {
                    implicitWidth: applyText.implicitWidth + 36
                    implicitHeight: 44
                    radius: Theme.r(14)
                    base: Theme.accent
                    active: win.selected !== "" && win.selected !== win.current
                    opacity: active ? 1 : 0.5
                    onClicked: win.apply()
                    Txt { id: applyText; anchors.centerIn: parent; text: "Apply"; font.weight: Font.DemiBold; color: Theme.textOnAccent }
                }
            }
        }
    }
}
