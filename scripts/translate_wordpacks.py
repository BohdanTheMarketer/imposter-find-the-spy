#!/usr/bin/env python3
"""Translate word pack words/hints from English to target locale."""

import json
import time
from pathlib import Path

try:
    from deep_translator import GoogleTranslator
except ImportError:
    raise SystemExit("pip install deep-translator")

ROOT = Path(__file__).resolve().parents[1]
EN_DIR = ROOT / "ImposterGame/Resources/WordPacks/en"
LOCALES = {
    "pt-BR": "pt",
    "fr": "fr",
    "es-MX": "es",
    "tr": "tr",
}

_cache: dict[tuple[str, str], str] = {}


def tr_batch(texts: list[str], lang: str) -> list[str]:
    translator = GoogleTranslator(source="en", target=lang)
    out: list[str] = []
    chunk_size = 40
    for i in range(0, len(texts), chunk_size):
        chunk = texts[i : i + chunk_size]
        try:
            translated = translator.translate_batch(chunk)
            out.extend(translated)
        except Exception:
            out.extend(chunk)
        time.sleep(0.2)
    return out


def translate_pack(en_path: Path, dest_path: Path, lang: str) -> None:
    data = json.loads(dest_path.read_text(encoding="utf-8"))
    en = json.loads(en_path.read_text(encoding="utf-8"))
    en_words = en["words"]
    en_hints = en.get("imposterHints") or []
    words = data["words"]
    hints = data.get("imposterHints") or []

    # Indices still in English (match en template)
    word_indices = [i for i, w in enumerate(words) if i < len(en_words) and w == en_words[i]]
    hint_indices = [
        i
        for i in range(len(words))
        if i < len(en_hints)
        and (hints[i] if i < len(hints) else "") == en_hints[i]
    ]

    if word_indices:
        batch_in = [en_words[i] for i in word_indices]
        batch_out = tr_batch(batch_in, lang)
        for idx, val in zip(word_indices, batch_out):
            words[idx] = val

    if hint_indices:
        batch_in = [en_hints[i] for i in hint_indices]
        batch_out = tr_batch(batch_in, lang)
        for idx, val in zip(hint_indices, batch_out):
            if idx < len(hints):
                hints[idx] = val
            else:
                hints.append(val)

    data["words"] = words
    data["imposterHints"] = hints[: len(words)]
    dest_path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def main() -> None:
    for locale, lang in LOCALES.items():
        dest_dir = ROOT / "ImposterGame/Resources/WordPacks" / locale
        for en_file in sorted(EN_DIR.glob("*.json")):
            dest = dest_dir / en_file.name
            if not dest.exists():
                continue
            print(f"{locale}/{en_file.name}")
            translate_pack(en_file, dest, lang)
    print("translate done")


if __name__ == "__main__":
    main()
