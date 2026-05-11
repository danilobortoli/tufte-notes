import SwiftUI

@main
struct TufteNotesApp: App {
    @StateObject private var store = NotesStore()
    @AppStorage("theme") private var themeRaw: String = AppTheme.system.rawValue

    private var colorScheme: ColorScheme? {
        switch AppTheme(rawValue: themeRaw) ?? .system {
        case .light: return .light
        case .dark:  return .dark
        case .system: return nil
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .frame(minWidth: 1000, minHeight: 640)
                .preferredColorScheme(colorScheme)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Nova nota") { store.createNote() }
                    .keyboardShortcut("n", modifiers: .command)
            }
            CommandMenu("Formatar") {
                Button("Negrito")  { NotificationCenter.default.post(name: .editorFormat, object: "bold") }
                    .keyboardShortcut("b", modifiers: .command)
                Button("Itálico")  { NotificationCenter.default.post(name: .editorFormat, object: "italic") }
                    .keyboardShortcut("i", modifiers: .command)
                Divider()
                Button("Título 1") { NotificationCenter.default.post(name: .editorFormat, object: "h1") }
                    .keyboardShortcut("1", modifiers: [.command, .option])
                Button("Título 2") { NotificationCenter.default.post(name: .editorFormat, object: "h2") }
                    .keyboardShortcut("2", modifiers: [.command, .option])
                Button("Título 3") { NotificationCenter.default.post(name: .editorFormat, object: "h3") }
                    .keyboardShortcut("3", modifiers: [.command, .option])
                Divider()
                Button("Sidenote") { NotificationCenter.default.post(name: .editorFormat, object: "sidenote") }
                    .keyboardShortcut("d", modifiers: [.command, .shift])
            }
            CommandGroup(after: .textEditing) {
                Button("Buscar na nota…") {
                    NotificationCenter.default.post(name: .editorToggleFind, object: nil)
                }
                .keyboardShortcut("f", modifiers: .command)
            }
        }

        Settings {
            SettingsView()
        }
    }
}

extension Notification.Name {
    static let editorFormat = Notification.Name("editorFormat")
    static let editorToggleFind = Notification.Name("editorToggleFind")
}
