import SwiftUI
import WebKit

struct TufteEditorView: NSViewRepresentable {
    let noteID: UUID
    let initialMarkdown: String
    @EnvironmentObject var store: NotesStore

    func makeCoordinator() -> Coordinator {
        Coordinator(noteID: noteID, store: store)
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let userContent = WKUserContentController()
        userContent.add(context.coordinator, name: "save")
        config.userContentController = userContent
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")

        if let url = Bundle.module.url(forResource: "editor", withExtension: "html") {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
        context.coordinator.pendingMarkdown = initialMarkdown
        context.coordinator.webView = webView
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        // The view is re-created when noteID changes via .id(...) in parent, so
        // we don't need to push markdown updates here.
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        let noteID: UUID
        weak var store: NotesStore?
        weak var webView: WKWebView?
        var pendingMarkdown: String = ""
        private var ready = false

        init(noteID: UUID, store: NotesStore) {
            self.noteID = noteID
            self.store = store
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            ready = true
            let escaped = pendingMarkdown
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "`", with: "\\`")
                .replacingOccurrences(of: "$", with: "\\$")
            let js = "window.tufte.load(`\(escaped)`);"
            webView.evaluateJavaScript(js, completionHandler: nil)
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "save", let body = message.body as? String else { return }
            Task { @MainActor in
                self.store?.update(self.noteID, body: body)
            }
        }
    }
}
