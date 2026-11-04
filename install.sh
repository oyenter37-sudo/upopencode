#!/usr/bin/env bash
#
# upopencode installer — one command, no dependencies beyond curl.
#
#   curl -fsSL https://raw.githubusercontent.com/oyenter37-sudo/upopencode/main/install.sh | bash
#   ... | bash -s -- --ru     # only the Russian build
#   ... | bash -s -- --en     # only the English build
#
set -uo pipefail

REPO="oyenter37-sudo/upopencode"
REF="${UPOPENCODE_REF:-main}"
RAW="https://raw.githubusercontent.com/${REPO}/${REF}"
WANT="both"          # both | en | ru
SRC_DIR="${UPOPENCODE_SRC:-}"   # for tests: install from a local checkout

RST=''; BOLD=''; DIM=''; GR=''; RD=''; YL=''; CY=''
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  RST=$'\033[0m'; BOLD=$'\033[1m'; DIM=$'\033[2m'
  GR=$'\033[38;5;46m'; RD=$'\033[38;5;203m'; YL=$'\033[38;5;220m'; CY=$'\033[38;5;51m'
fi

say()  { printf '%s\n' "$*"; }
ok()   { printf '  %s✔%s %s\n' "$GR" "$RST" "$*"; }
warn() { printf '  %s!%s %s\n' "$YL" "$RST" "$*"; }
die()  { printf '  %s✖%s %s\n' "$RD" "$RST" "$1" >&2; [ -n "${2:-}" ] && printf '%s\n' "$2" >&2; exit 1; }

usage() {
  cat <<EOF
upopencode installer

  --en        install the English build only  (upopencode)
  --ru        install the Russian build only  (upopencode-ru)
  --both      install both builds (default)
  --prefix D  install into D/bin instead of auto-detecting
  --ref REF   git ref to install from (default: main)
  -h, --help  this help

Examples:
  curl -fsSL ${RAW}/install.sh | bash
  curl -fsSL ${RAW}/install.sh | bash -s -- --ru
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --en)     WANT="en" ;;
    --ru)     WANT="ru" ;;
    --both)   WANT="both" ;;
    --prefix) [ $# -ge 2 ] || die "--prefix needs a directory"; PREFIX="$2"; shift ;;
    --ref)    [ $# -ge 2 ] || die "--ref needs a value"; REF="$2"; RAW="https://raw.githubusercontent.com/${REPO}/${REF}"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "Unknown option: $1" "Run with --help" ;;
  esac
  shift
done

# ---------- where to install ----------
if [ -n "${PREFIX:-}" ] && [ -d "$PREFIX" ]; then
  BIN="$PREFIX/bin"
elif [ -d /data/data/com.termux/files/usr ] && [ -w /data/data/com.termux/files/usr/bin ]; then
  BIN="/data/data/com.termux/files/usr/bin"
elif [ "$(id -u)" = 0 ]; then
  BIN="/usr/local/bin"
else
  BIN="$HOME/.local/bin"
fi
mkdir -p "$BIN" 2>/dev/null || die "Cannot create $BIN" "Try: --prefix \$HOME/.local"

TERMUX=0
[ -d /data/data/com.termux/files/usr ] && TERMUX=1

say ""
say "  ${CY}⬢${RST}  ${BOLD}upopencode${RST} installer"
say "  ${DIM}OpenCode v2 for Termux / Linux · ${BIN}${RST}"
say ""

command -v curl >/dev/null 2>&1 || die "curl is required." "Termux: pkg install curl"

fetch() { # $1 = file name, $2 = destination
  if [ -n "$SRC_DIR" ]; then
    [ -f "$SRC_DIR/$1" ] || return 1
    cp "$SRC_DIR/$1" "$2"
  else
    curl -fsSL --connect-timeout 10 --max-time 60 --retry 2 --retry-delay 1 \
      "${RAW}/$1" -o "$2" 2>/dev/null
  fi
}

install_one() { # $1 = en | ru
  local name tmp
  case "$1" in
    en) name="upopencode" ;;
    ru) name="upopencode-ru" ;;
  esac
  tmp=$(mktemp "${TMPDIR:-/tmp}/upopencode.XXXXXX" 2>/dev/null) || die "No temp dir" "Set TMPDIR"
  fetch "$name" "$tmp" || { rm -f "$tmp"; die "Download failed: ${RAW}/${name}" "Check your network and the ref (--ref)."; }
  grep -q '^SELF_VERSION=' "$tmp" 2>/dev/null || { rm -f "$tmp"; die "${name} is not an upopencode script."; }
  [ "$TERMUX" = 1 ] && sed -i "1s|.*|#!/data/data/com.termux/files/usr/bin/bash|" "$tmp"
  chmod 755 "$tmp"
  install -m 755 "$tmp" "$BIN/$name" || { rm -f "$tmp"; die "Cannot write $BIN/$name" "Permissions?"; }
  rm -f "$tmp"
  ok "$name → $BIN/$name"
}

alias_for() { # $1 = en | ru
  case "$1" in
    en) ln -sfn "$BIN/upopencode" "$BIN/upoc" 2>/dev/null || true ;;
    ru) ln -sfn "$BIN/upopencode-ru" "$BIN/upoc-ru" 2>/dev/null || true ;;
  esac
}

say "  ${BOLD}Installing${RST}"
case "$WANT" in
  en) install_one en; alias_for en; HAVE="upopencode" ;;
  ru) install_one ru; alias_for ru; HAVE="upopencode-ru" ;;
  *)  install_one en; install_one ru; alias_for en; alias_for ru; HAVE="upopencode (en) / upopencode-ru (ru)" ;;
esac

# ---------- sanity check ----------
if [ "$TERMUX" = 1 ]; then
  SHELL_BIN="/data/data/com.termux/files/usr/bin/bash"
else
  SHELL_BIN="$(command -v bash || true)"
fi
if [ -n "$SHELL_BIN" ] && ! "$SHELL_BIN" "$BIN/upopencode" --version >/dev/null 2>&1; then
  warn "Installed, but the self-check failed."
  warn "Run: $BIN/upopencode --version"
fi

say ""
case "$WANT" in
  en) say "  ${GR}✔${RST} Installed: ${BOLD}upopencode${RST} ${DIM}(English)${RST}" ;;
  ru) say "  ${GR}✔${RST} Установлено: ${BOLD}upopencode-ru${RST} ${DIM}(русский)${RST}" ;;
  *)  say "  ${GR}✔${RST} Installed: ${BOLD}upopencode${RST} ${DIM}(English)${RST}  +  ${BOLD}upopencode-ru${RST} ${DIM}(русский)${RST}" ;;
esac
say ""
say "  ${DIM}Next:${RST}  ${BOLD}upopencode${RST}        ${DIM}# menu, update OpenCode${RST}"
[ "$WANT" = "ru" ] && say "         ${BOLD}upopencode-ru${RST}     ${DIM}# то же меню по-русски${RST}"
say "         ${BOLD}upopencode --check${RST} ${DIM}# just check versions${RST}"
say "         ${BOLD}upopencode --help${RST}  ${DIM}# all options${RST}"
say ""
case ":$PATH:" in
  *":$BIN:"*) ;;
  *) warn "$BIN is not in PATH — add: export PATH=\"$BIN:\$PATH\"" ;;
esac
