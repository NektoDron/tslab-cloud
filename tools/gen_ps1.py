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
    ("EnvTitle",         "Окружение TSVerse:"),
    ("EnvOptProd",       "  1) prod    — боевое (по умолчанию)"),
    ("EnvOptStaging",    "  2) staging — предпрод"),
    ("EnvOptDev",        "  3) dev     — разработка"),
    ("EnvAsk",           "Выберите 1-3 [1]"),
    ("EnvAskAgain",      "Введите 1, 2 или 3."),
    ("EnvCurrent",       "Эта установка работает с окружением: {0}"),
    ("EnvKeep",          "Оставить это окружение? [Y/n]"),
    ("EnvSet",           "Окружение: {0}"),
    ("EnvBad",           "Неизвестное значение TSLAB_ENV: {0} (ожидается prod, staging или dev)."),
    ("UrlHint",          "Необязательные подмены адресов для отладки — Enter оставляет адреса выбранного окружения."),
    ("UrlIdentity",      "URL identity-сервера [{0}]"),
    ("UrlMarketplace",   "URL marketplace [{0}]"),
    ("UrlDefault",       "по умолчанию"),
    ("UrlBad",           "URL должен начинаться с http:// или https://"),
    ("UrlSet",           "Подмена адресов: {0}"),
    ("UrlNone",          "Подмена адресов: нет (адреса окружения)"),
    ("UrlWriteFail",     "Не удалось записать {0} — подмены не применены."),
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
    ("ScopeBlocked",     "Вход подтверждён, но на странице подтверждения TSVerse снято разрешение, без которого сервер работать не может, и вход не завершён. Снято:"),
    ("ScopeDegraded",    "Вход выполнен, но на странице подтверждения TSVerse часть разрешений снята. Снято:"),
    ("ScopeHint",        "Запустите установку ещё раз и оставьте на этой странице все галочки: «Offline Access» держит сессию после перезапуска, «shop api» открывает брокерские подключения, лицензии и подписки."),
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
# On an interactive console the installer asks where to keep the data, which TSVerse region to use
# (global / ru / us) and which environment (prod / staging / dev); it reuses the data folder of an
# existing container by default. On a non-production environment it also offers to redirect the
# identity and marketplace URLs, which is what debugging the /device* pages needs.
#
# Other variables (optional): $env:TSLAB_IMAGE, $env:TSLAB_NAME, $env:TSLAB_PORT,
#   $env:TSLAB_DATA_DIR, $env:TSLAB_REGION (global|ru|us), $env:TSLAB_ENV (prod|staging|dev),
#   $env:TSLAB_IDENTITY_URL, $env:TSLAB_MARKETPLACE_URL, $env:TSLAB_NONINTERACTIVE
# Any of them preset the answer and skip the matching question.
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
    EnvTitle         = 'TSVerse environment:'
    EnvOptProd       = '  1) prod    - production (default)'
    EnvOptStaging    = '  2) staging - staging'
    EnvOptDev        = '  3) dev     - development'
    EnvAsk           = 'Choose 1-3 [1]'
    EnvAskAgain      = 'Please enter 1, 2 or 3.'
    EnvCurrent       = 'This installation runs against the environment: {0}'
    EnvKeep          = 'Keep this environment? [Y/n]'
    EnvSet           = 'Environment: {0}'
    EnvBad           = 'Unknown TSLAB_ENV value: {0} (expected prod, staging or dev).'
    UrlHint          = 'Optional endpoint overrides for debugging - press Enter to use the defaults of the chosen environment.'
    UrlIdentity      = 'Identity server URL [{0}]'
    UrlMarketplace   = 'Marketplace URL [{0}]'
    UrlDefault       = 'default'
    UrlBad           = 'The URL has to start with http:// or https://'
    UrlSet           = 'Endpoint overrides: {0}'
    UrlNone          = 'Endpoint overrides: none (environment defaults)'
    UrlWriteFail     = 'Could not write {0} - the overrides are not applied.'
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
    ScopeBlocked     = 'The sign-in was confirmed, but a permission the server cannot work without was cleared on the TSVerse confirmation page, so the sign-in did not complete. Cleared:'
    ScopeDegraded    = 'Signed in, but some permissions were cleared on the TSVerse confirmation page. Cleared:'
    ScopeHint        = 'Run the installation again and leave every permission checked on that page: "Offline Access" keeps the session across restarts, "shop api" opens broker connections, licences and subscriptions.'
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

