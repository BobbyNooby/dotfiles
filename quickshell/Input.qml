// Typing language (fcitx5 input methods, set up in modules/input-method.nix from settings.nix
// `input.methods`). The bar's indicator and the Settings window read it.
//   current   fcitx5's name for the active method ("keyboard-us", "mozc", "pinyin", "rime")
//   methods   every method, in order (from fcitx5's profile)
//   next()    switch to the next one (Ctrl+Space and clicking the indicator)
//
//   qs ipc call input next        what Ctrl+Space runs
//   qs ipc call input set mozc
//
// Without fcitx5 (before the rebuild that installs it), it stays on English.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property string current: "keyboard-us"
    property var methods: ["keyboard-us"]
    property bool available: false

    // Short label for the bar, and a full name for menus
    function label(name) {
        return ({ "keyboard-us": "EN", mozc: "あ", pinyin: "拼", rime: "粵" })[name]
            ?? name.replace(/^keyboard-/, "").slice(0, 2).toUpperCase();
    }
    function title(name) {
        return ({ "keyboard-us": "English (US)", mozc: "Japanese (Mozc)", pinyin: "Mandarin (Pinyin)", rime: "Cantonese (Jyutping)" })[name] ?? name;
    }

    function set(name) {
        if (!available) return;
        current = name;
        Quickshell.execDetached(["fcitx5-remote", "-s", name]);
    }
    function next() {
        const i = methods.indexOf(current);
        set(methods[(i + 1) % methods.length]);
    }

    // The method list: your own profile if fcitx5 has saved one, else the system's
    function readProfile(text) {
        // (a RegExp loop: this JavaScript has no String.matchAll)
        const re = /^\[Groups\/0\/Items\/\d+\][^\[]*?^Name=(.+)$/gm;
        const names = [];
        let m;
        while ((m = re.exec(text)) !== null) names.push(m[1].trim());
        if (names.length) methods = names;
    }
    FileView {
        id: userProfile
        path: Quickshell.env("HOME") + "/.config/fcitx5/profile"
        printErrors: false
        onLoaded: root.readProfile(text())
        onLoadFailed: sysProfile.reload()
    }
    FileView {
        id: sysProfile
        path: "/etc/xdg/fcitx5/profile"
        printErrors: false
        onLoaded: root.readProfile(text())
    }

    // (Lives here, not in a window: the bar reads Input as soon as it loads, so it exists.)
    IpcHandler {
        target: "input"
        function next(): void { root.next() }
        function set(name: string): void { root.set(name) }
        function current(): string { return root.current }
    }

    // fcitx5 can also switch on its own (its own keys, a new window): check every 5 s (our own
    // switches show at once: set() updates `current` itself)
    Process {
        id: poll
        // (through sh, so a missing fcitx5 before the rebuild is quiet instead of a warning every 5 s)
        command: ["sh", "-c", "command -v fcitx5-remote >/dev/null && fcitx5-remote -n"]
        stdout: StdioCollector {
            onStreamFinished: {
                const n = text.trim();
                root.available = n.length > 0;
                if (n) root.current = n;
            }
        }
    }
    Timer { interval: Pace.ms(5000); running: root.methods.length !== 1; repeat: true; triggeredOnStart: true; onTriggered: poll.running = true }
}
