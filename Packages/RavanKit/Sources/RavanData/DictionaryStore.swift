import Foundation
import Observation
import RavanModel
import SwiftData

/// The app's single source of truth (repository over SwiftData).
///
/// It exposes plain value types (`Word`, `ReviewCard`, `Deck`) so views never touch persistence
/// objects. Every mutation saves and bumps `revision`; screens reload with
/// `.task(id: store.revision)`, which gives the same reactive behaviour as Room flows on Android.
@MainActor
@Observable
public final class DictionaryStore {
    public enum Status: Equatable, Sendable {
        case preparing
        case ready
        case failed(String)
    }

    public private(set) var revision = 0
    public private(set) var status: Status = .ready

    @ObservationIgnored public let container: ModelContainer
    @ObservationIgnored private var context: ModelContext { container.mainContext }

    public init(container: ModelContainer) {
        self.container = container
    }

    // MARK: - Setup

    /// Imports the bundled dictionary the first time the app runs (or after an update).
    public func prepare() async {
        guard DictionarySeeder.needsSeeding else { return }
        status = .preparing
        do {
            try await DictionarySeeder(modelContainer: container).seedIfNeeded()
            status = .ready
        } catch {
            status = .failed(error.localizedDescription)
        }
        revision += 1
    }

    // MARK: - Words

    public func word(id: String) -> Word? {
        record(id: id)?.word
    }

    public func wordCount() -> Int {
        (try? context.fetchCount(FetchDescriptor<WordRecord>())) ?? 0
    }

    public func words(filter: WordFilter, limit: Int = 300) -> [Word] {
        var descriptor: FetchDescriptor<WordRecord>
        switch filter {
        case .recent:
            descriptor = FetchDescriptor(
                predicate: #Predicate { $0.lastViewedAt != nil },
                sortBy: [SortDescriptor(\.lastViewedAt, order: .reverse)]
            )
        case .favorites:
            descriptor = FetchDescriptor(
                predicate: #Predicate { $0.isFavorite == true },
                sortBy: [SortDescriptor(\.normalizedText)]
            )
        case .mine:
            descriptor = FetchDescriptor(
                predicate: #Predicate { $0.isUserAdded == true },
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
        case .inReview:
            let ids = allCards().map(\.wordID)
            descriptor = FetchDescriptor(
                predicate: #Predicate { ids.contains($0.id) },
                sortBy: [SortDescriptor(\.normalizedText)]
            )
        }
        descriptor.fetchLimit = limit
        return fetch(descriptor)
    }

    public func recentWords(limit: Int = 8) -> [Word] {
        words(filter: .recent, limit: limit)
    }

    /// Exact match first, then headwords starting with the query, then matches in
    /// translations / synonyms — each group ordered by word frequency.
    public func search(_ query: String, limit: Int = 60) -> [Word] {
        let q = SearchNormalizer.normalize(query)
        guard !q.isEmpty else { return [] }

        var prefix = FetchDescriptor<WordRecord>(
            predicate: #Predicate { $0.normalizedText.starts(with: q) },
            sortBy: [SortDescriptor(\.searchRank), SortDescriptor(\.normalizedText)]
        )
        prefix.fetchLimit = limit
        var results = fetch(prefix)
        if let exact = results.firstIndex(where: { SearchNormalizer.normalize($0.text) == q }), exact > 0 {
            results.insert(results.remove(at: exact), at: 0)
        }

        if results.count < limit {
            var contains = FetchDescriptor<WordRecord>(
                predicate: #Predicate { $0.searchText.contains(q) && !$0.normalizedText.starts(with: q) },
                sortBy: [SortDescriptor(\.searchRank), SortDescriptor(\.normalizedText)]
            )
            contains.fetchLimit = limit - results.count
            results += fetch(contains)
        }
        return results
    }

    /// A stable "word of the day" from intermediate (B1–C1) bundled words that have examples.
    public func wordOfTheDay(for date: Date = .now, calendar: Calendar = .current) -> Word? {
        // Keep this predicate SQL-friendly: SwiftData cannot translate `??` or `contains` on optionals.
        let b1: String? = "B1", b2: String? = "B2", c1: String? = "C1"
        let pool = #Predicate<WordRecord> { record in
            record.isUserAdded == false && record.hasExamples == true
                && (record.level == b1 || record.level == b2 || record.level == c1)
        }
        let count = (try? context.fetchCount(FetchDescriptor(predicate: pool))) ?? 0
        guard count > 0 else { return nil }
        let day = calendar.dateComponents([.day], from: Date(timeIntervalSince1970: 0), to: calendar.startOfDay(for: date)).day ?? 0
        var descriptor = FetchDescriptor(predicate: pool, sortBy: [SortDescriptor(\WordRecord.id)])
        descriptor.fetchOffset = (day * 7_919) % count
        descriptor.fetchLimit = 1
        return fetch(descriptor).first
    }

