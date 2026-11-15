// Tailscale and Surfshark for the Connections card on the desktop (called Vpn: "Connections"
// is taken by QtQuick).
//
// Tailscale: `tailscale status --json` every 10 s. The switch runs `tailscale up` / `down`;
// that works without a password because the system makes you Tailscale's operator
// (services.tailscale.extraSetFlags in modules/common.nix). Not logged in yet: the switch
// starts `tailscale login` and opens the sign-in page in the browser.
//
// Surfshark: its app has no command line, so the switch brings a NetworkManager WireGuard
// connection up or down, one per location ("surfshark-<location>"); the card lets you pick the
// location. Import them once with scripts/surfshark-import (see the instructions in it).
// The keys stay in NetworkManager, never in this repo.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // ---- Tailscale ----
    property string tsState: ""      // Running, Stopped, NeedsLogin, ... ("" = not installed / not running)
    property var peers: []           // [{ name, online, direct, seen }]
    readonly property bool tsOn: tsState === "Running"
    readonly property int peersOnline: peers.filter(p => p.online).length
    readonly property string tsStatus: tsOn ? "On · " + peersOnline + "/" + peers.length + " online"
        : tsState === "NeedsLogin" ? "Sign in" : tsState === "" ? "Not running" : "Off"
    property bool tsBusy: false

    function toggleTailscale() {
        if (tsBusy) return;
        tsBusy = true;
        if (tsState === "NeedsLogin") login.running = true;
        else {
            tsCmd.command = ["tailscale", tsState === "Running" ? "down" : "up"];
            tsCmd.running = true;
        }
    }

    function ago(iso) {
        const t = Date.parse(iso);
        if (!t || t < 0) return "";
        const m = Math.round((Date.now() - t) / 60000);
        return m < 60 ? m + " min ago" : m < 2880 ? Math.round(m / 60) + " h ago" : Math.round(m / 1440) + " d ago";
    }

    Process {
        id: tsStatusProc
        command: ["tailscale", "status", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(text);
                    root.tsState = j.BackendState ?? "";
                    root.peers = Object.values(j.Peer ?? {}).map(p => ({
                        name: (p.HostName || p.DNSName.split(".")[0]).toLowerCase(),
                        online: p.Online === true,
                        direct: (p.CurAddr ?? "") !== "",
                        seen: root.ago(p.LastSeen)
                    })).sort((a, b) => (b.online - a.online) || a.name.localeCompare(b.name));
                } catch (e) { root.tsState = ""; root.peers = [] }
            }
        }
    }
    Process {
        id: tsCmd
        stderr: StdioCollector {
            onStreamFinished: if (text.includes("denied") || text.includes("operator"))
                Quickshell.execDetached(["notify-send", "-a", "Tailscale", "Tailscale",
                    "Not allowed to switch it. Run once: sudo tailscale set --operator=$USER"])
        }
        onExited: { root.tsBusy = false; tsStatusProc.running = true }
    }
    // `tailscale login` prints the sign-in link; open it in the browser
    Process {
        id: login
        command: ["tailscale", "login"]
        stderr: SplitParser {
            onRead: line => {
                const m = line.match(/https:\/\/login\.tailscale\.com\/\S+/);
                if (m) Quickshell.execDetached(["xdg-open", m[0]]);
            }
        }
        onExited: { root.tsBusy = false; tsStatusProc.running = true }
    }

    // ---- Surfshark (WireGuard in NetworkManager) ----
    // One connection per location, named "surfshark-<location>" by scripts/surfshark-import.
    property var vpns: []            // [{ name, label, active }]
    property string chosen: ""       // the location the switch turns on (remembered across restarts)
    readonly property var activeVpn: vpns.find(v => v.active) ?? null
    readonly property bool vpnOn: activeVpn !== null
    readonly property var current: activeVpn ?? vpns.find(v => v.name === chosen) ?? vpns[0] ?? null
    readonly property string vpnName: current?.name ?? ""
    readonly property string vpnStatus: !current ? "Not set up" : (vpnOn ? "On · " : "Off · ") + current.label
    property bool vpnBusy: false

    // "surfshark-uk-lon" → "UK · lon"
    function labelOf(name) {
        const loc = name.slice(Settings.vpnPrefix.length).replace(/^[-_ ]+/, "");
        const parts = loc.split("-");
        return parts.length > 1 ? parts[0].toUpperCase() + " · " + parts.slice(1).join(" ") : loc;
    }

    function toggleVpn() {
        if (!current) { // nothing to switch: open the app instead
            Quickshell.execDetached(["flatpak", "run", "com.surfshark.Surfshark"]);
            return;
        }
        vpnBusy = true;
        Quickshell.execDetached(["nmcli", "connection", vpnOn ? "down" : "up", current.name]);
        settle.restart();
    }
    // Pick a location: if the VPN is on, move over to it straight away
    function choose(name) {
        chosen = name;
        saved.chosen = name;
        stateFile.writeAdapter();
        if (vpnOn && activeVpn.name !== name) {
            vpnBusy = true;
            Quickshell.execDetached(["sh", "-c", "nmcli connection down \"$1\"; nmcli connection up \"$2\"", "sh", activeVpn.name, name]);
            settle.restart();
        }
    }

    FileView {
        id: stateFile
        path: Quickshell.statePath("vpn.json")
        printErrors: false
        adapter: JsonAdapter { id: saved; property string chosen: "" }
        onLoaded: root.chosen = saved.chosen
    }

    Process {
        id: vpnProc
        command: ["nmcli", "-t", "-f", "NAME,TYPE,ACTIVE", "connection", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                const wg = text.split("\n").map(l => l.replace(/\\:/g, "\x1f").split(":"))
                    .filter(f => f[1] === "wireguard")
                    .map(f => ({ name: f[0].replace(/\x1f/g, ":"), active: f[2] === "yes" }));
                // Surfshark's own connections if there are any, else any WireGuard ones
                const ss = wg.filter(c => c.name.toLowerCase().startsWith(Settings.vpnPrefix.toLowerCase())); // settings.nix desktop.vpnPrefix
                root.vpns = (ss.length ? ss : wg).map(c => ({ name: c.name, active: c.active, label: root.labelOf(c.name) }))
                    .sort((x, y) => x.label.localeCompare(y.label));
                root.vpnBusy = false;
            }
        }
    }

    function refresh() { tsStatusProc.running = true; vpnProc.running = true }
    Timer { interval: 10000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.refresh() }
    Timer { id: settle; interval: 2500; onTriggered: root.refresh() }
}
