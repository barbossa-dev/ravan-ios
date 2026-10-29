import SwiftUI

/// A soft turquoise / saffron mesh behind every screen, so Liquid Glass surfaces have
/// colour to refract. Static (no animation) to stay battery friendly.
public struct RavanBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    public init() {}

    public var body: some View {
        let dark = colorScheme == .dark
        let base: Color = dark ? Color(red: 0.05, green: 0.08, blue: 0.09) : Color(red: 0.95, green: 0.98, blue: 0.98)
        let teal: Color = dark ? Color(red: 0.0, green: 0.30, blue: 0.33) : Color(red: 0.72, green: 0.92, blue: 0.94)
        let saffron: Color = dark ? Color(red: 0.30, green: 0.22, blue: 0.02) : Color(red: 1.0, green: 0.90, blue: 0.70)
        MeshGradient(
            width: 3,
            height: 3,
            points: [
                [0, 0], [0.5, 0], [1, 0],
                [0, 0.5], [0.6, 0.45], [1, 0.5],
                [0, 1], [0.5, 1], [1, 1],
            ],
            colors: [
                teal, base, saffron.opacity(0.8),
                base, base, teal.opacity(0.6),
                saffron.opacity(0.5), base, base,
            ]
        )
        .ignoresSafeArea()
    }
}

public extension View {
    /// Places the brand mesh behind a scrollable screen.
    func ravanBackground() -> some View {
        scrollContentBackground(.hidden)
            .background { RavanBackground() }
    }
}
