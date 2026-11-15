// The launcher: Super + Space (or `qs ipc call launcher toggle`). One search box, Spotlight /
// Raycast style; results are ranked as you type and grouped under small labels.
//   anything      apps, open windows, actions and switches (Wi-Fi, VPN, power...), settings
//                 pages; a sum shows its answer; "Search Google" is always last
//   > cmd         run a command in WezTerm (Ctrl+Enter: in the background, no window)
//   f name, ~/…, /…   find files (scripts/launcher-files), Enter opens, Ctrl+Enter opens the folder
//   : name        emoji, Enter copies          cb text   clipboard history (cliphist)
//   g / yt / gh / nix / w  text   search Google, YouTube, GitHub, NixOS packages, Wikipedia
// Keys: ↑ ↓ choose, Tab / Shift+Tab next / previous group, Enter go, Ctrl+Enter the other action
// (shown in the footer), Esc close. Power actions ask for a second Enter.
// What you pick is remembered (frecency, ~/.local/state/quickshell/.../launcher.json) and
// floats up next time. rofi stays installed as the fallback (Super+Shift+Space).
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Bluetooth
import Quickshell.Services.UPower
import "LauncherLib.js" as Lib

PanelWindow {
    id: win
    property bool open: false
    property string query: ""
    property var results: []      // what the list shows: { header, label } rows and items (see below)
    property int sel: 0            // index of the chosen row in `results`
    property string confirmKey: "" // a power action waiting for its second Enter
    readonly property var current: results[sel] ?? null

    // An item: { key, section, title, sub, icon | appIcon | glyph, badge (text or function for
    // live state), fields (what the search matches), run(), alt() + altLabel, confirm, keep }

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-launcher"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    color: "transparent"
    visible: open || card.opacity > 0

    onOpenChanged: {
        if (open) {
            field.text = "";
            query = "";
            windowsProc.running = true;
            toolsProc.running = true;
            clipLoaded = false;
            Net.refresh();
            rebuild();
            field.forceActiveFocus();
        } else confirmKey = "";
    }

    IpcHandler {
        target: "launcher"
        function toggle(): void { win.open = !win.open }
        function open(): void { win.open = true }
        function close(): void { win.open = false }
        // open with text already typed, e.g. `qs ipc call launcher search ":heart"`
        function search(text: string): void { win.open = true; field.text = text }
        // run the highlighted result (alt = what Ctrl+Enter does), e.g. after search: for scripts/tests
        function run(alt: bool): void { win.activate(alt) }
    }

    // ---------------- helpers ----------------
    readonly property string home: Quickshell.env("HOME")
    function sh(cmd) { Quickshell.execDetached(["sh", "-c", cmd]) }
    function openUrl(u) { Quickshell.execDetached(["xdg-open", u]) }
    function copy(text) { Quickshell.execDetached(["wl-copy", "--", text]) }
    function tilde(p) { return p.startsWith(home) ? "~" + p.slice(home.length) : p }
    function qsCall(args) { sh("qs ipc call " + args) }
    // Settings window page; Quick settings if the Settings window isn't there
    function settingsPage(page) {
        sh('out=$(qs ipc call settings open ' + page + ' 2>&1); case "$out" in *"not found"*) qs ipc call controls toggle ;; esac');
    }

    // Which optional programs are installed (checked each time it opens: cheap, and picks up new ones)
    property bool hasQalc: false
    property bool hasPicker: false
    property bool hasCliphist: false
    Process {
        id: toolsProc
        command: ["sh", "-c", "for c in qalc hyprpicker cliphist; do command -v $c >/dev/null && echo $c; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                win.hasQalc = text.includes("qalc");
                win.hasPicker = text.includes("hyprpicker");
                win.hasCliphist = text.includes("cliphist");
            }
        }
    }

    // ---------------- frecency ----------------
    property var freq: ({}) // key → { n: times picked, t: last time }
    FileView {
        id: freqFile
        path: Quickshell.statePath("launcher.json")
        printErrors: false
        blockLoading: true
    }
    Component.onCompleted: { try { freq = JSON.parse(freqFile.text() || "{}") } catch (e) { freq = {} } }
    function remember(key) {
        if (!key) return;
        const f = Object.assign({}, freq);
        const r = f[key] ?? { n: 0, t: 0 };
        f[key] = { n: r.n + 1, t: Date.now() };
        // keep the file small: drop the least used when it grows past 400 entries
        const keys = Object.keys(f);
        if (keys.length > 400)
            keys.sort((a, b) => Lib.frecency(f[a], Date.now()) - Lib.frecency(f[b], Date.now()))
                .slice(0, keys.length - 400).forEach(k => delete f[k]);
        freq = f;
        freqFile.setText(JSON.stringify(f));
    }

    // ---------------- sources ----------------
    // Shortcut entries made for rofi (rofi script menus): the launcher has its own (live) versions
    readonly property var hiddenApps: ["wifi-menu", "bluetooth-menu", "settings-menu", "setwall", "lock-screen", "power-menu"]
    // Apps (and their extra actions, like "New private window") from the .desktop files
    readonly property var apps: {
        const out = [], seen = {};
        for (const e of DesktopEntries.applications.values) {
            if (e.noDisplay || seen[e.id] || hiddenApps.includes(e.id)) continue;
            seen[e.id] = true;
            const cmd = e.command;
            out.push({
                key: "app:" + e.id, section: "Apps", title: e.name,
                sub: e.genericName || e.comment || "", appIcon: e.icon || e.id,
                fields: [[e.name, 1, true], [e.genericName, 0.8, true], [(e.keywords ?? []).join(" "), 0.7],
                         [e.id, 0.6], [e.comment, 0.45]],
                run: () => e.execute(),
                altLabel: "open on the NVIDIA card",
                alt: () => Quickshell.execDetached(["nvidia-offload", ...cmd])
            });
            for (const a of e.actions ?? [])
                out.push({
                    key: "app:" + e.id + ":" + a.id, section: "Apps", title: e.name + ": " + a.name,
                    sub: e.genericName || "", appIcon: a.icon || e.icon || e.id, subAction: true,
                    fields: [[a.name, 0.85, true], [e.name + " " + a.name, 0.8, true]],
                    run: () => a.execute()
                });
        }
        return out;
    }

    // Open windows (asked from Hyprland each time it opens)
    property var windows: []
    Process {
        id: windowsProc
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    win.windows = JSON.parse(text)
                        .filter(c => c.mapped && (c.workspace?.id > 0 || c.workspace?.name === "special:minimized"))
                        .sort((a, b) => a.focusHistoryID - b.focusHistoryID)
                        .map(c => win.windowItem(c));
                } catch (e) { win.windows = [] }
                win.rebuild();
            }
        }
    }
    function windowItem(c) {
        const hidden = c.workspace.name === "special:minimized";
        const entry = DesktopEntries.heuristicLookup(c.class);
        const restore = () => Quickshell.execDetached([home + "/.config/hypr/scripts/minimize", "restore", c.address]);
        return {
            key: "win:" + c.address, section: "Windows", title: c.title || c.class,
            sub: (entry?.name ?? c.class) + " · " + (hidden ? "minimized" : "workspace " + c.workspace.id),
            appIcon: entry?.icon ?? c.class,
            fields: [[c.title, 0.9, true], [c.class, 0.9, true], [entry?.name ?? "", 0.9, true]],
            noFreq: true,
            run: hidden ? restore : () => Hyprland.dispatch("hl.dsp.focus({ window = \"address:" + c.address + "\" })"),
            altLabel: "bring it to this workspace", alt: restore
        };
    }

    // Actions and switches. `badge` functions are read by the row's binding, so they stay live.
    readonly property var adapter: Bluetooth.defaultAdapter
    function profileName(p) { return p === PowerProfile.PowerSaver ? "Saver" : p === PowerProfile.Performance ? "Performance" : "Balanced" }
    readonly property string shotCmd: // same as the Print keys in hyprland.lua; waits for this to fade first
        'sleep 0.4; d=$(jq -r ".folders.screenshotSave // \\"Pictures/Screenshots\\"" ~/.config/desktop/settings.json 2>/dev/null); '
        + 'case "$d" in /*) ;; *) d="$HOME/${d#\\~/}" ;; esac; mkdir -p "$d" && f="$d/screenshot-$(date +%F_%H-%M-%S).png" && '
    readonly property string shotDone: ' "$f" && wl-copy < "$f" && notify-send -a Screenshot -i "$f" Screenshot "Saved and copied: $f"'

    readonly property var actions: {
        const a = [
            { key: "act:wifi", title: "Wi-Fi", icon: "wifi", words: "wireless network internet wlan",
              sub: Net.wifiOn ? "Turn off · " + Net.label : "Turn on",
              badge: () => Net.wifiOn ? "On" : "Off", run: () => Net.setWifi(!Net.wifiOn),
              altLabel: "Wi-Fi settings", alt: () => settingsPage("wifi") },
            { key: "act:bt", title: "Bluetooth", icon: "bluetooth", words: "bt wireless headphones",
              sub: !adapter ? "No adapter" : adapter.enabled ? "Turn off" : "Turn on",
              badge: () => !win.adapter ? "" : win.adapter.enabled ? "On" : "Off",
              run: () => { if (win.adapter) win.adapter.enabled = !win.adapter.enabled },
              altLabel: "Bluetooth settings", alt: () => settingsPage("bluetooth") },
            { key: "act:dnd", title: "Do not disturb", icon: "bell", words: "dnd notifications quiet silence focus",
              sub: Notifs.dnd ? "Turn off: popups come back" : "Turn on: no notification popups",
              badge: () => Notifs.dnd ? "On" : "Off", run: () => Notifs.dnd = !Notifs.dnd },
            { key: "act:tailscale", title: "Tailscale", icon: "tailscale", words: "vpn tailnet mesh",
              sub: Vpn.tsStatus, badge: () => Vpn.tsOn ? "On" : Vpn.tsState === "NeedsLogin" ? "Sign in" : "Off",
              run: () => Vpn.toggleTailscale() },
            { key: "act:power-saver", title: "Power mode: Saver", icon: "saver", words: "battery profile power saver eco",
              sub: "Longer battery, slower", badge: () => PowerProfiles.profile === PowerProfile.PowerSaver ? "Current" : "",
              run: () => PowerProfiles.profile = PowerProfile.PowerSaver },
            { key: "act:power-balanced", title: "Power mode: Balanced", icon: "balanced", words: "battery profile power",
              sub: "The default", badge: () => PowerProfiles.profile === PowerProfile.Balanced ? "Current" : "",
              run: () => PowerProfiles.profile = PowerProfile.Balanced },
            { key: "act:lock", title: "Lock screen", icon: "lock", words: "hyprlock away", sub: "hyprlock", run: () => sh("hyprlock") },
            { key: "act:sleep", title: "Sleep", icon: "moon", words: "suspend", sub: "Suspend (locks first)",
              confirm: "Press Enter again to sleep", run: () => sh("systemctl suspend") },
            { key: "act:reboot", title: "Restart", icon: "restart", words: "reboot", sub: "Restart the laptop",
              confirm: "Press Enter again to restart", run: () => sh("systemctl reboot") },
            { key: "act:poweroff", title: "Shut down", icon: "power", words: "power off shutdown halt",
              sub: "Turn the laptop off", confirm: "Press Enter again to shut down", run: () => sh("systemctl poweroff") },
            { key: "act:logout", title: "Log out", icon: "logout", words: "sign out exit hyprland session",
              sub: "Close everything and go back to the login screen", confirm: "Press Enter again to log out",
              run: () => sh("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'") },
            { key: "act:wallpaper", title: "Wallpaper switcher", icon: "image", words: "background theme colours setwall",
              sub: "Super + W", run: () => qsCall("wallpicker open") },
            { key: "act:cheatsheet", title: "Cheat sheet", icon: "keyboard", words: "shortcuts keys keybinds aliases help",
              sub: "Super + /", run: () => qsCall("cheatsheet toggle") },
            { key: "act:notifs", title: "Notifications", icon: "bell", words: "notification center history",
              sub: "Super + N", run: () => Notifs.toggleCenter() },
            { key: "act:clear-notifs", title: "Clear notifications", icon: "close", words: "dismiss all notifications",
              sub: Notifs.count + " in the list", run: () => Notifs.clear() },
            { key: "act:hermes", title: "Hermes panel", icon: "sparkle", words: "ai chat claude assistant agent ask",
              sub: "Super + A", run: () => qsCall("hermes toggle") },
            { key: "act:controls", title: "Quick settings", icon: "sliders", words: "control center volume brightness",
              sub: "Super + ,", run: () => qsCall("controls toggle") },
            { key: "act:shot-region", title: "Screenshot: region", icon: "camera", words: "screenshot capture grim print snip",
              sub: "Saved and copied", run: () => sh(shotCmd + 'grim -g "$(slurp)"' + shotDone) },
            { key: "act:shot-screen", title: "Screenshot: whole screen", icon: "camera", words: "screenshot capture grim print",
              sub: "Saved and copied", run: () => sh(shotCmd + 'grim' + shotDone) },
            { key: "act:clipboard", title: "Clipboard history", icon: "clipboard", words: "cliphist paste copied",
              sub: "Type cb to search it", keep: true, run: () => field.text = "cb " },
            { key: "act:emoji", title: "Emoji", icon: "smile", words: "emoji smiley symbols", sub: "Type : to search them",
              keep: true, run: () => field.text = ":" },
            { key: "act:files", title: "Find files", icon: "search", words: "search files folders fd",
              sub: "Type f and a name, or a path starting with ~ or /", keep: true, run: () => field.text = "f " },
            { key: "act:trash", title: "Empty trash", icon: "trash", words: "bin delete rubbish",
              sub: "Deletes everything in ~/.local/share/Trash", confirm: "Press Enter again: this can't be undone",
              run: () => sh('rm -rf "$HOME/.local/share/Trash/files" "$HOME/.local/share/Trash/info"; notify-send -a Trash "Trash emptied"') },
            { key: "act:restart-shell", title: "Restart the shell", icon: "sync", words: "quickshell bar reload",
              sub: "Super + Shift + B", run: () => sh("sleep 0.3; for i in 1 2 3 4 5; do qs kill >/dev/null 2>&1 || break; done; qs -n -d") }
        ];
        if (PowerProfiles.hasPerformanceProfile)
            a.splice(5, 0, { key: "act:power-perf", title: "Power mode: Performance", icon: "boltLine", words: "battery profile power fast",
              sub: "Fastest, uses more battery", badge: () => PowerProfiles.profile === PowerProfile.Performance ? "Current" : "",
              run: () => PowerProfiles.profile = PowerProfile.Performance });
        if (hasPicker)
            a.push({ key: "act:picker", title: "Colour picker", icon: "droplet", words: "color pick eyedropper hex hyprpicker",
              sub: "Click anywhere: the colour is copied", run: () => sh("sleep 0.4; hyprpicker -a") });
        // one row per VPN location: connect, or disconnect the one that's on
        for (const v of Vpn.vpns)
            a.push({ key: "vpn:" + v.name, title: "VPN: " + v.label, icon: "shield", words: "vpn surfshark wireguard " + v.name,
              sub: v.active ? "Disconnect" : Vpn.vpnOn ? "Switch to this location" : "Connect",
              badge: () => (Vpn.activeVpn?.name === v.name) ? "Connected" : "",
              run: () => {
                  if (Vpn.activeVpn?.name === v.name) Vpn.toggleVpn();
                  else { Vpn.choose(v.name); if (!Vpn.vpnOn) Vpn.toggleVpn() }
              } });
        for (const x of a) {
            x.section = "Actions";
            x.fields = [[x.title, 1, true], [x.words ?? "", 0.75]];
        }
        return a;
    }

    // Pages of the Settings window
    readonly property var settingsPages: [
        ["", "Settings", "gear", "preferences control panel system"],
        ["wifi", "Wi-Fi & VPN", "wifi", "network wireless vpn tailscale"],
        ["bluetooth", "Bluetooth", "bluetooth", "devices pair headphones"],
        ["sound", "Sound", "volume", "audio volume speaker microphone output input"],
        ["notifications", "Notifications", "bell", "dnd mute apps"],
        ["keyboard", "Keyboard & language", "keyboard", "input layout fcitx ime language"],
        ["appearance", "Appearance", "image", "wallpaper theme colours fonts look"],
        ["clocks", "Clocks & weather", "clock", "time zone cities forecast"],
        ["power", "Power", "battery", "battery profile sleep idle"],
        ["about", "About", "info", "system version hardware"]
    ].map(([page, label, icon, words]) => ({
        key: "set:" + page, section: "Settings", title: page ? "Settings: " + label : label, icon: icon,
        sub: page ? "Open the Settings window" : "A page per topic",
        fields: [[label, 1, true], ["settings " + label, 0.9, true], [words, 0.7]],
        run: () => settingsPage(page)
    }))

    // ---- calculator: the instant JS answer, replaced by qalc's (units, currencies) when it's in ----
    property string qalcFor: ""
    property string qalcAnswer: ""
    // One run at a time: typing on while one runs starts the next when it ends (onExited), and
    // an answer only counts for the sum it was asked (ranFor)
    Timer {
        id: qalcDelay
        interval: 120
        onTriggered: if (!qalcProc.running) {
            qalcProc.ranFor = win.qalcFor;
            qalcProc.command = ["qalc", "-t", "--", win.qalcFor];
            qalcProc.running = true;
        }
    }
    Process {
        id: qalcProc
        property string ranFor
        stdout: StdioCollector {
            onStreamFinished: {
                const out = text.trim().split("\n").pop() ?? "";
                if (qalcProc.ranFor === win.qalcFor && win.qalcFor === win.query.trim() && out && !/error|warning/i.test(out)) { win.qalcAnswer = out; win.rebuild() }
            }
        }
        onExited: if (ranFor !== win.qalcFor && win.qalcFor) qalcDelay.restart()
    }

    // ---- files (debounced: one fd per pause in typing) ----
    property string filesFor: ""
    property var files: []
    Timer { // one search at a time, like qalc above
        id: filesDelay
        interval: 160
        onTriggered: if (!filesProc.running) {
            filesProc.ranFor = win.filesFor;
            filesProc.command = [Quickshell.shellDir + "/scripts/launcher-files", win.filesFor];
            filesProc.running = true;
        }
    }
    Process {
        id: filesProc
        property string ranFor
        onExited: if (ranFor !== win.filesFor && win.filesFor) filesDelay.restart()
        stdout: StdioCollector {
            onStreamFinished: {
                const q = win.filesFor;
                if (filesProc.ranFor !== q) return; // you typed on meanwhile: the next search is coming
                const want = q.replace(/^.*\//, "").toLowerCase();
                win.files = text.split("\n").filter(l => l).map(l => {
                    const [kind, path] = l.split("\t");
                    const name = path.replace(/^.*\//, "");
                    return { kind, path, name, rank: (name.toLowerCase().startsWith(want) ? 0 : 1) * 1000 + path.length };
                }).sort((a, b) => a.rank - b.rank).slice(0, 14);
                win.rebuild();
            }
        }
    }

    // ---- clipboard history (read once per opening, when you type "cb") ----
    property bool clipLoaded: false
    property var clips: []
    Process {
        id: clipProc
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                win.clips = text.split("\n").filter(l => l).map(l => ({ line: l, text: l.replace(/^\d+\t/, "") }));
                win.rebuild();
            }
        }
    }

    // ---- emoji (rofi-emoji's list, found through the rofi wrapper; read once) ----
    property var emojis: []
    property bool emojiLoading: false
    Process {
        id: emojiProc
        command: ["sh", "-c", 'for f in "${XDG_DATA_HOME:-$HOME/.local/share}/rofi-emoji/all_emojis.txt" '
            + '$(grep -ao "/nix/store/[a-z0-9]*-rofi-emoji-[^/:\\"]*" "$(readlink -f "$(command -v rofi)")" 2>/dev/null | sort -u | sed "s|$|/share/rofi-emoji/all_emojis.txt|"); '
            + 'do [ -f "$f" ] && exec cat "$f"; done']
        stdout: StdioCollector {
            onStreamFinished: {
                // emoji <tab> group <tab> subgroup <tab> name <tab> keywords ("a | b | c")
                // Most come twice (with and without the emoji presentation selector, U+FE0F):
                // keep the first of each name, with whichever copy has the keywords
                const byName = new Map();
                for (const l of text.split("\n")) {
                    const f = l.split("\t");
                    if (!f[0] || !f[3]) continue;
                    const words = (f[4] ?? "").replace(/ \| /g, " ");
                    const had = byName.get(f[3]);
                    if (had) { if (!had.words) had.words = words; continue }
                    byName.set(f[3], { e: f[0], name: f[3], words, group: f[1] ?? "" });
                }
                win.emojis = [...byName.values()];
                win.rebuild();
            }
        }
    }

    // ---- web ----
    readonly property var engines: ({
        g:   { name: "Google", url: "https://www.google.com/search?q=" },
        yt:  { name: "YouTube", url: "https://www.youtube.com/results?search_query=" },
        gh:  { name: "GitHub", url: "https://github.com/search?type=repositories&q=" },
        nix: { name: "NixOS packages", url: "https://search.nixos.org/packages?channel=unstable&query=" },
        w:   { name: "Wikipedia", url: "https://en.wikipedia.org/wiki/Special:Search?search=" }
    })
    function webItem(engine, text) {
        const e = engines[engine];
        return { key: "", section: "Web", title: "Search " + e.name + " for “" + text + "”", icon: "web",
                 sub: e.url.replace(/^https:\/\/(www\.)?/, "").replace(/[/?].*$/, ""), run: () => openUrl(e.url + encodeURIComponent(text)) };
    }

    // ---------------- ranking ----------------
    // Turn the typed text into the rows the list shows. Cheap sources are searched right here;
    // files and qalc start their (debounced) process and call rebuild() again when they answer.
    function rebuild() {
        const raw = query;
        const q = raw.trim();
        const ql = q.toLowerCase();
        const now = Date.now();
        const groups = []; // [{ label, items, best }]
        const add = (label, items, best) => { if (items.length) groups.push({ label, items, best: best ?? 0 }) };
        const rank = (items, limit) => items
            .map(it => ({ it, s: Lib.score(ql, it.fields) }))
            .filter(x => x.s > 0)
            .map(x => ({ it: x.it, s: x.s + (x.it.noFreq ? 0 : Lib.frecency(freq[x.it.key], now)) - (x.it.subAction ? 8 : 0) }))
            .sort((a, b) => b.s - a.s)
            .slice(0, limit);
        let fixedOrder = false;

        if (q === "") {
            // nothing typed: what you use most, then your windows
            const all = [...apps.filter(a => !a.subAction), ...actions, ...settingsPages];
            const recent = all.filter(it => freq[it.key])
                .sort((a, b) => Lib.frecency(freq[b.key], now) - Lib.frecency(freq[a.key], now)).slice(0, 7);
            add("Recent", recent);
            // until there's enough history, a few everyday switches fill the gap
            const starters = ["act:wifi", "act:bt", "act:dnd", "act:wallpaper", "act:files", "act:cheatsheet"];
            add("Suggestions", actions.filter(x => starters.includes(x.key) && !recent.includes(x)).slice(0, Math.max(0, 7 - recent.length)));
            add("Windows", windows.slice(0, 6));
            fixedOrder = true;
        } else if (raw.startsWith(">")) {
            const cmd = raw.slice(1).trim();
            if (cmd) add("Run", [{ key: "", title: cmd, mono: true, icon: "term", sub: "Run in WezTerm", verb: "run",
                run: () => Quickshell.execDetached(["wezterm", "start", "--", "zsh", "-ic", cmd + "; exec zsh"]),
                altLabel: "run in the background", alt: () => Quickshell.execDetached(["zsh", "-ic", cmd]) }]);
            else add("Run", [{ key: "", title: "Type a command", icon: "term", sub: "Enter runs it in WezTerm", keep: true, run: () => {} }]);
            fixedOrder = true;
        } else if (raw.startsWith(":")) {
            const e = raw.slice(1).trim().toLowerCase();
            if (!emojis.length && !emojiLoading) { emojiLoading = true; emojiProc.running = true }
            const list = !e ? emojis.slice(0, 40)
                : emojis.map(x => ({ x, s: Math.max(Lib.fuzzy(e, x.name, false), Lib.fuzzy(e, x.words, false) * 0.8) }))
                    .filter(y => y.s > 0).sort((a, b) => b.s - a.s).slice(0, 40).map(y => y.x);
            add("Emoji", list.map(x => ({ key: "", glyph: x.e, title: x.name, sub: x.group,
                verb: "copy", run: () => copy(x.e), altLabel: "copy its name", alt: () => copy(x.name) })));
            if (!emojis.length) add("Emoji", [{ title: "Loading emoji…", icon: "smile", keep: true, run: () => {} }]);
            fixedOrder = true;
        } else if (/^cb(\s|$)/i.test(raw)) {
            const t = raw.slice(2).trim().toLowerCase();
            if (!clipLoaded && hasCliphist) { clipLoaded = true; clipProc.running = true }
            const list = clips.filter(c => !t || c.text.toLowerCase().includes(t)).slice(0, 40);
            add("Clipboard", list.map(c => ({ key: "", icon: "clipboard", title: c.text.replace(/\s+/g, " ").slice(0, 200),
                verb: "copy", run: () => Quickshell.execDetached(["sh", "-c", 'printf "%s" "$1" | cliphist decode | wl-copy', "sh", c.line]),
                altLabel: "delete it from the history",
                alt: () => { Quickshell.execDetached(["sh", "-c", 'printf "%s" "$1" | cliphist delete', "sh", c.line]);
                             win.clips = win.clips.filter(x => x !== c); win.rebuild() }, keepAlt: true })));
            if (!hasCliphist) add("Clipboard", [{ title: "cliphist isn't installed", icon: "clipboard", keep: true, run: () => {} }]);
            else if (!list.length) add("Clipboard", [{ title: clips.length ? "Nothing matches" : "The history is empty", icon: "clipboard", keep: true, run: () => {} }]);
            fixedOrder = true;
        } else if (/^f\s/i.test(raw) || q.startsWith("/") || q.startsWith("~")) {
            const fq = /^f\s/i.test(raw) ? raw.slice(2).trim() : q;
            if (fq !== filesFor) { filesFor = fq; files = []; if (fq) filesDelay.restart() }
            add("Files", files.map(f => ({ key: "", title: f.name, sub: tilde(f.path),
                icon: f.kind === "d" ? "folder" : "file",
                run: () => openUrl(f.path),
                altLabel: "open the folder it's in", alt: () => openUrl(f.path.replace(/\/[^/]*$/, "") || "/") })));
            if (!files.length) add("Files", [{ title: fq ? (filesProc.running || filesDelay.running ? "Searching…" : "Nothing found") : "Type a name or a path",
                icon: "search", sub: "Hidden folders and caches are skipped", keep: true, run: () => {} }]);
            fixedOrder = true;
        } else {
            const pre = /^(g|yt|gh|nix|w)\s+(.+)$/i.exec(raw);
            if (pre) { add("Web", [webItem(pre[1].toLowerCase(), pre[2].trim())]); fixedOrder = true }
            else {
                // the answer to a sum goes first
                const mathy = Lib.looksMathy(q);
                if (mathy && hasQalc && qalcFor !== q) { qalcFor = q; qalcAnswer = ""; qalcDelay.restart() }
                const js = Lib.calc(q);
                const answer = (mathy && hasQalc && qalcAnswer && qalcFor === q) ? qalcAnswer : js !== null ? Lib.formatNumber(js) : "";
                if (answer && answer !== q)
                    add("Calculator", [{ key: "", title: answer, big: true, icon: "calc", sub: q + " =",
                        verb: "copy", run: () => copy(answer), altLabel: "copy “" + q + " = " + answer + "”", alt: () => copy(q + " = " + answer) }], 1000);
                if (Lib.looksLikeUrl(q))
                    add("Open", [{ key: "", title: q, icon: "link", sub: "Open in the browser",
                        run: () => openUrl(/^https?:/i.test(q) ? q : "https://" + q) }], 900);
                for (const [label, src, limit] of [["Apps", apps, 7], ["Windows", windows, 5], ["Actions", actions, 6], ["Settings", settingsPages, 4]]) {
                    const r = rank(src, limit);
                    if (r.length) add(label, r.map(x => x.it), r[0].s);
                }
                add("Web", [webItem("g", q)], -1);
            }
        }
        if (!fixedOrder) groups.sort((a, b) => b.best - a.best);

        const rows = [];
        for (const g of groups) { rows.push({ header: true, label: g.label }); rows.push(...g.items) }
        // keep the same item chosen when async results arrive; otherwise the first item
        const was = current && !current.header ? current : null;
        results = rows;
        let i = was ? rows.findIndex(r => r === was || (r.key && r.key === was.key && r.title === was.title)) : -1;
        sel = i >= 0 && !queryChanged ? i : rows.findIndex(r => !r.header);
        queryChanged = false;
        list.positionViewAtIndex(Math.max(0, sel - 1), ListView.Contain);
    }
    property bool queryChanged: false

    // ---------------- keys ----------------
    function move(d) {
        confirmKey = "";
        let i = sel;
        for (let n = 0; n < results.length; n++) {
            i = (i + d + results.length) % results.length;
            if (!results[i].header) break;
        }
        sel = i;
        list.positionViewAtIndex(results[sel - 1]?.header ? sel - 1 : sel, ListView.Contain);
    }
    // Tab: first item of the next group (Shift+Tab: of the previous one)
    function jumpGroup(d) {
        const heads = results.map((r, i) => r.header ? i : -1).filter(i => i >= 0);
        if (heads.length < 2) return move(d);
        const cur = heads.filter(h => h < sel).pop() ?? heads[0];
        const k = heads.indexOf(cur);
        sel = heads[(k + d + heads.length) % heads.length] + 1;
        confirmKey = "";
        list.positionViewAtIndex(sel - 1, ListView.Contain);
    }
    function activate(useAlt) {
        const it = current;
        if (!it || it.header) return;
        const fn = useAlt ? it.alt : it.run;
        if (!fn) return;
        if (!useAlt && it.confirm && confirmKey !== it.key) { confirmKey = it.key; return }
        if (!(it.noFreq) && !useAlt) remember(it.key);
        if (it.keep || (useAlt && it.keepAlt)) { fn(); return }
        open = false;
        fn();
    }

    // ---------------- the window ----------------
    Rectangle { // dim the screen a little (light enough that only the card gets blurred); click to close
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.18)
        opacity: card.opacity
        MouseArea { anchors.fill: parent; onClicked: win.open = false }
    }

    RectangularShadow {
        anchors.fill: card
        radius: card.radius
        offset.y: 18
        blur: 50
        color: Qt.rgba(0, 0, 0, 0.45 * card.opacity)
    }
    Rectangle {
        id: card
        x: Math.round((parent.width - width) / 2)
        y: Math.round(parent.height * 0.16)
        width: Math.min(parent.width - 32, 700)
        height: col.implicitHeight
        radius: Theme.r(26)
        color: Theme.alpha(Theme.bgLow, 0.93)
        border.color: Theme.alpha(Theme.border, 0.6)
        border.width: 1
        opacity: win.open ? 1 : 0
        scale: win.open ? 1 : 0.97
        Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        MouseArea { anchors.fill: parent } // clicks inside don't close it

        ColumnLayout {
            id: col
            width: parent.width
            spacing: 0

            // ---- search box ----
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 62
                Layout.leftMargin: 22
                Layout.rightMargin: 18
                spacing: 14
                Icon { name: "search"; size: 22; color: Theme.textDim }
                TextInput {
                    id: field
                    Layout.fillWidth: true
                    color: Theme.text
                    font.family: Theme.font
                    font.pixelSize: 20
                    selectionColor: Theme.accentSoft
                    selectedTextColor: Theme.textOnSoft
                    clip: true
                    focus: true
                    onTextChanged: { win.query = text; win.confirmKey = ""; win.queryChanged = true; win.rebuild() }
                    Txt { // placeholder
                        anchors.verticalCenter: parent.verticalCenter
                        visible: field.text === ""
                        text: "Search apps, windows, actions, files…"
                        font.pixelSize: 20
                        color: Theme.alpha(Theme.textDim, 0.6)
                    }
                    Keys.onPressed: e => {
                        const ctrl = e.modifiers & Qt.ControlModifier;
                        if (e.key === Qt.Key_Escape) win.open = false;
                        else if (e.key === Qt.Key_Down || (ctrl && (e.key === Qt.Key_J || e.key === Qt.Key_N))) win.move(1);
                        else if (e.key === Qt.Key_Up || (ctrl && (e.key === Qt.Key_K || e.key === Qt.Key_P))) win.move(-1);
                        else if (e.key === Qt.Key_Tab) win.jumpGroup(1);
                        else if (e.key === Qt.Key_Backtab) win.jumpGroup(-1);
                        else if (e.key === Qt.Key_PageDown) { for (let i = 0; i < 5; i++) win.move(1) }
                        else if (e.key === Qt.Key_PageUp) { for (let i = 0; i < 5; i++) win.move(-1) }
                        else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) win.activate(!!ctrl);
                        else return;
                        e.accepted = true;
                    }
                }
                Txt { // which mode the prefix picked
                    readonly property string mode: field.text.startsWith(">") ? "Run" : field.text.startsWith(":") ? "Emoji"
                        : /^cb(\s|$)/i.test(field.text) ? "Clipboard" : /^f\s/i.test(field.text) || /^[~/]/.test(field.text) ? "Files"
                        : /^(g|yt|gh|nix|w)\s/i.test(field.text) ? "Web" : ""
                    visible: mode !== ""
                    text: mode
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    color: Theme.textOnSoft
                    leftPadding: 10; rightPadding: 10; topPadding: 4; bottomPadding: 4
                    Rectangle { anchors.fill: parent; z: -1; radius: height / 2; color: Theme.accentSoft }
                }
            }
            Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.alpha(Theme.textDim, 0.12) }

            // ---- results ----
            ListView {
                id: list
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(contentHeight + 16, 470)
                Layout.leftMargin: 8
                Layout.rightMargin: 8
                topMargin: 4
                bottomMargin: 8
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: win.results
                reuseItems: false
                delegate: LauncherRow {
                    width: list.width
                    selected: index === win.sel
                    confirming: selected && !!modelData.key && modelData.key === win.confirmKey
                    onPicked: { win.sel = index; win.activate(false) }
                    onHovered: if (win.sel !== index) { win.sel = index; win.confirmKey = "" }
                }
            }

            // ---- hint footer ----
            Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.alpha(Theme.textDim, 0.12) }
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                Layout.leftMargin: 18
                Layout.rightMargin: 18
                spacing: 14
                Txt {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    font.pixelSize: 11
                    color: Theme.textDim
                    readonly property string verb: win.current?.verb ?? (win.current?.badge !== undefined ? "switch" : "open")
                    text: win.current?.alt ? "↵ " + verb + " · Ctrl+↵ " + win.current.altLabel + " · Esc close"
                        : "↑↓ choose · Tab next group · ↵ " + verb + " · Esc close"
                }
                Txt { // the prefixes, while nothing is typed
                    visible: win.query === ""
                    font.pixelSize: 11
                    font.family: Theme.mono
                    color: Theme.alpha(Theme.textDim, 0.75)
                    text: "> run  : emoji  cb clip  f files  g yt gh nix w"
                }
            }
        }
    }
}
