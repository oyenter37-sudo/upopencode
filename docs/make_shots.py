#!/usr/bin/env python3
"""Render real upopencode terminal output into SVG screenshots.

Runs the script in a pty, emulates the handful of ANSI sequences it uses
(CR, LF, CSI K/A/J, SGR), then draws the resulting character grid as an SVG
terminal window. No external dependencies.

    python3 docs/make_shots.py

Produces English and Russian variants (the Russian build is generated from the
same source, so the UI is captured from the real thing).
"""
from __future__ import annotations

import fcntl
import os
import pty
import re
import select
import struct
import termios
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "docs"
COLS, ROWS = 78, 26

# ---------------------------------------------------------------- ANSI → grid
BASE16 = [
    "#1c1c1c", "#ff5f5f", "#5fd75f", "#ffd75f", "#5f87ff", "#d75fd7", "#5fd7d7", "#c9d1d9",
    "#5f5f5f", "#ff8787", "#87ff87", "#ffff87", "#87afff", "#ff87ff", "#87ffff", "#ffffff",
]


def xterm256(n: int) -> str:
    if n < 16:
        return BASE16[n]
    if n < 232:
        n -= 16
        r, g, b = n // 36, (n % 36) // 6, n % 6
        conv = lambda v: 0 if v == 0 else 55 + v * 40  # noqa: E731
        return "#%02x%02x%02x" % (conv(r), conv(g), conv(b))
    v = 8 + (n - 232) * 10
    return "#%02x%02x%02x" % (v, v, v)


class Cell:
    __slots__ = ("ch", "fg", "bold", "dim")

    def __init__(self, ch=" ", fg=None, bold=False, dim=False):
        self.ch, self.fg, self.bold, self.dim = ch, fg, bold, dim

    def key(self):
        return (self.fg, self.bold, self.dim)


def blank(rows, cols):
    return [[Cell() for _ in range(cols)] for _ in range(rows)]


def feed(grid, raw: str):
    row = col = 0
    fg, bold, dim = None, False, False
    i = 0
    n = len(raw)
    while i < n:
        ch = raw[i]
        if ch == "\x1b":
            m = re.match(r"\x1b\[([0-9;?]*)([A-Za-z])", raw[i:])
            if not m:
                i += 1
                continue
            params, final = m.group(1), m.group(2)
            i += m.end()
            nums = [int(x) if x else 0 for x in params.replace("?", "").split(";")] if params.replace("?", "") else []
            if final == "m":
                if not nums:
                    nums = [0]
                j = 0
                while j < len(nums):
                    c = nums[j]
                    if c == 0:
                        fg, bold, dim = None, False, False
                    elif c == 1:
                        bold = True
                    elif c == 2:
                        dim = True
                    elif c == 22:
                        bold = dim = False
                    elif c == 39:
                        fg = None
                    elif c == 38 and j + 2 < len(nums) and nums[j + 1] == 5:
                        fg = xterm256(nums[j + 2]); j += 2
                    elif c == 38 and j + 4 < len(nums) and nums[j + 1] == 2:
                        fg = "#%02x%02x%02x" % (nums[j + 2], nums[j + 3], nums[j + 4]); j += 4
                    j += 1
                continue
            if final == "K":
                for x in range(col, COLS):
                    grid[row][x] = Cell()
                continue
            if final == "J":
                for y in range(row, ROWS):
                    grid[y] = [Cell() for _ in range(COLS)]
                continue
            if final == "A":
                row = max(0, row - (nums[0] if nums else 1))
                continue
            if final == "B":
                row = min(ROWS - 1, row + (nums[0] if nums else 1))
                continue
            if final == "C":
                col = min(COLS - 1, col + (nums[0] if nums else 1))
                continue
            if final == "D":
                col = max(0, col - (nums[0] if nums else 1))
                continue
            continue
        if ch == "\r":
            col = 0; i += 1; continue
        if ch == "\n":
            row += 1
            if row >= ROWS:
                grid.pop(0); grid.append([Cell() for _ in range(COLS)]); row = ROWS - 1
            i += 1
            continue
        if ch == "\x08":
            col = max(0, col - 1); i += 1; continue
        if ch == "\t":
            col = min(COLS - 1, (col // 4 + 1) * 4); i += 1; continue
        if ord(ch) < 32:
            i += 1; continue
        if col < COLS:
            grid[row][col] = Cell(ch, fg, bold, dim)
        col += 1
        if col >= COLS:
            col = 0; row += 1
            if row >= ROWS:
                grid.pop(0); grid.append([Cell() for _ in range(COLS)]); row = ROWS - 1
        i += 1
    return grid


# ---------------------------------------------------------------- SVG renderer
CW, LH, FS = 8.4, 20.0, 14.0
PADX, PADY, BAR = 26, 22, 38


def svg(grid, title: str) -> str:
    last = 0
    for y, line in enumerate(grid):
        if any(c.ch != " " for c in line):
            last = y
    used = grid[: last + 1]
    width = COLS * CW + PADX * 2
    height = (last + 1) * LH + PADY * 2 + BAR
    out = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width:.0f}" height="{height:.0f}" '
        f'viewBox="0 0 {width:.0f} {height:.0f}" font-family="\'JetBrains Mono\',\'SFMono-Regular\',Menlo,Consolas,\'DejaVu Sans Mono\',monospace">',
        '<defs><filter id="s" x="-10%" y="-10%" width="120%" height="130%">'
        '<feDropShadow dx="0" dy="6" stdDeviation="10" flood-color="#000" flood-opacity="0.45"/></filter></defs>',
        f'<rect x="0" y="0" width="{width:.0f}" height="{height:.0f}" rx="12" fill="#0b0f14" filter="url(#s)"/>',
        f'<rect x="0" y="0" width="{width:.0f}" height="{height:.0f}" rx="12" fill="none" stroke="#242c38"/>',
        f'<path d="M0 12 A12 12 0 0 1 12 0 H{width-12:.0f} A12 12 0 0 1 {width:.0f} 12 V{BAR} H0 Z" fill="#121821"/>',
        '<circle cx="22" cy="19" r="5.5" fill="#ff5f57"/><circle cx="40" cy="19" r="5.5" fill="#febc2e"/>'
        '<circle cx="58" cy="19" r="5.5" fill="#28c840"/>',
        f'<text x="{width/2:.0f}" y="24" fill="#7d8899" font-size="12" text-anchor="middle">{title}</text>',
        f'<g font-size="{FS:.0f}" xml:space="preserve">',
    ]
    for y, line in enumerate(used):
        x = 0
        while x < len(line):
            cell = line[x]
            if cell.ch == " ":
                x += 1
                continue
            run = [cell]
            j = x + 1
            while j < len(line) and line[j].key() == cell.key() and line[j].ch != " ":
                run.append(line[j]); j += 1
            fg = cell.fg or "#c9d1d9"
            attrs = f'fill="{fg}"'
            if cell.bold:
                attrs += ' font-weight="600"'
            if cell.dim:
                attrs += ' opacity="0.62"'
            xs = " ".join(f"{PADX + (x + k) * CW:.1f}" for k in range(len(run)))
            text = "".join(c.ch for c in run).replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
            out.append(f'<text x="{xs}" y="{PADY + BAR + (y + 1) * LH - 6:.1f}" {attrs}>{text}</text>')
            x = j
    out += ["</g>", "</svg>", ""]
    return "\n".join(out)


