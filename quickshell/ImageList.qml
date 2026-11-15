// The images in one folder, newest first (for the wallpaper and picture pickers).
//   ImageList { folder: "~/Documents/Wallpapers" }  → files: ["/home/…/a.jpg", …]
// Looks up to 3 folders deep, at most `limit` files. Call refresh() to look again.
import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: list
    property string folder
    property int limit: 600
    property var files: []
    property bool loading: false

    readonly property string path: folder.replace(/^~/, Quickshell.env("HOME"))
    function refresh() { if (path) { loading = true; finder.running = true } }
    onPathChanged: refresh()

    Process {
        id: finder
        command: ["sh", "-c", "find \"$1\" -maxdepth 3 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \\) -printf '%T@\\t%p\\n' 2>/dev/null | sort -rn | head -n \"$2\" | cut -f2-",
                  "sh", list.path, String(list.limit)]
        stdout: StdioCollector {
            onStreamFinished: { list.files = text.split("\n").filter(f => f); list.loading = false }
        }
    }
}
