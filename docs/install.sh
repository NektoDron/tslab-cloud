#!/usr/bin/env bash
#
# TSLab Console (headless) — установщик для Linux VPS и macOS.
#
# Что делает:
#   1. Проверяет Docker; если его нет — предлагает поставить (официальный get.docker.com).
#   2. Тянет публичный образ tslabdev/tslab-console и запускает контейнер.
#   3. Данные (БД, скрипты, настройки, сессия TSCloud) хранит в домашней папке пользователя,
#      поэтому они переживают рестарт и обновление образа.
#   4. Логинит инстанс в ваш аккаунт TSCloud по OAuth device flow: контейнер печатает в логи
#      короткий код + QR; вы подтверждаете на телефоне. Проброс портов и доступ к WebUI не нужны.
#
# Запуск (одной строкой):
#   curl -fsSL https://nektodron.github.io/tslab-cloud/install.sh | bash
#
# Переменные окружения (необязательно):
#   TSLAB_IMAGE           образ (по умолчанию tslabdev/tslab-console:latest)
#   TSLAB_NAME            имя контейнера (по умолчанию tslab)
#   TSLAB_PORT            локальный порт WebUI на loopback (по умолчанию 8088)
#   TSLAB_DATA_DIR        папка данных на хосте (по умолчанию ~/.local/share/tslab)
#   TSLAB_INSTALL_DOCKER  0 — не ставить Docker автоматически
#
set -euo pipefail

IMAGE="${TSLAB_IMAGE:-tslabdev/tslab-console:latest}"
NAME="${TSLAB_NAME:-tslab}"
PORT="${TSLAB_PORT:-8088}"
DATA_DIR="${TSLAB_DATA_DIR:-$HOME/.local/share/tslab}"

# --- вывод ----------------------------------------------------------------
if [ -t 1 ]; then
  B=$'\033[1m'; G=$'\033[32m'; Y=$'\033[33m'; R=$'\033[31m'; C=$'\033[36m'; Z=$'\033[0m'
else
  B=""; G=""; Y=""; R=""; C=""; Z=""
fi
say()  { printf "%s\n" "${C}==>${Z} $*"; }
ok()   { printf "%s\n" "${G}✓${Z} $*"; }
warn() { printf "%s\n" "${Y}!${Z} $*" >&2; }
err()  { printf "%s\n" "${R}✗ $*${Z}" >&2; exit 1; }

OS="$(uname -s)"

# --- sudo -----------------------------------------------------------------
SUDO=""
if [ "$(id -u)" -ne 0 ]; then
  if command -v sudo >/dev/null 2>&1; then SUDO="sudo"; fi
fi

# --- Docker ---------------------------------------------------------------
install_docker() {
  warn "Docker не найден."
  if [ "${TSLAB_INSTALL_DOCKER:-1}" = "0" ]; then
    err "Автоустановка Docker отключена. Установите Docker и запустите скрипт снова."
  fi
  if [ "$OS" = "Darwin" ]; then
    err "На macOS установите Docker Desktop вручную: https://www.docker.com/products/docker-desktop/ — затем запустите скрипт снова."
  fi
  # Спрашиваем подтверждение, если есть терминал (даже при запуске через curl | bash).
  if [ -e /dev/tty ]; then
    printf "%s" "Установить Docker автоматически через get.docker.com (нужен root/sudo)? [Y/n] " > /dev/tty
    read -r ans < /dev/tty || ans=""
    case "${ans}" in
      [nN]*) err "Отменено. Инструкция по ручной установке: https://docs.docker.com/engine/install/" ;;
    esac
  else
    say "Неинтерактивный запуск — ставлю Docker автоматически."
  fi
  if [ "$(id -u)" -ne 0 ] && [ -z "$SUDO" ]; then
    err "Для установки Docker нужны права root или sudo."
  fi
  say "Устанавливаю Docker (get.docker.com)…"
  curl -fsSL https://get.docker.com | $SUDO sh
  $SUDO systemctl enable --now docker 2>/dev/null || true
  # Чтобы текущий пользователь мог работать с docker без sudo в будущих сессиях.
  if [ "$(id -u)" -ne 0 ]; then
    $SUDO usermod -aG docker "$(id -un)" 2>/dev/null || true
    warn "Добавил вас в группу docker. Для применения без sudo перелогиньтесь (текущий запуск продолжу через sudo)."
  fi
}

if ! command -v docker >/dev/null 2>&1; then
  install_docker
fi

# Демон запущен?
DOCKER="docker"
if ! docker info >/dev/null 2>&1; then
  if [ -n "$SUDO" ] && $SUDO docker info >/dev/null 2>&1; then
    DOCKER="$SUDO docker"
  else
    say "Запускаю службу Docker…"
    $SUDO systemctl start docker 2>/dev/null || true
    for _ in $(seq 1 15); do
      if docker info >/dev/null 2>&1; then break; fi
      if [ -n "$SUDO" ] && $SUDO docker info >/dev/null 2>&1; then DOCKER="$SUDO docker"; break; fi
      sleep 1
    done
    if ! $DOCKER info >/dev/null 2>&1; then
      err "Docker установлен, но демон не запущен. Запустите его и повторите."
    fi
  fi
