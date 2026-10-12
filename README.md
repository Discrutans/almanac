# Almanac

Flutter-календарь с локальным SQLite snapshot и опциональным self-hosted FastAPI (сессии, sync, deep links).

**Без логина и регистрации.** Данные живут в профилях на устройстве. Сеть подключается вручную: Server URL + API Key + Profile ID.

## Системные требования

| Компонент | Требование |
|-----------|------------|
| Клиент | [Flutter](https://docs.flutter.dev/get-started/install) с Dart SDK **^3.10.7** |
| ОС разработки | Windows, macOS или Linux; Android/iOS SDK для мобильной сборки |
| Сервер (опционально) | Python **3.11+** или Docker; порт **8080** по умолчанию |
| Лабораторная сеть | пример origin `http://192.168.10.100:8080` |

## Локальный запуск клиента

```bash
flutter pub get
flutter run
```

Горячая перезагрузка UI на Windows: клавиша **`r`** в терминале `flutter run`. Если не подхватились новые типы/поля — **`R`**. На телефоне нужен новый APK.

Release APK подписывается ключом из `android/key.properties` + `android/keystore/almanac-upload.jks` (оба в `.gitignore`). Шаблон: `android/key.properties.example`. Без этих файлов Gradle возьмёт debug-ключ.

Пустой релиз (без demo-данных, с обфускацией):

```powershell
.\scripts\build_release_empty.ps1
```

Флаги: `--obfuscate --split-debug-info=build/debug-info`. Каталог символов нужен, чтобы расшифровать stack traces. HTTP cleartext разрешён только в debug/profile (LAN/home-lab); release требует HTTPS.

Тесты:

```bash
flutter test
```

На Windows, если `flutter test` ругается на `PROGRAMFILES(X86)`:

```bat
cmd.exe /c "set \"PROGRAMFILES(X86)=C:\Program Files (x86)\" && flutter test"
```

## Переменные окружения (dart-define)

Передаются в `flutter run` / `flutter build`:

```bash
flutter run --dart-define=SERVER_URL=http://192.168.10.100:8080
```

| Имя | По умолчанию | Назначение |
|-----|--------------|------------|
| `SERVER_URL` | пусто | запасной адрес API |
| `ENABLE_REMOTE_SYNC` | `false` | snapshot-sync с сервером |
| `ENABLE_AUTO_REMOTE_SYNC` | `true` | фоновый push после локальных правок |
| `PUSH_DEVICE_TOKEN` | пусто | FCM token устройства |
| `SEED_DEMO_DATA` | `false` | demo-события при пустой БД |

В приложении URL задаётся в **Профили → Ссылки и API** и перекрывает `SERVER_URL`.

Код: `lib/core/config/app_config.dart`.

## Сервер

Подробно: [docs/self-hosted.md](docs/self-hosted.md), [docs/platform-api.md](docs/platform-api.md).

```bash
cd server
docker compose -f docker-compose.sqlite.yml up --build
```

Или без Docker (Windows): `server/scripts/run_sqlite.ps1`.

Домашняя лаборатория совместного планирования: `server/scripts/AlmanacHomeLab.bat` (инструкция рядом: [AlmanacHomeLab.md](server/scripts/AlmanacHomeLab.md)) → [http://127.0.0.1:8080/lab/plan](http://127.0.0.1:8080/lab/plan). Подключение телефона через WireGuard: `/lab`.

Переменные сервера — `server/.env.example` (`ALMANAC_HOST`, `ALMANAC_PORT`, `ALMANAC_PUBLIC_ORIGIN`, `ALMANAC_DB_BACKEND`, …).

Маршруты клиента: `/` календарь, `/session/:token` сессия; `/join`, `/book`, `/plan` редиректят на сессию.

## Документация

- **[docs/README.md](docs/README.md)** — **оглавление** всей базы знаний (с чего начать)
- **[docs/project-guide.md](docs/project-guide.md)** — обзор приложения (экраны, UI, функции; сверено с кодом)
- [docs/audit-report.md](docs/audit-report.md) — audit doc↔code, UI surfaces, UX debt
- [docs/architecture.md](docs/architecture.md) — стек, папки, поток данных
- [docs/features.md](docs/features.md) — детальный **реестр функций** (модули; см. project-guide §11)
- [docs/week-ui.md](docs/week-ui.md) — spec недельного вида для разработчиков
- [docs/perf-scroll.md](docs/perf-scroll.md) — скролл и UI под 90/120/144 Гц
- [docs/self-hosted.md](docs/self-hosted.md) — Server URL и хостинг
- [docs/platform-api.md](docs/platform-api.md) — REST / WebSocket (справочник API)
- [docs/infoDB.md](docs/infoDB.md) — данные и API (кратко)
- [docs/app-links.md](docs/app-links.md) — Android / iOS deep links
- [docs/qa-checklist.md](docs/qa-checklist.md) — ручной QA
- [TODO.md](TODO.md) — статус платформенного чеклиста

## Структура (кратко)

| Путь | Назначение |
|------|------------|
| `lib/main.dart` | Точка входа |
| `lib/app/` | `AlmanacApp` |
| `lib/core/` | theme, ui, localization, config, router |
| `lib/calendar/`, `sessions/`, `finance/`, `schedules/`, `profiles/` | UI и домены |
| `lib/data/`, `lib/platform/`, `lib/state/` | persistence, API, Riverpod |
| `server/` | FastAPI: REST, WebSocket, SQLite/YDB |
| `docs/` | архитектура, реестр функций, API, QA |
