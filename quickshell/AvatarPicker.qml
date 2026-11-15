// Account picture picker: "Change picture" in the account popup, or
// `qs ipc call avatarpicker toggle`. A grid of your pictures (tabs for each folder) with a big
// round preview of the one you're on. Click to choose, double-click or Enter to use it, Esc closes.
// The picture is copied to ~/.face (and ~/.face.icon) by scripts/pick-avatar.
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
    property string chosen: ""
    readonly property var tabs: [
        // your folders (settings.nix desktop.folders)
        { name: "Pictures",    folder: Settings.pictures },
        { name: "Screenshots", folder: Settings.screenshots },
        { name: "Wallpapers",  folder: Settings.wallpapers }
    ]

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-avatarpicker"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    color: "transparent"
    visible: open || stage.opacity > 0

    IpcHandler {
        target: "avatarpicker"
        function toggle(): void { win.open = !win.open }
        function open(): void { win.open = true }
    }
    onOpenChanged: if (open) { Popups.close(); images.refresh(); chosen = ""; keys.forceActiveFocus() }

    ImageList { id: images; folder: win.tabs[win.tab].folder; limit: 400 }
    onTabChanged: chosen = ""

    function use() {
        if (!chosen) return;
        Quickshell.execDetached([Quickshell.shellDir + "/scripts/pick-avatar", chosen]);
        open = false;
    }

    Item {
        id: keys
        focus: true
        Keys.onPressed: e => {
            if (e.key === Qt.Key_Escape) win.open = false;
            else if (e.key === Qt.Key_Tab) win.tab = (win.tab + 1) % win.tabs.length;
            else if (e.key === Qt.Key_Backtab) win.tab = (win.tab + win.tabs.length - 1) % win.tabs.length;
            else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) win.use();
            else return;
            e.accepted = true;
        }
    }

    Item {
        id: stage
        anchors.fill: parent
        opacity: win.open ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.55)
            MouseArea { anchors.fill: parent; onClicked: win.open = false }
        }

        RectangularShadow { anchors.fill: card; radius: card.radius; offset.y: 18; blur: 50; color: Qt.rgba(0, 0, 0, 0.5) }
        Rectangle {
            id: card
            anchors.centerIn: parent
            width: Math.min(parent.width - 120, 1080)
            height: Math.min(parent.height - 120, 700)
            radius: Theme.r(32)
            color: Theme.bgLow
            MouseArea { anchors.fill: parent } // clicks inside don't close it

            RowLayout {
                anchors { fill: parent; margins: 28 }
                spacing: 28

                // ---- preview ----
                ColumnLayout {
                    Layout.preferredWidth: 260
                    Layout.fillHeight: true
                    spacing: 16
                    Txt { heading: true; text: "Your picture"; font.pixelSize: 22 }
                    Item {
                        Layout.preferredWidth: 220
                        Layout.preferredHeight: 220
                        Layout.alignment: Qt.AlignHCenter
                        Avatar { anchors.fill: parent; size: 220; visible: win.chosen === "" }
                        ClippingRectangle {
                            anchors.fill: parent
                            visible: win.chosen !== ""
                            radius: width / 2
                            color: Theme.bgMid
                            border.color: Theme.accent
                            border.width: 3
                            Image {
                                anchors.fill: parent
                                source: win.chosen ? Theme.fileUrl(win.chosen) : ""
                                fillMode: Image.PreserveAspectCrop
                                sourceSize.width: 440
                                asynchronous: true
                            }
                        }
                    }
                    Txt {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: win.chosen ? win.chosen.split("/").pop() : "Pick one on the right"
                        elide: Text.ElideMiddle
                        font.pixelSize: 12
                        color: Theme.textDim
                    }
                    Item { Layout.fillHeight: true }
                    Clicky {
                        Layout.fillWidth: true
                        implicitHeight: 48
                        radius: Theme.r(14)
                        base: Theme.accent
                        active: win.chosen !== ""
                        opacity: active ? 1 : 0.5
                        onClicked: win.use()
                        Txt { anchors.centerIn: parent; text: "Use this picture"; font.weight: Font.DemiBold; color: Theme.textOnAccent }
                    }
                    Clicky {
                        Layout.fillWidth: true
                        implicitHeight: 44
                        radius: Theme.r(14)
                        base: Theme.bgHigh
                        onClicked: win.open = false
                        Txt { anchors.centerIn: parent; text: "Cancel"; font.weight: Font.DemiBold }
                    }
                }

                // ---- tabs + grid ----
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 14
                    RowLayout {
                        spacing: 6
                        Repeater {
                            model: win.tabs
                            Clicky {
                                id: t
                                required property var modelData
                                required property int index
                                readonly property bool on: win.tab === index
                                implicitWidth: tText.implicitWidth + 28
                                implicitHeight: 36
                                radius: Theme.r(12)
                                base: on ? Theme.accent : "transparent"
                                onClicked: win.tab = index
                                Txt { id: tText; anchors.centerIn: parent; text: t.modelData.name; font.weight: Font.DemiBold; color: t.on ? Theme.textOnAccent : Theme.textDim }
                            }
                        }
                        Item { Layout.fillWidth: true }
                        Txt { text: images.files.length + " pictures"; font.pixelSize: 12; color: Theme.textDim }
                    }
                    GridView {
                        id: grid
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        cellWidth: Math.floor(width / Math.max(1, Math.floor(width / 128)))
                        cellHeight: cellWidth
                        model: images.files
                        boundsBehavior: Flickable.StopAtBounds
                        delegate: Item {
                            id: cell
                            required property string modelData
                            width: grid.cellWidth
                            height: grid.cellHeight
                            readonly property bool on: win.chosen === modelData
                            ClippingRectangle {
                                anchors { fill: parent; margins: 4 }
                                radius: Theme.r(16)
                                color: Theme.bgMid
                                border.color: cell.on ? Theme.accent : "transparent"
                                border.width: 3
                                scale: hov.hovered && !cell.on ? 1.04 : 1
                                Behavior on scale { NumberAnimation { duration: 120 } }
                                Image {
                                    anchors.fill: parent
                                    source: Theme.fileUrl(cell.modelData)
                                    fillMode: Image.PreserveAspectCrop
                                    sourceSize.width: 256
                                    asynchronous: true
                                }
                            }
                            HoverHandler { id: hov; cursorShape: Qt.PointingHandCursor }
                            TapHandler {
                                onTapped: win.chosen = cell.modelData
                                onDoubleTapped: { win.chosen = cell.modelData; win.use() }
                            }
                        }
                        Txt {
                            anchors.centerIn: parent
                            visible: images.files.length === 0
                            text: images.loading ? "Looking…" : "No pictures in " + win.tabs[win.tab].folder
                            color: Theme.textDim
                        }
                    }
                }
            }
        }
    }
}
