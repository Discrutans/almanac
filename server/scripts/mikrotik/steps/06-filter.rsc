# ЭТАП 6 — firewall. ТОЛЬКО с кабеля 192.168.10.x, не с Wi-Fi и не с телефона.
# На мгновение цепочка пустая (= accept), затем новые правила.
# Assist 2.4 не ходит в LAN. Если нужен доступ с Assist — не вставляйте
# правило "Isolate 2.4 IoT from LAN/WiFi/WG".

/ip firewall address-list
:foreach i in=[find list=bogons] do={ remove $i }
add list=bogons address=0.0.0.0/8 comment="bogon"
add list=bogons address=127.0.0.0/8 comment="bogon"
add list=bogons address=169.254.0.0/16 comment="bogon"
add list=bogons address=192.168.0.0/16 comment="bogon"
add list=bogons address=172.16.0.0/12 comment="bogon"
add list=bogons address=224.0.0.0/4 comment="bogon"
add list=bogons address=255.255.255.255 comment="bogon"

/ip firewall raw
:foreach i in=[find] do={ remove $i }
add chain=prerouting action=drop in-interface-list=WAN-interfaces \
    src-address-list=bogons comment="RAW drop bogon src from WAN"

/ip firewall filter
:foreach i in=[find] do={ remove $i }
add chain=forward action=accept connection-state=established,related,untracked \
    comment="FWD established"
add chain=forward action=drop connection-state=invalid comment="FWD invalid"
add chain=forward action=accept connection-nat-state=dstnat \
    in-interface-list=WAN-interfaces comment="Allow dstnat (UPnP/port-forwards)"
add chain=forward action=drop connection-state=new \
    in-interface-list=WAN-interfaces comment="Block new from WAN"
add chain=forward action=drop in-interface-list=IOT \
    out-interface-list=LAN-interfaces comment="Isolate 2.4 IoT from LAN/WiFi/WG"
add chain=forward action=accept in-interface-list=LAN-interfaces \
    comment="Allow LAN/WiFi/WG to anywhere"
add chain=forward action=drop comment="Drop all other forward"
add chain=input action=accept connection-state=established,related,untracked \
    comment="INPUT established"
add chain=input action=drop connection-state=invalid comment="INPUT invalid"
add chain=input action=accept in-interface=bridge-lan \
    comment="INPUT full access from cable LAN"
add chain=input action=accept protocol=udp dst-port=67 \
    in-interface-list=LAN-interfaces comment="INPUT DHCP from LAN/WiFi"
add chain=input action=accept protocol=udp dst-port=53 \
    in-interface-list=LAN-interfaces comment="INPUT DNS UDP from LAN/WiFi"
add chain=input action=accept protocol=tcp dst-port=53 \
    in-interface-list=LAN-interfaces comment="INPUT DNS TCP from LAN/WiFi"
add chain=input action=accept protocol=udp dst-port=123 \
    in-interface-list=LAN-interfaces comment="INPUT NTP from LAN/WiFi"
add chain=input action=accept protocol=udp dst-port=5353 \
    in-interface-list=LAN-interfaces comment="INPUT mDNS"
add chain=input action=accept protocol=icmp \
    in-interface-list=LAN-interfaces comment="INPUT ICMP ping from LAN/WiFi"
add chain=input action=accept protocol=udp dst-port=13231 \
    in-interface-list=WAN-interfaces comment="Almanac WG handshake"
add chain=input action=drop in-interface-list=WAN-interfaces \
    comment="INPUT drop WAN"
add chain=input action=drop comment="INPUT drop all"

:put "этап 6 ok"
/ip firewall filter print
