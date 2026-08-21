# -*- coding: utf-8 -*-
"""Generate docs/install.ps1 for tslab-cloud.

Run from anywhere:  python tools/gen_ps1.py

The Russian message table is emitted as base64(UTF-8) so the .ps1 file stays pure ASCII:
GitHub Pages serves it as application/octet-stream with no charset, Windows PowerShell 5.1
then decodes the download as cp1252/ANSI, and the UTF-8 bytes of Б В Г Д ё land on the
smart-quote characters — which makes the whole script unparseable.
"""
import base64
import io
import os

RU = [
    ("DockerMissing",    "Docker Desktop не найден."),
    ("WingetInstalling", "Ставлю Docker Desktop через winget (может запросить права администратора)…"),
    ("WingetDone",       "Docker Desktop установлен (или установка запущена). Дальше нужно сделать вручную — это особенность Windows:"),
    ("WingetStep1",      "   1) Перезагрузите компьютер."),
    ("WingetStep2",      "   2) Запустите Docker Desktop и дождитесь статуса 'Engine running' (значок-кит в трее)."),
    ("WingetStep3",      "   3) Снова выполните:  irm https://nektodron.github.io/tslab-cloud/install.ps1 | iex"),
    ("WingetFallback",   "   Если winget не смог установить — скачайте вручную: https://www.docker.com/products/docker-desktop/"),
    ("NoWinget",         "Docker Desktop не найден, и winget в системе недоступен. Установите Docker Desktop вручную: https://www.docker.com/products/docker-desktop/ — затем запустите его (статус «Engine running») и повторите команду."),
    ("DockerNotRunning", "Docker Desktop установлен, но не запущен. Запустите Docker Desktop (значок-кит в трее), дождитесь статуса «Engine running» и повторите."),
    ("DockerReady",      "Docker готов."),
    ("DataDir",          "Папка данных (переживает обновления): {0}"),
    ("Pull",             "Тяну образ: {0}  (может занять пару минут)…"),
    ("DataFound",        "Нашёл существующую установку. Её данные лежат в: {0}"),
    ("DataKeep",         "Оставить эту папку? [Y/n]"),
    ("DataAsk",          "Папка данных [{0}]"),
    ("DataAbsRequired",  "Введите абсолютный путь, например C:\\Users\\User\\tslab"),
    ("DataMkdirFail",    "Не удалось создать папку: {0}"),
    ("DataNewWarn",      "Другая папка — это чистый старт: старые данные останутся на диске, но новый инстанс снова попросит вход в TSVerse."),
    ("DataReusedAuto",   "Неинтерактивный запуск — беру папку данных существующего контейнера: {0}"),
    ("RegionTitle",      "Регион TSVerse:"),
    ("RegionOptGlobal",  "  1) global — tsverse.pro (по умолчанию)"),
    ("RegionOptRu",      "  2) ru     — tsverse.ru"),
    ("RegionOptUs",      "  3) us     — tsverse.us"),
    ("RegionAsk",        "Выберите 1-3 [1]"),
    ("RegionAskAgain",   "Введите 1, 2 или 3."),
    ("RegionCurrent",    "Эта установка настроена на регион TSVerse: {0}"),
    ("RegionKeep",       "Оставить этот регион? [Y/n]"),
    ("RegionChangeWarn", "Другой регион — это отдельное пространство аккаунтов TSVerse: инстанс попросит новый вход."),
    ("RegionSet",        "Регион TSVerse: {0}"),
    ("RegionBad",        "Неизвестное значение TSLAB_REGION: {0} (ожидается global, ru или us)."),
    ("RegionWriteFail",  "Не удалось записать {0} — регион остался прежним."),
    ("PullFailed",       "Не удалось скачать образ. Проверьте интернет и что Docker запущен, затем повторите."),
    ("Run",              "(Пере)запускаю контейнер: {0}"),
    ("RunFailed",        "Не удалось запустить контейнер. Подробности: docker logs {0}"),
    ("Started",          "Контейнер запущен (WebUI только на loopback: http://localhost:{0}/)."),
    ("WaitWebUi",        "Жду запуск WebUI…"),
    ("CheckLogin",       "Проверяю вход в TSVerse (код появляется через ~30–60 сек)…"),
    ("SessionRestored",  "Сессия TSVerse восстановлена — повторный вход не нужен."),
    ("LoginTitle",       "  Вход в TSVerse"),
    ("LoginStep1",       "  1) Откройте: {0}"),
    ("LoginStep2",       "  2) Код:      {0}"),
    ("LoginQr",          "  (или отсканируйте QR ниже)"),
    ("WaitConfirm",      "Жду подтверждения на вашем устройстве (до 5 минут)…"),
    ("Connected",        "Подключено к TSVerse."),
    ("ConfirmTimeout",   "Подтверждение не получено за отведённое время. Откройте логи и завершите вход: docker logs -f {0}"),
    ("NoCodeYet",        "Код входа пока не появился. Посмотрите логи (дождитесь блока с QR): docker logs -f {0}"),
    ("DoneOk",           "Готово. TSLab установлен и подключён к TSVerse."),
    ("DonePartial",      "TSLab установлен и запущен. Завершите вход по инструкции выше."),
    ("Unexpected",       "Непредвиденная ошибка: {0}"),
    ("WindowStaysOpen",  "(Окно PowerShell остаётся открытым — вывод выше можно прочитать.)"),
    ("FooterManage",     "Управление:"),
    ("FooterLogs",       "логи (и код входа)"),
    ("FooterRestart",    "перезапуск (сессия восстановится)"),
    ("FooterRemove",     "удалить контейнер (данные в {0} останутся)"),
    ("FooterUpdate",     "Обновление:"),
    ("FooterPanel",      "Веб-панель управления:"),
    ("FooterData",       "Данные:"),
]

