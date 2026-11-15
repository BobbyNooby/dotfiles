// Settings → Appearance: the wallpaper (opens the switcher, Super+W), the typeface (Theme.qml's
// six pairings), the lock screen's glow and which desktop widgets show.
// Typeface, glow and widgets go to ~/.config/desktop/overrides.json (Settings.qml); a note
// under each offers the settings.nix line when it differs from settings.nix.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

SetPage {
    id: page
    title: "Appearance"
    subtitle: "Colours follow the wallpaper (matugen)."

    property string wallpaper: ""
    FileView {
        path: Quickshell.env("HOME") + "/.local/state/wallpaper/path"
        watchChanges: true
        onFileChanged: reload()
        printErrors: false
        onLoaded: page.wallpaper = text().trim()
    }
    // The switcher is an overlay too: close this window first
    function pickWallpaper() { Quickshell.execDetached(["sh", "-c", "qs ipc call settings close; qs ipc call wallpicker open"]) }

    // ---- wallpaper ----
    SetCard {
        title: "Wallpaper"
        RowLayout {
            Layout.fillWidth: true
            Layout.margins: 8
            spacing: 16
            Rectangle {
                implicitWidth: 192
                implicitHeight: 108
                radius: Theme.r(14)
                color: Theme.bgHigh
                clip: true
                Image {
                    anchors.fill: parent
                    source: page.wallpaper ? Theme.fileUrl(page.wallpaper) : ""
                    sourceSize.width: 384
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8
                Txt { Layout.fillWidth: true; text: page.wallpaper ? page.wallpaper.split("/").pop() : "No wallpaper set"; font.pixelSize: 14; font.weight: Font.DemiBold; elide: Text.ElideMiddle }
                Txt { Layout.fillWidth: true; text: "Picking one recolours the whole desktop."; font.pixelSize: 12; color: Theme.textDim; wrapMode: Text.Wrap }
                SetButton { text: "Change wallpaper  (Super+W)"; accent: true; onClicked: page.pickWallpaper() }
            }
        }
    }

    // ---- typeface ----
    SetCard {
        title: "Typeface"
        trailing: Txt { text: "fonts and corners together"; font.pixelSize: 12; color: Theme.outline }
        GridLayout {
            Layout.fillWidth: true
            Layout.margins: 6
            columns: 3
            rowSpacing: 8
            columnSpacing: 8
            Repeater {
                model: Object.keys(Theme.typefaces)
                Clicky {
                    id: tf
                    required property string modelData
                    readonly property var f: Theme.typefaces[modelData]
                    readonly property bool on: Theme.typeface === modelData
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    implicitHeight: 92
                    radius: Math.round(16 * f.radius)
                    base: on ? Theme.accentSoft : Theme.bgHigh
                    border.width: on ? 2 : 0
                    border.color: Theme.accent
                    onClicked: Settings.set("typeface", modelData)
                    ColumnLayout {
                        anchors { fill: parent; margins: 12 }
                        spacing: 2
                        Text {
                            text: "12:34 Aa"
                            font.family: tf.f.display
                            font.pixelSize: 24
                            font.weight: Font.DemiBold
                            font.italic: tf.f.italic
                            color: tf.on ? Theme.textOnSoft : Theme.text
                        }
                        Text {
                            Layout.fillWidth: true
                            text: tf.modelData + " · " + tf.f.display + " + " + tf.f.body
                            font.family: tf.f.body
                            font.pixelSize: 11
                            elide: Text.ElideRight
                            color: tf.on ? Theme.textOnSoft : Theme.textDim
                        }
                    }
                }
            }
        }
        OverrideNote { key: "typeface"; Layout.margins: 6 }
    }

    // ---- lock glow ----
    SetCard {
        title: "Lock screen glow"
        SetChoice {
            Layout.margins: 6
            options: [{ value: "strong", label: "Strong" }, { value: "soft", label: "Soft" }, { value: "off", label: "Off" }]
            current: Settings.lockGlow
            onPicked: v => Settings.set("lockGlow", v)
        }
        Txt { Layout.leftMargin: 12; Layout.bottomMargin: 6; text: "Halos, scanlines and vignette on the Eva lock screen (Super+Escape to try)."; font.pixelSize: 12; color: Theme.textDim }
        OverrideNote { key: "lockGlow"; Layout.margins: 6 }
    }

    // ---- desktop widgets ----
    SetCard {
        title: "Desktop widgets"
        Repeater {
            model: [
                { k: "weather",     label: "Clocks and weather", icon: "sun" },
                { k: "system",      label: "System",             icon: "cpu" },
                { k: "connections", label: "Connections",        icon: "tailscale" },
                { k: "shortcuts",   label: "Shortcuts",          icon: "keyboard" },
                { k: "player",      label: "Music controller",   icon: "music" },
                { k: "lyrics",      label: "Floating lyrics",    icon: "lyrics" }
            ]
            SetRow {
                required property var modelData
                icon: modelData.icon
                label: modelData.label
                toggle: true
                on: Settings.show(modelData.k)
                onSwitched: Settings.setWidget(modelData.k, !on)
            }
        }
        OverrideNote { key: "widgets"; Layout.margins: 6 }
    }
}
