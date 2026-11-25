// ClaudePet – kleiner Pixel-Begleiter am unteren Bildschirmrand.
// Reagiert auf laufende Claude-Code-Sessions (~/.claude/projects/*.jsonl),
// Klick öffnet Chat über `claude -p` (Abo, kein API-Key). Animationen: Anim.swift
import AppKit
import SwiftUI

final class Pet: ObservableObject {
    @Published var f = Frame()
}

struct PetView: View {
    @ObservedObject var pet: Pet
    var body: some View {
        Canvas { ctx, _ in drawFrame(ctx, pet.f) }
            .frame(width: CGFloat(gridW) * px, height: CGFloat(gridH) * px)
    }
}

// MARK: - Chat

final class Chat: ObservableObject {
    @Published var input = ""
    @Published var answer = "Hallo Gabriel, ich bin Krümel! Frag mich was."
    @Published var busy = false
    var hasConversation = false
}

struct ChatView: View {
    @ObservedObject var chat: Chat
    var send: () -> Void
    let accent = pal["#"]!

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView {
                Text(chat.answer)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.white.opacity(0.9))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            HStack {
                TextField("Nachricht …", text: $chat.input)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.white)
                    .onSubmit(send)
                    .disabled(chat.busy)
                Text(chat.busy ? "…" : "↵").foregroundColor(accent)
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.07)))
        }
        .padding(14)
        .frame(width: 320, height: 230)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(red: 0.12, green: 0.11, blue: 0.10).opacity(0.96))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(accent.opacity(0.5), lineWidth: 1))
        )
    }
}

// MARK: - Sprechblase: was Claude gerade macht

final class Status: ObservableObject {
    @Published var text = ""
    @Published var done = false
}

struct BubbleView: View {
    @ObservedObject var s: Status
    let accent = pal["#"]!
    var body: some View {
        VStack {
            Spacer(minLength: 0)
            Text((s.done ? "✓ Fertig: " : "") + s.text)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.white.opacity(0.92))
                .lineLimit(2)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(red: 0.12, green: 0.11, blue: 0.10).opacity(0.94))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(accent.opacity(s.done ? 0.9 : 0.45), lineWidth: 1))
                )
        }
        .frame(width: 300, height: 56)
    }
}

final class BubbleHost: NSHostingView<BubbleView> {
    override func mouseUp(with event: NSEvent) {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.anthropic.claudefordesktop") {
            NSWorkspace.shared.openApplication(at: url, configuration: .init())
        }
    }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

/// Letzte Aktion von Claude aus dem Ende eines Session-Transkripts: Text oder Werkzeug.
func lastAction(_ file: URL) -> String? {
    guard let h = try? FileHandle(forReadingFrom: file) else { return nil }
    defer { try? h.close() }
    let size = (try? h.seekToEnd()) ?? 0
    try? h.seek(toOffset: size > 200_000 ? size - 200_000 : 0)
    guard let data = try? h.readToEnd(), let s = String(data: data, encoding: .utf8) else { return nil }
    for line in s.split(separator: "\n").reversed() {
        guard line.contains("\"type\":\"assistant\""),
              let o = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any],
              o["type"] as? String == "assistant", o["isSidechain"] as? Bool != true,
              let content = (o["message"] as? [String: Any])?["content"] as? [[String: Any]] else { continue }
        for c in content.reversed() {
            if c["type"] as? String == "text", let t = c["text"] as? String {
                let clean = t.replacingOccurrences(of: "**", with: "").replacingOccurrences(of: "`", with: "")
                if let first = clean.split(separator: "\n").map({ $0.trimmingCharacters(in: .whitespaces) }).first(where: { !$0.isEmpty }) {
                    return String(first.trimmingCharacters(in: CharacterSet(charactersIn: "#- ")).prefix(110))
                }
            }
            if c["type"] as? String == "tool_use", let name = c["name"] as? String {
                let input = c["input"] as? [String: Any] ?? [:]
                let detail = (input["description"] as? String)
                    ?? (input["file_path"] as? String).map { URL(fileURLWithPath: $0).lastPathComponent }
                    ?? ""
                let short = name.hasPrefix("mcp__") ? String(name.split(separator: "_").last ?? "") : name
                return String("\(short) \(detail)".trimmingCharacters(in: .whitespaces).prefix(110))
            }
        }
    }
    return nil
}

final class KeyPanel: NSPanel { override var canBecomeKey: Bool { true } }