fi
ok "Docker готов ($($DOCKER version --format '{{.Server.Version}}' 2>/dev/null || echo '?'))."

# --- запуск контейнера ----------------------------------------------------
say "Папка данных (на хосте, переживает обновления): ${B}${DATA_DIR}${Z}"
mkdir -p "$DATA_DIR"

say "Тяну образ: ${B}${IMAGE}${Z}"
$DOCKER pull "$IMAGE"

say "(Пере)запускаю контейнер: ${B}${NAME}${Z}"
$DOCKER rm -f "$NAME" >/dev/null 2>&1 || true
$DOCKER run -d --name "$NAME" --restart unless-stopped \
  -p "127.0.0.1:${PORT}:5000" \
  -e TSLAB_PROFILE_PATH=/var/lib/tslab \
  -v "${DATA_DIR}:/var/lib/tslab" \
  "$IMAGE" >/dev/null
ok "Контейнер запущен (WebUI только на loopback: http://localhost:${PORT}/)."

# Ждём, пока WebUI поднимется.
printf "%s" "${C}==>${Z} Жду запуск WebUI"
for _ in $(seq 1 60); do
  if curl -fsS "http://localhost:${PORT}/" >/dev/null 2>&1; then printf " — готово.\n"; break; fi
  printf "."; sleep 1
done

# --- вход в TSCloud (device flow) -----------------------------------------
open_url() {
  case "$OS" in
    Darwin) open "$1" >/dev/null 2>&1 || true ;;
    Linux)  command -v xdg-open >/dev/null 2>&1 && xdg-open "$1" >/dev/null 2>&1 || true ;;
  esac
}

say "Проверяю вход в TSCloud…"
CODE_SHOWN=0
SUCCESS=0
for _ in $(seq 1 90); do
  logs="$($DOCKER logs "$NAME" 2>&1 || true)"
  if printf "%s" "$logs" | grep -q "durable session restored"; then
    ok "Сессия TSCloud восстановлена из сохранённых данных — повторный вход не нужен."
    SUCCESS=1; break
  fi
  if printf "%s" "$logs" | grep -q "Enter code:"; then
    code="$(printf "%s" "$logs" | sed -n 's/.*Enter code:[[:space:]]*//p' | head -1 | awk '{print $1}')"
    vurl="$(printf "%s" "$logs" | sed -n 's/.*code prefilled:[[:space:]]*//p' | head -1 | tr -d ')' | awk '{print $1}')"
    [ -z "${vurl:-}" ] && vurl="$(printf "%s" "$logs" | sed -n 's/.*or open:[[:space:]]*//p' | head -1 | awk '{print $1}')"
    echo
    echo "${B}────────────────────────────────────────────────────────────────${Z}"
    echo "${B}  Вход в TSCloud${Z}"
    echo "  1) Откройте на телефоне/в браузере:  ${C}${vurl}${Z}"
    echo "  2) Введите код:                      ${B}${code}${Z}"
    echo "  (или отсканируйте QR-код ниже из логов)"
    echo "${B}────────────────────────────────────────────────────────────────${Z}"
    # Показываем полный блок с QR-кодом так, как его печатает контейнер.
    printf "%s\n" "$logs" | sed -n '/TSCloud sign-in required (device flow)/,/Waiting for confirmation/p'
    echo
    open_url "$vurl"
    CODE_SHOWN=1
    break
  fi
  sleep 2
done

if [ "$CODE_SHOWN" = "1" ]; then
  say "Жду подтверждения на вашем устройстве (до 5 минут)…"
  for _ in $(seq 1 150); do
    logs="$($DOCKER logs "$NAME" 2>&1 || true)"
    if printf "%s" "$logs" | grep -q "successfully connected to the notification system"; then
      ok "Подключено к TSCloud."
      SUCCESS=1; break
    fi
    sleep 2
  done
  if [ "$SUCCESS" != "1" ]; then
    warn "Подтверждение не получено за отведённое время."
    warn "Откройте логи и завершите вход (код живёт ~5 минут, при истечении появится новый):"
    warn "    $DOCKER logs -f $NAME"
  fi
fi

# --- итог -----------------------------------------------------------------
echo
if [ "$SUCCESS" = "1" ]; then
  ok "${B}Готово. TSLab установлен и подключён к TSCloud.${Z}"
else
  ok "${B}TSLab установлен и запущен.${Z} Завершите вход в TSCloud по инструкции выше."
fi
cat <<EOF

${B}Управление:${Z}
  $DOCKER logs -f ${NAME}        # логи (и код входа в TSCloud)
  $DOCKER restart ${NAME}        # перезапуск (сессия восстановится из сохранённых данных)
  $DOCKER stop ${NAME}           # остановить
  $DOCKER rm -f ${NAME}          # удалить контейнер (данные в ${DATA_DIR} останутся)

${B}Обновление до новой версии:${Z}
  curl -fsSL https://nektodron.github.io/tslab-cloud/install.sh | bash
  (повторный запуск подтянет свежий образ; данные и вход в TSCloud сохранятся)

${B}Данные:${Z} ${DATA_DIR}
  Бэкап:  tar czf tslab-backup.tgz -C "${DATA_DIR}" .
EOF
