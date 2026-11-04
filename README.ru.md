<div align="center">

# ⬢ upopencode

**Установщик и обновлятор OpenCode v2 для Termux (glibc) и Linux.**
Установка с нуля · переезд v1 → v2 · атомарные обновления · прогресс в одну строку.

[![CI](https://github.com/oyenter37-sudo/upopencode/actions/workflows/ci.yml/badge.svg)](https://github.com/oyenter37-sudo/upopencode/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/oyenter37-sudo/upopencode?color=46c018)](https://github.com/oyenter37-sudo/upopencode/releases)
[![License: MIT](https://img.shields.io/github/license/oyenter37-sudo/upopencode?color=blue)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Termux%20%7C%20Linux-8957e5)](#требования)

<img src="docs/screenshot-check-ru.svg" alt="upopencode --check" width="760">

</div>

---

## Зачем

Официальная сборка OpenCode — **glibc**-бинарь, а в Termux библиотеки **musl/Android**.
Если просто скопировать его в `$PREFIX/bin`, получишь `libc.so: invalid ELF header`,
сломанный `LD_PRELOAD` и никакой возможности обновляться.

`upopencode` берёт всё на себя:

- различает **чистую установку**, **повреждённую** и **старый v1**;
- качает нужный ассет под **arm64 / x64**;
- сверяет **SHA-256**;
- патчит интерпретатор через `patchelf` (без `RUNPATH` — с ним бинарь падает);
- меняет бинарь **атомарно** и **откатывается**, если новый не запустился;
- сохраняет v1 как `opencode-v1`;
- показывает красивое меню: стрелки, цифры, Enter и **тап пальцем**.

## Установка

```sh
curl -fsSL https://raw.githubusercontent.com/oyenter37-sudo/upopencode/main/install.sh | bash
```

Ставятся **обе** версии:

| Команда | Язык |
|---|---|
| `upopencode` | English |
| `upopencode-ru` | Русский |

Нужна только одна?

```sh
# только английская
curl -fsSL https://raw.githubusercontent.com/oyenter37-sudo/upopencode/main/install.sh | bash -s -- --en

# только русская
curl -fsSL https://raw.githubusercontent.com/oyenter37-sudo/upopencode/main/install.sh | bash -s -- --ru
```

Дальше просто:

```sh
upopencode-ru        # меню: поставить / обновить / переехать
upopencode-ru --check  # есть ли новая версия?
```

> **Никакого Node.js, Python и npm.** Чистый Bash + `curl`, `tar`, `sha256sum`, `df`,
> а на Termux ещё `patchelf` и `glibc` (скрипт сам предложит их поставить).

## Скриншоты

<div align="center">
<img src="docs/screenshot-menu-ru.svg" alt="интерактивное меню" width="720">
<img src="docs/screenshot-progress-ru.svg" alt="прогресс в одну строку" width="720">
</div>

## Использование

| Команда | Что делает |
|---|---|
| `upopencode-ru` | интерактивное меню: поставить / обновить / переехать |
| `upopencode-ru --check`, `-c` | сравнить установленную и последнюю версию, ничего не менять |
| `upopencode-ru --dry-run`, `-n` | показать план и место, ничего не качать |
| `upopencode-ru --yes`, `-y` | без вопросов (бэкап не создаётся) |
| `upopencode-ru --force`, `-f` | переустановить, даже если версия та же |
| `upopencode-ru --restart`, `-r` | перезапустить фоновый сервис после обновления |
| `upopencode-ru --backup` | всегда оставлять бэкап старого бинаря |
| `upopencode-ru --no-backup` | никогда не оставлять бэкап |
| `upopencode-ru --clean` | удалить старые бэкапы и брошенные временные папки |
| `upopencode-ru --alias set ИМЯ` | короткая команда для запуска OpenCode |
| `upopencode-ru --alias show` | список лаунчеров (`opencode`, `opencode2`, твои алиасы) |
| `upopencode-ru --alias remove ИМЯ` | удалить свой алиас |
| `upopencode-ru --self-update` | обновить **сам upopencode** с GitHub |
| `upopencode-ru --uninstall` | удалить сам upopencode, OpenCode останется |
| `upopencode-ru --uninstall-opencode` | удалить OpenCode v2 и лаунчер, upopencode останется |
| `upopencode-ru --no-color` | без цветов (для логов) |

### Короткие команды

```sh
upopencode-ru --alias set code     # теперь "code" запускает OpenCode
upopencode-ru --alias show
#   ✔ oc        → v2.2.5
#   ✔ code      → v2.2.5
#   ✔ opencode  (служебное)
```

Установщик уже создаёт `upoc` (английская сборка) и `upoc-ru` (русская).

### Обновлять сам апдейтер

```sh
upopencode-ru --self-update
```

Скачивает свежий `upopencode-ru` из этого репозитория, правит shebang под
платформу и атомарно заменяет себя. Английская сборка обновляется из
`upopencode`.

## Как это работает

1. **Определение** — архитектура (`arm64` / `x64`), Termux или Linux,
   установленная версия, запускается ли бинарь и не стоит ли v1.
2. **Поиск свежей v2** — npm dist-tags → atom-лента GitHub → GitHub API,
   с повторами и ограничением по времени.
3. **Проверка места** — пик ≈ 4.5 × размер ассета + 30 МиБ; если мало,
   предлагает `--clean`.
4. **Загрузка** — сверка `SHA256SUMS`, архив удаляется сразу после распаковки.
5. **Патч** — `patchelf --set-interpreter` на glibc-загрузчик Termux.
6. **Замена** — rollback через hardlink, `mv` поверх бинаря, запуск `--version`,
   автоматический откат при ошибке.
7. **Симлинки** — пересоздаёт `opencode` / `opencode2`; старый v1 становится
   `opencode-v1`; при желании перезапускает фоновый сервис.

## Требования

**Termux** (Android, aarch64 / x86_64): `curl`, `tar`, `coreutils`, плюс `glibc`
и `patchelf` (предложит поставить) — без них glibc-бинарь не запустится.

**Linux** (x86_64 / aarch64): `curl`, `tar`, `sha256sum`, `bash`.

## Удаление

Две отдельные команды — чтобы случайно не удалить лишнее.

Удалить **только upopencode** — OpenCode продолжит работать:

```sh
upopencode-ru --uninstall
```

Удалить **OpenCode v2** — upopencode останется, чтобы можно было поставить обратно:

```sh
upopencode-ru --uninstall-opencode
```

Обе команды сначала спрашивают подтверждение; для скриптов добавь `--yes`.
Данные и настройки не трогаются:

- `~/.local/share/opencode` — сессии и storage
- `~/.config/opencode` — `opencode.jsonc`, MCP-серверы, плагины

## Если что-то пошло не так

<details>
<summary><b>«Не удалось узнать последнюю версию»</b></summary>

Скрипт пробует npm, потом atom-ленту GitHub, потом GitHub API. Если все три
не ответили — проверь сеть:

```sh
curl -I https://registry.npmjs.org/-/package/@opencode%2Fcli/dist-tags
curl -I https://github.com/anomalyco/opencode/releases.atom
```

Если `curl` отвечает — просто запусти ещё раз: бывают кратковременные сбои DNS.
</details>

<details>
<summary><b>«Не хватает места»</b></summary>

Пик обновления — примерно **4.5 × 112 МиБ + 30 МиБ ≈ 536 МиБ** (новый бинарь +
старый бинарь + распаковка). Освободи место или запусти:

```sh
upopencode-ru --clean
```
</details>

<details>
<summary><b>Обновилось, но сервис всё ещё старый</b></summary>

```sh
opencode2 service restart
```
или в следующий раз используй `upopencode-ru --restart`.
</details>

## Участие

- `upopencode` (английский) — **источник правды**.
- `upopencode-ru` — **генерируется**: правь английский скрипт, затем

  ```sh
  python3 tools/translate.py to-ru
  ```

  CI упадёт, если файлы разойдутся.
- Скриншоты собраны из настоящего вывода терминала:

  ```sh
  python3 docs/make_shots.py
  ```

## Лицензия

[MIT](LICENSE) © 2026 oyenter37-sudo

<div align="center"><sub>OpenCode — отдельный проект его авторов. Этот инструмент только устанавливает его.</sub></div>