final class ClickHost: NSHostingView<PetView> {
    var onClick: () -> Void = {}
    var onMenu: (NSEvent) -> Void = { _ in }
    override func mouseUp(with event: NSEvent) { onClick() }
    override func rightMouseUp(with event: NSEvent) { onMenu(event) }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

// MARK: - App

final class AppDelegate: NSObject, NSApplicationDelegate {
    let pet = Pet()
    let chat = Chat()
    let status = Status()
    var window: KeyPanel!
    var chatPanel: KeyPanel!
    var bubble: KeyPanel!
    var bubbleUntil = Date.distantPast
    var t = 0
    var act: Act?
    var actT = 0
    var nextAct = Date().addingTimeInterval(5)
    var targetX: CGFloat?
    var lastActivity = Date.distantPast
    var lastInteraction = Date()
    var wasWorking = false
    var happyUntil = Date.distantPast
    let projects = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude/projects")
    let workDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude-pet")

    var winW: CGFloat { CGFloat(gridW) * px }
    var winH: CGFloat { CGFloat(gridH) * px }

    func applicationDidFinishLaunching(_ n: Notification) {
        NSApp.setActivationPolicy(.accessory)
        try? FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)

        let host = ClickHost(rootView: PetView(pet: pet))
        host.onClick = { [weak self] in self?.toggleChat() }
        host.onMenu = { [weak self] e in self?.showMenu(e, in: host) }
        window = makePanel(NSRect(x: 0, y: 0, width: winW, height: winH))
        window.contentView = host
        let vf = screen.visibleFrame
        window.setFrameOrigin(NSPoint(x: vf.maxX - winW - 140, y: vf.minY))
        window.orderFrontRegardless()

        chatPanel = makePanel(NSRect(x: 0, y: 0, width: 320, height: 230))
        chatPanel.contentView = NSHostingView(rootView: ChatView(chat: chat) { [weak self] in self?.ask() })
        bubble = makePanel(NSRect(x: 0, y: 0, width: 300, height: 56))
        bubble.contentView = BubbleHost(rootView: BubbleView(s: status))

