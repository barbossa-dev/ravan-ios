import RavanUI
import SwiftUI
import UniformTypeIdentifiers

public struct SettingsView: View {
    @Environment(DictionaryStore.self) private var store
    @Environment(SettingsStore.self) private var settings
    @Environment(Pronouncer.self) private var pronouncer

    @State private var wordCount = 0
    @State private var exportFile: BackupFile?
    @State private var showExporter = false
    @State private var showImporter = false
    @State private var pendingImport: URL?
    @State private var message: String?

    public init() {}

    public var body: some View {
        @Bindable var settings = settings
        Form {
            Section("ظاهر") {
                Picker("تم", selection: $settings.theme) {
                    ForEach(ThemePreference.allCases) { Text($0.persianLabel).tag($0) }
                }
                .pickerStyle(.segmented)
            }

            Section("تلفظ") {
                Picker("لهجهٔ پیش‌فرض", selection: $settings.accent) {
                    ForEach(Accent.allCases) { Text("\($0.persianName) (\($0.shortLabel))").tag($0) }
                }
                VStack(alignment: .leading) {
                    Text("سرعت خواندن: ×\(String(format: "%.1f", settings.speechRate).persianDigits)")
                    Slider(value: $settings.speechRate, in: 0.5...1.5, step: 0.1) {
                        Text("سرعت خواندن")
                    }
                }
                Toggle("تلفظ خودکار در مرور", isOn: $settings.autoPronounce)
                Button("آزمایش صدا", systemImage: "speaker.wave.2.fill") {
                    pronouncer.speak("Practice makes perfect.", settings: settings)
                }
            }

            Section("مرور") {
                Picker("جهت کارت‌ها", selection: $settings.reviewDirection) {
                    ForEach(ReviewDirection.allCases) { Text($0.persianLabel).tag($0) }
                }
                Stepper(value: $settings.dailyGoal, in: 5...100, step: 5) {
                    Text("هدف روزانه: \(settings.dailyGoal.persianDigits) کارت")
                }
            }

            Section {
                Button("گرفتن نسخهٔ پشتیبان", systemImage: "square.and.arrow.up", action: export)
                Button("بازگردانی از فایل پشتیبان", systemImage: "square.and.arrow.down") { showImporter = true }
            } header: {
                Text("پشتیبان‌گیری")
            } footer: {
                Text("همهٔ لغت‌ها، کارت‌های لایتنر، دسته‌ها و سابقهٔ مرور در یک فایل JSON ذخیره می‌شود. فایل پشتیبانِ نسخهٔ اندروید هم قابل بازگردانی است.")
            }

            Section("دربارهٔ روان") {
                LabeledContent("نسخه", value: appVersion.persianDigits)
                LabeledContent("لغت‌ها", value: wordCount.persianDigits)
                NavigationLink("منابع داده") { DataSourcesView() }
            }
        }
        .ravanBackground()
        .navigationTitle("تنظیمات")
        .task(id: store.revision) { wordCount = store.wordCount() }
        .fileExporter(
            isPresented: $showExporter,
            document: exportFile,
            contentType: .json,
            defaultFilename: "ravan-backup-\(Date.now.formatted(.iso8601.year().month().day()))"
        ) { result in
            if case .failure = result { message = "ذخیرهٔ فایل انجام نشد." }
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
            if case .success(let url) = result { pendingImport = url }
        }
        .confirmationDialog(
            "بازگردانی نسخهٔ پشتیبان؟",
            isPresented: Binding(get: { pendingImport != nil }, set: { if !$0 { pendingImport = nil } }),
            titleVisibility: .visible
        ) {
            Button("بازگردانی") { if let url = pendingImport { importBackup(from: url) } }
        } message: {
            Text("اطلاعات فایل با داده‌های فعلی ادغام می‌شود؛ مواردی که در هر دو هستند با نسخهٔ فایل جایگزین می‌شوند.")
        }
        .alert(message ?? "", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("باشه", role: .cancel) {}
        }
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    private func export() {
        do {
            exportFile = BackupFile(data: try store.exportBackup())
            showExporter = true
        } catch {
            message = "ساخت فایل پشتیبان انجام نشد."
        }
    }

    private func importBackup(from url: URL) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        do {
            let summary = try store.importBackup(try Data(contentsOf: url))
            message = "بازگردانی شد: \(summary.words.persianDigits) لغت، \(summary.cards.persianDigits) کارت، \(summary.decks.persianDigits) دسته"
        } catch {
            message = "فایل معتبر نیست یا خوانده نشد."
        }
        pendingImport = nil
    }
}

/// The JSON backup handed to the system file exporter.
nonisolated struct BackupFile: FileDocument {
    static let readableContentTypes: [UTType] = [.json]

    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

private struct DataSourcesView: View {
    private let sources: [(String, String)] = [
        ("Persian translations & bilingual examples", "Aryanpour English–Persian Dictionary (CRAN “persiandictionary”, GPL-2)"),
        ("US / UK pronunciation (IPA)", "open-dict-data/ipa-dict (MIT)"),
        ("Synonyms, antonyms, parts of speech", "Princeton WordNet 3.0 (WordNet License)"),
        ("CEFR levels", "CEFR-J Vocabulary Profile 1.5 (Tono Laboratory, TUFS) · Octanove C1/C2 Profile (CC BY-SA 4.0)"),
        ("Word frequency", "hermitdave/FrequencyWords — OpenSubtitles 2018 (CC BY-SA 4.0)"),
    ]

    var body: some View {
        List(sources, id: \.0) { source in
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: source.0).font(.headline)
                Text(verbatim: source.1).font(.subheadline).foregroundStyle(.secondary)
            }
            .environment(\.layoutDirection, .leftToRight)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("منابع داده")
    }
}
