import SwiftUI

// MARK: - AppTheme enum
// Mirrors every theme from the web app's CSS data-theme attributes.

enum AppTheme: String, CaseIterable, Identifiable {
    // Default
    case defaultDark    = "default-dark"
    case defaultLight   = "default-light"
    // Library
    case libraryDark    = "library-dark"
    case libraryLight   = "library-light"
    // Antique
    case antiqueDark    = "antique-dark"
    case antiqueLight   = "antique-light"
    // Editorial
    case editorialDark  = "editorial-dark"
    case editorialLight = "editorial-light"
    // Midnight
    case midnightDark   = "midnight-dark"
    case midnightLight  = "midnight-light"
    // Hermes
    case hermesDark     = "hermes-dark"
    case hermesLight    = "hermes-light"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .defaultDark:    return "Default"
        case .defaultLight:   return "Default Light"
        case .libraryDark:    return "Library"
        case .libraryLight:   return "Library Light"
        case .antiqueDark:    return "Antique"
        case .antiqueLight:   return "Antique Light"
        case .editorialDark:  return "Editorial"
        case .editorialLight: return "Editorial Light"
        case .midnightDark:   return "Midnight"
        case .midnightLight:  return "Midnight Light"
        case .hermesDark:     return "Hermes"
        case .hermesLight:    return "Hermes Light"
        }
    }

    var family: String {
        switch self {
        case .defaultDark, .defaultLight:     return "Default"
        case .libraryDark, .libraryLight:     return "Library"
        case .antiqueDark, .antiqueLight:     return "Antique"
        case .editorialDark, .editorialLight: return "Editorial"
        case .midnightDark, .midnightLight:   return "Midnight"
        case .hermesDark, .hermesLight:       return "Hermes"
        }
    }

    var isDark: Bool {
        switch self {
        case .defaultDark, .libraryDark, .antiqueDark,
             .editorialDark, .midnightDark, .hermesDark: return true
        default: return false
        }
    }

    var tokens: ThemeTokens {
        switch self {
        case .defaultDark:
            return ThemeTokens(
                bg: "#131320", surface: "#1c1c2e", surface2: "#252540",
                accent: "#e2b96f", text: "#e8e8f0", muted: "#8888aa",
                green: "#56c270", blue: "#5b9cf6", orange: "#f4a261", red: "#e76f51",
                border: "#2e2e4a",
                readBg: "#1a3a1e", readingBg: "#1a2a4a", toReadBg: "#2a2a2a", dnfBg: "#3a1a1a"
            )
        case .defaultLight:
            return ThemeTokens(
                bg: "#F5F2EA", surface: "#EDE9DE", surface2: "#E4DFCF",
                accent: "#9a7830", text: "#1a1a2e", muted: "#6a6880",
                green: "#2e7d4f", blue: "#2d5fa8", orange: "#b5620a", red: "#c0392b",
                border: "#D5D0C2",
                readBg: "#e6f2eb", readingBg: "#e6ecf7", toReadBg: "#edecf0", dnfBg: "#f5e8e8"
            )
        case .libraryDark:
            return ThemeTokens(
                bg: "#1C2B1C", surface: "#233224", surface2: "#2b3d2c",
                accent: "#C9A84C", text: "#F0E8D5", muted: "#9B8E76",
                green: "#7ec99a", blue: "#7ab8d4", orange: "#d4935a", red: "#c97a5a",
                border: "#3a4e3b",
                readBg: "#1e3327", readingBg: "#1e2f3d", toReadBg: "#2a2e2a", dnfBg: "#3a2820"
            )
        case .libraryLight:
            return ThemeTokens(
                bg: "#EDF5ED", surface: "#E0EDE0", surface2: "#D3E5D3",
                accent: "#5a7a22", text: "#1C2B1C", muted: "#5a7a5a",
                green: "#2e7d4f", blue: "#2a6080", orange: "#8B5A1A", red: "#8B3A2F",
                border: "#C0D8C0",
                readBg: "#e0f0e8", readingBg: "#dceaf2", toReadBg: "#e4eee4", dnfBg: "#f0e4e0"
            )
        case .antiqueDark:
            return ThemeTokens(
                bg: "#2A1F14", surface: "#362818", surface2: "#42311E",
                accent: "#D4955A", text: "#F4EDD8", muted: "#9B8E76",
                green: "#7ec99a", blue: "#7ab8d4", orange: "#D4955A", red: "#c97a5a",
                border: "#4a3828",
                readBg: "#1e3327", readingBg: "#1e2f3d", toReadBg: "#2e2820", dnfBg: "#3a2018"
            )
        case .antiqueLight:
            return ThemeTokens(
                bg: "#F4EDD8", surface: "#EDE4C8", surface2: "#E3D9BB",
                accent: "#8B3A2F", text: "#2C2415", muted: "#7A6A50",
                green: "#4a7c59", blue: "#4a6b8a", orange: "#b5621a", red: "#8B3A2F",
                border: "#C9B99A",
                readBg: "#e4f0e8", readingBg: "#e0eaf2", toReadBg: "#eee8dc", dnfBg: "#f2e4e0"
            )
        case .editorialDark:
            return ThemeTokens(
                bg: "#181818", surface: "#222222", surface2: "#2c2c2c",
                accent: "#E8384F", text: "#F5F5F5", muted: "#888888",
                green: "#4caf6e", blue: "#5a9fd4", orange: "#e0872a", red: "#E8384F",
                border: "#333333",
                readBg: "#1e3028", readingBg: "#1e2c38", toReadBg: "#282828", dnfBg: "#381820"
            )
        case .editorialLight:
            return ThemeTokens(
                bg: "#FAFAF7", surface: "#F2F0EB", surface2: "#E8E5DE",
                accent: "#C41E3A", text: "#111111", muted: "#666666",
                green: "#2d6a4f", blue: "#1a5c8c", orange: "#b5620a", red: "#C41E3A",
                border: "#E0DDD6",
                readBg: "#e4f0ea", readingBg: "#e0ecf5", toReadBg: "#ebebeb", dnfBg: "#f5e0e4"
            )
        case .midnightDark:
            return ThemeTokens(
                bg: "#0C0C0C", surface: "#161616", surface2: "#1e1e1e",
                accent: "#C8A97E", text: "#F2F2F2", muted: "#666666",
                green: "#5a9e72", blue: "#6a94bf", orange: "#d4905a", red: "#c96a5a",
                border: "#2a2418",
                readBg: "#1a2e22", readingBg: "#1a2430", toReadBg: "#1e1e1e", dnfBg: "#2e1a18"
            )
        case .midnightLight:
            return ThemeTokens(
                bg: "#F8F6F2", surface: "#EEE9DF", surface2: "#E4DDD2",
                accent: "#8a6a3a", text: "#1a1510", muted: "#7a6a5a",
                green: "#3a7a52", blue: "#3a6080", orange: "#9a6020", red: "#9a3a30",
                border: "#D5CCC0",
                readBg: "#e4f0e8", readingBg: "#e0eaf0", toReadBg: "#eeeae4", dnfBg: "#f2e4e0"
            )
        case .hermesDark:
            return ThemeTokens(
                bg: "#041C1C", surface: "#0a2626", surface2: "#0f2f2f",
                accent: "#ffe6cb", text: "#ffe6cb", muted: "#6a9a9a",
                green: "#56c270", blue: "#5b9cf6", orange: "#f4a261", red: "#e76f51",
                border: "#1a3a3a",
                readBg: "#0e3020", readingBg: "#0e2038", toReadBg: "#0f2828", dnfBg: "#2a1410"
            )
        case .hermesLight:
            return ThemeTokens(
                bg: "#e8f2f2", surface: "#d8eaea", surface2: "#c8e0e0",
                accent: "#041C1C", text: "#041C1C", muted: "#3a7a7a",
                green: "#2e7d4f", blue: "#2d5fa8", orange: "#b5620a", red: "#c0392b",
                border: "#B0D0D0",
                readBg: "#d8ede0", readingBg: "#d8e8f5", toReadBg: "#d8e8e8", dnfBg: "#f0ddd8"
            )
        }
    }
}

