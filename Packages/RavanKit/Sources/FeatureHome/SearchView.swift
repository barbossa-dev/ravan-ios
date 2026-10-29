import RavanUI
import SwiftUI

/// The search tab. On iOS 26 its field lives in the Liquid Glass tab bar.
public struct SearchView: View {
    @Environment(DictionaryStore.self) private var store
    @Environment(SettingsStore.self) private var settings
    @Environment(Pronouncer.self) private var pronouncer
    @Environment(AppRouter.self) private var router

    @State private var query = ""
    @State private var results: [Word] = []
    @State private var recentWords: [Word] = []

    public init() {}

    public var body: some View {
        List {
            if query.trimmingCharacters(in: .whitespaces).isEmpty {
                if !recentWords.isEmpty {
                    Section("اخیراً دیده‌شده") {
                        ForEach(recentWords) { word in
                            NavigationLink(value: AppRoute.word(word.id)) { WordRow(word: word) }
                        }
                    }
                }
            } else if results.isEmpty {
                ContentUnavailableView {
                    Label("«\(query)» پیدا نشد", systemImage: "magnifyingglass")
                } description: {
                    Text("می‌توانید این لغت را با معنی و مثال خودتان به دیکشنری اضافه کنید.")
                } actions: {
                    Button("افزودن به دیکشنری") { router.openEditor(initialText: query) }
                        .buttonStyle(.glassProminent)
                }
                .listRowBackground(Color.clear)
            } else {
                Section("\(results.count.persianDigits) نتیجه") {
                    ForEach(results) { word in
                        NavigationLink(value: AppRoute.word(word.id)) {
                            WordRow(word: word) {
                                SpeakButton(isSpeaking: pronouncer.speakingText == word.text) {
                                    pronouncer.speak(word.text, settings: settings)
                                }
                            }
                        }
                    }
                }
            }
        }
        .ravanBackground()
        .navigationTitle("جستجو")
        .searchable(text: $query, prompt: "لغت انگلیسی یا معنی فارسی")
        .autocorrectionDisabled()
        .textInputAutocapitalization(.never)
        .task(id: SearchKey(query: query, revision: store.revision)) {
            // Debounce: the task is cancelled when the user keeps typing.
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            results = store.search(query)
            recentWords = store.recentWords(limit: 10)
        }
    }
}

private struct SearchKey: Hashable {
    let query: String
    let revision: Int
}
