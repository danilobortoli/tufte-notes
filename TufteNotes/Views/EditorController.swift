import SwiftUI
import WebKit
import UniformTypeIdentifiers

@MainActor
final class EditorController: ObservableObject {
    weak var webView: WKWebView?
    @Published var wordCount: Int = 0
    @Published var charCount: Int = 0
    @Published var readingMinutes: Int = 0
    @Published var ready: Bool = false

    func run(_ js: String) {
        webView?.evaluateJavaScript(js, completionHandler: nil)
    }

    func format(_ action: String) {
        let escaped = action.replacingOccurrences(of: "'", with: "\\'")
        run("window.tufte.format('\(escaped)')")
    }

    func setTheme(_ theme: AppTheme) {
        run("window.tufte.setTheme('\(theme.rawValue)')")
    }

    func setFontSize(_ size: Double) {
        run("window.tufte.setFontSize(\(size))")
    }

    func find(_ query: String) {
        let escaped = query
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
        run("window.tufte.find(`\(escaped)`)")
    }

    func findNext() { run("window.tufte.findNext()") }
    func findPrev() { run("window.tufte.findPrev()") }
    func clearFind() { run("window.tufte.clearFind()") }

    // MARK: - Export

    func exportPDF(suggestedName: String) {
        guard let webView else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = "\(suggestedName).pdf"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            let config = WKPDFConfiguration()
            webView.createPDF(configuration: config) { result in
                if case .success(let data) = result {
                    try? data.write(to: url)
                }
            }
        }
    }

    func exportHTML(suggestedName: String, title: String) {
        guard let webView else { return }
        let cssURL = Bundle.module.url(forResource: "tufte", withExtension: "css")
        let css = cssURL.flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? ""

        let escapedTitle = title
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")

        webView.evaluateJavaScript("document.getElementById('editor').innerHTML") { value, _ in
            let inner = (value as? String) ?? ""
            let html = """
            <!DOCTYPE html>
            <html lang="pt-br">
            <head>
            <meta charset="utf-8">
            <title>\(escapedTitle)</title>
            <style>\(css)</style>
            </head>
            <body>
            <article><div id="editor">\(inner)</div></article>
            </body>
            </html>
            """
            let panel = NSSavePanel()
            panel.allowedContentTypes = [.html]
            panel.nameFieldStringValue = "\(suggestedName).html"
            panel.begin { response in
                guard response == .OK, let url = panel.url else { return }
                try? html.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }

    func exportMarkdown(noteURL: URL, suggestedName: String) {
        let panel = NSSavePanel()
        if let md = UTType(filenameExtension: "md") {
            panel.allowedContentTypes = [md]
        }
        panel.nameFieldStringValue = "\(suggestedName).md"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            try? FileManager.default.copyItem(at: noteURL, to: url)
        }
    }
}
