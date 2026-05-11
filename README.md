# Tufte Notes

Um app de notas para macOS inspirado em Edward Tufte: tipografia serifada,
margens generosas, sidenotes na margem direita, editor estilo Medium que
renderiza o estilo final enquanto você escreve. Notas ficam como arquivos
Markdown em `~/Documents/TufteNotes/`.

## Features

- **Editor WYSIWYG estilo Tufte** num `WKWebView` com `contenteditable`.
- **Toolbar de formatação** (negrito, itálico, código, H1–H3, listas, citação,
  régua, sidenote) — botões + atalhos.
- **Sidenotes** via sintaxe `^[texto]` ou pelo botão da toolbar.
- **Tema** claro / escuro / seguir sistema (Preferências, ⌘,).
- **Tamanho da fonte** ajustável em Preferências.
- **Tags por nota** (frontmatter YAML simples) com filtros chip na sidebar.
- **Fixar notas** (pin) — vão pro topo da lista.
- **Busca global** (sidebar) e **busca dentro da nota** (⌘F) com highlight e
  navegação prev/next.
- **Contagem de palavras + tempo estimado de leitura** na barra de status.
- **Exportar** para PDF (estilo Tufte renderizado), HTML standalone com CSS
  embutido, ou cópia do Markdown.
- **Auto-save** debounced em 350 ms — cada nota é um `.md` na pasta.

## Atalhos

| Atalho      | Ação                       |
| ----------- | -------------------------- |
| ⌘N          | Nova nota                  |
| ⌘,          | Preferências               |
| ⌘B / ⌘I     | Negrito / Itálico          |
| ⌥⌘1/2/3     | H1 / H2 / H3               |
| ⇧⌘D         | Sidenote                   |
| ⌘F          | Buscar nesta nota          |

## Sintaxe de escrita

| Você digita         | Vira                                       |
| ------------------- | ------------------------------------------ |
| `# `, `## `, `### ` | Cabeçalhos (transformam no espaço)         |
| `- ` ou `* `        | Lista                                      |
| `> `                | Citação                                    |
| `---` + Enter       | Régua horizontal                           |
| `**texto**`         | **negrito**                                |
| `*texto*`           | *itálico*                                  |
| `` `código` ``      | código inline                              |
| `^[aside]`          | sidenote na margem direita                 |

## Compilando

Projeto SwiftPM — não precisa abrir o Xcode. Requer apenas Command Line Tools
(`xcode-select --install`).

```sh
./build-app.sh          # build release → TufteNotes.app
./build-app.sh --run    # build + abre
./build-app.sh --debug  # debug
```

O script roda `swift build`, monta o `.app` bundle (binário em
`Contents/MacOS/`, recursos em `Contents/Resources/`, `Info.plist` gerado),
e codesigna ad-hoc para o Gatekeeper deixar abrir localmente.

Também dá pra abrir `Package.swift` direto no Xcode (`File → Open → Package.swift`)
e rodar com ⌘R.

## Estrutura

```
TufteNotes/
├── TufteNotesApp.swift          # @main, menus, Settings scene
├── ContentView.swift            # NavigationSplitView root
├── Models/
│   ├── Note.swift
│   └── NotesStore.swift         # I/O dos .md + frontmatter (tags, pinned)
├── Views/
│   ├── SidebarView.swift        # Busca, filtro de tags, lista, pin
│   ├── SettingsView.swift       # Preferências (tema, fonte, WPM)
│   ├── EditorController.swift   # Ponte SwiftUI ↔ WKWebView + export
│   └── TufteEditorView.swift    # Meta bar, toolbar, find bar, status bar
└── Resources/
    ├── editor.html
    ├── tufte.css                # Tema light/dark, font-size variável
    └── editor.js                # MD ↔ HTML, formats, find, stats
```

## Formato dos arquivos

Cada nota é um `.md` com frontmatter opcional:

```markdown
---
tags: [filosofia, ensaio]
pinned: true
---
# Sobre o estilo

Conteúdo...
```

Sem tags e sem pin, o frontmatter é omitido — o arquivo é Markdown puro,
versionável e legível por qualquer outro editor.

## Limitações conhecidas

- Markdown ↔ HTML é um subset (sem tabelas, links reference-style, listas
  aninhadas). Cobre o que escrita estilo Tufte normalmente pede.
- ET Book não vem bundlado. Fallback: *Iowan Old Style* → *Palatino* → *Georgia*.
  Pra usar ET Book, dropa os OTFs em `Resources/` e adiciona `@font-face` no
  `tufte.css`.
- O export PDF respeita o tema atual da janela — exporte em modo claro se
  quiser PDF de fundo bege Tufte clássico.
