# TSLab Cloud Server

**[English](#english) · [Русский](#русский)**

Instruction page / страница с инструкцией: https://nektodron.github.io/tslab-cloud/
(the page has an RU/EN switch in the top right corner)

---

## English

Put the **TSLab** trading server on your own Linux machine with a single command and connect it to
your **TSVerse** account. No system administration skills required.

### Install with one command

**Linux / macOS:**
```bash
curl -fsSL https://nektodron.github.io/tslab-cloud/install.sh | bash
```

**Windows (PowerShell):**
```powershell
irm https://nektodron.github.io/tslab-cloud/install.ps1 | iex
```

The command:
1. checks Docker and installs it when needed (with a confirmation);
2. pulls the public [`tslabdev/tslab-console`](https://hub.docker.com/r/tslabdev/tslab-console) image and starts the container;
3. keeps the data on the host (`~/.local/share/tslab`) — it survives restarts and updates;
4. signs the instance into TSVerse via the OAuth device flow (RFC 8628): the code + QR are printed
   into the logs and you confirm from your phone. No port forwarding, no access to the WebUI needed.

### Setup wizard: data folder and TSVerse region

On a terminal the installer asks three questions:

- **Data folder** — where the profile (DB, scripts, settings, TSVerse session) lives on the host.
  When a `tslab` container already exists, its mounted folder is detected with `docker inspect` and
  offered as the default, so re-running the one-liner never silently moves your data.
- **TSVerse region** — `global` (tsverse.pro), `ru` (tsverse.ru) or `us` (tsverse.us). It is stored
  as `<data folder>/launchSettings.json` (`{"legalRegion": "..."}`), which the console reads from its
  CommonData folder — inside the container that folder is the mounted profile path.
- **Environment** — `prod` (default), `staging` or `dev`, passed to the container as
  `TSLab__Environment` (the image ships `Production`). On a non-production environment the wizard also
  asks for two optional overrides — the **identity server URL** (for debugging the `/device*` pages)
  and the **marketplace URL**. They are written to `<data folder>/environment.override.json` and
  mounted as `/app/environment.json`, which the console merges over its embedded endpoint catalog;
  only the listed URLs are replaced. Switching back to `prod` removes the file.

Preset either answer to skip the matching question:

```bash
curl -fsSL https://nektodron.github.io/tslab-cloud/install.sh | TSLAB_DATA_DIR=/srv/tslab TSLAB_REGION=ru bash
curl -fsSL https://nektodron.github.io/tslab-cloud/install.sh | TSLAB_ENV=dev TSLAB_IDENTITY_URL=http://192.168.0.10:5001 bash
```

```powershell
$env:TSLAB_DATA_DIR='D:\tslab'; $env:TSLAB_REGION='ru'; irm https://nektodron.github.io/tslab-cloud/install.ps1 | iex
```

Without a terminal (CI, cron) nothing is asked: the existing container's folder is reused, otherwise
the default is taken, and the region falls back to the stored one or `global`.

### Installer language

Both installers speak **English by default** and switch to Russian on request:

```bash
curl -fsSL https://nektodron.github.io/tslab-cloud/install.sh | TSLAB_LANG=ru bash
# or:  curl -fsSL https://nektodron.github.io/tslab-cloud/install.sh | bash -s -- --lang ru
```

```powershell
$env:TSLAB_LANG='ru'; irm https://nektodron.github.io/tslab-cloud/install.ps1 | iex
```

Without `TSLAB_LANG` the language follows the machine locale, and falls back to English whenever the
terminal cannot render Cyrillic — printing Russian into a non-UTF-8 console produces mojibake.

### Management

```bash
docker logs -f tslab      # logs (and the TSVerse sign-in code)
docker restart tslab      # restart (the sign-in is kept)
docker rm -f tslab        # remove the container (data is kept)
```

### What is in the repository

| File | Purpose |
|------|---------|
| `docs/index.html` | Instruction page (GitHub Pages), RU/EN |
| `docs/install.sh` | Installer for Linux / macOS, RU/EN |
| `docs/install.ps1` | Installer for Windows (Docker Desktop), RU/EN |
| `docs/app/` | The hosted web console build (deployed from the main repo) |
| `.gitattributes` | Pins `*.sh` to LF — CRLF breaks `curl … \| bash` |

The image is built and published separately (CI → Docker Hub `tslabdev/tslab-console`). This
repository only distributes the instructions and the install scripts.

> **Maintainers:** `docs/install.sh` must stay LF-only, and `docs/install.ps1` must stay pure ASCII
> outside of comments (its Russian strings are stored as base64 — regenerate them with the
> generator noted at the top of the file). Both rules exist because GitHub Pages serves the files
> verbatim, with no charset, straight into `bash` and `iex`.

---

## Русский

Поставьте торговый сервер **TSLab** на собственный Linux-сервер одной командой и подключите его
к своему аккаунту **TSVerse**. Без навыков системного администратора.

### Установка одной командой

**Linux / macOS:**
```bash
curl -fsSL https://nektodron.github.io/tslab-cloud/install.sh | TSLAB_LANG=ru bash
```

**Windows (PowerShell):**
```powershell
$env:TSLAB_LANG='ru'; irm https://nektodron.github.io/tslab-cloud/install.ps1 | iex
```

Команда:
1. проверяет Docker и при необходимости ставит его (с подтверждением);
2. тянет публичный образ [`tslabdev/tslab-console`](https://hub.docker.com/r/tslabdev/tslab-console) и запускает контейнер;
3. хранит данные на хосте (`~/.local/share/tslab`) — переживают рестарт и обновление;
4. логинит инстанс в TSVerse по OAuth device flow (RFC 8628): код + QR печатаются в логи,
   подтверждение — с вашего телефона. Проброс портов и доступ к WebUI не требуются.

### Мастер: папка данных и регион TSVerse

В терминале установщик задаёт три вопроса:

- **Папка данных** — где на хосте лежит профиль (база, скрипты, настройки, сессия TSVerse). Если
  контейнер `tslab` уже есть, его примонтированная папка определяется через `docker inspect` и
  предлагается по умолчанию — повторный запуск однострочника не уводит данные молча в другое место.
- **Регион TSVerse** — `global` (tsverse.pro), `ru` (tsverse.ru) или `us` (tsverse.us). Хранится в
  `<папка данных>/launchSettings.json` (`{"legalRegion": "..."}`): консоль читает его из своей папки
  CommonData, а внутри контейнера это и есть примонтированный профиль.
- **Окружение** — `prod` (по умолчанию), `staging` или `dev`; уезжает в контейнер как
  `TSLab__Environment` (в образе прошито `Production`). Для не-боевого окружения мастер спросит ещё
  два необязательных адреса — **identity-сервера** (для отладки страниц `/device*`) и **marketplace**.
  Они пишутся в `<папка данных>/environment.override.json` и монтируются как `/app/environment.json`:
  консоль накладывает этот файл на встроенный каталог адресов, перетирая только указанные URL.
  При возврате на `prod` файл удаляется.

Чтобы вопрос не задавался, задайте ответ переменной:

```bash
curl -fsSL https://nektodron.github.io/tslab-cloud/install.sh | TSLAB_DATA_DIR=/srv/tslab TSLAB_REGION=ru bash
curl -fsSL https://nektodron.github.io/tslab-cloud/install.sh | TSLAB_ENV=dev TSLAB_IDENTITY_URL=http://192.168.0.10:5001 bash
```

```powershell
$env:TSLAB_DATA_DIR='D:\tslab'; $env:TSLAB_REGION='ru'; irm https://nektodron.github.io/tslab-cloud/install.ps1 | iex
```

Без терминала (CI, cron) вопросы не задаются: берётся папка существующего контейнера, иначе
дефолтная, а регион — сохранённый ранее или `global`.

### Язык установщика

По умолчанию установщики говорят **по-английски**. Русский включается переменной `TSLAB_LANG=ru`
(в командах выше она уже есть) или ключом `--lang ru`. Без переменной язык берётся из локали
машины, но на не-UTF-8 терминале остаётся английским: кириллица там превращается в «кракозябры».

### Управление

```bash
docker logs -f tslab      # логи (и код входа в TSVerse)
docker restart tslab      # перезапуск (вход сохранится)
docker rm -f tslab        # удалить контейнер (данные останутся)
```

### Что внутри

| Файл | Назначение |
|------|------------|
| `docs/index.html` | Страница-инструкция (GitHub Pages), RU/EN |
| `docs/install.sh` | Установщик для Linux / macOS, RU/EN |
| `docs/install.ps1` | Установщик для Windows (Docker Desktop), RU/EN |
| `docs/app/` | Сборка веб-консоли (деплоится из основного репозитория) |
| `.gitattributes` | Фиксирует LF для `*.sh` — CRLF ломает `curl … \| bash` |

Образ собирается и публикуется отдельно (CI → Docker Hub `tslabdev/tslab-console`).
Этот репозиторий — только дистрибуция инструкции и установочных скриптов.
