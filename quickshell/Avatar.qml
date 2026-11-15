// Your account picture (~/.face), round; your initial on the accent colour if there's none.
// A new picture from "Change picture" shows at once (the picker tells the shell over IPC).
import QtQuick
import Quickshell
import Quickshell.Widgets

Item {
    id: av
    property int size: 32
    implicitWidth: size
    implicitHeight: size
    readonly property string url: "file://" + Quickshell.env("HOME") + "/.face"

    // A new picture (scripts/pick-avatar bumps Popups.faceVersion): load it again
    Connections {
        target: Popups
        function onFaceVersionChanged() { pic.source = ""; pic.source = av.url }
    }

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: Theme.accentSoft
        visible: pic.status !== Image.Ready
        Txt {
            anchors.centerIn: parent
            heading: true
            text: (Quickshell.env("USER") || "?").charAt(0).toUpperCase()
            font.pixelSize: av.size * 0.45
            color: Theme.textOnSoft
        }
    }
    ClippingRectangle {
        anchors.fill: parent
        radius: width / 2
        color: "transparent"
        Image {
            id: pic
            anchors.fill: parent
            source: av.url
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: av.size * 2
            asynchronous: true
            cache: false
        }
    }
}
