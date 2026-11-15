// Settings → Clocks & weather: your cities (one or two; the first is home) with the time and
// weather there now. Edit changes a city's name, time zone and place; it goes to
// ~/.config/desktop/overrides.json (the note below offers the settings.nix lines).
import QtQuick
import QtQuick.Layouts

SetPage {
    id: page
    title: "Clocks & weather"
    subtitle: "On the desktop and the lock screen. Weather: Open-Meteo, every 15 minutes."
    readonly property var cities: Settings.cities

    // Replace one city (by id) in the list and keep the rest as they are
    function saveCity(c) { Settings.set("cities", cities.map(x => x.id === c.id ? c : x)) }

    Repeater {
        model: page.cities
        SetCityCard {
            required property var modelData
            required property int index
            city: modelData
            home: index === 0
            onSave: c => page.saveCity(c)
        }
    }
    Txt {
        visible: page.cities.length === 0
        text: "No cities set: add them to desktop.cities in settings.nix."
        color: Theme.textDim
    }
    OverrideNote { key: "cities" }
    Txt {
        Layout.fillWidth: true
        Layout.leftMargin: 6
        text: "Adding or removing a city, or changing which is home, is done in settings.nix (desktop.cities)."
        wrapMode: Text.Wrap
        font.pixelSize: 12
        color: Theme.outline
    }
}
