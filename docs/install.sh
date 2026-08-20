#!/usr/bin/env bash
#
# TSLab Console (headless) — installer for Linux VPS and macOS.
#
# What it does:
#   1. Checks Docker; offers to install it (official get.docker.com) when missing.
#   2. Pulls the public tslabdev/tslab-console image and starts the container.
#   3. Keeps data (DB, scripts, settings, TSVerse session) in the user's home directory,
#      so it survives restarts and image updates.
#   4. Signs the instance into your TSVerse account via the OAuth device flow: the container
#      prints a short code + QR into its logs and you confirm on your phone. No port forwarding
#      and no access to the WebUI are required.
#
# Run (one line):
#   curl -fsSL https://nektodron.github.io/tslab-cloud/install.sh | bash
#
# Message language: English by default, Russian on request.
#   curl -fsSL https://nektodron.github.io/tslab-cloud/install.sh | TSLAB_LANG=ru bash
#   curl -fsSL https://nektodron.github.io/tslab-cloud/install.sh | bash -s -- --lang ru
#   Without TSLAB_LANG the installer follows the shell locale, but falls back to English when the
#   terminal is not UTF-8 — Cyrillic in a non-UTF-8 terminal comes out as mojibake.
#
# Environment variables (all optional):
#   TSLAB_LANG            en | ru — installer message language (default: auto)
#   TSLAB_IMAGE           image (default tslabdev/tslab-console:latest)
#   TSLAB_NAME            container name (default tslab)
#   TSLAB_PORT            local WebUI port bound to loopback (default 8088)
#   TSLAB_DATA_DIR        data directory on the host (default ~/.local/share/tslab)
#   TSLAB_INSTALL_DOCKER  0 — never install Docker automatically
#
# MAINTAINERS: this file must stay LF-only. With CRLF, bash reads `set -o pipefail<CR>` and dies
# with ": invalid option nameipefail". `.gitattributes` pins `*.sh text eol=lf`.
#
set -euo pipefail

IMAGE="${TSLAB_IMAGE:-tslabdev/tslab-console:latest}"
NAME="${TSLAB_NAME:-tslab}"
PORT="${TSLAB_PORT:-8088}"
DATA_DIR="${TSLAB_DATA_DIR:-$HOME/.local/share/tslab}"

# --- language -------------------------------------------------------------
LANG_REQUEST="${TSLAB_LANG:-}"
SHOW_HELP=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --lang)    LANG_REQUEST="${2:-}"; shift 2 || true ;;
    --lang=*)  LANG_REQUEST="${1#--lang=}"; shift ;;
    -h|--help) SHOW_HELP=1; shift ;;
    *)         shift ;;
  esac
done

# Cyrillic is only safe to print into a UTF-8 terminal.
terminal_is_utf8() {
  case "${LC_ALL:-${LC_MESSAGES:-${LANG:-}}}" in
    *UTF-8*|*utf-8*|*UTF8*|*utf8*) return 0 ;;
    *) return 1 ;;
  esac
}

detect_lang() {
  case "${LC_ALL:-${LC_MESSAGES:-${LANG:-}}}" in
    ru*|RU*|Ru*) if terminal_is_utf8; then printf ru; return; fi ;;
  esac
  printf en
}

case "$(printf '%s' "$LANG_REQUEST" | tr 'A-Z' 'a-z')" in
  ru|ru_ru|ru-ru|russian) UI_LANG="ru" ;;
  en|en_us|en-us|english) UI_LANG="en" ;;
  "")                     UI_LANG="$(detect_lang)" ;;
  *)                      UI_LANG="en" ;;
esac

