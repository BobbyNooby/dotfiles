// Battery: click the battery in the bar. Charge, time left or to full, and the power profile.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.UPower

Dropdown {
    id: win
    name: "battery"
    panelWidth: 260
    padding: 18
    spacing: 6

    readonly property var batt: UPower.displayDevice
    readonly property int bstate: batt?.state ?? 0
    function hm(secs) { const m = Math.round(secs / 60); return Math.floor(m / 60) + " h " + (m % 60 < 10 ? "0" : "") + m % 60 + " m" }

    Txt { heading: true; text: Math.round((win.batt?.percentage ?? 0) * 100) + "%"; font.pixelSize: 32 }
    Txt {
        text: win.bstate === UPowerDeviceState.Charging ? "Charging"
            : win.bstate === UPowerDeviceState.FullyCharged ? "Full"
            : win.bstate === UPowerDeviceState.PendingCharge ? "Plugged in, not charging" : "On battery"
        font.pixelSize: 14
        font.weight: Font.DemiBold
        color: Theme.accent
    }
    Txt {
        visible: text !== ""
        text: win.bstate === UPowerDeviceState.Charging && win.batt.timeToFull > 0 ? "Full in about " + win.hm(win.batt.timeToFull)
            : win.bstate === UPowerDeviceState.Discharging && win.batt.timeToEmpty > 0 ? "About " + win.hm(win.batt.timeToEmpty) + " left" : ""
        color: Theme.textDim
    }
    Txt {
        text: "Power profile: " + (PowerProfiles.profile === PowerProfile.PowerSaver ? "Saver"
            : PowerProfiles.profile === PowerProfile.Performance ? "Performance" : "Balanced")
        color: Theme.textDim
    }
    Txt {
        visible: (win.batt?.energyRate ?? 0) > 0
        text: "Using " + (win.batt?.energyRate ?? 0).toFixed(1) + " W"
        color: Theme.textDim
    }
}
