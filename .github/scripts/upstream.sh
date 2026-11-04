#!/usr/bin/env bash
# Resolve the latest OpenCode 2.x version. Used by the daily upstream check.
set -euo pipefail

json_latest() {
  python3 -c 'import json,sys; print(json.load(sys.stdin).get("latest", ""))' 2>/dev/null || true
}

# v2 releases are not "latest" on GitHub (v1 still is), so pick the highest
# stable 2.x from the release list instead.
json_latest_v2() {
  python3 -c '
import json, re, sys
best = None
for rel in json.load(sys.stdin):
    if rel.get("draft") or rel.get("prerelease"):
        continue
    v = rel.get("tag_name", "").lstrip("v")
    if not re.fullmatch(r"2\.\d+\.\d+", v):
        continue
    key = tuple(int(x) for x in v.split("."))
    if best is None or key > best[0]:
        best = (key, v)
print(best[1] if best else "")
' 2>/dev/null || true
}

valid() {
  printf '%s' "$1" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$'
}

version=""

# 1) npm dist-tags — fast and not rate-limited
if tags=$(curl -fsSL --max-time 20 \
  'https://registry.npmjs.org/-/package/@opencode%2Fcli/dist-tags' 2>/dev/null); then
  version=$(printf '%s' "$tags" | json_latest)
fi

# 2) GitHub releases as a fallback
if ! valid "${version#v}"; then
  if rel=$(curl -fsSL --max-time 20 \
    'https://api.github.com/repos/anomalyco/opencode/releases?per_page=30' 2>/dev/null); then
    version=$(printf '%s' "$rel" | json_latest_v2)
  fi
fi

version=${version#v}
if ! valid "$version"; then
  echo "could not resolve the latest OpenCode version" >&2
  exit 1
fi

printf '%s\n' "$version"
