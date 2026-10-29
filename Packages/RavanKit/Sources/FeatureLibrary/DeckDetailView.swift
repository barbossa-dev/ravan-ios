import RavanUI
import SwiftUI

public struct DeckDetailView: View {
    private let deckID: String

    @Environment(DictionaryStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss

    @State private var deck: Deck?
    @State private var words: [Word] = []
    @State private var showPicker = false
    @State private var showRename = false
    @State private var showDeleteConfirmation = false
    @State private var addedToReview = false

    public init(deckID: String) {
        self.deckID = deckID
    }

    public var body: some View {
        List {
            if let deck {
                Section {
                    GlassCard(tint: RavanColor.deck(deck.colorIndex)) {
                        Text("\(words.count.persianDigits) لغت").font(.title2.bold())
                        GlassEffectContainer(spacing: 8) {
                            HStack(spacing: 8) {
                                Button {
                                    router.startReview(deckID: deckID)
                                } label: {
                                    Label("مرور این دسته", systemImage: "play.fill")
                                }
                                .buttonStyle(.glassProminent)
                                .tint(RavanColor.brand)
                                Button("همه به لایتنر", systemImage: "rectangle.stack.badge.plus") {
                                    store.addToReview(wordIDs: words.map(\.id))
                                    addedToReview = true
                                }
                                .buttonStyle(.glass)
                            }
                        }
                        .disabled(words.isEmpty)
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
                if words.isEmpty {
                    ContentUnavailableView(
                        "این دسته خالی است",
                        systemImage: "folder",
                        description: Text("با دکمهٔ + از دیکشنری لغت انتخاب کنید.")
                    )
                    .listRowBackground(Color.clear)
                } else {
                    Section {
                        ForEach(words) { word in
                            NavigationLink(value: AppRoute.word(word.id)) { WordRow(word: word) }
                                .swipeActions {
                                    Button("حذف از دسته", systemImage: "minus.circle", role: .destructive) {
                                        store.removeWord(word.id, fromDeck: deckID)
                                    }
                                }
                        }
                    }
                }
            }
        }
        .ravanBackground()
        .navigationTitle(deck?.name ?? "")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("افزودن لغت", systemImage: "plus") { showPicker = true }
            }
            ToolbarSpacer(.fixed, placement: .topBarTrailing)
            ToolbarItem(placement: .topBarTrailing) {
                Menu("گزینه‌های بیشتر", systemImage: "ellipsis") {
                    Button("ویرایش دسته", systemImage: "pencil") { showRename = true }
                    Button("حذف دسته", systemImage: "trash", role: .destructive) { showDeleteConfirmation = true }
                }
            }
        }
        .sheet(isPresented: $showPicker) {
            WordPickerSheet(excluded: Set(words.map(\.id))) { ids in
                store.addWords(Array(ids), toDeck: deckID)
            }
        }
        .sheet(isPresented: $showRename) {
            DeckEditorSheet(deck: deck).presentationDetents([.medium])
        }
        .confirmationDialog("حذف دستهٔ «\(deck?.name ?? "")»؟", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("حذف دسته", role: .destructive) {
                store.deleteDeck(id: deckID)
                dismiss()
            }
        } message: {
            Text("خود لغت‌ها حذف نمی‌شوند؛ فقط این دسته پاک می‌شود.")
        }
        .alert("لغت‌های این دسته به جعبهٔ لایتنر اضافه شدند", isPresented: $addedToReview) {
            Button("باشه", role: .cancel) {}
        }
        .task(id: store.revision) {
            deck = store.deck(id: deckID)
            words = store.words(inDeck: deckID)
        }
    }
}

/// Multi-select search over the whole dictionary.
private struct WordPickerSheet: View {
    let excluded: Set<String>
    let onConfirm: (Set<String>) -> Void

    @Environment(DictionaryStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [Word] = []
    @State private var selected: Set<String> = []

    var body: some View {
        NavigationStack {
            List(results.filter { !excluded.contains($0.id) }) { word in
                Button {
                    if selected.contains(word.id) { selected.remove(word.id) } else { selected.insert(word.id) }
                } label: {
                    WordRow(word: word) {
                        Image(systemName: selected.contains(word.id) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(selected.contains(word.id) ? RavanColor.brand : .secondary)
                            .font(.title3)
                    }
                }
                .buttonStyle(.plain)
            }
            .navigationTitle("انتخاب لغت‌ها")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "جستجو در دیکشنری")
            .textInputAutocapitalization(.never)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("انصراف", systemImage: "xmark") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("افزودن \(selected.count.persianDigits)") {
                        onConfirm(selected)
                        dismiss()
                    }
                    .buttonStyle(.glassProminent)
                    .tint(RavanColor.brand)
                    .disabled(selected.isEmpty)
                }
            }
            .task(id: query) {
                try? await Task.sleep(for: .milliseconds(150))
                guard !Task.isCancelled else { return }
                results = query.trimmingCharacters(in: .whitespaces).isEmpty
                    ? store.recentWords(limit: 50)
                    : store.search(query, limit: 100)
            }
        }
    }
}
