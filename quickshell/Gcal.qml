// Google: your accounts, calendar events and unread mail, from scripts/google (Hermes' sign-in).
// Events: last month + 60 days ahead, every 10 min (unread with them); both at once on
// refresh(), when the network comes back, and when a popup opens with old data.
// Saved to ~/.cache/quickshell/by-shell/…/gcal.json and shown straight away on start, so the
// calendar works offline ("offline · as of 14:05"). The helper takes 1–3 s per account.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// (More here, below the imports, to keep `pragma Singleton` near the top.)
// The helper never fails loudly when Google can't be reached: an account that errors just
// adds nothing. So an empty answer while offline is treated as "couldn't fetch" and the saved
// data stays. Named Gcal, not Calendar: QtQuick's Calendar would shadow it.
Singleton {
    id: root

    // demo mode: made-up accounts, events and counts (scripts/google-demo)
    readonly property string helper: Quickshell.shellDir + (Settings.demo ? "/scripts/google-demo" : "/scripts/google")
    onHelperChanged: { events = []; unread = []; refresh() }

    property var accounts: []       // [{ name, account (email), calendar, gmail }]
    property var events: []         // the helper's events + _s/_e (ms) and _key, sorted by start
    property var unread: []         // [{ name, account, unread }]
    property real eventsAt: 0       // when events were last fetched (ms), 0 = never
    property real unreadAt: 0
    property bool stale: false      // the last fetch failed: showing saved data
    property bool loaded: false     // accounts known (from the cache or the helper)
    property string error: ""       // the helper's error (e.g. Hermes not installed)
    property bool noHermes: false
    property int tick: 0            // bumps every minute ("in 25 min", today moves at midnight)

    readonly property bool connected: accounts.length > 0
    readonly property bool hasCalendar: accounts.some(a => a.calendar)
    readonly property bool busy: !!(accountsProc.running || eventsProc.running || unreadProc.running)
    readonly property int unreadTotal: unread.reduce((n, a) => n + (a.unread ?? 0), 0)
    readonly property var unreadAccounts: unread.filter(a => (a.unread ?? 0) > 0)
    // "Offline · as of 14:05" (or "as of Mon 16 Nov 14:05") when showing saved events
    readonly property string staleText: {
        tick;
        if (!stale || !eventsAt) return "";
        const d = new Date(eventsAt);
        return "Offline · as of " + (dayKey(d) === dayKey(new Date()) ? "" : Qt.formatDate(d, "ddd d MMM") + " ") + Qt.formatTime(d, "HH:mm");
    }

    // ---- fetching ----
    function refresh() { runAccounts(true) }
    // Refresh if the events are older than `minutes` (popups call this when they open)
    function refreshIfOld(minutes) { if (Date.now() - eventsAt > (minutes ?? 2) * 60000) refresh() }
    function fetchUnread() { if (unreadProc.running) unreadProc.again = true; else unreadProc.running = true }
    function runAccounts(thenAll) {
        if (thenAll) accountsProc.thenAll = true;
        if (!accountsProc.running) accountsProc.running = true;
    }
    function fetchEvents() {
        if (eventsProc.running) { eventsProc.again = true; return }
        // from the 1st of last month (or a week back, if that's earlier) to 60 days ahead
        const now = new Date();
        const from = new Date(now.getFullYear(), now.getMonth() - 1, 1);
        const to = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 61);
        eventsProc.command = [helper, "events", iso(from), iso(to)];
        eventsProc.running = true;
    }
    function parse(text) {
        try { return JSON.parse(text) } catch (e) { return { error: "Couldn't read the helper's answer" } }
    }

    Process {
        id: accountsProc
        property bool thenAll: false
        command: [root.helper, "accounts"]
        stdout: StdioCollector {
            onStreamFinished: {
                const j = root.parse(text);
                if (Array.isArray(j)) {
                    root.accounts = j;
                    root.error = "";
                    root.noHermes = false;
                    root.loaded = true;
                    if (!j.length) { root.events = []; root.unread = []; root.stale = false; root.eventsAt = root.unreadAt = Date.now() }
                } else {
                    root.error = j.error ?? "";
                    root.noHermes = !!j.noHermes;
                    root.loaded = true;
                }
                root.save();
                if (accountsProc.thenAll && root.connected) { root.fetchEvents(); root.fetchUnread() }
                accountsProc.thenAll = false;
            }
        }
    }
    Process {
        id: eventsProc
        property bool again: false
        stdout: StdioCollector {
            onStreamFinished: {
                const j = root.parse(text);
                // offline: the helper answers [] (or nothing); keep what's saved
                const failed = !Array.isArray(j) || (!j.length && !Net.online && root.events.length);
                if (failed) root.stale = true;
                else {
                    root.events = root.prepare(j);
                    root.eventsAt = Date.now();
                    root.stale = false;
                    root.save();
                }
                if (eventsProc.again) { eventsProc.again = false; root.fetchEvents() }
            }
        }
    }
    Process {
        id: unreadProc
        property bool again: false
        command: [root.helper, "unread"]
        stdout: StdioCollector {
            onStreamFinished: {
                const j = root.parse(text);
                if (Array.isArray(j) && (j.length || Net.online)) {
                    root.unread = j;
                    root.unreadAt = Date.now();
                    root.save();
                }
                if (unreadProc.again) { unreadProc.again = false; unreadProc.running = true }
            }
        }
    }

    Timer { interval: Pace.slow(600000); running: true; repeat: true; triggeredOnStart: true; onTriggered: root.runAccounts(true) }
    Timer { id: retry; interval: 60000; repeat: true; running: root.stale && Net.online; onTriggered: root.refresh() }
    SystemClock { precision: SystemClock.Minutes; onDateChanged: root.tick++ }
    Connections { // network back: fetch now instead of waiting
        target: Net
        function onOnlineChanged() { if (Net.online) root.refreshIfOld(1) }
    }

    // ---- the saved copy ----
    FileView {
        id: cache
        path: Quickshell.cachePath("gcal.json")
        printErrors: false
        // Fill in what the helper hasn't answered yet (accounts are quick, events take seconds)
        onLoaded: {
            try {
                const c = JSON.parse(text());
                if (!root.loaded) root.accounts = c.accounts ?? [];
                if (!root.eventsAt) {
                    root.events = root.prepare(c.events ?? []);
                    root.eventsAt = c.eventsAt ?? 0;
                    root.stale = Date.now() - root.eventsAt > 15 * 60000; // until a fetch succeeds
                }
                if (!root.unreadAt) { root.unread = c.unread ?? []; root.unreadAt = c.unreadAt ?? 0 }
            } catch (e) {}
            root.cacheRead = true;
        }
        onLoadFailed: root.cacheRead = true // no saved copy yet
    }
    property bool cacheRead: false // don't overwrite the saved copy before it's been read
    function save() {
        if (!cacheRead) { saveLater.restart(); return }
        cache.setText(JSON.stringify({
            accounts, unread, eventsAt, unreadAt,
            events: events.map(e => { const o = Object.assign({}, e); delete o._s; delete o._e; delete o._keys; return o })
        }));
    }

    Timer { id: saveLater; interval: 500; onTriggered: root.save() }

    // ---- dates ----
    function pad(n) { return (n < 10 ? "0" : "") + n }
    function dayKey(d) { return d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate()) }
    // A local time as RFC 3339 with its offset: 2026-11-17T00:00:00+08:00
    function iso(d) {
        const off = -d.getTimezoneOffset(), a = Math.abs(off);
        return dayKey(d) + "T" + pad(d.getHours()) + ":" + pad(d.getMinutes()) + ":00"
            + (off >= 0 ? "+" : "-") + pad(Math.floor(a / 60)) + ":" + pad(a % 60);
    }
    // "2026-11-17" → local midnight that day
    function fromKey(k) { const p = k.split("-").map(Number); return new Date(p[0], p[1] - 1, p[2]) }
    function addDays(d, n) { return new Date(d.getFullYear(), d.getMonth(), d.getDate() + n) }

    // Adds start/end in ms and the days each event touches; sorts by start (all-day first)
    function prepare(list) {
        const out = [];
        for (const e of list) {
            if (!e || !e.start) continue;
            const o = Object.assign({}, e);
            if (o.allDay) {
                o._s = fromKey(o.start).getTime();
                o._e = o.end ? fromKey(o.end).getTime() : addDays(new Date(o._s), 1).getTime(); // end is exclusive
            } else {
                o._s = new Date(o.start).getTime();
                o._e = o.end ? new Date(o.end).getTime() : o._s;
            }
            if (isNaN(o._s)) continue;
            const keys = [];
            let d = new Date(o._s);
            d = new Date(d.getFullYear(), d.getMonth(), d.getDate());
            const last = Math.max(o._s, o._e - 1); // an event ending at midnight doesn't touch the next day
            for (let i = 0; d.getTime() <= last && i < 62; i++, d = addDays(d, 1)) keys.push(dayKey(d));
            o._keys = keys;
            out.push(o);
        }
        out.sort((a, b) => a._s - b._s || (b.allDay - a.allDay));
        return out;
    }
    // day key → that day's events (all-day ones first)
    readonly property var byDay: {
        const m = {};
        for (const e of events) for (const k of e._keys ?? []) (m[k] = m[k] ?? []).push(e);
        for (const k in m) m[k].sort((a, b) => (b.allDay - a.allDay) || a._s - b._s);
        return m;
    }

    function eventsOn(date) { return byDay[dayKey(date)] ?? [] }
    function hasEvents(date) { return !!byDay[dayKey(date)] }
    // The calendar colours of a day's events, each once, at most `max` (the month grid's dots)
    function colorsOn(date, max) {
        const c = [];
        for (const e of eventsOn(date)) {
            const col = e.color || Theme.accent;
            if (!c.includes(col)) c.push(col);
            if (c.length >= (max ?? 3)) break;
        }
        return c;
    }
    // What's on now or next: events that haven't ended, soonest first
    function upcoming(n) {
        tick;
        const now = Date.now();
        return events.filter(e => e._e > now).slice(0, n ?? 4);
    }

    // ---- words ----
    // Big counts short: 950, 1.2k, 30k
    function count(n) { return n < 1000 ? String(n) : n < 10000 ? (Math.floor(n / 100) / 10) + "k" : Math.floor(n / 1000) + "k" }
    function hm(ms) { return Qt.formatTime(new Date(ms), "HH:mm") }
    // "09:00 – 10:30", "All day", "All day · until Wed 19 Nov", "Until 11:00" for a multi-day
    function timeText(e, date) {
        if (e.allDay) {
            const days = (e._keys ?? []).length;
            return days > 1 ? "All day · until " + Qt.formatDate(new Date(e._e - 1), "ddd d MMM") : "All day";
        }
        const k = date ? dayKey(date) : dayKey(new Date(e._s));
        const sameStart = dayKey(new Date(e._s)) === k, sameEnd = dayKey(new Date(e._e - 1)) === k;
        if (sameStart && sameEnd) return e._e > e._s ? hm(e._s) + " – " + hm(e._e) : hm(e._s);
        if (sameStart) return "From " + hm(e._s);
        if (sameEnd) return "Until " + hm(e._e);
        return "All day";
    }
    // For the desktop card: "Now · until 15:00", "in 25 min", "Today 14:00", "Tomorrow 09:00", "Thu 20 Nov 09:00"
    function whenText(e) {
        tick;
        const now = Date.now();
        if (e._s <= now) return e.allDay ? (e._keys.length > 1 ? "Until " + Qt.formatDate(new Date(e._e - 1), "ddd d MMM") : "Today · all day") : "Now · until " + hm(e._e);
        const mins = Math.round((e._s - now) / 60000);
        const today = new Date(), k = dayKey(new Date(e._s));
        const label = k === dayKey(today) ? "Today" : k === dayKey(addDays(today, 1)) ? "Tomorrow" : Qt.formatDate(new Date(e._s), "ddd d MMM");
        if (e.allDay) return label + " · all day";
        if (mins < 60) return "In " + Math.max(1, mins) + " min · " + hm(e._s);
        return label + " " + hm(e._s);
    }
    // Opening an event in the right account (multi-account browsers pick the first otherwise)
    function emailOf(name) { return accounts.find(a => a.name === name)?.account ?? "" }
    function open(url) { if (url) Quickshell.execDetached(["xdg-open", url]) }
    function openEvent(e) {
        const who = emailOf(e.accountName);
        open(e.link + (who && e.link ? (e.link.includes("?") ? "&" : "?") + "authuser=" + encodeURIComponent(who) : ""));
    }
    function openCalendar(date) {
        const d = date ?? new Date();
        open("https://calendar.google.com/calendar/r/day/" + d.getFullYear() + "/" + (d.getMonth() + 1) + "/" + d.getDate());
    }
    function openMail(email) { open(email ? "https://mail.google.com/mail/u/" + encodeURIComponent(email) : "https://mail.google.com") }
    // ---- connect / disconnect (Settings → Accounts) ----
    // Sign-in is interactive (paste the address back): a terminal of its own, and a refresh
    // when it closes. --always-new-process makes wezterm wait for its window.
    property string connecting: ""   // the account being signed in
    function connect(name) {
        if (connectProc.running || !name) return;
        connecting = name;
        connectProc.command = ["wezterm", "start", "--always-new-process", "--class", "google-connect", "--", helper, "connect", name];
        connectProc.running = true;
    }
    function disconnect(name) {
        if (disconnectProc.running || !name) return;
        disconnectProc.command = [helper, "disconnect", name];
        disconnectProc.running = true;
    }
    Process { id: connectProc; onExited: { root.connecting = ""; root.refresh() } }
    Process { id: disconnectProc; onExited: root.refresh() }

    // Settings → Accounts (the Settings window is a window, so ask it over IPC)
    function openSettings() { Quickshell.execDetached(["qs", "ipc", "call", "settings", "open", "accounts"]) }
}
