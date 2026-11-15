// Base for the popups that drop down from the bar (player, Wi-Fi, volume, battery, notifications).
// Opens when Popups.open === name, under the button that opened it; a click anywhere else or
// Esc closes it. Put the content inside: it's stacked in a column with `spacing` between items.
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

PanelWindow {
    id: win
    property string name
    property int panelWidth: 320
    property bool centred: false     // centre of the screen (the player)
    property bool alignRight: false  // against the right edge (notifications)
    property int padding: 16
    property int cardRadius: 24
    property alias spacing: column.spacing
    default property alias content: column.data
    readonly property bool shown: Popups.open === name
    readonly property int shadowPad: 28 // room around the card for its shadow

    signal opened()

    anchors { top: true; left: true }
    exclusiveZone: 0
    margins.top: Theme.popupTop - shadowPad / 2
    margins.left: {
        const sw = screen?.width ?? 1920;
        let x;
        if (centred) x = (sw - panelWidth) / 2;
        else if (alignRight || Popups.anchorX < 0) x = sw - panelWidth - Theme.barSide;
        else x = Popups.anchorX - panelWidth / 2;
        return Math.round(Math.max(Theme.barSide, Math.min(sw - panelWidth - Theme.barSide, x))) - shadowPad;
    }
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "qs-popup"
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    color: "transparent"
    implicitWidth: panelWidth + 2 * shadowPad
    implicitHeight: card.implicitHeight + 2 * shadowPad
    mask: Region { item: card } // the shadow area doesn't catch clicks

    visible: shown || card.opacity > 0
    onShownChanged: if (shown) { opened(); keys.forceActiveFocus() }

    HyprlandFocusGrab {
        windows: [win]
        active: win.shown
        onCleared: Popups.close(win.name)
    }

    RectangularShadow {
        anchors.fill: card
        opacity: card.opacity * 0.5
        offset.y: 18
        blur: 50
        radius: card.radius
        color: "black"
    }

    Rectangle {
        id: card
        x: win.shadowPad
        y: win.shadowPad + (win.shown ? 0 : -8)
        width: win.panelWidth
        implicitHeight: column.implicitHeight + 2 * win.padding
        radius: Theme.r(win.cardRadius)
        color: Theme.bgLow
        opacity: win.shown ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        Behavior on y { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        Item {
            id: keys
            focus: true
            Keys.onEscapePressed: Popups.close(win.name)
        }

        ColumnLayout {
            id: column
            x: win.padding
            y: win.padding
            width: parent.width - 2 * win.padding
            spacing: 12
        }
    }
}
