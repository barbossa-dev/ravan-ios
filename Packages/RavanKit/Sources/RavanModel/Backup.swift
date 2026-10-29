import Foundation

/// Cross-platform backup file — byte-compatible with the Android app.
/// All timestamps are Unix epoch milliseconds.
public struct BackupDocument: Codable, Sendable {
    public static let appID = "ravan"
    public static let currentFormatVersion = 1

    public var app: String
    public var formatVersion: Int
    public var exportedAt: Int64
    public var platform: String
    public var words: [BackupWord]
    public var cards: [BackupCard]
    public var decks: [BackupDeck]
    public var reviewLogs: [BackupReviewLog]

    public init(exportedAt: Int64, words: [BackupWord], cards: [BackupCard], decks: [BackupDeck], reviewLogs: [BackupReviewLog]) {
        self.app = Self.appID
        self.formatVersion = Self.currentFormatVersion
        self.exportedAt = exportedAt
        self.platform = "ios"
        self.words = words
        self.cards = cards
        self.decks = decks
        self.reviewLogs = reviewLogs
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        app = try c.decode(String.self, forKey: .app)
        formatVersion = try c.decode(Int.self, forKey: .formatVersion)
        exportedAt = try c.decodeIfPresent(Int64.self, forKey: .exportedAt) ?? 0
        platform = try c.decodeIfPresent(String.self, forKey: .platform) ?? "unknown"
        words = try c.decodeIfPresent([BackupWord].self, forKey: .words) ?? []
        cards = try c.decodeIfPresent([BackupCard].self, forKey: .cards) ?? []
        decks = try c.decodeIfPresent([BackupDeck].self, forKey: .decks) ?? []
        reviewLogs = try c.decodeIfPresent([BackupReviewLog].self, forKey: .reviewLogs) ?? []
    }

    public var summary: BackupSummary {
        BackupSummary(words: words.count, cards: cards.count, decks: decks.count, reviewLogs: reviewLogs.count)
    }
}

public struct BackupWord: Codable, Sendable {
    public var id: String
    public var text: String
    public var phoneticUs: String
    public var phoneticUk: String
    public var partOfSpeech: String
    public var level: String?
    public var meanings: [Meaning]
    public var examples: [Example]
    public var synonyms: [String]
    public var antonyms: [String]
    public var note: String
    public var isFavorite: Bool
    public var isUserAdded: Bool
    public var createdAt: Int64
    public var updatedAt: Int64
    public var lastViewedAt: Int64?
    public var frequencyRank: Int

    public init(_ word: Word) {
        id = word.id
        text = word.text
        phoneticUs = word.phoneticUS
        phoneticUk = word.phoneticUK
        partOfSpeech = word.partOfSpeech.rawValue
        level = word.level?.rawValue
        meanings = word.meanings
        examples = word.examples
        synonyms = word.synonyms
        antonyms = word.antonyms
        note = word.note
        isFavorite = word.isFavorite
        isUserAdded = word.isUserAdded
        createdAt = word.createdAt.epochMilliseconds
        updatedAt = word.updatedAt.epochMilliseconds
        lastViewedAt = word.lastViewedAt?.epochMilliseconds
        frequencyRank = word.frequencyRank
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        text = try c.decode(String.self, forKey: .text)
        phoneticUs = try c.decodeIfPresent(String.self, forKey: .phoneticUs) ?? ""
        phoneticUk = try c.decodeIfPresent(String.self, forKey: .phoneticUk) ?? ""
        partOfSpeech = try c.decodeIfPresent(String.self, forKey: .partOfSpeech) ?? "other"
        level = try c.decodeIfPresent(String.self, forKey: .level)
        meanings = try c.decodeIfPresent([Meaning].self, forKey: .meanings) ?? []
        examples = try c.decodeIfPresent([Example].self, forKey: .examples) ?? []
        synonyms = try c.decodeIfPresent([String].self, forKey: .synonyms) ?? []
        antonyms = try c.decodeIfPresent([String].self, forKey: .antonyms) ?? []
        note = try c.decodeIfPresent(String.self, forKey: .note) ?? ""
        isFavorite = try c.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        isUserAdded = try c.decodeIfPresent(Bool.self, forKey: .isUserAdded) ?? false
        createdAt = try c.decodeIfPresent(Int64.self, forKey: .createdAt) ?? 0
        updatedAt = try c.decodeIfPresent(Int64.self, forKey: .updatedAt) ?? 0
        lastViewedAt = try c.decodeIfPresent(Int64.self, forKey: .lastViewedAt)
        frequencyRank = try c.decodeIfPresent(Int.self, forKey: .frequencyRank) ?? 0
    }

    public var word: Word {
        Word(
            id: id,
            text: text,
            phoneticUS: phoneticUs,
            phoneticUK: phoneticUk,
            partOfSpeech: PartOfSpeech(key: partOfSpeech),
            level: CEFRLevel(key: level),
            meanings: meanings,
            examples: examples,
            synonyms: synonyms,
            antonyms: antonyms,
            note: note,
            isFavorite: isFavorite,
            isUserAdded: isUserAdded,
            createdAt: Date(epochMilliseconds: createdAt),
            updatedAt: Date(epochMilliseconds: updatedAt),
            lastViewedAt: lastViewedAt.map(Date.init(epochMilliseconds:)),
            frequencyRank: frequencyRank
        )
    }
}

public struct BackupCard: Codable, Sendable {
    public var wordId: String
    public var box: Int
    public var dueAt: Int64
    public var reviewCount: Int
    public var correctCount: Int
    public var lastReviewedAt: Int64?
    public var addedAt: Int64

