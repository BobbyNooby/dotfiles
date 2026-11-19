// How often the shell checks things, by power mode (power-profiles-daemon):
//   Saver        3x slower   (CPU every 9 s, Wi-Fi signal every 90 s, ...)
//   Balanced     as written
//   Performance  2x faster   (CPU every 1.5 s, ...)
// While the screen is locked everything is 3x slower on top of that.
// Timers use `interval: Pace.ms(3000)`. Things where faster is pointless (weather, mail) use
// Pace.slow(), which only ever slows down.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.UPower

Singleton {
    readonly property bool saver: PowerProfiles.profile === PowerProfile.PowerSaver
    readonly property bool performance: PowerProfiles.profile === PowerProfile.Performance
    property bool locked: false // set by LockScreen.qml: nobody is reading the numbers, so 3x slower again
    readonly property real factor: (saver ? 3 : performance ? 0.5 : 1) * (locked ? 3 : 1)
    function ms(base) { return Math.round(base * factor) }
    function slow(base) { return Math.round(base * Math.max(1, factor)) }
}