# The console picks its environment from TSLab__Environment (the image ships Production) and merges an
# optional /app/environment.json over the embedded endpoint catalog - only the listed properties are
# overridden, so a two-line file is enough to redirect identity or marketplace.
function ConvertTo-TSLabEnvironment([string]$Value) {
  if ([string]::IsNullOrWhiteSpace($Value)) { return '' }
  switch ($Value.Trim().ToLowerInvariant()) {
    'prod'        { return 'Production' }
    'production'  { return 'Production' }
    'stage'       { return 'Staging' }
    'staging'     { return 'Staging' }
    'dev'         { return 'Development' }
    'development' { return 'Development' }
    default       { return '' }
  }
}

function Read-TSLabEnvironment($L) {
  Write-Host $L.EnvTitle
  Write-Host $L.EnvOptProd
  Write-Host $L.EnvOptStaging
  Write-Host $L.EnvOptDev
  while ($true) {
    $a = (Read-Host -Prompt $L.EnvAsk)
    if ($null -eq $a) { $a = '' }
    switch -Regex ($a.Trim()) {
      '^(1|prod|production)?$' { return 'Production' }
      '^(2|stage|staging)$'    { return 'Staging' }
      '^(3|dev|development)$'  { return 'Development' }
      default { Write-Host $L.EnvAskAgain -ForegroundColor Yellow }
    }
  }
}

function Read-TSLabUrl([string]$Template, [string]$Current, $L) {
  while ($true) {
    $shown = if ([string]::IsNullOrWhiteSpace($Current)) { $L.UrlDefault } else { $Current }
    $a = Read-Host -Prompt ($Template -f $shown)
    if ($null -eq $a) { $a = '' }
    $a = $a.Trim()
    if ($a -eq '') { return $Current }
    if ($a -eq '-' -or $a -eq 'none') { return '' }
    if ($a -match '^https?://') { return $a }
    Write-Host $L.UrlBad -ForegroundColor Yellow
  }
}

function Get-TSLabOverride([string]$DataDir, [string]$Key) {
  $f = Join-Path $DataDir 'environment.override.json'
  if (-not (Test-Path $f)) { return '' }
  try {
    $m = Select-String -Path $f -Pattern ('"' + $Key + '"\s*:\s*"([^"]*)"') | Select-Object -First 1
    if ($m) { return $m.Matches[0].Groups[1].Value }
  } catch { }
  return ''
}

function Set-TSLabOverrides([string]$DataDir, [string]$EnvName, [string]$Region, [string]$Identity, [string]$Marketplace) {
  $nl = "`r`n"
  $body = "{$nl  ""environments"": {$nl    ""$EnvName"": {$nl      ""$Region"": {"
  $sep = ''
  if ($Identity)    { $body += "$nl        ""identityUrl"": ""$Identity"""; $sep = ',' }
  if ($Marketplace) { $body += "$sep$nl        ""marketplaceBaseUrl"": ""$Marketplace""" }
  $body += "$nl      }$nl    }$nl  }$nl}$nl"
  try {
    [System.IO.File]::WriteAllText((Join-Path $DataDir 'environment.override.json'), $body, (New-Object System.Text.UTF8Encoding($false)))
    return $true
  } catch { return $false }
}

function Remove-TSLabOverrides([string]$DataDir) {
  $f = Join-Path $DataDir 'environment.override.json'
  if (Test-Path $f) { try { Remove-Item -Force -Path $f } catch { } }
}

