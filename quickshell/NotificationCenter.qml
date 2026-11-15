// The notification list: click the bell in the bar (or Super+N / `qs ipc call notifs toggleCenter`).
// Do not disturb, Clear all, and every notification until you dismiss it.
import QtQuick
import QtQuick.Layouts
import Quickshell

Dropdown {
    id: win
    name: "notifs"
    panelWidth: 380
    alignRight: true
    cardRadius: 28

    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: 4
        Txt { Layout.fillWidth: true; heading: true; text: "Notifications"; font.pixelSize: 17 }
        Clicky {
            visible: Notifs.count > 0
            implicitWidth: clearText.implicitWidth + 20
            implicitHeight: 36
            onClicked: Notifs.clear()
            Txt { id: clearText; anchors.centerIn: parent; text: "Clear all"; font.weight: Font.DemiBold; color: Theme.accent }
        }
    }

    // Do not disturb
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 52
        radius: Theme.r(16)
        color: Theme.bgMid
        RowLayout {
            anchors { fill: parent; leftMargin: 12; rightMargin: 4 }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Txt { text: "Do not disturb"; font.pixelSize: 14; font.weight: Font.DemiBold }
                Txt { text: Notifs.dnd ? "Popups hidden, still listed here" : "Off"; font.pixelSize: 12; color: Theme.textDim }
            }
            Clicky {
                implicitWidth: 56
                implicitHeight: 44
                onClicked: Notifs.dnd = !Notifs.dnd
                Toggle { anchors.centerIn: parent; on: Notifs.dnd }
            }
        }
    }

    Txt {
        visible: Notifs.count === 0
        Layout.fillWidth: true
        Layout.topMargin: 16
        Layout.bottomMargin: 16
        horizontalAlignment: Text.AlignHCenter
        text: "All caught up."
        font.pixelSize: 14
        color: Theme.textDim
    }

    Flickable {
        visible: Notifs.count > 0
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(cards.implicitHeight, 600)
        contentHeight: cards.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        ColumnLayout {
            id: cards
            width: parent.width
            spacing: 8
            Repeater {
                model: Notifs.all.slice().reverse() // newest first
                NotificationCard {
                    required property var modelData
                    notif: modelData
                    Layout.fillWidth: true
                }
            }
        }
    }
}
