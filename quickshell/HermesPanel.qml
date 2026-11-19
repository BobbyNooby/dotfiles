// Hermes side panel: Super+A (or the hint in the bottom-right corner, or `qs ipc call hermes toggle`).
// Ask about the laptop, or ask for a change. Who answers: Hermes (quick) or Claude Code (for
// config changes). It stays open until you close it (×, Esc or Super+A again). See Hermes.qml.
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: win
    anchors { top: true; right: true; bottom: true }
    margins { top: Theme.popupTop - 20 } // the panel sits inside, with room for its shadow
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "qs-hermes"
    WlrLayershell.keyboardFocus: Hermes.open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    color: "transparent"
    implicitWidth: 20 + 430 + Theme.barSide // shadow room on the left, 10 px gap on the right
    mask: Region { item: panel }
    visible: Hermes.open || panel.opacity > 0
    onVisibleChanged: if (Hermes.open) input.forceActiveFocus()

    component Chip: Clicky {
        id: chip
        property string label
        property string sub
        property bool on
        property bool filled: true // filled when on (engine) or outlined (mode)
        implicitWidth: chipCol.implicitWidth + 24
        radius: Theme.r(12)
        base: on ? (filled ? Theme.accent : Theme.accentSoft) : "transparent"
        border.color: !filled ? (on ? Theme.accentSoft : Theme.border) : "transparent"
        border.width: filled ? 0 : 1
        readonly property color fg: on ? (filled ? Theme.textOnAccent : Theme.textOnSoft) : Theme.textDim
        Column {
            id: chipCol
            anchors.centerIn: parent
            Txt { anchors.horizontalCenter: parent.horizontalCenter; text: chip.label; font.pixelSize: chip.sub ? 13 : 12; font.weight: Font.DemiBold; color: chip.fg }
            Txt { visible: chip.sub !== ""; anchors.horizontalCenter: parent.horizontalCenter; text: chip.sub; font.pixelSize: 11; color: chip.fg; opacity: 0.8 }
        }
    }

    RectangularShadow {
        anchors.fill: panel
        radius: panel.radius
        offset.y: 18
        blur: 50
        color: Qt.rgba(0, 0, 0, 0.5 * panel.opacity)
    }

    Rectangle {
        id: panel
        x: 20 + (Hermes.open ? 0 : 30)
        y: 20
        width: 430
        height: win.height - 20 - 10 // 10 px above the screen's bottom edge
        radius: Theme.r(28)
        color: Theme.alpha(Theme.bgLow, 0.97)
        opacity: Hermes.open ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        clip: true

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // ---- header ----
            RowLayout {
                Layout.fillWidth: true
                Layout.margins: 12
                Layout.leftMargin: 18
                Layout.topMargin: 16
                spacing: 12
                Rectangle {
                    implicitWidth: 36
                    implicitHeight: 36
                    radius: Theme.r(12)
                    color: Theme.accentSoft
                    Icon { anchors.centerIn: parent; name: "sparkle"; size: 20; color: Theme.textOnSoft }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    Txt { heading: true; text: "Hermes"; font.pixelSize: 18 }
                    Txt {
                        text: Hermes.busy ? "Answering…" : Hermes.fresh ? "New session · /sessions for older ones" : "Session ongoing"
                        font.pixelSize: 12
                        color: Theme.textDim
                    }
                }
                Clicky {
                    implicitWidth: 44
                    implicitHeight: 44
                    radius: Theme.r(14)
                    onClicked: Hermes.newChat()
                    Icon { anchors.centerIn: parent; name: "plus"; size: 18; stroke: 2; color: Theme.textDim }
                }
                Clicky {
                    implicitWidth: 44
                    implicitHeight: 44
                    radius: Theme.r(14)
                    onClicked: Hermes.open = false
                    Icon { anchors.centerIn: parent; name: "close"; size: 18; stroke: 2; color: Theme.textDim }
                }
            }

            // ---- who answers ----
            Rectangle {
                Layout.fillWidth: true
                Layout.leftMargin: 18
                Layout.rightMargin: 18
                implicitHeight: 52
                radius: Theme.r(16)
                color: Theme.bgMid
                RowLayout {
                    anchors { fill: parent; margins: 4 }
                    spacing: 4
                    Chip { Layout.fillWidth: true; Layout.fillHeight: true; label: "Hermes"; sub: "quick answers"; on: Hermes.engine === "hermes"; onClicked: Hermes.engine = "hermes" }
                    Chip { Layout.fillWidth: true; Layout.fillHeight: true; label: "Claude Code"; sub: "search · config changes"; on: Hermes.engine === "claude"; onClicked: Hermes.engine = "claude" }
                }
            }

            // ---- the conversation ----
            ListView {
                id: chat
                SmoothWheel { flick: chat }
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.topMargin: 6
                clip: true
                spacing: 14
                topMargin: 12
                bottomMargin: 12
                model: Hermes.messages.length
                onCountChanged: Qt.callLater(positionViewAtEnd)
                boundsBehavior: Flickable.StopAtBounds

                delegate: Item {
                    id: msg
                    required property int index
                    readonly property var m: Hermes.messages[index] ?? { me: false, text: "" }
                    readonly property bool waiting: !!m.streaming && !m.text
                    readonly property string kind: m.me ? "me" : m.note ? "note" : m.sessions ? "sessions" : "answer"
                    width: chat.width
                    implicitHeight: kind === "me" ? bubble.height : kind === "note" ? noteText.implicitHeight
                        : kind === "sessions" ? sessionList.implicitHeight : answer.implicitHeight

                    // A small grey line: "Carrying on: …", "No earlier sessions…"
                    Txt {
                        id: noteText
                        visible: msg.kind === "note"
                        x: 18
                        width: chat.width - 36
                        horizontalAlignment: Text.AlignHCenter
                        text: msg.m.note ?? ""
                        wrapMode: Text.Wrap
                        font.pixelSize: 12
                        color: Theme.outline
                    }

                    // /sessions: recent sessions, click one to carry it on
                    ColumnLayout {
                        id: sessionList
                        visible: msg.kind === "sessions"
                        x: 18
                        width: chat.width - 36
                        spacing: 4
                        Txt { text: "Recent sessions · click one to carry it on"; font.pixelSize: 12; color: Theme.textDim; Layout.bottomMargin: 2 }
                        Repeater {
                            model: msg.m.sessions ?? []
                            Clicky {
                                id: sess
                                required property var modelData
                                Layout.fillWidth: true
                                implicitHeight: 48
                                radius: Theme.r(14)
                                base: Theme.bgMid
                                onClicked: Hermes.resume(modelData.id, modelData.title)
                                ColumnLayout {
                                    anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                                    spacing: 1
                                    Txt { Layout.fillWidth: true; text: sess.modelData.title; font.weight: Font.DemiBold; elide: Text.ElideRight }
                                    Txt { text: sess.modelData.when; font.pixelSize: 11; color: Theme.textDim }
                                }
                            }
                        }
                    }

                    // You: a bubble on the right
                    Rectangle {
                        id: bubble
                        visible: msg.kind === "me"
                        anchors { right: parent.right; rightMargin: 18 }
                        width: Math.min(mine.implicitWidth + 28, (chat.width - 36) * 0.8)
                        height: mine.implicitHeight + 20
                        radius: Theme.r(18)
                        bottomRightRadius: 6
                        color: Theme.accentSoft
                        TextEdit {
                            id: mine
                            x: 14
                            y: 10
                            width: parent.width - 28
                            text: msg.m.me ? msg.m.text : ""
                            readOnly: true
                            selectByMouse: true
                            wrapMode: Text.Wrap
                            color: Theme.textOnSoft
                            font.family: Theme.font
                            font.pixelSize: 14
                        }
                    }

                    // The answer: plain text on the left, plus any files it changed
                    ColumnLayout {
                        id: answer
                        visible: msg.kind === "answer"
                        x: 18
                        width: (chat.width - 36) * 0.92
                        spacing: 8
                        // Tools it used (web search, files read, MCP calls), as small chips
                        Flow {
                            visible: (msg.m.tools ?? []).length > 0
                            Layout.fillWidth: true
                            spacing: 6
                            Repeater {
                                model: msg.m.tools ?? []
                                Rectangle {
                                    id: toolChip
                                    required property string modelData
                                    width: Math.min(toolText.implicitWidth + 16, answer.width)
                                    height: 22
                                    radius: Theme.r(8)
                                    color: Theme.bgHigh
                                    Txt { id: toolText; anchors.centerIn: parent; width: Math.min(implicitWidth, parent.width - 16); text: toolChip.modelData; font.family: Theme.mono; font.pixelSize: 11; color: Theme.textDim; elide: Text.ElideRight }
                                }
                            }
                        }
                        TextEdit {
                            Layout.fillWidth: true
                            text: msg.waiting ? (msg.m.tools?.length ? "Working…" : "…") : (msg.m.text ?? "")
                            textFormat: TextEdit.MarkdownText
                            readOnly: true
                            selectByMouse: true
                            wrapMode: Text.Wrap
                            color: msg.waiting ? Theme.textDim : Theme.text
                            palette.link: Theme.accent // links in the answer (sources etc.)
                            onLinkActivated: link => Qt.openUrlExternally(link)
                            HoverHandler { cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : Qt.IBeamCursor }
                            font.family: Theme.font
                            font.pixelSize: 14
                        }
                        Repeater {
                            model: msg.m.files ?? []
                            Rectangle {
                                required property string modelData
                                Layout.fillWidth: true
                                implicitHeight: 40
                                radius: Theme.r(14)
                                color: Theme.bgMid
                                RowLayout {
                                    anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                                    spacing: 10
                                    Icon { name: "code"; size: 16; color: Theme.accent }
                                    Txt { Layout.fillWidth: true; text: parent.parent.modelData; font.family: Theme.mono; elide: Text.ElideMiddle; font.strikeout: !!msg.m.undone }
                                }
                            }
                        }
                        RowLayout {
                            visible: (msg.m.files ?? []).length > 0
                            spacing: 8
                            Clicky {
                                implicitWidth: diffText.implicitWidth + 28
                                implicitHeight: 40
                                radius: Theme.r(12)
                                border.color: Theme.border
                                border.width: 1
                                onClicked: Quickshell.execDetached(["wezterm", "start", "--cwd", Settings.repo, "--", "sh", "-c", "git diff; git status --short; exec $SHELL"])
                                Txt { id: diffText; anchors.centerIn: parent; text: "Show diff"; font.weight: Font.DemiBold }
                            }
                            Clicky {
                                implicitWidth: reloadText.implicitWidth + 28
                                implicitHeight: 40
                                radius: Theme.r(12)
                                base: Theme.accent
                                onClicked: Quickshell.reload(true)
                                Txt { id: reloadText; anchors.centerIn: parent; text: "Reload shell"; font.weight: Font.DemiBold; color: Theme.textOnAccent }
                            }
                            // Put the listed files back as they were before this message
                            Clicky {
                                visible: !!msg.m.undoRef
                                active: !msg.m.undone
                                implicitWidth: undoText.implicitWidth + 28
                                implicitHeight: 40
                                radius: Theme.r(12)
                                onClicked: Hermes.undo(msg.index)
                                Txt { id: undoText; anchors.centerIn: parent; text: msg.m.undone ? "Undone" : "Undo"; font.weight: Font.DemiBold; color: Theme.textDim }
                            }
                        }
                    }
                }
            }

            // ---- message box ----
            Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.alpha(Theme.textDim, 0.1) }
            ColumnLayout {
                Layout.fillWidth: true
                Layout.margins: 14
                Layout.topMargin: 12
                spacing: 10
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: Math.max(56, Math.min(160, input.implicitHeight + 12))
                    radius: Theme.r(20)
                    color: Theme.bgHigh
                    RowLayout {
                        anchors { fill: parent; leftMargin: 14; rightMargin: 6; topMargin: 6; bottomMargin: 6 }
                        spacing: 8
                        ScrollView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            TextArea {
                                id: input
                                placeholderText: "Ask anything · /sessions to carry one on · /new"
                                placeholderTextColor: Theme.outline
                                text: Hermes.draft
                                onTextChanged: Hermes.draft = text
                                wrapMode: TextArea.Wrap
                                color: Theme.text
                                font.family: Theme.font
                                font.pixelSize: 14
                                background: null
                                padding: 4
                                // Enter sends, Shift+Enter is a new line, Esc closes the panel
                                Keys.onPressed: e => {
                                    if ((e.key === Qt.Key_Return || e.key === Qt.Key_Enter) && !(e.modifiers & Qt.ShiftModifier)) {
                                        if (!Hermes.busy) { Hermes.send(input.text); input.text = "" }
                                        e.accepted = true;
                                    } else if (e.key === Qt.Key_Escape) {
                                        Hermes.open = false;
                                        e.accepted = true;
                                    }
                                }
                            }
                        }
                        // Send; while an answer is being written it's Stop instead (ends the
                        // agent's process and keeps what it wrote so far, see EngineChat.stop)
                        Clicky {
                            Layout.alignment: Qt.AlignBottom
                            implicitWidth: 44
                            implicitHeight: 44
                            radius: Theme.r(14)
                            base: Hermes.busy ? Theme.bgHighest : Theme.accent
                            onClicked: {
                                if (Hermes.busy) Hermes.chat.stop();
                                else { Hermes.send(input.text); input.text = "" }
                            }
                            Icon { visible: !Hermes.busy; anchors.centerIn: parent; name: "send"; size: 18; stroke: 2; color: Theme.textOnAccent }
                            Txt { visible: Hermes.busy; anchors.centerIn: parent; text: "Stop"; font.pixelSize: 12; font.weight: Font.DemiBold }
                        }
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    Chip { implicitHeight: 32; filled: false; label: "Quick question"; on: Hermes.mode === "quick"; onClicked: Hermes.mode = "quick" }
                    Chip { implicitHeight: 32; filled: false; label: "Can edit files"; on: Hermes.mode === "edit"; onClicked: Hermes.mode = "edit" }
                    Txt {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignRight
                        text: Hermes.mode === "quick" ? "read + search, no edits" : "can edit files, no shell"
                        font.pixelSize: 11
                        color: Theme.outline
                        elide: Text.ElideLeft
                    }
                }
            }
        }
    }
}
