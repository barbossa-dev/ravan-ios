# Ravan — iOS

Ravan ("fluent" in Persian) is an offline English → Persian dictionary and vocabulary trainer
for Persian speakers, written in SwiftUI for iOS 26 with the Liquid Glass design.

## Features

- **Offline dictionary of ~21,400 words** generated from open data sets (see
  [`tools/dictionary`](tools/dictionary/README.md)): Persian senses, bilingual example sentences,
  US and UK IPA, CEFR level, synonyms and antonyms.
- **American and British pronunciation** with the on-device speech synthesizer (the best
  installed voice — Premium, Enhanced or Default — is picked automatically).
- **Search tab in the Liquid Glass tab bar**: English or Persian queries, normalised for
  Arabic/Persian letter variants and ZWNJ, ranked by exact match, prefix and word frequency.
- **Add and edit words** with senses, examples, synonyms, antonyms and a personal note.
- **Decks** to group words and review them separately.
- **Leitner flash cards** with a 3D flip, haptics, English → Persian / Persian → English / mixed
  directions, free practice, streaks, a daily goal and Swift Charts statistics.
- **Backup & restore** through the Files app. The JSON format is shared with the Android app.
- **Light and dark themes** (or follow the system), full right-to-left layout, Dynamic Type and
  VoiceOver labels.

## Requirements

- Xcode 26 or newer (the project was created with Xcode 27)
- iOS / iPadOS 26.0 or newer — Liquid Glass APIs (`glassEffect`, `GlassEffectContainer`,
  `.glass` button styles, search tab role, tab bar minimise behaviour) need iOS 26

## Run

1. Open `Ravan.xcodeproj`.
2. Select the **Ravan** target → *Signing & Capabilities* and choose your team.
3. Run on a simulator or device. The first launch imports the bundled dictionary in the
   background (a few seconds); the Home screen shows progress.

Unit tests for the domain layer live in the package:

```bash
cd Packages/RavanKit && swift test     # or open Package.swift in Xcode and run the RavanKit scheme
```

## Architecture

The app target only contains `RavanApp.swift` and the asset catalog. Everything else is a
modular Swift package, `Packages/RavanKit`, layered so that dependencies only point downwards:

```
AppFeature        composition root: Liquid Glass TabView, navigation stacks, sheets, dependency wiring
FeatureHome       home (word of the day, review call-out, recent words) and the search tab
FeatureWord       word details: US/UK pronunciation, senses, examples, synonyms, antonyms, Leitner, decks
FeatureEditor     add / edit a word
FeatureLibrary    personal library filters, decks, deck details, word picker
FeatureReview     review dashboard (Swift Charts) and the flash-card session
FeatureSettings   theme, accent, speech rate, review options, backup / restore, data sources
RavanUI           AppRouter, SettingsStore, shared rows; re-exports the layers below
RavanDesign       colours, Liquid Glass components, typography, FlowLayout, background
RavanData         SwiftData models, DictionaryStore (repository), DictionarySeeder (@ModelActor)
RavanSpeech       Pronouncer (AVSpeechSynthesizer)
RavanModel        pure Swift domain: Word, ReviewCard, Leitner scheduler, backup format, text utils
```

- **Swift 6 language mode** everywhere. UI targets use Swift 6.2 *default main-actor
  isolation*; domain and data targets are non-isolated and explicitly annotated.
- **State:** `@Observable` stores injected with `.environment(_:)`. `DictionaryStore` returns
  value types only and bumps a `revision` counter after every write; screens reload with
  `.task(id: store.revision)`.
- **Navigation:** features push `AppRoute` values; destinations are registered once in
  `AppFeature`, so features never import each other. Sheets and the review session are driven
  by `AppRouter`.
- **Persistence:** SwiftData. The bundled `dictionary.json` is imported on a background
  `@ModelActor`; existing rows are never overwritten, so user edits survive dictionary updates.

## Backup format

Settings → *Create backup* exports a JSON file with words, Leitner cards, decks and review
history (`formatVersion: 1`, timestamps in epoch milliseconds). Restoring merges the file into
the existing data. Backups made by the Android app can be restored on iOS and vice versa.

## Data licenses

The bundled dictionary combines several open data sets; see
[`tools/dictionary/README.md`](tools/dictionary/README.md). The Persian translations are
GPL-2 licensed — review the implications before publishing the app.
