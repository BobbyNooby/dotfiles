// One notification: the app's icon in a tile, "App · 2 min", title, text and a close button.
// Popups (popup: true) also get action buttons: the app's first action and "Mark read".
// Used by the popups and by the notification list.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications

Rectangle {
    id: card
    required property var notif
    property bool popup: false        // popups time out; cards in the list don't
    signal hide()                     // popup timed out or was closed

    readonly property bool critical: notif?.urgency === NotificationUrgency.Critical
    readonly property var actions: (notif?.actions ?? []).filter(a => a.identifier !== "default")
    // The app's icon (apps send an icon-theme name or a file path); a picture
    // (someone's avatar, an album cover) replaces it
    readonly property string image: notif?.image ?? ""
    readonly property string icon: {
        const a = notif?.appIcon ?? "";
        if (!a) return Quickshell.iconPath((notif?.appName ?? "").toLowerCase(), true);
        if (a.startsWith("/")) return "file://" + a;
        if (a.includes("://")) return a;
        return Quickshell.iconPath(a, true);
    }

    implicitWidth: popup ? 340 : 348
    implicitHeight: body.implicitHeight + (popup ? 26 : 24)
    radius: Theme.r(popup ? 22 : 18)
    color: popup ? Theme.bgMid : Theme.bgMid
    border.color: critical ? Theme.danger : "transparent"
    border.width: critical ? 2 : 0

    // Popups disappear after the app's timeout (else Notifs.popupSeconds, 6 s by default);
    // hovering keeps them up.
    // Critical ones (e.g. battery) stay until you close them.
    Timer {
        running: card.popup && !card.critical && !hover.hovered
        interval: (card.notif?.expireTimeout ?? 0) > 0 ? card.notif.expireTimeout * 1000 : Notifs.popupSeconds * 1000
        onTriggered: card.hide()
    }
    HoverHandler { id: hover }

    // Click the card = the app's default action (usually "open"), then hide it.
    // (Declared before the content, so the buttons sit on top of it.)
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            const def = (card.notif?.actions ?? []).find(a => a.identifier === "default");
            if (def) def.invoke();
            if (card.popup) card.hide();
            else card.notif?.dismiss();
        }
    }

    ColumnLayout {
        id: body
        anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: card.popup ? 14 : 12; rightMargin: card.popup ? 12 : 8; topMargin: card.popup ? 14 : 12 }
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            // App tile
            Item { // the bell sits outside the clip: ClippingRectangle darkens what it draws
                Layout.alignment: Qt.AlignTop
                implicitWidth: tile.implicitWidth
                implicitHeight: tile.implicitHeight
                ClippingRectangle {
                    id: tile
                    readonly property int s: card.popup ? 36 : 32
                    implicitWidth: s
                    implicitHeight: s
                    radius: card.popup ? 12 : 10
                    color: Theme.accentSoft
                    Image {
                        visible: card.image !== ""
                        anchors.fill: parent
                        source: card.image
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }
                    IconImage {
                        id: appIcon
                        visible: card.image === "" && card.icon !== "" && status === Image.Ready
                        anchors.centerIn: parent
                        source: card.image === "" ? card.icon : ""
                        implicitSize: tile.s - 14
                    }
                }
                    Icon { // no picture and no app icon found: a bell
                        visible: card.image === "" && !appIcon.visible
                        anchors.centerIn: tile
                        name: "bell"
                        size: tile.s / 2
                        stroke: 2
                        color: Theme.textOnSoft
                    }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Txt {
                    Layout.fillWidth: true
                    text: (card.notif?.appName || "Notification") + " · " + (card.popup ? "now" : Notifs.ago(card.notif))
                    font.pixelSize: 12
                    color: Theme.textDim
                    elide: Text.ElideRight
                }
                Txt {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: card.notif?.summary ?? ""
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }
                Txt {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: card.notif?.body ?? ""
                    textFormat: Text.StyledText // apps may send <b>, <i>, links
                    font.pixelSize: 13
                    lineHeight: 1.15
                    color: Theme.textDim
                    wrapMode: Text.Wrap
                    maximumLineCount: card.popup ? 4 : 6
                    elide: Text.ElideRight
                }
            }

            Clicky {
                Layout.alignment: Qt.AlignTop
                implicitWidth: 32
                implicitHeight: 32
                onClicked: card.popup ? card.hide() : card.notif?.dismiss()
                Icon { anchors.centerIn: parent; name: "close"; size: card.popup ? 15 : 14; stroke: 2.2; color: Theme.textDim }
            }
        }

        // Popups: the app's first action (Reply, Open...) and Mark read (removes it everywhere)
        RowLayout {
            visible: card.popup
            Layout.leftMargin: 48
            Layout.bottomMargin: 0
            spacing: 8
            Clicky {
                visible: card.actions.length > 0
                implicitWidth: actText.implicitWidth + 28
                implicitHeight: 36
                radius: Theme.r(12)
                base: Theme.accent
                onClicked: { card.actions[0]?.invoke(); card.hide() }
                Txt { id: actText; anchors.centerIn: parent; text: card.actions[0]?.text ?? ""; font.weight: Font.DemiBold; color: Theme.textOnAccent }
            }
            Clicky {
                implicitWidth: readText.implicitWidth + 28
                implicitHeight: 36
                radius: Theme.r(12)
                border.color: Theme.border
                border.width: 1
                onClicked: card.notif?.dismiss()
                Txt { id: readText; anchors.centerIn: parent; text: "Mark read"; font.weight: Font.DemiBold }
            }
        }
    }
}