        Timer.scheduledTimer(withTimeInterval: 0.12, repeats: true) { [weak self] _ in self?.step() }
        Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in self?.checkActivity() }
        checkActivity()
    }

    var screen: NSScreen { window?.screen ?? NSScreen.main ?? NSScreen.screens[0] }

    func makePanel(_ r: NSRect) -> KeyPanel {
        let p = KeyPanel(contentRect: r, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = false
        p.level = .floating
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        return p
    }

    // Claude arbeitet, wenn irgendein Session-Transkript in den letzten 6 s geschrieben wurde.
    // Eigene Chat-Sessions des Pets zählen nicht als „Claude arbeitet“.
    func checkActivity() {
        DispatchQueue.global(qos: .utility).async { [projects] in
            var newest = Date.distantPast
            var newestFile: URL?
            let fm = FileManager.default
            let dirs = (try? fm.contentsOfDirectory(at: projects, includingPropertiesForKeys: nil)) ?? []
            for d in dirs where !d.lastPathComponent.hasSuffix("-claude-pet") {
                let files = (try? fm.contentsOfDirectory(at: d, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
                for f in files where f.pathExtension == "jsonl" {
                    if let m = try? f.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate, m > newest {
                        newest = m; newestFile = f
                    }
                }
            }
            let recent = Date().timeIntervalSince(newest) < 15
            let text = recent ? newestFile.flatMap(lastAction) : nil
            DispatchQueue.main.async {
                self.lastActivity = newest
                if let text { self.status.text = text }
            }
        }
    }

    func updateBubble(working: Bool) {
        let show = (working || Date() < bubbleUntil) && !status.text.isEmpty && !chatPanel.isVisible
        if show {
            let f = window.frame
            bubble.setFrameOrigin(NSPoint(x: f.midX - 150, y: f.minY + CGFloat(gridH - bodyY) * px + 34))
            if !bubble.isVisible { bubble.orderFrontRegardless() }
        } else if bubble.isVisible { bubble.orderOut(nil) }
    }

    func step() {
        t += 1
        let now = Date()
        let working = now.timeIntervalSince(lastActivity) < 6
        if wasWorking && !working && !chat.busy {
            happyUntil = now.addingTimeInterval(3)
            bubbleUntil = now.addingTimeInterval(12)
            status.done = true
        }
        if working { status.done = false }
        wasWorking = working
        updateBubble(working: working)

        if chat.busy { pet.f = thinkFrame(t); return }
        if now < happyUntil { pet.f = happyFrame(t); return }
        if working && act == nil { targetX = nil; lastInteraction = now; pet.f = laptopFrame(t); return }

        if let a = act {
            pet.f = a.f(actT)
            actT += 1
            if actT >= a.len { act = nil; nextAct = now.addingTimeInterval(.random(in: 6...16)) }
            return
        }
        if now.timeIntervalSince(lastInteraction) > 900 { pet.f = napFrame(t); return }

        let vf = screen.visibleFrame
        if let tx = targetX {
            var o = window.frame.origin
            let dx = tx - o.x
            if abs(dx) < 3 { targetX = nil; nextAct = now.addingTimeInterval(.random(in: 3...8)) }
            else {
                o.x += dx > 0 ? 3 : -3
                o.y = vf.minY
                window.setFrameOrigin(o)
                pet.f = walkFrame(t, left: dx < 0)
                return
            }
        }

        if now >= nextAct && !chatPanel.isVisible {
            if Double.random(in: 0..<1) < 0.3 {
                targetX = CGFloat.random(in: vf.minX...(vf.maxX - winW))
            } else {
                play(pickAct(hour: Calendar.current.component(.hour, from: now)))
            }
        }
        pet.f = idleFrame(t)
    }

    func play(_ i: Int) {
        act = acts[i]
        actT = 0
        targetX = nil
    }

    func toggleChat() {
        lastInteraction = Date()
        targetX = nil
        if chatPanel.isVisible { chatPanel.orderOut(nil); return }
        let f = window.frame
        let vf = screen.visibleFrame
        let x = min(max(f.midX - 160, vf.minX + 8), vf.maxX - 328)
        // Körperoberkante liegt (gridH - bodyY) Raster über Fensterunterkante
        chatPanel.setFrameOrigin(NSPoint(x: x, y: f.minY + CGFloat(gridH - bodyY + 3) * px))
        NSApp.activate(ignoringOtherApps: true)
        chatPanel.makeKeyAndOrderFront(nil)
    }

    func ask() {
        let q = chat.input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty, !chat.busy else { return }
        chat.input = ""
        chat.busy = true
        chat.answer = "› \(q)\n\n…"
        lastInteraction = Date()
        let cont = chat.hasConversation
        let system = "Du heißt Krümel und bist ein kleines orangefarbenes Pixel-Wesen am Bildschirmrand von Gabriel. Antworte kurz, freundlich, auf Deutsch, ohne Markdown. Du darfst Dateien im Schreibtisch-Ordner ~/Desktop lesen, verschieben, umbenennen und anlegen. Lösche nie etwas; zum Aufräumen in Ordner verschieben."
        DispatchQueue.global().async { [workDir] in
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/bin/zsh")
            // Argumente über $1/$2/$3, damit Nutzertext nie als Shell-Code läuft
            // Desktop-Zugriff: lesen + ändern, aber kein rm (Löschen bleibt gesperrt)
            let tools = "Read,Glob,Grep,Edit,Write,Bash(ls:*),Bash(mv:*),Bash(mkdir:*),Bash(cp:*)"
            p.arguments = ["-lc", "claude -p --model claude-sonnet-5-5 \(cont ? "-c " : "")--add-dir ~/Desktop --permission-mode acceptEdits --allowedTools \"$3\" --append-system-prompt \"$2\" \"$1\"", "pet", q, system, tools]
            p.currentDirectoryURL = workDir
            let out = Pipe()
            p.standardOutput = out
            p.standardError = out
            var text = ""
            do {
                try p.run()
                text = String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                p.waitUntilExit()
            } catch { text = "Fehler: \(error.localizedDescription)" }
            DispatchQueue.main.async {
                self.chat.answer = "› \(q)\n\n" + text.trimmingCharacters(in: .whitespacesAndNewlines)
                self.chat.busy = false
                if p.terminationStatus == 0 { self.chat.hasConversation = true; self.happyUntil = Date().addingTimeInterval(2) }
            }
        }
    }

    func showMenu(_ e: NSEvent, in view: NSView) {
        let m = NSMenu()
        m.addItem(withTitle: "Zufällige Animation", action: #selector(playRandom), keyEquivalent: "").target = self
        let sub = NSMenu()
        for (i, a) in acts.enumerated() {
            let item = sub.addItem(withTitle: a.name, action: #selector(playItem(_:)), keyEquivalent: "")
            item.tag = i
            item.target = self
        }
        m.addItem(withTitle: "Animation zeigen (\(acts.count))", action: nil, keyEquivalent: "").submenu = sub
        m.addItem(.separator())
        m.addItem(withTitle: "Neues Gespräch", action: #selector(resetChat), keyEquivalent: "").target = self
        m.addItem(withTitle: "Beenden", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "")
        NSMenu.popUpContextMenu(m, with: e, for: view)
    }

    @objc func playItem(_ s: NSMenuItem) { lastInteraction = Date(); play(s.tag) }
    @objc func playRandom() { lastInteraction = Date(); play(Int.random(in: 0..<acts.count)) }
    @objc func resetChat() { chat.hasConversation = false; chat.answer = "Frisch gestartet. Frag mich was." }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
