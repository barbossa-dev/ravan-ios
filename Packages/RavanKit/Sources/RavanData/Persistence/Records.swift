import Foundation
import RavanModel
import SwiftData

/// SwiftData row for a dictionary entry. Meanings/examples are stored as JSON blobs: they are
/// always read together with the word, and it keeps the schema simple to migrate.
@Model
public final class WordRecord {
    #Index<WordRecord>([\.normalizedText], [\.lastViewedAt], [\.searchRank])

    @Attribute(.unique) public var id: String
    public var text: String
    /// Normalised headword — exact / prefix matching and duplicate detection.
    public var normalizedText: String
    /// Normalised headword + Persian translations + synonyms — what search runs on.
    public var searchText: String
    public var phoneticUS: String
    public var phoneticUK: String
    public var partOfSpeech: String
    public var level: String?
    public var meaningsData: Data
    public var examplesData: Data
    public var synonyms: [String]
    public var antonyms: [String]
    public var note: String
    public var isFavorite: Bool
    public var isUserAdded: Bool
    public var createdAt: Date
    public var updatedAt: Date
    public var lastViewedAt: Date?
    public var frequencyRank: Int
    /// Frequency rank with "unknown" sorted last; used to order search results.
    public var searchRank: Int
    public var hasExamples: Bool

    public init(word: Word) {
        id = word.id
        text = ""
        normalizedText = ""
        searchText = ""
        phoneticUS = ""
        phoneticUK = ""
        partOfSpeech = PartOfSpeech.other.rawValue
        meaningsData = Data()
        examplesData = Data()
        synonyms = []
        antonyms = []
        note = ""
        isFavorite = false
        isUserAdded = false
        createdAt = word.createdAt
        updatedAt = word.updatedAt
        frequencyRank = 0
        searchRank = Int.max
        hasExamples = false
        apply(word)
    }

    public func apply(_ word: Word) {
        text = word.text.trimmingCharacters(in: .whitespacesAndNewlines)
        normalizedText = SearchNormalizer.normalize(word.text)
        searchText = ([word.text] + word.meanings.map(\.translation) + word.synonyms)
            .map(SearchNormalizer.normalize)
            .joined(separator: " | ")
        phoneticUS = word.phoneticUS
        phoneticUK = word.phoneticUK
        partOfSpeech = word.partOfSpeech.rawValue
        level = word.level?.rawValue
        meaningsData = JSONCoding.encode(word.meanings)
        examplesData = JSONCoding.encode(word.examples)
        synonyms = word.synonyms
        antonyms = word.antonyms
        note = word.note
        isFavorite = word.isFavorite
        isUserAdded = word.isUserAdded
        createdAt = word.createdAt
        updatedAt = word.updatedAt
        lastViewedAt = word.lastViewedAt
        frequencyRank = word.frequencyRank
        searchRank = word.frequencyRank > 0 ? word.frequencyRank : Int.max
        hasExamples = !word.examples.isEmpty
    }

    public var word: Word {
        Word(
            id: id,
            text: text,
            phoneticUS: phoneticUS,
            phoneticUK: phoneticUK,
            partOfSpeech: PartOfSpeech(key: partOfSpeech),
            level: CEFRLevel(key: level),
            meanings: JSONCoding.decode([Meaning].self, from: meaningsData) ?? [],
            examples: JSONCoding.decode([Example].self, from: examplesData) ?? [],
            synonyms: synonyms,
            antonyms: antonyms,
            note: note,
            isFavorite: isFavorite,
            isUserAdded: isUserAdded,
            createdAt: createdAt,
            updatedAt: updatedAt,
            lastViewedAt: lastViewedAt,
            frequencyRank: frequencyRank
        )
    }
}

@Model
public final class CardRecord {
    @Attribute(.unique) public var wordID: String
    public var box: Int
    public var dueAt: Date
    public var reviewCount: Int
    public var correctCount: Int
    public var lastReviewedAt: Date?
    public var addedAt: Date

    public init(card: ReviewCard) {
        wordID = card.wordID
        box = card.box
        dueAt = card.dueAt
        reviewCount = card.reviewCount
        correctCount = card.correctCount
        lastReviewedAt = card.lastReviewedAt
        addedAt = card.addedAt
    }

    public func apply(_ card: ReviewCard) {
        box = card.box
        dueAt = card.dueAt
        reviewCount = card.reviewCount
        correctCount = card.correctCount
        lastReviewedAt = card.lastReviewedAt
        addedAt = card.addedAt
    }

    public var card: ReviewCard {
        ReviewCard(
            wordID: wordID,
            box: box,
            dueAt: dueAt,
            reviewCount: reviewCount,
            correctCount: correctCount,
            lastReviewedAt: lastReviewedAt,
            addedAt: addedAt
        )
    }
}

@Model
public final class DeckRecord {
    @Attribute(.unique) public var id: String
    public var name: String
    public var colorIndex: Int
    public var createdAt: Date
    public var wordIDs: [String]

    public init(id: String, name: String, colorIndex: Int, createdAt: Date, wordIDs: [String] = []) {
        self.id = id
        self.name = name
        self.colorIndex = colorIndex
        self.createdAt = createdAt
        self.wordIDs = wordIDs
    }

    public var deck: Deck {
        Deck(id: id, name: name, colorIndex: colorIndex, createdAt: createdAt, wordCount: wordIDs.count)
    }
}

/// Review history. Kept when a word is deleted so streaks stay correct.
@Model
public final class ReviewLogRecord {
    @Attribute(.unique) public var id: String
    public var wordID: String
    public var reviewedAt: Date
    public var correct: Bool

    public init(id: String = UUID().uuidString, wordID: String, reviewedAt: Date, correct: Bool) {
        self.id = id
        self.wordID = wordID
        self.reviewedAt = reviewedAt
        self.correct = correct
    }
}

enum JSONCoding {
    static func encode<T: Encodable>(_ value: T) -> Data {
        (try? JSONEncoder().encode(value)) ?? Data("[]".utf8)
    }

    static func decode<T: Decodable>(_ type: T.Type, from data: Data) -> T? {
        try? JSONDecoder().decode(type, from: data)
    }
}

public enum RavanSchema {
    public static var models: [any PersistentModel.Type] {
        [WordRecord.self, CardRecord.self, DeckRecord.self, ReviewLogRecord.self]
    }

    /// The app's on-disk store, or an in-memory one for previews and tests.
    public static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema(models)
        let configuration = ModelConfiguration("Ravan", schema: schema, isStoredInMemoryOnly: inMemory)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
