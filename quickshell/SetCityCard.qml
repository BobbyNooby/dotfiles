// One city on Settings → Clocks & weather: its time and weather now, and (Edit) its name,
// time zone and place for the forecast. Saving hands the edited city to save(city).
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Rectangle {
    id: card
    property var city
    property bool home: false
    property bool editing: false
    property string error: ""
    signal save(var city)
    readonly property var w: Weather.city(city.id)

    Layout.fillWidth: true
    implicitHeight: col.implicitHeight + 28
    radius: Theme.r(18)
    color: Theme.bgMid

    ColumnLayout {
        id: col
        x: 16
        y: 14
        width: parent.width - 32
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredWidth: col.width
            spacing: 18
            Txt { heading: true; text: Weather.hm(card.city.id); font.pixelSize: 40 }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Txt { text: card.city.name + (card.home ? "  · home" : ""); font.pixelSize: 15; font.weight: Font.DemiBold }
                Txt { text: Weather.dateText(card.city.id) + " · " + (Weather.zoneText(card.city.id) || card.city.tz); font.pixelSize: 12; color: Theme.textDim }
            }
            RowLayout { // weather now
                Layout.fillWidth: false // (layouts fill by default)
                spacing: 8
                Icon { visible: !!card.w && !card.w.offline; name: card.w?.kind ?? "cloud"; size: 26; color: card.w?.kind === "sun" ? Theme.sun : card.w?.kind === "moon" ? Theme.moon : Theme.rain }
                ColumnLayout {
                    spacing: 0
                    Txt { text: !card.w ? "…" : card.w.offline ? "offline" : card.w.temp + "°"; font.pixelSize: 20; font.weight: Font.DemiBold; Layout.alignment: Qt.AlignRight }
                    Txt { visible: !!card.w && !card.w.offline; text: card.w ? (card.w.cond ?? "") + (card.w.hi !== undefined ? " · " + card.w.hi + "° / " + card.w.lo + "°" : "") : ""; font.pixelSize: 11; color: Theme.textDim; Layout.alignment: Qt.AlignRight }
                }
            }
            SetButton { text: card.editing ? "Cancel" : "Edit"; onClicked: { card.editing = !card.editing; card.error = "" } }
        }

        // ---- edit ----
        GridLayout {
            visible: card.editing
            Layout.fillWidth: true
            columns: 4
            rowSpacing: 6
            columnSpacing: 8
            Txt { text: "Name"; font.pixelSize: 12; color: Theme.textDim }
            SetField { id: fName; Layout.fillWidth: true; text: card.city.name ?? "" }
            Txt { text: "Lock screen"; font.pixelSize: 12; color: Theme.textDim }
            SetField { id: fShort; Layout.fillWidth: true; text: card.city.short ?? ""; placeholderText: "SHORT NAME" }
            Txt { text: "Time zone"; font.pixelSize: 12; color: Theme.textDim }
            SetField { id: fTz; Layout.fillWidth: true; text: card.city.tz ?? ""; placeholderText: "Region/City, e.g. Asia/Tokyo" }
            Txt { text: "Zone label"; font.pixelSize: 12; color: Theme.textDim }
            SetField { id: fZone; Layout.fillWidth: true; text: card.city.zone ?? ""; placeholderText: "optional, e.g. MYT" }
            Txt { text: "Latitude"; font.pixelSize: 12; color: Theme.textDim }
            SetField { id: fLat; Layout.fillWidth: true; text: String(card.city.lat ?? ""); inputMethodHints: Qt.ImhFormattedNumbersOnly }
            Txt { text: "Longitude"; font.pixelSize: 12; color: Theme.textDim }
            SetField { id: fLon; Layout.fillWidth: true; text: String(card.city.lon ?? ""); inputMethodHints: Qt.ImhFormattedNumbersOnly }
        }
        RowLayout {
            visible: card.editing
            Layout.fillWidth: true
            spacing: 8
            Txt { Layout.fillWidth: true; text: card.error || "Lat / lon: right-click a place in a map app to copy them."; font.pixelSize: 12; color: card.error ? Theme.danger : Theme.outline; wrapMode: Text.Wrap }
            SetButton { text: "Save"; accent: true; onClicked: card.trySave() }
        }
    }

    // Check the time zone exists before saving (a wrong one would quietly show UTC)
    function trySave() {
        const lat = Number(fLat.text), lon = Number(fLon.text);
        if (!fName.text.trim()) { error = "Give it a name."; return }
        if (!(Math.abs(lat) <= 90 && Math.abs(lon) <= 180) || fLat.text === "" || fLon.text === "") { error = "Latitude is −90…90, longitude −180…180."; return }
        tzCheck.command = ["test", "-f", "/etc/zoneinfo/" + fTz.text.trim()];
        tzCheck.running = true;
    }
    Process {
        id: tzCheck
        onExited: code => {
            if (code !== 0 || !fTz.text.trim() || fTz.text.includes("..")) { card.error = "Unknown time zone \"" + fTz.text.trim() + "\" (like Europe/London)."; return }
            const c = { id: card.city.id, name: fName.text.trim(), short: (fShort.text.trim() || fName.text.trim()).toUpperCase(),
                        tz: fTz.text.trim(), lat: Number(fLat.text), lon: Number(fLon.text) };
            if (fZone.text.trim()) c.zone = fZone.text.trim();
            card.error = "";
            card.editing = false;
            card.save(c);
        }
    }
}
