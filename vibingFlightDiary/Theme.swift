import SwiftUI

// MARK: - Color Helpers

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int & 0xFF0000) >> 16) / 255
        let g = Double((int & 0x00FF00) >> 8)  / 255
        let b = Double(int & 0x0000FF)          / 255
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Design Tokens

enum FDColor {
    // Backgrounds
    static let black    = Color(hex: "0A0A0F")
    static let surface  = Color(hex: "111118")
    static let surface2 = Color(hex: "1A1A24")
    static let surface3 = Color(hex: "22222E")

    // Accent
    static let gold      = Color(hex: "C9A96E")
    static let goldLight = Color(hex: "E8C98A")
    static let blue      = Color(hex: "4A7FA5")

    // Text
    static let text      = Color(hex: "F0EEE8")
    static let textMuted = Color(hex: "F0EEE8").opacity(0.45)
    static let textDim   = Color(hex: "F0EEE8").opacity(0.25)

    // Borders
    static let border       = Color.white.opacity(0.07)
    static let borderBright = Color.white.opacity(0.15)
}

// MARK: - Typography

enum FDFont {
    /// New York serif — for display headings and IATA codes
    static func display(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
    /// SF Pro — for all UI labels
    static func ui(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
}
