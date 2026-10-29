#!/usr/bin/env python3
"""
Builds the offline English -> Persian dictionary bundled with the Ravan apps.

Sources (cloned from GitHub, see tools/dictionary/README.md):
  * Persian translations and bilingual examples: Aryanpour English-Persian dictionary,
    as packaged in the CRAN package `persiandictionary` (GPL-2).
  * US / UK pronunciations (IPA): open-dict-data/ipa-dict (MIT).
  * Synonyms, antonyms, parts of speech, extra English examples: Princeton WordNet 3.0
    (WordNet License).
  * CEFR levels: CEFR-J Vocabulary Profile 1.5 + Octanove C1/C2 profile (CC BY-SA 4.0).
  * Frequency ranking: hermitdave/FrequencyWords, OpenSubtitles 2018 (CC BY-SA 4.0).

Usage:
  python3 build_dictionary.py --sources /path/to/sources --out dictionary.json [--max-words 22000]
"""
from __future__ import annotations

import argparse
import csv
import json
import re
import sys
import time
from collections import defaultdict
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from rda import read_rda  # noqa: E402

# --------------------------------------------------------------------------- text helpers

ARABIC_TO_PERSIAN = str.maketrans({"ي": "ی", "ك": "ک", "ى": "ی", "ة": "ه"})
PERSIAN_LETTER = re.compile(r"[؀-ۿ]")
LATIN_LETTER = re.compile(r"[A-Za-z]")
TERMINAL = ".!?؟…"


def is_persian(ch: str) -> bool:
    return bool(PERSIAN_LETTER.match(ch))


def is_latin(ch: str) -> bool:
    return bool(LATIN_LETTER.match(ch))


def clean_fa(text: str) -> str:
    text = text.translate(ARABIC_TO_PERSIAN)
    text = text.replace("‌ ", " ").replace(" ‌", " ")
    text = re.sub(r"\s+", " ", text)
    text = re.sub(r"\s*،\s*", "، ", text)
    text = re.sub(r"\(\s+", "(", text)
    text = re.sub(r"\s+\)", ")", text)
    text = text.replace("‌!", "!").replace("‌.", ".")
    return text.strip(" ،-")


def clean_en(text: str) -> str:
    text = re.sub(r"\s+", " ", text).strip()
    return text.strip(" -")


# --------------------------------------------------------------------------- Aryanpour parser

def split_runs(raw: str) -> list[tuple[str, str]]:
    """Splits an entry into alternating ('fa', text) / ('en', text) runs.

    Latin text inside parentheses is kept in the surrounding Persian run, so
    notes such as "(Lycopersicon esculentum ...)" stay attached to their sense.
    """
    runs: list[tuple[str, str]] = []
    buf: list[str] = []
    kind = "fa"
    depth = 0
    i = 0
    while i < len(raw):
        ch = raw[i]
        if kind == "fa":
            if ch == "(":
                depth += 1
            elif ch == ")":
                depth = max(0, depth - 1)
            starts_latin = depth == 0 and (
                is_latin(ch) or (ch == "*" and i + 2 < len(raw) and is_latin(raw[i + 2] if raw[i + 1] == " " else raw[i + 1]))
            )
            if starts_latin:
                runs.append(("fa", "".join(buf)))
                buf = [ch]
                kind = "en"
            else:
                buf.append(ch)
        else:
            if is_persian(ch):
                text = "".join(buf)
                # Opening brackets / numbering just before the Persian text belong to it.
                tail = re.search(r"[\s(\[\d\-]*$", text)
                carry = tail.group(0) if tail else ""
                if carry and carry.strip() and "(" not in carry and not carry.strip().rstrip("-").isdigit():
                    carry = ""
                runs.append(("en", text[: len(text) - len(carry)]))
                buf = list(carry) + [ch]
                depth = carry.count("(")
                kind = "fa"
            else:
                buf.append(ch)
        i += 1
    runs.append((kind, "".join(buf)))
    return [(k, t) for k, t in runs if t.strip()]


def split_translation(text: str) -> tuple[str, str]:
    """For the Persian run after an English example, returns (translation, rest).

    The source joins an example's translation and the next sense without a separator;
    a sentence-final punctuation mark is the only reliable boundary.
    """
    depth = 0
    for idx, ch in enumerate(text):
        if ch == "(":
            depth += 1
        elif ch == ")":
            depth = max(0, depth - 1)
        if ch in TERMINAL and depth == 0:
            # Keep "..." / ")" glued to the translation.
            end = idx + 1
            while end < len(text) and text[end] in TERMINAL + ")»‌ ":
                end += 1
            return text[:end], text[end:]
    return text, ""


