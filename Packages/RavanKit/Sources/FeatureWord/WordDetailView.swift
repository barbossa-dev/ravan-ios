import RavanUI
import SwiftUI

/// Full entry: US/UK pronunciation, senses, examples, synonyms/antonyms, Leitner state and decks.
public struct WordDetailView: View {
    private let wordID: String

    @Environment(DictionaryStore.self) private var store
    @Environment(SettingsStore.self) private var settings
    @Environment(Pronouncer.self) private var pronouncer
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss

    @State private var word: Word?
    @State private var card: ReviewCard?
    @State private var decks: [Deck] = []
    @State private var selectedDeckIDs: Set<String> = []
    @State private var relatedIDs: [String: String] = [:]
    @State private var lastAccent: Accent = .us
    @State private var isLoaded = false
    @State private var showDeleteConfirmation = false
    @State private var showDeckPicker = false

    public init(wordID: String) {
        self.wordID = wordID
    }

    public var body: some View {
        Group {
            if let word {
                content(word)
            } else if isLoaded {
                ContentUnavailableView("این لغت پیدا نشد", systemImage: "questionmark.circle", description: Text("ممکن است حذف شده باشد."))
            } else {
                ProgressView()
            }
        }
        .ravanBackground()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbar }
        .task { store.markViewed(wordID: wordID) }
        .task(id: store.revision) { load() }
        .confirmationDialog("حذف «\(word?.text ?? "")»؟", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("حذف لغت", role: .destructive) {
                pronouncer.stop()
                store.deleteWord(id: wordID)
                dismiss()
            }
        } message: {
            Text("این لغت، کارت مرور و جایگاهش در دسته‌ها حذف می‌شود.")
        }
        .sheet(isPresented: $showDeckPicker) {
            DeckPickerSheet(wordID: wordID)
                .presentationDetents([.medium, .large])
        }
    }

    // MARK: Content

    private func content(_ word: Word) -> some View {
        ScrollView {
            GlassEffectContainer(spacing: 16) {
                VStack(alignment: .leading, spacing: 16) {
                    header(word)
                    pronunciation(word)
                    leitner
                    meanings(word)
                    examples(word)
                    related(title: "مترادف‌ها", words: word.synonyms)
                    related(title: "متضادها", words: word.antonyms)
                    if !word.note.isEmpty {
                        SectionTitle("یادداشت من")
                        GlassCard { Text(word.note) }
                    }
                    deckSection
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
        }
    }

    private func header(_ word: Word) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(verbatim: word.text)
                .font(.headword(.largeTitle))
                .textSelection(.enabled)
            FlowLayout {
                Pill(word.partOfSpeech.persianLabel)
                if let level = word.level { Pill(level.rawValue, tint: RavanColor.brand) }
                if word.isUserAdded { Pill("لغت من", systemImage: "person.fill", tint: RavanColor.saffron) }
            }
        }
        .padding(.top, 8)
    }

    private func pronunciation(_ word: Word) -> some View {
        HStack(spacing: 12) {
            ForEach(Accent.allCases) { accent in
                PronounceButton(
                    label: "\(accent.persianName) · \(accent.shortLabel)",
                    phonetic: word.phonetic(for: accent),
                    isSpeaking: pronouncer.speakingText == word.text && lastAccent == accent
                ) {
                    lastAccent = accent
                    pronouncer.speak(word.text, settings: settings, accent: accent)
                }
            }
        }
    }

    private var leitner: some View {
        GlassCard {
            HStack {
                Label("جعبهٔ لایتنر", systemImage: "rectangle.stack.fill")
                    .font(.headline)
                    .foregroundStyle(RavanColor.brand)
                Spacer()
                if let card { Pill(card.boxLabel, tint: RavanColor.brand) }
            }
            if let card {
                LeitnerProgressView(box: card.box, boxCount: Leitner.boxCount)
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(card.dueLabel()).font(.subheadline)
                        Text("\(card.reviewCount.persianDigits) مرور · \(card.correctCount.persianDigits) پاسخ درست")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("حذف از مرور", role: .destructive) { store.removeFromReview(wordID: wordID) }
                        .buttonStyle(.glass)
                }
            } else {
                Text("این لغت را به کارت‌های مرور اضافه کنید تا در زمان مناسب دوباره ببینید.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button {
                    store.addToReview(wordIDs: [wordID])
                } label: {
                    Label("افزودن به جعبهٔ لایتنر", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .tint(RavanColor.brand)
                .controlSize(.large)
            }
        }
    }

    @ViewBuilder
    private func meanings(_ word: Word) -> some View {
        if !word.meanings.isEmpty {
            SectionTitle("معانی")
            GlassCard {
                ForEach(Array(word.meanings.enumerated()), id: \.offset) { index, meaning in
                    HStack(alignment: .top, spacing: 12) {
                        Text((index + 1).persianDigits)
                            .font(.subheadline.bold())
                            .foregroundStyle(RavanColor.brand)
                            .frame(width: 28, height: 28)
                            .background(RavanColor.brandContainer.opacity(0.6), in: .circle)
                        VStack(alignment: .leading, spacing: 4) {
                            if !meaning.description.isEmpty {
                                Text(meaning.description)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(RavanColor.saffron)
                            }
                            Text(meaning.translation)
                                .font(.body.weight(.medium))
                                .textSelection(.enabled)
                        }
                    }
                    if index < word.meanings.count - 1 { Divider() }
                }
            }
        }
    }

    @ViewBuilder
    private func examples(_ word: Word) -> some View {
        if !word.examples.isEmpty {
            SectionTitle("مثال‌ها")
            ForEach(Array(word.examples.enumerated()), id: \.offset) { _, example in
                GlassCard {
                    HStack(alignment: .top, spacing: 10) {
                        VStack(alignment: .leading, spacing: 6) {
                            EnglishText(example.english, leftAligned: true)
                            if !example.persian.isEmpty {
                                Text(example.persian)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        SpeakButton(isSpeaking: pronouncer.speakingText == example.english) {
                            pronouncer.speak(example.english, settings: settings)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func related(title: String, words: [String]) -> some View {
        if !words.isEmpty {
            SectionTitle(title)
            FlowLayout {
                ForEach(words, id: \.self) { text in
                    let id = relatedIDs[text]
                    Button {
                        if let id { router.open(.word(id)) } else { router.openEditor(initialText: text) }
                    } label: {
                        Text(verbatim: text).font(.body)
                    }
                    .buttonStyle(.glass)
                    .tint(id == nil ? .secondary : RavanColor.brand)
                    .accessibilityHint(id == nil ? "افزودن به دیکشنری" : "نمایش لغت")
                }
            }
        }
    }

    private var deckSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                SectionTitle("دسته‌ها")
                Button("مدیریت") { showDeckPicker = true }
                    .buttonStyle(.glass)
            }
            let selected = decks.filter { selectedDeckIDs.contains($0.id) }
            if selected.isEmpty {
                Text("در هیچ دسته‌ای نیست").font(.subheadline).foregroundStyle(.secondary)
            } else {
                FlowLayout {
                    ForEach(selected) { deck in
                        Pill(deck.name, systemImage: "folder.fill", tint: RavanColor.deck(deck.colorIndex))
                    }
                }
            }
        }
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        if let word {
            ToolbarItem(placement: .topBarTrailing) {
                Button(word.isFavorite ? "حذف نشان" : "نشان کردن", systemImage: word.isFavorite ? "star.fill" : "star") {
                    store.setFavorite(!word.isFavorite, wordID: word.id)
                }
                .tint(word.isFavorite ? RavanColor.saffron : nil)
            }
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: shareText(word)) { Label("اشتراک‌گذاری", systemImage: "square.and.arrow.up") }
            }
            ToolbarSpacer(.fixed, placement: .topBarTrailing)
            ToolbarItem(placement: .topBarTrailing) {
                Menu("گزینه‌های بیشتر", systemImage: "ellipsis") {
                    Button("ویرایش", systemImage: "pencil") { router.openEditor(wordID: word.id) }
                    Button("حذف لغت", systemImage: "trash", role: .destructive) { showDeleteConfirmation = true }
                }
            }
        }
    }

    // MARK: Data

    private func load() {
        word = store.word(id: wordID)
        card = store.card(for: wordID)
        decks = store.decks()
        selectedDeckIDs = store.deckIDs(containing: wordID)
        if let word { relatedIDs = store.wordIDs(forTexts: word.synonyms + word.antonyms) }
        if !isLoaded { lastAccent = settings.accent }
        isLoaded = true
    }

    private func shareText(_ word: Word) -> String {
        var lines = ["\(word.text)  \(word.phoneticUS)"]
        lines += word.meanings.map { "• \($0.translation)" }
        if let example = word.examples.first { lines += ["", example.english, example.persian] }
        return lines.joined(separator: "\n")
    }
}

/// Adds the word to decks or creates a new deck.
private struct DeckPickerSheet: View {
    let wordID: String

    @Environment(DictionaryStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var decks: [Deck] = []
    @State private var selected: Set<String> = []
    @State private var newDeckName = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(decks) { deck in
                        Button {
                            if selected.contains(deck.id) { selected.remove(deck.id) } else { selected.insert(deck.id) }
                            store.setDecks(selected, forWord: wordID)
                        } label: {
                            HStack {
                                Circle().fill(RavanColor.deck(deck.colorIndex)).frame(width: 12, height: 12)
                                Text(deck.name).foregroundStyle(.primary)
                                Spacer()
                                if selected.contains(deck.id) {
                                    Image(systemName: "checkmark").foregroundStyle(RavanColor.brand)
                                }
                            }
                        }
                    }
                }
                Section("دستهٔ جدید") {
                    HStack {
                        TextField("نام دستهٔ جدید", text: $newDeckName)
                        Button("ساختن") {
                            let id = store.createDeck(name: newDeckName, colorIndex: Int.random(in: 0..<RavanColor.decks.count))
                            selected.insert(id)
                            store.setDecks(selected, forWord: wordID)
                            newDeckName = ""
                        }
                        .disabled(newDeckName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
            .navigationTitle("افزودن به دسته")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("تمام", systemImage: "checkmark") { dismiss() }
                }
            }
            .task(id: store.revision) {
                decks = store.decks()
                selected = store.deckIDs(containing: wordID)
            }
        }
    }
}
