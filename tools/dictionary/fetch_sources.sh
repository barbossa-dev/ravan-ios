#!/usr/bin/env bash
# Downloads every source used by build_dictionary.py into ./sources (≈250 MB, mostly WordNet git history is skipped).
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p sources && cd sources

clone() { [ -d "$(basename "$1")" ] || git clone --depth 1 "https://github.com/$1.git" "${@:2}"; }

clone cran/persiandictionary                     # Aryanpour English-Persian dictionary (GPL-2)
clone open-dict-data/ipa-dict                    # US / UK IPA (MIT)
clone openlanguageprofiles/olp-en-cefrj          # CEFR-J + Octanove vocabulary profiles

if [ ! -d FrequencyWords ]; then                 # OpenSubtitles frequency list (CC BY-SA 4.0)
  git clone --depth 1 --filter=blob:none --sparse https://github.com/hermitdave/FrequencyWords.git
  git -C FrequencyWords sparse-checkout set content/2018/en
fi

if [ ! -d wn/wordnet ]; then                     # Princeton WordNet 3.0 (WordNet License)
  git clone --depth 1 --filter=blob:none --sparse https://github.com/nltk/nltk_data.git
  git -C nltk_data sparse-checkout set --no-cone /packages/corpora/wordnet.zip
  mkdir -p wn && unzip -q -o nltk_data/packages/corpora/wordnet.zip -d wn
fi
echo "Sources ready in $(pwd)"
