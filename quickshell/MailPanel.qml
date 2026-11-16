// Unread mail per account: opens from the bar's mail icon when more than one Google account
// has unread mail (with one, the icon opens that inbox straight away). Counts from Gcal.qml.
import QtQuick
import QtQuick.Layouts

Dropdown {
    id: win
    name: "mail"
    panelWidth: 280
    padding: 10
    spacing: 2

    onOpened: Gcal.fetchUnread()

    Txt { Layout.leftMargin: 8; Layout.topMargin: 4; Layout.bottomMargin: 4; text: "Unread mail"; font.pixelSize: 12; font.weight: Font.DemiBold; color: Theme.textDim }
    Repeater {
        model: Gcal.unreadAccounts
        Clicky {
            id: acct
            required property var modelData
            Layout.fillWidth: true
            implicitHeight: 48
            radius: Theme.r(14)
            onClicked: { Popups.close(); Gcal.openMail(modelData.account) }
            RowLayout {
                anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                spacing: 10
                Icon { name: "mail"; size: 17; color: Theme.textDim }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Txt { Layout.fillWidth: true; text: acct.modelData.name; font.pixelSize: 13; font.weight: Font.DemiBold; elide: Text.ElideRight }
                    Txt { Layout.fillWidth: true; text: acct.modelData.account; font.pixelSize: 11; color: Theme.textDim; elide: Text.ElideRight }
                }
                Rectangle {
                    implicitWidth: Math.max(22, n.implicitWidth + 12)
                    implicitHeight: 20
                    radius: 10
                    color: Theme.accent
                    Txt { id: n; anchors.centerIn: parent; text: Gcal.count(acct.modelData.unread); font.pixelSize: 11; font.weight: Font.Bold; color: Theme.textOnAccent }
                }
            }
        }
    }
}
