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

I scaffolded the source files but not the `.xcodeproj` (those are finicky to
hand-roll). To run it:

1. **Open Xcode** → File → New → Project → **macOS** → **App**.
2. Product Name: `TufteNotes`. Interface: **SwiftUI**. Language: **Swift**.
3. Save it somewhere outside this repo (or inside, your call), then **close** it.
4. Replace the generated `TufteNotesApp.swift` and `ContentView.swift` with the
   ones in this repo's `TufteNotes/` folder.
5. Drag `Models/`, `Views/`, and `Resources/` from this repo into the Xcode
   project navigator. When prompted, choose **Create groups** and tick **Copy
   items if needed** + the app target.
6. For `Resources/` make sure the files end up in **Copy Bundle Resources** under
   the target's Build Phases (drag-and-drop usually handles this, but verify
   `editor.html`, `tufte.css`, and `editor.js` are listed there).
7. In Signing & Capabilities, set a development team. The app reads/writes
   `~/Documents/TufteNotes/`, which is allowed under the default App Sandbox.
8. ⌘R to run.

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