    public init(_ card: ReviewCard) {
        wordId = card.wordID
        box = card.box
        dueAt = card.dueAt.epochMilliseconds
        reviewCount = card.reviewCount
        correctCount = card.correctCount
        lastReviewedAt = card.lastReviewedAt?.epochMilliseconds
        addedAt = card.addedAt.epochMilliseconds
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        wordId = try c.decode(String.self, forKey: .wordId)
        box = try c.decode(Int.self, forKey: .box)
        dueAt = try c.decode(Int64.self, forKey: .dueAt)
        reviewCount = try c.decodeIfPresent(Int.self, forKey: .reviewCount) ?? 0
        correctCount = try c.decodeIfPresent(Int.self, forKey: .correctCount) ?? 0
        lastReviewedAt = try c.decodeIfPresent(Int64.self, forKey: .lastReviewedAt)
        addedAt = try c.decodeIfPresent(Int64.self, forKey: .addedAt) ?? 0
    }

    public var card: ReviewCard {
        ReviewCard(
            wordID: wordId,
            box: min(max(box, 1), Leitner.masteredBox),
            dueAt: Date(epochMilliseconds: dueAt),
            reviewCount: reviewCount,
            correctCount: correctCount,
            lastReviewedAt: lastReviewedAt.map(Date.init(epochMilliseconds:)),
            addedAt: Date(epochMilliseconds: addedAt)
        )
    }
}

public struct BackupDeck: Codable, Sendable {
    public var id: String
    public var name: String
    public var colorIndex: Int
    public var createdAt: Int64
    public var wordIds: [String]

    public init(id: String, name: String, colorIndex: Int, createdAt: Date, wordIds: [String]) {
        self.id = id
        self.name = name
        self.colorIndex = colorIndex
        self.createdAt = createdAt.epochMilliseconds
        self.wordIds = wordIds
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        colorIndex = try c.decodeIfPresent(Int.self, forKey: .colorIndex) ?? 0
        createdAt = try c.decodeIfPresent(Int64.self, forKey: .createdAt) ?? 0
        wordIds = try c.decodeIfPresent([String].self, forKey: .wordIds) ?? []
    }
}

public struct BackupReviewLog: Codable, Sendable {
    public var id: String
    public var wordId: String
    public var reviewedAt: Int64
    public var correct: Bool

    public init(id: String, wordId: String, reviewedAt: Date, correct: Bool) {
        self.id = id
        self.wordId = wordId
        self.reviewedAt = reviewedAt.epochMilliseconds
        self.correct = correct
    }
}

public enum BackupError: Error, LocalizedError {
    case notARavanBackup
    case unsupportedVersion(Int)

    public var errorDescription: String? {
        switch self {
        case .notARavanBackup: "This file is not a Ravan backup."
        case .unsupportedVersion(let version): "Backup format \(version) is newer than this app supports."
        }
    }
}

/// Shape of the bundled `dictionary.json` (shared with Android, generated by tools/dictionary).
public struct SeedDictionary: Decodable, Sendable {
    public var version: Int
    public var attribution: [String]
    public var words: [SeedWord]

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decode(Int.self, forKey: .version)
        attribution = try c.decodeIfPresent([String].self, forKey: .attribution) ?? []
        words = try c.decode([SeedWord].self, forKey: .words)
    }

    private enum CodingKeys: String, CodingKey { case version, attribution, words }
}

public struct SeedWord: Decodable, Sendable {
    public var text: String
    public var phoneticUs: String
    public var phoneticUk: String
    public var partOfSpeech: String
    public var level: String?
    public var rank: Int
    public var meanings: [Meaning]
    public var examples: [Example]
    public var synonyms: [String]
    public var antonyms: [String]

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        text = try c.decode(String.self, forKey: .text)
        phoneticUs = try c.decodeIfPresent(String.self, forKey: .phoneticUs) ?? ""
        phoneticUk = try c.decodeIfPresent(String.self, forKey: .phoneticUk) ?? ""
        partOfSpeech = try c.decodeIfPresent(String.self, forKey: .partOfSpeech) ?? "other"
        level = try c.decodeIfPresent(String.self, forKey: .level)
        rank = try c.decodeIfPresent(Int.self, forKey: .rank) ?? 0
        meanings = try c.decodeIfPresent([Meaning].self, forKey: .meanings) ?? []
        examples = try c.decodeIfPresent([Example].self, forKey: .examples) ?? []
        synonyms = try c.decodeIfPresent([String].self, forKey: .synonyms) ?? []
        antonyms = try c.decodeIfPresent([String].self, forKey: .antonyms) ?? []
    }

    private enum CodingKeys: String, CodingKey {
        case text, phoneticUs, phoneticUk, partOfSpeech, level, rank, meanings, examples, synonyms, antonyms
    }

    public func word(now: Date) -> Word {
        Word(
            id: seedWordID(for: text),
            text: text,
            phoneticUS: phoneticUs,
            phoneticUK: phoneticUk,
            partOfSpeech: PartOfSpeech(key: partOfSpeech),
            level: CEFRLevel(key: level),
            meanings: meanings,
            examples: examples,
            synonyms: synonyms,
            antonyms: antonyms,
            isUserAdded: false,
            createdAt: now,
            updatedAt: now,
            frequencyRank: rank
        )
    }
}

public extension Date {
    var epochMilliseconds: Int64 { Int64((timeIntervalSince1970 * 1000).rounded()) }

    init(epochMilliseconds: Int64) {
        self.init(timeIntervalSince1970: TimeInterval(epochMilliseconds) / 1000)
    }
}
