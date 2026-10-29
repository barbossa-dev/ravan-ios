#if DEBUG
import Foundation
import RavanUI

/// Debug-only hooks used by the `RavanUITests` store-screenshot test.
///
/// Launch arguments:
/// - `-RavanScreenshots` turns the mode on and installs a sample study history (review cards,
///   review logs, decks, recently viewed and favourite words) built from real dictionary entries.
/// - `-RavanScreen <home|search|library|review|session|settings|word:<text>>` opens a screen.
/// - `-settings.theme <light|dark>` forces the theme (plain UserDefaults argument domain).
///
/// Nothing here is compiled into Release builds.
@MainActor
enum ScreenshotMode {
    private static var arguments: [String] { ProcessInfo.processInfo.arguments }

    static var isEnabled: Bool { arguments.contains("-RavanScreenshots") }

    private static func value(after flag: String) -> String? {
        guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count else { return nil }
        return arguments[index + 1]
    }

    static func apply(store: DictionaryStore, router: AppRouter) {
        guard isEnabled else { return }
        DemoLibrary.install(into: store)

        let screen = value(after: "-RavanScreen") ?? "home"
        switch screen {
        case "search": router.selectedTab = .search
        case "library": router.selectedTab = .library
        case "review": router.selectedTab = .review
        case "settings": router.selectedTab = .settings
        case "session":
            router.selectedTab = .review
            router.startReview()
        default:
            router.selectedTab = .home
            if screen.hasPrefix("word:"), let word = store.findWord(text: String(screen.dropFirst(5))) {
                router.homePath = [.word(word.id)]
            }
        }
    }
}

/// A realistic few weeks of study, expressed as a backup document so it goes through the same
/// import path as a user's own backup. Identical to the Android debug `DemoLibrary`.
enum DemoLibrary {
    static let boxes: [(box: Int, words: [String])] = [
        (1, ["achieve", "journey", "abundant", "eager", "reliable", "confident", "improve", "vocabulary", "habit", "practice"]),
        (2, ["resilient", "curious", "brave", "fluent", "memory", "challenge", "opportunity", "knowledge", "patient", "honest"]),
        (3, ["ambitious", "generous", "grateful", "obvious", "ancient", "efficient", "essential", "flexible"]),
        (4, ["accurate", "anxious", "brilliant", "capable", "diverse", "genuine"]),
        (5, ["inevitable", "meticulous", "persistent", "profound"]),
        (6, ["apple", "house", "water", "friend", "happy", "family", "travel"]),
    ]
    static let recentlyViewed = ["journey", "achieve", "reliable", "eager", "curious", "resilient", "brave"]
    static let favorites = ["resilient", "brave", "fluent", "journey"]
    static let logsPerDay = [14, 22, 9, 18, 25, 16, 11] // six days ago … today
    static let intervalDays = [1, 2, 4, 8, 16, 60]

    static func id(_ text: String) -> String { seedWordID(for: text) }

    @MainActor
    static func install(into store: DictionaryStore) {
        let now = Date.now.epochMilliseconds
        let hour: Int64 = 3_600_000
        let day: Int64 = 24 * hour

        var cards: [BackupCard] = []
        for (box, words) in boxes {
            for (index, text) in words.enumerated() {
                let due: Int64 = switch box {
                case 1: now - day + Int64(index) * 60_000           // all due, "achieve" first
                case 2 where index < 3: now - hour                  // a few more due today
                default: now + Int64(intervalDays[box - 1]) * day - Int64(index) * 3 * hour
                }
                let reviews = max(0, (box - 1) * 2 + index % 3)
                cards.append(BackupCard(
                    wordId: id(text), box: box, dueAt: due,
                    reviewCount: reviews, correctCount: max(0, reviews - index % 2),
                    lastReviewedAt: box == 1 ? nil : now - Int64(index % 3 + 1) * day,
                    addedAt: now - 21 * day
                ))
            }
        }

        let all = boxes.flatMap(\.words)
        var logs: [BackupReviewLog] = []
        for (offset, count) in logsPerDay.enumerated() {
            let daysAgo = Int64(logsPerDay.count - 1 - offset)
            for k in 0..<count {
                logs.append(BackupReviewLog(
                    id: "demo-log-\(daysAgo)-\(k)",
                    wordId: id(all[(offset * 7 + k) % all.count]),
                    reviewedAt: Date(epochMilliseconds: now - daysAgo * day - Int64(k) * 90_000),
                    correct: k % 5 != 0
                ))
            }
        }

        let created = Date(epochMilliseconds: now - 20 * day)
        let decks = [
            BackupDeck(id: "demo-deck-ielts", name: "آیلتس", colorIndex: 0, createdAt: created,
                       wordIds: (boxes[1].words + boxes[2].words).map(id)),
            BackupDeck(id: "demo-deck-504", name: "لغت‌های ۵۰۴", colorIndex: 1, createdAt: created,
                       wordIds: (boxes[0].words + boxes[3].words).map(id)),
            BackupDeck(id: "demo-deck-travel", name: "سفر", colorIndex: 2, createdAt: created,
                       wordIds: ["journey", "travel", "abundant", "ancient", "family"].map(id)),
        ]

        let document = BackupDocument(exportedAt: now, words: [], cards: cards, decks: decks, reviewLogs: logs)
        if let data = try? JSONEncoder().encode(document) {
            _ = try? store.importBackup(data)
        }
        for text in recentlyViewed { store.markViewed(wordID: id(text)) }
        for text in favorites { store.setFavorite(true, wordID: id(text)) }
    }
}

private extension BackupCard {
    init(wordId: String, box: Int, dueAt: Int64, reviewCount: Int, correctCount: Int, lastReviewedAt: Int64?, addedAt: Int64) {
        self.init(ReviewCard(
            wordID: wordId, box: box, dueAt: Date(epochMilliseconds: dueAt),
            reviewCount: reviewCount, correctCount: correctCount,
            lastReviewedAt: lastReviewedAt.map(Date.init(epochMilliseconds:)),
            addedAt: Date(epochMilliseconds: addedAt)
        ))
    }
}
#endif
