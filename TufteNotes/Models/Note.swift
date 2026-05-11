import Foundation

struct Note: Identifiable, Hashable {
    let id: UUID
    var url: URL
    var title: String
    var body: String
    var modifiedAt: Date

    var preview: String {
        let stripped = body
            .replacingOccurrences(of: "#", with: "")
            .replacingOccurrences(of: "*", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let firstLine = stripped.split(whereSeparator: \.isNewline).dropFirst().first.map(String.init) ?? ""
        return firstLine
    }
}
