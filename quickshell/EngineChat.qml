// One chat of the side panel (see Hermes.qml): its messages, its agent session and the
// processes that ask the agent. Hermes.qml makes two: one for Hermes, one for Claude Code.
//
// Every chat starts as a new session. Typed commands:
//   /new        start a fresh session
//   /sessions   list recent sessions (this folder); click one to carry it on
//
// message: { me, text, tools: [labels], files: [paths], undoRef, undone, streaming, stopped }
//          { note: "text" }                              a small grey line (resumed, new...)
//          { sessions: [{ id, title, when }] }           the /sessions list
import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: c
    required property string engine
    property var messages: []
    property bool busy: false
    // The agent session this chat continues: for Hermes its id ("" = start one with the next
    // message); for Claude Code a uuid we choose, used with --session-id first, --resume after.
    property string sessionId: engine === "claude" ? newId() : ""
    property bool fresh: true                 // next message starts the session
    property string sentMode: "quick"
    property string statusBefore: ""
    property string undoRef: ""
    property bool stopping: false             // Stop was pressed: the answer ends as "(stopped)"
    property bool heard: false                // Claude Code sent something, so its session exists

    function newId() {
        return "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx".replace(/[xy]/g, ch => {
            const r = Math.random() * 16 | 0;
            return (ch === "x" ? r : (r & 3 | 8)).toString(16);
        });
    }

    function send(text, mode) {
        text = text.trim();
        if (!text || busy) return;
        if (text === "/new") { reset(); return }
        if (text === "/sessions") { listSessions(); return }
        messages = [...messages, { me: true, text }, { me: false, text: "", tools: [], files: [], streaming: true }];
        busy = true;
        stopping = false;
        heard = false;
        sentMode = mode;
        asker.command = engine === "claude"
            ? [Quickshell.shellDir + "/scripts/ask", "claude", mode, fresh ? "new" : "continue", sessionId, text]
            : [Quickshell.shellDir + "/scripts/ask", "hermes", mode, fresh ? "new" : sessionId, text];
        before.running = true; // remember the repo's state first, then ask
    }
    // Stop the answer being written (the panel's Stop button): without this a stalled agent
    // leaves the chat stuck on "Answering…" until its process ends, which may be never.
    // What it wrote so far stays, marked "(stopped)".
    function stop() {
        if (!busy || stopping) return;
        stopping = true;
        if (asker.running) asker.running = false; // sends TERM; onExited below tidies up
        else { before.running = false; finish(0) } // still at the git step: nothing was asked
    }
    // The answer is over (it ended by itself, or was stopped): close the last message
    function finish(code) {
        const who = engine === "claude" ? "Claude Code" : "Hermes";
        const stopped = stopping;
        patchLast(m => {
            m.streaming = false;
            m.text = m.text.trim();
            if (stopped) {
                m.stopped = true;
                m.text += (m.text ? "\n\n" : "") + "(stopped)";
            } else if (!m.text) m.text = code === 0 ? "(no answer)"
                : "⚠ " + who + " stopped with an error (exit " + code + "). "
                  + (Net.online ? "Try again, or run `" + (engine === "claude" ? "claude" : "hermes doctor") + "` in a terminal to see why."
                                : "You're offline: it needs the internet.");
            return m;
        });
        // Stopped before Claude Code said anything: its session may not exist yet, so
        // --resume would fail. Start the next message as a new session under a new id.
        if (engine === "claude" && stopped && fresh && !heard) sessionId = newId();
        else if (engine === "claude" || sessionId) fresh = false;
        stopping = false;
        busy = false;
    }
    function reset() {
        if (busy) return;
        messages = [];
        fresh = true;
        sessionId = engine === "claude" ? newId() : "";
    }
    function listSessions() {
        if (busy) return;
        lister.command = [Quickshell.shellDir + "/scripts/ask", "sessions", engine];
        lister.running = true;
    }
    // Carry on an old session (clicked in the /sessions list)
    function resume(id, title) {
        if (busy) return;
        sessionId = id;
        fresh = false;
        messages = [{ note: "Carrying on: " + title }];
    }

    // Change the answer being written (the last message)
    function patchLast(f) {
        const m = messages.slice();
        m[m.length - 1] = f(Object.assign({}, m[m.length - 1]));
        messages = m;
    }
    function undo(index) {
        const m = messages[index];
        if (!m?.undoRef || !m.files?.length || m.undone) return;
        Quickshell.execDetached([Quickshell.shellDir + "/scripts/ask", "undo", m.undoRef, ...m.files]);
        const all = messages.slice();
        all[index] = Object.assign({}, m, { undone: true });
        messages = all;
    }

    Process {
        id: lister
        stdout: StdioCollector {
            onStreamFinished: {
                const items = text.split("\n").filter(l => l.includes("\t")).map(l => {
                    const [id, title, when] = l.split("\t");
                    return { id, title: title === "—" ? "Untitled" : title, when };
                });
                c.messages = [...c.messages, items.length ? { sessions: items } : { note: "No earlier sessions here yet." }];
            }
        }
    }

    // Before asking: git status (to spot changed files) and a snapshot ref for Undo
    Process {
        id: before
        command: ["sh", "-c", "cd \"$1\" && git status --short && echo @@ && (git stash create || true) && git rev-parse HEAD", "sh", Settings.repo]
        stdout: StdioCollector {
            onStreamFinished: {
                const [status, refs] = text.split("@@\n");
                c.statusBefore = status;
                c.undoRef = (refs ?? "").trim().split("\n")[0] ?? "";
                if (c.busy && !c.stopping) asker.running = true; // not if Stop came first
            }
        }
    }

    // Claude streams JSON lines; Hermes prints its answer, then "@@SESSION <id>" for a new one
    Process {
        id: asker
        stdout: SplitParser {
            onRead: line => {
                if (c.engine !== "claude") {
                    const s = line.match(/^@@SESSION (\S+)/);
                    if (s) c.sessionId = s[1];
                    else c.patchLast(m => { m.text += (m.text ? "\n" : "") + line; return m });
                    return;
                }
                let e;
                try { e = JSON.parse(line) } catch (err) { return }
                c.heard = true;
                if (e.type === "stream_event") {
                    const ev = e.event;
                    if (ev?.type === "content_block_delta" && ev.delta?.type === "text_delta")
                        c.patchLast(m => { m.text += ev.delta.text; return m });
                    else if (ev?.type === "content_block_start" && ev.content_block?.type === "text")
                        c.patchLast(m => { if (m.text && !m.text.endsWith("\n\n")) m.text += "\n\n"; return m });
                } else if (e.type === "assistant") {
                    // a chip per tool call: name and what it was about (ToolSearch is its own bookkeeping)
                    const uses = (e.message?.content ?? []).filter(b => b.type === "tool_use" && b.name !== "ToolSearch");
                    if (uses.length) c.patchLast(m => {
                        m.tools = [...(m.tools ?? []), ...uses.map(u => {
                            const i = u.input ?? {};
                            const what = i.query ?? i.url ?? i.file_path ?? i.pattern ?? i.path ?? "";
                            return u.name.replace(/^mcp__[^_]+__/, "") + (what ? " · " + String(what).split("/").pop() : "");
                        })];
                        return m;
                    });
                } else if (e.type === "result") {
                    c.patchLast(m => {
                        if (e.is_error) m.text = (m.text.trim() ? m.text + "\n\n" : "") + "⚠ " + (e.result || e.subtype || "Claude Code reported an error");
                        else if (!m.text.trim()) m.text = e.result ?? "";
                        return m;
                    });
                }
            }
        }
        onExited: (code, status) => {
            c.finish(code);
            // also after Stop: it may have changed files before it was stopped
            if (c.sentMode === "edit") after.running = true;
        }
    }

    // Which files the answer changed: lines of `git status` that weren't there before
    Process {
        id: after
        command: ["git", "-C", Settings.repo, "status", "--short"]
        stdout: StdioCollector {
            onStreamFinished: {
                const old = c.statusBefore.split("\n");
                const files = text.split("\n").filter(l => l && !old.includes(l)).map(l => l.slice(3));
                if (files.length) c.patchLast(m => { m.files = files; m.undoRef = c.undoRef; return m });
            }
        }
    }
}
