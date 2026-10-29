import SwiftUI
import UIKit

/// Brand palette: Persian turquoise with a saffron accent (same as the Android app).
public enum RavanColor {
    public static let brand = Color(light: 0x006A71, dark: 0x80D4DB)
    public static let brandContainer = Color(light: 0xB8ECF0, dark: 0x004F55)
    public static let saffron = Color(light: 0x7A5900, dark: 0xF2BF48)
    public static let saffronContainer = Color(light: 0xFFDEA6, dark: 0x5C4200)
    public static let success = Color(light: 0x2E6C00, dark: 0x8FDA5D)
    public static let danger = Color(light: 0xBA1A1A, dark: 0xFFB4AB)

    /// Colours a user can pick for a deck.
    public static let decks: [Color] = [
        Color(light: 0x006A71, dark: 0x80D4DB),
        Color(light: 0x8A5100, dark: 0xFFB86E),
        Color(light: 0xA0304B, dark: 0xFFB1C1),
        Color(light: 0x4355B9, dark: 0xBAC3FF),
        Color(light: 0x2E6C00, dark: 0x8FDA5D),
        Color(light: 0x7D3EA8, dark: 0xE6B4FF),
        Color(light: 0x52634F, dark: 0xB9CCB4),
        Color(light: 0x9A4521, dark: 0xFFB597),
    ]

    public static func deck(_ index: Int) -> Color {
        decks[((index % decks.count) + decks.count) % decks.count]
    }
}

public extension Color {
    /// A colour that adapts to light / dark appearance.
    nonisolated init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor.dynamic(light: light, dark: dark))
    }
}

extension UIColor {
    /// SwiftUI resolves dynamic colours on its background render thread
    /// (`com.apple.SwiftUI.AsyncRenderer`), so the provider must not be main-actor isolated —
    /// this module uses default main-actor isolation, hence the explicit `nonisolated`/`@Sendable`.
    nonisolated static func dynamic(light: UInt32, dark: UInt32) -> UIColor {
        let lightColor = UIColor(hex: light)
        let darkColor = UIColor(hex: dark)
        return UIColor { @Sendable traits in
            traits.userInterfaceStyle == .dark ? darkColor : lightColor
        }
    }

    nonisolated convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

public extension Font {
    /// English headwords use New York (serif) so they stand apart from Persian at a glance.
    static func headword(_ style: Font.TextStyle = .largeTitle) -> Font {
        .system(style, design: .serif, weight: .bold)
    }

    static let englishSentence = Font.system(.body, design: .serif)
    static let phonetic = Font.system(.subheadline, design: .default)
}
