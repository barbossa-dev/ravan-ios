@_exported import RavanData
@_exported import RavanDesign
@_exported import RavanModel
@_exported import RavanSpeech
import SwiftUI

/// The standard row for a word in every list.
public struct WordRow: View {
    private let word: Word
    private let trailing: AnyView?

    public init(word: Word) {
        self.word = word
        self.trailing = nil
    }

    public init<Trailing: View>(word: Word, @ViewBuilder trailing: () -> Trailing) {
        self.word = word
        self.trailing = AnyView(trailing())
    }

    public var body: some View {
        HStack(spacing: 14) {
            Text(verbatim: String(word.text.prefix(1)).uppercased())
                .font(.headword(.headline))
                .foregroundStyle(RavanColor.brand)
                .frame(width: 40, height: 40)
                .background(RavanColor.brandContainer.opacity(0.6), in: .circle)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: word.text)
                    .font(.headword(.headline))
                    .lineLimit(1)
                Text(word.primaryTranslation)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            if let trailing {
                trailing
            } else if word.isFavorite {
                Image(systemName: "star.fill")
                    .foregroundStyle(RavanColor.saffron)
                    .accessibilityLabel("نشان‌شده")
            }
        }
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}

public extension Pronouncer {
    /// Speaks with the user's accent and speed unless an accent is given.
    func speak(_ text: String, settings: SettingsStore, accent: Accent? = nil) {
        speak(text, accent: accent ?? settings.accent, rate: settings.speechRate)
    }
}

public extension ReviewCard {
    var boxLabel: String {
        isMastered ? "یاد گرفته‌شده" : "خانهٔ \(box.persianDigits)"
    }

    func dueLabel(now: Date = .now) -> String {
        let remaining = dueAt.timeIntervalSince(now)
        guard remaining > 0 else { return "آمادهٔ مرور" }
        let days = Int((remaining / 86_400).rounded(.up))
        return days <= 1 ? "مرور: فردا" : "مرور: \(days.persianDigits) روز دیگر"
    }
}
