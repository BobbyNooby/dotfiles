// Smooth scrolling for a Flickable / ListView: put `SmoothWheel {}` inside it.
// Qt's own wheel handling jumps a fixed step per mouse-wheel notch and stutters on touchpads.
// Here a mouse wheel glides to its target (notches in quick succession add up), and a touchpad
// moves the content by exactly the pixels your fingers moved.
import QtQuick

WheelHandler {
    id: h
    required property Flickable flick // the Flickable it scrolls (inside one, `parent` is its content item)
    property real step: 110 // pixels per wheel notch
    target: null
    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

    function clamp(y) {
        const top = flick.originY - flick.topMargin;
        const bottom = flick.originY + flick.contentHeight + flick.bottomMargin - flick.height;
        return Math.max(top, Math.min(Math.max(top, bottom), y));
    }

    property NumberAnimation glide: NumberAnimation {
        target: h.flick
        property: "contentY"
        duration: 260
        easing.type: Easing.OutCubic
    }

    onWheel: event => {
        if (event.pixelDelta.y !== 0) { // touchpad: follow the fingers
            glide.stop();
            flick.contentY = clamp(flick.contentY - event.pixelDelta.y);
        } else if (event.angleDelta.y !== 0) { // mouse wheel: glide, adding to a glide underway
            const from = glide.running ? glide.to : flick.contentY;
            glide.stop();
            glide.to = clamp(from - event.angleDelta.y / 120 * step);
            glide.start();
        }
        event.accepted = true;
    }
}
