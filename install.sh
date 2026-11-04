#!/usr/bin/env bash
#
# upopencode installer — one command, no dependencies beyond curl.
#
#   curl -fsSL https://raw.githubusercontent.com/oyenter37-sudo/upopencode/main/install.sh | bash
#   ... | bash -s -- --ru     # skip the menu: only the Russian build
#   ... | bash -s -- --en     # skip the menu: only the English build
#
set -uo pipefail

REPO="oyenter37-sudo/upopencode"
REF="${UPOPENCODE_REF:-main}"
RAW="https://raw.githubusercontent.com/${REPO}/${REF}"
WANT="both"          # both | en | ru
WANT_SET=0           # 1 when --en/--ru/--both was passed
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

  (no options)  choose the language with an arrow-key menu
  --en          English only:  upopencode, upoc
  --ru          Russian only:  upopencode, upoc
  --both        both:  upopencode (ru), upopencode-en (en)
  --prefix D    install into D/bin instead of auto-detecting
  --ref REF     git ref to install from (default: main)
  -h, --help    this help

Examples:
  curl -fsSL ${RAW}/install.sh | bash
  curl -fsSL ${RAW}/install.sh | bash -s -- --ru
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --en)     WANT="en";   WANT_SET=1 ;;
    --ru)     WANT="ru";   WANT_SET=1 ;;
    --both)   WANT="both"; WANT_SET=1 ;;
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

# ---------- language menu ----------
LANG_NAMES=("English + Русский  (both)" "English only" "Русский / Russian only")
LANG_VALS=(both en ru)
LANG_SEL=0

draw_lang() {
  local i
  for i in 0 1 2; do
    if [ "$i" = "$LANG_SEL" ]; then
      printf '  %s▸%s %s%s%s\n' "$CY" "$RST" "$BOLD" "${LANG_NAMES[$i]}" "$RST"
    else
      printf '    %s%s%s\n' "$DIM" "${LANG_NAMES[$i]}" "$RST"
    fi
  done
}

choose_lang() {
  local key c1 c2 c3
  if [ -t 0 ]; then
    exec 3<&0
  elif { exec 3</dev/tty; } 2>/dev/null && [ -t 3 ]; then
    :                                        # piped through curl — read keys from the terminal
  else
    say "  ${DIM}No terminal — installing both builds (use --en or --ru to pick one).${RST}"
    say ""
    return
  fi

  say "  ${BOLD}Choose the language / Выбери язык${RST}"
  say "  ${DIM}↑/↓ · Enter · 1/2/3${RST}"
  say ""
  draw_lang
  while :; do
    IFS= read -rsn1 -u 3 key || break
    case "$key" in
      '') break ;;
      $'\e')
        IFS= read -rsn1 -t 0.05 -u 3 c1 || break
        [ "$c1" = "[" ] || continue
        IFS= read -rsn1 -t 0.05 -u 3 c2 || continue
        case "$c2" in
          A) LANG_SEL=$(( (LANG_SEL + 2) % 3 )) ;;
          B) LANG_SEL=$(( (LANG_SEL + 1) % 3 )) ;;
          '<') while IFS= read -rsn1 -t 0.05 -u 3 c3; do
                 case "$c3" in M|m) break ;; esac
               done
               continue ;;
          *) continue ;;
        esac ;;
      [1-3]) LANG_SEL=$(( key - 1 )) ;;
      j|J)   LANG_SEL=$(( (LANG_SEL + 1) % 3 )) ;;
      k|K)   LANG_SEL=$(( (LANG_SEL + 2) % 3 )) ;;
      *) continue ;;
    esac
    printf '\033[3A'
    draw_lang
  done
  WANT="${LANG_VALS[$LANG_SEL]}"
  printf '\n'
  case "$WANT" in
    en) say "  ${GR}✔${RST} Language: ${BOLD}English${RST}" ;;
    ru) say "  ${GR}✔${RST} Язык: ${BOLD}русский${RST}" ;;
    *)  say "  ${GR}✔${RST} Language / Язык: ${BOLD}English + Русский${RST}" ;;
  esac
  say ""
  exec 3<&-
}

if [ "$WANT_SET" = 0 ]; then
  choose_lang
