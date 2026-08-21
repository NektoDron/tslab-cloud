# TSLab Console (headless) - installer for Windows (Docker Desktop).
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
    DockerMissing    = 'RG9ja2VyIERlc2t0b3Ag0L3QtSDQvdCw0LnQtNC10L0u'  # Docker Desktop не найден.
    WingetInstalling = '0KHRgtCw0LLQu9GOIERvY2tlciBEZXNrdG9wINGH0LXRgNC10Lcgd2luZ2V0ICjQvNC+0LbQtdGCINC30LDQv9GA0L7RgdC40YLRjCDQv9GA0LDQstCwINCw0LTQvNC40L3QuNGB0YLRgNCw0YLQvtGA0LAp4oCm'  # Ставлю Docker Desktop через winget (может запросить права администратора)…
    WingetDone       = 'RG9ja2VyIERlc2t0b3Ag0YPRgdGC0LDQvdC+0LLQu9C10L0gKNC40LvQuCDRg9GB0YLQsNC90L7QstC60LAg0LfQsNC/0YPRidC10L3QsCkuINCU0LDQu9GM0YjQtSDQvdGD0LbQvdC+INGB0LTQtdC70LDRgtGMINCy0YDRg9GH0L3Rg9GOIOKAlCDRjdGC0L4g0L7RgdC+0LHQtdC90L3QvtGB0YLRjCBXaW5kb3dzOg=='  # Docker Desktop установлен (или установка запущена). Дальше нужно сделать вручную — это особенность Windows:
    WingetStep1      = 'ICAgMSkg0J/QtdGA0LXQt9Cw0LPRgNGD0LfQuNGC0LUg0LrQvtC80L/RjNGO0YLQtdGALg=='  #    1) Перезагрузите компьютер.
    WingetStep2      = 'ICAgMikg0JfQsNC/0YPRgdGC0LjRgtC1IERvY2tlciBEZXNrdG9wINC4INC00L7QttC00LjRgtC10YHRjCDRgdGC0LDRgtGD0YHQsCAnRW5naW5lIHJ1bm5pbmcnICjQt9C90LDRh9C+0Lot0LrQuNGCINCyINGC0YDQtdC1KS4='  #    2) Запустите Docker Desktop и дождитесь статуса 'Engine running' (значок-кит в трее).
    WingetStep3      = 'ICAgMykg0KHQvdC+0LLQsCDQstGL0L/QvtC70L3QuNGC0LU6ICBpcm0gaHR0cHM6Ly9uZWt0b2Ryb24uZ2l0aHViLmlvL3RzbGFiLWNsb3VkL2luc3RhbGwucHMxIHwgaWV4'  #    3) Снова выполните:  irm https://nektodron.github.io/tslab-cloud/install.ps1 | iex
    WingetFallback   = 'ICAg0JXRgdC70Lggd2luZ2V0INC90LUg0YHQvNC+0LMg0YPRgdGC0LDQvdC+0LLQuNGC0Ywg4oCUINGB0LrQsNGH0LDQudGC0LUg0LLRgNGD0YfQvdGD0Y46IGh0dHBzOi8vd3d3LmRvY2tlci5jb20vcHJvZHVjdHMvZG9ja2VyLWRlc2t0b3Av'  #    Если winget не смог установить — скачайте вручную: https://www.docker.com/products/docker-desktop/
    NoWinget         = 'RG9ja2VyIERlc2t0b3Ag0L3QtSDQvdCw0LnQtNC10L0sINC4IHdpbmdldCDQsiDRgdC40YHRgtC10LzQtSDQvdC10LTQvtGB0YLRg9C/0LXQvS4g0KPRgdGC0LDQvdC+0LLQuNGC0LUgRG9ja2VyIERlc2t0b3Ag0LLRgNGD0YfQvdGD0Y46IGh0dHBzOi8vd3d3LmRvY2tlci5jb20vcHJvZHVjdHMvZG9ja2VyLWRlc2t0b3AvIOKAlCDQt9Cw0YLQtdC8INC30LDQv9GD0YHRgtC40YLQtSDQtdCz0L4gKNGB0YLQsNGC0YPRgSDCq0VuZ2luZSBydW5uaW5nwrspINC4INC/0L7QstGC0L7RgNC40YLQtSDQutC+0LzQsNC90LTRgy4='  # Docker Desktop не найден, и winget в системе недоступен. Установите Docker Desktop вручную: https://www.docker.com/products/docker-desktop/ — затем запустите его (статус «Engine running») и повторите команду.
    DockerNotRunning = 'RG9ja2VyIERlc2t0b3Ag0YPRgdGC0LDQvdC+0LLQu9C10L0sINC90L4g0L3QtSDQt9Cw0L/Rg9GJ0LXQvS4g0JfQsNC/0YPRgdGC0LjRgtC1IERvY2tlciBEZXNrdG9wICjQt9C90LDRh9C+0Lot0LrQuNGCINCyINGC0YDQtdC1KSwg0LTQvtC20LTQuNGC0LXRgdGMINGB0YLQsNGC0YPRgdCwIMKrRW5naW5lIHJ1bm5pbmfCuyDQuCDQv9C+0LLRgtC+0YDQuNGC0LUu'  # Docker Desktop установлен, но не запущен. Запустите Docker Desktop (значок-кит в трее), дождитесь статуса «Engine running» и повторите.
    DockerReady      = 'RG9ja2VyINCz0L7RgtC+0LIu'  # Docker готов.
    DataDir          = '0J/QsNC/0LrQsCDQtNCw0L3QvdGL0YUgKNC/0LXRgNC10LbQuNCy0LDQtdGCINC+0LHQvdC+0LLQu9C10L3QuNGPKTogezB9'  # Папка данных (переживает обновления): {0}
    Pull             = '0KLRj9C90YMg0L7QsdGA0LDQtzogezB9ICAo0LzQvtC20LXRgiDQt9Cw0L3Rj9GC0Ywg0L/QsNGA0YMg0LzQuNC90YPRginigKY='  # Тяну образ: {0}  (может занять пару минут)…
    DataFound        = '0J3QsNGI0ZHQuyDRgdGD0YnQtdGB0YLQstGD0Y7RidGD0Y4g0YPRgdGC0LDQvdC+0LLQutGDLiDQldGRINC00LDQvdC90YvQtSDQu9C10LbQsNGCINCyOiB7MH0='  # Нашёл существующую установку. Её данные лежат в: {0}
    DataKeep         = '0J7RgdGC0LDQstC40YLRjCDRjdGC0YMg0L/QsNC/0LrRgz8gW1kvbl0='  # Оставить эту папку? [Y/n]
    DataAsk          = '0J/QsNC/0LrQsCDQtNCw0L3QvdGL0YUgW3swfV0='  # Папка данных [{0}]
    DataAbsRequired  = '0JLQstC10LTQuNGC0LUg0LDQsdGB0L7Qu9GO0YLQvdGL0Lkg0L/Rg9GC0YwsINC90LDQv9GA0LjQvNC10YAgQzpcVXNlcnNcVXNlclx0c2xhYg=='  # Введите абсолютный путь, например C:\Users\User\tslab
    DataMkdirFail    = '0J3QtSDRg9C00LDQu9C+0YHRjCDRgdC+0LfQtNCw0YLRjCDQv9Cw0L/QutGDOiB7MH0='  # Не удалось создать папку: {0}
    DataNewWarn      = '0JTRgNGD0LPQsNGPINC/0LDQv9C60LAg4oCUINGN0YLQviDRh9C40YHRgtGL0Lkg0YHRgtCw0YDRgjog0YHRgtCw0YDRi9C1INC00LDQvdC90YvQtSDQvtGB0YLQsNC90YPRgtGB0Y8g0L3QsCDQtNC40YHQutC1LCDQvdC+INC90L7QstGL0Lkg0LjQvdGB0YLQsNC90YEg0YHQvdC+0LLQsCDQv9C+0L/RgNC+0YHQuNGCINCy0YXQvtC0INCyIFRTVmVyc2Uu'  # Другая папка — это чистый старт: старые данные останутся на диске, но новый инстанс снова попросит вход в TSVerse.
    DataReusedAuto   = '0J3QtdC40L3RgtC10YDQsNC60YLQuNCy0L3Ri9C5INC30LDQv9GD0YHQuiDigJQg0LHQtdGA0YMg0L/QsNC/0LrRgyDQtNCw0L3QvdGL0YUg0YHRg9GJ0LXRgdGC0LLRg9GO0YnQtdCz0L4g0LrQvtC90YLQtdC50L3QtdGA0LA6IHswfQ=='  # Неинтерактивный запуск — беру папку данных существующего контейнера: {0}
    RegionTitle      = '0KDQtdCz0LjQvtC9IFRTVmVyc2U6'  # Регион TSVerse:
    RegionOptGlobal  = 'ICAxKSBnbG9iYWwg4oCUIHRzdmVyc2UucHJvICjQv9C+INGD0LzQvtC70YfQsNC90LjRjik='  #   1) global — tsverse.pro (по умолчанию)
    RegionOptRu      = 'ICAyKSBydSAgICAg4oCUIHRzdmVyc2UucnU='  #   2) ru     — tsverse.ru
    RegionOptUs      = 'ICAzKSB1cyAgICAg4oCUIHRzdmVyc2UudXM='  #   3) us     — tsverse.us
    RegionAsk        = '0JLRi9Cx0LXRgNC40YLQtSAxLTMgWzFd'  # Выберите 1-3 [1]
    RegionAskAgain   = '0JLQstC10LTQuNGC0LUgMSwgMiDQuNC70LggMy4='  # Введите 1, 2 или 3.
    RegionCurrent    = '0K3RgtCwINGD0YHRgtCw0L3QvtCy0LrQsCDQvdCw0YHRgtGA0L7QtdC90LAg0L3QsCDRgNC10LPQuNC+0L0gVFNWZXJzZTogezB9'  # Эта установка настроена на регион TSVerse: {0}
    RegionKeep       = '0J7RgdGC0LDQstC40YLRjCDRjdGC0L7RgiDRgNC10LPQuNC+0L0/IFtZL25d'  # Оставить этот регион? [Y/n]
    RegionChangeWarn = '0JTRgNGD0LPQvtC5INGA0LXQs9C40L7QvSDigJQg0Y3RgtC+INC+0YLQtNC10LvRjNC90L7QtSDQv9GA0L7RgdGC0YDQsNC90YHRgtCy0L4g0LDQutC60LDRg9C90YLQvtCyIFRTVmVyc2U6INC40L3RgdGC0LDQvdGBINC/0L7Qv9GA0L7RgdC40YIg0L3QvtCy0YvQuSDQstGF0L7QtC4='  # Другой регион — это отдельное пространство аккаунтов TSVerse: инстанс попросит новый вход.
    RegionSet        = '0KDQtdCz0LjQvtC9IFRTVmVyc2U6IHswfQ=='  # Регион TSVerse: {0}
    RegionBad        = '0J3QtdC40LfQstC10YHRgtC90L7QtSDQt9C90LDRh9C10L3QuNC1IFRTTEFCX1JFR0lPTjogezB9ICjQvtC20LjQtNCw0LXRgtGB0Y8gZ2xvYmFsLCBydSDQuNC70LggdXMpLg=='  # Неизвестное значение TSLAB_REGION: {0} (ожидается global, ru или us).
    RegionWriteFail  = '0J3QtSDRg9C00LDQu9C+0YHRjCDQt9Cw0L/QuNGB0LDRgtGMIHswfSDigJQg0YDQtdCz0LjQvtC9INC+0YHRgtCw0LvRgdGPINC/0YDQtdC20L3QuNC8Lg=='  # Не удалось записать {0} — регион остался прежним.
    EnvTitle         = '0J7QutGA0YPQttC10L3QuNC1IFRTVmVyc2U6'  # Окружение TSVerse:
    EnvOptProd       = 'ICAxKSBwcm9kICAgIOKAlCDQsdC+0LXQstC+0LUgKNC/0L4g0YPQvNC+0LvRh9Cw0L3QuNGOKQ=='  #   1) prod    — боевое (по умолчанию)
    EnvOptStaging    = 'ICAyKSBzdGFnaW5nIOKAlCDQv9GA0LXQtNC/0YDQvtC0'  #   2) staging — предпрод
    EnvOptDev        = 'ICAzKSBkZXYgICAgIOKAlCDRgNCw0LfRgNCw0LHQvtGC0LrQsA=='  #   3) dev     — разработка
    EnvAsk           = '0JLRi9Cx0LXRgNC40YLQtSAxLTMgWzFd'  # Выберите 1-3 [1]
    EnvAskAgain      = '0JLQstC10LTQuNGC0LUgMSwgMiDQuNC70LggMy4='  # Введите 1, 2 или 3.
    EnvCurrent       = '0K3RgtCwINGD0YHRgtCw0L3QvtCy0LrQsCDRgNCw0LHQvtGC0LDQtdGCINGBINC+0LrRgNGD0LbQtdC90LjQtdC8OiB7MH0='  # Эта установка работает с окружением: {0}
    EnvKeep          = '0J7RgdGC0LDQstC40YLRjCDRjdGC0L4g0L7QutGA0YPQttC10L3QuNC1PyBbWS9uXQ=='  # Оставить это окружение? [Y/n]
    EnvSet           = '0J7QutGA0YPQttC10L3QuNC1OiB7MH0='  # Окружение: {0}
    EnvBad           = '0J3QtdC40LfQstC10YHRgtC90L7QtSDQt9C90LDRh9C10L3QuNC1IFRTTEFCX0VOVjogezB9ICjQvtC20LjQtNCw0LXRgtGB0Y8gcHJvZCwgc3RhZ2luZyDQuNC70LggZGV2KS4='  # Неизвестное значение TSLAB_ENV: {0} (ожидается prod, staging или dev).
    UrlHint          = '0J3QtdC+0LHRj9C30LDRgtC10LvRjNC90YvQtSDQv9C+0LTQvNC10L3RiyDQsNC00YDQtdGB0L7QsiDQtNC70Y8g0L7RgtC70LDQtNC60Lgg4oCUIEVudGVyINC+0YHRgtCw0LLQu9GP0LXRgiDQsNC00YDQtdGB0LAg0LLRi9Cx0YDQsNC90L3QvtCz0L4g0L7QutGA0YPQttC10L3QuNGPLg=='  # Необязательные подмены адресов для отладки — Enter оставляет адреса выбранного окружения.
    UrlIdentity      = 'VVJMIGlkZW50aXR5LdGB0LXRgNCy0LXRgNCwIFt7MH1d'  # URL identity-сервера [{0}]
    UrlMarketplace   = 'VVJMIG1hcmtldHBsYWNlIFt7MH1d'  # URL marketplace [{0}]
    UrlDefault       = '0L/QviDRg9C80L7Qu9GH0LDQvdC40Y4='  # по умолчанию
    UrlBad           = 'VVJMINC00L7Qu9C20LXQvSDQvdCw0YfQuNC90LDRgtGM0YHRjyDRgSBodHRwOi8vINC40LvQuCBodHRwczovLw=='  # URL должен начинаться с http:// или https://
    UrlSet           = '0J/QvtC00LzQtdC90LAg0LDQtNGA0LXRgdC+0LI6IHswfQ=='  # Подмена адресов: {0}
    UrlNone          = '0J/QvtC00LzQtdC90LAg0LDQtNGA0LXRgdC+0LI6INC90LXRgiAo0LDQtNGA0LXRgdCwINC+0LrRgNGD0LbQtdC90LjRjyk='  # Подмена адресов: нет (адреса окружения)
    UrlWriteFail     = '0J3QtSDRg9C00LDQu9C+0YHRjCDQt9Cw0L/QuNGB0LDRgtGMIHswfSDigJQg0L/QvtC00LzQtdC90Ysg0L3QtSDQv9GA0LjQvNC10L3QtdC90Ysu'  # Не удалось записать {0} — подмены не применены.
    PullFailed       = '0J3QtSDRg9C00LDQu9C+0YHRjCDRgdC60LDRh9Cw0YLRjCDQvtCx0YDQsNC3LiDQn9GA0L7QstC10YDRjNGC0LUg0LjQvdGC0LXRgNC90LXRgiDQuCDRh9GC0L4gRG9ja2VyINC30LDQv9GD0YnQtdC9LCDQt9Cw0YLQtdC8INC/0L7QstGC0L7RgNC40YLQtS4='  # Не удалось скачать образ. Проверьте интернет и что Docker запущен, затем повторите.
    Run              = 'KNCf0LXRgNC1KdC30LDQv9GD0YHQutCw0Y4g0LrQvtC90YLQtdC50L3QtdGAOiB7MH0='  # (Пере)запускаю контейнер: {0}
    RunFailed        = '0J3QtSDRg9C00LDQu9C+0YHRjCDQt9Cw0L/Rg9GB0YLQuNGC0Ywg0LrQvtC90YLQtdC50L3QtdGALiDQn9C+0LTRgNC+0LHQvdC+0YHRgtC4OiBkb2NrZXIgbG9ncyB7MH0='  # Не удалось запустить контейнер. Подробности: docker logs {0}
    Started          = '0JrQvtC90YLQtdC50L3QtdGAINC30LDQv9GD0YnQtdC9IChXZWJVSSDRgtC+0LvRjNC60L4g0L3QsCBsb29wYmFjazogaHR0cDovL2xvY2FsaG9zdDp7MH0vKS4='  # Контейнер запущен (WebUI только на loopback: http://localhost:{0}/).
    WaitWebUi        = '0JbQtNGDINC30LDQv9GD0YHQuiBXZWJVSeKApg=='  # Жду запуск WebUI…
    CheckLogin       = '0J/RgNC+0LLQtdGA0Y/RjiDQstGF0L7QtCDQsiBUU1ZlcnNlICjQutC+0LQg0L/QvtGP0LLQu9GP0LXRgtGB0Y8g0YfQtdGA0LXQtyB+MzDigJM2MCDRgdC10Lop4oCm'  # Проверяю вход в TSVerse (код появляется через ~30–60 сек)…
    SessionRestored  = '0KHQtdGB0YHQuNGPIFRTVmVyc2Ug0LLQvtGB0YHRgtCw0L3QvtCy0LvQtdC90LAg4oCUINC/0L7QstGC0L7RgNC90YvQuSDQstGF0L7QtCDQvdC1INC90YPQttC10L0u'  # Сессия TSVerse восстановлена — повторный вход не нужен.
    LoginTitle       = 'ICDQktGF0L7QtCDQsiBUU1ZlcnNl'  #   Вход в TSVerse
    LoginStep1       = 'ICAxKSDQntGC0LrRgNC+0LnRgtC1OiB7MH0='  #   1) Откройте: {0}
    LoginStep2       = 'ICAyKSDQmtC+0LQ6ICAgICAgezB9'  #   2) Код:      {0}
    LoginQr          = 'ICAo0LjQu9C4INC+0YLRgdC60LDQvdC40YDRg9C50YLQtSBRUiDQvdC40LbQtSk='  #   (или отсканируйте QR ниже)
    WaitConfirm      = '0JbQtNGDINC/0L7QtNGC0LLQtdGA0LbQtNC10L3QuNGPINC90LAg0LLQsNGI0LXQvCDRg9GB0YLRgNC+0LnRgdGC0LLQtSAo0LTQviA1INC80LjQvdGD0YIp4oCm'  # Жду подтверждения на вашем устройстве (до 5 минут)…
    Connected        = '0J/QvtC00LrQu9GO0YfQtdC90L4g0LogVFNWZXJzZS4='  # Подключено к TSVerse.
    ConfirmTimeout   = '0J/QvtC00YLQstC10YDQttC00LXQvdC40LUg0L3QtSDQv9C+0LvRg9GH0LXQvdC+INC30LAg0L7RgtCy0LXQtNGR0L3QvdC+0LUg0LLRgNC10LzRjy4g0J7RgtC60YDQvtC50YLQtSDQu9C+0LPQuCDQuCDQt9Cw0LLQtdGA0YjQuNGC0LUg0LLRhdC+0LQ6IGRvY2tlciBsb2dzIC1mIHswfQ=='  # Подтверждение не получено за отведённое время. Откройте логи и завершите вход: docker logs -f {0}
    NoCodeYet        = '0JrQvtC0INCy0YXQvtC00LAg0L/QvtC60LAg0L3QtSDQv9C+0Y/QstC40LvRgdGPLiDQn9C+0YHQvNC+0YLRgNC40YLQtSDQu9C+0LPQuCAo0LTQvtC20LTQuNGC0LXRgdGMINCx0LvQvtC60LAg0YEgUVIpOiBkb2NrZXIgbG9ncyAtZiB7MH0='  # Код входа пока не появился. Посмотрите логи (дождитесь блока с QR): docker logs -f {0}
    DoneOk           = '0JPQvtGC0L7QstC+LiBUU0xhYiDRg9GB0YLQsNC90L7QstC70LXQvSDQuCDQv9C+0LTQutC70Y7Rh9GR0L0g0LogVFNWZXJzZS4='  # Готово. TSLab установлен и подключён к TSVerse.
    DonePartial      = 'VFNMYWIg0YPRgdGC0LDQvdC+0LLQu9C10L0g0Lgg0LfQsNC/0YPRidC10L0uINCX0LDQstC10YDRiNC40YLQtSDQstGF0L7QtCDQv9C+INC40L3RgdGC0YDRg9C60YbQuNC4INCy0YvRiNC1Lg=='  # TSLab установлен и запущен. Завершите вход по инструкции выше.
    Unexpected       = '0J3QtdC/0YDQtdC00LLQuNC00LXQvdC90LDRjyDQvtGI0LjQsdC60LA6IHswfQ=='  # Непредвиденная ошибка: {0}
    WindowStaysOpen  = 'KNCe0LrQvdC+IFBvd2VyU2hlbGwg0L7RgdGC0LDRkdGC0YHRjyDQvtGC0LrRgNGL0YLRi9C8IOKAlCDQstGL0LLQvtC0INCy0YvRiNC1INC80L7QttC90L4g0L/RgNC+0YfQuNGC0LDRgtGMLik='  # (Окно PowerShell остаётся открытым — вывод выше можно прочитать.)
    FooterManage     = '0KPQv9GA0LDQstC70LXQvdC40LU6'  # Управление:
    FooterLogs       = '0LvQvtCz0LggKNC4INC60L7QtCDQstGF0L7QtNCwKQ=='  # логи (и код входа)
    FooterRestart    = '0L/QtdGA0LXQt9Cw0L/Rg9GB0LogKNGB0LXRgdGB0LjRjyDQstC+0YHRgdGC0LDQvdC+0LLQuNGC0YHRjyk='  # перезапуск (сессия восстановится)
    FooterRemove     = '0YPQtNCw0LvQuNGC0Ywg0LrQvtC90YLQtdC50L3QtdGAICjQtNCw0L3QvdGL0LUg0LIgezB9INC+0YHRgtCw0L3Rg9GC0YHRjyk='  # удалить контейнер (данные в {0} останутся)
    FooterUpdate     = '0J7QsdC90L7QstC70LXQvdC40LU6'  # Обновление:
    FooterPanel      = '0JLQtdCxLdC/0LDQvdC10LvRjCDRg9C/0YDQsNCy0LvQtdC90LjRjzo='  # Веб-панель управления:
    FooterData       = '0JTQsNC90L3Ri9C1Og=='  # Данные:
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
