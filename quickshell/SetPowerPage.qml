// Settings → Power: the power profile (power-profiles-daemon), the battery (charge, time left,
// draw, health), what happens when you leave the laptop idle (dim, lock, screen off, sleep) and
// what closing the lid does. Idle changes apply at once (Settings.setIdle → hypr/scripts/
// idle-config rewrites hypridle.conf); the lid is the system's (logind), so it needs a rebuild.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.UPower

SetPage {
    id: page
    title: "Power"
    readonly property var batt: UPower.displayDevice
    // The real battery (the display device has no health or model)
    readonly property var cell: UPower.devices.values.find(d => d.isLaptopBattery) ?? null
    readonly property int bstate: batt?.state ?? 0
    readonly property bool hasBattery: !!cell || (batt?.isPresent ?? false)
    subtitle: !hasBattery ? "No battery" : Math.round((batt?.percentage ?? 0) * 100) + "% · " + stateText

    function hm(secs) { const m = Math.round(secs / 60); return m < 60 ? m + " min" : Math.floor(m / 60) + " h " + (m % 60 < 10 ? "0" : "") + m % 60 + " m" }
    readonly property string stateText: bstate === UPowerDeviceState.Charging ? "Charging"
        : bstate === UPowerDeviceState.FullyCharged ? "Full"
        : bstate === UPowerDeviceState.PendingCharge ? "Plugged in, not charging" : "On battery"

    // ---- profile ----
    SetCard {
        title: "Power mode"
        SetChoice {
            Layout.margins: 6
            options: [
                { value: PowerProfile.PowerSaver, label: "Saver", icon: "saver" },
                { value: PowerProfile.Balanced, label: "Balanced", icon: "balanced" },
                ...(PowerProfiles.hasPerformanceProfile ? [{ value: PowerProfile.Performance, label: "Performance", icon: "boltLine" }] : [])
            ]
            current: PowerProfiles.profile
            onPicked: v => PowerProfiles.profile = v
        }
        Txt {
            Layout.leftMargin: 12
            Layout.bottomMargin: 6
            text: PowerProfiles.profile === PowerProfile.PowerSaver ? "Slower, cooler, longest battery."
                : PowerProfiles.profile === PowerProfile.Performance ? "Fastest; fans and battery pay for it."
                : "The everyday mode."
            font.pixelSize: 12
            color: Theme.textDim
        }
    }

    // ---- battery ----
    SetCard {
        visible: page.hasBattery
        title: "Battery"
        SetRow {
            icon: "battery"
            label: Math.round((page.batt?.percentage ?? 0) * 100) + "% · " + page.stateText
            sub: page.bstate === UPowerDeviceState.Charging && page.batt.timeToFull > 0 ? "Full in about " + page.hm(page.batt.timeToFull)
                : page.bstate === UPowerDeviceState.Discharging && page.batt.timeToEmpty > 0 ? "About " + page.hm(page.batt.timeToEmpty) + " left" : ""
        }
        SetRow {
            visible: Math.abs(page.cell?.changeRate ?? page.batt?.changeRate ?? 0) > 0
            icon: "bolt"
            label: (page.bstate === UPowerDeviceState.Charging ? "Charging at " : "Using ") + Math.abs(page.cell?.changeRate ?? page.batt?.changeRate ?? 0).toFixed(1) + " W"
        }
        SetRow {
            visible: !!page.cell
            icon: "sync"
            label: "Health " + (page.cell?.healthSupported ? Math.round(page.cell.healthPercentage) + "%" : "unknown")
            sub: (page.cell ? (page.cell.energy ?? 0).toFixed(1) + " of " + (page.cell.energyCapacity ?? 0).toFixed(1) + " Wh" : "")
                + (page.cell?.model ? " · " + page.cell.model : "")
        }
        Txt {
            Layout.leftMargin: 12
            Layout.bottomMargin: 6
            text: "History: run `battery` in a terminal."
            font.pixelSize: 12
            color: Theme.outline
        }
    }

    // ---- idle (Settings.idle → hypridle) ----
    function dur(s) { return s <= 0 ? "never" : s < 60 ? s + " s" : s % 60 === 0 ? (s / 60) + " min" : (s / 60).toFixed(1) + " min" }
    function mins(list) { return list.map(m => ({ value: m * 60, label: m === 0 ? "Never" : m < 60 ? m + " min" : (m / 60) + " h" })) }

    SetCard {
        title: "When idle"
        Repeater {
            model: [
                { key: "dim", icon: "sun", label: "Dim the screen", choices: page.mins([0, 1, 2.5, 5, 10]) },
                { key: "lock", icon: "lock", label: "Lock", choices: page.mins([0, 2, 5, 10, 15, 30]) },
                { key: "screenOff", icon: "power", label: "Turn the screen off", choices: page.mins([0, 2, 5.5, 10, 15, 30]) },
                { key: "suspend", icon: "moon", label: "Sleep", choices: page.mins([0, 15, 30, 60, 120]) }
            ]
            ColumnLayout {
                id: step
                required property var modelData
                readonly property int secs: Settings.idle[modelData.key] ?? 0
                Layout.fillWidth: true
                spacing: 0
                SetRow { icon: step.modelData.icon; label: step.modelData.label; sub: step.secs > 0 ? "After " + page.dur(step.secs) + " idle" : "Never" }
                SetChoice {
                    Layout.leftMargin: 6
                    Layout.rightMargin: 6
                    Layout.bottomMargin: 6
                    options: step.modelData.choices
                    current: step.secs
                    onPicked: v => Settings.setIdle(step.modelData.key, v)
                }
            }
        }
        SetRow {
            icon: "bolt"
            label: "Sleep on the charger too"
            sub: Settings.idle.suspendPluggedIn ? "Sleeps after the time above, plugged in or not" : "Only sleeps on battery"
            toggle: true
            on: Settings.idle.suspendPluggedIn
            onSwitched: Settings.setIdle("suspendPluggedIn", !Settings.idle.suspendPluggedIn)
        }
        SetRow {
            icon: "lock"
            label: "Lock before sleeping"
            sub: Settings.idle.lockOnSleep ? "Waking up (lid, sleep) asks for your password" : "Waking up goes straight to the desktop"
            toggle: true
            on: Settings.idle.lockOnSleep
            onSwitched: Settings.setIdle("lockOnSleep", !Settings.idle.lockOnSleep)
        }
        OverrideNote { key: "idle"; Layout.margins: 6 }
    }

    // ---- lid (logind: settings.nix only) ----
    function lidText(v) { return v === "lock" ? "Lock, stay awake" : v === "ignore" ? "Nothing" : "Sleep" }
    SetCard {
        title: "Closing the lid"
        SetRow { icon: "battery"; label: "On battery"; sub: page.lidText(Settings.idle.lid) }
        SetRow { icon: "bolt"; label: "On the charger"; sub: page.lidText(Settings.idle.lidPluggedIn) }
        Txt {
            Layout.fillWidth: true
            Layout.margins: 12
            text: "Set by the system: change lid / lidPluggedIn under desktop.idle in settings.nix (\"suspend\", \"lock\" or \"ignore\"), then rebuild."
            wrapMode: Text.Wrap
            font.pixelSize: 12
            color: Theme.outline
        }
    }
}
