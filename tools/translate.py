#!/usr/bin/env python3
"""Translate the upopencode script between the RU and EN message tables.

  python3 tools/translate.py to-en <src> <dst>   # one-off: RU source -> EN
  python3 tools/translate.py to-ru                # upopencode (EN) -> upopencode-ru

`upopencode` is the English source of truth; `upopencode-ru` is generated.
"""
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
sys.path.insert(0, str(HERE))
from i18n_table import PAIRS  # noqa: E402

RU2EN = dict(PAIRS)
EN2RU = {}
for ru, en in PAIRS:
    if en in EN2RU and EN2RU[en] != ru:
        raise SystemExit(f"ambiguous EN key: {en!r} -> {EN2RU[en]!r} / {ru!r}")
    EN2RU[en] = ru


def apply(text: str, mapping: dict) -> str:
    keys = sorted(mapping, key=len, reverse=True)
    pattern = re.compile("|".join(re.escape(k) for k in keys))
    return pattern.sub(lambda m: mapping[m.group(0)], text)


def main() -> int:
    mode = sys.argv[1] if len(sys.argv) > 1 else "to-ru"
    if mode == "to-en":
        src, dst = Path(sys.argv[2]), Path(sys.argv[3])
        dst.write_text(apply(src.read_text(), RU2EN), encoding="utf-8")
        return 0
    if mode == "to-ru":  # pragma: no cover - trivial
        src = ROOT / "upopencode"
        dst = ROOT / "upopencode-ru"
        text = apply(src.read_text(), EN2RU)
        first, rest = text.split("\n", 1)
        header = "# ВНИМАНИЕ: файл сгенерирован из upopencode (tools/translate.py).\n"
        dst.write_text(first + "\n" + header + rest, encoding="utf-8")
        return 0
    print(__doc__)
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
