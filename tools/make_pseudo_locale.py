#!/usr/bin/env python3
"""Regenerate the pseudo-locale column ("xa") in localization/game.csv.

The pseudo-locale is a localization STRESS TEST, not a language:
- every character is accented, so any plain-English text on a
  pseudo-locale screenshot is a HARDCODED string the l10n scanner missed;
- every string is padded ~35% longer and bracketed, so layouts that only
  fit English break visibly (German and Russian run 30-40% longer);
- printf placeholders (%s, %d, %.2f, %%) pass through untouched, so a
  malformed-format crash cannot hide in the disguise.

Run after adding UI strings:  python3 tools/make_pseudo_locale.py
then re-import so game.xa.translation is rebuilt. A language dropdown must
filter "xa" out — players never see it; scenarios/pseudo_locale.txt
switches to it with the console's `locale xa`.

OWNED BY KOMBUCHA (tools/tooling-manifest.txt).
"""
import csv
import re
import sys

ACCENT = str.maketrans(
    "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ",
    "àƀçđèƒĝĥìĵķłɱñòƥɋřşŧùṽẁxýžÀƁÇÐÈƑĜĤÌĴĶŁϺÑÒƤɊŘŞŦÙṼẀXÝŽ")
PLACEHOLDER = re.compile(r"%[%]|%[-+ #0]*\d*(?:\.\d+)?[sdif]")


def pseudo(text: str) -> str:
    parts = []
    last = 0
    for m in PLACEHOLDER.finditer(text):
        parts.append(text[last:m.start()].translate(ACCENT))
        parts.append(m.group(0))
        last = m.end()
    parts.append(text[last:].translate(ACCENT))
    body = "".join(parts)
    pad = "~" * max(1, int(len(text) * 0.35))
    return "[%s%s]" % (body, pad)


def main() -> int:
    path = "localization/game.csv"
    with open(path, newline="", encoding="utf-8") as f:
        rows = list(csv.reader(f))
    header = rows[0]
    if "xa" in header:
        xa = header.index("xa")
    else:
        header.append("xa")
        xa = len(header) - 1
    for row in rows[1:]:
        if not row:
            continue
        while len(row) <= xa:
            row.append("")
        row[xa] = pseudo(row[1])
    with open(path, "w", newline="", encoding="utf-8") as f:
        csv.writer(f, lineterminator="\n").writerows(rows)
    print("pseudo-locale: %d strings" % (len(rows) - 1))
    return 0


if __name__ == "__main__":
    sys.exit(main())
