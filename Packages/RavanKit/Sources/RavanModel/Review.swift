import Foundation

/// Leitner state of one word. `box` runs 1…5; `Leitner.masteredBox` means learned.
public struct ReviewCard: Hashable, Sendable {
    public var wordID: String
    public var box: Int
    public var dueAt: Date
    public var reviewCount: Int
    public var correctCount: Int
    public var lastReviewedAt: Date?
    public var addedAt: Date

    public init(
        wordID: String,
        box: Int = 1,
        dueAt: Date,
        reviewCount: Int = 0,
        correctCount: Int = 0,
        lastReviewedAt: Date? = nil,
        addedAt: Date
    ) {
        self.wordID = wordID
        self.box = box
        self.dueAt = dueAt
        self.reviewCount = reviewCount
        self.correctCount = correctCount
        self.lastReviewedAt = lastReviewedAt
        self.addedAt = addedAt
    }

    public var isMastered: Bool { box >= Leitner.masteredBox }
    public func isDue(at now: Date) -> Bool { dueAt <= now }
}

public enum ReviewDirection: String, CaseIterable, Sendable, Identifiable {
    case englishToPersian, persianToEnglish, mixed
    public var id: String { rawValue }

    public var persianLabel: String {
        switch self {
        case .englishToPersian: "انگلیسی ← فارسی"
        case .persianToEnglish: "فارسی ← انگلیسی"
        case .mixed: "ترکیبی"
        }
    }
}

/// One card in a review session.
public struct ReviewItem: Identifiable, Hashable, Sendable {
    public var word: Word
    public var card: ReviewCard
    public var direction: ReviewDirection
    public var id: String { word.id }

    public init(word: Word, card: ReviewCard, direction: ReviewDirection) {
        self.word = word
        self.card = card
        self.direction = direction
    }
}

public struct DayActivity: Identifiable, Hashable, Sendable {
    public var day: Date
    public var reviewed: Int
    public var correct: Int
    public var id: Date { day }

    public init(day: Date, reviewed: Int, correct: Int) {
        self.day = day
        self.reviewed = reviewed
        self.correct = correct
    }
}

public struct ReviewStats: Sendable {
    public var dueCount: Int
    public var totalCards: Int
    public var masteredCount: Int
    /// Index 0…4 → boxes 1…5, index 5 → mastered.
    public var boxCounts: [Int]
    public var streakDays: Int
    public var reviewedToday: Int
    public var dailyGoal: Int
    public var lastSevenDays: [DayActivity]

    public init(
        dueCount: Int,
        totalCards: Int,
        masteredCount: Int,
        boxCounts: [Int],
        streakDays: Int,
        reviewedToday: Int,
        dailyGoal: Int,
        lastSevenDays: [DayActivity]
    ) {
        self.dueCount = dueCount
        self.totalCards = totalCards
        self.masteredCount = masteredCount
        self.boxCounts = boxCounts
        self.streakDays = streakDays
        self.reviewedToday = reviewedToday
        self.dailyGoal = dailyGoal
        self.lastSevenDays = lastSevenDays
    }

    public var accuracy: Double {
        let reviewed = lastSevenDays.reduce(0) { $0 + $1.reviewed }
        guard reviewed > 0 else { return 0 }
        return Double(lastSevenDays.reduce(0) { $0 + $1.correct }) / Double(reviewed)
    }

    public var goalProgress: Double {
        min(1, Double(reviewedToday) / Double(max(dailyGoal, 1)))
    }
}

/// Consecutive days with at least one review, ending today — or yesterday, so a streak
/// is not shown as broken before the user had a chance to review today.
public func calculateStreak(activeDays: Set<Date>, today: Date, calendar: Calendar = .current) -> Int {
    let startOfToday = calendar.startOfDay(for: today)
    let normalized = Set(activeDays.map { calendar.startOfDay(for: $0) })
    guard let yesterday = calendar.date(byAdding: .day, value: -1, to: startOfToday) else { return 0 }
    var cursor: Date
    if normalized.contains(startOfToday) {
        cursor = startOfToday
    } else if normalized.contains(yesterday) {
        cursor = yesterday
    } else {
        return 0
    }
    var streak = 0
    while normalized.contains(cursor) {
        streak += 1
        guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
        cursor = previous
    }
    return streak
}
