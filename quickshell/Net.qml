// Network status for the bar's Wi-Fi button and the Wi-Fi popup.
// Asks NetworkManager (nmcli) every 5 s, and right away after a change made from here.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property string ssid: ""       // Wi-Fi network you're on ("" = none)
    property bool wired: false     // an ethernet cable is connected
    property bool wifiOn: true     // the Wi-Fi radio is switched on
    property int signal: 0         // 0..100 of the network you're on
    property var networks: []      // [{ ssid, signal, secure, saved, active }], strongest first
    property var saved: []         // names of saved connections
    property bool scanning: false  // the Wi-Fi popup is open: list networks too
    readonly property bool online: ssid !== "" || wired
    readonly property string label: ssid || (wired ? "Wired" : wifiOn ? "Not connected" : "Wi-Fi off")

    function refresh() {
        devices.running = true;
        radio.running = true;
        if (!scanning) strength.running = true;
        if (scanning) { list.running = true; savedProc.running = true }
    }
    function setWifi(on) {
        wifiOn = on; // show it at once; the next refresh confirms
        Quickshell.execDetached(["nmcli", "radio", "wifi", on ? "on" : "off"]);
        settle.restart();
    }
    // Saved and open networks connect straight away; a new secured one needs its password,
    // so that goes to the rofi picker (scripts/wifi-menu), which asks for it.
    function connect(net) {
        if (net.active) return;
        if (net.saved) Quickshell.execDetached(["nmcli", "connection", "up", "id", net.ssid]);
        else if (!net.secure) Quickshell.execDetached(["nmcli", "device", "wifi", "connect", net.ssid]);
        else Quickshell.execDetached([Quickshell.shellDir + "/scripts/wifi-menu"]);
        settle.restart();
    }

    Process {
        id: devices
        command: ["nmcli", "-t", "-f", "TYPE,STATE,CONNECTION", "device"]
        stdout: StdioCollector {
            onStreamFinished: {
                let wifi = "", cable = false;
                for (const line of text.split("\n")) {
                    const [type, state, ...name] = line.split(":");
                    if (state !== "connected") continue;
                    if (type === "wifi" && !wifi) wifi = name.join(":").replace(/\\/g, "");
                    else if (type === "ethernet") cable = true;
                }
                root.ssid = wifi;
                root.wired = cable;
            }
        }
    }
    Process {
        id: radio
        command: ["nmcli", "radio", "wifi"]
        stdout: StdioCollector { onStreamFinished: root.wifiOn = text.trim() === "enabled" }
    }
    Process {
        id: list
        command: ["nmcli", "-t", "-f", "IN-USE,SIGNAL,SECURITY,SSID", "device", "wifi", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const seen = {}, out = [];
                for (const line of text.split("\n")) {
                    const f = line.replace(/\\:/g, "\x1f").split(":");
                    if (f.length < 4) continue;
                    const ssid = f.slice(3).join(":").replace(/\x1f/g, ":");
                    if (!ssid || seen[ssid]) continue;
                    seen[ssid] = true;
                    out.push({ ssid, signal: Number(f[1]) || 0, secure: f[2] !== "" && f[2] !== "--",
                               active: f[0] === "*", saved: root.saved.includes(ssid) });
                }
                out.sort((a, b) => (b.active - a.active) || (b.saved - a.saved) || (b.signal - a.signal));
                root.networks = out;
                root.signal = out.find(n => n.active)?.signal ?? root.signal;
            }
        }
    }
    Process { // signal of the network you're on (cached scan results: no new scan, cheap)
        id: strength
        command: ["nmcli", "-t", "-f", "IN-USE,SIGNAL", "device", "wifi", "list", "--rescan", "no"]
        stdout: StdioCollector {
            onStreamFinished: {
                const line = text.split("\n").find(l => l.startsWith("*:"));
                root.signal = line ? Number(line.split(":")[1]) || 0 : 0;
            }
        }
    }
    Process {
        id: savedProc
        command: ["nmcli", "-t", "-f", "NAME,TYPE", "connection", "show"]
        stdout: StdioCollector {
            onStreamFinished: root.saved = text.split("\n").filter(l => l.endsWith(":802-11-wireless"))
                .map(l => l.slice(0, -":802-11-wireless".length).replace(/\\:/g, ":"))
        }
    }

    onScanningChanged: if (scanning) refresh()
    Timer { interval: root.scanning ? 4000 : 5000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.refresh() }
    Timer { id: settle; interval: 1500; onTriggered: root.refresh() } // after a change from here
}
