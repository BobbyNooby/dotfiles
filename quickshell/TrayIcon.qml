// A tray app's icon in one colour (the bar's text colour, so it follows the wallpaper).
// Known apps get a clean one-colour icon (Papirus's panel icons, or one of Icon.qml's);
// anything else is drawn as a silhouette of its own icon.
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets

Item {
    id: root
    required property var item
    property int size: 16
    property color color: Theme.text
    implicitWidth: size
    implicitHeight: size

    readonly property string key: ((item?.id ?? "") + " " + (item?.title ?? "") + " " + (item?.tooltipTitle ?? "")).toLowerCase()
    // our own line icon for these
    readonly property string lineIcon: /surfshark/.test(key) ? "shield" : /syncthing/.test(key) ? "sync" : /spotifast/.test(key) ? "music" : ""
    // one-colour icons from the Papirus theme for these
    readonly property string themed: /discord|vesktop|vencord/.test(key) ? "discord-tray"
        : /telegram/.test(key) ? "telegram-panel" : /spotify/.test(key) ? "spotify-indicator"
        : /steam/.test(key) ? "steam_tray_mono" : ""

    // A theme icon no installed theme has (fcitx5's "input-keyboard-symbolic") loads as a blank
    // square, which the mask below turns into a solid block: draw a plain window icon instead
    readonly property string iconName: { const m = String(item?.icon ?? "").match(/^image:\/\/icon\/([^?]+)/); return m ? m[1] : "" }
    readonly property bool missing: lineIcon === "" && themed === "" && iconName !== "" && !Quickshell.hasThemeIcon(iconName)
    Icon {
        visible: root.lineIcon !== "" || root.missing
        anchors.centerIn: parent
        name: root.lineIcon || "window"
        size: root.size
        stroke: 2
        color: root.color
    }

    // Everything else: the icon's shape, filled with one colour
    IconImage {
        id: src
        anchors.fill: parent
        implicitSize: root.size
        source: root.themed ? "file:///etc/profiles/per-user/" + Quickshell.env("USER") + "/share/icons/Papirus-Dark/22x22/panel/" + root.themed + ".svg"
            : (root.item?.icon ?? "")
        visible: false
        layer.enabled: true
    }
    Rectangle {
        visible: root.lineIcon === "" && !root.missing
        anchors.fill: parent
        color: root.color
        layer.enabled: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: src
            maskThresholdMin: 0.4
            maskSpreadAtMin: 0.3
        }
    }
}
