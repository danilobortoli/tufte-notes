import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var label: String {
        switch self {
        case .system: return "Seguir sistema"
        case .light:  return "Claro"
        case .dark:   return "Escuro"
        }
    }
}

struct SettingsView: View {
    @AppStorage("theme") private var themeRaw: String = AppTheme.system.rawValue
    @AppStorage("editorFontSize") private var fontSize: Double = 1.4
    @AppStorage("readingWPM") private var wpm: Double = 220

    var body: some View {
        TabView {
            appearanceTab
                .tabItem { Label("Aparência", systemImage: "paintbrush") }
            readingTab
                .tabItem { Label("Leitura", systemImage: "book") }
        }
        .frame(width: 460, height: 280)
    }

    private var appearanceTab: some View {
        Form {
            Picker("Tema", selection: $themeRaw) {
                ForEach(AppTheme.allCases) { theme in
                    Text(theme.label).tag(theme.rawValue)
                }
            }
            .pickerStyle(.segmented)

            HStack {
                Text("Tamanho da fonte")
                Slider(value: $fontSize, in: 1.0...2.2, step: 0.05)
                Text(String(format: "%.2f rem", fontSize))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 70, alignment: .trailing)
            }
        }
        .padding(20)
    }

    private var readingTab: some View {
        Form {
            HStack {
                Text("Velocidade de leitura")
                Slider(value: $wpm, in: 150...350, step: 10)
                Text("\(Int(wpm)) ppm")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 80, alignment: .trailing)
            }
            Text("Usada pra estimar o tempo de leitura mostrado na barra de status.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(20)
    }
}
