// Settings → Keyboard & language: the typing languages (fcitx5 input methods, through
// Input.qml) with the one in use, click to switch; Ctrl+Space cycles. Below: the keyboard
// layout and the system language / formats, which are set in Nix (read-only here).
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

SetPage {
    id: page
    title: "Keyboard & language"
    subtitle: Input.available ? "Typing in " + Input.title(Input.current) + " · Ctrl+Space switches" : "Typing languages arrive with the next rebuild"

    // ---- typing languages ----
    SetCard {
        title: "Typing languages"
        trailing: Txt { text: "Ctrl+Space: next"; font.pixelSize: 12; color: Theme.outline }
        Repeater {
            model: Input.methods
            SetRow {
                id: im
                required property string modelData
                label: Input.title(modelData)
                sub: modelData + (Input.current === modelData && Input.available ? " · in use" : "")
                highlight: Input.available && Input.current === modelData
                active: Input.available && Input.current !== modelData
                hoverColor: Theme.alpha(Theme.text, 0.06)
                onClicked: Input.set(modelData)
                Rectangle {
                    implicitWidth: 34
                    implicitHeight: 26
                    radius: Theme.r(8)
                    color: im.highlight ? Theme.alpha(Theme.textOnSoft, 0.15) : Theme.bgHigh
                    Txt { anchors.centerIn: parent; text: Input.label(im.modelData); font.pixelSize: 13; font.weight: Font.DemiBold; color: im.ink }
                }
            }
        }
        // fcitx5 isn't installed / running yet (modules/input-method.nix arrives with a rebuild)
        RowLayout {
            visible: !Input.available
            Layout.fillWidth: true
            Layout.margins: 12
            spacing: 10
            Icon { name: "info"; size: 16; color: Theme.accent }
            Txt {
                Layout.fillWidth: true
                text: "Available after rebuild: Japanese (Mozc), Mandarin (Pinyin) and Cantonese (Jyutping) come with fcitx5 once the system is rebuilt and you log in again."
                wrapMode: Text.Wrap
                font.pixelSize: 12
                color: Theme.textDim
            }
        }
        Txt {
            Layout.fillWidth: true
            Layout.margins: 12
            text: "Which languages: settings.nix → input.methods (mozc, pinyin, jyutping). English is always first."
            wrapMode: Text.Wrap
            font.pixelSize: 12
            color: Theme.outline
        }
    }

    // ---- layout and locale (from Nix) ----
    property string kbLayout: ""
    property var locale: ({})
    Process {
        running: true
        command: ["sh", "-c", "hyprctl getoption input:kb_layout 2>/dev/null | sed -n 's/^str: //p'; echo @@; locale"]
        stdout: StdioCollector {
            onStreamFinished: {
                const [kb, loc] = text.split("@@\n");
                page.kbLayout = (kb ?? "").trim();
                const l = {};
                for (const line of (loc ?? "").split("\n")) {
                    const m = line.match(/^(\w+)="?([^"]*)"?$/);
                    if (m) l[m[1]] = m[2];
                }
                page.locale = l;
            }
        }
    }
    function pretty(v) {
        return ({ "en_GB.UTF-8": "English (UK)", "en_US.UTF-8": "English (US)", "C.UTF-8": "Plain (C)" })[v] ?? v ?? "";
    }

    SetCard {
        title: "Keyboard and formats"
        SetRow { icon: "keyboard"; label: "Keyboard layout"; sub: (page.kbLayout || "us").toUpperCase() + " · hypr/hyprland.lua (input.kb_layout)" }
        SetRow { icon: "web"; label: "System language"; sub: page.pretty(page.locale.LANG) + (page.locale.LANG ? " · " + page.locale.LANG : "") }
        SetRow { icon: "clock"; label: "Dates, times and numbers"; sub: page.pretty(page.locale.LC_TIME) + " · 24-hour clock, day before month" }
        Txt {
            Layout.fillWidth: true
            Layout.margins: 12
            text: "Language and formats are set in Nix (i18n.defaultLocale), not here: change them in the repo and rebuild."
            wrapMode: Text.Wrap
            font.pixelSize: 12
            color: Theme.outline
        }
    }
}
