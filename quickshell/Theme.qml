// Colours, fonts and sizes for every part of the shell.
// matugen writes colors.json next to this file from the wallpaper (run `setwall <image>`);
// the shell recolours the moment the file changes. The values below are the fallback
// (Tokyo Night Storm) for when colors.json doesn't exist yet.
//
// Look: the "Clean desktop" design (claude.ai design canvas "NixOS Desktop Preview"):
// Outfit for big numbers and headings, Inter for everything else, very round corners.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: theme

    // ---- colours (Material 3 roles, as matugen names them) ----
    readonly property color bg:          c.surface                    // bar background
    readonly property color bgLow:       c.surface_container_low      // popup background
    readonly property color bgMid:       c.surface_container          // rows and cards inside popups
    readonly property color bgHigh:      c.surface_container_high     // buttons, chips
    readonly property color bgHighest:   c.surface_container_highest  // hovered things, empty meter track
    readonly property color border:      c.outline_variant
    readonly property color outline:     c.outline                    // off switches, faint labels
    readonly property color text:        c.on_surface
    readonly property color textDim:     c.on_surface_variant
    readonly property color accent:      c.primary                    // active workspace, switches, play
    readonly property color textOnAccent:    c.on_primary                 // text drawn on top of accent
    readonly property color accentSoft:  c.primary_container          // "on" tiles, chosen network
    readonly property color textOnSoft: c.on_primary_container
    readonly property color second:      c.tertiary
    // low battery, DND slash, full meters. With a red or pink wallpaper matugen's error colour
    // is the same as the accent, so a warning would look like "normal": then use a fixed red.
    readonly property color danger: {
        const e = Qt.color(c.error), a = Qt.color(c.primary);
        const far = Math.abs(e.r - a.r) + Math.abs(e.g - a.g) + Math.abs(e.b - a.b) > 0.25;
        return far ? e : "#ff5a4f";
    }

    // Weather icons keep their own colours whatever the wallpaper
    readonly property color sun:  "#f2c879"
    readonly property color moon: "#c9d6ee"
    readonly property color rain: "#adcae6"

    // How see-through the bar and desktop cards are (Hyprland blurs what's behind them)
    readonly property real barOpacity: 0.84
    readonly property real cardOpacity: 0.74

    // ---- type and corners: ONE setting ----
    // The six pairings from the design canvas's Typography page:
    //   outfit (A, now) · grotesk (B) · mono (C) · condensed (D) · serif (E) · dotmatrix (F)
    // Each sets the display font (clocks, numbers, headings), the body font, italic / capital
    // headings, and how round the corners are. Fonts not installed fall back to a default.
    // Set in settings.nix (desktop.typeface) or the Settings window (Super+I → Appearance).
    readonly property string typeface: Settings.typeface
    readonly property var typefaces: ({
        outfit:    { display: "Outfit",           body: "Inter",          italic: false, caps: false, radius: 1.0 },
        grotesk:   { display: "Space Grotesk",    body: "IBM Plex Sans",  italic: false, caps: false, radius: 0.45 },
        mono:      { display: "JetBrains Mono",   body: "JetBrains Mono", italic: false, caps: false, radius: 0.2 },
        condensed: { display: "Barlow Condensed", body: "Barlow",         italic: false, caps: true,  radius: 0.15 },
        serif:     { display: "Newsreader",       body: "Inter Tight",    italic: true,  caps: false, radius: 0.55 },
        dotmatrix: { display: "Doto",             body: "Geist Mono",     italic: false, caps: true,  radius: 0.0 }
    })
    readonly property var tf: typefaces[typeface] ?? typefaces.outfit
    readonly property string fontDisplay: tf.display
    readonly property string fontBody: tf.body
    readonly property bool displayItalic: tf.italic
    readonly property bool displayCaps: tf.caps
    readonly property real radiusScale: tf.radius
    function r(px) { return Math.round(px * radiusScale) } // every corner: radius: Theme.r(24)

    // older names, used all over the shell
    readonly property string display: fontDisplay
    readonly property string font: fontBody
    readonly property string mono: "FiraCode Nerd Font Mono"
    readonly property int fontSize: 13

    // ---- shape and sizes ----
    readonly property int barTop: 8        // gap above the bar
    readonly property int barHeight: 44
    readonly property int barSide: 10      // gap left and right of the bar
    readonly property int popupTop: barTop + barHeight + 8 // popups open just under the bar
    readonly property int radius: r(14)  // Control Center tiles and buttons

    function alpha(col, a) { return Qt.rgba(col.r, col.g, col.b, a) }
    // A file path as an image address; names with # ? % or spaces would break a plain "file://"+path
    function fileUrl(p) { return "file://" + p.split("/").map(encodeURIComponent).join("/") }

    FileView {
        path: Quickshell.shellDir + "/colors.json"
        watchChanges: true
        onFileChanged: reload()
        printErrors: false // a missing file just means "use the fallback"

        adapter: JsonAdapter {
            id: c
            property string surface:                   "#1f2335"
            property string surface_container_low:     "#222639"
            property string surface_container:         "#24283b"
            property string surface_container_high:    "#292e42"
            property string surface_container_highest: "#2f344a"
            property string outline_variant:           "#3b4261"
            property string outline:                   "#737aa2"
            property string on_surface:                "#c0caf5"
            property string on_surface_variant:        "#a9b1d6"
            property string primary:                   "#7aa2f7"
            property string on_primary:                "#1a1b26"
            property string primary_container:         "#3d59a1"
            property string on_primary_container:      "#dbe4ff"
            property string tertiary:                  "#bb9af7"
            property string error:                     "#f7768e"
        }
    }
}
