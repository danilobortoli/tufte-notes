import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: NotesStore

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 220, ideal: 280, max: 360)
        } detail: {
            if let id = store.selectedID, let note = store.binding(for: id) {
                TufteEditorView(noteID: note.id, initialMarkdown: note.body)
                    .id(note.id)
            } else {
                EmptyEditorPlaceholder()
            }
        }
    }
}

struct EmptyEditorPlaceholder: View {
    @EnvironmentObject var store: NotesStore

    var body: some View {
        VStack(spacing: 12) {
            Text("No note selected")
                .font(.system(.title2, design: .serif))
                .foregroundStyle(.secondary)
            Button("New Note") { store.createNote() }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