fi

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

install_one() { # $1 = en | ru (repo file), $2 = installed file name
  local src target tmp
  case "$1" in
    en) src="upopencode" ;;
    ru) src="upopencode-ru" ;;
  esac
  target="${2:-$src}"
  tmp=$(mktemp "${TMPDIR:-/tmp}/upopencode.XXXXXX" 2>/dev/null) || die "No temp dir" "Set TMPDIR"
  fetch "$src" "$tmp" || { rm -f "$tmp"; die "Download failed: ${RAW}/${src}" "Check your network and the ref (--ref)."; }
  grep -q '^SELF_VERSION=' "$tmp" 2>/dev/null || { rm -f "$tmp"; die "${src} is not an upopencode script."; }
  [ "$TERMUX" = 1 ] && sed -i "1s|.*|#!/data/data/com.termux/files/usr/bin/bash|" "$tmp"
  chmod 755 "$tmp"
  install -m 755 "$tmp" "$BIN/$target" || { rm -f "$tmp"; die "Cannot write $BIN/$target" "Permissions?"; }
  rm -f "$tmp"
  ok "$target → $BIN/$target"
}

link_aliases() {
  # one short name for a single language, two when both are installed
  rm -f "$BIN/upoc" "$BIN/upoc-en" "$BIN/upoc-ru" 2>/dev/null || true
  ln -sfn "$BIN/upopencode" "$BIN/upoc" 2>/dev/null || true
  if [ "$WANT" = "both" ]; then
    ln -sfn "$BIN/upopencode-en" "$BIN/upoc-en" 2>/dev/null || true
  fi
}

say "  ${BOLD}Installing${RST}"
rm -f "$BIN/upopencode" "$BIN/upopencode-en" "$BIN/upopencode-ru" 2>/dev/null || true
case "$WANT" in
  en) install_one en upopencode ;;
  ru) install_one ru upopencode ;;
  *)  install_one ru upopencode
      install_one en upopencode-en ;;
esac
link_aliases

# ---------- sanity check ----------
if [ "$TERMUX" = 1 ]; then
  SHELL_BIN="/data/data/com.termux/files/usr/bin/bash"
else
  SHELL_BIN="$(command -v bash || true)"
fi
CHECK_FILES=("$BIN/upopencode")
[ "$WANT" = "both" ] && CHECK_FILES+=("$BIN/upopencode-en")
for f in "${CHECK_FILES[@]}"; do
  if [ -n "$SHELL_BIN" ] && ! "$SHELL_BIN" "$f" --version >/dev/null 2>&1; then
    warn "Installed, but the self-check failed for $f"
    warn "Run: $SHELL_BIN $f --version"
  fi
done

say ""
case "$WANT" in
  en) say "  ${GR}✔${RST} Installed: ${BOLD}upopencode${RST} ${DIM}(English)${RST}" ;;
  ru) say "  ${GR}✔${RST} Установлено: ${BOLD}upopencode${RST} ${DIM}(русский)${RST}" ;;
  *)  say "  ${GR}✔${RST} Installed: ${BOLD}upopencode${RST} ${DIM}(русский)${RST}  +  ${BOLD}upopencode-en${RST} ${DIM}(English)${RST}" ;;
esac
say ""
say "  ${DIM}Next:${RST}  ${BOLD}upoc${RST}             ${DIM}# $( [ "$WANT" = "en" ] && echo "menu, update OpenCode" || echo "меню, обновление OpenCode" )${RST}"
say "         ${BOLD}upoc --check${RST}      ${DIM}# just check versions${RST}"
say "         ${BOLD}upoc --help${RST}       ${DIM}# all options${RST}"
say ""
case "$WANT" in
  en) say "  ${DIM}upoc → upopencode (English)${RST}" ;;
  ru) say "  ${DIM}upoc → upopencode (русский)${RST}" ;;
  *)  say "  ${DIM}upoc → upopencode (русский) · upoc-en → upopencode-en (English)${RST}" ;;
esac
say ""
case ":$PATH:" in
  *":$BIN:"*) ;;
  *) warn "$BIN is not in PATH — add: export PATH=\"$BIN:\$PATH\"" ;;
esac