# ---------------------------------------------------------------- pty capture
def run_pty(cmd, timeout=12.0, kill_after=None):
    pid, fd = pty.fork()
    if pid == 0:
        os.environ["COLUMNS"] = str(COLS)
        os.environ["LINES"] = str(ROWS)
        os.execvp(cmd[0], cmd)
    fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack("HHHH", ROWS, COLS, 0, 0))
    buf = b""
    end = time.time() + timeout
    while time.time() < end:
        r, _, _ = select.select([fd], [], [], 0.1)
        if r:
            try:
                chunk = os.read(fd, 65536)
            except OSError:
                break
            if not chunk:
                break
            buf += chunk
            if kill_after and kill_after in buf.decode("utf-8", "replace"):
                time.sleep(0.4)
                break
        else:
            done, _ = os.waitpid(pid, os.WNOHANG)
            if done:
                break
    try:
        os.kill(pid, 9)
    except ProcessLookupError:
        pass
    try:
        os.waitpid(pid, 0)
    except ChildProcessError:
        pass
    return buf.decode("utf-8", "replace")


# ---------------------------------------------------------------- snippets
HERO = r'''
source <(sed -n '1,/^# ---------- @@MARKER@@ ----------/{/^# ---------- @@MARKER@@ ----------/d;p}' "$0")
TTY=1
banner
printf '  %s%s · %s%s\n\n' "$DIM" "$(uname -m)" "Termux/glibc" "$RST"
okline() { printf '  %s✔%s %s[%s]%s %s %s· %s%s\n' "$GR" "$RST" "$GY" "$1" "$RST" "$2" "$DIM" "$3" "$RST"; }
okline 1/2 "@@READ@@" "v2.2.0"
okline 2/2 "@@LATEST@@" "v2.2.5"
printf '\n'
box_top "@@UPDATE@@"
box_row "$(printf '%sv%s%s  →  %sv%s%s' "$BOLD" "2.2.0" "$RST" "$GR$BOLD" "2.2.5" "$RST")"
box_bottom
printf '\n'
'''

