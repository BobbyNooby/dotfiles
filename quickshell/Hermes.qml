// The side panel's chats (HermesPanel.qml): Super+A or `qs ipc call hermes toggle`.
//
// Two chats, like two tabs: Hermes (DeepSeek, quick answers) and Claude Code (search with
// its web tools and MCP servers, or config changes; answers stream in, with a chip per tool
// it used). Every chat starts as a NEW session. Type /sessions to pick an old one and carry
// it on, /new (or the + button) to start over. Switching tabs keeps both; an answer lands in
// the chat that asked. See EngineChat.qml for one chat, scripts/ask for the agent commands.
// In "Can edit files" mode, changed files are listed after the answer, with Show diff /
// Reload shell / Undo (Undo puts those files back as they were before that message).
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool open: false
    property string engine: "hermes"   // which chat is shown: "hermes" | "claude"
    property string mode: "quick"      // "quick" | "edit"
    property string draft: ""          // what's typed in the box (kept while the panel is closed)

    // The chat on screen; the panel reads these
    readonly property var chat: engine === "claude" ? claudeChat : hermesChat
    readonly property var messages: chat.messages
    readonly property bool busy: chat.busy
    readonly property bool fresh: chat.fresh

    function toggle() { open = !open; if (open) Popups.close() }
    function send(text) { chat.send(text, mode) }
    function newChat() { chat.reset() }
    function undo(index) { chat.undo(index) }
    function resume(id, title) { chat.resume(id, title) }

    EngineChat { id: hermesChat; engine: "hermes" }
    EngineChat { id: claudeChat; engine: "claude" }

    IpcHandler {
        target: "hermes"
        function toggle(): void { root.toggle() }
        function close(): void { root.open = false }
        // send a message from a terminal: qs ipc call hermes ask claude "what's new in Hyprland?"
        function ask(engine: string, text: string): void { root.engine = engine; root.open = true; root.send(text) }
    }
}
