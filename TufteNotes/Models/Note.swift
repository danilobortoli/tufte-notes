import Foundation

struct Note: Identifiable, Hashable {
    let id: UUID
    var url: URL
    var title: String
    var body: String        // sem frontmatter
    var tags: [String]
    var pinned: Bool
    var modifiedAt: Date

    var filename: String { url.lastPathComponent }

    var preview: String {
        let stripped = body
            .replacingOccurrences(of: "#", with: "")
            .replacingOccurrences(of: "*", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let firstLine = stripped.split(whereSeparator: \.isNewline).dropFirst().first.map(String.init) ?? ""
        return firstLine
    }
}
