// Low-battery warnings: a notification when the charge drops past 20%, 10% and 5% while on
// battery (the last two stay up until you close them). Plugging in resets it, so each level
// warns once per discharge.
//
// Also the "battery look": in Saver mode (and `saverLook` on in the settings) Hyprland's blur,
// shadows and window animations go off (hypr/scripts/saver-look); any other mode restores them.
// Reloading Hyprland's config restores them too, so it's applied again after a reload.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.UPower

Scope {
    id: root
    readonly property var batt: UPower.displayDevice
    readonly property int pct: Math.round((batt?.percentage ?? 1) * 100)
    readonly property bool draining: batt?.state === UPowerDeviceState.Discharging
    property int warnedAt: 101 // the lowest level already warned about

    function check() {
        if (!draining) { warnedAt = 101; return }
        for (const level of [5, 10, 20]) {
            if (pct <= level && warnedAt > level) {
                warnedAt = level;
                Quickshell.execDetached(["notify-send", "-a", "Battery", "-i", "battery-caution",
                    "-u", level <= 10 ? "critical" : "normal",
                    level <= 5 ? "Battery almost empty" : "Battery low",
                    pct + "% left. " + (level <= 5 ? "Plug in now: the laptop will switch off soon." : "Plug in when you can.")]);
                break;
            }
        }
    }
    readonly property bool plain: Settings.saverLook && PowerProfiles.profile === PowerProfile.PowerSaver
    function look() { Quickshell.execDetached([Quickshell.env("HOME") + "/.config/hypr/scripts/saver-look", plain ? "on" : "off"]) }
    onPlainChanged: look()
    Component.onCompleted: if (plain) look()
    Connections {
        target: Hyprland
        function onRawEvent(event) { if (event.name === "configreloaded" && root.plain) root.look() }
    }

    onPctChanged: check()
    onDrainingChanged: check()
}
