import Foundation

/// A dictionary entry. Bundled entries and words the user adds share the same shape.
public struct Word: Identifiable, Hashable, Sendable {
    public var id: String
    public var text: String
    public var phoneticUS: String
    public var phoneticUK: String
    public var partOfSpeech: PartOfSpeech
    public var level: CEFRLevel?
    public var meanings: [Meaning]
    public var examples: [Example]
    public var synonyms: [String]
    public var antonyms: [String]
    public var note: String
    public var isFavorite: Bool
    public var isUserAdded: Bool
    public var createdAt: Date
    public var updatedAt: Date
    public var lastViewedAt: Date?
    /// Corpus frequency rank (1 = most common); 0 when unknown, e.g. for words the user added.
    public var frequencyRank: Int

    public init(
        id: String = "",
        text: String,
        phoneticUS: String = "",
        phoneticUK: String = "",
        partOfSpeech: PartOfSpeech = .other,
        level: CEFRLevel? = nil,
        meanings: [Meaning] = [],
        examples: [Example] = [],
        synonyms: [String] = [],
        antonyms: [String] = [],
        note: String = "",
        isFavorite: Bool = false,
        isUserAdded: Bool = false,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        lastViewedAt: Date? = nil,
        frequencyRank: Int = 0
    ) {
        self.id = id
        self.text = text
        self.phoneticUS = phoneticUS
        self.phoneticUK = phoneticUK
        self.partOfSpeech = partOfSpeech
        self.level = level
        self.meanings = meanings
        self.examples = examples
        self.synonyms = synonyms
        self.antonyms = antonyms
        self.note = note
        self.isFavorite = isFavorite
        self.isUserAdded = isUserAdded
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastViewedAt = lastViewedAt
        self.frequencyRank = frequencyRank
    }

    /// The first translation, used in compact rows.
    public var primaryTranslation: String { meanings.first?.translation ?? "" }

    public func phonetic(for accent: Accent) -> String {
        switch accent {
        case .us: phoneticUS.isEmpty ? phoneticUK : phoneticUS
        case .uk: phoneticUK.isEmpty ? phoneticUS : phoneticUK
        }
    }
}

public struct Meaning: Hashable, Sendable, Codable {
    public var translation: String
    public var description: String

    public init(translation: String, description: String = "") {
        self.translation = translation
        self.description = description
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        translation = try container.decode(String.self, forKey: .translation)
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
    }
}

public struct Example: Hashable, Sendable, Codable {
    public var english: String
    public var persian: String

    public init(english: String, persian: String = "") {
        self.english = english
        self.persian = persian
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        english = try container.decode(String.self, forKey: .english)
        persian = try container.decodeIfPresent(String.self, forKey: .persian) ?? ""
    }
}

public enum PartOfSpeech: String, CaseIterable, Sendable, Codable, Identifiable {
    case noun, verb, adjective, adverb, pronoun, preposition, conjunction, determiner, interjection, phrase, other

    public var id: String { rawValue }

    public var persianLabel: String {
        switch self {
        case .noun: "اسم"
        case .verb: "فعل"
        case .adjective: "صفت"
        case .adverb: "قید"
        case .pronoun: "ضمیر"
        case .preposition: "حرف اضافه"
        case .conjunction: "حرف ربط"
        case .determiner: "صفت اشاره/شمارشی"
        case .interjection: "صوت"
        case .phrase: "عبارت"
        case .other: "سایر"
        }
    }

    public init(key: String?) {
        self = key.flatMap { PartOfSpeech(rawValue: $0.lowercased()) } ?? .other
    }
}

public enum CEFRLevel: String, CaseIterable, Sendable, Codable, Identifiable {
    case a1 = "A1", a2 = "A2", b1 = "B1", b2 = "B2", c1 = "C1", c2 = "C2"

    public var id: String { rawValue }

    public init?(key: String?) {
        guard let key, let level = CEFRLevel(rawValue: key.uppercased()) else { return nil }
        self = level
    }
}

public enum Accent: String, CaseIterable, Sendable, Identifiable {
    case us, uk

    public var id: String { rawValue }

    /// BCP-47 code of the matching speech voice.
    public var voiceLanguage: String { self == .us ? "en-US" : "en-GB" }
    public var shortLabel: String { self == .us ? "US" : "UK" }
    public var persianName: String { self == .us ? "آمریکایی" : "بریتانیایی" }
}

/// Stable ids for bundled words — identical on Android, so backups move between platforms.
public func seedWordID(for text: String) -> String {
    "seed-" + text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().replacingOccurrences(of: " ", with: "-")
}
