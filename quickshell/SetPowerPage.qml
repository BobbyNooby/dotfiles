// Settings → Power: the power profile (power-profiles-daemon), the battery (charge, time left,
// draw, health) and what happens when you leave the laptop idle (read from
// hypr/hypridle.conf; edit that file to change the times).
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
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

    // ---- idle (hypridle.conf) ----
    property var idle: [] // [{ secs, what }]
    FileView {
        path: Quickshell.env("HOME") + "/.config/hypr/hypridle.conf"
        watchChanges: true
        onFileChanged: reload()
        printErrors: false
        onLoaded: {
            // each `listener { timeout = N  # 5 min: lock ... }`: the time and the comment's words
            // (a RegExp loop: this JavaScript has no String.matchAll)
            const out = [], re = /listener\s*\{[^}]*?timeout\s*=\s*(\d+)[ \t]*(?:#\s*([^\n]*))?/g;
            const t = text();
            let m;
            while ((m = re.exec(t)) !== null) {
                const words = (m[2] ?? "").replace(/^[^:]*:\s*/, "");
                out.push({ secs: Number(m[1]), what: words || "action" });
            }
            page.idle = out.sort((a, b) => a.secs - b.secs);
        }
    }
    function dur(s) { return s < 60 ? s + " s" : s % 60 === 0 ? (s / 60) + " min" : (s / 60).toFixed(1) + " min" }

    SetCard {
        title: "When idle"
        Repeater {
            model: page.idle
            SetRow {
                required property var modelData
                icon: /lock/.test(modelData.what) ? "lock" : /suspend|sleep/.test(modelData.what) ? "moon" : /off/.test(modelData.what) ? "power" : "sun"
                label: "After " + page.dur(modelData.secs)
                sub: modelData.what
            }
        }
        Txt { visible: page.idle.length === 0; Layout.margins: 12; text: "No hypridle.conf found."; color: Theme.textDim }
        Txt {
            Layout.fillWidth: true
            Layout.margins: 12
            text: "Read from dotfiles/hypr/hypridle.conf. Change the times there, then restart hypridle (systemctl --user restart hypridle)."
            wrapMode: Text.Wrap
            font.pixelSize: 12
            color: Theme.outline
        }
    }
}