SENSE_NOTE = re.compile(r"^\(([^()]{1,60})\)\s*")


GLUED_NOTE_BEFORE = re.compile(r"(?<=[\u0600-\u06FF])\((?=[^)]*\))")
GLUED_NOTE_AFTER = re.compile(r"\)(?=[\u0600-\u06FF(])")


def split_senses(text: str) -> list[str]:
    """The source glues senses together; "word(note)" and "(note)word" mark a new sense."""
    text = GLUED_NOTE_BEFORE.sub("§(", text)
    text = GLUED_NOTE_AFTER.sub(")§", text)
    text = mark_glued_tokens(text)
    parts: list[str] = []
    for chunk in text.split("§"):
        # "(note)§" must stay with the sense it introduces.
        if parts and re.fullmatch(r"\s*\([^()]*\)\s*", parts[-1]):
            parts[-1] += chunk
        else:
            parts.append(chunk)
    return parts


def parse_senses(text: str) -> list[dict]:
    return [s for s in (parse_sense(part) for part in split_senses(text)) if s]


def parse_sense(text: str) -> dict | None:
    text = clean_fa(text)
    text = re.sub(r"رجوع شود به:?.*$", "", text).strip(" ،")
    if not text or not PERSIAN_LETTER.search(text):
        return None
    note = ""
    m = SENSE_NOTE.match(text)
    if m:
        note = m.group(1).strip()
        text = text[m.end():].strip()
    if text[-1:] in ".!؟?":
        return None  # a stray example sentence, not a sense
    parts = [p.strip(" -") for p in text.split("،")]
    parts = [p for p in parts if p and PERSIAN_LETTER.search(p)]
    if not parts:
        return None
    seen, unique = set(), []
    for p in parts:
        if p not in seen:
            seen.add(p)
            unique.append(p)
    translation = "، ".join(unique[:6])
    if len(translation) > 140:
        translation = translation[:140].rsplit("، ", 1)[0]
    return {"translation": translation, "description": note}


TOKEN_FREQ: dict[str, int] = {}
PERSIAN_TOKEN = re.compile(r"[\u0621-\u063A\u0641-\u064A\u067E\u0686\u0698\u06A9\u06AF\u06CC\u200c]+")


def build_token_frequencies(texts) -> None:
    for text in texts:
        for token in re.findall(PERSIAN_TOKEN.pattern, text.translate(ARABIC_TO_PERSIAN)):
            TOKEN_FREQ[token] = TOKEN_FREQ.get(token, 0) + 1


GLUE_PREFIXES = {"می", "نمی", "هم", "پر", "بی", "نا", "با", "پاد", "سر", "پا", "دو", "از", "در", "بر", "فرا",
                 "پیش", "پس", "باز", "وا", "فرو", "ور", "دست", "خود", "نیم", "چند", "سه", "تک", "کم", "خوش", "بد", "نو", "ابر", "زیر", "روی", "هر"}
GLUE_SUFFIXES = {"دار", "گر", "گرانه", "گری", "گاه", "ساز", "کار", "انه", "مند", "وار", "ناک", "گین", "ستان", "زار",
                 "کده", "یت", "ی", "ها", "های", "ای", "ات", "ین", "ان", "گیر", "گیری", "پذیر", "آور", "آمیز", "شناس",
                 "شناسی", "نما", "باز", "بازی", "نشین", "خوار", "کش", "کشی", "زده", "دان", "سرا", "پرور", "چه", "ک",
                 "سان", "بندی", "سنج", "سنجی", "انداز", "اندازی", "گون", "گونه", "فام", "وش", "دیس", "آسا", "آوا", "مرد", "نامه"}


def glued_cut(token: str) -> int | None:
    """Index where a rare token is really two words glued together, or None.

    Conservative: one side must be very common, compound prefixes/suffixes are never split,
    and a left part ending in an infinitive (…دن / …تن) is the strongest signal.
    """
    if TOKEN_FREQ.get(token, 0) > 2 or len(token) < 6:
        return None
    best = None
    for cut in range(3, len(token) - 2):
        left, right = token[:cut], token[cut:]
        if "\u200c" in (left[-1], right[0]) or left in GLUE_PREFIXES or right in GLUE_SUFFIXES:
            continue
        lf, rf = TOKEN_FREQ.get(left, 0), TOKEN_FREQ.get(right, 0)
        infinitive = left.endswith(("دن", "تن")) and lf >= 5 and rf >= 5
        common = min(lf, rf) >= 60
        if infinitive or common:
            score = min(lf, rf) + (10**6 if infinitive else 0)
            if best is None or score > best[0]:
                best = (score, cut)
    return best[1] if best else None


