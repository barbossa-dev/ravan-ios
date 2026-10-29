# Dictionary builder

`dictionary.json` (bundled with both the Android and the iOS app) is generated from open
data sets. Nothing in it is hand-written sample data.

| Data | Source | License |
| --- | --- | --- |
| Persian translations, senses, bilingual example sentences, idioms | Aryanpour English–Persian Dictionary, as packaged in the CRAN package [`persiandictionary`](https://github.com/cran/persiandictionary) (63,778 entries) | GPL-2 |
| US and UK pronunciation (IPA) | [open-dict-data/ipa-dict](https://github.com/open-dict-data/ipa-dict) | MIT |
| Synonyms, antonyms, part of speech, extra English examples | Princeton WordNet 3.0 (via [nltk_data](https://github.com/nltk/nltk_data)) | WordNet License |
| CEFR level (A1–C2) | [CEFR-J Vocabulary Profile 1.5 and Octanove C1/C2 Profile](https://github.com/openlanguageprofiles/olp-en-cefrj) | Free with citation / CC BY-SA 4.0 |
| Frequency rank | [hermitdave/FrequencyWords](https://github.com/hermitdave/FrequencyWords) (OpenSubtitles 2018) | CC BY-SA 4.0 |

> **License note.** The Persian translations come from a GPL-2 data set. If you distribute the
> app with this file, comply with GPL-2 (or replace the translation source before release).
> Attribution for every source is stored in the `attribution` field of `dictionary.json` and
> shown on the app's About screen.

## Rebuild

```bash
./fetch_sources.sh                                   # clones the sources into ./sources
python3 build_dictionary.py --sources sources --out dictionary.json --max-words 22000
cp dictionary.json <ravan-android>/core/data/src/main/assets/dictionary.json            # Android
cp dictionary.json ../../Packages/RavanKit/Sources/RavanData/Resources/                 # iOS
```

Then bump the seed version (`DictionarySeeder.SEED_VERSION` on Android, `DictionarySeeder.seedVersion`
on iOS) to the new `version` so existing installs import the new entries.

## What the builder does

1. Reads the R data files of `persiandictionary` (`rda.py` is a tiny reader for R's XDR format).
2. Splits every raw entry into senses and example sentences. The source glues senses, English
   examples and their Persian translations together without separators; the parser uses script
   changes (Latin ↔ Persian), sentence punctuation, parenthesised notes and a token-frequency
   model to find the boundaries, and normalises Arabic letters (ي/ك → ی/ک).
3. Picks headwords: every CEFR word plus the most frequent words of the OpenSubtitles list that
   have an IPA transcription, and common multi-word entries (phrasal verbs, compounds).
4. Adds IPA (stress marks are moved to the syllable onset, `ɹ` → `r`), the part of speech
   (CEFR-J first, then a Persian-infinitive check, then WordNet), up to 8 synonyms and 5
   antonyms from the WordNet senses of that part of speech, and fills examples up to 4 with
   WordNet sentences.

## Output format

```json
{
  "version": 2,
  "attribution": ["…"],
  "words": [
    {
      "text": "resilient",
      "phoneticUs": "/rɪˈzɪljənt/",
      "phoneticUk": "/rɪˈzɪliənt/",
      "partOfSpeech": "adjective",
      "level": "C1",
      "rank": 20955,
      "meanings": [{ "translation": "کشسان، ارتجاعی", "description": "optional note" }],
      "examples": [{ "english": "Rubber is resilient.", "persian": "لاستیک کشسان است." }],
      "synonyms": ["bouncy", "springy"],
      "antonyms": []
    }
  ]
}
```

Optional fields are omitted when empty. `rank` is the OpenSubtitles frequency rank (1 = most common).
