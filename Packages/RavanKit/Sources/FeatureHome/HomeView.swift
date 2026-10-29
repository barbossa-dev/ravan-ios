import RavanUI
import SwiftUI

/// Home: review call-out, word of the day and recently viewed words.
public struct HomeView: View {
    @Environment(DictionaryStore.self) private var store
    @Environment(SettingsStore.self) private var settings
    @Environment(Pronouncer.self) private var pronouncer
    @Environment(AppRouter.self) private var router

    @State private var wordOfTheDay: Word?
    @State private var recentWords: [Word] = []
    @State private var dueCount = 0
    @State private var wordCount = 0

    public init() {}

    public var body: some View {
        ScrollView {
            GlassEffectContainer(spacing: 20) {
                VStack(spacing: 16) {
                    if store.status == .preparing {
                        PreparingCard()
                    }
                    ReviewCallout(dueCount: dueCount, wordCount: wordCount) { router.startReview() }
                    if let wordOfTheDay {
                        WordOfTheDayCard(
                            word: wordOfTheDay,
                            accent: settings.accent,
                            isSpeaking: pronouncer.speakingText == wordOfTheDay.text
                        ) {
                            pronouncer.speak(wordOfTheDay.text, settings: settings)
                        }
                    }
                    recentSection
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
        }
        .ravanBackground()
        .navigationTitle("روان")
        .navigationSubtitle("دیکشنری انگلیسی به فارسی")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("جستجو", systemImage: "magnifyingglass") { router.select(.search) }
            }
            ToolbarSpacer(.fixed, placement: .topBarTrailing)
            ToolbarItem(placement: .topBarTrailing) {
                Button("لغت جدید", systemImage: "plus") { router.openEditor() }
            }
        }
        .task(id: store.revision) { load() }
    }

    @ViewBuilder
    private var recentSection: some View {
        if recentWords.isEmpty {
            GlassCard {
                Label("از کجا شروع کنم؟", systemImage: "lightbulb.fill")
                    .font(.headline)
                    .foregroundStyle(RavanColor.saffron)
                Text("لغتی را جستجو کنید، آن را به جعبهٔ لایتنر اضافه کنید و هر روز چند دقیقه مرور کنید.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        } else {
            SectionTitle("اخیراً دیده‌شده")
            GlassCard(cornerRadius: 22) {
                ForEach(recentWords) { word in
                    NavigationLink(value: AppRoute.word(word.id)) {
                        WordRow(word: word)
                    }
                    .buttonStyle(.plain)
                    if word.id != recentWords.last?.id { Divider() }
                }
            }
        }
    }

    private func load() {
        wordOfTheDay = store.wordOfTheDay()
        recentWords = store.recentWords(limit: 6)
        dueCount = store.dueCount()
        wordCount = store.wordCount()
    }
}

private struct PreparingCard: View {
    var body: some View {
        GlassCard {
            HStack(spacing: 12) {
                ProgressView()
                VStack(alignment: .leading, spacing: 2) {
                    Text("در حال آماده‌سازی دیکشنری…").font(.headline)
                    Text("فقط بار اول چند ثانیه طول می‌کشد.").font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct ReviewCallout: View {
    let dueCount: Int
    let wordCount: Int
    let onStart: () -> Void

    var body: some View {
        GlassCard(tint: RavanColor.brand) {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    if dueCount > 0 {
                        Text("\(dueCount.persianDigits) کارت آمادهٔ مرور")
                            .font(.title3.bold())
                        Text("چند دقیقه مرور، لغت‌ها را در حافظهٔ بلندمدت نگه می‌دارد.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("\(wordCount.persianDigits) لغت در دیکشنری شما")
                            .font(.headline)
                        Text("امروز کارتی برای مرور ندارید.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
                if dueCount > 0 {
                    Button("شروع مرور", action: onStart)
                        .buttonStyle(.glassProminent)
                        .tint(RavanColor.brand)
                }
            }
        }
    }
}

private struct WordOfTheDayCard: View {
    let word: Word
    let accent: Accent
    let isSpeaking: Bool
    let onSpeak: () -> Void

    var body: some View {
        NavigationLink(value: AppRoute.word(word.id)) {
            GlassCard(tint: RavanColor.saffron) {
                HStack {
                    Pill("لغت روز", systemImage: "sparkles", tint: RavanColor.saffron)
                    Text(word.partOfSpeech.persianLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    SpeakButton(isSpeaking: isSpeaking, action: onSpeak)
                }
                Text(verbatim: word.text)
                    .font(.headword(.largeTitle))
                    .foregroundStyle(.primary)
                if !word.phonetic(for: accent).isEmpty {
                    Text(verbatim: word.phonetic(for: accent))
                        .font(.phonetic)
                        .foregroundStyle(.secondary)
                }
                Text(word.primaryTranslation)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                if let example = word.examples.first {
                    EnglishText(example.english, leftAligned: true)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
