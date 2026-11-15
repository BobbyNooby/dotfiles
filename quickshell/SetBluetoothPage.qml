// Settings → Bluetooth: on/off, Scan (looks for new devices for a while), your paired devices
// (connect / disconnect, forget, battery) and the ones found nearby (pair).
// Talks to BlueZ through Quickshell.Bluetooth; nothing here needs blueman.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth

SetPage {
    id: page
    title: "Bluetooth"
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool on: adapter?.enabled ?? false
    subtitle: !adapter ? "No Bluetooth adapter found." : (adapter.name || "Adapter") + (on ? " · on" : " · off")
    readonly property var all: Bluetooth.devices.values
    readonly property var paired: all.filter(d => d.paired || d.connected)
        .sort((a, b) => (b.connected - a.connected) || (a.name || "").localeCompare(b.name || ""))
    // Found while scanning; unnamed ones (just an address) last
    readonly property var found: all.filter(d => !d.paired && !d.connected)
        .sort((a, b) => (!!b.deviceName - !!a.deviceName) || (a.name || "").localeCompare(b.name || ""))
    property string forgetting: "" // address waiting for a second click

    // Stop scanning when you leave the page (scanning costs battery)
    Component.onDestruction: if (adapter?.discovering) adapter.discovering = false

    function kind(d) { return /audio|headset|headphone/.test(d.icon ?? "") ? "headphones" : /input-keyboard/.test(d.icon ?? "") ? "keyboard" : "bluetooth" }
    function stateText(d) {
        if (d.pairing) return "Pairing…";
        if (d.state === BluetoothDeviceState.Connecting) return "Connecting…";
        if (d.state === BluetoothDeviceState.Disconnecting) return "Disconnecting…";
        const batt = d.batteryAvailable ? " · battery " + Math.round(d.battery * 100) + "%" : "";
        return (d.connected ? "Connected" : d.paired ? "Paired" : "Not paired") + batt;
    }

    SetCard {
        SetRow {
            icon: "bluetooth"
            label: "Bluetooth"
            sub: !page.adapter ? "No adapter" : page.on ? (page.adapter.discovering ? "On · looking for devices" : "On") : "Off"
            toggle: !!page.adapter
            on: page.on
            onSwitched: page.adapter.enabled = !page.on
        }
    }

    SetCard {
        visible: page.on
        title: "My devices"
        Txt { visible: page.paired.length === 0; Layout.margins: 12; text: "No paired devices yet. Scan below to add one."; color: Theme.textDim }
        Repeater {
            model: page.paired
            SetRow {
                id: dev
                required property var modelData
                icon: page.kind(modelData)
                label: modelData.name || modelData.address
                sub: page.stateText(modelData)
                highlight: modelData.connected
                SetButton {
                    text: dev.modelData.connected ? "Disconnect" : "Connect"
                    accent: !dev.modelData.connected
                    onClicked: dev.modelData.connected ? dev.modelData.disconnect() : dev.modelData.connect()
                }
                SetButton {
                    text: page.forgetting === dev.modelData.address ? "Click again to forget" : "Forget"
                    danger: true
                    onClicked: {
                        if (page.forgetting !== dev.modelData.address) { page.forgetting = dev.modelData.address; return }
                        page.forgetting = "";
                        dev.modelData.forget();
                    }
                }
            }
        }
    }

    SetCard {
        visible: page.on
        title: "Other devices"
        trailing: SetButton {
            text: page.adapter?.discovering ? "Stop scanning" : "Scan"
            accent: !(page.adapter?.discovering ?? false)
            onClicked: page.adapter.discovering = !page.adapter.discovering
        }
        Txt {
            visible: page.found.length === 0
            Layout.margins: 12
            text: page.adapter?.discovering ? "Looking… put the device in pairing mode." : "Press Scan to look for devices nearby."
            color: Theme.textDim
        }
        Repeater {
            model: page.found
            SetRow {
                id: nd
                required property var modelData
                icon: page.kind(modelData)
                label: modelData.deviceName || modelData.address
                sub: page.stateText(modelData)
                fg: modelData.deviceName ? Theme.text : Theme.textDim
                SetButton {
                    text: nd.modelData.pairing ? "Cancel" : "Pair"
                    onClicked: nd.modelData.pairing ? nd.modelData.cancelPair() : nd.modelData.pair()
                }
            }
        }
    }

    Txt {
        visible: !page.on && !!page.adapter
        Layout.leftMargin: 6
        text: "Bluetooth is off."
        color: Theme.textDim
    }
}