// MARK: - ThemeTokens

struct ThemeTokens {
    let bg: String
    let surface: String
    let surface2: String
    let accent: String
    let text: String
    let muted: String
    let green: String
    let blue: String
    let orange: String
    let red: String
    let border: String
    // Status badge backgrounds
    let readBg: String
    let readingBg: String
    let toReadBg: String
    let dnfBg: String
}

// MARK: - ShelfTheme
// Active theme wrapper. Reads from @AppStorage and exposes typed Colors.

@Observable
final class ShelfTheme {

    static let shared = ShelfTheme()
    private init() {}

    var current: AppTheme = .defaultDark {
        didSet { UserDefaults.standard.set(current.rawValue, forKey: "shelf.theme") }
    }

    func load() {
        let saved = UserDefaults.standard.string(forKey: "shelf.theme") ?? AppTheme.defaultDark.rawValue
        current = AppTheme(rawValue: saved) ?? .defaultDark
    }

    // MARK: - Convenience colour accessors

    var bg:       Color { Color(hex: current.tokens.bg) }
    var surface:  Color { Color(hex: current.tokens.surface) }
    var surface2: Color { Color(hex: current.tokens.surface2) }
    var accent:   Color { Color(hex: current.tokens.accent) }
    var text:     Color { Color(hex: current.tokens.text) }
    var muted:    Color { Color(hex: current.tokens.muted) }
    var green:    Color { Color(hex: current.tokens.green) }
    var blue:     Color { Color(hex: current.tokens.blue) }
    var orange:   Color { Color(hex: current.tokens.orange) }
    var red:      Color { Color(hex: current.tokens.red) }
    var border:   Color { Color(hex: current.tokens.border) }

