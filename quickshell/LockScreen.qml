// The lock screen: the Eva 7 "Signal board" (EvaBoard.qml) on every screen, unlocked with your
// password through PAM (the same "hyprlock" PAM service hyprlock uses).
//   qs ipc call lock lock      lock now (hypridle and the lock key run this)
//   qs ipc call lock status    "locked" or "unlocked"
// Safety: Hyprland is set to allow_session_lock_restore, so if this ever crashes while
// locked, another locker can take over. Recovery from a text console (Ctrl+Alt+F3, log in):
//   hyprctl --instance 0 dispatch 'hl.dsp.exec_cmd("hyprlock")'
// then go back to the desktop with Ctrl+Alt+F2 and unlock in hyprlock.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam

Scope {
    id: root

    property string phase: "idle"   // idle | verify | granted | denied
    property string message: ""     // what PAM says (e.g. "Account locked"), if anything
    property string pending: ""     // the password, kept only until PAM asks for it
    property bool caps: false

    // `locked` is what we asked for; `secure` is the compositor confirming the screen is covered.
    // If a lock was refused (e.g. hyprlock already held the screen), `locked` stays true while
    // nothing shows: after 3 s unconfirmed, drop it and ask again.
    property real askedAt: 0
    function lock() {
        if (session.locked && (session.secure || Date.now() - askedAt < 3000)) return;
        if (session.locked) session.locked = false;
        reset();
        askedAt = Date.now();
        session.locked = true;
    }
    function reset() { phase = "idle"; message = ""; pending = "" }

    function submit(password) {
        if (phase === "verify" || phase === "granted" || password === "") return;
        pending = password;
        phase = "verify";
        message = "";
        if (!pam.start()) fail("PAM couldn't start");
    }
    function fail(why) {
        pending = "";
        phase = "denied";
        message = why;
        backToIdle.restart();
    }

    PamContext {
        id: pam
        config: "hyprlock" // /etc/pam.d/hyprlock (programs.hyprlock in modules/desktop.nix)
        onResponseRequiredChanged: {
            if (!responseRequired) return;
            respond(root.pending); // PAM asks for the password: hand it over once
            root.pending = "";
        }
        onPamMessage: { if (messageIsError) root.message = message }
        onCompleted: result => {
            if (result === PamResult.Success) {
                root.phase = "granted";
                unlockSoon.restart(); // show ACCESS GRANTED for a moment
            } else {
                root.fail(result === PamResult.MaxTries ? "Too many tries" : "");
            }
        }
        onError: error => root.fail("PAM error")
    }
    Timer { id: unlockSoon; interval: 700; onTriggered: { session.locked = false; root.reset() } }
    Timer { id: backToIdle; interval: 2200; onTriggered: if (root.phase === "denied") { root.phase = "idle"; root.message = "" } }

    // Caps Lock: read the keyboard's light (Qt can't tell a locked screen)
    Process {
        id: capsRead
        command: ["sh", "-c", "cat /sys/class/leds/*::capslock/brightness 2>/dev/null | sort -rn | head -1"]
        stdout: StdioCollector { onStreamFinished: root.caps = text.trim() !== "" && text.trim() !== "0" }
    }
    Timer { interval: 400; repeat: true; running: session.locked; onTriggered: capsRead.running = true }

    WlSessionLock {
        id: session
        WlSessionLockSurface {
            id: surface
            color: EvaStyle.bg
            EvaBoard {
                id: eva
                anchors.centerIn: parent
                scale: Math.min(parent.width / width, parent.height / height) // the 1600×900 design, fitted
                phase: root.phase
                message: root.message
                caps: root.caps
                onSubmit: password => root.submit(password)
                Component.onCompleted: focusInput()
                // the surface only gets the keyboard once it's on screen: take focus then too
                Timer { running: surface.visible; interval: 120; onTriggered: eva.focusInput() }
                Connections {
                    target: root
                    function onPhaseChanged() {
                        if (root.phase === "denied") eva.clearInput();
                        if (root.phase === "idle") eva.focusInput();
                    }
                }
            }
        }
    }

    IpcHandler {
        target: "lock"
        function lock(): void { root.lock() }
        // "locked" only once the compositor confirms it (scripts/lock relies on this)
        function status(): string { return session.secure ? "locked" : session.locked ? "pending" : "unlocked" }
    }
}
