// Account popup: click your picture at the left end of the bar.
// Your picture and name, change picture / wallpaper / settings, and lock, sleep, sign out,
// restart, shut down. Restart and shut down ask for a second click first.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets

Dropdown {
    id: win
    name: "account"
    panelWidth: 300
    spacing: 10

    readonly property string user: Quickshell.env("USER")
    property string host: ""
    property string confirm: "" // "reboot" or "poweroff" after the first click
    onShownChanged: confirm = ""
    // The machine's name as configured (/etc/hostname): right after a rename, before the reboot
    // that makes it the live hostname
    FileView { path: "/etc/hostname"; watchChanges: true; onFileChanged: reload(); printErrors: false; onLoaded: win.host = text().trim() }

    function run(cmd) { Popups.close(); Quickshell.execDetached(["sh", "-c", cmd]) }

    // ---- who ----
    RowLayout {
        Layout.fillWidth: true
        spacing: 14
        Avatar { size: 56 }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Txt { heading: true; text: win.user; font.pixelSize: 20 }
            Txt { text: (win.host ? win.host + " · " : "") + Stats.uptimeText; font.pixelSize: 12; color: Theme.textDim }
        }
    }

    // ---- change things ----
    component Row: Clicky {
        id: row
        property string icon
        property string label
        property bool danger: false
        Layout.fillWidth: true
        implicitHeight: 44
        radius: Theme.r(14)
        RowLayout {
            anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
            spacing: 12
            Icon { name: row.icon; size: 18; color: row.danger ? Theme.danger : Theme.textDim }
            Txt { Layout.fillWidth: true; text: row.label; font.pixelSize: 14; color: row.danger ? Theme.danger : Theme.text }
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 2
        Row { icon: "user"; label: "Change picture"; onClicked: win.run("qs ipc call avatarpicker open") }
        Row { icon: "image"; label: "Change wallpaper"; onClicked: win.run("qs ipc call wallpicker open") }
        Row { icon: "gear"; label: "Settings"; onClicked: { Popups.close(); Controls.toggle() } }
    }
    Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.alpha(Theme.textDim, 0.1) }

    // ---- session ----
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 2
        Row { icon: "lock"; label: "Lock"; onClicked: win.run("loginctl lock-session") }
        Row { icon: "moon"; label: "Sleep"; onClicked: win.run("systemctl suspend") } // hypridle locks first
        Row { icon: "logout"; label: "Sign out"; onClicked: win.run("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'") }
        Row {
            icon: "restart"
            label: win.confirm === "reboot" ? "Click again to restart" : "Restart"
            danger: win.confirm === "reboot"
            onClicked: win.confirm === "reboot" ? win.run("systemctl reboot") : win.confirm = "reboot"
        }
        Row {
            icon: "power"
            label: win.confirm === "poweroff" ? "Click again to shut down" : "Shut down"
            danger: win.confirm === "poweroff"
            onClicked: win.confirm === "poweroff" ? win.run("systemctl poweroff") : win.confirm = "poweroff"
        }
    }
}
