import Foundation

/// A user-made collection of words ("دسته") that can be reviewed on its own.
public struct Deck: Identifiable, Hashable, Sendable {
    public var id: String
    public var name: String
    public var colorIndex: Int
    public var createdAt: Date
    public var wordCount: Int

    public init(id: String, name: String, colorIndex: Int, createdAt: Date, wordCount: Int = 0) {
        self.id = id
        self.name = name
        self.colorIndex = colorIndex
        self.createdAt = createdAt
        self.wordCount = wordCount
    }
}

/// Filters of the personal library. The full dictionary is reached through search.
public enum WordFilter: String, CaseIterable, Sendable, Identifiable {
    case recent, favorites, mine, inReview
    public var id: String { rawValue }

    public var persianLabel: String {
        switch self {
        case .recent: "اخیراً دیده‌شده"
        case .favorites: "نشان‌شده‌ها"
        case .mine: "لغت‌های من"
        case .inReview: "در جعبهٔ لایتنر"
        }
    }
}

public enum ThemePreference: String, CaseIterable, Sendable, Identifiable {
    case system, light, dark
    public var id: String { rawValue }

    public var persianLabel: String {
        switch self {
        case .system: "سیستم"
        case .light: "روشن"
        case .dark: "تیره"
        }
    }
}

public struct BackupSummary: Sendable, Equatable {
    public var words: Int
    public var cards: Int
    public var decks: Int
    public var reviewLogs: Int

    public init(words: Int, cards: Int, decks: Int, reviewLogs: Int) {
        self.words = words
        self.cards = cards
        self.decks = decks
        self.reviewLogs = reviewLogs
    }
}
