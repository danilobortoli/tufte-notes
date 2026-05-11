# tufte-notes

A small macOS notes app with a Tufte-inspired writing surface. Notes are stored
as plain Markdown files in `~/Documents/TufteNotes/`.

## What's in the box

- **SwiftUI macOS app** with a sidebar (`NavigationSplitView`) and a rich editor.
- **WKWebView editor** that renders Markdown live in Tufte styling (ET Book–style
  serif, generous margins, sidenotes in the right margin).
- **Medium-style live transforms**: typing `# `, `## `, `- `, `> `, `---` at the
  start of a line transforms the block in place.
- **Sidenotes** via `^[text]` syntax — appears as a marginalia note next to the
  paragraph (Tufte's signature element).
- **Full-text search** in the sidebar.
- **Auto-save** debounced at 350 ms; each note is a single `.md` file.

## Project layout

```
TufteNotes/
├── TufteNotesApp.swift        # App entry, ⌘N shortcut, window config
├── ContentView.swift          # NavigationSplitView root
├── Models/
│   ├── Note.swift             # Note model
│   └── NotesStore.swift       # Reads/writes ~/Documents/TufteNotes/*.md
├── Views/
│   ├── SidebarView.swift      # Search field + notes list + "New Note"
│   └── TufteEditorView.swift  # NSViewRepresentable around WKWebView
└── Resources/
    ├── editor.html            # Bare contenteditable shell
    ├── tufte.css              # Tufte typography & sidenote layout
    └── editor.js              # MD <-> HTML, live shortcuts, save bridge
```

## Building it

The project is a Swift Package — no Xcode GUI needed. You do need the Swift
toolchain on macOS (`xcode-select --install` is enough; full Xcode also works).

```sh
./build-app.sh          # release build → TufteNotes.app in repo root
./build-app.sh --run    # build + launch
./build-app.sh --debug  # debug build
```

What the script does:

1. `swift build -c release` produces the binary in `.build/release/`.
2. It assembles a `TufteNotes.app` bundle next to the repo: copies the binary
   into `Contents/MacOS/`, copies the SPM-generated resource bundle
   (`TufteNotes_TufteNotes.bundle`) into `Contents/Resources/`, writes an
   `Info.plist`, and ad-hoc codesigns so Gatekeeper lets it launch.

First-run Gatekeeper note: an ad-hoc signed `.app` opens cleanly on the same
Mac it was built on, but if you copy it elsewhere you'll get the "unidentified
developer" dialog — right-click → Open the first time to bypass.

### Or use Xcode if you prefer

You can also open `Package.swift` directly in Xcode (File → Open → pick
`Package.swift`). Xcode treats SwiftPM packages as first-class projects: hit ⌘R
and it'll build and run the executable target.

## Editor cheatsheet

| You type            | You get                                        |
| ------------------- | ---------------------------------------------- |
| `# ` then text      | H1 title                                       |
| `## ` then text     | H2 section                                     |
| `### ` then text    | H3 subsection                                  |
| `- ` then text      | Unordered list                                 |
| `> ` then text      | Blockquote                                     |
| `---` Enter         | Horizontal rule                                |
| `**bold**`          | **bold** (rendered on next reload)             |
| `*italic*`          | *italic*                                       |
| `` `code` ``        | inline code                                    |
| `^[an aside]`       | sidenote in the right margin                   |
| ⌘N                  | New note                                       |

## Where notes live

`~/Documents/TufteNotes/` — every note is one `.md` file. You can edit them with
any other editor, version them with git, drop a folder of existing notes there
and the app picks them up on next launch.

## Known sharp edges

- The Markdown ↔ HTML round-trip is intentionally minimal (no tables, no
  reference-style links, no nested lists). It handles the subset Tufte writing
  actually uses.
- The first paragraph after a heading shares the same column width — wide
  digressions still go in `^[ ]` sidenotes.
- ET Book is not bundled. The CSS falls back to *Iowan Old Style* → *Palatino* →
  *Georgia*. To use ET Book, drop the OTF files into `Resources/` and add an
  `@font-face` block to `tufte.css`.
