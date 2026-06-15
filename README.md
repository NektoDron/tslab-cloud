# TSLab Cloud Server — установка на свой VPS

Поставьте торговый сервер **TSLab** на собственный Linux-сервер одной командой и подключите его
к своему аккаунту **TSCloud**. Без навыков системного администратора.

**Страница с инструкцией:** https://nektodron.github.io/tslab-cloud/

## Установка одной командой

**Linux / macOS:**
```bash
curl -fsSL https://nektodron.github.io/tslab-cloud/install.sh | bash
```

**Windows (PowerShell):**
```powershell
irm https://nektodron.github.io/tslab-cloud/install.ps1 | iex
```

Команда:
1. проверяет Docker и при необходимости ставит его (с подтверждением);
2. тянет публичный образ [`tslabdev/tslab-console`](https://hub.docker.com/r/tslabdev/tslab-console) и запускает контейнер;
3. хранит данные на хосте (`~/.local/share/tslab`) — переживают рестарт и обновление;
4. логинит инстанс в TSCloud по OAuth device flow (RFC 8628): код + QR печатаются в логи,
   подтверждение — с вашего телефона. Проброс портов и доступ к WebUI не требуются.

## Управление

```bash
docker logs -f tslab      # логи (и код входа в TSCloud)
docker restart tslab      # перезапуск (вход сохранится)
docker rm -f tslab        # удалить контейнер (данные останутся)
```

## Что внутри

| Файл | Назначение |
|------|------------|
| `docs/index.html` | Страница-инструкция (GitHub Pages) |
| `docs/install.sh` | Установщик для Linux / macOS |
| `docs/install.ps1` | Установщик для Windows (Docker Desktop) |

Образ собирается и публикуется отдельно (CI → Docker Hub `tslabdev/tslab-console`).
Этот репозиторий — только дистрибуция инструкции и установочных скриптов.
