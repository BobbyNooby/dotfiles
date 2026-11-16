// A line icon from the design, drawn as a tiny SVG in any colour.
//   Icon { name: "wifi"; size: 17; color: Theme.text }
// Icons are 24×24 stroke drawings; "filled" ones (play, pause, bolt...) are solid shapes.
// Add one: put its SVG body in `paths` below (use currentColor for the icon's colour).
import QtQuick

Image {
    id: icon
    property string name
    property color color: Theme.text
    property real size: 16
    property real stroke: 1.8

    readonly property var paths: ({
        // apps (bar workspaces, workspace OSD)
        term:    '<rect x="3" y="4" width="18" height="16" rx="3"/><path d="M7 9l3 3-3 3M12 15h5"/>',
        web:     '<circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3c2.5 2.7 3.8 5.7 3.8 9s-1.3 6.3-3.8 9c-2.5-2.7-3.8-5.7-3.8-9S9.5 5.7 12 3z"/>',
        code:    '<path d="M8 7l-5 5 5 5M16 7l5 5-5 5M14 4l-4 16"/>',
        music:   '<path d="M9 18V6l11-2v12"/><circle cx="6.5" cy="18" r="2.5"/><circle cx="17.5" cy="16" r="2.5"/>',
        chat:    '<path d="M4 5h16v11H9l-5 4z"/>',
        folder:  '<path d="M3 7a2 2 0 0 1 2-2h4l2 2h8a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/>',
        notes:   '<path d="M6 3h9l4 4v14H6z"/><path d="M9 11h7M9 15h7"/>',
        window:  '<rect x="3" y="4" width="18" height="16" rx="3"/><path d="M3 9h18"/>',
        // player
        play:    '<path d="M8 5.5v13l11-6.5z" fill="currentColor" stroke="none"/>',
        pause:   '<g fill="currentColor" stroke="none"><rect x="6" y="5" width="4" height="14" rx="1.2"/><rect x="14" y="5" width="4" height="14" rx="1.2"/></g>',
        prev:    '<g fill="currentColor" stroke="none"><path d="M18 6v12l-9-6z"/><rect x="5" y="6" width="2.4" height="12" rx="1"/></g>',
        next:    '<g fill="currentColor" stroke="none"><path d="M6 6v12l9-6z"/><rect x="16.6" y="6" width="2.4" height="12" rx="1"/></g>',
        lyrics:  '<path d="M4 6h16M4 11h12M4 16h8"/><path d="M18 14v6M18 14l3 1"/>',
        eq:      '<path d="M6 4v16M12 4v16M18 4v16"/><circle cx="6" cy="14" r="2" fill="BG"/><circle cx="12" cy="8" r="2" fill="BG"/><circle cx="18" cy="15" r="2" fill="BG"/>',
        headphones: '<path d="M4 15v-3a8 8 0 0 1 16 0v3"/><rect x="3" y="14" width="4.5" height="6.5" rx="1.5"/><rect x="16.5" y="14" width="4.5" height="6.5" rx="1.5"/>',
        speaker: '<rect x="6" y="3" width="12" height="18" rx="2.5"/><circle cx="12" cy="14" r="3"/><path d="M12 7h.01"/>',
        // bar
        ram:     '<rect x="3" y="7" width="18" height="10" rx="2"/><path d="M7 17v3M11 17v3M15 17v3M7.5 10.5v3M12 10.5v3M16.5 10.5v3"/>',
        keyboard:'<rect x="2.5" y="6" width="19" height="12" rx="2.5"/><path d="M6 10h.01M9.5 10h.01M13 10h.01M16.5 10h.01M7.5 14h9"/>',
        volume:  '<path d="M4 9.5h3.5L12 6v12l-4.5-3.5H4z"/><path d="M15.5 9a4 4 0 0 1 0 6M18 6.5a7.5 7.5 0 0 1 0 11"/>',
        mute:    '<path d="M4 9.5h3.5L12 6v12l-4.5-3.5H4z"/><path d="M16 9.5l5 5M21 9.5l-5 5"/>',
        wifi:    '<path d="M2.5 9a14 14 0 0 1 19 0M5.5 12.5a9.5 9.5 0 0 1 13 0M8.6 15.8a5 5 0 0 1 6.8 0"/><circle cx="12" cy="19" r="1.2" fill="currentColor"/>',
        bluetooth: '<path d="M7 7l10 10-5 5V2l5 5L7 17"/>',
        ethernet:'<rect x="4" y="9" width="16" height="11" rx="2"/><path d="M8 9V5h8v4M8 14v2M12 14v2M16 14v2"/>',
        bell:    '<path d="M6 16v-5a6 6 0 0 1 12 0v5l1.5 2h-15z"/><path d="M10 20.5a2 2 0 0 0 4 0"/>',
        slash:   '<path d="M4 4l16 16"/>',
        bolt:    '<path d="M13 2 5 13.5h6L10 22l8-11.5h-6z" fill="currentColor" stroke="none"/>',
        boltLine:'<path d="M13 2 5 13.5h6L10 22l8-11.5h-6z"/>',
        // weather (storm has its own yellow bolt)
        sun:     '<circle cx="12" cy="12" r="4"/><path d="M12 2.5v2M12 19.5v2M5.3 5.3l1.4 1.4M17.3 17.3l1.4 1.4M2.5 12h2M19.5 12h2M5.3 18.7l1.4-1.4M17.3 6.7l1.4-1.4"/>',
        moon:    '<path d="M20 14.5A8 8 0 1 1 9.5 4a6.5 6.5 0 0 0 10.5 10.5z"/>',
        cloud:   '<path d="M7 18h10a4 4 0 0 0 .5-7.97A6 6 0 0 0 6.1 9.5 4.25 4.25 0 0 0 7 18z"/>',
        rain:    '<path d="M7 14h10a4 4 0 0 0 .5-7.97A6 6 0 0 0 6.1 5.5 4.25 4.25 0 0 0 7 14z"/><path d="M8.5 17l-1 3M12.5 17l-1 3M16.5 17l-1 3"/>',
        snow:    '<path d="M7 14h10a4 4 0 0 0 .5-7.97A6 6 0 0 0 6.1 5.5 4.25 4.25 0 0 0 7 14z"/><path d="M8.5 18h.01M12 20h.01M15.5 18h.01"/>',
        storm:   '<path d="M7 14h10a4 4 0 0 0 .5-7.97A6 6 0 0 0 6.1 5.5 4.25 4.25 0 0 0 7 14z"/><path d="M12.5 15.5 10.5 19h3l-1.8 3.5" stroke="#f2c879"/>',
        // system card
        cpu:     '<rect x="6" y="6" width="12" height="12" rx="2"/><path d="M9 2.5v3.5M15 2.5v3.5M9 18v3.5M15 18v3.5M2.5 9H6M2.5 15H6M18 9h3.5M18 15h3.5"/>',
        gpu:     '<rect x="2.5" y="6" width="19" height="12" rx="2"/><circle cx="9" cy="12" r="3"/><path d="M15 10h3M15 14h3"/>',
        battery: '<rect x="2.5" y="7" width="17" height="10" rx="2.5"/><path d="M21.5 10.5v3"/>',
        saver:   '<path d="M5 19c0-8 5-13 14-14-1 9-6 14-14 14zM5 19l7-7"/>',
        balanced:'<path d="M12 4v16M8 20h8M5 8h14M5 8l-2.5 6a2.8 2.8 0 0 0 5 0zM19 8l-2.5 6a2.8 2.8 0 0 0 5 0z"/>',
        // connections
        tailscale: '<circle cx="6" cy="7" r="2.5"/><circle cx="18" cy="7" r="2.5"/><circle cx="12" cy="18" r="2.5"/><path d="M8.5 7h7M7.3 9.2l3.5 6.6M16.7 9.2l-3.5 6.6"/>',
        shield:  '<path d="M12 3l7.5 3v5.5c0 4.6-3.2 8.3-7.5 9.5-4.3-1.2-7.5-4.9-7.5-9.5V6z"/><path d="M9 12l2.2 2.2L15.5 10"/>',
        lock:    '<rect x="5" y="11" width="14" height="9" rx="2"/><path d="M8 11V8a4 4 0 0 1 8 0v3"/>',
        // general
        close:   '<path d="M6 6l12 12M18 6 6 18"/>',
        sparkle: '<path d="M12 3l1.8 5.2L19 10l-5.2 1.8L12 17l-1.8-5.2L5 10l5.2-1.8z"/><path d="M19 15l.8 2.2L22 18l-2.2.8L19 21l-.8-2.2L16 18l2.2-.8z"/>',
        send:    '<path d="M4 12l16-8-6 16-2.5-6.5z"/>',
        sync:    '<path d="M20 11a8 8 0 0 0-14.3-4.9L4 8M4 4v4h4M4 13a8 8 0 0 0 14.3 4.9L20 16M20 20v-4h-4"/>',
        user:    '<circle cx="12" cy="8" r="4"/><path d="M4 21a8 8 0 0 1 16 0"/>',
        image:   '<rect x="3" y="4" width="18" height="16" rx="3"/><circle cx="9" cy="10" r="2"/><path d="M21 16l-5-5-9 9"/>',
        logout:  '<path d="M9 21H6a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h3M16 17l5-5-5-5M21 12H9"/>',
        restart: '<path d="M20 11a8 8 0 1 0-2.3 5.7M20 4v7h-7"/>',
        power:   '<path d="M12 3v9M6.3 6.3a8 8 0 1 0 11.4 0"/>',
        chevron: '<path d="M9 6l6 6-6 6"/>',
        // launcher (Launcher.qml)
        calc:    '<rect x="5" y="3" width="14" height="18" rx="2.5"/><path d="M8.5 7.5h7M8.5 12h.01M12 12h.01M15.5 12h.01M8.5 16h.01M12 16h.01M15.5 16h.01"/>',
        smile:   '<circle cx="12" cy="12" r="9"/><path d="M8.5 14.5a4.5 4.5 0 0 0 7 0M9 9.5h.01M15 9.5h.01"/>',
        file:    '<path d="M6 3h8l4 4v14H6z"/><path d="M14 3v4h4"/>',
        camera:  '<path d="M4 8h3l2-3h6l2 3h3v11H4z"/><circle cx="12" cy="13" r="3.5"/>',
        droplet: '<path d="M12 3c3.5 4.2 6 7.4 6 10.5a6 6 0 0 1-12 0C6 10.4 8.5 7.2 12 3z"/>',
        trash:   '<path d="M4 7h16M10 11v6M14 11v6M6 7l1 13h10l1-13M9 7V4h6v3"/>',
        clipboard: '<rect x="5" y="4" width="14" height="17" rx="2"/><path d="M9 4h6v3H9z"/>',
        link:    '<path d="M10 14a4 4 0 0 0 5.7 0l3-3a4 4 0 0 0-5.7-5.7l-1 1M14 10a4 4 0 0 0-5.7 0l-3 3a4 4 0 0 0 5.7 5.7l1-1"/>',
        sliders: '<path d="M4 7h10M18 7h2M4 17h4M12 17h8"/><circle cx="16" cy="7" r="2"/><circle cx="10" cy="17" r="2"/>',
        plus:    '<path d="M12 5v14M5 12h14"/>',
        clock:   '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>',
        // Google (calendar popup, bar mail, Settings → Accounts)
        calendar:'<rect x="3.5" y="5" width="17" height="15.5" rx="2.5"/><path d="M3.5 10h17M8 3v4M16 3v4"/>',
        mail:    '<rect x="3" y="5.5" width="18" height="13" rx="2.5"/><path d="M3.5 7l8.5 6 8.5-6"/>',
        pin:     '<path d="M12 21s-6.5-5.6-6.5-11a6.5 6.5 0 0 1 13 0c0 5.4-6.5 11-6.5 11z"/><circle cx="12" cy="10" r="2.3"/>',
        video:   '<rect x="3" y="6.5" width="12.5" height="11" rx="2.5"/><path d="M15.5 10.5 21 7.5v9l-5.5-3"/>',
        info:    '<circle cx="12" cy="12" r="9"/><path d="M12 11v5"/><circle cx="12" cy="8" r="0.6" fill="currentColor"/>',
        mic:     '<rect x="9" y="3" width="6" height="11" rx="3"/><path d="M5.5 11a6.5 6.5 0 0 0 13 0M12 17.5V21"/>',
        search:  '<circle cx="11" cy="11" r="6.5"/><path d="M16 16l4.5 4.5"/>',
        type:    '<path d="M5 7V5h14v2M12 5v14M9 19h6"/>',
        git:     '<circle cx="6" cy="6" r="2.5"/><circle cx="6" cy="18" r="2.5"/><circle cx="18" cy="9" r="2.5"/><path d="M6 8.5v7M18 11.5c0 3-4 3.5-10 5"/>',
        gear:    '<circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.7 1.7 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.7 1.7 0 0 0-1.8-.3 1.7 1.7 0 0 0-1 1.5V21a2 2 0 1 1-4 0v-.1a1.7 1.7 0 0 0-1.1-1.5 1.7 1.7 0 0 0-1.8.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.7 1.7 0 0 0 .3-1.8 1.7 1.7 0 0 0-1.5-1H3a2 2 0 1 1 0-4h.1a1.7 1.7 0 0 0 1.5-1.1 1.7 1.7 0 0 0-.3-1.8l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.7 1.7 0 0 0 1.8.3H9a1.7 1.7 0 0 0 1-1.5V3a2 2 0 1 1 4 0v.1a1.7 1.7 0 0 0 1 1.5 1.7 1.7 0 0 0 1.8-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.7 1.7 0 0 0-.3 1.8V9a1.7 1.7 0 0 0 1.5 1H21a2 2 0 1 1 0 4h-.1a1.7 1.7 0 0 0-1.5 1z"/>'
    })

    // Colour used to "cut out" shapes (the EQ icon's knobs): the popup background
    property color cutout: Theme.bgLow

    function hex(c) { return Qt.rgba(c.r, c.g, c.b, 1).toString() }

    width: size
    height: size
    sourceSize.width: Math.round(size)
    sourceSize.height: Math.round(size)
    smooth: true
    opacity: color.a
    source: {
        const body = paths[name];
        if (!body) return "";
        const svg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor"'
            + ' stroke-width="' + stroke + '" stroke-linecap="round" stroke-linejoin="round">'
            + body + '</svg>';
        return "data:image/svg+xml;utf8," + encodeURIComponent(
            svg.replace(/currentColor/g, hex(color)).replace(/"BG"/g, '"' + hex(cutout) + '"'));
    }
}