def mark_glued_tokens(text: str) -> str:
    """Inserts a sense break (§) inside tokens such as "کردنخواسته" (= "کردن" + "خواسته")."""
    def repl(match: re.Match) -> str:
        token = match.group(0)
        cut = glued_cut(token)
        return token if cut is None else token[:cut] + "§" + token[cut:]
    return re.sub(PERSIAN_TOKEN.pattern, repl, text.translate(ARABIC_TO_PERSIAN))


def split_glued(text: str) -> tuple[str, str]:
    """Finds where an example translation runs into the next sense ("مسابقه دوبه سرعت ...").

    Returns (translation, rest) or (text, "") when no boundary is found.
    """
    text = text.translate(ARABIC_TO_PERSIAN)
    first_comma = text.find("،")
    limit = first_comma if first_comma != -1 else len(text)
    for match in PERSIAN_TOKEN.finditer(text[:limit]):
        cut = glued_cut(match.group(0))
        if cut is None:
            # Short glues like "دو|به" need a looser rule: both halves very common.
            token = match.group(0)
            for c in range(2, len(token) - 1):
                if TOKEN_FREQ.get(token, 0) <= 2 and min(TOKEN_FREQ.get(token[:c], 0), TOKEN_FREQ.get(token[c:], 0)) >= 300:
                    cut = c
                    break
        if cut is not None:
            pos = match.start() + cut
            if len(text[pos:].split()) >= 2:
                return text[:pos], text[pos:]
    return text, ""


def parse_idiom_translation(text: str) -> str:
    text = clean_fa(text)
    items = [s.strip(" -،") for s in re.split(r"\d+\s*-\s*", text) if s.strip(" -،")]
    return "؛ ".join(items)


def parse_entry(raw: str) -> tuple[list[dict], list[dict]]:
    meanings: list[dict] = []
    examples: list[dict] = []
    runs = split_runs(raw)
    pending_en: str | None = None
    for kind, text in runs:
        if kind == "en":
            pending_en = text
            continue
        if pending_en is None:
            meanings.extend(parse_senses(text))
            continue
        english = clean_en(pending_en)
        pending_en = None
        is_idiom = english.startswith("*")
        english = english.lstrip("* ").strip()
        if is_idiom:
            translation, rest = text, ""
            persian = parse_idiom_translation(translation)
        else:
            translation, rest = split_translation(text)
            persian = clean_fa(translation)
            has_terminal = any(c in TERMINAL for c in translation)
            if not has_terminal:
                head, tail = split_glued(translation)
                if tail:
                    persian, rest = clean_fa(head), tail
                elif "(" in persian or len(persian.split()) > 5:
                    persian = ""
        good_english = (
            1 <= len(english.split()) <= 30
            and LATIN_LETTER.search(english)
            and not PERSIAN_LETTER.search(english)
            and "رجوع" not in persian
        )
        if good_english and persian:
            examples.append({"english": english, "persian": persian})
        if rest.strip():
            meanings.extend(parse_senses(rest))
    return meanings, examples


# --------------------------------------------------------------------------- other sources

IPA_VOWELS = set("aeiouæɑɒɔəɚɛɜɝɪʊʌɐyøœɨʉ")
ONSETS = {
    "pl", "pr", "bl", "br", "tr", "dr", "kl", "kr", "gl", "gr", "fl", "fr", "θr", "ʃr", "sl", "sm",
    "sn", "sp", "st", "sk", "sw", "tw", "dw", "kw", "gw", "spl", "spr", "str", "skr", "skw", "tʃ",
    "dʒ", "pj", "bj", "tj", "dj", "kj", "gj", "mj", "nj", "fj", "vj", "hj", "lj", "sj", "θj", "stj", "spj", "skj",
}


