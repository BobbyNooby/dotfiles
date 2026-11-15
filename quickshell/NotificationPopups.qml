// Notification popups, stacked in the top-right corner under the bar (newest on top).
// They slide in from the right and hide after a few seconds; they stay in the list behind the bell.
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    anchors { top: true; right: true }
    margins { top: Theme.popupTop - 6; right: 16 - 20 }
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Overlay // above fullscreen windows too
    WlrLayershell.namespace: "qs-notifications"
    color: "transparent"
    // hidden while the list is open (it shows the same things)
    visible: Notifs.popups.length > 0 && !Notifs.centerOpen
    implicitWidth: 340 + 40 // + room for the shadow
    implicitHeight: Math.max(1, list.implicitHeight + 40)

    ColumnLayout {
        id: list
        x: 20
        y: 6
        width: 340
        spacing: 8
        Repeater {
            model: [...Notifs.popups].reverse()
            NotificationCard {
                id: pop
                required property var modelData
                notif: modelData
                popup: true
                Layout.fillWidth: true
                onHide: Notifs.dismissPopup(modelData)

                // slide in from the right
                transform: Translate { id: slide; x: 40; Behavior on x { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } } }
                opacity: 0
                Component.onCompleted: { slide.x = 0; opacity = 1 }
                Behavior on opacity { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

                RectangularShadow {
                    z: -1
                    anchors.fill: parent
                    radius: parent.radius
                    offset.y: 14
                    blur: 40
                    color: Qt.rgba(0, 0, 0, 0.45)
                }
            }
        }
    }
}