width = max(len(k) for k, _ in RU)
rows = []
for key, text in RU:
    b64 = base64.b64encode(text.encode('utf-8')).decode('ascii')
    rows.append("    %-*s = '%s'  # %s" % (width, key, b64, text))
RU_TABLE = "\n".join(rows)

TEMPLATE = r'''# TSLab Console (headless) - installer for Windows (Docker Desktop).
#
# What it does:
#   1. Checks Docker Desktop.
#   2. Pulls the public tslabdev/tslab-console image and starts the container.
#   3. Keeps data (DB, scripts, settings, TSVerse session) in the user profile - it survives updates.
#   4. Signs the instance into your TSVerse account via the device flow: code + QR go to the logs.
#
# Run (PowerShell):
#   irm https://nektodron.github.io/tslab-cloud/install.ps1 | iex
#
# Message language: English by default, Russian on request (set the variable BEFORE the pipe):
#   $env:TSLAB_LANG='ru'; irm https://nektodron.github.io/tslab-cloud/install.ps1 | iex
#   Without TSLAB_LANG the installer follows the Windows UI culture, and it falls back to English
#   whenever the console cannot be switched to UTF-8.
#
# On an interactive console the installer asks where to keep the data and which TSVerse region to
# use (global / ru / us); it reuses the data folder of an existing container by default. Setting
# $env:TSLAB_DATA_DIR or $env:TSLAB_REGION skips the matching question, and $env:TSLAB_NONINTERACTIVE
# suppresses both - handy for unattended runs.
#
# Other variables (optional): $env:TSLAB_IMAGE, $env:TSLAB_NAME, $env:TSLAB_PORT,
#   $env:TSLAB_DATA_DIR, $env:TSLAB_REGION (global|ru|us), $env:TSLAB_NONINTERACTIVE
#
# IMPORTANT: the script is run through `iex` in the current session, so it NEVER calls `exit`
# (that would close the PowerShell window) - everything lives in a function, errors are printed
# and the window stays open.
#
# MAINTAINERS: keep this file pure ASCII outside of comments. GitHub Pages serves it as
# application/octet-stream with no charset, so Windows PowerShell 5.1 decodes the download as
# cp1252 - and there the UTF-8 bytes of the Cyrillic letters B, V, G, D and yo land exactly on the
# smart-quote characters, which makes the whole script fail to parse. That is why the Russian
# messages below are stored as base64(UTF-8); regenerate them with tools/gen_ps1.py.

function Get-TSLabStringsEn {
  @{
    DockerMissing    = 'Docker Desktop not found.'
    WingetInstalling = 'Installing Docker Desktop via winget (may ask for administrator rights)...'
    WingetDone       = 'Docker Desktop is installed (or the installation has started). The rest is manual - that is how Windows works:'
    WingetStep1      = '   1) Reboot the computer.'
    WingetStep2      = "   2) Start Docker Desktop and wait for the 'Engine running' status (the whale icon in the tray)."
    WingetStep3      = '   3) Run again:  irm https://nektodron.github.io/tslab-cloud/install.ps1 | iex'
    WingetFallback   = '   If winget could not install it, download it manually: https://www.docker.com/products/docker-desktop/'
    NoWinget         = 'Docker Desktop is not installed and winget is unavailable. Install Docker Desktop manually: https://www.docker.com/products/docker-desktop/ - then start it (status "Engine running") and run the command again.'
    DockerNotRunning = 'Docker Desktop is installed but not running. Start Docker Desktop (the whale icon in the tray), wait for the "Engine running" status and try again.'
    DockerReady      = 'Docker is ready.'
    DataDir          = 'Data directory (survives updates): {0}'
    DataFound        = 'Found an existing installation. Its data is in: {0}'
    DataKeep         = 'Keep using this folder? [Y/n]'
    DataAsk          = 'Data folder [{0}]'
    DataAbsRequired  = 'Please enter an absolute path, for example C:\Users\User\tslab'
    DataMkdirFail    = 'Cannot create the folder: {0}'
    DataNewWarn      = 'A different folder means a fresh start: the old data stays on disk, but the new instance will ask for the TSVerse sign-in again.'
    DataReusedAuto   = 'Non-interactive run - reusing the data folder of the existing container: {0}'
    RegionTitle      = 'TSVerse region:'
    RegionOptGlobal  = '  1) global - tsverse.pro (default)'
    RegionOptRu      = '  2) ru     - tsverse.ru'
    RegionOptUs      = '  3) us     - tsverse.us'
    RegionAsk        = 'Choose 1-3 [1]'
    RegionAskAgain   = 'Please enter 1, 2 or 3.'
    RegionCurrent    = 'This installation is set to the TSVerse region: {0}'
    RegionKeep       = 'Keep this region? [Y/n]'
    RegionChangeWarn = 'Another region is a separate TSVerse account space - the instance will ask for a new sign-in.'
    RegionSet        = 'TSVerse region: {0}'
    RegionBad        = 'Unknown TSLAB_REGION value: {0} (expected global, ru or us).'
    RegionWriteFail  = 'Could not write {0} - the region stays as it was.'
    Pull             = 'Pulling the image: {0}  (may take a couple of minutes)...'
    PullFailed       = 'Could not download the image. Check the internet connection and that Docker is running, then try again.'
    Run              = '(Re)starting the container: {0}'
    RunFailed        = 'Could not start the container. Details: docker logs {0}'
    Started          = 'Container started (WebUI on loopback only: http://localhost:{0}/).'
    WaitWebUi        = 'Waiting for the WebUI...'
    CheckLogin       = 'Checking the TSVerse sign-in (the code appears after ~30-60 s)...'
    SessionRestored  = 'TSVerse session restored - no sign-in needed.'
    LoginTitle       = '  Sign in to TSVerse'
    LoginStep1       = '  1) Open:     {0}'
    LoginStep2       = '  2) The code: {0}'
    LoginQr          = '  (or scan the QR code below)'
    WaitConfirm      = 'Waiting for the confirmation on your device (up to 5 minutes)...'
    Connected        = 'Connected to TSVerse.'
    ConfirmTimeout   = 'No confirmation arrived within the timeout. Open the logs and finish the sign-in: docker logs -f {0}'
    NoCodeYet        = 'The sign-in code has not appeared yet. Check the logs and wait for the QR block: docker logs -f {0}'
    DoneOk           = 'Done. TSLab is installed and connected to TSVerse.'
    DonePartial      = 'TSLab is installed and running. Finish the sign-in as described above.'
    Unexpected       = 'Unexpected error: {0}'
    WindowStaysOpen  = '(The PowerShell window stays open so you can read the output above.)'
    FooterManage     = 'Management:'
    FooterLogs       = 'logs (and the sign-in code)'
    FooterRestart    = 'restart (the session is restored)'
    FooterRemove     = 'remove the container (data in {0} is kept)'
    FooterUpdate     = 'Update:'
    FooterPanel      = 'Web control panel:'
    FooterData       = 'Data:'
  }
}

function Get-TSLabStringsRu {
  # base64(UTF-8) - see the MAINTAINERS note at the top. The readable text follows each line.
  $b64 = @{
__RU_TABLE__
  }
  $out = @{}
  foreach ($k in $b64.Keys) {
    $out[$k] = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($b64[$k]))
  }
  return $out
}

function Get-TSLabUiLanguage {
  $req = ''
  if ($env:TSLAB_LANG) { $req = $env:TSLAB_LANG.Trim().ToLowerInvariant() }
  if (@('ru', 'ru-ru', 'ru_ru', 'russian') -contains $req) { return 'ru' }
  if (@('en', 'en-us', 'en_us', 'english') -contains $req) { return 'en' }
  if ($req -ne '') { return 'en' }
  try { if ((Get-UICulture).TwoLetterISOLanguageName -eq 'ru') { return 'ru' } } catch { }
  return 'en'
}

function Get-TSLabStrings {
  # Cyrillic needs a UTF-8 console; without one we print English instead of question marks.
  if ((Get-TSLabUiLanguage) -eq 'ru') {
    try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
    $consoleOk = $false
    try { $consoleOk = ([Console]::OutputEncoding.CodePage -eq 65001) } catch { }
    if ($consoleOk) { return Get-TSLabStringsRu }
  }
  return Get-TSLabStringsEn
}

# --- wizard helpers ---------------------------------------------------------
function Test-TSLabInteractive {
  if ($env:TSLAB_NONINTERACTIVE) { return $false }
  try { return [Environment]::UserInteractive } catch { return $false }
}

function Read-TSLabYesNo([string]$Prompt) {
  $a = Read-Host -Prompt $Prompt
  return -not ($a -match '^\s*[nN]')
}

function Read-TSLabPath([string]$Default, $L) {
  while ($true) {
    $a = Read-Host -Prompt ($L.DataAsk -f $Default)
    if ([string]::IsNullOrWhiteSpace($a)) { $a = $Default }
    $a = $a.Trim().Trim('"')
    if (-not [System.IO.Path]::IsPathRooted($a)) {
      Write-Host $L.DataAbsRequired -ForegroundColor Yellow
      continue
    }
    try { New-Item -ItemType Directory -Force -Path $a | Out-Null; return $a }
    catch { Write-Host ($L.DataMkdirFail -f $a) -ForegroundColor Yellow }
  }
}

function Read-TSLabRegion($L) {
  Write-Host $L.RegionTitle
  Write-Host $L.RegionOptGlobal
  Write-Host $L.RegionOptRu
  Write-Host $L.RegionOptUs
  while ($true) {
    $a = (Read-Host -Prompt $L.RegionAsk)
    if ($null -eq $a) { $a = '' }
    switch -Regex ($a.Trim()) {
      '^(1|global|pro)?$' { return 'global' }
      '^(2|ru)$'          { return 'ru' }
      '^(3|us)$'          { return 'us' }
      default { Write-Host $L.RegionAskAgain -ForegroundColor Yellow }
    }
  }
}

function ConvertTo-TSLabRegion([string]$Value) {
  if ([string]::IsNullOrWhiteSpace($Value)) { return '' }
  switch ($Value.Trim().ToLowerInvariant()) {
    'ru'      { return 'ru' }
    'russia'  { return 'ru' }
    'russian' { return 'ru' }
    'us'      { return 'us' }
    'usa'     { return 'us' }
    'global'  { return 'global' }
    'pro'     { return 'global' }
    'world'   { return 'global' }
    default   { return '' }
  }
}

# The console reads its TSVerse region from launchSettings.json in the CommonData folder, and inside
# the container CommonData is the profile path - the volume we mount. So the file simply lives at
# <data dir>\launchSettings.json on the host.
function Get-TSLabRegionFile([string]$DataDir) {
  $f = Join-Path $DataDir 'launchSettings.json'
  if (-not (Test-Path $f)) { return '' }
  try {
    $j = Get-Content -Raw -Path $f | ConvertFrom-Json
    if ($j.legalRegion) { return [string]$j.legalRegion }
  } catch { }
  return ''
}

function Set-TSLabRegionFile([string]$DataDir, [string]$Region) {
  $f = Join-Path $DataDir 'launchSettings.json'
  $json = "{`r`n  ""legalRegion"": ""$Region""`r`n}`r`n"
  try {
    [System.IO.File]::WriteAllText($f, $json, (New-Object System.Text.UTF8Encoding($false)))
    return $true
  } catch { return $false }
}

function Invoke-TSLabInstall {
  $L = Get-TSLabStrings
  $sep = '-' * 64

  $Image   = if ($env:TSLAB_IMAGE)    { $env:TSLAB_IMAGE }    else { 'tslabdev/tslab-console:latest' }
  $Name    = if ($env:TSLAB_NAME)     { $env:TSLAB_NAME }     else { 'tslab' }
  $Port    = if ($env:TSLAB_PORT)     { $env:TSLAB_PORT }     else { '8088' }
  $DefaultDataDir = Join-Path $env:USERPROFILE '.tslab'
  $DataDir = ''

  function Say($m)  { Write-Host "==> $m" -ForegroundColor Cyan }
  function Ok($m)   { Write-Host "OK  $m" -ForegroundColor Green }
  function Warn($m) { Write-Host "!   $m" -ForegroundColor Yellow }
  function Fail($m) { Write-Host ""; Write-Host "x  $m" -ForegroundColor Red }

  # --- Docker checks (use return, never exit) ---
  if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Warn $L.DockerMissing
    if (Get-Command winget -ErrorAction SilentlyContinue) {
      Say $L.WingetInstalling
      winget install -e --id Docker.DockerDesktop --accept-source-agreements --accept-package-agreements
      Write-Host ""
      Warn $L.WingetDone
      Write-Host $L.WingetStep1 -ForegroundColor Yellow
      Write-Host $L.WingetStep2 -ForegroundColor Yellow
      Write-Host $L.WingetStep3 -ForegroundColor Yellow
      Write-Host $L.WingetFallback -ForegroundColor DarkGray
    }
    else {
      Fail $L.NoWinget
    }
    return
  }
  docker info 2>$null | Out-Null
  if ($LASTEXITCODE -ne 0) {
    Fail $L.DockerNotRunning
    return
  }
  Ok $L.DockerReady

  # --- wizard: data folder ---------------------------------------------------
  # An explicit TSLAB_DATA_DIR wins; otherwise reuse what the existing container has mounted, and
  # only fall back to the default when there is nothing to reuse.
  $existingDataDir = ''
  try {
    $inspected = docker inspect -f '{{range .Mounts}}{{if eq .Destination "/var/lib/tslab"}}{{.Source}}{{end}}{{end}}' $Name 2>$null
    if ($inspected) { $existingDataDir = ([string]($inspected | Select-Object -First 1)).Trim() }
  } catch { }

  if ($env:TSLAB_DATA_DIR) {
    $DataDir = $env:TSLAB_DATA_DIR
  }
  elseif ($existingDataDir) {
    if (Test-TSLabInteractive) {
      Say ($L.DataFound -f $existingDataDir)
      if (Read-TSLabYesNo $L.DataKeep) { $DataDir = $existingDataDir }
      else {
        Warn $L.DataNewWarn
        $DataDir = Read-TSLabPath $DefaultDataDir $L
      }
    }
    else {
      $DataDir = $existingDataDir
      Say ($L.DataReusedAuto -f $DataDir)
    }
  }
  elseif (Test-TSLabInteractive) {
    $DataDir = Read-TSLabPath $DefaultDataDir $L
  }
  else {
    $DataDir = $DefaultDataDir
  }

  try { New-Item -ItemType Directory -Force -Path $DataDir | Out-Null }
  catch { Fail ($L.DataMkdirFail -f $DataDir); return }
  Say ($L.DataDir -f $DataDir)

  # --- wizard: TSVerse region ------------------------------------------------
  $currentRegion = ConvertTo-TSLabRegion (Get-TSLabRegionFile $DataDir)
  $Region = ConvertTo-TSLabRegion $env:TSLAB_REGION
  if ($env:TSLAB_REGION -and -not $Region) { Fail ($L.RegionBad -f $env:TSLAB_REGION); return }
  if (-not $Region) {
    if ($currentRegion) {
      if (Test-TSLabInteractive) {
        Say ($L.RegionCurrent -f $currentRegion)
        if (Read-TSLabYesNo $L.RegionKeep) { $Region = $currentRegion }
        else {
          Warn $L.RegionChangeWarn
          $Region = Read-TSLabRegion $L
        }
      }
      else { $Region = $currentRegion }
    }
    elseif (Test-TSLabInteractive) { $Region = Read-TSLabRegion $L }
    else { $Region = 'global' }
  }
  if ($Region -ne $currentRegion) {
    if (-not (Set-TSLabRegionFile $DataDir $Region)) {
      Warn ($L.RegionWriteFail -f (Join-Path $DataDir 'launchSettings.json'))
    }
  }
  Ok ($L.RegionSet -f $Region)

  Say ($L.Pull -f $Image)
  docker pull $Image
  if ($LASTEXITCODE -ne 0) { Fail $L.PullFailed; return }

  Say ($L.Run -f $Name)
  docker rm -f $Name 2>$null | Out-Null
  docker run -d --name $Name --restart unless-stopped `
    -p "127.0.0.1:${Port}:5000" `
    -e TSLAB_PROFILE_PATH=/var/lib/tslab `
    -v "${DataDir}:/var/lib/tslab" `
    $Image | Out-Null
  if ($LASTEXITCODE -ne 0) { Fail ($L.RunFailed -f $Name); return }
  Ok ($L.Started -f $Port)

  Say $L.WaitWebUi
  for ($i = 0; $i -lt 60; $i++) {
    try { Invoke-WebRequest -UseBasicParsing "http://localhost:$Port/" -TimeoutSec 2 | Out-Null; break } catch { Start-Sleep 1 }
  }

  Say $L.CheckLogin
  $success = $false; $codeShown = $false
  for ($i = 0; $i -lt 90; $i++) {
    $logs = (docker logs $Name 2>&1) -join "`n"
    if ($logs -match 'durable session restored') {
      Ok $L.SessionRestored; $success = $true; break
    }
    if ($logs -match 'Enter code:') {
      $code = ([regex]::Match($logs, 'Enter code:\s*(\S+)')).Groups[1].Value
      $url  = ([regex]::Match($logs, 'code prefilled:\s*(\S+)')).Groups[1].Value.TrimEnd(')')
      if (-not $url) { $url = ([regex]::Match($logs, 'or open:\s*(\S+)')).Groups[1].Value }
      Write-Host ""
      Write-Host $sep
      Write-Host $L.LoginTitle
      Write-Host ($L.LoginStep1 -f $url) -ForegroundColor Cyan
      Write-Host ($L.LoginStep2 -f $code)
      Write-Host $L.LoginQr
      Write-Host $sep
      $block = $logs -split "`n" | Select-String -Pattern 'TSVerse sign-in required \(device flow\)' -Context 0, 40
      if ($block) { $block.Context.PostContext | ForEach-Object { Write-Host $_ } }
      try { Start-Process $url } catch { }
      $codeShown = $true; break
    }
    Start-Sleep 2
  }

  if ($codeShown) {
    Say $L.WaitConfirm
    for ($i = 0; $i -lt 150; $i++) {
      $logs = (docker logs $Name 2>&1) -join "`n"
      if ($logs -match 'successfully connected to the notification system') { Ok $L.Connected; $success = $true; break }
      Start-Sleep 2
    }
    if (-not $success) { Warn ($L.ConfirmTimeout -f $Name) }
  }
  elseif (-not $success) {
    Warn ($L.NoCodeYet -f $Name)
  }

  Write-Host ""
  if ($success) { Ok $L.DoneOk }
  else { Ok $L.DonePartial }

  $removeLine = $L.FooterRemove -f $DataDir
  Write-Host @"

$($L.FooterManage)
  docker logs -f $Name        # $($L.FooterLogs)
  docker restart $Name        # $($L.FooterRestart)
  docker rm -f $Name          # $removeLine

$($L.FooterUpdate)
  irm https://nektodron.github.io/tslab-cloud/install.ps1 | iex

$($L.FooterPanel) https://nektodron.github.io/tslab-cloud/app/
$($L.FooterData) $DataDir
"@
}

$TSLabL = Get-TSLabStrings
try {
  Invoke-TSLabInstall
}
catch {
  Write-Host ""
  Write-Host ("x  " + ($TSLabL.Unexpected -f $_.Exception.Message)) -ForegroundColor Red
}
Write-Host ""
Write-Host $TSLabL.WindowStaysOpen -ForegroundColor DarkGray
'''

out = TEMPLATE.replace('__RU_TABLE__', RU_TABLE)
# CRLF, UTF-8 without BOM (the file is ASCII apart from the trailing comments).
io.open(r'C:\Projects\tslab-cloud\docs\install.ps1', 'w', encoding='utf-8', newline='\r\n').write(out)

# Report any non-ASCII outside comments.
bad = []
for n, line in enumerate(out.splitlines(), 1):
    code = line.split('#', 1)[0]
    if any(ord(c) > 127 for c in code):
        bad.append((n, line))
print('generated; non-ascii code lines:', bad)
