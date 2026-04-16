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

extension UIColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = CGFloat((int & 0xFF0000) >> 16) / 255
        let g = CGFloat((int & 0x00FF00) >> 8)  / 255
        let b = CGFloat(int & 0x0000FF)          / 255
        self.init(red: r, green: g, blue: b, alpha: 1)
    }
}

// MARK: - Design Tokens
//
// All colors are dynamic: dark-mode palette (current dark luxury look) +
// light-mode palette (warm linen / cognac / sky, from flight_diary_light_mode.html)

enum FDColor {

    // MARK: Backgrounds
    /// Deepest background — near-black (dark) / linen #F5F0E8 (light)
    static var black: Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: "0A0A0F") : UIColor(hex: "F5F0E8") })
    }
    /// Primary surface — #111118 (dark) / white (light)
    static var surface: Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: "111118") : UIColor(hex: "FFFFFF") })
    }
    /// Elevated surface — #1A1A24 (dark) / warm off-white #F9F6F0 (light)
    static var surface2: Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: "1A1A24") : UIColor(hex: "F9F6F0") })
    }
    /// Highest surface — #22222E (dark) / warm light #F0EBE1 (light)
    static var surface3: Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: "22222E") : UIColor(hex: "F0EBE1") })
    }

    // MARK: Accent
    /// Primary accent — amber gold #C9A96E (dark) / cognac #8B5E2A (light)
    static var gold: Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: "C9A96E") : UIColor(hex: "8B5E2A") })
    }
    /// Light accent — #E8C98A (dark) / warm gold #A87040 (light)
    static var goldLight: Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: "E8C98A") : UIColor(hex: "A87040") })
    }
    /// Blue accent — #4A7FA5 (dark) / steel blue #2A6080 (light)
    static var blue: Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: "4A7FA5") : UIColor(hex: "2A6080") })
    }

    // MARK: Text
    /// Primary text — warm white #F0EEE8 (dark) / warm ink #1A1410 (light)
    static var text: Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: "F0EEE8") : UIColor(hex: "1A1410") })
    }
    static var textMuted: Color { text.opacity(0.45) }
    static var textDim:   Color { text.opacity(0.25) }

    // MARK: Borders
    /// Subtle border — white/7% (dark) / warm brown tint rgba(60,45,20,0.09) (light)
    static var border: Color {
        Color(UIColor { t in
            t.userInterfaceStyle == .dark
                ? UIColor(white: 1, alpha: 0.07)
                : UIColor(red: 60/255, green: 45/255, blue: 20/255, alpha: 0.09)
        })
    }
    /// Bright border — white/15% (dark) / rgba(60,45,20,0.18) (light)
    static var borderBright: Color {
        Color(UIColor { t in
            t.userInterfaceStyle == .dark
                ? UIColor(white: 1, alpha: 0.15)
                : UIColor(red: 60/255, green: 45/255, blue: 20/255, alpha: 0.18)
        })
    }
}

// MARK: - Typography

enum FDFont {
    /// Serif — for display headings and IATA codes
    static func display(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
    /// Default — for all UI labels
    static func ui(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
}