def move_stress_to_onset(ipa: str) -> str:
    """eSpeak-style "/bˈʊk/" → dictionary-style "/ˈbʊk/": a stress mark precedes the syllable onset."""
    chars = list(ipa)
    i = 0
    while i < len(chars):
        if chars[i] in "ˈˌ":
            mark = chars.pop(i)
            cluster_start = i
            while cluster_start > 0 and chars[cluster_start - 1] not in IPA_VOWELS | set("/ˈˌː "):
                cluster_start -= 1
            word_initial = cluster_start == 0 or chars[cluster_start - 1] in "/ "
            if word_initial:
                start = cluster_start
            else:
                # Longest legal English onset; the remaining consonants close the previous syllable.
                start = next(
                    k for k in range(cluster_start, i + 1)
                    if k == i or i - k == 1 or "".join(chars[k:i]) in ONSETS
                )
            chars.insert(start, mark)
        i += 1
    return "".join(chars)


def load_ipa(path: Path, us: bool) -> dict[str, str]:
    out: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        if "\t" not in line:
            continue
        word, ipa = line.split("\t", 1)
        first = ipa.split(",")[0].strip()
        first = first.replace("ɹ", "r").replace("ɫ", "l")
        if us:
            # CMUdict writes stressed /ʌ/ as /ə/.
            first = re.sub(r"([ˈˌ][^aeiouæɑɒɔəɚɛɜɝɪʊʌ/]*)ə", r"\1ʌ", first)
        else:
            first = move_stress_to_onset(first.replace("ɐ", "ə"))
        out.setdefault(word.lower(), first)
    return out


def load_frequency(path: Path) -> dict[str, int]:
    ranks: dict[str, int] = {}
    for i, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        word = line.split(" ")[0].lower()
        ranks.setdefault(word, i)
    return ranks


def load_cefr(paths: list[Path]) -> dict[str, tuple[str, list[str]]]:
    """headword -> (lowest CEFR level, parts of speech in level order)."""
    order = ["A1", "A2", "B1", "B2", "C1", "C2"]
    rows: dict[str, list[tuple[int, str]]] = defaultdict(list)
    for path in paths:
        with path.open(encoding="utf-8") as f:
            for row in csv.DictReader(f):
                level = row["CEFR"].strip().upper()
                if level not in order:
                    continue
                for headword in row["headword"].split("/"):
                    key = headword.strip().lower()
                    if key:
                        rows[key].append((order.index(level), row["pos"].strip().lower()))
    result = {}
    for key, items in rows.items():
        items.sort()
        pos = []
        for _, p in items:
            if p not in pos:
                pos.append(p)
        result[key] = (order[items[0][0]], pos)
    return result


WN_POS = {"n": "noun", "v": "verb", "a": "adjective", "s": "adjective", "r": "adverb"}


