# ЭТАП 7 — NAT. На секунду может моргнуть интернет.

/ip firewall nat
:foreach i in=[find] do={ remove $i }
add chain=srcnat action=masquerade src-address=192.168.10.0/24 \
    dst-address=192.168.10.0/24 comment="Hairpin LAN"
add chain=srcnat action=masquerade out-interface-list=WAN-interfaces \
    comment="WAN NAT"

:put "этап 7 ok"
/ip firewall nat print
