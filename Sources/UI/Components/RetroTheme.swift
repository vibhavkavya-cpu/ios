import SwiftUI

enum RetroTheme {
    static let background = Color.black
    static let surface = Color(white: 0.08)
    static let elevatedSurface = Color(white: 0.14)
    static let hairline = Color.white.opacity(0.15)
    static let mutedText = Color(white: 0.55)
    static let amberAccent = Color(red: 1.0, green: 0.80, blue: 0.12) // Classic iOS 7/8 yellow-amber

    static func monoLabel(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    static func uiLabel(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
}
