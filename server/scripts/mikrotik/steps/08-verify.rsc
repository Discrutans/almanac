# ЭТАП 8 — проверка. Пришлите вывод, если что-то красное.

:put "=== version ==="
/system resource print
:put "=== cloud ddns ==="
/ip cloud print
:put "=== dns / doh ==="
/ip dns print
:put "=== filter comments ==="
/ip firewall filter print where comment~"Isolate|drop WAN|WG handshake|mDNS"
:put "=== mangle count ==="
:put [:len [/ip firewall mangle find]]
:put "=== upnp ==="
/ip upnp interfaces print
:put "=== wifi ==="
/interface wifi print
:put "=== resolve ==="
/resolve cloudflare.com
:put "этап 8 ok — дальше /lab и WG overlay"
