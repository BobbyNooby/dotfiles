// Calendar: click the clock in the bar (or `qs ipc call popups toggle calendar`).
// The month (CalMonth.qml: Monday first, today ringed, a dot per calendar on days with events,
// ‹ › for other months, click a day) and that day's events from every Google account
// (CalDayList.qml, data from Gcal.qml). The desktop Calendar card shows the same two pieces.
import QtQuick
import QtQuick.Layouts

Dropdown {
    id: win
    name: "calendar"
    panelWidth: 348
    padding: 16
    spacing: 10

    onOpened: { month.goToday(); Gcal.refreshIfOld(2) }

    CalMonth { id: month; Layout.fillWidth: true }
    CalDayList { Layout.fillWidth: true; day: month.selected }
}
