import Foundation
import Testing
@testable import RavanModel

@Suite("Leitner scheduler")
struct LeitnerTests {
    let now = Date(timeIntervalSince1970: 1_700_000_000)

    @Test func correctAnswerMovesCardForward() {
        let next = Leitner.answer(Leitner.newCard(wordID: "w", now: now), correct: true, now: now)
        #expect(next.box == 2)
        #expect(next.dueAt == now.addingTimeInterval(2 * 86_400))
        #expect(next.correctCount == 1)
    }

    @Test func wrongAnswerResetsToFirstBox() {
        var card = Leitner.newCard(wordID: "w", now: now)
        card.box = 4
        let next = Leitner.answer(card, correct: false, now: now)
        #expect(next.box == 1)
        #expect(next.dueAt == now)
        #expect(next.reviewCount == 1)
    }

    @Test func lastBoxBecomesMastered() {
        var card = Leitner.newCard(wordID: "w", now: now)
        card.box = Leitner.boxCount
        #expect(Leitner.answer(card, correct: true, now: now).isMastered)
    }
}

@Suite("Persian text")
struct PersianTextTests {
    @Test func digitsAreConverted() {
        #expect("12 کارت".persianDigits == "۱۲ کارت")
        #expect(305.persianDigits == "۳۰۵")
    }

    @Test func normalizerUnifiesLetterVariants() {
        #expect(SearchNormalizer.normalize("مي‌شود") == SearchNormalizer.normalize("میشود"))
        #expect(SearchNormalizer.normalize("كتاب") == SearchNormalizer.normalize("کتاب"))
        #expect(SearchNormalizer.normalize("  Water ") == "water")
    }
}

@Suite("Streak")
struct StreakTests {
    let calendar = Calendar(identifier: .gregorian)
    let today = Date(timeIntervalSince1970: 1_700_000_000)

    func day(_ offset: Int) -> Date { calendar.date(byAdding: .day, value: offset, to: today)! }

    @Test func countsConsecutiveDays() {
        #expect(calculateStreak(activeDays: [day(0), day(-1), day(-2), day(-4)], today: today, calendar: calendar) == 3)
    }

    @Test func survivesUntilEndOfToday() {
        #expect(calculateStreak(activeDays: [day(-1), day(-2)], today: today, calendar: calendar) == 2)
    }

    @Test func brokenStreakIsZero() {
        #expect(calculateStreak(activeDays: [day(-3)], today: today, calendar: calendar) == 0)
    }
}

@Suite("Backup format")
struct BackupTests {
    /// A document written by the Android app must decode on iOS.
    @Test func decodesAndroidDocument() throws {
        let json = """
        {"app":"ravan","formatVersion":1,"exportedAt":1700000000000,"platform":"android",
         "words":[{"id":"seed-water","text":"water","meanings":[{"translation":"آب"}],"level":null}],
         "cards":[{"wordId":"seed-water","box":2,"dueAt":1700000000000}],
         "decks":[{"id":"d1","name":"Food","wordIds":["seed-water"]}],
         "reviewLogs":[]}
        """
        let document = try JSONDecoder().decode(BackupDocument.self, from: Data(json.utf8))
        #expect(document.words.first?.word.text == "water")
        #expect(document.cards.first?.card.box == 2)
        #expect(document.decks.first?.wordIds == ["seed-water"])
    }

    @Test func seedIDsMatchAndroid() {
        #expect(seedWordID(for: " Give Up ") == "seed-give-up")
    }
}
