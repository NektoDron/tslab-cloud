# TSLab Console (headless) — установщик для Windows (Docker Desktop).
#
# Что делает:
#   1. Проверяет Docker Desktop.
#   2. Тянет публичный образ tslabdev/tslab-console и запускает контейнер.
#   3. Данные (БД, скрипты, настройки, сессия TSCloud) хранит в папке пользователя,
#      поэтому они переживают рестарт и обновление образа.
#   4. Логинит инстанс в ваш аккаунт TSCloud по device flow: код + QR печатаются в логи.
#
# Запуск (PowerShell):
#   irm https://nektodron.github.io/tslab-cloud/install.ps1 | iex
#
# Переменные (необязательно): $env:TSLAB_IMAGE, $env:TSLAB_NAME, $env:TSLAB_PORT, $env:TSLAB_DATA_DIR

$ErrorActionPreference = 'Stop'

$Image   = if ($env:TSLAB_IMAGE)    { $env:TSLAB_IMAGE }    else { 'tslabdev/tslab-console:latest' }
$Name    = if ($env:TSLAB_NAME)     { $env:TSLAB_NAME }     else { 'tslab' }
$Port    = if ($env:TSLAB_PORT)     { $env:TSLAB_PORT }     else { '8088' }
$DataDir = if ($env:TSLAB_DATA_DIR) { $env:TSLAB_DATA_DIR } else { Join-Path $env:USERPROFILE '.tslab' }

function Say($m)  { Write-Host "==> $m" -ForegroundColor Cyan }
function Ok($m)   { Write-Host "OK  $m" -ForegroundColor Green }
function Warn($m) { Write-Host "!   $m" -ForegroundColor Yellow }
function Die($m)  { Write-Host "x   $m" -ForegroundColor Red; exit 1 }

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
  Die "Docker Desktop не найден. Установите его: https://www.docker.com/products/docker-desktop/ и запустите скрипт снова."
}
try { docker info | Out-Null } catch { Die "Docker Desktop установлен, но не запущен. Запустите Docker Desktop и повторите." }
Ok "Docker готов."

Say "Папка данных (переживает обновления): $DataDir"
New-Item -ItemType Directory -Force -Path $DataDir | Out-Null

Say "Тяну образ: $Image"
docker pull $Image

Say "(Пере)запускаю контейнер: $Name"
docker rm -f $Name 2>$null | Out-Null
docker run -d --name $Name --restart unless-stopped `
  -p "127.0.0.1:${Port}:5000" `
  -e TSLAB_PROFILE_PATH=/var/lib/tslab `
  -v "${DataDir}:/var/lib/tslab" `
  $Image | Out-Null
Ok "Контейнер запущен (WebUI только на loopback: http://localhost:$Port/)."

Say "Жду запуск WebUI…"
for ($i = 0; $i -lt 60; $i++) {
  try { Invoke-WebRequest -UseBasicParsing "http://localhost:$Port/" -TimeoutSec 2 | Out-Null; break } catch { Start-Sleep 1 }
}

Say "Проверяю вход в TSCloud…"
$success = $false; $codeShown = $false
for ($i = 0; $i -lt 90; $i++) {
  $logs = (docker logs $Name 2>&1) -join "`n"
  if ($logs -match 'durable session restored') {
    Ok "Сессия TSCloud восстановлена — повторный вход не нужен."; $success = $true; break
  }
  if ($logs -match 'Enter code:') {
    $code = ([regex]::Match($logs, 'Enter code:\s*(\S+)')).Groups[1].Value
    $url  = ([regex]::Match($logs, 'code prefilled:\s*(\S+)')).Groups[1].Value.TrimEnd(')')
    if (-not $url) { $url = ([regex]::Match($logs, 'or open:\s*(\S+)')).Groups[1].Value }
    Write-Host ""
    Write-Host "────────────────────────────────────────────────────────────────"
    Write-Host "  Вход в TSCloud"
    Write-Host "  1) Откройте: $url" -ForegroundColor Cyan
    Write-Host "  2) Код:      $code"
    Write-Host "  (или отсканируйте QR ниже)"
    Write-Host "────────────────────────────────────────────────────────────────"
    $block = $logs -split "`n" | Select-String -Pattern 'TSCloud sign-in required \(device flow\)' -Context 0,40
    if ($block) { $block.Context.PostContext | ForEach-Object { Write-Host $_ } }
    try { Start-Process $url } catch {}
    $codeShown = $true; break
  }
  Start-Sleep 2
}

if ($codeShown) {
  Say "Жду подтверждения на вашем устройстве (до 5 минут)…"
  for ($i = 0; $i -lt 150; $i++) {
    $logs = (docker logs $Name 2>&1) -join "`n"
    if ($logs -match 'successfully connected to the notification system') { Ok "Подключено к TSCloud."; $success = $true; break }
    Start-Sleep 2
  }
  if (-not $success) { Warn "Подтверждение не получено. Откройте логи: docker logs -f $Name" }
}

Write-Host ""
if ($success) { Ok "Готово. TSLab установлен и подключён к TSCloud." }
else { Ok "TSLab установлен и запущен. Завершите вход по инструкции выше." }
Write-Host @"

Управление:
  docker logs -f $Name        # логи (и код входа)
  docker restart $Name        # перезапуск (сессия восстановится)
  docker rm -f $Name          # удалить контейнер (данные в $DataDir останутся)

Обновление:
  irm https://nektodron.github.io/tslab-cloud/install.ps1 | iex

Данные: $DataDir
"@
