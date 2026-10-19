# ЭТАП 4 — UPnP только кабель (ether2 игры). С Wi-Fi снимаем.

/ip upnp
set enabled=yes show-dummy-rule=no
/ip upnp interfaces
:foreach i in=[find] do={ remove $i }
add interface=ether1 type=external
add interface=bridge-lan type=internal

:put "этап 4 ok"
/ip upnp interfaces print
