import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var store: NotesStore

    var body: some View {
        VStack(spacing: 0) {
            searchField
            if !store.allTags.isEmpty {
                tagBar
            }

            List(selection: $store.selectedID) {
                ForEach(store.filteredNotes) { note in
                    NoteRow(note: note)
                        .tag(note.id)
                        .contextMenu {
                            Button(note.pinned ? "Desafixar" : "Fixar") {
                                store.togglePin(note.id)
                            }
                            Button("Mostrar no Finder") {
                                store.revealInFinder(note.id)
                            }
                            Divider()
                            Button("Apagar", role: .destructive) {
                                store.delete(note.id)
                            }
                        }
                }
            }
            .listStyle(.sidebar)

            Divider()

            Button {
                store.createNote()
            } label: {
                Label("Nova nota", systemImage: "square.and.pencil")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .padding(12)
        }
    }

    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Buscar", text: $store.searchQuery)
                .textFieldStyle(.plain)
            if !store.searchQuery.isEmpty {
                Button {
                    store.searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private var tagBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                TagChip(label: "Todas", active: store.activeTag == nil) {
                    store.activeTag = nil
                }
                ForEach(store.allTags, id: \.self) { tag in
                    TagChip(label: "#\(tag)", active: store.activeTag == tag) {
                        store.activeTag = (store.activeTag == tag) ? nil : tag
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
    }
}

struct TagChip: View {
    let label: String
    let active: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(active ? Color.accentColor : Color(nsColor: .controlBackgroundColor))
                .foregroundStyle(active ? Color.white : Color.primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct NoteRow: View {
    let note: Note

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            if note.pinned {
                Image(systemName: "pin.fill")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .padding(.top, 4)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(note.title)
                    .font(.system(.body, design: .serif))
                    .lineLimit(1)
                Text(note.preview.isEmpty ? "Sem texto adicional" : note.preview)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if !note.tags.isEmpty {
                    Text(note.tags.map { "#\($0)" }.joined(separator: " "))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 2)
    }
}
