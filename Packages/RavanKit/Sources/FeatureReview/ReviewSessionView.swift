import RavanUI
import SwiftUI

/// Full-screen flash-card session.
public struct ReviewSessionView: View {
    private let request: SessionRequest

    @Environment(DictionaryStore.self) private var store
    @Environment(SettingsStore.self) private var settings
    @Environment(Pronouncer.self) private var pronouncer
    @Environment(\.dismiss) private var dismiss

    @State private var items: [ReviewItem] = []
    @State private var index = 0
    @State private var isFlipped = false
    @State private var correctCount = 0
    @State private var wrongWords: [Word] = []
    @State private var isLoaded = false

    public init(request: SessionRequest) {
        self.request = request
    }

    private var isFinished: Bool { isLoaded && !items.isEmpty && index >= items.count }

    public var body: some View {
        NavigationStack {
            Group {
                if !isLoaded {
                    ProgressView()
                } else if items.isEmpty {
                    ContentUnavailableView {
                        Label("کارتی برای مرور نیست", systemImage: "checkmark.seal")
                    } description: {
                        Text("فعلاً همهٔ کارت‌ها مرور شده‌اند. بعداً دوباره سر بزنید.")
                    } actions: {
                        Button("پایان") { dismiss() }.buttonStyle(.glassProminent)
                    }
                } else if isFinished {
                    summary
                } else {
                    session
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background { RavanBackground() }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("بستن", systemImage: "xmark") {
                        pronouncer.stop()
                        dismiss()
                    }
                }
                if !items.isEmpty && !isFinished {
                    ToolbarItem(placement: .principal) {
                        Text("\((index + 1).persianDigits) از \(items.count.persianDigits)")
                            .font(.headline)
                            .contentTransition(.numericText())
                    }
                }
            }
        }
        .sensoryFeedback(.success, trigger: correctCount)
        .sensoryFeedback(.warning, trigger: wrongWords.count)
        .task { load() }
    }

    // MARK: Session

    private var session: some View {
        VStack(spacing: 20) {
            ProgressView(value: Double(index), total: Double(items.count))
                .tint(RavanColor.brand)
            if request.practice {
                Pill("تمرین آزاد · خانه‌ها تغییر نمی‌کنند", systemImage: "shuffle", tint: RavanColor.saffron)
            }
            FlashCard(item: items[index], isFlipped: isFlipped, accent: settings.accent, speakingText: pronouncer.speakingText) {
                pronouncer.speak($0, settings: settings)
            }
            .id(items[index].id)
            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
            .onTapGesture(perform: flip)
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("برای دیدن جواب دو بار ضربه بزنید")

            GlassEffectContainer(spacing: 12) {
                if isFlipped {
                    HStack(spacing: 12) {
                        Button {
                            answer(correct: false)
                        } label: {
                            Label("بلد نبودم", systemImage: "xmark").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.glass)
                        .tint(RavanColor.danger)

                        Button {
                            answer(correct: true)
                        } label: {
                            Label("بلد بودم", systemImage: "checkmark").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.glassProminent)
                        .tint(RavanColor.success)
                    }
                } else {
                    Button(action: flip) {
                        Text("نمایش پاسخ").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(RavanColor.brand)
                }
            }
            .controlSize(.extraLarge)
        }
        .padding()
    }

    private var summary: some View {
        ScrollView {
            VStack(spacing: 16) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(RavanColor.saffron)
                    .symbolEffect(.bounce, value: isFinished)
                    .padding(.top, 32)
                Text("آفرین!").font(.largeTitle.bold())
                Text("\(correctCount.persianDigits) کارت از \(items.count.persianDigits) را درست جواب دادید.")
                    .font(.title3)
                    .multilineTextAlignment(.center)
                if !wrongWords.isEmpty {
                    SectionTitle("این لغت‌ها را دوباره ببینید")
                    GlassCard {
                        ForEach(wrongWords) { word in
                            WordRow(word: word)
                        }
                    }
                }
                Button {
                    dismiss()
                } label: {
                    Text("پایان").frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .tint(RavanColor.brand)
                .controlSize(.extraLarge)
            }
            .padding()
        }
    }

    // MARK: Logic

    private func load() {
        let limit = max(settings.dailyGoal, 10)
        let direction = settings.reviewDirection
        items = store.sessionCards(deckID: request.deckID, includeNotDue: request.practice, limit: limit)
            .shuffled()
            .map { pair in
                let resolved: ReviewDirection = direction == .mixed
                    ? (Bool.random() ? .englishToPersian : .persianToEnglish)
                    : direction
                return ReviewItem(word: pair.word, card: pair.card, direction: resolved)
            }
        isLoaded = true
        pronounceFront()
    }

    private func flip() {
        withAnimation(.spring(duration: 0.5)) { isFlipped.toggle() }
        let item = items[index]
        if isFlipped, item.direction == .persianToEnglish, settings.autoPronounce {
            pronouncer.speak(item.word.text, settings: settings)
        }
    }

    private func answer(correct: Bool) {
        let item = items[index]
        store.recordAnswer(card: item.card, correct: correct, reschedule: !request.practice)
        if correct { correctCount += 1 } else if !wrongWords.contains(item.word) { wrongWords.append(item.word) }
        withAnimation(.snappy) {
            isFlipped = false
            index += 1
        }
        if index < items.count { pronounceFront() } else { pronouncer.stop() }
    }

    private func pronounceFront() {
        guard index < items.count, settings.autoPronounce, items[index].direction == .englishToPersian else { return }
        pronouncer.speak(items[index].word.text, settings: settings)
    }
}

/// A card that turns over in 3D: question on the front, full answer on the back.
private struct FlashCard: View {
    let item: ReviewItem
    let isFlipped: Bool
    let accent: Accent
    let speakingText: String?
    let onSpeak: (String) -> Void

