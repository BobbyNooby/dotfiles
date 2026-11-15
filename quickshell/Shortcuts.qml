// What the Shortcuts card and the cheat sheet (Super + /) list.
// Hyprland and terminal keys are written out here: edit these lists when you rebind something
// (hypr/hyprland.lua, and your tmux config). Your aliases are read live from
// ~/aliases/*.zsh by scripts/aliases, so new ones show up by themselves.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // [keys, what it does]; a row with only one item is a small heading
    readonly property var hyprland: [
        ["Apps"],
        ["Super + Return", "terminal (WezTerm)"],
        ["Super + Space", "launcher: apps, windows, actions, sums, files"],
        ["Super + Shift + Space", "rofi (fallback launcher)"],
        ["Super + E", "files"],
        ["Super + A", "Hermes side panel"],
        ["Super + /", "this cheat sheet"],
        ["Windows"],
        ["Super + Q", "close window"],
        ["Super + F", "fullscreen"],
        ["Super + V", "float / tile"],
        ["Super + T", "flip the split"],
        ["Super + P", "pseudo-tile"],
        ["Super + M", "minimize (Alt+Tab brings it back)"],
        ["Super + h j k l", "focus left / down / up / right"],
        ["Alt + Tab", "switch window (hold Alt, Tab to step)"],
        ["Super + drag", "move (left) / resize (right)"],
        ["Workspaces"],
        ["Super + 1…0", "go to workspace"],
        ["Super + Shift + 1…0", "move window there"],
        ["Super + S", "scratchpad (Shift: send window)"],
        ["Super + wheel", "next / previous workspace"],
        ["Desktop"],
        ["Super + N", "notifications (Shift: do not disturb)"],
        ["Super + ,", "Quick settings"],
        ["Super + I", "Settings window"],
        ["Super + W", "pick a wallpaper"],
        ["Super + Shift + V", "clipboard history"],
        ["Super + .", "emoji"],
        ["Super + C", "calculator"],
        ["Print", "screenshot a region (Shift: whole screen)"],
        ["Super + Escape", "lock"],
        ["Super + Shift + Esc", "power menu"],
        ["Super + Shift + M", "log out"],
        ["Super + Shift + B", "restart the bar"],
        ["Tray icon, middle-click", "close that app"]
    ]
    readonly property var terminal: [
        ["WezTerm"],
        ["Ctrl + Shift + T", "new tab"],
        ["Ctrl + Shift + W", "close tab"],
        ["Ctrl + Tab", "next tab"],
        ["Ctrl + Shift + C / V", "copy / paste"],
        ["Ctrl + Shift + F", "search scrollback"],
        ["Ctrl + = / -", "bigger / smaller text"],
        ["tmux (prefix Ctrl + A)"],
        ["prefix  |  /  -", "split side by side / top-bottom"],
        ["prefix  h j k l", "move between panes"],
        ["prefix  c", "new window"],
        ["prefix  1…9", "go to window"],
        ["prefix  x", "close pane"],
        ["prefix  d", "detach (tmux a to come back)"],
        ["prefix  [", "scroll / copy mode (v select, y copy)"],
        ["prefix  r", "reload tmux config"],
        ["Shell"],
        ["Ctrl + R", "search history (fzf)"],
        ["Ctrl + T", "insert a file path (fzf)"],
        ["z <dir>", "jump to a folder you've used"]
    ]
    property var aliases: [] // [name, what it does]

    function refresh() { aliasProc.running = true }
    Process {
        id: aliasProc
        command: [Quickshell.shellDir + "/scripts/aliases"]
        stdout: StdioCollector {
            onStreamFinished: root.aliases = text.split("\n").filter(l => l.includes("\t")).map(l => l.split("\t"))
        }
    }
    Timer { interval: 300000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.refresh() }
}