    func statusFg(_ status: ReadStatus) -> Color {
        switch status {
        case .read:    return green
        case .reading: return blue
        case .toRead:  return orange
        case .dnf:     return red
        }
    }

    func statusBg(_ status: ReadStatus) -> Color {
        let t = current.tokens
        switch status {
        case .read:    return Color(hex: t.readBg)
        case .reading: return Color(hex: t.readingBg)
        case .toRead:  return Color(hex: t.toReadBg)
        case .dnf:     return Color(hex: t.dnfBg)
        }
    }

    var colorScheme: ColorScheme {
        current.isDark ? .dark : .light
    }
}

// MARK: - Color hex initialiser

extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: .init(charactersIn: "#"))
        var rgb: UInt64 = 0
        Scanner(string: h).scanHexInt64(&rgb)
        let r = Double((rgb >> 16) & 0xFF) / 255
        let g = Double((rgb >>  8) & 0xFF) / 255
        let b = Double((rgb      ) & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - View modifiers

extension View {
    func shelfCard(radius: CGFloat = 12) -> some View {
        modifier(ShelfCardModifier(radius: radius))
    }
    func shelfBackground() -> some View {
        modifier(ShelfBackgroundModifier())
    }
}

private struct ShelfCardModifier: ViewModifier {
    @Environment(ShelfTheme.self) var theme
    let radius: CGFloat
    func body(content: Content) -> some View {
        content
            .background(theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: radius))
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .strokeBorder(theme.border, lineWidth: 1)
            )
    }
}

private struct ShelfBackgroundModifier: ViewModifier {
    @Environment(ShelfTheme.self) var theme
    func body(content: Content) -> some View {
        content.background(theme.bg.ignoresSafeArea())
    }
}

// MARK: - ThemePickerView (used in Settings)

struct ThemePickerView: View {
    @Environment(ShelfTheme.self) var theme

    // Group themes by family for a cleaner picker
    private var families: [(String, [AppTheme])] {
        var seen: [String: [AppTheme]] = [:]
        var order: [String] = []
        for t in AppTheme.allCases {
            if seen[t.family] == nil { order.append(t.family) }
            seen[t.family, default: []].append(t)
        }
        return order.map { ($0, seen[$0]!) }
    }

    var body: some View {
        List {
            ForEach(families, id: \.0) { family, variants in
                Section(family) {
                    ForEach(variants) { appTheme in
                        ThemeRow(appTheme: appTheme, isSelected: theme.current == appTheme) {
                            theme.current = appTheme
                        }
                        .listRowBackground(Color(hex: appTheme.tokens.bg))
                    }
                }
            }
        }
        .navigationTitle("Theme")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ThemeRow: View {
    let appTheme: AppTheme
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Mini swatch
                HStack(spacing: 3) {
                    ForEach([appTheme.tokens.accent, appTheme.tokens.green,
                             appTheme.tokens.blue, appTheme.tokens.orange], id: \.self) { hex in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(hex: hex))
                            .frame(width: 12, height: 24)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 4))

                Text(appTheme.displayName)
                    .foregroundStyle(Color(hex: appTheme.tokens.text))
                    .font(.body)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color(hex: appTheme.tokens.accent))
                        .font(.body.bold())
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }
}
