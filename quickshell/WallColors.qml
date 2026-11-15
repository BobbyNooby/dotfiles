// The colours matugen would make from an image, without applying anything (`--dry-run`):
//   WallColors { image: "/path/to.jpg" }  → colors: [primary, secondary, tertiary, surface…]
// Used by the wallpaper switcher to compare "Now" and "New".
import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: pal
    property string image
    property var colors: []   // hex strings
    onImageChanged: wait.restart()
    Timer { id: wait; interval: 220; onTriggered: if (pal.image) run.running = true } // not on every scroll step

    Process {
        id: run
        command: ["matugen", "image", pal.image, "--mode", "dark", "--dry-run", "-j", "hex"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const c = JSON.parse(text).colors;
                    const get = k => c[k]?.dark?.color ?? c[k]?.default?.color ?? c[k]?.color;
                    pal.colors = ["primary", "secondary", "tertiary", "primary_container", "surface_container_high", "surface"].map(get).filter(x => x);
                } catch (e) { pal.colors = [] }
            }
        }
    }
}
