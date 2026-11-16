// A month to pick a day from, shared by the calendar popup (CalendarPanel.qml) and the desktop
// Calendar card: Monday first, today ringed, a dot per calendar on days with events (Gcal.qml),
// ‹ › or the mouse wheel for other months, "Today" to come back. `selected` is the chosen day.
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: cal
    property date selected: new Date()
    // the month shown (not bound to `selected`: changing it rebuilds the grid under the click)
    property int year: new Date().getFullYear()
    property int month: new Date().getMonth() // 0..11
    property int cellHeight: 40
    property int titleSize: 19
    spacing: 8

    readonly property string todayKey: { Gcal.tick; return Gcal.dayKey(new Date()) }
    readonly property bool onToday: Gcal.dayKey(selected) === todayKey

    function step(n) {
        const d = new Date(year, month + n, 1);
        year = d.getFullYear();
        month = d.getMonth();
    }
    function goToday() { selected = new Date(); year = selected.getFullYear(); month = selected.getMonth() }
    // The 42 days shown: from the Monday on or before the 1st
    readonly property var cells: {
        const first = new Date(year, month, 1);
        const start = Gcal.addDays(first, -((first.getDay() + 6) % 7));
        const out = [];
        for (let i = 0; i < 42; i++) out.push(Gcal.addDays(start, i));
        return out;
    }
    // A new day (midnight) moves "today" along when today was selected
    onTodayKeyChanged: if (!onToday && Gcal.dayKey(Gcal.addDays(new Date(), -1)) === Gcal.dayKey(selected)) goToday()

    // ---- month header ----
    RowLayout {
        Layout.fillWidth: true
        spacing: 4
        Txt {
            Layout.fillWidth: true
            Layout.leftMargin: 4
            heading: true
            text: Qt.formatDate(new Date(cal.year, cal.month, 1), "MMMM yyyy")
            font.pixelSize: cal.titleSize
            elide: Text.ElideRight
        }
        Clicky {
            visible: cal.year !== new Date().getFullYear() || cal.month !== new Date().getMonth() || !cal.onToday
            implicitWidth: todayLbl.implicitWidth + 20
            implicitHeight: 28
            radius: Theme.r(10)
            base: Theme.bgHigh
            onClicked: cal.goToday()
            Txt { id: todayLbl; anchors.centerIn: parent; text: "Today"; font.pixelSize: 12; font.weight: Font.DemiBold }
        }
        Clicky {
            implicitWidth: 28; implicitHeight: 28; radius: Theme.r(10)
            onClicked: cal.step(-1)
            Icon { anchors.centerIn: parent; name: "chevron"; size: 16; rotation: 180; color: Theme.textDim }
        }
        Clicky {
            implicitWidth: 28; implicitHeight: 28; radius: Theme.r(10)
            onClicked: cal.step(1)
            Icon { anchors.centerIn: parent; name: "chevron"; size: 16; color: Theme.textDim }
        }
    }

    // ---- weekday names, then 6 weeks ----
    Item {
        Layout.fillWidth: true
        implicitHeight: grid.implicitHeight
        WheelHandler { onWheel: e => cal.step(e.angleDelta.y < 0 ? 1 : -1) } // scroll = months
        GridLayout {
            id: grid
            width: parent.width
            columns: 7
            rowSpacing: 2
            columnSpacing: 2
            Repeater {
                model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
                Txt {
                    required property string modelData
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    color: Theme.outline
                }
            }
            Repeater {
                model: cal.cells
                Clicky {
                    id: cell
                    required property var modelData
                    readonly property string key: Gcal.dayKey(modelData)
                    readonly property bool inMonth: modelData.getMonth() === cal.month
                    readonly property bool isToday: key === cal.todayKey
                    readonly property bool isSel: key === Gcal.dayKey(cal.selected)
                    readonly property var dots: { Gcal.events; return Gcal.colorsOn(modelData, 3) }
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    implicitHeight: cal.cellHeight
                    radius: Theme.r(12)
                    base: isSel ? Theme.accentSoft : "transparent"
                    border.width: isToday ? 1.5 : 0
                    border.color: Theme.accent
                    onClicked: {
                        // locals first: moving to another month destroys this cell mid-handler
                        const c = cal, d = modelData, other = !inMonth;
                        c.selected = d;
                        if (other) { c.year = d.getFullYear(); c.month = d.getMonth() }
                    }
                    Txt {
                        anchors { horizontalCenter: parent.horizontalCenter; verticalCenter: parent.verticalCenter; verticalCenterOffset: -3 }
                        text: cell.modelData.getDate()
                        font.pixelSize: 13
                        font.weight: cell.isToday || cell.isSel ? Font.Bold : Font.Normal
                        color: cell.isSel ? Theme.textOnSoft : cell.isToday ? Theme.accent : cell.inMonth ? Theme.text : Theme.outline
                        opacity: cell.inMonth ? 1 : 0.7
                    }
                    Row {
                        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: Math.round(cal.cellHeight / 7) }
                        spacing: 3
                        Repeater {
                            model: cell.dots
                            Rectangle {
                                required property string modelData
                                width: 5; height: 5; radius: 2.5
                                color: modelData
                                opacity: cell.inMonth ? 1 : 0.5
                            }
                        }
                    }
                }
            }
        }
    }
}
