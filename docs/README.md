# Документация Almanac

Единая база знаний проекта. **Начните здесь**, затем переходите по ссылкам.

| Кому | С чего начать |
|------|----------------|
| Продукт, новый участник команды | [project-guide.md](project-guide.md) — экраны, UI, функции |
| Разработчик клиента | [project-guide.md](project-guide.md) §10 + [architecture.md](architecture.md) |
| Backend / self-hosted | [self-hosted.md](self-hosted.md) → [platform-api.md](platform-api.md) |
| QA перед релизом | [qa-checklist.md](qa-checklist.md) |
| Аудит и расхождения doc↔code | [audit-report.md](audit-report.md) |

**Последнее обновление hub:** 2026-10-01.

---

## Оглавление файлов

### Обзор и аудит

| Файл | Назначение |
|------|------------|
| [project-guide.md](project-guide.md) | Главный обзор приложения (клиент), проверенный по коду |
| [audit-report.md](audit-report.md) | Audit doc↔code, UI surfaces, UX debt |
| [ux-rework-baseline.md](ux-rework-baseline.md) | UX rework journeys, matrices, phase log |

### Клиент

| Файл | Назначение |
|------|------------|
| [architecture.md](architecture.md) | Стек, `lib/`, поток данных, профили, SQLite |
| [features.md](features.md) | Реестр функций с путями к модулям |
| [week-ui.md](week-ui.md) | Spec недельного вида (wide / carousel) |
| [perf-scroll.md](perf-scroll.md) | Высокая частота кадров, scroll |
| [app-links.md](app-links.md) | Deep links Android / iOS |

### Сервер и данные

| Файл | Назначение |
|------|------------|
| [self-hosted.md](self-hosted.md) | Развёртывание FastAPI (Docker, LAN) |
| [platform-api.md](platform-api.md) | REST `/v1`, WebSocket сессий |
| [inbox-unified-api-note.md](inbox-unified-api-note.md) | Optional future unified inbox API |

### Процессы

| Файл | Назначение |
|------|------------|
| [qa-checklist.md](qa-checklist.md) | Ручная проверка self-hosted и UI |

### Вне `docs/`

| Файл | Назначение |
|------|------------|
| [../README.md](../README.md) | Сборка, `flutter run`, dart-define |
| [../server/scripts/AlmanacHomeLab.md](../server/scripts/AlmanacHomeLab.md) | Домашняя лаборатория |
| [../TODO.md](../TODO.md) | Платформенный чеклист |

---

## Правила актуальности

1. **Источник истины** — код (`lib/`, `server/`), не устаревшие абзацы в secondary docs.
2. При расхождении: обновить файл или зафиксировать в [audit-report.md](audit-report.md) и [project-guide.md §11](project-guide.md#11-актуальность-документации).
3. Обзор продукта не дублировать в `features.md` — только детальный реестр.