# --- messages -------------------------------------------------------------
strings_en() {
  M_HELP="Usage: install.sh [--lang en|ru]
Environment: TSLAB_LANG, TSLAB_IMAGE, TSLAB_NAME, TSLAB_PORT, TSLAB_DATA_DIR, TSLAB_INSTALL_DOCKER
Docs: https://nektodron.github.io/tslab-cloud/"
  M_DOCKER_MISSING="Docker not found."
  M_DOCKER_AUTOINSTALL_OFF="Automatic Docker installation is disabled. Install Docker and run this script again."
  M_DOCKER_MACOS="On macOS install Docker Desktop manually: https://www.docker.com/products/docker-desktop/ - then run this script again."
  M_DOCKER_PROMPT="Install Docker automatically via get.docker.com (needs root/sudo)? [Y/n] "
  M_DOCKER_DECLINED="Cancelled. Manual installation guide: https://docs.docker.com/engine/install/"
  M_DOCKER_NONINTERACTIVE="Non-interactive run - installing Docker automatically."
  M_DOCKER_NEED_ROOT="Installing Docker requires root or sudo."
  M_DOCKER_INSTALLING="Installing Docker (get.docker.com)..."
  M_DOCKER_GROUP="Added you to the docker group. Log out and back in to use docker without sudo (this run continues via sudo)."
  M_DOCKER_STARTING="Starting the Docker service..."
  M_DOCKER_DAEMON_FAIL="Docker is installed but the daemon is not running. Start it and try again."
  M_DOCKER_READY="Docker is ready (%s)."
  M_DATA_DIR="Data directory (on the host, survives updates): %s"
  M_PULL="Pulling the image: %s"
  M_RUN="(Re)starting the container: %s"
  M_STARTED="Container started (WebUI on loopback only: http://localhost:%s/)."
  M_WAIT_WEBUI="Waiting for the WebUI"
  M_WAIT_DONE=" - ready."
  M_CHECK_LOGIN="Checking the TSVerse sign-in..."
  M_SESSION_RESTORED="TSVerse session restored from saved data - no sign-in needed."
  M_LOGIN_TITLE="  Sign in to TSVerse"
  M_LOGIN_STEP1="  1) Open on your phone / in a browser:"
  M_LOGIN_STEP2="  2) Enter the code:"
  M_LOGIN_QR="  (or scan the QR code printed below)"
  M_WAIT_CONFIRM="Waiting for the confirmation on your device (up to 5 minutes)..."
  M_CONNECTED="Connected to TSVerse."
  M_CONFIRM_TIMEOUT="No confirmation arrived within the timeout."
  M_SEE_LOGS="Open the logs and finish the sign-in (a code lives ~5 minutes; a new one appears when it expires):"
  M_DONE_OK="Done. TSLab is installed and connected to TSVerse."
  M_DONE_PARTIAL="TSLab is installed and running."
  M_DONE_PARTIAL2="Finish the TSVerse sign-in as described above."
  M_F_MANAGE="Management:"
  M_F_LOGS="logs (and the TSVerse sign-in code)"
  M_F_RESTART="restart (the session is restored from saved data)"
  M_F_STOP="stop"
  M_F_REMOVE="remove the container (data in %s is kept)"
  M_F_UPDATE="Update to a newer version:"
  M_F_UPDATE_NOTE="(a repeat run pulls the fresh image; data and the TSVerse sign-in are preserved)"
  M_F_DATA="Data:"
  M_F_BACKUP="Backup:"
}