MENU = r'''
source <(sed -n '1,/^# ---------- @@MARKER@@ ----------/{/^# ---------- @@MARKER@@ ----------/d;p}' "$0")
TTY=1
banner
printf '  %s%s · %s%s\n\n' "$DIM" "$(uname -m)" "Termux/glibc" "$RST"
okline() { printf '  %s✔%s %s[%s]%s %s %s· %s%s\n' "$GR" "$RST" "$GY" "$1" "$RST" "$2" "$DIM" "$3" "$RST"; }
okline 1/7 "@@READ@@" "v2.2.0"
okline 2/7 "@@LATEST@@" "v2.2.5"
printf '\n'
box_top "@@UPDATE@@"
box_row "$(printf '%sv%s%s  →  %sv%s%s' "$BOLD" "2.2.0" "$RST" "$GR$BOLD" "2.2.5" "$RST")"
box_row "$(printf '@@PACKAGE@@: %s   @@SIZE@@: %s' "opencode-..." "112.4 MiB")"
box_bottom
printf '\n'
menu_select "@@QUESTION@@" "@@YES@@" "@@NO@@"
'''

PROGRESS = r'''
source <(sed -n '1,/^# ---------- @@MARKER@@ ----------/{/^# ---------- @@MARKER@@ ----------/d;p}' "$0")
TTY=1
printf '\n  %s⬢%s  %s\n\n' "$MG" "$RST" "$(gtext @@NAME@@)"
STEP=3; STEPS=7
printf '  %s✔%s %s[1/7]%s @@READ@@ %s· v2.2.0%s\n' "$GR" "$RST" "$GY" "$RST" "$DIM" "$RST"
printf '  %s✔%s %s[2/7]%s @@LATEST@@ %s· v2.2.5%s\n' "$GR" "$RST" "$GY" "$RST" "$DIM" "$RST"
start=$(( ${EPOCHREALTIME/./} - 9000000 ))
printf '  %s⠧%s %s[3/7]%s @@DOWNLOAD@@ %s· opencode-linux-arm64.tar.gz%s\n' "$CY" "$RST" "$GY" "$RST" "$DIM" "$RST"
draw_bar 50529000 117861733 "$start"
'''

LANG = {
    "en": {
        "build": "upopencode",
        "marker": "main flow",
        "name": "upopencode",
        "READ": "Reading the installed version",
        "LATEST": "Checking the latest release",
        "UPDATE": "Update available",
        "PACKAGE": "Package",
        "SIZE": "Size",
        "QUESTION": "Update OpenCode?",
        "YES": "Yes, update to v$LATEST_VER",
        "NO": "No, cancel",
        "DOWNLOAD": "Downloading package",
        "title": "upopencode",
    },
    "ru": {
        "build": "upopencode-ru",
        "marker": "главный поток",
        "name": "upopencode-ru",
        "READ": "Читаю установленную версию",
        "LATEST": "Проверяю последний релиз",
        "UPDATE": "Обновление доступно",
        "PACKAGE": "Пакет",
        "SIZE": "Размер",
        "QUESTION": "Обновить OpenCode?",
        "YES": "Да, обновить до v2.2.5",
        "NO": "Нет, отмена",
        "DOWNLOAD": "Скачиваю пакет",
        "title": "upopencode-ru",
    },
}


def fill(text: str, lang: dict) -> str:
    for key in ("READ", "LATEST", "UPDATE", "PACKAGE", "SIZE", "QUESTION", "YES", "NO", "DOWNLOAD", "name"):
        text = text.replace(f"@@{key}@@", lang[key])
    text = text.replace("@@MARKER@@", lang["marker"])
    text = text.replace("@@NAME@@", lang["name"])
    # $LATEST_VER is a shell variable in the real script; keep the literal text
    return text.replace('"Yes, update to v$LATEST_VER"', '"Yes, update to v2.2.5"')


def main() -> int:
    OUT.mkdir(exist_ok=True)
    env_bash = ["bash", "--noprofile", "--norc", "-c"]

    for code, lang in LANG.items():
        script = str(ROOT / lang["build"])
        suffix = "" if code == "en" else f"-{code}"

        raw = run_pty(env_bash + [fill(HERO, lang), script], timeout=20)
        (OUT / f"screenshot-check{suffix}.svg").write_text(
            svg(feed(blank(ROWS, COLS), raw), f"{lang['name']} --check"))

        raw = run_pty(env_bash + [fill(MENU, lang), script], timeout=30,
                      kill_after="tap an option" if code == "en" else "тап по варианту")
        (OUT / f"screenshot-menu{suffix}.svg").write_text(
            svg(feed(blank(ROWS, COLS), raw), lang["name"]))

        raw = run_pty(env_bash + [fill(PROGRESS, lang), script], timeout=20)
        (OUT / f"screenshot-progress{suffix}.svg").write_text(
            svg(feed(blank(ROWS, COLS), raw), f"{lang['name']} — download" if code == "en" else f"{lang['name']} — загрузка"))

    for p in sorted(OUT.glob("*.svg")):
        print(f"{p.name}: {p.stat().st_size} bytes")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
