// Settings → Notifications: Do not disturb, how long popups stay, and each app that has sent
// something: mute it (no popups, still listed behind the bell) or unmute it.
// All of it lives in Notifs.qml and is saved in its notifs.json (no Nix needed).
import QtQuick
import QtQuick.Layouts
import Quickshell

SetPage {
    id: page
    title: "Notifications"
    subtitle: Notifs.count + (Notifs.count === 1 ? " notification" : " notifications") + " in the list"
              + (Notifs.muted.length ? " · " + Notifs.muted.length + " muted " + (Notifs.muted.length === 1 ? "app" : "apps") : "")
    // Apps seen so far (saved), plus any in the list and any muted, A to Z
    readonly property var apps: [...new Set([...Notifs.seen, ...Notifs.groups.map(g => g.app), ...Notifs.muted])]
        .sort((a, b) => a.localeCompare(b))

    SetCard {
        SetRow {
            icon: "bell"
            label: "Do not disturb"
            sub: Notifs.dnd ? "Popups hidden; they still land in the list" : "Off"
            toggle: true
            on: Notifs.dnd
            onSwitched: Notifs.dnd = !Notifs.dnd
        }
        SetRow {
            icon: "clock"
            label: "Popups stay for"
            sub: "When the app doesn't ask for its own time; hovering keeps one up"
        }
        SetChoice {
            Layout.leftMargin: 10
            Layout.rightMargin: 10
            Layout.bottomMargin: 8
            options: [3, 6, 10, 15, 30].map(s => ({ value: s, label: s + " s" }))
            current: Notifs.popupSeconds
            onPicked: v => Notifs.popupSeconds = v
        }
    }

    SetCard {
        title: "Apps"
        trailing: Txt { text: "Switch off = no popups"; font.pixelSize: 12; color: Theme.outline }
        Txt {
            visible: page.apps.length === 0
            Layout.margins: 12
            text: "No app has sent a notification yet."
            color: Theme.textDim
        }
        Repeater {
            model: page.apps
            SetRow {
                id: app
                required property string modelData
                readonly property int listed: Notifs.groups.find(g => g.app === modelData)?.items.length ?? 0
                label: modelData
                sub: (Notifs.isMuted(modelData) ? "Muted" : "Popups on") + (listed ? " · " + listed + " in the list" : "")
                fg: Notifs.isMuted(modelData) ? Theme.textDim : Theme.text
                toggle: true
                on: !Notifs.isMuted(modelData)
                onSwitched: Notifs.toggleMute(modelData)
                SetButton { visible: app.listed > 0; text: "Clear"; onClicked: Notifs.clearApp(app.modelData) }
            }
        }
    }
}
