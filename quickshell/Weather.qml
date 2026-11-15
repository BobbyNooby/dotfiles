// Clocks and weather for your cities (settings.nix desktop.cities: up to two; the first is home).
//
// Time: each city's UTC offset comes from the time-zone database (`TZ=... date +%z`), checked
// every minute, so a city like London switches between GMT and BST by itself, on time (last Sunday of March
// and October, 01:00 UTC). Nothing to update by hand: the database ships with NixOS.
// The forecast's hours are matched by their real date and time, so the 23- and 25-hour days
// when the clocks change still put "Now" on the right hour.
// Weather: Open-Meteo (free, no API key), one request per city every 15 minutes, hourly for
// today and tomorrow in the city's own time zone.
// Offline: each forecast is saved (~/.cache/quickshell/by-shell/…/weather-<city>.json) and
// shown straight away on start; it's fetched again as soon as the network is back. A saved
// forecast that no longer covers today is shown as "offline" rather than as wrong numbers.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // Your cities (Settings.qml ← settings.nix desktop.cities): the first one is "home".
    // Each: { id, name, short, zone (optional label), tz, lat, lon }
    readonly property var cityList: Settings.cities
    readonly property string homeId: cityList[0]?.id ?? ""

    property var offsets: ({})                 // city id → minutes east of UTC
    property var abbrevs: ({})                 // city id → the zone's short name now (GMT, BST, …)
    property var data: ({})                    // city id → Open-Meteo response
    property var failed: ({})                  // city id → true when fetching failed and nothing is saved
    property int tick: 0                       // bumps every minute so clocks redraw

    SystemClock {
        precision: SystemClock.Minutes
        onDateChanged: { root.tick++; zones.running = true } // re-check the offsets every minute
    }

    // ---- time zones: `TZ=<zone> date` for each city (the time-zone database knows the DST rules) ----
    Process {
        id: zones
        command: ["sh", "-c", "for z in \"$@\"; do TZ=\"$z\" date '+%z %Z'; done", "sh", ...root.cityList.map(c => c.tz)]
        stdout: StdioCollector {
            onStreamFinished: {
                const toMin = s => (s[0] === "-" ? -1 : 1) * (Number(s.slice(1, 3)) * 60 + Number(s.slice(3, 5)));
                const l = text.trim().split("\n");
                if (l.length !== root.cityList.length) return;
                const o = {}, a = {};
                root.cityList.forEach((c, i) => {
                    const [off, abbr] = l[i].split(" ");
                    o[c.id] = toMin(off);
                    a[c.id] = /^[A-Za-z]+$/.test(abbr ?? "") ? abbr : ""; // "+08" isn't a name
                });
                root.offsets = o;
                root.abbrevs = a;
            }
        }
    }
    onCityListChanged: zones.running = true
    Component.onCompleted: zones.running = true

    // A Date shifted so its UTC fields read as the city's wall clock
    function cityNow(id) { tick; return new Date(Date.now() + (offsets[id] ?? 0) * 60000) }
    function pad(n) { return (n < 10 ? "0" : "") + n }
    function hm(id) { const d = cityNow(id); return pad(d.getUTCHours()) + ":" + pad(d.getUTCMinutes()) }
    readonly property var days: ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    readonly property var months: ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    function dateText(id) { const d = cityNow(id); return days[d.getUTCDay()] + " " + d.getUTCDate() + " " + months[d.getUTCMonth()] }
    function cityById(id) { return cityList.find(c => c.id === id) }
    // The zone's name: the setting for home ("MYT"), else the database's (GMT/BST); and for the
    // other cities how far behind/ahead of home they are: "GMT −8 h"
    function zoneName(id) { return cityById(id)?.zone || abbrevs[id] || "" }
    function zoneText(id) {
        const name = zoneName(id);
        if (id === homeId || offsets[id] === undefined || offsets[homeId] === undefined) return name;
        const diff = Math.round(((offsets[id] ?? 0) - (offsets[homeId] ?? 0)) / 60);
        const rel = diff === 0 ? "same time" : (diff > 0 ? "+" : "−") + Math.abs(diff) + " h";
        return (name ? name + " " : "") + rel;
    }

    // ---- weather ----
    // WMO weather codes → icon kind and words
    function kindOf(code, isDay) {
        if (code <= 2) return isDay ? "sun" : "moon";
        if (code === 3 || code === 45 || code === 48) return "cloud";
        if (code >= 95) return "storm";
        if ((code >= 71 && code <= 77) || code === 85 || code === 86) return "snow";
        return "rain";
    }
    function condName(code, isDay) {
        if (code === 0) return isDay ? "Sunny" : "Clear";
        if (code <= 2) return "Partly cloudy";
        if (code === 3) return "Cloudy";
        if (code === 45 || code === 48) return "Fog";
        if (code >= 51 && code <= 57) return "Drizzle";
        if ((code >= 61 && code <= 67)) return "Rain";
        if ((code >= 71 && code <= 77) || code === 85 || code === 86) return "Snow";
        if (code >= 80 && code <= 82) return "Showers";
        return "Thunderstorms";
    }

    // Everything the widget shows for one city (null until the first forecast arrives)
    function city(id) {
        tick;
        const d = data[id];
        if (!d || !d.hourly) return null;
        const now = cityNow(id);
        const h = d.hourly;
        const fetched = d._fetchedAt ?? Date.now();
        const ageMin = Math.round((Date.now() - fetched) / 60000);
        // Open-Meteo's times are the city's wall-clock times ("2026-11-15T17:00"); find the one
        // for this hour by name rather than by position (switch days have 23 or 25 hours)
        const nowKey = now.getUTCFullYear() + "-" + pad(now.getUTCMonth() + 1) + "-" + pad(now.getUTCDate()) + "T" + pad(now.getUTCHours()) + ":00";
        const nowH = h.time.indexOf(nowKey);
        // The saved forecast doesn't reach this hour (offline for a long time): say so
        if (nowH < 0) {
            const f = new Date(fetched + (offsets[id] ?? 0) * 60000);
            return { offline: true, since: days[f.getUTCDay()] + " " + pad(f.getUTCHours()) + ":" + pad(f.getUTCMinutes()) };
        }
        const firstDay = (h.time[0] ?? "").slice(0, 10);
        const hours = [];
        for (let i = 0; i < Math.min(48, h.time.length); i++) {
            const code = h.weather_code[i], isDay = h.is_day[i] === 1;
            const rain = h.precipitation_probability[i] ?? 0;
            const day = h.time[i].slice(0, 10), hour = Number(h.time[i].slice(11, 13));
            const newDay = i === 0 || day !== h.time[i - 1].slice(0, 10);
            hours.push({
                i, kind: kindOf(code, isDay),
                temp: Math.round(h.temperature_2m[i]),
                tag: !newDay ? "" : day === firstDay ? "Today" : days[new Date(day + "T12:00:00Z").getUTCDay()],
                label: i === nowH ? "Now" : pad(hour) + ":00",
                rainText: rain >= 20 ? rain + "%" : "",
                now: i === nowH, past: i < nowH, tomorrow: day !== firstDay,
                hour, wet: code >= 51
            });
        }
        const cur = hours[nowH];
        const code = h.weather_code[nowH];
        let cond = condName(code, h.is_day[nowH] === 1);
        if (!cur.wet) {
            const next = hours.find(x => x.i > nowH && x.wet);
            if (next) cond += " · " + (next.kind === "storm" ? "storm" : "rain") + " from " + pad(next.hour) + ":00" + (next.tomorrow ? " tmrw" : "");
        }
        const hmOf = s => s ? s.slice(11, 16) : "";
        const nowText = pad(nowH) + ":" + pad(now.getUTCMinutes());
        const rise = hmOf(d.daily.sunrise[0]), set = hmOf(d.daily.sunset[0]);
        const sunLine = nowText >= rise && nowText < set ? "Sunset " + set
            : "Sunrise " + (nowText >= set ? hmOf(d.daily.sunrise[1]) : rise);
        return {
            temp: cur.temp, kind: cur.kind, cond, hours, nowH, sunLine,
            hi: Math.round(d.daily.temperature_2m_max[0]),
            lo: Math.round(d.daily.temperature_2m_min[0]),
            // older than 90 min = fetching isn't working (offline): show how old it is
            stale: ageMin > 90 ? (ageMin < 120 ? ageMin + " min" : Math.round(ageMin / 60) + " h") + " old" : ""
        };
    }

    Variants {
        model: root.cityList
        Scope {
            id: fetcher
            required property var modelData
            // The last forecast, saved: shown at start until a fresh one arrives
            FileView {
                id: saved
                path: Quickshell.cachePath("weather-" + fetcher.modelData.id + ".json")
                printErrors: false
                onLoaded: {
                    if (root.data[fetcher.modelData.id]) return; // a fresh one came first
                    try { fetcher.use(JSON.parse(text())) } catch (e) {}
                }
            }
            function use(j) {
                const next = Object.assign({}, root.data);
                next[modelData.id] = j;
                root.data = next;
            }
            Process {
                id: curl
                command: ["curl", "-sf", "--max-time", "20",
                    "https://api.open-meteo.com/v1/forecast?latitude=" + fetcher.modelData.lat
                    + "&longitude=" + fetcher.modelData.lon
                    + "&hourly=temperature_2m,precipitation_probability,weather_code,is_day"
                    + "&daily=sunrise,sunset,temperature_2m_max,temperature_2m_min"
                    + "&timezone=" + encodeURIComponent(fetcher.modelData.tz) + "&forecast_days=2"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        try {
                            const j = JSON.parse(text);
                            j._fetchedAt = Date.now();
                            fetcher.use(j);
                            saved.setText(JSON.stringify(j));
                        } catch (e) { // offline or Open-Meteo down: try again in a minute
                            if (!root.data[fetcher.modelData.id]) { const f = Object.assign({}, root.failed); f[fetcher.modelData.id] = true; root.failed = f }
                            retry.start();
                        }
                    }
                }
            }
            Timer { interval: 900000; running: true; repeat: true; triggeredOnStart: true; onTriggered: curl.running = true }
            Timer { id: retry; interval: 60000; onTriggered: curl.running = true }
            Connections { // network back: fetch now instead of waiting
                target: Net
                function onOnlineChanged() { if (Net.online) curl.running = true }
            }
        }
    }
}
