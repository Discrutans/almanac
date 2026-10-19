# hAP ax S · RouterOS 7.24.5 stable

Три моста уже есть — их не сносим. Работаем с кабеля `192.168.10.x` в WinBox → Terminal.

## 1. Как скинуть конфиг

В Terminal, **целиком один блок**:

```
/system resource print
/system routerboard print
/system package print
/ip cloud print
/export compact hide-sensitive
```

Что прислать:

- весь вывод этого блока (это и есть конфиг);
- модель и версию, если не совпали: должно быть **hAP ax S / 7.24.5**;
- **не** пароли Wi‑Fi и **не** `/export` без `hide-sensitive`.

Файл на диск (если удобнее вложить `.rsc`):

```
/system backup save name=before-almanac
/export compact hide-sensitive file=almanac-export
```

WinBox → Files → скачать `almanac-export.rsc` и `before-almanac.backup`. Backup оставьте у себя.

## 2. Что даёт 7.24.5 на этом железе

| | |
|---|---|
| Релиз | 2026-09-29, канал **stable** |
| Зачем держать | CVE-2026-103903 (WinBox auth bypass), CVE-2026-84411 (www уже выключен), свежий Wi‑Fi regulatory |
| Железо | E62iUGS-2axD5axT, ARM **32-bit** EN7562CT 2×950 МГц, 512 МБ, 5×1G, **SFP 2.5G**, PoE-out ether5 |
| Wi‑Fi | драйвер `wifi` (не `wireless`), 2.4×2 + 5 ГГц×3 AX3000 |
| DoH | HTTP/1.1 (HTTP/2 только на ARM64/x86) → Cloudflare, не Quad9 |
| Уже в 7.21+ | `builtin-trust-store` для DoH без ручного CA, mDNS repeater, WG `responder=yes`, `name=` у peer |
| Не включать | FastTrack — ломает CAKE; DHCP snooping IP-binding в 7.24.x как раз чинили |

Проверка, что вы на 7.24.5:

```
/system resource print
```

`version: 7.24.5 (stable)`. Если ниже — System → Packages → Check For Updates → stable.

## 3. Как делаем (и почему)

Оставляем вашу схему: LAN / Assist 2.4 / TDK 5 ГГц / WAN ether1 / CAKE 475M / игры на ether2.

| Решение | Почему так на 7.24.5 |
|---|---|
| Три моста как есть | Изоляция L2 уже есть, VLAN на этом свитче не нужны |
| SFP не трогаем | У вас WAN на ether1; sfp1 — запас под провайдера 2.5G |
| DNS = шлюз + DoH Cloudflare | Кэш 4096 KiB у вас простаивал; `1.1.1.1` как bootstrap, дальше HTTPS. HTTP/1.1 ок |
| mDNS только LAN↔wifi5 | Телефон на TDK видит принтер/Apple TV на кабеле. Нужен **input UDP 5353** |
| Assist 2.4 = IoT | Не ходит в LAN/5 ГГц. Если это рабочие телефоны — этап 6, правило Isolate не вставлять |
| UPnP только bridge-lan | Игры на ether2; с Wi‑Fi UPnP снимаем |
| Filter без дубля SSH/Winbox | Уже есть полный input с `bridge-lan` + `available-from=192.168.10.0/24` |
| Mangle ether2 без TCP/UDP-дублей | Один conn-mark, DSCP EF в обе стороны, CAKE diffserv4 |
| WG позже с `/lab` | Ключи не храним в git; peer с `responder=yes` (сервер) |
| Не reset-configuration | В экспорте нет PSK |

Этапы: `steps/00` … `steps/08`. Вставляйте **по одному файлу**, смотрите что напечатало, потом следующий.

## 4. Порядок

| # | Файл | Что делает |
|---|---|---|
| 0 | `steps/00-export.rsc` | Снимок для чата + backup |
| 1 | `steps/01-lists-services.rsc` | IOT-список, ALG/WPS/MAC/SSH, Cloud DDNS |
| 2 | `steps/02-dns-ntp-doh.rsc` | Кэш, DoH, NTP, mDNS |
| 3 | `steps/03-wifi.rsc` | 2.4: 20 МГц + isolation, WPS off |
| 4 | `steps/04-upnp.rsc` | UPnP только кабель |
| 5 | `steps/05-mangle.rsc` | SQM/DSCP, 10 → 7 правил |
| 6 | `steps/06-filter.rsc` | Firewall. Только с кабеля |
| 7 | `steps/07-nat.rsc` | Hairpin + WAN masquerade |
| 8 | `steps/08-verify.rsc` | Печать проверки |

Потом `/lab` → сгенерировать WG → вставить overlay.

Откат фильтра, если отвалился интернет: backup `before-almanac.backup` → Files → Restore.