    public func findWord(text: String) -> Word? {
        let normalized = SearchNormalizer.normalize(text)
        var descriptor = FetchDescriptor<WordRecord>(predicate: #Predicate { $0.normalizedText == normalized })
        descriptor.fetchLimit = 1
        return fetch(descriptor).first
    }

    /// Maps each text that exists in the dictionary to its word id (makes synonyms tappable).
    public func wordIDs(forTexts texts: [String]) -> [String: String] {
        guard !texts.isEmpty else { return [:] }
        let byNormalized = Dictionary(texts.map { (SearchNormalizer.normalize($0), $0) }, uniquingKeysWith: { first, _ in first })
        let keys = Array(byNormalized.keys)
        let descriptor = FetchDescriptor<WordRecord>(predicate: #Predicate { keys.contains($0.normalizedText) })
        let records = (try? context.fetch(descriptor)) ?? []
        var result: [String: String] = [:]
        for record in records {
            if let original = byNormalized[record.normalizedText] { result[original] = record.id }
        }
        return result
    }

    /// Inserts (empty id) or updates a word and returns its id.
    @discardableResult
    public func save(_ word: Word, addToReview: Bool = false) -> String {
        var word = word
        let now = Date.now
        if word.id.isEmpty {
            word.id = UUID().uuidString
            word.isUserAdded = true
            word.createdAt = now
        }
        word.updatedAt = now
        if let existing = record(id: word.id) {
            existing.apply(word)
        } else {
            context.insert(WordRecord(word: word))
        }
        if addToReview { insertCardIfNeeded(wordID: word.id, now: now) }
        commit()
        return word.id
    }

    public func setFavorite(_ isFavorite: Bool, wordID: String) {
        guard let record = record(id: wordID) else { return }
        record.isFavorite = isFavorite
        record.updatedAt = .now
        commit()
    }

    public func markViewed(wordID: String) {
        record(id: wordID)?.lastViewedAt = .now
        commit()
    }

    public func deleteWord(id: String) {
        if let record = record(id: id) { context.delete(record) }
        if let card = cardRecord(wordID: id) { context.delete(card) }
        for deck in deckRecords() where deck.wordIDs.contains(id) {
            deck.wordIDs.removeAll { $0 == id }
        }
        commit()
    }

    // MARK: - Leitner cards

    public func card(for wordID: String) -> ReviewCard? {
        cardRecord(wordID: wordID)?.card
    }

    public func allCards() -> [ReviewCard] {
        ((try? context.fetch(FetchDescriptor<CardRecord>())) ?? []).map(\.card)
    }

    public func dueCount(at now: Date = .now) -> Int {
        let descriptor = FetchDescriptor<CardRecord>(predicate: #Predicate { $0.dueAt <= now })
        return (try? context.fetchCount(descriptor)) ?? 0
    }

    public func addToReview(wordIDs: [String]) {
        let now = Date.now
        for id in wordIDs { insertCardIfNeeded(wordID: id, now: now) }
        commit()
    }

    public func removeFromReview(wordID: String) {
        if let card = cardRecord(wordID: wordID) { context.delete(card) }
        commit()
    }

    /// Cards for a session; lower boxes first. `includeNotDue` is free practice.
    public func sessionCards(deckID: String?, includeNotDue: Bool, limit: Int, now: Date = .now) -> [(word: Word, card: ReviewCard)] {
        var descriptor: FetchDescriptor<CardRecord>
        if includeNotDue {
            descriptor = FetchDescriptor(sortBy: [SortDescriptor(\.box), SortDescriptor(\.dueAt)])
        } else {
            descriptor = FetchDescriptor(
                predicate: #Predicate { $0.dueAt <= now },
                sortBy: [SortDescriptor(\.box), SortDescriptor(\.dueAt)]
            )
        }
        var cards = (try? context.fetch(descriptor)) ?? []
        if let deckID, let deck = deckRecord(id: deckID) {
            let members = Set(deck.wordIDs)
            cards = cards.filter { members.contains($0.wordID) }
        }
        return cards.prefix(limit).compactMap { card in
            record(id: card.wordID).map { (word: $0.word, card: card.card) }
        }
    }

    /// Logs an answer; when `reschedule` is false (free practice) the Leitner box is unchanged.
    @discardableResult
    public func recordAnswer(card: ReviewCard, correct: Bool, reschedule: Bool) -> ReviewCard {
        let now = Date.now
        var updated = card
        if reschedule {
            updated = Leitner.answer(card, correct: correct, now: now)
        } else {
            updated.reviewCount += 1
            updated.correctCount += correct ? 1 : 0
            updated.lastReviewedAt = now
        }
        cardRecord(wordID: card.wordID)?.apply(updated)
        context.insert(ReviewLogRecord(wordID: card.wordID, reviewedAt: now, correct: correct))
        commit()
        return updated
    }

    public func reviewStats(dailyGoal: Int, now: Date = .now, calendar: Calendar = .current) -> ReviewStats {
        let cards = allCards()
        let today = calendar.startOfDay(for: now)
        let weekStart = calendar.date(byAdding: .day, value: -6, to: today) ?? today
        let logs = (try? context.fetch(FetchDescriptor<ReviewLogRecord>())) ?? []

        var byDay: [Date: (reviewed: Int, correct: Int)] = [:]
        var activeDays = Set<Date>()
        for log in logs {
            let day = calendar.startOfDay(for: log.reviewedAt)
            activeDays.insert(day)
            guard day >= weekStart else { continue }
            var entry = byDay[day] ?? (0, 0)
            entry.reviewed += 1
            entry.correct += log.correct ? 1 : 0
            byDay[day] = entry
        }
        let lastSevenDays = (0..<7).compactMap { offset -> DayActivity? in
            guard let day = calendar.date(byAdding: .day, value: offset, to: weekStart) else { return nil }
            let entry = byDay[day] ?? (0, 0)
            return DayActivity(day: day, reviewed: entry.reviewed, correct: entry.correct)
        }
        return ReviewStats(
            dueCount: cards.filter { $0.isDue(at: now) }.count,
            totalCards: cards.count,
            masteredCount: cards.filter(\.isMastered).count,
            boxCounts: (1...Leitner.masteredBox).map { box in cards.filter { $0.box == box }.count },
            streakDays: calculateStreak(activeDays: activeDays, today: now, calendar: calendar),
            reviewedToday: byDay[today]?.reviewed ?? 0,
            dailyGoal: dailyGoal,
            lastSevenDays: lastSevenDays
        )
    }

    // MARK: - Decks

    public func decks() -> [Deck] {
        deckRecords().map(\.deck)
    }

    public func deck(id: String) -> Deck? {
        deckRecord(id: id)?.deck
    }

    public func words(inDeck deckID: String) -> [Word] {
        guard let ids = deckRecord(id: deckID)?.wordIDs, !ids.isEmpty else { return [] }
        let descriptor = FetchDescriptor<WordRecord>(
            predicate: #Predicate { ids.contains($0.id) },
            sortBy: [SortDescriptor(\.normalizedText)]
        )
        return fetch(descriptor)
    }

    public func deckIDs(containing wordID: String) -> Set<String> {
        Set(deckRecords().filter { $0.wordIDs.contains(wordID) }.map(\.id))
    }

    @discardableResult
    public func createDeck(name: String, colorIndex: Int) -> String {
        let id = UUID().uuidString
        context.insert(DeckRecord(id: id, name: name.trimmingCharacters(in: .whitespacesAndNewlines), colorIndex: colorIndex, createdAt: .now))
        commit()
        return id
    }

    public func updateDeck(id: String, name: String, colorIndex: Int) {
        guard let deck = deckRecord(id: id) else { return }
        deck.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        deck.colorIndex = colorIndex
        commit()
    }

    public func deleteDeck(id: String) {
        if let deck = deckRecord(id: id) { context.delete(deck) }
        commit()
    }

    public func addWords(_ wordIDs: [String], toDeck deckID: String) {
        guard let deck = deckRecord(id: deckID) else { return }
        for id in wordIDs where !deck.wordIDs.contains(id) { deck.wordIDs.append(id) }
        commit()
    }

    public func removeWord(_ wordID: String, fromDeck deckID: String) {
        deckRecord(id: deckID)?.wordIDs.removeAll { $0 == wordID }
        commit()
    }

    public func setDecks(_ deckIDs: Set<String>, forWord wordID: String) {
        for deck in deckRecords() {
            let shouldContain = deckIDs.contains(deck.id)
            let contains = deck.wordIDs.contains(wordID)
            if shouldContain && !contains { deck.wordIDs.append(wordID) }
            if !shouldContain && contains { deck.wordIDs.removeAll { $0 == wordID } }
        }
        commit()
    }

    // MARK: - Backup

    /// The whole library as a JSON backup (same format as the Android app).
    public func exportBackup() throws -> Data {
        let words = ((try? context.fetch(FetchDescriptor<WordRecord>())) ?? []).map { BackupWord($0.word) }
        let decks = deckRecords().map {
            BackupDeck(id: $0.id, name: $0.name, colorIndex: $0.colorIndex, createdAt: $0.createdAt, wordIds: $0.wordIDs)
        }
        let logs = ((try? context.fetch(FetchDescriptor<ReviewLogRecord>())) ?? []).map {
            BackupReviewLog(id: $0.id, wordId: $0.wordID, reviewedAt: $0.reviewedAt, correct: $0.correct)
        }
        let document = BackupDocument(
            exportedAt: Date.now.epochMilliseconds,
            words: words,
            cards: allCards().map(BackupCard.init),
            decks: decks,
            reviewLogs: logs
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(document)
    }

    /// Merges a backup into the library: records with the same id are replaced, others kept.
    @discardableResult
    public func importBackup(_ data: Data) throws -> BackupSummary {
        let document: BackupDocument
        do {
            document = try JSONDecoder().decode(BackupDocument.self, from: data)
        } catch {
            throw BackupError.notARavanBackup
        }
        guard document.app == BackupDocument.appID else { throw BackupError.notARavanBackup }
        guard document.formatVersion <= BackupDocument.currentFormatVersion else {
            throw BackupError.unsupportedVersion(document.formatVersion)
        }

        for backup in document.words {
            let word = backup.word
            if let existing = record(id: word.id) { existing.apply(word) } else { context.insert(WordRecord(word: word)) }
        }
        let existingWordIDs = Set(((try? context.fetch(FetchDescriptor<WordRecord>())) ?? []).map(\.id))
        for backup in document.cards where existingWordIDs.contains(backup.wordId) {
            let card = backup.card
            if let existing = cardRecord(wordID: card.wordID) { existing.apply(card) } else { context.insert(CardRecord(card: card)) }
        }
        for backup in document.decks {
            let members = backup.wordIds.filter(existingWordIDs.contains)
            if let deck = deckRecord(id: backup.id) {
                deck.name = backup.name
                deck.colorIndex = backup.colorIndex
                deck.wordIDs = Array(Set(deck.wordIDs).union(members))
            } else {
                context.insert(DeckRecord(
                    id: backup.id,
                    name: backup.name,
                    colorIndex: backup.colorIndex,
                    createdAt: Date(epochMilliseconds: backup.createdAt),
                    wordIDs: members
                ))
            }
        }
        let existingLogIDs = Set(((try? context.fetch(FetchDescriptor<ReviewLogRecord>())) ?? []).map(\.id))
        for log in document.reviewLogs where !existingLogIDs.contains(log.id) {
            context.insert(ReviewLogRecord(
                id: log.id,
                wordID: log.wordId,
                reviewedAt: Date(epochMilliseconds: log.reviewedAt),
                correct: log.correct
            ))
        }
        commit()
        return document.summary
    }

    // MARK: - Private

    private func commit() {
        do {
            try context.save()
        } catch {
            assertionFailure("SwiftData save failed: \(error)")
        }
        revision += 1
    }

    private func fetch(_ descriptor: FetchDescriptor<WordRecord>) -> [Word] {
        ((try? context.fetch(descriptor)) ?? []).map(\.word)
    }

    private func record(id: String) -> WordRecord? {
        var descriptor = FetchDescriptor<WordRecord>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    private func cardRecord(wordID: String) -> CardRecord? {
        var descriptor = FetchDescriptor<CardRecord>(predicate: #Predicate { $0.wordID == wordID })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    private func deckRecord(id: String) -> DeckRecord? {
        var descriptor = FetchDescriptor<DeckRecord>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    private func deckRecords() -> [DeckRecord] {
        (try? context.fetch(FetchDescriptor<DeckRecord>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)]))) ?? []
    }

    private func insertCardIfNeeded(wordID: String, now: Date) {
        guard cardRecord(wordID: wordID) == nil else { return }
        context.insert(CardRecord(card: Leitner.newCard(wordID: wordID, now: now)))
    }
}