# The container reports a cleared consent permission in English (its whole log is). Pull out the
# checkbox names it lists - the user saw exactly those on the confirmation page - and frame them in the
# installer's language.
function Show-TSLabDeclinedScopes([string]$Logs, [bool]$Blocked, $L) {
  if ($Blocked) { Write-Host "!   $($L.ScopeBlocked)" -ForegroundColor Yellow }
  else { Write-Host "!   $($L.ScopeDegraded)" -ForegroundColor Yellow }
  $seen = @{}
  foreach ($m in [regex]::Matches($Logs, '-\s+"([^"]*)"')) {
    $name = $m.Groups[1].Value
    if (-not $seen.ContainsKey($name)) {
      $seen[$name] = $true
      Write-Host "        - $name" -ForegroundColor Yellow
    }
  }
  Write-Host "!   $($L.ScopeHint)" -ForegroundColor Yellow
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

  # --- wizard: TSVerse environment -------------------------------------------
  $currentEnv = ''
  try {
    $envLines = docker inspect -f '{{range .Config.Env}}{{println .}}{{end}}' $Name 2>$null
    if ($envLines) {
      $m = $envLines | Select-String -Pattern '^TSLab__Environment=(.*)$' | Select-Object -First 1
      if ($m) { $currentEnv = ConvertTo-TSLabEnvironment $m.Matches[0].Groups[1].Value }
    }
  } catch { }

  $EnvName = ConvertTo-TSLabEnvironment $env:TSLAB_ENV
  if ($env:TSLAB_ENV -and -not $EnvName) { Fail ($L.EnvBad -f $env:TSLAB_ENV); return }
  if (-not $EnvName) {
    if ($currentEnv -and $currentEnv -ne 'Production') {
      if (Test-TSLabInteractive) {
        Say ($L.EnvCurrent -f $currentEnv)
        if (Read-TSLabYesNo $L.EnvKeep) { $EnvName = $currentEnv } else { $EnvName = Read-TSLabEnvironment $L }
      }
      else { $EnvName = $currentEnv }
    }
    elseif (Test-TSLabInteractive) { $EnvName = Read-TSLabEnvironment $L }
    else { if ($currentEnv) { $EnvName = $currentEnv } else { $EnvName = 'Production' } }
  }
  Ok ($L.EnvSet -f $EnvName)

  # --- wizard: endpoint overrides (debugging, non-production only) ------------
  $IdentityUrl = $env:TSLAB_IDENTITY_URL
  $MarketplaceUrl = $env:TSLAB_MARKETPLACE_URL
  if (-not $IdentityUrl) { $IdentityUrl = Get-TSLabOverride $DataDir 'identityUrl' }
  if (-not $MarketplaceUrl) { $MarketplaceUrl = Get-TSLabOverride $DataDir 'marketplaceBaseUrl' }
  if ($EnvName -eq 'Production') {
    $IdentityUrl = ''
    $MarketplaceUrl = ''
  }
  elseif (-not $env:TSLAB_IDENTITY_URL -and -not $env:TSLAB_MARKETPLACE_URL -and (Test-TSLabInteractive)) {
    Say $L.UrlHint
    $IdentityUrl = Read-TSLabUrl $L.UrlIdentity $IdentityUrl $L
    $MarketplaceUrl = Read-TSLabUrl $L.UrlMarketplace $MarketplaceUrl $L
  }

  $OverrideFile = ''
  if ($IdentityUrl -or $MarketplaceUrl) {
    if (Set-TSLabOverrides $DataDir $EnvName $Region $IdentityUrl $MarketplaceUrl) {
      $OverrideFile = Join-Path $DataDir 'environment.override.json'
      $shownId = if ($IdentityUrl) { $IdentityUrl } else { '-' }
      $shownMk = if ($MarketplaceUrl) { $MarketplaceUrl } else { '-' }
      Ok ($L.UrlSet -f "$shownId $shownMk")
    }
    else { Warn ($L.UrlWriteFail -f (Join-Path $DataDir 'environment.override.json')) }
  }
  else {
    Remove-TSLabOverrides $DataDir
    Say $L.UrlNone
  }

  Say ($L.Pull -f $Image)
  docker pull $Image
  if ($LASTEXITCODE -ne 0) { Fail $L.PullFailed; return }

  Say ($L.Run -f $Name)
  docker rm -f $Name 2>$null | Out-Null
  $runArgs = @(
    'run', '-d', '--name', $Name, '--restart', 'unless-stopped',
    '-p', "127.0.0.1:${Port}:5000",
    '-e', 'TSLAB_PROFILE_PATH=/var/lib/tslab',
    '-e', "TSLab__Environment=$EnvName",
    '-v', "${DataDir}:/var/lib/tslab"
  )
  # The catalog override is merged over the embedded environment.json in the image working dir.
  if ($OverrideFile) { $runArgs += @('-v', "${OverrideFile}:/app/environment.json:ro") }
  $runArgs += $Image
  docker @runArgs | Out-Null
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
    $scopesBlocked = $false
    for ($i = 0; $i -lt 150; $i++) {
      $logs = (docker logs $Name 2>&1) -join "`n"
      if ($logs -match 'successfully connected to the notification system') { Ok $L.Connected; $success = $true; break }
      # A cleared required permission never resolves: the container just issues a fresh code every few
      # minutes. Stop and say so instead of waiting out the timeout and blaming the wrong thing.
      if ($logs -match 'sign-in could not be completed') { $scopesBlocked = $true; break }
      Start-Sleep 2
    }
    if ($scopesBlocked) {
      Show-TSLabDeclinedScopes $logs $true $L
    }
    elseif ($success) {
      if ($logs -match 'permissions were cleared on the confirmation page') {
        Show-TSLabDeclinedScopes $logs $false $L
      }
    }
    else { Warn ($L.ConfirmTimeout -f $Name) }
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
