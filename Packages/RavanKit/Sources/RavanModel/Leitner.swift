import Foundation

/// Classic Leitner spaced repetition — the same rules as the Android app:
/// a correct answer moves a card one box forward and further into the future,
/// a wrong answer sends it back to box 1, due again immediately.
public enum Leitner {
    public static let boxCount = 5
    public static let masteredBox = boxCount + 1

    /// Days to wait after landing in box n (index = box - 1). The last entry is for mastered cards.
    private static let intervalDays = [1, 2, 4, 8, 16, 60]

    public static func newCard(wordID: String, now: Date = .now) -> ReviewCard {
        ReviewCard(wordID: wordID, box: 1, dueAt: now, addedAt: now)
    }

    public static func answer(_ card: ReviewCard, correct: Bool, now: Date = .now) -> ReviewCard {
        var next = card
        next.box = correct ? min(card.box + 1, masteredBox) : 1
        next.dueAt = correct ? now.addingTimeInterval(TimeInterval(intervalDays[next.box - 1]) * 86_400) : now
        next.reviewCount += 1
        next.correctCount += correct ? 1 : 0
        next.lastReviewedAt = now
        return next
    }

    public static func intervalDays(forBox box: Int) -> Int {
        intervalDays[max(0, min(box - 1, intervalDays.count - 1))]
    }
}
