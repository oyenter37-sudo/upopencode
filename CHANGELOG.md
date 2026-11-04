# upopencode 1.5.0

First public release.

### Added
- Interactive updater for **OpenCode v2** on Termux (glibc build) and Linux.
- Three modes detected automatically: fresh install, broken install (repair), and
  legacy **v1 → v2** migration (the old binary is kept as `opencode-v1`).
- Arrow-key / mouse-tap menus with a responsive boxed UI and a single-line
  progress bar that adapts to the terminal width.
- Version lookup through three independent sources: npm dist-tags, the GitHub
  releases atom feed, and the GitHub API (with retries and a time budget).
- SHA-256 verification, `patchelf` interpreter fix, atomic replace and
  automatic rollback if the new binary refuses to start.
- Disk-space preflight with a `--clean` helper; the downloaded archive is
  deleted right after extraction to keep the peak footprint low.
- Optional backup of the previous binary (`--backup` / `--no-backup`).
- `--check`, `--dry-run`, `--yes`, `--force`, `--restart`, `--no-color`.
- Short launcher names: `upoc` (English) and `upoc-ru` (Russian), managed with
  `--alias set|show|remove NAME`.
- `--self-update` — update the updater itself from GitHub.
- `--uninstall` — remove upopencode itself (short names and aliases) while
  keeping OpenCode, user data and config.
- `--uninstall-opencode` — remove OpenCode v2 and its launcher while keeping
  upopencode, user data and config.
- English (`upopencode`) and Russian (`upopencode-ru`) builds generated from a
  single source of truth.
- One-command installer with `--en`, `--ru`, `--both`, `--prefix`, `--ref`.
