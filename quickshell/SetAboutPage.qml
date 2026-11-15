// Settings → About: this machine and the system it runs. Read once when the page opens
// (scripts/system-info: hostname, NixOS version + generation, kernel, CPU, GPUs, disk); memory
// and uptime come live from Stats. The NVIDIA card's asleep/awake is the power-state file Stats reads; nvidia-smi
// would wake it, so it's never run.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

SetPage {
    id: page
    title: "About"
    subtitle: (info.host || "This computer") + (info.nixos ? " · NixOS " + info.nixos : "")

    property var info: ({})
    Process {
        running: true
        command: [Quickshell.shellDir + "/scripts/system-info"]
        stdout: StdioCollector {
            onStreamFinished: {
                const o = { gpus: [] };
                for (const line of text.split("\n")) {
                    const i = line.indexOf("=");
                    if (i < 0) continue;
                    const k = line.slice(0, i), v = line.slice(i + 1).trim();
                    if (k === "gpu") o.gpus.push(v.replace(/\s*\(rev [0-9a-f]+\)$/, "")); else o[k] = v;
                }
                page.info = o;
            }
        }
    }
    function copy(t) { Quickshell.execDetached(["wl-copy", "--", t]) }

    SetCard {
        title: "System"
        SetRow { icon: "window"; label: "Computer name"; sub: page.info.host ?? "…" }
        SetRow {
            icon: "sparkle"
            label: "NixOS " + (page.info.nixos ?? "…")
            sub: "Generation " + (page.info.gen ?? "?") + (page.info.gendate ? " · built " + page.info.gendate : "")
            SetButton { text: "Copy path"; onClicked: page.copy(page.info.system ?? "") }
        }
        SetRow { icon: "term"; label: "Kernel"; sub: "Linux " + (page.info.kernel ?? "…") }
        SetRow { icon: "clock"; label: "Uptime"; sub: Stats.uptimeText }
    }

    SetCard {
        title: "Hardware"
        SetRow { icon: "cpu"; label: page.info.cpu ?? "…"; sub: (page.info.cores ?? "?") + " threads · " + Math.round(Stats.cpu * 100) + "% busy" + (Stats.cpuTemp ? " · " + Stats.cpuTemp + " °C" : "") }
        Repeater {
            model: page.info.gpus ?? []
            SetRow {
                id: g
                required property string modelData
                readonly property bool nvidia: /nvidia/i.test(modelData)
                icon: "gpu"
                label: modelData
                sub: !nvidia ? "Draws the desktop"
                    : !Stats.hasGpu ? "Second GPU (nvidia-offload <app>)"
                    : Stats.gpuAsleep ? "Asleep (0 W) · nvidia-offload <app> to use it" : "Awake: something is using it"
                Rectangle {
                    visible: g.nvidia && Stats.hasGpu
                    width: 9; height: 9; radius: 4.5
                    color: Stats.gpuAsleep ? Theme.outline : Theme.accent
                }
            }
        }
        SetRow { icon: "ram"; label: "Memory"; sub: Stats.memUsedGb.toFixed(1) + " of " + Stats.memTotalGb.toFixed(1) + " GB used" + (Stats.swapTotalGb > 0 ? " · swap " + Stats.swapUsedGb.toFixed(1) + " of " + Stats.swapTotalGb.toFixed(1) + " GB" : "") }
        SetRow { icon: "folder"; label: "Disk"; sub: page.info.disk ?? "…" }
    }

    SetCard {
        title: "Configuration"
        SetRow {
            icon: "git"
            label: Settings.repo
            sub: "The whole system: hosts/, modules/, home/, dotfiles/ (linked live)"
            SetButton { text: "Open in terminal"; onClicked: Quickshell.execDetached(["wezterm", "start", "--cwd", Settings.repo]) }
        }
        SetRow {
            icon: "gear"
            label: "Your settings"
            sub: "hosts/" + (page.info.host || "<host>") + "/settings.nix · changes made here: ~/.config/desktop/overrides.json"
        }
    }
}
