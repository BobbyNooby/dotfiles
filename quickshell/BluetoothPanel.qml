// Bluetooth: click the Bluetooth icon in the bar. The switch turns it on/off; click a device to
// connect or disconnect it. New devices: "Pair a new device" opens the Bluetooth manager.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth

Dropdown {
    id: win
    name: "bluetooth"
    panelWidth: 320

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool on: adapter?.enabled ?? false
    // paired devices first (connected at the top), then ones nearby while it looks
    readonly property var devices: Bluetooth.devices.values
        .filter(d => d.paired || d.connected)
        .sort((a, b) => (b.connected - a.connected) || a.name.localeCompare(b.name))

    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: 4
        Txt { Layout.fillWidth: true; heading: true; text: "Bluetooth"; font.pixelSize: 17 }
        Clicky {
            implicitWidth: 52
            implicitHeight: 44
            onClicked: if (win.adapter) win.adapter.enabled = !win.on
            Toggle { anchors.centerIn: parent; on: win.on }
        }
    }

    ColumnLayout {
        visible: win.on
        Layout.fillWidth: true
        spacing: 4
        Txt {
            visible: win.devices.length === 0
            Layout.margins: 12
            text: "No paired devices yet."
            color: Theme.textDim
        }
        Repeater {
            model: win.devices
            Clicky {
                id: row
                required property var modelData
                readonly property bool busy: modelData.state === BluetoothDeviceState.Connecting || modelData.state === BluetoothDeviceState.Disconnecting
                readonly property color fg: modelData.connected ? Theme.textOnSoft : Theme.text
                Layout.fillWidth: true
                implicitHeight: 48
                radius: Theme.r(14)
                base: modelData.connected ? Theme.accentSoft : "transparent"
                onClicked: modelData.connected ? modelData.disconnect() : modelData.connect()
                RowLayout {
                    anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                    spacing: 12
                    Icon {
                        name: /audio|headset|headphone/.test(row.modelData.icon ?? "") ? "headphones" : "bluetooth"
                        size: 18
                        color: row.fg
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        Txt { Layout.fillWidth: true; text: row.modelData.name || row.modelData.address; font.pixelSize: 14; font.weight: Font.DemiBold; color: row.fg; elide: Text.ElideRight }
                        Txt {
                            text: row.busy ? (row.modelData.connected ? "Disconnecting…" : "Connecting…")
                                : row.modelData.connected ? "Connected" + (row.modelData.batteryAvailable ? " · " + Math.round(row.modelData.battery * 100) + "%" : "")
                                : "Paired"
                            font.pixelSize: 12
                            color: row.fg
                            opacity: 0.8
                        }
                    }
                }
            }
        }
    }
    Txt {
        visible: !win.on
        Layout.fillWidth: true
        Layout.margins: 12
        text: "Bluetooth is off."
        color: Theme.textDim
    }

    Clicky {
        Layout.fillWidth: true
        implicitHeight: 44
        radius: Theme.r(14)
        base: Theme.bgHigh
        onClicked: { Popups.close(); Quickshell.execDetached(["blueman-manager"]) }
        Txt { anchors.centerIn: parent; text: "Pair a new device"; font.weight: Font.DemiBold }
    }
}
