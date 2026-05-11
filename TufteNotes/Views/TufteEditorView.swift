import SwiftUI
import WebKit

struct TufteEditorView: View {
    let note: Note
    @EnvironmentObject var store: NotesStore
    @StateObject private var controller = EditorController()
    @AppStorage("theme") private var themeRaw: String = AppTheme.system.rawValue
    @AppStorage("editorFontSize") private var fontSize: Double = 1.4
    @AppStorage("readingWPM") private var wpm: Double = 220

    @State private var tagsText: String = ""
    @State private var showFindBar: Bool = false
    @State private var findQuery: String = ""

    private var theme: AppTheme { AppTheme(rawValue: themeRaw) ?? .system }

    var body: some View {
        VStack(spacing: 0) {
            metaBar
            Divider()
            toolbar
            Divider()
            if showFindBar { findBar; Divider() }
            TufteWebView(controller: controller,
                         noteID: note.id,
                         initialMarkdown: note.body,
                         theme: theme,
                         fontSize: fontSize)
            Divider()
            statusBar
        }
        .onAppear {
            tagsText = note.tags.joined(separator: ", ")
        }
        .onChange(of: themeRaw) { _ in
            controller.setTheme(theme)
        }
        .onChange(of: fontSize) { newValue in
            controller.setFontSize(newValue)
        }
        .onReceive(NotificationCenter.default.publisher(for: .editorFormat)) { notif in
            if let action = notif.object as? String {
                controller.format(action)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .editorToggleFind)) { _ in
            showFindBar.toggle()
            if !showFindBar {
                findQuery = ""
                controller.clearFind()
            }
        }
    }

    // MARK: - Bars

    private var metaBar: some View {
        HStack(spacing: 10) {
            Button {
                store.togglePin(note.id)
            } label: {
                Image(systemName: note.pinned ? "pin.fill" : "pin")
                    .foregroundStyle(note.pinned ? .orange : .secondary)
            }
            .buttonStyle(.borderless)
            .help(note.pinned ? "Desafixar nota" : "Fixar nota")

            HStack(spacing: 4) {
                Image(systemName: "tag")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                TextField("tags separadas por vírgula", text: $tagsText)
                    .textFieldStyle(.plain)
                    .font(.caption)
                    .onSubmit(commitTags)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 5))

            Spacer()

            Text(note.title)
                .font(.system(.caption, design: .serif))
                .italic()
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private var toolbar: some View {
        HStack(spacing: 2) {
            ToolbarButton(icon: "bold",    help: "Negrito (⌘B)")     { controller.format("bold") }
            ToolbarButton(icon: "italic",  help: "Itálico (⌘I)")     { controller.format("italic") }
            ToolbarButton(icon: "curlybraces",
                          help: "Código inline") { controller.format("code") }
            ToolbarDivider()
            ToolbarTextButton(label: "H1", help: "Título 1 (⌥⌘1)")  { controller.format("h1") }
            ToolbarTextButton(label: "H2", help: "Título 2 (⌥⌘2)")  { controller.format("h2") }
            ToolbarTextButton(label: "H3", help: "Título 3 (⌥⌘3)")  { controller.format("h3") }
            ToolbarDivider()
            ToolbarButton(icon: "list.bullet",     help: "Lista")       { controller.format("ul") }
            ToolbarButton(icon: "list.number",     help: "Lista numerada") { controller.format("ol") }
            ToolbarButton(icon: "text.quote",      help: "Citação")     { controller.format("quote") }
            ToolbarButton(icon: "minus",           help: "Linha horizontal") { controller.format("hr") }
            ToolbarDivider()
            ToolbarButton(icon: "note.text", help: "Sidenote (⇧⌘D)") { controller.format("sidenote") }

            Spacer()

            Menu {
                Button("Exportar PDF…") {
                    controller.exportPDF(suggestedName: note.title)
                }
                Button("Exportar HTML…") {
                    controller.exportHTML(suggestedName: note.title, title: note.title)
                }
                Button("Exportar Markdown…") {
                    controller.exportMarkdown(noteURL: note.url, suggestedName: note.title)
                }
                Divider()
                Button("Mostrar no Finder") {
                    store.revealInFinder(note.id)
                }
            } label: {
                Label("Exportar", systemImage: "square.and.arrow.up")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private var findBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Buscar nesta nota", text: $findQuery)
                .textFieldStyle(.plain)
                .onChange(of: findQuery) { value in
                    controller.find(value)
                }
                .onSubmit { controller.findNext() }
            Button {
                controller.findPrev()
            } label: { Image(systemName: "chevron.up") }
                .buttonStyle(.borderless)
            Button {
                controller.findNext()
            } label: { Image(systemName: "chevron.down") }
                .buttonStyle(.borderless)
            Button("Fechar") {
                showFindBar = false
                findQuery = ""
                controller.clearFind()
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private var statusBar: some View {
        HStack(spacing: 14) {
            Label("\(controller.wordCount) palavras", systemImage: "textformat.size")
            Text("\(controller.charCount) caracteres")
            Text("≈ \(readingTimeLabel) de leitura")
            Spacer()
            Text(note.modifiedAt.formatted(date: .abbreviated, time: .shortened))
                .foregroundStyle(.tertiary)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
    }

    private var readingTimeLabel: String {
        let minutes = max(1, Int((Double(controller.wordCount) / max(60, wpm)).rounded(.up)))
        return minutes == 1 ? "1 min" : "\(minutes) min"
    }

    private func commitTags() {
        let tags = tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        store.updateTags(note.id, tags: tags)
    }
}

// MARK: - Toolbar pieces

private struct ToolbarButton: View {
    let icon: String
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .frame(width: 26, height: 22)
        }
        .buttonStyle(.borderless)
        .help(help)
    }
}

private struct ToolbarTextButton: View {
    let label: String
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(.caption, design: .serif).bold())
                .frame(width: 26, height: 22)
        }
        .buttonStyle(.borderless)
        .help(help)
    }
}

private struct ToolbarDivider: View {
    var body: some View {
        Divider()
            .frame(height: 16)
            .padding(.horizontal, 4)
    }
}

// MARK: - WebView wrapper

struct TufteWebView: NSViewRepresentable {
    @ObservedObject var controller: EditorController
    let noteID: UUID
    let initialMarkdown: String
    let theme: AppTheme
    let fontSize: Double
    @EnvironmentObject var store: NotesStore