class WordNet:
    def __init__(self, root: Path):
        self.synsets: dict[tuple[str, int], dict] = {}
        self.index: dict[str, list[tuple[str, int]]] = defaultdict(list)
        for pos, name in [("n", "noun"), ("v", "verb"), ("a", "adj"), ("r", "adv")]:
            self._load_data(root / f"data.{name}", pos)
            self._load_index(root / f"index.{name}", pos)

    def _load_data(self, path: Path, pos: str) -> None:
        for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
            if line.startswith("  "):
                continue
            body, _, gloss = line.partition(" | ")
            parts = body.split()
            offset = int(parts[0])
            ss_type = parts[2]
            w_cnt = int(parts[3], 16)
            words = [parts[4 + 2 * i].replace("_", " ") for i in range(w_cnt)]
            words = [re.sub(r"\(.*\)$", "", w) for w in words]
            p = 4 + 2 * w_cnt
            p_cnt = int(parts[p])
            pointers = []
            for j in range(p_cnt):
                sym, off, ppos, st = parts[p + 1 + 4 * j: p + 5 + 4 * j]
                pointers.append((sym, int(off), ppos, int(st[:2], 16), int(st[2:], 16)))
            examples = re.findall(r'"([^"]+)"', gloss)
            definition = gloss.split(';')[0].strip()
            self.synsets[(pos, offset)] = {
                "type": ss_type,
                "words": words,
                "pointers": pointers,
                "examples": examples,
                "definition": definition,
            }

    def _load_index(self, path: Path, pos: str) -> None:
        for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
            if line.startswith("  "):
                continue
            parts = line.split()
            lemma = parts[0].replace("_", " ")
            synset_cnt = int(parts[2])
            offsets = parts[-synset_cnt:]
            for off in offsets:
                self.index[lemma].append((pos, int(off)))

    def lookup(self, lemma: str) -> list[tuple[tuple[str, int], dict]]:
        return [(key, self.synsets[key]) for key in self.index.get(lemma, []) if key in self.synsets]

    def dominant_pos(self, lemma: str) -> str | None:
        score: dict[str, int] = defaultdict(int)
        for rank, (_, synset) in enumerate(self.lookup(lemma)):
            score[WN_POS[synset["type"]]] += max(1, 6 - rank)
        return max(score, key=score.get) if score else None

    def details(self, lemma: str, pos: str | None, max_senses: int = 3) -> dict:
        senses = [s for s in self.lookup(lemma) if pos is None or WN_POS[s[1]["type"]] == pos] or self.lookup(lemma)
        synonyms: list[str] = []
        antonyms: list[str] = []
        examples: list[str] = []
        pos_count: dict[str, int] = defaultdict(int)
        for rank, (key, synset) in enumerate(senses):
            pos_count[WN_POS[synset["type"]]] += max(1, 6 - rank)
            if rank >= max_senses:
                continue
            for w in synset["words"]:
                usable = w.lower() != lemma and w == w.lower() and len(w.split()) <= 2
                if usable and w not in synonyms:
                    synonyms.append(w)
            # Lexical antonyms of the lemma itself (source word index matches the lemma).
            lemma_index = next(
                (i + 1 for i, w in enumerate(synset["words"]) if w.lower() == lemma), None
            )
            for sym, off, ppos, src, dst in synset["pointers"]:
                if sym == "!" and (src == lemma_index or src == 0):
                    target = self.synsets.get((ppos if ppos != "s" else "a", off))
                    if target:
                        name = target["words"][dst - 1] if dst else target["words"][0]
                        if name not in antonyms:
                            antonyms.append(name)
            for ex in synset["examples"]:
                if re.search(rf"\b{re.escape(lemma)}", ex, re.IGNORECASE) and ex not in examples:
                    examples.append(ex)
        return {"synonyms": synonyms, "antonyms": antonyms, "examples": examples}


CEFR_POS = {
    "noun": "noun", "verb": "verb", "adjective": "adjective", "adverb": "adverb",
    "pronoun": "pronoun", "preposition": "preposition", "conjunction": "conjunction",
    "determiner": "determiner", "interjection": "interjection", "number": "determiner",
}


def is_persian_infinitive(translation: str) -> bool:
    first = translation.split("،")[0].strip()
    return first.endswith(("دن", "تن")) and len(first) > 3


def choose_pos(word: str, meanings: list[dict], cefr_pos: list[str], wordnet: WordNet) -> str:
    infinitive = bool(meanings) and is_persian_infinitive(meanings[0]["translation"])
    if cefr_pos:
        if infinitive and "verb" in cefr_pos:
            return "verb"
        dominant = wordnet.dominant_pos(word)
        if len(cefr_pos) > 1 and dominant in cefr_pos and not infinitive:
            return dominant
        return cefr_pos[0]
    if infinitive:
        return "verb"
    if " " in word:
        return "verb" if wordnet.dominant_pos(word) == "verb" else "phrase"
    return wordnet.dominant_pos(word) or "other"


def polish_example(example: dict) -> dict:
    """Bilingual sentence examples get sentence case and a full stop, like the Persian side."""
    english, persian = example["english"], example["persian"]
    if persian and persian[-1] in TERMINAL and english[:1].islower():
        english = english[0].upper() + english[1:]
    if persian and persian[-1] in TERMINAL and english[-1] not in TERMINAL:
        english += persian[-1] if persian[-1] in ".!?" else ("?" if persian[-1] == "؟" else ".")
    return {"english": english, "persian": persian}


# --------------------------------------------------------------------------- main

