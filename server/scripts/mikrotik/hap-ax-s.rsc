# Almanac / hAP ax S — целевой снимок конфига (RouterOS 7)
#
# Три изолированных L2-моста:
#   bridge-lan    192.168.10.0/24  ether2–ether5   (ПК Almanac, Winbox/SSH)
#   bridge-wifi24 192.168.20.0/24  SSID Assist
#   bridge-wifi5  192.168.30.0/24  SSID TDK
# WAN: ether1 DHCP. SQM CAKE 475M. IPv6 выключен.
#
# Пароли Wi-Fi в экспорте скрыты — этот файл НЕ для /system reset-configuration
# без повторной установки PSK в WinBox.
#
# WireGuard (Almanac): на живом роутере вставьте скрипт со страницы
# http://127.0.0.1:8080/lab — он идемпотентный и проставит ключи.
# Ниже — как должен выглядеть конечный firewall/адреса после overlay.

/interface bridge
add comment="LAN " igmp-snooping=yes name=bridge-lan
add comment="WiFi 5 GHz" igmp-snooping=yes name=bridge-wifi5 protocol-mode=none
add comment="WiFi 2.4 GHz" igmp-snooping=yes name=bridge-wifi24 protocol-mode=\
    none
/interface wifi
set [ find default-name=wifi1 ] channel.band=2ghz-ax .width=20/40mhz \
    configuration.country=Russia .installation=indoor .mode=ap .ssid=Assist \
    disabled=no name=wifi2.4 security.authentication-types=wpa2-psk,wpa3-psk
set [ find default-name=wifi2 ] channel.band=5ghz-ax .frequency=5180 .width=\
    20/40/80mhz configuration.country=Russia .installation=indoor .mode=ap \
    .ssid=TDK disabled=no name=wifi5 security.authentication-types=\
    wpa2-psk,wpa3-psk
/interface ethernet
set [ find default-name=ether1 ] mac-address=74:56:3C:CA:21:58
/interface wireguard
add comment="Almanac home lab" listen-port=13231 name=wg-almanac
/interface list
add name=LAN-interfaces
add comment="WAN only" name=WAN-interfaces
/ip pool
add name=pool-lan ranges=192.168.10.100-192.168.10.200
add name=pool-wifi24 ranges=192.168.20.100-192.168.20.200
add name=pool-wifi5 ranges=192.168.30.100-192.168.30.200
/ip dhcp-server
add address-pool=pool-lan interface=bridge-lan lease-time=1d name=dhcp-lan
add address-pool=pool-wifi24 interface=bridge-wifi24 lease-time=8h name=\
    dhcp-wifi24
add address-pool=pool-wifi5 interface=bridge-wifi5 lease-time=8h name=\
    dhcp-wifi5
/queue type
add cake-ack-filter=filter cake-diffserv=diffserv4 cake-nat=yes kind=cake name=\
    cake-wan
/queue tree
add max-limit=475M name=WAN-UP packet-mark=pkt-wan-up parent=global queue=\
    cake-wan
add comment="CAKE download 95% of 500M" max-limit=475M name=WAN-DOWN \
    packet-mark=pkt-wan-down parent=global queue=cake-wan
/interface bridge port
add bridge=bridge-wifi24 interface=wifi2.4
add bridge=bridge-wifi5 interface=wifi5
add bridge=bridge-lan interface=ether2
add bridge=bridge-lan interface=ether3
add bridge=bridge-lan interface=ether4
add bridge=bridge-lan interface=ether5
/ip neighbor discovery-settings
set discover-interface-list=!WAN-interfaces
/ip settings
set rp-filter=loose tcp-syncookies=yes
/ipv6 settings
set accept-router-advertisements=no disable-ipv6=yes
/interface list member
add interface=bridge-lan list=LAN-interfaces
add interface=bridge-wifi24 list=LAN-interfaces
add interface=bridge-wifi5 list=LAN-interfaces
add comment="Almanac WG" interface=wg-almanac list=LAN-interfaces
add interface=ether1 list=WAN-interfaces
/ip address
add address=192.168.10.1/24 comment="LAN gateway" interface=bridge-lan network=\
    192.168.10.0
add address=192.168.20.1/24 comment="WiFi 2.4 gateway" interface=bridge-wifi24 \
    network=192.168.20.0
add address=192.168.30.1/24 comment="WiFi 5 gateway" interface=bridge-wifi5 \
    network=192.168.30.0
add address=10.13.13.1/24 comment="Almanac WG" interface=wg-almanac network=\
    10.13.13.0
/ip dhcp-client
add comment="WAN DHCP" interface=ether1 name=client1 use-peer-dns=no
/ip dhcp-server network
add address=192.168.10.0/24 dns-server=1.1.1.1,8.8.8.8 gateway=192.168.10.1
add address=192.168.20.0/24 dns-server=1.1.1.1,8.8.8.8 gateway=192.168.20.1
add address=192.168.30.0/24 dns-server=1.1.1.1,8.8.8.8 gateway=192.168.30.1
/ip dns
set allow-remote-requests=yes cache-size=4096KiB servers=1.1.1.1,8.8.8.8
/ip firewall filter
add action=accept chain=forward comment="FWD established" connection-state=\
    established,related
