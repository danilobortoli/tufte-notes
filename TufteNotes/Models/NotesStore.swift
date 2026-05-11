import Foundation
import Combine

@MainActor
final class NotesStore: ObservableObject {
    @Published private(set) var notes: [Note] = []
    @Published var selectedID: UUID?
    @Published var searchQuery: String = ""

    let folder: URL

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.folder = docs.appendingPathComponent("TufteNotes", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        reload()
        if notes.isEmpty {
            createNote(title: "Welcome", body: Self.welcomeMarkdown)
        }
        selectedID = notes.first?.id
    }

    var filteredNotes: [Note] {
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return notes }
        return notes.filter { note in
            note.title.lowercased().contains(q) || note.body.lowercased().contains(q)
        }
    }

    func reload() {
        let fm = FileManager.default
        let urls = (try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles])) ?? []
        let mdURLs = urls.filter { $0.pathExtension.lowercased() == "md" }
        let loaded: [Note] = mdURLs.compactMap { url in
            guard let body = try? String(contentsOf: url, encoding: .utf8) else { return nil }
            let attrs = try? url.resourceValues(forKeys: [.contentModificationDateKey])
            let mod = attrs?.contentModificationDate ?? Date()
            let title = Self.deriveTitle(from: body) ?? url.deletingPathExtension().lastPathComponent
            return Note(id: UUID(), url: url, title: title, body: body, modifiedAt: mod)
        }
        notes = loaded.sorted { $0.modifiedAt > $1.modifiedAt }
    }

    @discardableResult
    func createNote(title: String = "Untitled", body: String? = nil) -> Note {
        let slug = Self.slug(from: title)
        var url = folder.appendingPathComponent("\(slug).md")
        var n = 1
        while FileManager.default.fileExists(atPath: url.path) {
            n += 1
            url = folder.appendingPathComponent("\(slug)-\(n).md")
        }
        let content = body ?? "# \(title)\n\n"
        try? content.write(to: url, atomically: true, encoding: .utf8)
        let note = Note(id: UUID(), url: url, title: title, body: content, modifiedAt: Date())
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
        try? body.write(to: note.url, atomically: true, encoding: .utf8)
        notes[idx] = note
    }

    func delete(_ id: UUID) {
        guard let idx = notes.firstIndex(where: { $0.id == id }) else { return }
        let note = notes[idx]
        try? FileManager.default.removeItem(at: note.url)
        notes.remove(at: idx)
        if selectedID == id {
            selectedID = notes.first?.id
        }
    }

    func binding(for id: UUID) -> Note? {
        notes.first(where: { $0.id == id })
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
        return cleaned.isEmpty ? "untitled" : cleaned
    }

    private static let welcomeMarkdown = """
    # Welcome to Tufte Notes

    A quiet place to write, styled after Edward Tufte's principles: generous margins, classic serif type, and sidenotes for asides.

    Start typing. Use `#` for a title and `##` for a section. Bold with `**text**`, italics with `*text*`.

    For a sidenote, write `^[your aside here]` in the margin.^[Like this — sidenotes keep digressions adjacent without breaking flow.]

    > Quotes are set in a smaller, indented block — useful for citations or epigraphs.

    Press ⌘N to start a new note. Notes are saved as Markdown files in `~/Documents/TufteNotes/`.
    """
}