    func makeCoordinator() -> Coordinator {
        Coordinator(noteID: noteID, controller: controller, store: store,
                    theme: theme, fontSize: fontSize, initialMarkdown: initialMarkdown)
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let userContent = WKUserContentController()
        userContent.add(context.coordinator, name: "save")
        userContent.add(context.coordinator, name: "stats")
        config.userContentController = userContent
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")

        if let url = Bundle.module.url(forResource: "editor", withExtension: "html") {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
        context.coordinator.webView = webView
        controller.webView = webView
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        // Note swaps recreate the whole view via `.id(note.id)`, so no per-update
        // sync is needed here.
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        let noteID: UUID
        let controller: EditorController
        weak var store: NotesStore?
        weak var webView: WKWebView?
        var theme: AppTheme
        var fontSize: Double
        var initialMarkdown: String

        init(noteID: UUID, controller: EditorController, store: NotesStore,
             theme: AppTheme, fontSize: Double, initialMarkdown: String) {
            self.noteID = noteID
            self.controller = controller
            self.store = store
            self.theme = theme
            self.fontSize = fontSize
            self.initialMarkdown = initialMarkdown
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            controller.ready = true
            controller.setTheme(theme)
            controller.setFontSize(fontSize)
            let escaped = initialMarkdown
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "`", with: "\\`")
                .replacingOccurrences(of: "$", with: "\\$")
            webView.evaluateJavaScript("window.tufte.load(`\(escaped)`);", completionHandler: nil)
        }

        func userContentController(_ userContentController: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            switch message.name {
            case "save":
                guard let md = message.body as? String else { return }
                store?.update(noteID, body: md)
            case "stats":
                guard let dict = message.body as? [String: Any] else { return }
                controller.wordCount = dict["words"] as? Int ?? 0
                controller.charCount = dict["chars"] as? Int ?? 0
            default:
                break
            }
        }
    }
}
