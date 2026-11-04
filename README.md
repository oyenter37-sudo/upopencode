<div align="center">

# ⬢ upopencode

**OpenCode v2 installer & updater for Termux (glibc) and Linux.**
Fresh install · v1 → v2 migration · atomic updates · one-line progress.

[![CI](https://github.com/oyenter37-sudo/upopencode/actions/workflows/ci.yml/badge.svg)](https://github.com/oyenter37-sudo/upopencode/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/oyenter37-sudo/upopencode?color=46c018)](https://github.com/oyenter37-sudo/upopencode/releases)
[![License: MIT](https://img.shields.io/github/license/oyenter37-sudo/upopencode?color=blue)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Termux%20%7C%20Linux-8957e5)](#requirements)

<img src="docs/screenshot-check.svg" alt="upopencode --check" width="760">

</div>

---

## Why

The official OpenCode build is a **glibc** binary, and Termux ships **musl/Android**
libs. Copying it into `$PREFIX/bin` gives you `libc.so: invalid ELF header`,
a broken `LD_PRELOAD`, and no way to update it later.

`upopencode` handles all of it:

- detects **fresh install**, **broken install** and **legacy v1**;
- downloads the right asset for **arm64 / x64**;
- verifies **SHA-256**;
- patches the interpreter with `patchelf` (no `RUNPATH`, it would segfault);
- swaps the binary **atomically** and **rolls back** if it does not start;
- keeps your v1 around as `opencode-v1`;
- shows a pretty menu you can drive with keys **or a finger tap**.

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/oyenter37-sudo/upopencode/main/install.sh | bash
```

That installs **both** builds:

| Command | Language |
|---|---|
| `upopencode` | English |
| `upopencode-ru` | Русский |

Want only one?

```sh
# English only
curl -fsSL https://raw.githubusercontent.com/oyenter37-sudo/upopencode/main/install.sh | bash -s -- --en

# Russian only
curl -fsSL https://raw.githubusercontent.com/oyenter37-sudo/upopencode/main/install.sh | bash -s -- --ru
```

Then just run it:

```sh
upopencode          # menu: install / update / migrate
upopencode --check  # is there a newer version?
```

> **No Node.js, no Python, no npm.** Pure Bash + `curl`, `tar`, `sha256sum`, `df`
> and, on Termux, `patchelf` + `glibc` (the script offers to install them).

## Screenshots

<div align="center">
<img src="docs/screenshot-menu.svg" alt="interactive menu" width="720">
<img src="docs/screenshot-progress.svg" alt="one-line progress bar" width="720">
</div>

## Usage

| Command | What it does |
|---|---|
| `upopencode` | interactive menu: install / update / migrate |
| `upopencode --check`, `-c` | check installed vs latest version, change nothing |
| `upopencode --dry-run`, `-n` | show the plan and disk space, download nothing |
| `upopencode --yes`, `-y` | no prompts (no backup) |
| `upopencode --force`, `-f` | reinstall even if the version matches |
| `upopencode --restart`, `-r` | restart the background service after updating |
| `upopencode --backup` | always keep a backup of the previous binary |
| `upopencode --no-backup` | never keep a backup |
| `upopencode --clean` | delete old backups and abandoned temp dirs |
| `upopencode --alias set NAME` | add a short command that launches OpenCode |
| `upopencode --alias show` | list launchers (`opencode`, `opencode2`, your aliases) |
| `upopencode --alias remove NAME` | remove one of your aliases |
| `upopencode --self-update` | update **upopencode itself** from GitHub |
| `upopencode --uninstall` | remove upopencode itself, keep OpenCode |
| `upopencode --uninstall-opencode` | remove OpenCode v2 and its launcher, keep upopencode |
| `upopencode --no-color` | plain output for logs |

### Short commands

```sh
upopencode --alias set code     # now "code" launches OpenCode
upopencode --alias show
#   ✔ oc        → v2.2.5
#   ✔ code      → v2.2.5
#   ✔ opencode  (built-in)
```

The installer already creates `upoc` (English build) and `upoc-ru` (Russian).

### Keep it fresh

```sh
upopencode --self-update
```

It downloads the latest `upopencode` from this repository, rewrites the shebang
for your platform and replaces itself atomically. `upopencode-ru` updates from
`upopencode-ru`.

## How it works

1. **Detect** — architecture (`arm64` / `x64`), Termux vs Linux, installed
   version, whether the binary actually runs, and whether `opencode` is a v1.
2. **Resolve the latest v2** — npm dist-tags → GitHub atom feed → GitHub API,
   with retries and a hard time budget.
3. **Preflight** — check free disk space (peak ≈ 4.5 × asset + 30 MiB), offer
   `--clean` if it is tight.
4. **Download** — verify `SHA256SUMS`, delete the archive immediately after
   extraction.
5. **Patch** — `patchelf --set-interpreter` to the Termux glibc loader.
6. **Swap** — hardlink rollback, `mv` over the real binary, run `--version`,
   roll back automatically on failure.
7. **Link** — recreate `opencode` / `opencode2` symlinks; a legacy v1 becomes
   `opencode-v1`; optionally restart the background service.

## Requirements

**Termux** (Android, aarch64 / x86_64): `curl`, `tar`, `coreutils`, plus `glibc`
and `patchelf` (offered automatically) — that is what makes the glibc build run.

**Linux** (x86_64 / aarch64): `curl`, `tar`, `sha256sum`, `bash`.

## Uninstall

Two separate commands, so you never delete more than you meant to.

Remove **upopencode only** — OpenCode keeps working:

```sh
upopencode --uninstall
```

Remove **OpenCode v2** — upopencode stays installed, so you can bring it back:

```sh
upopencode --uninstall-opencode
```

Both ask for confirmation first; add `--yes` for scripts. Neither touches your
data or config:

- `~/.local/share/opencode` — sessions, storage
- `~/.config/opencode` — `opencode.jsonc`, MCP servers, plugins

## Troubleshooting

<details>
<summary><b>“Could not determine the latest version”</b></summary>

The script tries npm, then the GitHub atom feed, then the GitHub API. If all
three fail, check your network:

```sh
curl -I https://registry.npmjs.org/-/package/@opencode%2Fcli/dist-tags
curl -I https://github.com/anomalyco/opencode/releases.atom
```

If `curl` works, just run the command again — brief DNS failures happen.
</details>

<details>
<summary><b>“Not enough space”</b></summary>

An update peaks at roughly **4.5 × 112 MiB + 30 MiB ≈ 536 MiB** (new binary +
old binary + extraction). Free some space or run:

```sh
upopencode --clean
```
</details>

<details>
<summary><b>Updated, but the running service is still old</b></summary>

```sh
opencode2 service restart
```
or use `upopencode --restart` next time.
</details>

## Contributing

- `upopencode` (English) is the **source of truth**.
- `upopencode-ru` is **generated**: edit the English script, then run

  ```sh
  python3 tools/translate.py to-ru
  ```

  CI fails if the two files are out of sync.
- Screenshots are generated from real terminal output:

  ```sh
  python3 docs/make_shots.py
  ```

## License

[MIT](LICENSE) © 2026 oyenter37-sudo

<div align="center"><sub>OpenCode is a separate project by its authors. This tool only installs it.</sub></div>
