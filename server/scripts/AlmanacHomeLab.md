# Almanac Home Lab

Двойной щелчок по `AlmanacHomeLab.bat` поднимает API на этом ПК и открывает помощник в браузере.

Нужны **Python 3.11+** и пакеты из `server/requirements.txt`:

```bat
cd /d "%~dp0.."
pip install -r requirements.txt
```

(из папки `server`: `pip install -r requirements.txt`)

Порт **8080**. Окно PowerShell не закрывать — это и есть сервер. Остановка: Ctrl+C.

## Страницы

| Адрес | Зачем |
|-------|--------|
| http://127.0.0.1:8080/lab | Server URL, проверка связи, скрипты WireGuard для MikroTik |
| http://127.0.0.1:8080/lab/plan | Тест совместного планирования: сессия, `/join`, живая комната |
| http://127.0.0.1:8080/health | Сервер жив |

В Almanac: **Профили → Ссылки и API** → URL вида `http://192.168.x.x:8080` (тот, что печатает скрипт, не `localhost` с телефона).

Помощник отвечает только с этого ПК и домашней сети (`ALMANAC_HOME_LAB=1`). На публичный VPS не включать.

## Совместное планирование

1. Откройте `/lab/plan`.
2. **Создать сессию** (API key можно оставить пустым — лаборатория заведёт свой).
3. Телефон: скопируйте `/join` или `almanac://` и откройте в Almanac.
4. Второй браузер: **Открыть гостевую вкладку** — слоты синхронизируются по WebSocket.

Гость без ключа ограничен числом редакторов. Галочка «как владелец» + API key — без лимита.

## Телефон через WireGuard (MikroTik hAP ax S)

Страница `/lab`, не открывать порт 8080 в интернет.

Сначала оптимизация живого роутера (WinBox Terminal с кабеля `192.168.10.x`):
[`mikrotik/hap-ax-s-optimize.rsc`](mikrotik/hap-ax-s-optimize.rsc).

Целевой снимок: [`mikrotik/hap-ax-s.rsc`](mikrotik/hap-ax-s.rsc). Пароли Wi‑Fi скрыты — не делать `reset-configuration`.

Что меняется в firewall/сервисах:

- Удалены дубли: SSH+Winbox в filter (уже есть полный доступ с `bridge-lan` + `available-from=192.168.10.0/24`), раздельные TCP/UDP mangle для ether2 (было 10 правил, стало 7).
- WAN везде через `WAN-interfaces`, не хардкод `ether1`.
- UPnP только на кабельном LAN (игры); с Wi‑Fi снят.
- DNS-кэш роутера: DHCP раздаёт `192.168.x.1`, не сырые 1.1.1.1. Имя `router.lan`.
- NTP-сервер на роутере, mDNS repeater между LAN и Wi‑Fi 5 (AirPlay/печать).
- 2.4 Assist = IoT: не ходит в LAN/5 GHz/WG, WPS выкл, client isolation, 20 МГц.
- SIP/FTP/H323 ALG выкл, MAC Winbox только LAN, bandwidth-server/SNMP выкл, Cloud DDNS для WG.
- Bogon drop на WAN без `10.0.0.0/8` (CGNAT и туннель `10.13.13.0/24`).
- Hairpin NAT для UPnP с LAN.

| Мост | Подсеть | Порты / SSID |
|------|---------|----------------|
| `bridge-lan` | `192.168.10.0/24` | ether2–ether5, Winbox/SSH, **ПК Almanac** |
| `bridge-wifi24` | `192.168.20.0/24` | SSID Assist |
| `bridge-wifi5` | `192.168.30.0/24` | SSID TDK |
| `wg-almanac` | `10.13.13.0/24` | UDP 13231 на WAN, peer телефона `.2` |

1. WAN IP или DDNS роутера, порт WG (по умолчанию 13231).
2. LAN подсети: `192.168.10.0/24,192.168.20.0/24,192.168.30.0/24`.
3. **Сгенерировать ключи и скрипты**.
4. Скрипт — в Terminal WinBox / MikroTik. Он идемпотентный: ставит `wg-almanac` в `LAN-interfaces` и handshake **перед** `INPUT drop WAN`. Wi‑Fi, DHCP и CAKE не трогает.
5. `almanac-phone.conf` — в приложение WireGuard на телефоне, туннель включить. Split-tunnel: только WG + три домашние сети, не весь интернет.
6. На ПК (PowerShell от администратора), если телефон не достучится:

```bat
netsh advfirewall firewall add rule name="Almanac API" dir=in action=allow protocol=TCP localport=8080
```

7. В Almanac вставить Server URL с **LAN IP этого ПК** (`192.168.10.x`, не Wi‑Fi).

Если в списке IP всплыл `172.17` / `172.18` / `172.19` — это Docker. Выберите `192.168.*` или `10.*`.

Winbox и SSH по-прежнему только с `192.168.10.0/24`. Телефон в туннеле доходит до API, но не до управления роутером.

## Файлы

Рядом с SQLite (`server/data/`):

- `almanac.db` — сессии лаборатории
- `home_lab.json` — ключи WG и API key лаборатории (**не копировать в git**)

Ключ из приложения Almanac можно вставить на `/lab` и `/lab/plan` — тогда сессии будут в том же workspace, что и телефон.
