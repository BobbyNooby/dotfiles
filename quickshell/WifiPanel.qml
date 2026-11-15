// Wi-Fi: click the Wi-Fi icon in the bar. The switch turns the radio on/off; click a network
// to join it (saved and open ones join at once; a new secured one asks for its password).
import QtQuick
import QtQuick.Layouts
import Quickshell

Dropdown {
    id: win
    name: "wifi"
    panelWidth: 320
    onShownChanged: Net.scanning = shown

    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: 4
        Txt { Layout.fillWidth: true; heading: true; text: "Wi-Fi"; font.pixelSize: 17 }
        Clicky {
            implicitWidth: 52
            implicitHeight: 44
            onClicked: Net.setWifi(!Net.wifiOn)
            Toggle { anchors.centerIn: parent; on: Net.wifiOn }
        }
    }

    ColumnLayout {
        visible: Net.wifiOn
        Layout.fillWidth: true
        spacing: 4
        Txt {
            visible: Net.networks.length === 0
            Layout.margins: 12
            text: "Looking for networks…"
            color: Theme.textDim
        }
        Repeater {
            model: Net.networks.slice(0, 7)
            Clicky {
                id: row
                required property var modelData
                Layout.fillWidth: true
                implicitHeight: 48
                radius: Theme.r(14)
                base: modelData.active ? Theme.accentSoft : "transparent"
                onClicked: Net.connect(modelData)
                readonly property color fg: modelData.active ? Theme.textOnSoft : Theme.text
                RowLayout {
                    anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                    spacing: 12
                    Icon {
                        name: "wifi"
                        size: 18
                        stroke: 1.9
                        color: Theme.alpha(row.fg, row.modelData.signal > 66 ? 1 : row.modelData.signal > 33 ? 0.7 : 0.45)
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        Txt { Layout.fillWidth: true; text: row.modelData.ssid; font.pixelSize: 14; font.weight: Font.DemiBold; color: row.fg; elide: Text.ElideRight }
                        Txt {
                            text: row.modelData.active ? "Connected" : row.modelData.saved ? "Saved" : row.modelData.secure ? "Secured" : "Open network"
                            font.pixelSize: 12
                            color: row.fg
                            opacity: 0.8
                        }
                    }
                    Icon { visible: row.modelData.secure; name: "lock"; size: 14; stroke: 2; color: Theme.alpha(row.fg, 0.7) }
                }
            }
        }
    }
    Txt {
        visible: !Net.wifiOn
        Layout.fillWidth: true
        Layout.margins: 12
        text: "Wi-Fi is off. Turn it on to see networks."
        wrapMode: Text.Wrap
        color: Theme.textDim
    }

    Clicky {
        Layout.fillWidth: true
        implicitHeight: 44
        radius: Theme.r(14)
        base: Theme.bgHigh
        onClicked: { Popups.close(); Quickshell.execDetached(["nm-connection-editor"]) }
        Txt { anchors.centerIn: parent; text: "Network settings"; font.weight: Font.DemiBold }
    }
}
