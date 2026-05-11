import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var store: NotesStore

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search", text: $store.searchQuery)
                    .textFieldStyle(.plain)
            }
            .padding(8)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 8)

            List(selection: $store.selectedID) {
                ForEach(store.filteredNotes) { note in
                    NoteRow(note: note)
                        .tag(note.id)
                        .contextMenu {
                            Button("Delete", role: .destructive) {
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
                Label("New Note", systemImage: "square.and.pencil")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .padding(12)
        }
    }
}

struct NoteRow: View {
    let note: Note

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(note.title)
                .font(.system(.body, design: .serif))
                .lineLimit(1)
            Text(note.preview.isEmpty ? "No additional text" : note.preview)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, 2)
    }
}
