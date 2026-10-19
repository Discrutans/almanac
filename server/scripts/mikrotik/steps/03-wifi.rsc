# ЭТАП 3 — Wi-Fi. PSK не трогает.
# 7.24.5 обновил regulatory: country=Russia оставляем.
# 2.4 Assist = IoT: 20 МГц стабильнее в плотной застройке, isolation между клиентами.

/interface wifi
set [find name=wifi2.4] channel.width=20mhz datapath.client-isolation=yes \
    security.wps=disable configuration.country=Russia
set [find name=wifi5] security.wps=disable configuration.country=Russia \
    channel.frequency=5180

:put "этап 3 ok"
/interface wifi print detail where name=wifi2.4 or name=wifi5