strings_ru() {
  M_HELP="Использование: install.sh [--lang en|ru]
Переменные окружения: TSLAB_LANG, TSLAB_IMAGE, TSLAB_NAME, TSLAB_PORT, TSLAB_DATA_DIR, TSLAB_INSTALL_DOCKER
Инструкция: https://nektodron.github.io/tslab-cloud/"
  M_DOCKER_MISSING="Docker не найден."
  M_DOCKER_AUTOINSTALL_OFF="Автоустановка Docker отключена. Установите Docker и запустите скрипт снова."
  M_DOCKER_MACOS="На macOS установите Docker Desktop вручную: https://www.docker.com/products/docker-desktop/ — затем запустите скрипт снова."
  M_DOCKER_PROMPT="Установить Docker автоматически через get.docker.com (нужен root/sudo)? [Y/n] "
  M_DOCKER_DECLINED="Отменено. Инструкция по ручной установке: https://docs.docker.com/engine/install/"
  M_DOCKER_NONINTERACTIVE="Неинтерактивный запуск — ставлю Docker автоматически."
  M_DOCKER_NEED_ROOT="Для установки Docker нужны права root или sudo."
  M_DOCKER_INSTALLING="Устанавливаю Docker (get.docker.com)…"
  M_DOCKER_GROUP="Добавил вас в группу docker. Чтобы работать без sudo, перелогиньтесь (текущий запуск продолжу через sudo)."
  M_DOCKER_STARTING="Запускаю службу Docker…"
  M_DOCKER_DAEMON_FAIL="Docker установлен, но демон не запущен. Запустите его и повторите."
  M_DOCKER_READY="Docker готов (%s)."
  M_DATA_DIR="Папка данных (на хосте, переживает обновления): %s"
  M_PULL="Тяну образ: %s"
  M_RUN="(Пере)запускаю контейнер: %s"
  M_STARTED="Контейнер запущен (WebUI только на loopback: http://localhost:%s/)."
  M_WAIT_WEBUI="Жду запуск WebUI"
  M_WAIT_DONE=" — готово."
  M_CHECK_LOGIN="Проверяю вход в TSVerse…"
  M_SESSION_RESTORED="Сессия TSVerse восстановлена из сохранённых данных — повторный вход не нужен."
  M_LOGIN_TITLE="  Вход в TSVerse"
  M_LOGIN_STEP1="  1) Откройте на телефоне / в браузере:"
  M_LOGIN_STEP2="  2) Введите код:"
  M_LOGIN_QR="  (или отсканируйте QR-код ниже)"
  M_WAIT_CONFIRM="Жду подтверждения на вашем устройстве (до 5 минут)…"
  M_CONNECTED="Подключено к TSVerse."
  M_CONFIRM_TIMEOUT="Подтверждение не получено за отведённое время."
  M_SEE_LOGS="Откройте логи и завершите вход (код живёт ~5 минут, при истечении появится новый):"
  M_DONE_OK="Готово. TSLab установлен и подключён к TSVerse."
  M_DONE_PARTIAL="TSLab установлен и запущен."
  M_DONE_PARTIAL2="Завершите вход в TSVerse по инструкции выше."
  M_F_MANAGE="Управление:"
  M_F_LOGS="логи (и код входа в TSVerse)"
  M_F_RESTART="перезапуск (сессия восстановится из сохранённых данных)"
  M_F_STOP="остановить"
  M_F_REMOVE="удалить контейнер (данные в %s останутся)"
  M_F_UPDATE="Обновление до новой версии:"
  M_F_UPDATE_NOTE="(повторный запуск подтянет свежий образ; данные и вход в TSVerse сохраняются)"
  M_F_DATA="Данные:"
  M_F_BACKUP="Бэкап:"
}

if [ "$UI_LANG" = "ru" ]; then strings_ru; else strings_en; fi

if [ "$SHOW_HELP" = "1" ]; then
  printf "%s\n" "$M_HELP"
  exit 0
fi

# --- output ---------------------------------------------------------------
if [ -t 1 ]; then
  B=$'\033[1m'; G=$'\033[32m'; Y=$'\033[33m'; R=$'\033[31m'; C=$'\033[36m'; Z=$'\033[0m'
else
  B=""; G=""; Y=""; R=""; C=""; Z=""
fi
# Check marks and box drawing only render on a UTF-8 terminal; fall back to ASCII elsewhere.
if terminal_is_utf8; then
  G_OK="✓"; G_ERR="✗"; SEP="────────────────────────────────────────────────────────────────"
else
  G_OK="+"; G_ERR="x"; SEP="----------------------------------------------------------------"
