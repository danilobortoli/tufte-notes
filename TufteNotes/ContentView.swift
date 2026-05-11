import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: NotesStore

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 240, ideal: 300, max: 380)
        } detail: {
            if let id = store.selectedID, let note = store.note(for: id) {
                TufteEditorView(note: note)
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
        VStack(spacing: 14) {
            Image(systemName: "doc.text")
                .font(.system(size: 42))
                .foregroundStyle(.tertiary)
            Text("Nenhuma nota selecionada")
                .font(.system(.title3, design: .serif))
                .foregroundStyle(.secondary)
            Button("Criar nova nota") { store.createNote() }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
