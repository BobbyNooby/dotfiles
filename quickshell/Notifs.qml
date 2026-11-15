// The notification daemon (replaces mako). Apps send notifications here; the popups
// (NotificationPopups.qml), the bell in the bar and the list (NotificationCenter.qml) read from it.
//
// From a terminal or a keybind:
//   qs ipc call notifs toggleDnd       do not disturb on/off
//   qs ipc call notifs toggleCenter    open/close the list
//   qs ipc call notifs clear           dismiss everything
//   qs ipc call notifs list            what's in the list
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

Singleton {
    id: root

    property bool dnd: false          // do not disturb: no popups (they still land in the list)
    readonly property bool centerOpen: Popups.open === "notifs"
    property var popups: []           // notifications currently shown as popups

    readonly property var all: server.trackedNotifications.values
    readonly property int count: all.length
    // The bell's badge: notifications that arrived since you last opened the list
    property int unread: 0
    onCenterOpenChanged: unread = 0

    // When each notification arrived (id → ms), for "2 min" in the list
    property var times: ({})
    property int tick: 0 // bumps every minute so those times redraw
    Timer { interval: 60000; running: true; repeat: true; onTriggered: root.tick++ }
    function ago(n) {
        tick;
        const t = times[n?.id];
        if (!t) return "now";
        const m = Math.floor((Date.now() - t) / 60000);
        return m < 1 ? "now" : m < 60 ? m + " min" : m < 1440 ? Math.floor(m / 60) + " h" : Math.floor(m / 1440) + " d";
    }

    function dismissPopup(n) { popups = popups.filter(p => p !== n) }
    function clear() {
        for (const n of all.slice()) n.dismiss();
        popups = [];
        unread = 0;
    }
    function toggleCenter() { Popups.toggle("notifs") }

    NotificationServer {
        id: server
        keepOnReload: true        // saving a .qml file doesn't drop your notifications
        actionsSupported: true    // "Reply", "Open" etc. buttons
        imageSupported: true
        bodyMarkupSupported: true
        persistenceSupported: true

        onNotification: n => {
            n.tracked = true; // keep it in the list until dismissed
            root.times[n.id] = Date.now();
            if (!root.centerOpen) root.unread++;
            n.closed.connect(() => root.dismissPopup(n)); // closed by the app or dismissed
            if (!root.dnd || n.urgency === NotificationUrgency.Critical)
                root.popups = [...root.popups, n];
        }
    }

    IpcHandler {
        target: "notifs"
        function toggleDnd(): void { root.dnd = !root.dnd }
        function toggleCenter(): void { root.toggleCenter() }
        function clear(): void { root.clear() }
        // what's in the list, one per line: "app | title" (for checking from a terminal)
        function list(): string { return root.all.map(n => n.appName + " | " + n.summary).join("\n") }
    }
}
