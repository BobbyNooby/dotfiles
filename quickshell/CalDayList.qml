// The chosen day's events under the month (CalMonth.qml), shared by the calendar popup and the
// desktop Calendar card: time, title, calendar colour, place; click = open in Google Calendar,
// Join = the Meet call. Today with nothing (left) on it shows what's coming up instead.
// Not signed in: a card that opens Settings → Accounts. Footer: Open Google Calendar, the
// "offline · as of" note and refresh.
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: list
    property date day: new Date()
    property int maxListHeight: 260
    property int upcomingCount: 10
    spacing: 10

    readonly property bool isToday: { Gcal.tick; return Gcal.dayKey(day) === Gcal.dayKey(new Date()) }
    readonly property var dayEvents: { Gcal.events; return Gcal.eventsOn(day) }
    // today, and everything on it is over (or nothing was on): show the next events instead
    readonly property bool upcomingMode: { Gcal.tick; return isToday && !dayEvents.some(e => e._e > Date.now()) && Gcal.upcoming(1).length > 0 }
    readonly property var shown: upcomingMode ? Gcal.upcoming(upcomingCount) : dayEvents

    Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.alpha(Theme.textDim, 0.12) }

    // ---- not signed in ----
    Rectangle {
        visible: Gcal.loaded && !Gcal.connected
        Layout.fillWidth: true
        implicitHeight: hello.implicitHeight + 28
        radius: Theme.r(18)
        color: Theme.bgMid
        ColumnLayout {
            id: hello
            x: 14; y: 14
            width: parent.width - 28
            spacing: 8
            RowLayout {
                spacing: 10
                Icon { name: "calendar"; size: 20; color: Theme.accent }
                Txt { text: "Your Google Calendar here"; font.pixelSize: 14; font.weight: Font.DemiBold }
            }
            Txt {
                Layout.fillWidth: true
                text: Gcal.noHermes ? "Needs Hermes and its google-workspace skill. Install Hermes, then connect an account."
                    : "Connect a Google account to see your events here and on the desktop, and unread mail in the bar."
                wrapMode: Text.Wrap
                font.pixelSize: 12
                color: Theme.textDim
            }
            SetButton { text: "Connect Google"; accent: true; onClicked: { Popups.close(); Gcal.openSettings() } }
        }
    }

    // ---- the chosen day ----
    ColumnLayout {
        visible: Gcal.connected
        Layout.fillWidth: true
        spacing: 6
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 4
            Txt {
                Layout.fillWidth: true
                text: list.upcomingMode ? (list.dayEvents.length ? "Nothing more today · coming up" : "Nothing today · coming up")
                    : (list.isToday ? "Today · " : Gcal.dayKey(list.day) === Gcal.dayKey(Gcal.addDays(new Date(), 1)) ? "Tomorrow · " : "")
                    + Qt.formatDate(list.day, "dddd d MMMM")
                font.pixelSize: 12
                font.weight: Font.DemiBold
                color: Theme.textDim
            }
            Txt { text: !list.upcomingMode && list.shown.length ? list.shown.length + (list.shown.length === 1 ? " event" : " events") : ""; font.pixelSize: 11; color: Theme.outline }
        }
        Txt {
            visible: !list.shown.length
            Layout.leftMargin: 4
            Layout.topMargin: 2
            Layout.bottomMargin: 4
            text: !Gcal.eventsAt && Gcal.busy ? "Loading your calendar…" : "Nothing on. Free day."
            color: Theme.textDim
        }
        Flickable {
            id: flick
            visible: list.shown.length > 0
            Layout.fillWidth: true
            implicitHeight: Math.min(evCol.implicitHeight, list.maxListHeight)
            contentHeight: evCol.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            clip: true
            interactive: contentHeight > height
            SmoothWheel { flick: flick }
            ColumnLayout {
                id: evCol
                width: flick.width
                spacing: 4
                Repeater {
                    model: list.shown
                    Clicky {
                        id: ev
                        required property var modelData
                        readonly property bool past: { Gcal.tick; return modelData._e <= Date.now() }
                        Layout.fillWidth: true
                        implicitHeight: evRow.implicitHeight + 16
                        radius: Theme.r(14)
                        base: Theme.bgMid
                        onClicked: { Popups.close(); Gcal.openEvent(modelData) }
                        RowLayout {
                            id: evRow
                            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 8; rightMargin: 8 }
                            spacing: 10
                            Rectangle { // the calendar's colour
                                Layout.fillHeight: true
                                implicitWidth: 4
                                radius: 2
                                color: ev.modelData.color || Theme.accent
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                opacity: ev.past ? 0.55 : 1
                                Txt { Layout.fillWidth: true; text: list.upcomingMode ? Gcal.whenText(ev.modelData) : Gcal.timeText(ev.modelData, list.day); font.pixelSize: 11; font.weight: Font.DemiBold; color: Theme.textDim }
                                Txt { Layout.fillWidth: true; text: ev.modelData.title; font.pixelSize: 13; font.weight: Font.DemiBold; elide: Text.ElideRight; maximumLineCount: 2; wrapMode: Text.Wrap }
                                RowLayout {
                                    visible: !!ev.modelData.location
                                    Layout.fillWidth: true
                                    spacing: 4
                                    Icon { name: "pin"; size: 12; color: Theme.textDim }
                                    Txt { Layout.fillWidth: true; text: ev.modelData.location ?? ""; font.pixelSize: 11; color: Theme.textDim; elide: Text.ElideRight }
                                }
                                Txt { // which calendar (and account, with several)
                                    Layout.fillWidth: true
                                    text: ev.modelData.calendar + (Gcal.accounts.length > 1 && ev.modelData.calendar !== Gcal.emailOf(ev.modelData.accountName) ? " · " + ev.modelData.accountName : "")
                                    font.pixelSize: 10
                                    color: Theme.outline
                                    elide: Text.ElideRight
                                }
                            }
                            Clicky {
                                visible: !!ev.modelData.meet && !ev.past
                                implicitWidth: joinRow.implicitWidth + 18
                                implicitHeight: 30
                                radius: Theme.r(10)
                                base: Theme.accent
                                onClicked: { Popups.close(); Gcal.open(ev.modelData.meet) }
                                RowLayout {
                                    id: joinRow
                                    anchors.centerIn: parent
                                    spacing: 5
                                    Icon { name: "video"; size: 14; stroke: 2; color: Theme.textOnAccent }
                                    Txt { text: "Join"; font.pixelSize: 12; font.weight: Font.DemiBold; color: Theme.textOnAccent }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ---- footer ----
    RowLayout {
        visible: Gcal.connected
        Layout.fillWidth: true
        spacing: 6
        Clicky {
            implicitWidth: openRow.implicitWidth + 16
            implicitHeight: 30
            radius: Theme.r(10)
            onClicked: { Popups.close(); Gcal.openCalendar(list.day) }
            RowLayout {
                id: openRow
                anchors.centerIn: parent
                spacing: 6
                Icon { name: "link"; size: 14; color: Theme.accent }
                Txt { text: "Open Google Calendar"; font.pixelSize: 12; font.weight: Font.DemiBold; color: Theme.accent }
            }
        }
        Txt {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignRight
            text: Gcal.staleText
            font.pixelSize: 11
            color: Theme.outline
            elide: Text.ElideLeft
        }
        Clicky { // fetch again now
            implicitWidth: 30; implicitHeight: 30; radius: Theme.r(10)
            onClicked: Gcal.refresh()
            Icon {
                id: syncIcon
                anchors.centerIn: parent
                name: "sync"; size: 15; color: Theme.textDim
                RotationAnimation on rotation { running: Gcal.busy; from: 0; to: 360; duration: 1000; loops: Animation.Infinite; onRunningChanged: if (!running) syncIcon.rotation = 0 }
            }
        }
    }
}
