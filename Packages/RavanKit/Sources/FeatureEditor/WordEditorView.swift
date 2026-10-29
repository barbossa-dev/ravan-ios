import RavanUI
import SwiftUI

/// Add a new word or edit an existing one. Presented as a sheet.
public struct WordEditorView: View {
    private let request: EditorRequest
    private let onSaved: (_ wordID: String, _ isNew: Bool) -> Void

    @Environment(DictionaryStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var draft = Draft()
    @State private var original: Word?
    @State private var addToReview = true
    @State private var error: EditorError?
    @State private var duplicateID: String?
    @FocusState private var focusedField: Field?

    private var isNew: Bool { request.wordID == nil }

    public init(request: EditorRequest, onSaved: @escaping (_ wordID: String, _ isNew: Bool) -> Void) {
        self.request = request
        self.onSaved = onSaved
    }

    public var body: some View {
        NavigationStack {
            Form {
                headwordSection
                Section("نقش دستوری و سطح") {
                    Picker("نقش دستوری", selection: $draft.partOfSpeech) {
                        ForEach(PartOfSpeech.allCases) { Text($0.persianLabel).tag($0) }
                    }
                    Picker("سطح (CEFR)", selection: $draft.level) {
                        Text("نامشخص").tag(CEFRLevel?.none)
                        ForEach(CEFRLevel.allCases) { Text($0.rawValue).tag(CEFRLevel?.some($0)) }
                    }
                }
                meaningsSection
                examplesSection
                RelatedWordsSection(title: "مترادف‌ها (Synonyms)", words: $draft.synonyms)
                RelatedWordsSection(title: "متضادها (Antonyms)", words: $draft.antonyms)
                Section("یادداشت شخصی") {
                    TextField("مثلاً نکتهٔ تلفظ یا جمله‌ای که خودتان ساختید", text: $draft.note, axis: .vertical)
                        .lineLimit(3...8)
                }
                if isNew {
                    Section {
                        Toggle(isOn: $addToReview) {
                            Label("افزودن به جعبهٔ لایتنر", systemImage: "rectangle.stack.badge.plus")
                        }
                    } footer: {
                        Text("کارت مرور این لغت همین حالا ساخته می‌شود.")
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(isNew ? "لغت جدید" : "ویرایش لغت")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("بستن", systemImage: "xmark") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("ذخیره", systemImage: "checkmark", action: save)
                        .buttonStyle(.glassProminent)
                        .tint(RavanColor.brand)
                }
            }
            .task { load() }
        }
    }

    // MARK: Sections

    private var headwordSection: some View {
        Section {
            TextField("لغت انگلیسی", text: $draft.text)
                .font(.headword(.title2))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .text)
                .environment(\.layoutDirection, .leftToRight)
            LabeledContent("تلفظ آمریکایی") {
                TextField("/ˈwɔtər/", text: $draft.phoneticUS)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .environment(\.layoutDirection, .leftToRight)
            }
            LabeledContent("تلفظ بریتانیایی") {
                TextField("/ˈwɔːtə/", text: $draft.phoneticUK)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .environment(\.layoutDirection, .leftToRight)
            }
        } header: {
            Text("لغت")
        } footer: {
            if let error {
                VStack(alignment: .leading, spacing: 6) {
                    Text(error.message).foregroundStyle(RavanColor.danger)
                    if let duplicateID {
                        Button("مشاهدهٔ لغت موجود") {
                            dismiss()
                            onSaved(duplicateID, true)
                        }
                    }
                }
            }
        }
    }

    private var meaningsSection: some View {
        Section("معانی") {
            ForEach($draft.meanings) { $meaning in
                VStack(alignment: .leading, spacing: 8) {
                    TextField("معنی فارسی", text: $meaning.translation)
                        .font(.body.weight(.medium))
                    TextField("توضیح (اختیاری)", text: $meaning.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .onDelete { draft.meanings.remove(atOffsets: $0) }
            Button("افزودن معنی", systemImage: "plus") { draft.meanings.append(.init()) }
        }
    }

    private var examplesSection: some View {
        Section("جمله‌های مثال") {
            ForEach($draft.examples) { $example in
                VStack(alignment: .leading, spacing: 8) {
                    TextField("English sentence", text: $example.english, axis: .vertical)
                        .font(.englishSentence)
                        .environment(\.layoutDirection, .leftToRight)
                    TextField("ترجمهٔ فارسی", text: $example.persian, axis: .vertical)
                        .font(.subheadline)
                }
            }
            .onDelete { draft.examples.remove(atOffsets: $0) }
            Button("افزودن مثال", systemImage: "plus") { draft.examples.append(.init()) }
        }
    }

    // MARK: Actions

    private func load() {
        guard let wordID = request.wordID else {
            draft.text = request.initialText
            focusedField = .text
            return
        }
        guard let word = store.word(id: wordID) else { return }
        original = word
        draft = Draft(word: word)
    }

    private func save() {
        let text = draft.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return fail(.emptyWord) }
        let meanings = draft.meanings
            .map { Meaning(translation: $0.translation.trimmed, description: $0.description.trimmed) }
            .filter { !$0.translation.isEmpty }
        guard !meanings.isEmpty else { return fail(.noMeaning) }
        if let existing = store.findWord(text: text), existing.id != original?.id {
            duplicateID = existing.id
            return fail(.duplicate)
        }

        var word = original ?? Word(text: text)
        word.text = text
        word.phoneticUS = draft.phoneticUS.trimmed
        word.phoneticUK = draft.phoneticUK.trimmed
        word.partOfSpeech = draft.partOfSpeech
        word.level = draft.level
        word.meanings = meanings
        word.examples = draft.examples
            .map { Example(english: $0.english.trimmed, persian: $0.persian.trimmed) }
            .filter { !$0.english.isEmpty }
        word.synonyms = draft.synonyms
        word.antonyms = draft.antonyms
        word.note = draft.note.trimmed

        let id = store.save(word, addToReview: isNew && addToReview)
        dismiss()
        onSaved(id, isNew)
    }

    private func fail(_ error: EditorError) {
        withAnimation { self.error = error }
    }
}

// MARK: - Draft model

private enum Field: Hashable { case text }

private enum EditorError {
    case emptyWord, noMeaning, duplicate

    var message: String {
        switch self {
        case .emptyWord: "لغت انگلیسی را وارد کنید."
        case .noMeaning: "دست‌کم یک معنی فارسی لازم است."
        case .duplicate: "این لغت قبلاً در دیکشنری هست."
        }
    }
}

private struct Draft {
    struct MeaningInput: Identifiable {
        let id = UUID()
        var translation = ""
        var description = ""
    }

    struct ExampleInput: Identifiable {
        let id = UUID()
        var english = ""
        var persian = ""
    }

    var text = ""
    var phoneticUS = ""
    var phoneticUK = ""
    var partOfSpeech: PartOfSpeech = .noun
    var level: CEFRLevel?
    var meanings: [MeaningInput] = [MeaningInput()]
    var examples: [ExampleInput] = [ExampleInput()]
    var synonyms: [String] = []
    var antonyms: [String] = []
    var note = ""

    init() {}

    init(word: Word) {
        text = word.text
        phoneticUS = word.phoneticUS
        phoneticUK = word.phoneticUK
        partOfSpeech = word.partOfSpeech
        level = word.level
        meanings = word.meanings.map { MeaningInput(translation: $0.translation, description: $0.description) }
        if meanings.isEmpty { meanings = [MeaningInput()] }
        examples = word.examples.map { ExampleInput(english: $0.english, persian: $0.persian) }
        if examples.isEmpty { examples = [ExampleInput()] }
        synonyms = word.synonyms
        antonyms = word.antonyms
        note = word.note
    }
}

/// Chip-style input for synonyms / antonyms.
private struct RelatedWordsSection: View {
    let title: String
    @Binding var words: [String]
    @State private var input = ""

    var body: some View {
        Section(title) {
            HStack {
                TextField("یک لغت بنویسید و + بزنید", text: $input)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onSubmit(add)
                Button("افزودن", systemImage: "plus.circle.fill", action: add)
                    .labelStyle(.iconOnly)
                    .disabled(input.trimmed.isEmpty)
            }
            if !words.isEmpty {
                FlowLayout {
                    ForEach(words, id: \.self) { word in
                        Button {
                            words.removeAll { $0 == word }
                        } label: {
                            Label(word, systemImage: "xmark")
                                .labelStyle(.titleAndIcon)
                                .font(.subheadline)
                        }
                        .buttonStyle(.glass)
                        .accessibilityLabel("حذف \(word)")
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func add() {
        let value = input.trimmed
        guard !value.isEmpty, !words.contains(where: { $0.caseInsensitiveCompare(value) == .orderedSame }) else { return }
        words.append(value)
        input = ""
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
