# Manual QA — self-hosted Almanac

Чеклист перед релизом или после крупных изменений.  
Сервер: `cd server && .\scripts\run_sqlite.ps1` (Windows) или Docker.

## Подключение

- [ ] Настройки → **Рабочее пространство** → URL `http://localhost:8080` → **Сохранить**
- [ ] **Проверить подключение** → «Сервер доступен, API key принят»
- [ ] (Опционально) **Push-токен (FCM)** сохраняется без ошибки

## Сессии

- [ ] **Новая сессия записи** → deep link `/join/:token` копируется
- [ ] **Новое совместное планирование** → слоты добавляются, видны у второго клиента
- [ ] Владелец: кнопка ✕ закрывает сессию; сессия исчезает из списка
- [ ] Гость: поле «Ваше имя в сессии» → **Применить** → имя в chips участников
- [ ] Collaborative: гость **не** видит кнопки edit/delete/add слотов

## Deep links

- [ ] Браузер: `http://localhost:8080/join/TOKEN` → landing / открытие приложения
- [ ] Guest **без** Server URL в профиле открывает HTTPS ссылку → подключается к серверу из URL
- [ ] `almanac://join/TOKEN?server=http%3A%2F%2Flocalhost%3A8080` (Android/iOS)
- [ ] Legacy `/book/:token` offline → redirect `/session/:token` (local UI removed)
- [ ] Legacy `/plan/:token` offline → redirect `/session/:token`

## Booking inbox

- [ ] Гость отправляет заявку → владелец видит badge inbox
- [ ] Inbox: секция **REST** отдельно от **legacy offline**
- [ ] **Подтвердить** → событие появляется в календаре
- [ ] **Отклонить** → заявка исчезает из inbox
- [ ] На session page owner: pending panel + preview «Как видит гость»

## Sync календаря

- [ ] Настройки → **Отправить** / **Загрузить** (push/pull snapshot)
- [ ] После редактирования события — auto-push snapshot (если `ENABLE_REMOTE_SYNC=true`, `ENABLE_AUTO_REMOTE_SYNC=true`, задан Server URL и auto-push в профиле; без обязательной задержки ~5 с)
- [ ] Второе устройство с тем же API key + profile → pull получает данные

## UX rework (2026-10)

- [ ] **CreateHub**: tier-1 + «Ещё параметры»; month/agenda create bar
- [ ] **Workspace** из Settings; sync не дублируется отдельной простынёй
- [ ] Tap события → preview (agenda/week/day); week hold → DnD move
- [ ] Long-press день (не month) → «Создать…» + «События дня»

## Регрессия

- [ ] Без Server URL: подсказка «Укажите URL сервера» в «Ссылки и API»
- [ ] С Server URL: только server sessions + remote inbox

## Mobile / layout (после рефакторинга)

Проверить на ширинах **360 / 390 / 600 / 960** (эмулятор или resize окна):

- [ ] Календарь: toolbar и top nav без горизонтального overflow
- [ ] Создание / редактирование события: top-panel читаем, поля и кнопки доступны
- [ ] Work schedules / Savings / Platform links sheets — без обрезанных действий
- [ ] Session page (`/session/:token`) — AppBar и контент с safe area
- [ ] Все прежние действия на месте (ничего не «спрятано» ради компактности)

## Домашняя лаборатория (`ALMANAC_HOME_LAB=1`)

- [ ] `AlmanacHomeLab.bat` открывает `/lab`
- [ ] `/lab/plan` создаёт collaborative-сессию со слотами
- [ ] Вторая вкладка как гость видит слоты и участников
- [ ] `/join/:token` открывается с телефона в той же LAN / WireGuard

## Неделя (wide 7д + carousel 3д)

См. [week-ui.md](week-ui.md).

- [ ] Sticky strip (carousel): не уезжает при вертикальном скролле часов
- [ ] Общий vertical scroll: все видимые дни едут вместе
- [ ] Monolithic сетка без стыков колонок
- [ ] Now-line только на сегодня, синхронна со scroll
- [ ] Empty tap → слот 1ч; handles resize; live на labels
- [ ] Drop preview слабее selected slot; armed между ними
- [ ] Drag: autoscroll у края; ghost-дни принимают drop (carousel)
- [ ] hideEmpty expand/collapse не уносит точку фокуса
- [ ] Pinch zoom масштабирует labels
- [ ] Wide: те же слот / DnD / pin / now-line

## Автотесты (CI)

```bash
flutter test
flutter test test/deep_link_test.dart test/server_url_test.dart test/data/local_persistence_test.dart
cd server && python -m pytest tests/ -q
```
