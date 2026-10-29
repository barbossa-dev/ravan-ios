import Charts
import RavanUI
import SwiftUI

/// Leitner overview: what is due, streak, daily goal, box distribution and weekly activity.
public struct ReviewDashboardView: View {
    @Environment(DictionaryStore.self) private var store
    @Environment(SettingsStore.self) private var settings
    @Environment(AppRouter.self) private var router

    @State private var stats: ReviewStats?
    @State private var decks: [Deck] = []

    public init() {}

    public var body: some View {
        Group {
            if let stats {
                if stats.totalCards == 0 {
                    ContentUnavailableView {
                        Label("جعبهٔ لایتنر خالی است", systemImage: "rectangle.stack")
                    } description: {
                        Text("در صفحهٔ هر لغت، «افزودن به جعبهٔ لایتنر» را بزنید تا کارت مرورش ساخته شود.")
                    } actions: {
                        Button("جستجو در دیکشنری") { router.select(.search) }
                            .buttonStyle(.glassProminent)
                            .tint(RavanColor.brand)
                    }
                } else {
                    dashboard(stats)
                }
            } else {
                ProgressView()
            }
        }
        .ravanBackground()
        .navigationTitle("مرور")
        .task(id: store.revision) {
            stats = store.reviewStats(dailyGoal: settings.dailyGoal)
            decks = store.decks().filter { $0.wordCount > 0 }
        }
    }

    private func dashboard(_ stats: ReviewStats) -> some View {
        ScrollView {
            GlassEffectContainer(spacing: 16) {
                VStack(spacing: 16) {
                    hero(stats)
                    HStack(spacing: 12) {
                        StatTile(value: stats.streakDays.persianDigits, label: "روز پیاپی", systemImage: "flame.fill", tint: .orange)
                        StatTile(
                            value: "\(stats.reviewedToday.persianDigits)/\(stats.dailyGoal.persianDigits)",
                            label: "هدف امروز",
                            systemImage: "target",
                            tint: RavanColor.brand,
                            progress: stats.goalProgress
                        )
                        StatTile(value: stats.masteredCount.persianDigits, label: "یاد گرفته‌شده", systemImage: "trophy.fill", tint: RavanColor.saffron)
                    }
                    boxesChart(stats)
                    weekChart(stats)
                    if !decks.isEmpty {
                        SectionTitle("مرور بر اساس دسته")
                        ForEach(decks) { deck in
                            GlassCard {
                                HStack {
                                    Circle().fill(RavanColor.deck(deck.colorIndex)).frame(width: 12, height: 12)
                                    VStack(alignment: .leading) {
                                        Text(deck.name).font(.headline)
                                        Text("\(deck.wordCount.persianDigits) لغت").font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Button("مرور") { router.startReview(deckID: deck.id) }
                                        .buttonStyle(.glass)
                                }
                            }
                        }
                    }
                    howItWorks
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
        }
    }

    private func hero(_ stats: ReviewStats) -> some View {
        GlassCard(tint: RavanColor.brand) {
            Text("آمادهٔ مرور امروز").font(.headline)
            Text("\(stats.dueCount.persianDigits) کارت")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .contentTransition(.numericText())
            if stats.dueCount > 0 {
                Button {
                    router.startReview()
                } label: {
                    Label("شروع مرور", systemImage: "play.fill").frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .tint(RavanColor.brand)
                .controlSize(.large)
            } else {
                Text("امروز همهٔ کارت‌ها را مرور کرده‌اید. اگر بخواهید می‌توانید تمرین آزاد کنید.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button {
                    router.startReview(practice: true)
                } label: {
                    Label("تمرین آزاد", systemImage: "shuffle").frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
                .controlSize(.large)
            }
        }
    }

    private func boxesChart(_ stats: ReviewStats) -> some View {
        GlassCard {
            Text("خانه‌های لایتنر").font(.headline)
            Chart(Array(stats.boxCounts.enumerated()), id: \.offset) { index, count in
                BarMark(
                    x: .value("خانه", index + 1 > Leitner.boxCount ? "بلدم" : (index + 1).persianDigits),
                    y: .value("کارت", count)
                )
                .foregroundStyle(index + 1 > Leitner.boxCount ? RavanColor.saffron : RavanColor.brand)
                .cornerRadius(6)
                .annotation(position: .top) {
                    Text(count.persianDigits).font(.caption2).foregroundStyle(.secondary)
                }
            }
            .chartYAxis(.hidden)
            .frame(height: 150)
            .accessibilityLabel("تعداد کارت‌ها در هر خانهٔ لایتنر")
        }
    }

    private func weekChart(_ stats: ReviewStats) -> some View {
        GlassCard {
            HStack {
                Text("فعالیت هفت روز اخیر").font(.headline)
                Spacer()
                Text("دقت \(Int((stats.accuracy * 100).rounded()).persianDigits)٪")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Chart(stats.lastSevenDays) { day in
                BarMark(
                    x: .value("روز", day.day, unit: .day),
                    y: .value("مرور", day.reviewed)
                )
                .foregroundStyle(Calendar.current.isDateInToday(day.day) ? RavanColor.brand : RavanColor.brand.opacity(0.4))
                .cornerRadius(6)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisValueLabel(format: .dateTime.weekday(.narrow))
                }
            }
            .frame(height: 150)
            .environment(\.locale, Locale(identifier: "fa_IR"))
            .accessibilityLabel("تعداد مرورها در هفت روز اخیر")
        }
    }

    private var howItWorks: some View {
        GlassCard(tint: RavanColor.saffron) {
            Label("جعبهٔ لایتنر چطور کار می‌کند؟", systemImage: "lightbulb.fill").font(.headline)
            Text("هر کارت از خانهٔ ۱ شروع می‌شود. اگر جواب را بدانید یک خانه جلو می‌رود و دیرتر دوباره می‌آید (۱، ۲، ۴، ۸ و ۱۶ روز بعد). اگر ندانید به خانهٔ ۱ برمی‌گردد. کارتی که از خانهٔ ۵ هم بگذرد «یاد گرفته‌شده» است.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

private struct StatTile: View {
    let value: String
    let label: String
    let systemImage: String
    let tint: Color
    var progress: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: systemImage).foregroundStyle(tint)
            Text(value).font(.title3.bold()).lineLimit(1).minimumScaleFactor(0.7)
            Text(label).font(.caption).foregroundStyle(.secondary)
            if let progress {
                ProgressView(value: progress).tint(tint)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
        .accessibilityElement(children: .combine)
    }
}
