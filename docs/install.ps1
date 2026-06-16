# TSLab Console (headless) — установщик для Windows (Docker Desktop).
#
# Что делает:
#   1. Проверяет Docker Desktop.
#   2. Тянет публичный образ tslabdev/tslab-console и запускает контейнер.
#   3. Данные (БД, скрипты, настройки, сессия TSVerse) хранит в папке пользователя — переживают обновления.
#   4. Логинит инстанс в ваш аккаунт TSVerse по device flow: код + QR печатаются в логи.
#
# Запуск (PowerShell):
#   irm https://nektodron.github.io/tslab-cloud/install.ps1 | iex
#
# Переменные (необязательно): $env:TSLAB_IMAGE, $env:TSLAB_NAME, $env:TSLAB_PORT, $env:TSLAB_DATA_DIR
#
# ВАЖНО: скрипт запускается через `iex` в текущей сессии, поэтому он НИКОГДА не вызывает `exit`
# (это закрыло бы окно PowerShell) — вся логика в функции, ошибки показываются, окно остаётся открытым.

function Invoke-TSLabInstall {
  $Image   = if ($env:TSLAB_IMAGE)    { $env:TSLAB_IMAGE }    else { 'tslabdev/tslab-console:latest' }
  $Name    = if ($env:TSLAB_NAME)     { $env:TSLAB_NAME }     else { 'tslab' }
  $Port    = if ($env:TSLAB_PORT)     { $env:TSLAB_PORT }     else { '8088' }
  $DataDir = if ($env:TSLAB_DATA_DIR) { $env:TSLAB_DATA_DIR } else { Join-Path $env:USERPROFILE '.tslab' }

  function Say($m)  { Write-Host "==> $m" -ForegroundColor Cyan }
  function Ok($m)   { Write-Host "OK  $m" -ForegroundColor Green }
  function Warn($m) { Write-Host "!   $m" -ForegroundColor Yellow }
  function Fail($m) { Write-Host ""; Write-Host "x  $m" -ForegroundColor Red }

  # --- Docker checks (use return, never exit) ---
  if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Warn "Docker Desktop не найден."
    if (Get-Command winget -ErrorAction SilentlyContinue) {
      Say "Ставлю Docker Desktop через winget (может запросить права администратора)…"
      winget install -e --id Docker.DockerDesktop --accept-source-agreements --accept-package-agreements
      Write-Host ""
      Warn "Docker Desktop установлен (или установка запущена). Дальше нужно сделать вручную — это особенность Windows:"
      Write-Host "   1) Перезагрузите компьютер." -ForegroundColor Yellow
      Write-Host "   2) Запустите Docker Desktop и дождитесь статуса 'Engine running' (значок-кит в трее)." -ForegroundColor Yellow
      Write-Host "   3) Снова выполните:  irm https://nektodron.github.io/tslab-cloud/install.ps1 | iex" -ForegroundColor Yellow
      Write-Host "   Если winget не смог установить — скачайте вручную: https://www.docker.com/products/docker-desktop/" -ForegroundColor DarkGray
    }
    else {
      Fail "Docker Desktop не найден, и winget в системе недоступен. Установите Docker Desktop вручную: https://www.docker.com/products/docker-desktop/  — затем запустите его (статус 'Engine running') и повторите команду."
    }
    return
  }
  docker info 2>$null | Out-Null
  if ($LASTEXITCODE -ne 0) {
    Fail "Docker Desktop установлен, но не запущен. Запустите Docker Desktop (значок-кит в трее), дождитесь статуса 'Engine running' и повторите."
    return
  }
  Ok "Docker готов."

  Say "Папка данных (переживает обновления): $DataDir"
  New-Item -ItemType Directory -Force -Path $DataDir | Out-Null

  Say "Тяну образ: $Image  (может занять пару минут)…"
  docker pull $Image
  if ($LASTEXITCODE -ne 0) { Fail "Не удалось скачать образ. Проверьте интернет и что Docker запущен, затем повторите."; return }

  Say "(Пере)запускаю контейнер: $Name"
  docker rm -f $Name 2>$null | Out-Null
  docker run -d --name $Name --restart unless-stopped `
    -p "127.0.0.1:${Port}:5000" `
    -e TSLAB_PROFILE_PATH=/var/lib/tslab `
    -v "${DataDir}:/var/lib/tslab" `
    $Image | Out-Null
  if ($LASTEXITCODE -ne 0) { Fail "Не удалось запустить контейнер. Подробности: docker logs $Name"; return }
  Ok "Контейнер запущен (WebUI только на loopback: http://localhost:$Port/)."

  Say "Жду запуск WebUI…"
  for ($i = 0; $i -lt 60; $i++) {
    try { Invoke-WebRequest -UseBasicParsing "http://localhost:$Port/" -TimeoutSec 2 | Out-Null; break } catch { Start-Sleep 1 }
  }

  Say "Проверяю вход в TSVerse (код появляется через ~30–60 сек)…"
  $success = $false; $codeShown = $false
  for ($i = 0; $i -lt 90; $i++) {
    $logs = (docker logs $Name 2>&1) -join "`n"
    if ($logs -match 'durable session restored') {
      Ok "Сессия TSVerse восстановлена — повторный вход не нужен."; $success = $true; break
    }
    if ($logs -match 'Enter code:') {
      $code = ([regex]::Match($logs, 'Enter code:\s*(\S+)')).Groups[1].Value
      $url  = ([regex]::Match($logs, 'code prefilled:\s*(\S+)')).Groups[1].Value.TrimEnd(')')
      if (-not $url) { $url = ([regex]::Match($logs, 'or open:\s*(\S+)')).Groups[1].Value }
      Write-Host ""
      Write-Host "────────────────────────────────────────────────────────────────"
      Write-Host "  Вход в TSVerse"
      Write-Host "  1) Откройте: $url" -ForegroundColor Cyan
      Write-Host "  2) Код:      $code"
      Write-Host "  (или отсканируйте QR ниже)"
      Write-Host "────────────────────────────────────────────────────────────────"
      $block = $logs -split "`n" | Select-String -Pattern 'TSVerse sign-in required \(device flow\)' -Context 0,40
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
      if ($logs -match 'successfully connected to the notification system') { Ok "Подключено к TSVerse."; $success = $true; break }
      Start-Sleep 2
    }
    if (-not $success) { Warn "Подтверждение не получено за отведённое время. Откройте логи и завершите вход: docker logs -f $Name" }
  }
  elseif (-not $success) {
    Warn "Код входа пока не появился. Посмотрите логи (дождитесь блока с QR): docker logs -f $Name"
  }

  Write-Host ""
  if ($success) { Ok "Готово. TSLab установлен и подключён к TSVerse." }
  else { Ok "TSLab установлен и запущен. Завершите вход по инструкции выше." }
  Write-Host @"

Управление:
  docker logs -f $Name        # логи (и код входа)
  docker restart $Name        # перезапуск (сессия восстановится)
  docker rm -f $Name          # удалить контейнер (данные в $DataDir останутся)

Обновление:
  irm https://nektodron.github.io/tslab-cloud/install.ps1 | iex

Веб-панель управления: https://nektodron.github.io/tslab-cloud/app/
Данные: $DataDir
"@
}

try {
  Invoke-TSLabInstall
}
catch {
  Write-Host ""
  Write-Host "x  Непредвиденная ошибка: $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""
Write-Host "(Окно PowerShell остаётся открытым — вывод выше можно прочитать.)" -ForegroundColor DarkGray
