// Mounted drives for the System card: one entry per real disk or partition (the internal
// disk, plus USB sticks and external drives while they're mounted). Read with df once a minute (Pace.qml scales it).
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // [{ mount, name, usedGb, totalGb, freeGb, fraction, removable }]
    property var drives: []

    // "69 / 907 GB", or TB once a drive passes 1000 GB
    function sizeText(d) {
        const tb = d.totalGb >= 1000;
        const f = v => tb ? (v / 1000).toFixed(1) : Math.round(v);
        return f(d.usedGb) + " / " + f(d.totalGb) + (tb ? " TB" : " GB");
    }

    function parse(text) {
        const seen = {}, out = [];
        for (const line of text.trim().split("\n").slice(1)) {
            const f = line.trim().split(/\s+/);
            if (f.length < 5) continue;
            const src = f[0], size = Number(f[1]), used = Number(f[2]), avail = Number(f[3]);
            const mount = f.slice(4).join(" ");
            // one row per device; skip the boot partition and Nix's view of the same disk
            if (!src.startsWith("/dev/") || seen[src] || size <= 0) continue;
            if (mount.startsWith("/boot") || mount.startsWith("/nix")) continue;
            seen[src] = true;
            const removable = mount.startsWith("/run/media/") || mount.startsWith("/media/") || mount.startsWith("/mnt/");
            const gb = 1073741824;
            out.push({
                mount, removable,
                name: mount === "/" ? "Disk" : mount === "/home" ? "Home" : mount.split("/").pop(),
                usedGb: Math.round(used / gb), totalGb: Math.round(size / gb), freeGb: Math.round(avail / gb),
                // "used" the way df shows it: what's taken out of what a user can fill
                fraction: Math.round(used / (used + avail) * 100) / 100
            });
        }
        // only replace when something changed, so the card isn't redrawn every minute
        if (JSON.stringify(out) !== JSON.stringify(root.drives)) root.drives = out;
    }

    Process {
        id: df
        command: ["df", "-B1", "--output=source,size,used,avail,target",
                  "-x", "tmpfs", "-x", "devtmpfs", "-x", "efivarfs", "-x", "overlay", "-x", "squashfs"]
        stdout: StdioCollector { onStreamFinished: root.parse(text) }
    }
    Timer { interval: Pace.ms(60000); running: true; repeat: true; triggeredOnStart: true; onTriggered: df.running = true }
}