fi
say()  { printf "%s\n" "${C}==>${Z} $*"; }
ok()   { printf "%s\n" "${G}${G_OK}${Z} $*"; }
warn() { printf "%s\n" "${Y}!${Z} $*" >&2; }
err()  { printf "%s\n" "${R}${G_ERR} $*${Z}" >&2; exit 1; }
# fmt <template-with-%s> <value> — every template below carries a single %s placeholder.
fmt()  { printf "$1" "${2:-}"; }

OS="$(uname -s)"

# --- sudo -----------------------------------------------------------------
SUDO=""
if [ "$(id -u)" -ne 0 ]; then
  if command -v sudo >/dev/null 2>&1; then SUDO="sudo"; fi
fi

# --- Docker ---------------------------------------------------------------
install_docker() {
  warn "$M_DOCKER_MISSING"
  if [ "${TSLAB_INSTALL_DOCKER:-1}" = "0" ]; then
    err "$M_DOCKER_AUTOINSTALL_OFF"
  fi
  if [ "$OS" = "Darwin" ]; then
    err "$M_DOCKER_MACOS"
  fi
  # Ask for confirmation while a terminal is reachable (works even under `curl | bash`).
  if [ -e /dev/tty ]; then
    printf "%s" "$M_DOCKER_PROMPT" > /dev/tty
    read -r ans < /dev/tty || ans=""
    case "${ans}" in
      [nN]*) err "$M_DOCKER_DECLINED" ;;
    esac
  else
    say "$M_DOCKER_NONINTERACTIVE"
  fi
  if [ "$(id -u)" -ne 0 ] && [ -z "$SUDO" ]; then
    err "$M_DOCKER_NEED_ROOT"
  fi
  say "$M_DOCKER_INSTALLING"
  curl -fsSL https://get.docker.com | $SUDO sh
  $SUDO systemctl enable --now docker 2>/dev/null || true
  # So the current user can run docker without sudo in later sessions.
  if [ "$(id -u)" -ne 0 ]; then
    $SUDO usermod -aG docker "$(id -un)" 2>/dev/null || true
    warn "$M_DOCKER_GROUP"
  fi
}

if ! command -v docker >/dev/null 2>&1; then
  install_docker
fi

# Daemon up?
DOCKER="docker"
if ! docker info >/dev/null 2>&1; then
  if [ -n "$SUDO" ] && $SUDO docker info >/dev/null 2>&1; then
    DOCKER="$SUDO docker"
  else
    say "$M_DOCKER_STARTING"
    $SUDO systemctl start docker 2>/dev/null || true
    for _ in $(seq 1 15); do
      if docker info >/dev/null 2>&1; then break; fi
      if [ -n "$SUDO" ] && $SUDO docker info >/dev/null 2>&1; then DOCKER="$SUDO docker"; break; fi
      sleep 1
    done
    if ! $DOCKER info >/dev/null 2>&1; then
      err "$M_DOCKER_DAEMON_FAIL"
    fi
  fi
fi
ok "$(fmt "$M_DOCKER_READY" "$($DOCKER version --format '{{.Server.Version}}' 2>/dev/null || echo '?')")"

# --- container ------------------------------------------------------------
say "$(fmt "$M_DATA_DIR" "${B}${DATA_DIR}${Z}")"
mkdir -p "$DATA_DIR"

say "$(fmt "$M_PULL" "${B}${IMAGE}${Z}")"
$DOCKER pull "$IMAGE"

say "$(fmt "$M_RUN" "${B}${NAME}${Z}")"
$DOCKER rm -f "$NAME" >/dev/null 2>&1 || true
$DOCKER run -d --name "$NAME" --restart unless-stopped \
  -p "127.0.0.1:${PORT}:5000" \
  -e TSLAB_PROFILE_PATH=/var/lib/tslab \
  -v "${DATA_DIR}:/var/lib/tslab" \
  "$IMAGE" >/dev/null
ok "$(fmt "$M_STARTED" "${PORT}")"

