#!/usr/bin/env bash
# Installer / updater smoke test. Runs entirely inside a throwaway HOME,
# PREFIX and XDG_DATA_HOME, so the real machine is never touched.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
SB=$(mktemp -d "${TMPDIR:-/tmp}/upopencode-smoke.XXXXXX")
trap 'rm -rf "$SB"' EXIT

export HOME="$SB/home"
export PREFIX="$HOME/.local"
export XDG_DATA_HOME="$SB/data"
export XDG_CONFIG_HOME="$SB/config"
export NO_COLOR=1
mkdir -p "$HOME" "$PREFIX/bin" "$XDG_DATA_HOME/opencode2" "$XDG_CONFIG_HOME/opencode"

BIN="$PREFIX/bin"
OC_DIR="$XDG_DATA_HOME/opencode2"
FAIL=0

say()  { printf '\n== %s\n' "$*"; }
ok()   { printf '   ok: %s\n' "$*"; }
bad()  { printf '   FAIL: %s\n' "$*"; FAIL=1; }
has()  { [ -e "$1" ] || [ -L "$1" ]; }
assert_file()   { has "$1" && ok "$1 exists" || bad "$1 missing"; }
assert_gone()   { if has "$1"; then bad "$1 still exists"; else ok "$1 removed"; fi; }
assert_contains() { case "$1" in *"$2"*) ok "output contains: $2" ;; *) bad "output lacks: $2" ;; esac; }
assert_link()   { [ "$(readlink -f "$1" 2>/dev/null)" = "$(readlink -f "$2" 2>/dev/null)" ] \
                    && ok "$1 → $(basename "$2")" || bad "$1 does not point to $2"; }

# ---------- fake OpenCode v2 install (as uninstall input) ----------
cat > "$OC_DIR/opencode" <<'EOF'
#!/usr/bin/env bash
[ "${1:-}" = "--version" ] && { echo "2.2.5"; exit 0; }
echo "fake opencode"
EOF
chmod 755 "$OC_DIR/opencode"
printf '2.2.5\n' > "$OC_DIR/VERSION"
: > "$OC_DIR/opencode.real"
echo '{"$schema":"test"}' > "$XDG_CONFIG_HOME/opencode/opencode.jsonc"
ln -s /bin/true "$BIN/opencode-v1"          # foreign v1, must survive

# ---------- install both builds ----------
say "install.sh --both: upopencode = ru, upopencode-en = en"
UPOPENCODE_SRC="$ROOT" bash "$ROOT/install.sh" --prefix "$PREFIX" --both >"$SB/install.log"
cat "$SB/install.log"
assert_file "$BIN/upopencode"
assert_file "$BIN/upopencode-en"
assert_file "$BIN/upoc"
assert_file "$BIN/upoc-en"
assert_link "$BIN/upoc" "$BIN/upopencode"
assert_link "$BIN/upoc-en" "$BIN/upopencode-en"
[ -x "$BIN/upopencode" ] && ok "upopencode is executable" || bad "upopencode not executable"

# ---------- version / help ----------
say "--version and --help"
v=$("$BIN/upopencode" --version)
assert_contains "$v" "upopencode 1.5.1"
v=$("$BIN/upopencode-en" --version)
assert_contains "$v" "upopencode-en 1.5.1"
h=$("$BIN/upopencode" --help)
assert_contains "$h" "Использование:"
assert_contains "$h" "--self-update"
assert_contains "$h" "--uninstall-opencode"
h=$("$BIN/upopencode-en" --help)
assert_contains "$h" "Usage:"

# ---------- short command that launches OpenCode ----------
say "--alias set/show/remove"
"$BIN/upopencode" --alias set smoketest >"$SB/alias.log"
cat "$SB/alias.log"
if [ -L "$BIN/smoketest" ]; then ok "alias symlink created"; else bad "alias symlink missing"; fi
"$BIN/upopencode" --alias show >"$SB/show.log"
cat "$SB/show.log"
assert_contains "$(cat "$SB/show.log")" "smoketest"
"$BIN/upopencode" --alias remove smoketest >"$SB/rm.log"
assert_gone "$BIN/smoketest"

# ---------- uninstall: updater only, OpenCode stays ----------
say "--uninstall --yes (removes upopencode, keeps OpenCode)"
ln -s "$OC_DIR/opencode" "$BIN/opencode"
ln -s "$OC_DIR/opencode" "$BIN/opencode2"
ln -s "$OC_DIR/opencode" "$BIN/smokealias"
"$BIN/upopencode" --uninstall --yes >"$SB/uninstall.log"
cat "$SB/uninstall.log"
assert_gone "$BIN/upopencode"
assert_gone "$BIN/upopencode-en"
assert_gone "$BIN/upoc"
assert_gone "$BIN/upoc-en"
assert_gone "$BIN/smokealias"                            # alias belongs to upopencode
assert_file "$OC_DIR/opencode"                           # OpenCode kept
assert_file "$BIN/opencode"                              # its launcher links kept
assert_file "$BIN/opencode2"
assert_file "$BIN/opencode-v1"                           # foreign v1 kept
assert_file "$XDG_CONFIG_HOME/opencode/opencode.jsonc"   # user config kept

# ---------- reinstall, then remove OpenCode only ----------
say "reinstall + --uninstall-opencode --yes"
UPOPENCODE_SRC="$ROOT" bash "$ROOT/install.sh" --prefix "$PREFIX" --both >"$SB/reinstall.log"
"$BIN/upopencode" --alias set smokealias >/dev/null
"$BIN/upopencode" --uninstall-opencode --yes >"$SB/uninstall-oc.log"
cat "$SB/uninstall-oc.log"
assert_gone "$OC_DIR"
assert_gone "$BIN/opencode"
assert_gone "$BIN/opencode2"
assert_gone "$BIN/smokealias"
assert_file "$BIN/upopencode"                            # updater stays
assert_file "$BIN/upopencode-en"
assert_file "$BIN/upoc"
assert_file "$BIN/upoc-en"
assert_file "$BIN/opencode-v1"                           # foreign v1 kept
assert_file "$XDG_CONFIG_HOME/opencode/opencode.jsonc"   # user config kept

# ---------- single language: one command, one alias ----------
for lang in ru en; do
  D="$SB/one-$lang"
  mkdir -p "$D/home" "$D/prefix"
  say "install.sh --$lang (single language)"
  HOME="$D/home" PREFIX="$D/prefix" UPOPENCODE_SRC="$ROOT" \
    bash "$ROOT/install.sh" --prefix "$D/prefix" "--$lang" >"$D/install.log"
  cat "$D/install.log"
  assert_file "$D/prefix/bin/upopencode"
  assert_file "$D/prefix/bin/upoc"
  assert_gone "$D/prefix/bin/upopencode-en"
  assert_gone "$D/prefix/bin/upoc-en"
  assert_link "$D/prefix/bin/upoc" "$D/prefix/bin/upopencode"
  h=$(HOME="$D/home" PREFIX="$D/prefix" "$D/prefix/bin/upopencode" --help)
  if [ "$lang" = "ru" ]; then
    assert_contains "$h" "Использование:"
  else
    assert_contains "$h" "Usage:"
  fi
done

[ "$FAIL" = 0 ] && { printf '\nALL SMOKE TESTS PASSED\n'; exit 0; }
printf '\nSMOKE TESTS FAILED\n'
exit 1
