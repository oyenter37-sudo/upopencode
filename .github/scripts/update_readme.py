#!/usr/bin/env python3
"""Rewrite the upstream version markers in both READMEs."""
import pathlib
import re
import sys

version = sys.argv[1].lstrip("v")
if not re.fullmatch(r"\d+\.\d+\.\d+", version):
    sys.exit(f"bad version: {version!r}")

blocks = {
    "README.md": (
        "**Latest OpenCode: v{version}** · checked daily · "
        "[install or update with one command →](#quick-start)"
    ),
    "README.ru.md": (
        "**Последний OpenCode: v{version}** · проверяется каждый день · "
        "[поставить или обновить одной командой →](#быстрый-старт)"
    ),
}

pattern = re.compile(r"<!-- upstream:start -->.*?<!-- upstream:end -->", re.S)
changed = False

for name, template in blocks.items():
    path = pathlib.Path(name)
    src = path.read_text()
    if not pattern.search(src):
        sys.exit(f"{name}: upstream markers not found")

    block = (
        "<!-- upstream:start -->\n"
        + template.format(version=version)
        + "\n<!-- upstream:end -->"
    )
    new = pattern.sub(lambda _: block, src, count=1)

    if new == src:
        print(f"{name}: already v{version}")
        continue
    path.write_text(new)
    changed = True
    print(f"{name}: updated to v{version}")

if not changed:
    print("nothing to commit")
