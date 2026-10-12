# Реестр функций Almanac

> При расхождении с кодом: [project-guide.md §11](project-guide.md#11-актуальность-документации), [audit-report.md](audit-report.md).

Перечень возможностей клиента и опционального self-hosted API.  
**Входа по логину/паролю нет:** идентификация — локальный профиль + (для сети) Server URL, API Key и Profile ID.

Права зависят от [типа и роли профиля](architecture.md#профили-и-доступ).

## 1. Профили и доступ

| Функция | Назначение | Вход | Результат | Модуль |
|---------|------------|------|-----------|--------|
| Создать профиль | Новое изолированное рабочее пространство | Имя, тип: `personal` / `collaborative` / `booking` | `ContextProfile` (id, kind, role=`owner`) | `lib/profiles/create_profile_sheet.dart` |
| Подключиться к чужому | Войти как участник чужого календаря | Server URL, API Key, Profile ID владельца | Профиль с `role=member` | `CreateProfileSheet` (`_join`) |
| Переключить профиль | Сменить активный контекст | `profileId` | Активный профиль, свои события и настройки | `lib/profiles/profile_switcher.dart` |
| Права профиля | Единая матрица действий | `ProfileKind` + `ProfileRole` | `ProfileAccess` (создание/правка событий, слоты, inbox, sync) | `lib/data/profiles/profile_kind.dart` |
| Удалить / переименовать | Управление списком профилей | `profileId`, новое имя | Данные профиля удаляются из snapshot | `lib/profiles/profile_manager_sheet.dart` |

Типы:

- **personal** — только это устройство, сервер не нужен.
- **collaborative** — общий календарь; блокировки событий на сервере.
- **booking** — владелец правит слоты; участник только записывается.

## 2. Календарь и навигация

| Функция | Назначение | Вход | Результат | Модуль |
|---------|------------|------|-----------|--------|
| Месяц | Сетка месяца, метки дней, статистика | Выбранная дата, видимые профили | Сетка + чипы статистики (скрываются при низкой высоте) | `lib/calendar/views/month_view.dart` |
| Неделя | Wide 7д / карусель 3д, сетка, слот, DnD, hideEmpty, pinch | Дата, события диапазона | Паритет режимов, см. [week-ui.md](week-ui.md) | `lib/calendar/views/week_view.dart` |
| Повестка | Список по дням | Дата, фильтры | Секции дней | `lib/calendar/views/agenda_view.dart` |
| Год | Мини-календари 12 месяцев | Год | Выбор месяца/дня | `lib/calendar/views/year_view.dart` |
| Выбор даты | Переход «сегодня», long-press | `DateTime` | Смена `CalendarMode` / лист дня | `lib/calendar/calendar_screen.dart` |
| Фильтр видимости | Какие профили показывать | Набор `profileId` | Объединённый список записей | `lib/state/calendar_filter_providers.dart` |
| Создать запись | Нижняя кнопка «+» | Режим календаря, права | Форма события / заметки / чек-листа | `CalendarCreateBar` |

## 3. Записи календаря

Виды: `event`, `note`, `checklist`, `savingsGoal`.  
Источники: личные, бронь, слот брони, сгенерированная смена, override смены, проекция цели, гостевой ICS.

| Функция | Назначение | Вход | Результат | Модуль |
|---------|------------|------|-----------|--------|
| Создать / править запись | CRUD timed-события, заметки, чек-листа | Заголовок, время, цвет, заметки, чек-лист, вложения, RRULE, финансы, pomodoro | Сохранённый `AppEvent` в SQLite snapshot | `EventEntryFormBody`, `EventRepository` |
| Удалить / свайп | Удаление с учётом прав и источника | `eventId`, `EntryCapabilities` | Запись исчезает; для RRULE — исключение дня | `calendar_entry_capabilities.dart` |
| Повторения | Серия по RRULE | `rrule`, `recurrenceUntil`, исключения | Развёрнутые вхождения в диапазоне | `calendar_entry_expander.dart`, пакет `rrule` |
| Вложения заметки | Фото и файлы | `image_picker` / `file_picker` | `NoteAttachment` + открытие `open_filex` | `note_attachments_section.dart` |
| Быстрые шаблоны | Повтор часто используемых полей | Профиль | Список шаблонов в форме | `event_quick_templates_bar.dart` |
| Предпросмотр | Карточка без полного редактора | `AppEvent` | Sheet с действиями | `event_preview_sheet.dart` |
| Перенос в неделе | Drag timed-события | Новая дата/время | Preview + commit через `WeekMoveController` (если `canDragInWeekView`) | `WeekTimedDragLayer`, `week_move_controller.dart`, `week_carousel_unified.dart`, `week_events_drop_grid.dart` |

Гость booking (`canBookOnly`) не создаёт и не правит чужие события — только запись на слот.

## 4. Рабочие расписания и оплата

| Функция | Назначение | Вход | Результат | Модуль |
|---------|------------|------|-----------|--------|
| Цикл RRULE | Повторяющиеся смены (дни недели) | Заголовок, время, `FREQ=WEEKLY;BYDAY=…` | Виртуальные дни `scheduleGenerated` | `CyclicWorkScheduleRepository` |
| Сменный цикл | N рабочих / M выходных | Пресеты 2/2, 1/3, 3/3, 5/2, 2/5 или свои числа, дата старта | Сгенерированные смены | `CyclicScheduleKind.shiftCycle` |
| Override дня | Разово изменить/пропустить смену | `scheduleId`, дата, overtime/unpaid | `scheduleOverride` | `EventRepository.upsertScheduleOverride` |
| Расчёт оплаты | Зарплата за месяц | Ставка hourly/daily/monthly, overtime, НДС, бонус | `WorkPaySummary` в статистике месяца | `lib/finance/pay_types.dart` |
| Быстрые действия смены | Пропуск, сверхурочные | Событие смены | Обновлённый override | `shift_quick_actions.dart` |

## 5. Финансы и цели накопления

| Функция | Назначение | Вход | Результат | Модуль |
|---------|------------|------|-----------|--------|
| Доход в событии | Учёт поступления / подарка | Сумма, флаг «подарок» | Поля в `EventFinanceState`, статистика месяца | `event_finance_fields.dart` |
| Цель накопления | План суммы к дате | Название, сумма, дата, уже накоплено, ежемесячные траты | `SavingsGoal` + проекции на календарь | `lib/finance/savings_goals_sheet.dart` |
| Проекция цели | Показать цель как записи календаря | Цель + диапазон дат | Эфемерные `savingsGoalProjected` | `savings_goal_calendar_projection.dart` |

## 6. Pomodoro

| Функция | Назначение | Вход | Результат | Модуль |
|---------|------------|------|-----------|--------|
| Таймер события | Работа/перерыв, привязанные к записи | Work/break минуты, состояние сессии | Обновлённый `EventPomodoroState` | `lib/pomodoro/pomodoro_timer_sheet.dart` |
| Индикатор | Показать активный таймер | Текущая сессия | Чип на календаре | `pomodoro_live_indicator.dart` |

Недоступен для слотов брони и гостевых ICS (`EntryCapabilities.canSetPomodoro`).

## 7. Сессии записи (booking)

Сервер обязателен для удалённой сессии. Локальные шаблоны остаются для offline.

| Функция | Назначение | Вход | Результат | Модуль |
|---------|------------|------|-----------|--------|
| Создать сессию записи | Слоты + форма для гостя | Профиль, дни, длительность, `SessionFormField` (text/phone/select) | Сессия на сервере, deep link в буфере | `create_booking_session_sheet.dart` |
| Генерация слотов | Нарезать окна по дням | Даты, шаг, рабочие часы | `List<SessionSlot>` | `booking_slot_generator.dart` |
| Записаться | Гость выбирает слот и заполняет форму | Token, `slotId`, ответы формы | `SessionBookingRequest` (`pending`) | `session_page.dart` |
| Проекция слотов | Слоты владельца на календаре участника | Открытые сессии | Эфемерные `bookingSlot` | `booking_slot_calendar_projection.dart` |
| Подтвердить / отклонить | Владелец обрабатывает заявку | `requestId`, `confirmed` / `rejected` | Событие в календаре или отказ | Inbox + PATCH `/v1/sessions/:token/requests/:id` |
| Закрыть сессию | Владелец завершает набор | Token | `SessionStatus.closed` | AppBar сессии, «Ссылки и API» |

## 8. Совместное планирование (collaborative)

| Функция | Назначение | Вход | Результат | Модуль |
|---------|------------|------|-----------|--------|
| Создать сессию плана | Общие слоты команды | Заголовок, слоты | Сессия `mode=collaborative` + ссылка | `session_creation_service.dart` |
| Real-time | Живое состояние сессии | WebSocket `/v1/ws/sessions/:token` | Слоты и участники без перезагрузки | `session_websocket_client.dart` |
| Имя гостя | Подпись в списке участников | Строка имени | Отображается у остальных | `session_page.dart` |
| Блокировка события | Эксклюзивное редактирование | `eventId`, device id | 200 (lock) или 409 | `event_lock_service.dart` |
| Правка слотов | Только владелец | Слот | PATCH сессии (API key владельца) | `session_page_panels.dart` |

## 9. Inbox заявок

| Функция | Назначение | Вход | Результат | Модуль |
|---------|------------|------|-----------|--------|
| Удалённые pending | Заявки с сервера | API key, опрос **~10 с** | Список на подтверждение | `remote_session_pending_panel.dart`, `platform_bootstrap.dart` |
| Локальные pending | Offline-шаблоны брони | `BookingRepository.getPendingRequests` | Локальные заявки | `legacy_local_pending_panel.dart` |
| Badge inbox | Напомнить владельцу booking | Число pending | Иконка на календаре | `session_pending_providers.dart` |

## 10. Синхронизация и платформа

Авторизации пользователя нет. Доступ к API: заголовки `X-Api-Key`, `X-Profile-Id`.

| Функция | Назначение | Вход | Результат | Модуль |
|---------|------------|------|-----------|--------|
| Сохранить Server URL | Привязать профиль к API | URL, API Key, Profile ID | `PlatformConfig` | `platform_links_sheet.dart` |
| Push snapshot | Отправить локальные данные | Snapshot JSON | `POST /v1/calendar/snapshot` | `almanac_remote_sync_service.dart` |
| Pull snapshot | Забрать удалённые данные | Те же credentials | Локальный merge / конфликт | `resolveSyncDirection` |
| Auto-sync | Фоновый push после правок | `ENABLE_REMOTE_SYNC`, `ENABLE_AUTO_REMOTE_SYNC`, auto-push в профиле | Push после persist (`schedulePush`, delay по умолчанию **0**) | `platform_bootstrap.dart`, `remote_auto_sync.dart` |
| Workspace | Проверить ключ | `GET /v1/workspace` | Workspace существует / auto-provision | `RemoteAlmanacPlatformApi` |
| Мини-сервер | Раздать API с этого ПК/телефона | Кнопка в «Ссылки и API» | `/v1` + WS на LAN, без Python | `lib/platform/mini_server/` |

Dart-define: `SERVER_URL`, `ENABLE_REMOTE_SYNC` (по умолчанию `false`), `ENABLE_AUTO_REMOTE_SYNC` (по умолчанию `true`), `PUSH_DEVICE_TOKEN`, `SEED_DEMO_DATA` (по умолчанию `false`).

## 11. Deep links и маршруты

| Маршрут | Назначение | Вход | Результат |
|---------|------------|------|-----------|
| `/` | Главный календарь | — | `CalendarScreen` |
| `/session/:token` | Страница сессии | Token, query `slot` | `SessionPage` |
| `/join/:token`, `/book/:token`, `/plan/:token` | Публичные ссылки | Token | Редирект на `/session/:token` |
| `almanac://join/TOKEN?server=` | Join-сессия | Token, origin | Редирект на `/session/:token` + подстановка Server URL |
| `almanac://connect?…` | Подключение профиля / YDB invite | Query-параметры | Парсинг `parseYdbInvite`, настройка Platform |
| HTTPS `/connect` | То же для App Links | Query | См. [app-links.md](app-links.md) |

Разбор URI: `lib/core/router/deep_link.dart`. Хостинг: [app-links.md](app-links.md).

## 12. Гостевые календари и экспорт

| Функция | Назначение | Вход | Результат | Модуль |
|---------|------------|------|-----------|--------|
| Подписка ICS | Read-only чужой календарь | URL `.ics`, название, цвет | Кэш событий `guestCalendar` | `guest_calendar_subscription.dart` |
| Экспорт ICS | Выгрузить свои события | Список `AppEvent` | Строка iCalendar, share | `ical_export.dart`, `share_plus` |
| Тестовое заполнение | Debug-наполнение календаря | Профиль | Demo-события | `test_calendar_fill.dart` |

## 13. Напоминания и настройки UI

| Функция | Назначение | Вход | Результат | Модуль |
|---------|------------|------|-----------|--------|
| Напоминание | Локальное уведомление до старта | `reminderMinutesBefore`, горизонт 365 дн., до 64 штук | Планировщик `flutter_local_notifications` | `event_reminder_service.dart` |
| Тема / акцент | Оформление профиля | `ThemeMode`, цвет, пресеты | `AlmanacProfileTheme` | `settings_sheet.dart` |
| Язык | ru / en | Код локали | `appLocaleProvider` | `AppLocalizations` |
| Высокая частота кадров | 90–120 Hz на Android | Method channel | Refresh rate + лимит image cache | `high_refresh_rate.dart` |

## Связанные документы

- [architecture.md](architecture.md) — папки, стек, поток данных
- [self-hosted.md](self-hosted.md) — развёртывание API
- [platform-api.md](platform-api.md) — REST / WebSocket
- [qa-checklist.md](qa-checklist.md) — ручная проверка
