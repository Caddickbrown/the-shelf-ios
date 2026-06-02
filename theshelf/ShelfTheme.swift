import SwiftUI

// MARK: - ShelfTheme
// Design tokens mirroring the web app's CSS custom properties.
// Web: --bg #131320, --surface #1c1c2e, --accent #e2b96f, status colours matched.

enum ShelfTheme {

    // MARK: Background layers
    /// Deepest background — page/screen fill. Web: --bg #131320
    static let bg      = Color(hex: "#131320")
    /// Card/surface layer. Web: --surface #1c1c2e
    static let surface = Color(hex: "#1c1c2e")
    /// Slightly elevated surface. Web: --surface2 #252540
    static let surface2 = Color(hex: "#252540")

    // MARK: Text
    /// Primary text. Web: --text #e8e8f0
    static let text    = Color(hex: "#e8e8f0")
    /// Secondary / muted text. Web: --muted #8888aa
    static let muted   = Color(hex: "#8888aa")

    // MARK: Accent (gold)
    /// Gold accent — buttons, highlights, stars. Web: --accent #e2b96f
    static let accent  = Color(hex: "#e2b96f")
    /// Darker gold for pressed/hover states. Web: --accent2 #c99a50
    static let accent2 = Color(hex: "#c99a50")

    // MARK: Status colours (match web badge palette)
    static let green  = Color(hex: "#56c270")   // read
    static let blue   = Color(hex: "#5b9cf6")   // reading
    static let orange = Color(hex: "#f4a261")   // to-read
    static let red    = Color(hex: "#e76f51")   // DNF

    // MARK: Status badge backgrounds (web: semi-transparent fills)
    static let readBg    = Color(hex: "#1a3a1e")
    static let readingBg = Color(hex: "#1a2a4a")
    static let toReadBg  = Color(hex: "#2a2a2a")
    static let dnfBg     = Color(hex: "#3a1a1a")

    // MARK: Borders
    /// Subtle divider / card border. Web: --border #2e2e4a
    static let border = Color(hex: "#2e2e4a")

    // MARK: Helpers
    static func statusFg(_ status: ReadStatus) -> Color {
        switch status {
        case .read:    return green
        case .reading: return blue
        case .toRead:  return orange
        case .dnf:     return red
        }
    }

    static func statusBg(_ status: ReadStatus) -> Color {
        switch status {
        case .read:    return readBg
        case .reading: return readingBg
        case .toRead:  return toReadBg
        case .dnf:     return dnfBg
        }
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
    /// Shelf card: surface background with rounded corners and subtle border.
    func shelfCard(radius: CGFloat = 12) -> some View {
        self
            .background(ShelfTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: radius))
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .strokeBorder(ShelfTheme.border, lineWidth: 1)
            )
    }

    /// Full-screen shelf background.
    func shelfBackground() -> some View {
        self.background(ShelfTheme.bg.ignoresSafeArea())
    }
}
