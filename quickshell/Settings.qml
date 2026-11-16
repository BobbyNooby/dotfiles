// Your personal settings for the shell: cities, picture folders, the repo, GPU, VPN, lock glow,
// desktop widgets and the typeface.
// They come from ~/.config/desktop/settings.json, which Home Manager writes from
// hosts/<host>/settings.nix (desktop = ...); without Nix, write that file by hand
// (settings.example.json shows every key). Missing keys fall back to the defaults below.
// (More below the imports: pragma Singleton has to stay near the top of the file, or
// Quickshell doesn't see it.)
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Changes made in the Settings window (Super+I) go to ~/.config/desktop/overrides.json, laid
// on top of settings.json (settings.json is a read-only link into /nix/store, rewritten on every
// rebuild). Each page shows when a value differs from settings.nix, with a button that copies
// the Nix line to paste in; once settings.nix has the same value, the override drops away.
// Delete overrides.json to go back to settings.nix. Both files apply the moment they change.
//
// Keys: repo, cities [{ id, name, short, zone, tz, lat, lon }], folders { wallpapers, pictures,
// screenshots, screenshotSave }, gpu, vpnPrefix, lockGlow (strong/soft/off),
// widgets { weather, system, connections, shortcuts, player, lyrics, calendar }, typeface (Theme.qml:
// outfit, grotesk, mono, condensed, serif, dotmatrix).
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    // "Documents/x" or "~/x" → /home/you/...; absolute paths stay as they are
    function path(p) { return !p ? "" : p.startsWith("/") ? p : home + "/" + p.replace(/^~\/?/, "") }

    // ---- defaults, for when there's no settings file ----
    readonly property var defaults: ({
        repo: "nixos-config",
        cities: [{ id: "home", name: "London", short: "LONDON", tz: "Europe/London", lat: 51.5072, lon: -0.1276 }],
        folders: { wallpapers: "Pictures/Wallpapers", pictures: "Pictures", screenshots: "Pictures/Screenshots", screenshotSave: "Pictures/Screenshots" },
        gpu: "",
        vpnPrefix: "surfshark",
        lockGlow: "strong",
        typeface: "outfit",
        // desktop widgets on/off
        widgets: { weather: true, system: true, connections: true, shortcuts: true, player: true, lyrics: true, calendar: true },
        // hypridle (hypr/scripts/idle-config turns these into hypridle.conf); seconds, 0 = never
        idle: { dim: 150, lock: 300, screenOff: 330, suspend: 1800, suspendPluggedIn: true, lockOnSleep: true, lid: "suspend", lidPluggedIn: "suspend" }
    })
    property var base: ({})       // settings.json (from settings.nix)
    property var overrides: ({})  // overrides.json (from the Settings window)
    // The two merged; `widgets`, `folders` and `idle` merge key by key
    readonly property var data: {
        const d = Object.assign({}, base, overrides);
        for (const k of ["widgets", "folders", "idle"])
            if (overrides[k]) d[k] = Object.assign({}, base[k] ?? {}, overrides[k]);
        return d;
    }
    function get(k) { return data[k] ?? defaults[k] }

    readonly property string repo: path(get("repo"))                  // absolute path of the config repo
    readonly property var cities: (get("cities") ?? []).filter(c => c?.id && c.tz).slice(0, 2) // the widgets show 1–2
    readonly property var folders: Object.assign({}, defaults.folders, data.folders ?? {})
    readonly property string wallpapers: path(folders.wallpapers)
    readonly property string pictures: path(folders.pictures)
    readonly property string screenshots: path(folders.screenshots)
    readonly property string gpu: get("gpu") ?? ""                    // PCI address, "" = none
    readonly property string vpnPrefix: get("vpnPrefix") ?? "surfshark"
    readonly property string lockGlow: get("lockGlow") ?? "strong"
    readonly property bool saverLook: get("saverLook") ?? true         // no blur/shadows/animations in Saver mode
    readonly property string typeface: get("typeface") ?? "outfit"    // Theme.qml's pairing
    readonly property var idle: Object.assign({}, defaults.idle, data.idle ?? {})
    // One idle setting (kept as a whole `idle` set, like widgets)
    function setIdle(name, v) {
        const i = Object.assign({}, baseValue("idle"), overrides.idle ?? {});
        i[name] = v;
        set("idle", i);
    }
    // hypridle.conf follows the idle settings: rewrite it and restart hypridle when they change
    // (from this window or a rebuild). Not on startup: hypridle's service does that itself.
    property string idleSeen: ""
    onIdleChanged: {
        const now = JSON.stringify(idle);
        if (idleSeen !== "" && now !== idleSeen) idleApply.restart();
        idleSeen = now;
    }
    Timer { // wait for the overrides file to be written
        id: idleApply
        interval: 400
        onTriggered: Quickshell.execDetached([root.home + "/.config/hypr/scripts/idle-config"])
    }
    // Is this desktop widget switched on? (weather, system, connections, shortcuts, player, lyrics, calendar)
    function show(name) { return (data.widgets ?? {})[name] ?? defaults.widgets[name] ?? true }

    // ---- overrides (the Settings window) ----
    // What settings.nix says for a key (or the default when it doesn't say)
    function baseValue(k) {
        if (k === "widgets" || k === "folders" || k === "idle") return Object.assign({}, defaults[k], base[k] ?? {});
        return base[k] ?? defaults[k];
    }
    function same(a, b) { return JSON.stringify(a) === JSON.stringify(b) }
    // Change a setting from the shell. The same value as settings.nix drops the override.
    function set(k, v) {
        const o = Object.assign({}, overrides);
        if (same(v, baseValue(k))) delete o[k]; else o[k] = v;
        writeOverrides(o);
    }
    // One desktop widget on/off (kept as a whole `widgets` set, so the Nix snippet is complete)
    function setWidget(name, on) {
        const w = Object.assign({}, baseValue("widgets"), overrides.widgets ?? {});
        w[name] = on;
        set("widgets", w);
    }
    function reset(k) { const o = Object.assign({}, overrides); delete o[k]; writeOverrides(o) }
    // Does the shell use something other than settings.nix for this key?
    function differs(k) { return k in overrides && !same(get(k), baseValue(k)) }

    // The key as Nix, ready to paste inside `desktop = { ... }` in settings.nix
    function nix(v, ind) {
        ind = ind ?? "";
        if (typeof v === "string") return JSON.stringify(v);
        if (typeof v === "number" || typeof v === "boolean") return String(v);
        if (Array.isArray(v)) {
            if (!v.length) return "[ ]";
            return "[\n" + v.map(x => ind + "  " + nix(x, ind + "  ")).join("\n") + "\n" + ind + "]";
        }
        if (v && typeof v === "object") {
            const keys = Object.keys(v);
            const flat = keys.every(k => typeof v[k] !== "object");
            if (flat && keys.length <= 8 && ind.length >= 2) // a city: one line, like settings.nix
                return "{ " + keys.map(k => k + " = " + nix(v[k]) + ";").join(" ") + " }";
            return "{\n" + keys.map(k => ind + "  " + k + " = " + nix(v[k], ind + "  ") + ";").join("\n") + "\n" + ind + "}";
        }
        return "null";
    }
    function nixSnippet(k) { return "# hosts/<host>/settings.nix, inside desktop = { ... }\n" + k + " = " + nix(get(k)) + ";\n" }
    function copyNix(k) { Quickshell.execDetached(["wl-copy", "--", nixSnippet(k)]) }

    function writeOverrides(o) {
        overrides = o; // apply at once; the file watcher confirms
        ovFile.setText(JSON.stringify(o, null, 2) + "\n");
    }

    FileView {
        id: file
        path: root.home + "/.config/desktop/settings.json"
        watchChanges: true
        blockLoading: true // read it before anything uses the settings (no flash of the defaults)
        onFileChanged: reload()
        printErrors: false
        // A file caught mid-write reads empty or cut off: keep the last good settings and look
        // again shortly; only complain if it's still broken after a few tries.
        onLoaded: root.parse()
    }
    function parse() {
        const t = file.text();
        if (!t) return; // not there (yet): the defaults stay
        try { base = JSON.parse(t); retry.tries = 0 }
        catch (e) {
            if (retry.tries++ < 5) retry.restart();
            else console.warn("~/.config/desktop/settings.json isn't valid JSON, keeping the last good settings:", e);
        }
    }
    Timer { id: retry; property int tries: 0; interval: 300; onTriggered: file.reload() }

    // Changes from the Settings window. May not exist yet: written on the first change.
    FileView {
        id: ovFile
        path: root.home + "/.config/desktop/overrides.json"
        watchChanges: true
        blockLoading: true
        onFileChanged: reload()
        printErrors: false
        onLoaded: root.parseOverrides()
    }
    function parseOverrides() {
        const t = ovFile.text();
        if (!t) return;
        try { const o = JSON.parse(t); if (o && typeof o === "object") overrides = o }
        catch (e) { console.warn("~/.config/desktop/overrides.json isn't valid JSON, ignoring it:", e) }
    }
    Component.onCompleted: { parse(); parseOverrides() } // blockLoading has the text ready now; `loaded` only fires later
}
