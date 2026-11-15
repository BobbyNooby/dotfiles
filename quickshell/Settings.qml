// Your personal settings for the shell: cities, picture folders, the repo, GPU, VPN, lock glow.
// They come from ~/.config/desktop/settings.json, which Home Manager writes from
// hosts/<host>/settings.nix (desktop = ...); without Nix, write that file by hand
// (settings.example.json shows every key). Missing keys fall back to the defaults below.
// Changes apply the moment the file changes.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

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
        // desktop widgets on/off
        widgets: { weather: true, system: true, connections: true, shortcuts: true, player: true, lyrics: true }
    })
    property var data: ({})
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
    // Is this desktop widget switched on? (weather, system, connections, shortcuts, player, lyrics)
    function show(name) { return (data.widgets ?? {})[name] ?? defaults.widgets[name] ?? true }

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
        try { data = JSON.parse(t); retry.tries = 0 }
        catch (e) {
            if (retry.tries++ < 5) retry.restart();
            else console.warn("~/.config/desktop/settings.json isn't valid JSON, keeping the last good settings:", e);
        }
    }
    Component.onCompleted: parse() // blockLoading has the text ready now; `loaded` only fires later
    Timer { id: retry; property int tries: 0; interval: 300; onTriggered: file.reload() }
}