# Wait until the WebUI answers.
printf "%s" "${C}==>${Z} $M_WAIT_WEBUI"
for _ in $(seq 1 60); do
  if curl -fsS "http://localhost:${PORT}/" >/dev/null 2>&1; then printf "%s\n" "$M_WAIT_DONE"; break; fi
  printf "."; sleep 1
done

# --- TSVerse sign-in (device flow) ----------------------------------------
open_url() {
  case "$OS" in
    Darwin) open "$1" >/dev/null 2>&1 || true ;;
    Linux)  command -v xdg-open >/dev/null 2>&1 && xdg-open "$1" >/dev/null 2>&1 || true ;;
  esac
}

say "$M_CHECK_LOGIN"
CODE_SHOWN=0
SUCCESS=0
for _ in $(seq 1 90); do
  logs="$($DOCKER logs "$NAME" 2>&1 || true)"
  if printf "%s" "$logs" | grep -q "durable session restored"; then
    ok "$M_SESSION_RESTORED"
    SUCCESS=1; break
  fi
  if printf "%s" "$logs" | grep -q "Enter code:"; then
    code="$(printf "%s" "$logs" | sed -n 's/.*Enter code:[[:space:]]*//p' | head -1 | awk '{print $1}')"
    vurl="$(printf "%s" "$logs" | sed -n 's/.*code prefilled:[[:space:]]*//p' | head -1 | tr -d ')' | awk '{print $1}')"
    [ -z "${vurl:-}" ] && vurl="$(printf "%s" "$logs" | sed -n 's/.*or open:[[:space:]]*//p' | head -1 | awk '{print $1}')"
    echo
    echo "${B}${SEP}${Z}"
    echo "${B}${M_LOGIN_TITLE}${Z}"
    echo "${M_LOGIN_STEP1}  ${C}${vurl}${Z}"
    echo "${M_LOGIN_STEP2}  ${B}${code}${Z}"
    echo "${M_LOGIN_QR}"
    echo "${B}${SEP}${Z}"
    # Reprint the container's own block so the QR code shows exactly as it drew it.
    printf "%s\n" "$logs" | sed -n '/TSVerse sign-in required (device flow)/,/Waiting for confirmation/p'
    echo
    open_url "$vurl"
    CODE_SHOWN=1
    break
  fi
  sleep 2
done

if [ "$CODE_SHOWN" = "1" ]; then
  say "$M_WAIT_CONFIRM"
  for _ in $(seq 1 150); do
    logs="$($DOCKER logs "$NAME" 2>&1 || true)"
    if printf "%s" "$logs" | grep -q "successfully connected to the notification system"; then
      ok "$M_CONNECTED"
      SUCCESS=1; break
    fi
    sleep 2
  done
  if [ "$SUCCESS" != "1" ]; then
    warn "$M_CONFIRM_TIMEOUT"
    warn "$M_SEE_LOGS"
    warn "    $DOCKER logs -f $NAME"
  fi
fi

# --- summary --------------------------------------------------------------
echo
if [ "$SUCCESS" = "1" ]; then
  ok "${B}${M_DONE_OK}${Z}"
else
  ok "${B}${M_DONE_PARTIAL}${Z} ${M_DONE_PARTIAL2}"
fi
M_F_REMOVE_LINE="$(fmt "$M_F_REMOVE" "${DATA_DIR}")"
cat <<EOF

${B}${M_F_MANAGE}${Z}
  $DOCKER logs -f ${NAME}        # ${M_F_LOGS}
  $DOCKER restart ${NAME}        # ${M_F_RESTART}
  $DOCKER stop ${NAME}           # ${M_F_STOP}
  $DOCKER rm -f ${NAME}          # ${M_F_REMOVE_LINE}

${B}${M_F_UPDATE}${Z}
  curl -fsSL https://nektodron.github.io/tslab-cloud/install.sh | bash
  ${M_F_UPDATE_NOTE}

${B}${M_F_DATA}${Z} ${DATA_DIR}
  ${M_F_BACKUP}  tar czf tslab-backup.tgz -C "${DATA_DIR}" .
EOF
