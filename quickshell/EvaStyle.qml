// The fixed look of the Eva 7 "Signal board" lock screen (LockScreen.qml, EvaBoard.qml):
// colours, fonts and the glow level. Fixed on purpose: it doesn't follow the wallpaper.
// Taken from the design canvas board Login-EvaSignal.dc.html (docs/desktop/design/).
pragma Singleton
import QtQuick
import Quickshell

Singleton {
    // ---- palette ----
    readonly property color bg:      "#050505" // black
    readonly property color orange:  "#ff8a1e" // main: labels, clock, buttons
    readonly property color cyan:    "#2de1c2" // second: meters, border line, UK time
    readonly property color green:   "#3cff7a" // granted, online
    readonly property color red:     "#ff3b2a" // denied, offline, music X
    readonly property color yellow:  "#ffd400" // verifying, caps lock
    readonly property color white:   "#f4f1ea" // big readings
    readonly property color dim:     "#8a5a2a" // small print
    readonly property color dark:    "#5a3210" // unlit labels
    readonly property color line:    "#3a2008" // panel borders, unlit steps
    readonly property color segOff:  "#221204" // unlit clock segments
    readonly property color ledOff:  "#0c2622" // unlit meter LEDs
    readonly property color hot:     "#ff3b5c" // meter LEDs past 80 %
    readonly property color board:   "#b85f10" // the Tailnet circuit board
    readonly property color boardInk: "#2a1404"

    // ---- type ----
    readonly property string sans: "TeX Gyre Heros Cn"   // condensed Helvetica-style (gyre-fonts)
    readonly property string jp:   "Shippori Mincho B1"  // the Japanese labels (google-fonts)
    readonly property string mono: "Share Tech Mono"     // small numbers (google-fonts)

    // ---- glow: "strong", "soft" or "off" ----
    // strong: halos round labels, LEDs and the clock + scanlines and vignette
    // soft:   smaller halos, fainter scanlines;  off: flat, no halos or scanlines
    readonly property string glow: Settings.lockGlow // settings.nix desktop.lockGlow
    readonly property real halo: glow === "strong" ? 1.0 : glow === "soft" ? 0.45 : 0
}
