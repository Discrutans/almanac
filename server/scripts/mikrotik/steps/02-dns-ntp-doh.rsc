# ЭТАП 2 — DNS-кэш, DoH Cloudflare (HTTP/1.1, ARM 32-bit), NTP, mDNS
# 7.24.5: builtin-trust-store уже умеет dns, CA качать не надо.
# Если интернет на клиентах пропал на минуту: вставьте rollback внизу файла.

/ip dhcp-server network
set [find address=192.168.10.0/24] dns-server=192.168.10.1 ntp-server=192.168.10.1
set [find address=192.168.20.0/24] dns-server=192.168.20.1 ntp-server=192.168.20.1
set [find address=192.168.30.0/24] dns-server=192.168.30.1 ntp-server=192.168.30.1

/ip dns static
:if ([:len [find name="router.lan"]] = 0) do={
  add name=router.lan address=192.168.10.1 type=A comment="router"
}

# 7.21+: builtin-trust-store=default уже включает dns — CA качать не надо.

/ip dns
set allow-remote-requests=yes cache-size=4096KiB servers=1.1.1.1 \
    use-doh-server="https://cloudflare-dns.com/dns-query" verify-doh-cert=yes \
    mdns-repeat-ifaces=bridge-lan,bridge-wifi5

/system ntp client
set enabled=yes
/system ntp server
set enabled=yes

:put "этап 2 ok"
:put "Проверка DoH (должно быть flags=resolved):"
/ip dns static print where name="router.lan"
/resolve google.com

# --- rollback DoH, если resolve не работает ---
# /ip dns set use-doh-server="" verify-doh-cert=no servers=1.1.1.1,8.8.8.8
