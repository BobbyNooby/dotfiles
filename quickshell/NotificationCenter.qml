// The notification list: click the bell in the bar (or Super+N / `qs ipc call notifs toggleCenter`).
// Do not disturb, Clear all, and every notification until you dismiss it, grouped by app. Each
// app's header: mute (no popups from it, still listed here; remembered), clear that app, and
// "+N more" to open the rest. Muted apps are listed at the bottom to unmute.
import QtQuick
import QtQuick.Layouts

Dropdown {
    id: win
    name: "notifs"
    panelWidth: 380
    alignRight: true
    cardRadius: 28

    // Apps whose group is opened past the first three. Kept here, not in the group below:
    // the groups are rebuilt whenever a notification arrives or goes, which closed them all.
    property var expandedApps: []
    function toggleExpanded(app) {
        expandedApps = expandedApps.includes(app) ? expandedApps.filter(a => a !== app) : [...expandedApps, app];
    }
    Connections { // an app with nothing left starts closed next time
        target: Notifs
        function onGroupsChanged() {
            const left = win.expandedApps.filter(a => Notifs.groups.some(g => g.app === a));
            if (left.length !== win.expandedApps.length) win.expandedApps = left;
        }
    }

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
        id: notifFlick
        SmoothWheel { flick: notifFlick }
        visible: Notifs.count > 0
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(groupsCol.implicitHeight, 600)
        contentHeight: groupsCol.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        ColumnLayout {
            id: groupsCol
            width: parent.width
            spacing: 14
            Repeater {
                model: Notifs.groups
                ColumnLayout {
                    id: group
                    required property var modelData
                    readonly property string app: modelData.app
                    readonly property bool muted: Notifs.isMuted(app)
                    readonly property bool expanded: win.expandedApps.includes(app)
                    Layout.fillWidth: true
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 6
                        spacing: 2
                        Txt { Layout.fillWidth: true; text: group.app + "  ·  " + group.modelData.items.length; elide: Text.ElideRight; font.pixelSize: 13; font.weight: Font.DemiBold; color: Theme.textDim }
                        Clicky { // mute this app's popups
                            implicitWidth: 32; implicitHeight: 32
                            onClicked: Notifs.toggleMute(group.app)
                            Icon { anchors.centerIn: parent; name: "bell"; size: 15; color: group.muted ? Theme.danger : Theme.textDim }
                            Icon { anchors.centerIn: parent; visible: group.muted; name: "slash"; size: 15; stroke: 2; color: Theme.danger }
                        }
                        Clicky { // clear this app
                            implicitWidth: 32; implicitHeight: 32
                            onClicked: Notifs.clearApp(group.app)
                            Icon { anchors.centerIn: parent; name: "close"; size: 14; color: Theme.textDim }
                        }
                    }
                    Repeater {
                        model: group.expanded ? group.modelData.items : group.modelData.items.slice(0, 3)
                        NotificationCard {
                            required property var modelData
                            notif: modelData
                            Layout.fillWidth: true
                        }
                    }
                    Clicky {
                        visible: group.modelData.items.length > 3
                        Layout.alignment: Qt.AlignHCenter
                        implicitWidth: moreText.implicitWidth + 20
                        implicitHeight: 28
                        onClicked: win.toggleExpanded(group.app)
                        Txt { id: moreText; anchors.centerIn: parent; text: group.expanded ? "Show less" : "+" + (group.modelData.items.length - 3) + " more"; font.pixelSize: 12; color: Theme.accent }
                    }
                }
            }
        }
    }

    // Muted apps: click one to unmute
    ColumnLayout {
        visible: Notifs.muted.length > 0
        Layout.fillWidth: true
        Layout.leftMargin: 6
        spacing: 6
        Txt { text: "Muted (no popups)"; font.pixelSize: 12; color: Theme.textDim }
        Flow {
            Layout.fillWidth: true
            spacing: 6
            Repeater {
                model: Notifs.muted
                Clicky {
                    required property string modelData
                    implicitWidth: chip.implicitWidth + 24
                    implicitHeight: 28
                    onClicked: Notifs.toggleMute(modelData)
                    Rectangle { anchors.fill: parent; radius: height / 2; color: Theme.bgMid }
                    Txt { id: chip; anchors.centerIn: parent; text: parent.modelData + "  ✕"; font.pixelSize: 12 }
                }
            }
        }
    }
}
