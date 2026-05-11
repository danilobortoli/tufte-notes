import Foundation
import Combine
import SwiftUI

@MainActor
final class NotesStore: ObservableObject {
    @Published private(set) var notes: [Note] = []
    @Published var selectedID: UUID?
    @Published var searchQuery: String = ""
    @Published var activeTag: String? = nil

    let folder: URL

    @AppStorage("pinnedFilenames") private var pinnedFilenamesData: Data = Data()

    private var pinnedFilenames: Set<String> {
        get { (try? JSONDecoder().decode(Set<String>.self, from: pinnedFilenamesData)) ?? [] }
        set { pinnedFilenamesData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.folder = docs.appendingPathComponent("TufteNotes", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        reload()
        if notes.isEmpty {
            createNote(title: "Bem-vindo", body: Self.welcomeMarkdown)
        }
        selectedID = sortedNotes.first?.id
    }

    var allTags: [String] {
        let set = notes.reduce(into: Set<String>()) { acc, n in acc.formUnion(n.tags) }
        return set.sorted()
    }

    var sortedNotes: [Note] {
        notes.sorted { a, b in
            if a.pinned != b.pinned { return a.pinned && !b.pinned }
            return a.modifiedAt > b.modifiedAt
        }
    }

    var filteredNotes: [Note] {
        var list = sortedNotes
        if let tag = activeTag {
            list = list.filter { $0.tags.contains(tag) }
        }
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return list }
        return list.filter { note in
            note.title.lowercased().contains(q)
                || note.body.lowercased().contains(q)
                || note.tags.contains(where: { $0.lowercased().contains(q) })
        }
    }

    func reload() {
        let fm = FileManager.default
        let urls = (try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles])) ?? []
        let mdURLs = urls.filter { $0.pathExtension.lowercased() == "md" }
        let pinned = pinnedFilenames
        let loaded: [Note] = mdURLs.compactMap { url in
            guard let raw = try? String(contentsOf: url, encoding: .utf8) else { return nil }
            let (front, body) = Self.splitFrontmatter(raw)
            let attrs = try? url.resourceValues(forKeys: [.contentModificationDateKey])
            let mod = attrs?.contentModificationDate ?? Date()
            let title = Self.deriveTitle(from: body) ?? url.deletingPathExtension().lastPathComponent
            return Note(
                id: UUID(),
                url: url,
                title: title,
                body: body,
                tags: front.tags,
                pinned: front.pinned || pinned.contains(url.lastPathComponent),
                modifiedAt: mod
            )
        }
        notes = loaded
    }

    @discardableResult
    func createNote(title: String = "Sem título", body: String? = nil) -> Note {
        let slug = Self.slug(from: title)
        var url = folder.appendingPathComponent("\(slug).md")
        var n = 1
        while FileManager.default.fileExists(atPath: url.path) {
            n += 1
            url = folder.appendingPathComponent("\(slug)-\(n).md")
        }
        let content = body ?? "# \(title)\n\n"
        let serialized = Self.serialize(front: Frontmatter(tags: [], pinned: false), body: content)
        try? serialized.write(to: url, atomically: true, encoding: .utf8)
        let note = Note(id: UUID(), url: url, title: title, body: content, tags: [], pinned: false, modifiedAt: Date())
        notes.insert(note, at: 0)
        selectedID = note.id
        return note
    }

    func update(_ id: UUID, body: String) {
        guard let idx = notes.firstIndex(where: { $0.id == id }) else { return }
        var note = notes[idx]
        note.body = body
        note.title = Self.deriveTitle(from: body) ?? note.title
        note.modifiedAt = Date()
        persist(note)
        notes[idx] = note
    }

    func updateTags(_ id: UUID, tags: [String]) {
        guard let idx = notes.firstIndex(where: { $0.id == id }) else { return }
        var note = notes[idx]
        note.tags = tags
        note.modifiedAt = Date()
        persist(note)
        notes[idx] = note
    }

    func togglePin(_ id: UUID) {
        guard let idx = notes.firstIndex(where: { $0.id == id }) else { return }
        var note = notes[idx]
        note.pinned.toggle()
        var pinned = pinnedFilenames
        if note.pinned { pinned.insert(note.filename) } else { pinned.remove(note.filename) }
        pinnedFilenames = pinned
        persist(note)
        notes[idx] = note
    }

    func delete(_ id: UUID) {
        guard let idx = notes.firstIndex(where: { $0.id == id }) else { return }
        let note = notes[idx]
        try? FileManager.default.removeItem(at: note.url)
        var pinned = pinnedFilenames
        pinned.remove(note.filename)
        pinnedFilenames = pinned
        notes.remove(at: idx)
        if selectedID == id {
            selectedID = sortedNotes.first?.id
        }
    }

    func note(for id: UUID) -> Note? {
        notes.first(where: { $0.id == id })
    }

    func revealInFinder(_ id: UUID) {
        guard let note = note(for: id) else { return }
        NSWorkspace.shared.activateFileViewerSelecting([note.url])
    }

    private func persist(_ note: Note) {
        let front = Frontmatter(tags: note.tags, pinned: note.pinned)
        let serialized = Self.serialize(front: front, body: note.body)
        try? serialized.write(to: note.url, atomically: true, encoding: .utf8)
    }

    // MARK: - Frontmatter

    private struct Frontmatter {
        var tags: [String]
        var pinned: Bool
    }

    private static func splitFrontmatter(_ raw: String) -> (Frontmatter, String) {
        let lines = raw.components(separatedBy: "\n")
        guard let first = lines.first, first.trimmingCharacters(in: .whitespaces) == "---" else {
            return (Frontmatter(tags: [], pinned: false), raw)
        }
        var endIdx: Int? = nil
        for i in 1..<lines.count where lines[i].trimmingCharacters(in: .whitespaces) == "---" {
            endIdx = i
            break
        }
        guard let end = endIdx else {
            return (Frontmatter(tags: [], pinned: false), raw)
        }
        var tags: [String] = []
        var pinned = false
        for i in 1..<end {
            let line = lines[i]
            if let r = line.range(of: "tags:") {
                let value = String(line[r.upperBound...])
                let cleaned = value
                    .replacingOccurrences(of: "[", with: "")
                    .replacingOccurrences(of: "]", with: "")
                tags = cleaned.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            } else if line.contains("pinned:") {
                pinned = line.lowercased().contains("true")
            }
        }
        let bodyLines = Array(lines[(end + 1)...])
        var body = bodyLines.joined(separator: "\n")
        if body.hasPrefix("\n") { body.removeFirst() }
        return (Frontmatter(tags: tags, pinned: pinned), body)
    }

    private static func serialize(front: Frontmatter, body: String) -> String {
        if front.tags.isEmpty && !front.pinned {
            return body
        }
        var lines = ["---"]
        if !front.tags.isEmpty {
            lines.append("tags: [\(front.tags.joined(separator: ", "))]")
        }
        if front.pinned {
            lines.append("pinned: true")
        }
        lines.append("---")
        lines.append("")
        return lines.joined(separator: "\n") + body
    }

    private static func deriveTitle(from body: String) -> String? {
        for line in body.split(whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("# ") {
                return String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
            }
            if !trimmed.isEmpty {
                return String(trimmed.prefix(80))
            }
        }
        return nil
    }

    private static func slug(from title: String) -> String {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789-")
        let lower = title.lowercased().replacingOccurrences(of: " ", with: "-")
        let scalars = lower.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" }
        let cleaned = String(scalars).trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return cleaned.isEmpty ? "sem-titulo" : cleaned
    }

    private static let welcomeMarkdown = """
    # Bem-vindo ao Tufte Notes

    Um lugar tranquilo pra escrever, no espírito de Edward Tufte: margens generosas, tipografia serifada clássica e notas marginais (sidenotes) pra digressões.

    Comece a digitar. Use `#` para título, `##` para seção. **Negrito** com `**texto**`, *itálico* com `*texto*`.

    Para uma sidenote, escreva `^[seu comentário]` no fluxo do texto.^[Como esta — sidenotes mantêm a digressão ao lado sem cortar a leitura.]

    > Citações ficam num bloco menor e indentado.

    ⌘N para uma nova nota. ⌘, abre as preferências. Arquivos são salvos em `~/Documents/TufteNotes/`.
    """
}
