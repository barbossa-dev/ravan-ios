import RavanUI
import SwiftUI

/// The user's own library: recently viewed, favourites, own words, Leitner words — and decks.
public struct LibraryView: View {
    private enum Mode: String, CaseIterable, Identifiable {
        case words, decks
        var id: String { rawValue }
        var title: String { self == .words ? "لغت‌ها" : "دسته‌ها" }
    }

    @Environment(DictionaryStore.self) private var store
    @Environment(AppRouter.self) private var router

    @State private var mode: Mode = .words
    @State private var filter: WordFilter = .recent
    @State private var words: [Word] = []
    @State private var decks: [Deck] = []
    @State private var deckEditor: DeckEditorRequest?

    public init() {}

    public var body: some View {
        Group {
            switch mode {
            case .words: wordsList
            case .decks: decksGrid
            }
        }
        .ravanBackground()
        .navigationTitle("واژه‌های من")
        .safeAreaInset(edge: .top, spacing: 0) {
            Picker("نمایش", selection: $mode) {
                ForEach(Mode.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                switch mode {
                case .words:
                    Button("لغت جدید", systemImage: "plus") { router.openEditor() }
                case .decks:
                    Button("دستهٔ جدید", systemImage: "folder.badge.plus") { deckEditor = DeckEditorRequest(deck: nil) }
                }
            }
        }
        .sheet(item: $deckEditor) { request in
            DeckEditorSheet(deck: request.deck)
                .presentationDetents([.medium])
        }
        .task(id: LoadKey(revision: store.revision, filter: filter)) {
            words = store.words(filter: filter)
            decks = store.decks()
        }
    }

    private var wordsList: some View {
        List {
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    GlassEffectContainer(spacing: 8) {
                        HStack(spacing: 8) {
                            ForEach(WordFilter.allCases) { option in
                                Button(option.persianLabel) { filter = option }
                                    .buttonStyle(.glass)
                                    .tint(option == filter ? RavanColor.brand : nil)
                                    .fontWeight(option == filter ? .bold : .regular)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
            if words.isEmpty {
                ContentUnavailableView(
                    "چیزی اینجا نیست",
                    systemImage: "books.vertical",
                    description: Text(emptyMessage)
                )
                .listRowBackground(Color.clear)
            } else {
                Section("\(words.count.persianDigits) لغت") {
                    ForEach(words) { word in
                        NavigationLink(value: AppRoute.word(word.id)) { WordRow(word: word) }
                    }
                }
            }
        }
    }

    private var emptyMessage: String {
        switch filter {
        case .recent: "لغت‌هایی که در دیکشنری باز می‌کنید اینجا می‌آیند."
        case .favorites: "با زدن ستاره در صفحهٔ هر لغت، آن را نشان کنید."
        case .mine: "لغت‌هایی که خودتان اضافه می‌کنید اینجا می‌آیند."
        case .inReview: "لغت‌ها را از صفحهٔ هر لغت به جعبهٔ لایتنر اضافه کنید."
        }
    }

    @ViewBuilder
    private var decksGrid: some View {
        if decks.isEmpty {
            ContentUnavailableView {
                Label("هنوز دسته‌ای ندارید", systemImage: "folder")
            } description: {
                Text("لغت‌ها را دسته‌بندی کنید؛ مثلاً «آیلتس»، «سفر» یا «کار» و هر دسته را جدا مرور کنید.")
            } actions: {
                Button("دستهٔ جدید") { deckEditor = DeckEditorRequest(deck: nil) }
                    .buttonStyle(.glassProminent)
                    .tint(RavanColor.brand)
            }
        } else {
            ScrollView {
                GlassEffectContainer(spacing: 12) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 12)], spacing: 12) {
                        ForEach(decks) { deck in
                            NavigationLink(value: AppRoute.deck(deck.id)) { DeckCard(deck: deck) }
                                .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
            }
        }
    }
}

private struct LoadKey: Hashable {
    let revision: Int
    let filter: WordFilter
}

private struct DeckCard: View {
    let deck: Deck

    var body: some View {
        GlassCard(tint: RavanColor.deck(deck.colorIndex)) {
            Image(systemName: "folder.fill")
                .font(.title2)
                .foregroundStyle(RavanColor.deck(deck.colorIndex))
            Text(deck.name)
                .font(.headline)
                .lineLimit(2)
            Text("\(deck.wordCount.persianDigits) لغت")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

struct DeckEditorRequest: Identifiable {
    let id = UUID()
    let deck: Deck?
}

/// Create or rename a deck and pick its colour.
struct DeckEditorSheet: View {
    let deck: Deck?

    @Environment(DictionaryStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var colorIndex = 0

    var body: some View {
        NavigationStack {
            Form {
                TextField("نام دسته", text: $name)
                Section("رنگ") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 14) {
                        ForEach(RavanColor.decks.indices, id: \.self) { index in
                            Button {
                                colorIndex = index
                            } label: {
                                Circle()
                                    .fill(RavanColor.deck(index))
                                    .frame(width: 40, height: 40)
                                    .overlay {
                                        if index == colorIndex {
                                            Image(systemName: "checkmark").font(.headline).foregroundStyle(.white)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("رنگ \((index + 1).persianDigits)")
                            .accessibilityAddTraits(index == colorIndex ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
            .navigationTitle(deck == nil ? "دستهٔ جدید" : "ویرایش دسته")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("انصراف", systemImage: "xmark") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("ذخیره", systemImage: "checkmark") {
                        if let deck {
                            store.updateDeck(id: deck.id, name: name, colorIndex: colorIndex)
                        } else {
                            store.createDeck(name: name, colorIndex: colorIndex)
                        }
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                name = deck?.name ?? ""
                colorIndex = deck?.colorIndex ?? Int.random(in: 0..<RavanColor.decks.count)
            }
        }
    }
}