def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--sources", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--max-words", type=int, default=22000)
    args = parser.parse_args()
    src = args.sources

    started = time.time()
    en = read_rda(src / "persiandictionary/data/en.rda")["en"]
    fa = read_rda(src / "persiandictionary/data/fa.rda")["fa"]
    build_token_frequencies(fa)
    raw_by_word: dict[str, list[str]] = defaultdict(list)
    for e, f in zip(en, fa):
        if e and f:
            raw_by_word[e.strip().lower()].append(f)

    ipa_us = load_ipa(src / "ipa-dict/data/en_US.txt", us=True)
    ipa_uk = load_ipa(src / "ipa-dict/data/en_UK.txt", us=False)
    ranks = load_frequency(src / "FrequencyWords/content/2018/en/en_50k.txt")
    cefr = load_cefr([
        src / "olp-en-cefrj/cefrj-vocabulary-profile-1.5.csv",
        src / "olp-en-cefrj/octanove-vocabulary-profile-c1c2-1.0.csv",
    ])
    wordnet = WordNet(src / "wn/wordnet")

    headword = re.compile(r"^[a-z][a-z'\-]*( [a-z][a-z'\-]*){0,2}$")
    candidates = []
    for word, raws in raw_by_word.items():
        if not headword.match(word):
            continue
        single = " " not in word
        rank = ranks.get(word, 0)
        in_cefr = word in cefr
        has_ipa = word in ipa_us or word in ipa_uk
        if single and not (rank or in_cefr):
            continue
        if not single and not wordnet.index.get(word):
            continue  # keep only well-known multi-word entries (phrasal verbs, compounds)
        if single and not has_ipa:
            continue
        candidates.append((word, raws, rank))

    # CEFR words first, then by corpus frequency, then multi-word expressions.
    def priority(item):
        word, _, rank = item
        if " " in word:
            parts = word.split()
            rank = max(ranks.get(p, 10**6) for p in parts) * 4
        level = cefr.get(word, ("Z", []))[0]
        return (0 if word in cefr else 1, rank if rank else 10**6, level, word)

    candidates.sort(key=priority)
    candidates = candidates[: args.max_words]

    entries = []
    for word, raws, rank in candidates:
        meanings: list[dict] = []
        examples: list[dict] = []
        for raw in raws:
            m, e = parse_entry(raw)
            meanings.extend(m)
            examples.extend(e)
        # Merge duplicate senses, keep the most useful amount.
        seen, merged = set(), []
        for m in meanings:
            if m["translation"] not in seen:
                seen.add(m["translation"])
                merged.append(m)
        meanings = merged[:6]
        if not meanings:
            continue

        level, cefr_pos = cefr.get(word, ("", []))
        pos = choose_pos(word, meanings, [CEFR_POS[p] for p in cefr_pos if p in CEFR_POS], wordnet)
        wn = wordnet.details(word, pos if pos in WN_POS.values() else None)
        examples = [polish_example(x) for x in examples]
        sentence_examples = [x for x in examples if x["english"][-1:] in TERMINAL]
        phrase_examples = [x for x in examples if x["english"][-1:] not in TERMINAL]
        chosen = (sentence_examples[:3] + phrase_examples)[:4]
        for ex in wn["examples"]:
            if len(chosen) >= 4:
                break
            sentence = ex[0].upper() + ex[1:]
            if sentence[-1] not in TERMINAL:
                sentence += "."
            chosen.append({"english": sentence, "persian": ""})

        entry = {
            "text": word,
            "phoneticUs": ipa_us.get(word, ""),
            "phoneticUk": ipa_uk.get(word, ""),
            "partOfSpeech": pos,
            "meanings": [
                {k: v for k, v in m.items() if v} for m in meanings
            ],
        }
        if level:
            entry["level"] = level
        if rank:
            entry["rank"] = rank
        if chosen:
            entry["examples"] = [{k: v for k, v in x.items() if v} for x in chosen]
        if wn["synonyms"]:
            entry["synonyms"] = wn["synonyms"][:8]
        if wn["antonyms"]:
            entry["antonyms"] = wn["antonyms"][:5]
        entries.append(entry)

    entries.sort(key=lambda e: e["text"])
    document = {
        "version": 2,
        "generatedAt": time.strftime("%Y-%m-%d"),
        "attribution": [
            "Persian translations & bilingual examples: Aryanpour English-Persian Dictionary (CRAN 'persiandictionary', GPL-2)",
            "Pronunciation (IPA): open-dict-data/ipa-dict (MIT)",
            "Synonyms, antonyms, parts of speech, English examples: Princeton WordNet 3.0 (WordNet License)",
            "CEFR levels: CEFR-J Vocabulary Profile 1.5 (Tono Laboratory, TUFS) and Octanove C1/C2 Profile (CC BY-SA 4.0)",
            "Frequency ranks: hermitdave/FrequencyWords, OpenSubtitles 2018 (CC BY-SA 4.0)",
        ],
        "words": entries,
    }
    args.out.write_text(json.dumps(document, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    print(f"{len(entries)} words -> {args.out} ({args.out.stat().st_size / 1e6:.1f} MB) in {time.time() - started:.0f}s")


if __name__ == "__main__":
    main()
