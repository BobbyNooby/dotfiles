// Settings → Wi-Fi & VPN: the radio, networks around (click to join; a new secured one asks
// for its password right here), saved networks (Forget), Surfshark locations and Tailscale.
// Wi-Fi goes through NetworkManager (Net.qml + nmcli), the VPNs through Vpn.qml.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

SetPage {
    id: page
    title: "Wi-Fi & VPN"
    subtitle: Net.wired ? "Wired connection" + (Net.ssid ? " and Wi-Fi " + Net.ssid : "") : Net.label

    // The network list only refreshes while something looks at it
    Component.onCompleted: { Net.scanning = true; Vpn.refresh() }
    Component.onDestruction: Net.scanning = false

    property string asking: ""     // network whose password box is open
    property string joining: ""    // network being joined
    property string error: ""      // nmcli's complaint, shown under it
    property string forgetting: "" // saved network waiting for a second click

    function join(net) {
        error = "";
        if (net.saved || !net.secure) { Net.connect(net); return }
        asking = asking === net.ssid ? "" : net.ssid;
    }
    // A new secured network: nmcli saves it with the password (NetworkManager keeps it, not us)
    function joinWith(ssid, pw) {
        joining = ssid;
        error = "";
        joinProc.command = ["nmcli", "device", "wifi", "connect", ssid, "password", pw];
        joinProc.running = true;
    }
    Process {
        id: joinProc
        stderr: StdioCollector { id: joinErr }
        onExited: code => {
            if (code !== 0) page.error = (joinErr.text.trim().split("\n").pop() || "Couldn't join").replace(/^Error: /, "");
            else page.asking = "";
            page.joining = "";
            Net.refresh();
        }
    }
    function forget(name) {
        if (forgetting !== name) { forgetting = name; return }
        forgetting = "";
        Quickshell.execDetached(["nmcli", "connection", "delete", "id", name]);
        refreshSoon.restart();
    }
    Timer { id: refreshSoon; interval: 1200; onTriggered: Net.refresh() }

    // ---- Wi-Fi ----
    SetCard {
        SetRow {
            icon: "wifi"
            label: "Wi-Fi"
            sub: Net.wifiOn ? (Net.ssid ? "Connected to " + Net.ssid + " · " + Net.signal + "%" : "On, not connected") : "Off"
            toggle: true
            on: Net.wifiOn
            onSwitched: Net.setWifi(!Net.wifiOn)
        }
    }

    SetCard {
        visible: Net.wifiOn
        title: "Networks"
        trailing: SetButton { text: "Advanced…"; onClicked: Quickshell.execDetached(["nm-connection-editor"]) }
        Txt {
            visible: Net.networks.length === 0
            Layout.margins: 12
            text: "Looking for networks…"
            color: Theme.textDim
        }
        Repeater {
            model: Net.networks
            ColumnLayout {
                id: net
                required property var modelData
                readonly property bool open: page.asking === modelData.ssid
                Layout.fillWidth: true
                spacing: 4
                SetRow {
                    label: net.modelData.ssid
                    sub: page.joining === net.modelData.ssid ? "Joining…"
                        : net.modelData.active ? "Connected" : net.modelData.saved ? "Saved" : net.modelData.secure ? "Secured" : "Open network"
                    highlight: net.modelData.active
                    active: !net.modelData.active
                    hoverColor: Theme.alpha(Theme.text, 0.06)
                    onClicked: page.join(net.modelData)
                    Icon { visible: net.modelData.secure; name: "lock"; size: 14; stroke: 2; color: Theme.textDim }
                    Txt { text: net.modelData.signal + "%"; font.pixelSize: 12; color: Theme.textDim; Layout.preferredWidth: 36; horizontalAlignment: Text.AlignRight }
                    Icon {
                        name: "wifi"
                        size: 18
                        color: Theme.alpha(Theme.text, net.modelData.signal > 66 ? 1 : net.modelData.signal > 33 ? 0.65 : 0.35)
                    }
                }
                RowLayout { // password for a new secured network
                    visible: net.open
                    Layout.fillWidth: true
                    Layout.leftMargin: 12
                    Layout.rightMargin: 10
                    Layout.bottomMargin: 6
                    spacing: 8
                    SetField {
                        id: pw
                        Layout.fillWidth: true
                        placeholderText: "Password for " + net.modelData.ssid
                        echoMode: TextInput.Password
                        onVisibleChanged: if (visible) { text = ""; forceActiveFocus() }
                        onAccepted: if (text) page.joinWith(net.modelData.ssid, text)
                    }
                    SetButton { text: "Join"; accent: true; active: pw.text.length > 0 && page.joining === ""; onClicked: page.joinWith(net.modelData.ssid, pw.text) }
                    SetButton { text: "Cancel"; onClicked: page.asking = "" }
                }
                Txt {
                    visible: net.open && page.error !== ""
                    Layout.leftMargin: 14
                    Layout.bottomMargin: 6
                    text: page.error
                    color: Theme.danger
                    font.pixelSize: 12
                }
            }
        }
    }

    SetCard {
        visible: Net.saved.length > 0
        title: "Saved networks"
        Repeater {
            model: Net.saved
            SetRow {
                id: sv
                required property string modelData
                label: modelData
                sub: Net.ssid === modelData ? "Connected" : Net.networks.some(n => n.ssid === sv.modelData) ? "In range" : "Not in range"
                SetButton {
                    text: page.forgetting === sv.modelData ? "Click again to forget" : "Forget"
                    danger: true
                    onClicked: page.forget(sv.modelData)
                }
            }
        }
    }

    // ---- Surfshark ----
    SetCard {
        title: "Surfshark VPN"
        SetRow {
            icon: "shield"
            label: "VPN"
            sub: Vpn.vpnBusy ? "Switching…" : Vpn.vpnStatus
            toggle: Vpn.current !== null
            on: Vpn.vpnOn
            onSwitched: Vpn.toggleVpn()
            SetButton { visible: Vpn.current === null; text: "Open Surfshark"; onClicked: Quickshell.execDetached(["flatpak", "run", "com.surfshark.Surfshark"]) }
        }
        Txt {
            visible: Vpn.vpns.length > 0
            Layout.leftMargin: 12
            Layout.topMargin: 6
            text: "Location" + (Vpn.vpnOn ? " (switches over straight away)" : "")
            font.pixelSize: 12
            color: Theme.textDim
        }
        Flow {
            visible: Vpn.vpns.length > 0
            Layout.fillWidth: true
            Layout.margins: 8
            spacing: 6
            Repeater {
                model: Vpn.vpns
                Clicky {
                    id: loc
                    required property var modelData
                    readonly property bool on: Vpn.current?.name === modelData.name
                    implicitWidth: locText.implicitWidth + 28
                    implicitHeight: 34
                    radius: 17
                    base: on ? Theme.accent : Theme.bgHigh
                    onClicked: Vpn.choose(modelData.name)
                    Txt { id: locText; anchors.centerIn: parent; text: loc.modelData.label + (loc.modelData.active ? "  ●" : ""); font.pixelSize: 12; font.weight: Font.DemiBold; color: loc.on ? Theme.textOnAccent : Theme.text }
                }
            }
        }
    }

    // ---- Tailscale ----
    SetCard {
        title: "Tailscale"
        trailing: Txt { visible: Vpn.tsOn; text: Vpn.peersOnline + " of " + Vpn.peers.length + " online"; font.pixelSize: 12; color: Theme.textDim }
        SetRow {
            icon: "tailscale"
            label: "Tailscale"
            sub: Vpn.tsBusy ? "Switching…" : Vpn.tsStatus
            toggle: Vpn.tsState !== ""
            on: Vpn.tsOn
            onSwitched: Vpn.toggleTailscale()
        }
        Repeater {
            model: Vpn.tsOn ? Vpn.peers : []
            SetRow {
                id: peer
                required property var modelData
                label: modelData.name
                sub: modelData.online ? (modelData.direct ? "Online · direct" : "Online · relayed") : "Offline" + (modelData.seen ? " · seen " + modelData.seen : "")
                Rectangle { width: 9; height: 9; radius: 4.5; color: peer.modelData.online ? Theme.accent : Theme.outline }
            }
        }
    }
}
