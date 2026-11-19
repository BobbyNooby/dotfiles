// System numbers for the bar and the System card, read every 3 seconds (Pace.qml scales it):
// CPU load (/proc/stat), CPU temperature (the k10temp sensor), memory (/proc/meminfo),
// uptime (/proc/uptime) and whether the NVIDIA card is asleep. The card's power-state file
// is safe to read while it sleeps; nvidia-smi would wake it up, so it's never used here.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property real cpu: 0          // 0..1
    property int cpuTemp: 0       // °C
    property real mem: 0          // 0..1
    property real memUsedGb: 0
    property real memTotalGb: 0
    property real swapUsedGb: 0
    property real swapTotalGb: 0
    property real uptime: 0       // seconds
    property bool gpuAsleep: true
    property bool hasGpu: false

    readonly property string uptimeText: {
        const m = Math.floor(uptime / 60), d = Math.floor(m / 1440), h = Math.floor(m / 60) % 24;
        return "up " + (d ? d + " d " : "") + (d || h ? h + " h " : "") + (m % 60) + " m";
    }

    property var lastCpu: null
    property string tempPath: "" // found once: hwmon numbers change between boots

    Timer {
        interval: Pace.ms(3000) // Saver 9 s, Performance 1.5 s (Pace.qml)
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            stat.reload();
            meminfo.reload();
            uptimeFile.reload();
            if (Settings.gpu) gpu.reload(); else root.hasGpu = false;
            if (root.tempPath) temp.reload();
        }
    }

    // First line of /proc/stat: "cpu  user nice system idle iowait irq softirq ..."
    FileView {
        id: stat
        path: "/proc/stat"
        onLoaded: {
            const f = text().split("\n")[0].trim().split(/\s+/).slice(1).map(Number);
            const idle = f[3] + f[4];
            const total = f.reduce((a, b) => a + b, 0);
            if (root.lastCpu) {
                const dt = total - root.lastCpu.total;
                // whole percents: a 0.3% wobble shouldn't redraw the bar and the System card
                if (dt > 0) root.cpu = Math.round((1 - (idle - root.lastCpu.idle) / dt) * 100) / 100;
            }
            root.lastCpu = { idle, total };
        }
    }

    FileView {
        id: meminfo
        path: "/proc/meminfo"
        onLoaded: {
            const kb = key => Number((text().match(new RegExp(key + ":\\s+(\\d+)")) ?? [0, 0])[1]);
            const total = kb("MemTotal"), avail = kb("MemAvailable");
            if (total > 0) {
                root.mem = Math.round((1 - avail / total) * 100) / 100;
                root.memUsedGb = Math.round((total - avail) / 104857.6) / 10; // one decimal
                root.memTotalGb = total / 1048576;
            }
            const st = kb("SwapTotal"), sf = kb("SwapFree");
            root.swapTotalGb = st / 1048576;
            root.swapUsedGb = (st - sf) / 1048576;
        }
    }

    FileView {
        id: uptimeFile
        path: "/proc/uptime"
        onLoaded: root.uptime = Number(text().split(" ")[0]) || 0
    }

    // "suspended" = asleep (0 W); "active" = something is using it (or keeping it awake)
    FileView {
        id: gpu
        path: Settings.gpu ? "/sys/bus/pci/devices/" + Settings.gpu + "/power/runtime_status" : "" // settings.nix desktop.gpu
        printErrors: false
        onLoaded: { root.hasGpu = true; root.gpuAsleep = text().trim() === "suspended" }
        onLoadFailed: root.hasGpu = false
    }

    // Tctl of the Ryzen's k10temp sensor, in millidegrees
    FileView {
        id: temp
        path: root.tempPath
        printErrors: false
        onLoaded: root.cpuTemp = Math.round(Number(text()) / 1000)
    }
    Process {
        running: true
        command: ["sh", "-c", "for d in /sys/class/hwmon/hwmon*; do [ \"$(cat $d/name)\" = k10temp ] && echo $d/temp1_input && break; done"]
        stdout: StdioCollector { onStreamFinished: root.tempPath = text.trim() }
    }
}
