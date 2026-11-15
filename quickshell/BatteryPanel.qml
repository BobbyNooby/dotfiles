// Battery: click the battery in the bar. Charge, time left or to full, and the power profile.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.UPower
import "Common.js" as Common

Dropdown {
    id: win
    name: "battery"
    panelWidth: 260
    padding: 18
    spacing: 6

    readonly property var batt: UPower.displayDevice
    readonly property int bstate: batt?.state ?? 0

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
        text: win.bstate === UPowerDeviceState.Charging && win.batt.timeToFull > 0 ? "Full in about " + Common.hm(win.batt.timeToFull)
            : win.bstate === UPowerDeviceState.Discharging && win.batt.timeToEmpty > 0 ? "About " + Common.hm(win.batt.timeToEmpty) + " left" : ""
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
