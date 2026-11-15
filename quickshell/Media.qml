// Whatever is playing (Spotify, a browser tab, mpv...) via MPRIS: title, art, position.
// Picks the player that is playing right now, otherwise the first one open.
//
// Lyrics: synced lyrics from LRCLIB (lrclib.net, free, no key), matched by title, artist,
// album and length (scripts/lyrics, which keeps a copy so they work offline), then shown in
// time with the position (the floating lyrics on the desktop).
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

Singleton {
    id: root

    readonly property var players: Mpris.players.values
    // Remote-control apps (Spotifast when it drives the Spotify app) also show up as "playing"
    // but ignore play/pause, so the player that actually makes the sound wins over them.
    function remote(p) { return /spotifast/i.test((p.identity ?? "") + " " + (p.dbusName ?? "")) }
    readonly property var active: players.find(p => p.isPlaying && !remote(p))
        ?? players.find(p => p.isPlaying) ?? players.find(p => !remote(p)) ?? players[0] ?? null

    readonly property bool hasPlayer: active !== null
    readonly property string title: active?.trackTitle ?? ""
    readonly property string artist: active?.trackArtist ?? ""
    readonly property string album: active?.trackAlbum ?? ""
    readonly property string art: active?.trackArtUrl ?? ""
    readonly property string app: active?.identity ?? ""
    readonly property bool playing: active?.isPlaying ?? false
    readonly property real length: active?.length ?? 0 // seconds
    property real position: 0                          // seconds, smooth (see below)
    readonly property real progress: length > 0 ? Math.min(1, position / length) : 0

    function toggle() { if (active?.canTogglePlaying) active.togglePlaying() }
    function next() { if (active?.canGoNext) active.next() }
    function previous() { if (active?.canGoPrevious) active.previous() }
    function seek(fraction) { if (active?.canSeek && length > 0) { active.position = fraction * length; position = active.position } }
    function time(s) { s = Math.max(0, Math.floor(s)); return Math.floor(s / 60) + ":" + (s % 60 < 10 ? "0" : "") + s % 60 }

    // MPRIS doesn't announce position changes, so ask the player once a second and count
    // forward from there in between (10 times a second), so lyrics and progress bars move
    // smoothly instead of in half-second steps.
    property real readPos: 0     // last position the player reported...
    property real readAt: 0      // ...and when (ms)
    function sync() { readPos = active?.position ?? 0; readAt = Date.now(); position = readPos }
    onActiveChanged: sync()
    onPlayingChanged: sync()
    Timer {
        interval: 1000
        running: root.active !== null
        repeat: true
        triggeredOnStart: true
        onTriggered: root.sync()
    }
    // (only while lyrics or the player popup need it: otherwise the once-a-second ask is enough,
    // and the bar doesn't redraw 10 times a second for a 2 px progress line)
    Timer {
        interval: 100
        running: root.playing && (root.hasLyrics || Popups.open === "music")
        repeat: true
        onTriggered: {
            const p = root.readPos + (Date.now() - root.readAt) / 1000 * (root.active?.rate || 1);
            root.position = root.length > 0 ? Math.min(p, root.length) : p;
        }
    }

    // ---------------- lyrics ----------------
    property bool showLyrics: true  // the player's Lyrics button
    property var lines: []          // [{ t: seconds, text }]
    // Switch to the next line this much early (seconds), so it has finished rolling into
    // place when it's sung. Raise it if lyrics feel late, lower it if they feel early.
    property real lyricLead: 0.35
    readonly property int lineIndex: {
        let i = -1;
        for (let k = 0; k < lines.length && lines[k].t <= position + lyricLead; k++) i = k;
        return i;
    }
    readonly property string lyricNow: lineIndex < 0 ? (lines.length ? "· · ·" : "") : lines[lineIndex].text || "· · ·"
    readonly property string lyricNext: lines[lineIndex + 1]?.text ?? ""
    readonly property bool hasLyrics: lines.length > 0

    readonly property string trackKey: title + "\n" + artist
    onTrackKeyChanged: { lines = []; lyricDelay.restart(); sync() }
    onLengthChanged: if (lines.length === 0) lyricDelay.restart() // length often arrives a moment later

    Timer { // wait for the track's details to settle (players send them in pieces)
        id: lyricDelay
        interval: 900
        onTriggered: {
            if (!root.title || !root.artist) return;
            lrc.forKey = root.trackKey;
            lrc.command = [Quickshell.shellDir + "/scripts/lyrics", root.title, root.artist, root.album, String(Math.round(root.length))];
            lrc.running = true;
        }
    }

    function parse(lrcText) {
        const out = [];
        for (const line of (lrcText ?? "").split("\n")) {
            const m = line.match(/^\[(\d+):(\d+(?:\.\d+)?)\]\s*(.*)$/);
            if (m) out.push({ t: Number(m[1]) * 60 + Number(m[2]), text: m[3] });
        }
        return out;
    }

    // scripts/lyrics: LRCLIB with a cache, so songs you've played before work offline
    Process {
        id: lrc
        property string forKey
        stdout: StdioCollector {
            onStreamFinished: if (lrc.forKey === root.trackKey) root.lines = root.parse(text) // the song may have changed meanwhile
        }
    }
}