    var body: some View {
        ZStack {
            face { front }
                .opacity(isFlipped ? 0 : 1)
            face { back }
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                .opacity(isFlipped ? 1 : 0)
        }
        .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func face<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .glassEffect(.regular.tint(RavanColor.brand.opacity(0.12)), in: .rect(cornerRadius: 36))
    }

    private var front: some View {
        VStack(spacing: 14) {
            Pill(item.word.partOfSpeech.persianLabel)
            if item.direction == .persianToEnglish {
                ForEach(Array(item.word.meanings.prefix(2).enumerated()), id: \.offset) { _, meaning in
                    Text(meaning.translation)
                        .font(.title.bold())
                        .multilineTextAlignment(.center)
                }
            } else {
                Text(verbatim: item.word.text)
                    .font(.headword(.largeTitle))
                    .minimumScaleFactor(0.5)
                    .lineLimit(2)
                if !item.word.phonetic(for: accent).isEmpty {
                    Text(verbatim: item.word.phonetic(for: accent)).font(.phonetic).foregroundStyle(.secondary)
                }
                SpeakButton(isSpeaking: speakingText == item.word.text) { onSpeak(item.word.text) }
            }
            Text("برای دیدن جواب، کارت را لمس کنید")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.top, 24)
        }
    }

    private var back: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: item.word.text).font(.headword(.title))
                        if !item.word.phonetic(for: accent).isEmpty {
                            Text(verbatim: item.word.phonetic(for: accent)).font(.phonetic).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    SpeakButton(isSpeaking: speakingText == item.word.text) { onSpeak(item.word.text) }
                }
                Divider()
                ForEach(Array(item.word.meanings.prefix(4).enumerated()), id: \.offset) { _, meaning in
                    VStack(alignment: .leading, spacing: 2) {
                        if !meaning.description.isEmpty {
                            Text(meaning.description).font(.caption.weight(.semibold)).foregroundStyle(RavanColor.saffron)
                        }
                        Text(meaning.translation).font(.title3.weight(.semibold))
                    }
                }
                if let example = item.word.examples.first {
                    Divider()
                    EnglishText(example.english, leftAligned: true)
                    if !example.persian.isEmpty {
                        Text(example.persian).font(.subheadline).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
    }
}