add action=drop chain=forward comment="FWD invalid" connection-state=invalid
add action=accept chain=forward comment="Allow dstnat (UPnP/port-forwards)" \
    connection-nat-state=dstnat in-interface=ether1
add action=drop chain=forward comment="Block new from WAN" connection-state=new \
    in-interface=ether1
add action=accept chain=forward comment="Allow LAN/WiFi to anywhere" \
    in-interface-list=LAN-interfaces
add action=drop chain=forward comment="Drop all other forward"
add action=accept chain=input comment="INPUT established" connection-state=\
    established,related
add action=drop chain=input comment="INPUT invalid" connection-state=invalid
add action=accept chain=input comment="INPUT DHCP from LAN/WiFi" dst-port=67 \
    in-interface-list=LAN-interfaces protocol=udp
add action=accept chain=input comment="INPUT DNS UDP from LAN/WiFi" dst-port=53 \
    in-interface-list=LAN-interfaces protocol=udp
add action=accept chain=input comment="INPUT DNS TCP from LAN/WiFi" dst-port=53 \
    in-interface-list=LAN-interfaces protocol=tcp
add action=accept chain=input comment="INPUT ICMP ping from LAN/WiFi" \
    in-interface-list=LAN-interfaces protocol=icmp
add action=accept chain=input comment="INPUT SSH+Winbox from LAN 10.x only" \
    dst-port=22,8291 protocol=tcp src-address=192.168.10.0/24
add action=accept chain=input comment="INPUT full access from cable LAN" \
    in-interface=bridge-lan
add action=accept chain=input comment="Almanac WG handshake" dst-port=13231 \
    in-interface-list=WAN-interfaces protocol=udp
add action=drop chain=input comment="INPUT drop WAN" in-interface=ether1
add action=drop chain=input comment="INPUT drop all"
/ip firewall mangle
add action=change-dscp chain=forward comment="WiFi5 upload -> DSCP CS1 bulk" \
    dscp=0 in-interface=bridge-wifi5 new-dscp=8 out-interface=ether1
add action=change-dscp chain=forward comment="WiFi24 upload -> DSCP CS1 bulk" \
    dscp=0 in-interface=bridge-wifi24 new-dscp=8 out-interface=ether1
add action=mark-packet chain=postrouting comment=\
    "Mark WAN upload for SQM (pkt-wan-up)" new-packet-mark=pkt-wan-up \
    out-interface=ether1 passthrough=no
add action=change-dscp chain=forward comment="ether2 upload UDP EF" \
    in-bridge-port=ether2 in-interface=bridge-lan new-dscp=46 out-interface=\
    ether1 protocol=udp
add action=change-dscp chain=forward comment="ether2 upload TCP EF" \
    in-bridge-port=ether2 in-interface=bridge-lan new-dscp=46 out-interface=\
    ether1 protocol=tcp
add action=mark-connection chain=forward comment="ether2 conn mark gaming" \
    connection-mark=no-mark in-bridge-port=ether2 in-interface=bridge-lan \
    new-connection-mark=gaming-ether2 protocol=udp
add action=mark-connection chain=forward comment="ether2 conn mark gaming TCP" \
    connection-mark=no-mark in-bridge-port=ether2 in-interface=bridge-lan \
    new-connection-mark=gaming-ether2 protocol=tcp
add action=change-dscp chain=forward comment="WAN gaming ether2 UDP EF" \
    connection-mark=gaming-ether2 in-interface=ether1 new-dscp=46 protocol=udp
add action=change-dscp chain=forward comment="WAN gaming ether2 TCP EF" \
    connection-mark=gaming-ether2 in-interface=ether1 new-dscp=46 protocol=tcp
add action=mark-packet chain=prerouting comment=\
    "Mark WAN download for SQM (pkt-wan-down)" in-interface=ether1 \
    new-packet-mark=pkt-wan-down passthrough=no
/ip firewall nat
add action=masquerade chain=srcnat comment="WAN NAT" out-interface=ether1
/ip service
set ftp disabled=yes
set ssh available-from=192.168.10.0/24
set telnet disabled=yes
set www disabled=yes
set winbox available-from=192.168.10.0/24
set api disabled=yes
set api-ssl disabled=yes
/ip upnp
set show-dummy-rule=no
/ip upnp interfaces
add interface=ether1 type=external
add interface=bridge-lan type=internal
add interface=bridge-wifi24 type=internal
add interface=bridge-wifi5 type=internal
/system clock
set time-zone-name=Europe/Moscow
/system ntp client
set enabled=yes
/system ntp client servers
add address=pool.ntp.org
add address=time.cloudflare.com
