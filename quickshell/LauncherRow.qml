// One line of the launcher's list (Launcher.qml): a small section label, or a result with its
// icon (a line icon, an app icon or an emoji), title, grey line under it, and a state chip
// ("On", "Off", "Current") on the right. The chosen row is filled in the accent colour.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

Item {
    id: row
    required property var modelData
    required property int index
    property bool selected: false
    property bool confirming: false // first Enter on a power action: "press again"
    signal picked()
    signal hovered()

    readonly property var it: modelData
    readonly property bool header: !!it.header
    // live state for toggles: a function, so the binding follows Net.wifiOn etc.
    readonly property string badge: typeof it.badge === "function" ? it.badge() : (it.badge ?? "")
    // the app's themed icon; "" when the theme hasn't got it (then a line icon is drawn instead)
    readonly property string appSrc: !it.appIcon ? "" : it.appIcon.startsWith("/") ? Theme.fileUrl(it.appIcon)
        : Quickshell.iconPath(it.appIcon, true)

    implicitHeight: header ? 28 : (it.sub || confirming ? 50 : 40)

    Txt { // section label
        visible: row.header
        anchors { left: parent.left; leftMargin: 14; bottom: parent.bottom; bottomMargin: 5 }
        text: row.it.label ?? ""
        font.pixelSize: 11
        font.weight: Font.DemiBold
        font.letterSpacing: 0.4
        color: Theme.textDim
    }

    Clicky {
        id: box
        visible: !row.header
        anchors.fill: parent
        radius: Theme.r(14)
        base: row.selected ? (row.confirming ? Theme.danger : Theme.accent) : "transparent"
        hoverColor: Theme.alpha(Theme.text, 0.06)
        onClicked: row.picked()
        onHoveredChanged: if (hovered) row.hovered()
        readonly property color fg: row.selected ? Theme.textOnAccent : Theme.text
        readonly property color fgDim: row.selected ? Theme.alpha(Theme.textOnAccent, 0.75) : Theme.textDim

        RowLayout {
            anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
            spacing: 12

            Item { // the picture: app icon, emoji or line icon
                implicitWidth: 28
                implicitHeight: 28
                IconImage {
                    anchors.centerIn: parent
                    visible: row.appSrc !== ""
                    implicitSize: 26
                    source: row.appSrc
                }
                Text {
                    anchors.centerIn: parent
                    visible: !!row.it.glyph
                    text: row.it.glyph ?? ""
                    font.pixelSize: 22
                }
                Icon {
                    anchors.centerIn: parent
                    visible: row.appSrc === "" && !row.it.glyph
                    name: row.it.icon ?? (row.it.appIcon ? "window" : "chevron")
                    size: 19
                    color: box.fg
                    cutout: row.selected ? Theme.accent : Theme.bgLow
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Txt {
                    Layout.fillWidth: true
                    text: row.it.title ?? ""
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                    font.pixelSize: row.it.big ? 18 : 14
                    font.weight: row.it.big ? Font.DemiBold : Font.Medium
                    font.family: row.it.mono ? Theme.mono : Theme.font
                    color: box.fg
                }
                Txt {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: row.confirming ? (row.it.confirm ?? "") : (row.it.sub ?? "")
                    elide: Text.ElideMiddle
                    textFormat: Text.PlainText
                    font.pixelSize: 12
                    font.weight: row.confirming ? Font.DemiBold : Font.Normal
                    color: box.fgDim
                }
            }

            Rectangle { // state chip
                visible: row.badge !== ""
                implicitWidth: chip.implicitWidth + 16
                implicitHeight: 22
                radius: 11
                readonly property bool on: row.badge === "On" || row.badge === "Current" || row.badge === "Connected"
                color: row.selected ? Theme.alpha(Theme.textOnAccent, 0.18)
                     : on ? Theme.accentSoft : Theme.bgHigh
                Txt {
                    id: chip
                    anchors.centerIn: parent
                    text: row.badge
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    color: row.selected ? Theme.textOnAccent : parent.on ? Theme.textOnSoft : Theme.textDim
                }
            }
            Txt { // what Enter does on the chosen row
                visible: row.selected && !row.confirming
                text: "↵"
                font.pixelSize: 14
                color: box.fgDim
            }
        }
    }
}
