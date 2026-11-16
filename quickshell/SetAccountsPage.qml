// Settings → Accounts: your Google accounts (the calendar popup + desktop card, unread mail in
// the bar) and what Hermes is set up with. Accounts come from scripts/google through Gcal.qml;
// signing in runs `google connect NAME` in a terminal, Remove runs `google disconnect NAME`.
// Tokens live in ~/.hermes (never in git); Hermes' google-workspace skill uses the same sign-in.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

SetPage {
    id: page
    title: "Accounts"
    subtitle: "Google for the calendar and unread mail. Hermes signs in with the same accounts."

    property string confirm: ""     // account name after the first click on Remove
    property string hermesDefault: "" // the account ~/.hermes/google_token.json points at
    property var mcp: []            // `hermes mcp list`, line by line
    property bool mcpLoaded: false
    Timer { id: unconfirm; interval: 4000; onTriggered: page.confirm = "" }

    Component.onCompleted: { Gcal.refresh(); readHermes() }
    Connections { target: Gcal; function onAccountsChanged() { page.readHermes() } }
    function readHermes() { defaultProc.running = true; if (!mcpProc.running) mcpProc.running = true }

    // Which token Hermes reads by default: a link to google_token_<name>.json (only the link is read)
    Process {
        id: defaultProc
        command: ["sh", "-c", "readlink \"${HERMES_HOME:-$HOME/.hermes}/google_token.json\""]
        stdout: StdioCollector { onStreamFinished: page.hermesDefault = text.trim().replace(/^.*google_token_/, "").replace(/\.json$/, "") }
    }
    Process {
        id: mcpProc
        command: ["sh", "-c", "hermes mcp list 2>&1"]
        stdout: StdioCollector {
            onStreamFinished: {
                // drop the install warning and blank lines; keep the rest as written
                page.mcp = text.split("\n").map(l => l.replace(/\x1b\[[0-9;]*m/g, "").replace(/\s+$/, ""))
                    .filter(l => l.trim() && !/^\s*⚠|install out of sync/.test(l));
                page.mcpLoaded = true;
            }
        }
    }

    function add() {
        const n = nameField.text.replace(/[^a-zA-Z0-9_-]/g, "");
        if (!n) { nameField.forceActiveFocus(); return }
        Gcal.connect(n);
        nameField.text = "";
    }

    // ---- Google ----
    SetCard {
        title: "Google"
        trailing: [
            Txt { text: Gcal.busy ? "Checking…" : Gcal.staleText; font.pixelSize: 12; color: Theme.outline },
            SetButton { text: "Refresh"; onClicked: Gcal.refresh() }
        ]

        SetRow {
            visible: Gcal.noHermes || (Gcal.error !== "" && !Gcal.connected)
            icon: "info"
            label: Gcal.noHermes ? "Hermes isn't installed" : "Couldn't read the accounts"
            sub: Gcal.noHermes ? "Sign-in uses Hermes' google-workspace skill: install Hermes first." : Gcal.error
        }
        SetRow {
            visible: Gcal.loaded && !Gcal.connected && !Gcal.noHermes
            icon: "user"
            label: "No Google account yet"
            sub: "Add one below: give it a short name, then sign in in the browser."
        }
        SetRow {
            visible: !Gcal.loaded
            icon: "sync"
            label: "Looking for your accounts…"
        }

        Repeater {
            model: Gcal.accounts
            SetRow {
                id: acct
                required property var modelData
                readonly property var mail: Gcal.unread.find(u => u.name === modelData.name)
                icon: "user"
                label: modelData.name + (page.hermesDefault === modelData.name ? "  ·  Hermes' default" : "")
                sub: (modelData.account || "address unknown")
                    + (mail ? " · " + Gcal.count(mail.unread) + " unread" : "")
                    + (Gcal.connecting === modelData.name ? " · signing in…" : "")
                Repeater { // what it can reach
                    model: [["Calendar", acct.modelData.calendar], ["Gmail", acct.modelData.gmail]]
                    Rectangle {
                        required property var modelData
                        implicitWidth: chip.implicitWidth + 16
                        implicitHeight: 24
                        radius: 12
                        color: modelData[1] ? Theme.accentSoft : "transparent"
                        border.width: modelData[1] ? 0 : 1
                        border.color: Theme.border
                        Txt { id: chip; anchors.centerIn: parent; text: parent.modelData[0]; font.pixelSize: 11; font.weight: Font.DemiBold; color: parent.modelData[1] ? Theme.textOnSoft : Theme.outline; font.strikeout: !parent.modelData[1] }
                    }
                }
                SetButton { text: "Reconnect"; active: !Gcal.connecting; onClicked: Gcal.connect(acct.modelData.name) }
                SetButton {
                    text: page.confirm === acct.modelData.name ? "Really remove?" : "Remove"
                    danger: true
                    onClicked: {
                        if (page.confirm === acct.modelData.name) { page.confirm = ""; Gcal.disconnect(acct.modelData.name) }
                        else { page.confirm = acct.modelData.name; unconfirm.restart() }
                    }
                }
            }
        }

        // add one: a short name, then the sign-in terminal
        RowLayout {
            visible: !Gcal.noHermes
            Layout.fillWidth: true
            Layout.margins: 8
            spacing: 8
            SetField {
                id: nameField
                Layout.fillWidth: true
                placeholderText: Gcal.connected ? "Short name for another account, e.g. work" : "Short name, e.g. main"
                onAccepted: page.add()
            }
            SetButton { text: Gcal.connecting ? "Signing in…" : "Add account"; accent: true; active: !Gcal.connecting; onClicked: page.add() }
        }
        Txt {
            Layout.fillWidth: true
            Layout.leftMargin: 12
            Layout.rightMargin: 12
            Layout.bottomMargin: 8
            text: "Sign-in opens a terminal and your browser: pick the account, allow Calendar and Gmail, then paste the "
                + "page's address back into the terminal. Keys and tokens stay in ~/.hermes (never in git). "
                + "Hermes uses the same sign-in: google_token.json points at its default account (one named main, else the first connected)."
            wrapMode: Text.Wrap
            font.pixelSize: 12
            color: Theme.textDim
        }
    }

    // ---- Hermes ----
    SetCard {
        title: "Hermes"
        SetRow {
            icon: "sparkle"
            label: "Google account Hermes uses"
            sub: page.hermesDefault ? page.hermesDefault + (Gcal.emailOf(page.hermesDefault) ? " · " + Gcal.emailOf(page.hermesDefault) : "")
                : Gcal.connected ? "None set (an account named main becomes it)" : "None yet"
        }
        SetRow {
            icon: "link"
            label: "MCP servers"
            sub: !page.mcpLoaded ? "…" : page.mcp.some(l => /No MCP servers/i.test(l)) ? "None configured · add with hermes mcp add <name> --url <endpoint>" : "From hermes mcp list"
        }
        Txt { // the list as Hermes prints it
            visible: page.mcpLoaded && !page.mcp.some(l => /No MCP servers/i.test(l)) && page.mcp.length > 0
            Layout.fillWidth: true
            Layout.leftMargin: 14
            Layout.rightMargin: 14
            Layout.bottomMargin: 10
            text: page.mcp.join("\n")
            font.family: Theme.mono
            font.pixelSize: 12
            color: Theme.text
            wrapMode: Text.Wrap
        }
    }
}
