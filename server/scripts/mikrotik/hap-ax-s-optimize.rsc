# Оптимизация живого hAP ax S. Вставить целиком в Terminal WinBox
# с кабеля 192.168.10.x (не с Wi-Fi и не через WireGuard).
#
# Не трогает: пароли Wi-Fi, SSID, CAKE 475M, адреса/DHCP-пулы, ether1 MAC.
# После этого: страница /lab → сгенерировать ключи → вставить WG overlay.

:log info "almanac: optimize start"

# --- списки ---
/interface list
:if ([:len [find name="IOT"]] = 0) do={ add name=IOT comment="2.4 Assist IoT" }

/interface list member
:if ([:len [find where list=IOT and interface=bridge-wifi24]] = 0) do={
  add list=IOT interface=bridge-wifi24
}

# --- Wi-Fi: WPS off, IoT isolation, 2.4 = 20 MHz ---
:do {
  /interface wifi set [find name=wifi2.4] channel.width=20mhz \
      datapath.client-isolation=yes security.wps=disable
  /interface wifi set [find name=wifi5] security.wps=disable
} on-error={ :put "wifi wps/isolation: пропуск" }

# --- DNS кэш роутера вместо прямых 1.1.1.1 на клиентах ---
/ip dhcp-server network
set [find address=192.168.10.0/24] dns-server=192.168.10.1 ntp-server=192.168.10.1
set [find address=192.168.20.0/24] dns-server=192.168.20.1 ntp-server=192.168.20.1
set [find address=192.168.30.0/24] dns-server=192.168.30.1 ntp-server=192.168.30.1

/ip dns static
:if ([:len [find name="router.lan"]] = 0) do={
  add name=router.lan address=192.168.10.1 comment="router"
}

:do { /system ntp server set enabled=yes } on-error={
  :put "NTP server: нет в этой версии ROS, пропуск"
}

:do { /ip cloud set ddns-enabled=yes update-time=yes } on-error={
  :put "ip cloud: пропуск"
}

:do {
  /ip dns set mdns-repeat-ifaces=bridge-lan,bridge-wifi5
} on-error={
  :put "mDNS repeater: нет в этой версии ROS, пропуск"
}

/ip neighbor discovery-settings
set discover-interface-list=LAN-interfaces

/ip ssh
set strong-crypto=yes

/snmp
set enabled=no

/tool bandwidth-server
set enabled=no

/tool mac-server
set allowed-interface-list=LAN-interfaces
/tool mac-server mac-winbox
set allowed-interface-list=LAN-interfaces

:foreach n in={"ftp";"tftp";"h323";"sip";"pptp";"rtsp"} do={
  :do { /ip firewall service-port set [find name=$n] disabled=yes } on-error={}
}

# --- UPnP только кабельный LAN (игры на ether2), не Wi-Fi ---
/ip upnp
set enabled=yes show-dummy-rule=no
/ip upnp interfaces
:foreach i in=[find] do={ remove $i }
add interface=ether1 type=external
add interface=bridge-lan type=internal

# --- bogons: без 10.0.0.0/8 (CGNAT/WG 10.13.13.0/24) ---
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

# --- filter: дубли SSH/Winbox убраны, ether1 → WAN-interfaces ---
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
add chain=input action=accept protocol=icmp \
    in-interface-list=LAN-interfaces comment="INPUT ICMP ping from LAN/WiFi"
add chain=input action=accept protocol=udp dst-port=13231 \
    in-interface-list=WAN-interfaces comment="Almanac WG handshake"
add chain=input action=drop in-interface-list=WAN-interfaces \
    comment="INPUT drop WAN"
add chain=input action=drop comment="INPUT drop all"

# --- mangle: 10 правил → 7, TCP/UDP ether2 слиты ---
/ip firewall mangle
:foreach i in=[find] do={ remove $i }
add chain=prerouting action=mark-packet in-interface-list=WAN-interfaces \
    new-packet-mark=pkt-wan-down passthrough=no \
    comment="Mark WAN download for SQM (pkt-wan-down)"
add chain=forward action=mark-connection connection-mark=no-mark \
    in-bridge-port=ether2 in-interface=bridge-lan \
    new-connection-mark=gaming-ether2 comment="ether2 gaming conn"
add chain=forward action=change-dscp in-bridge-port=ether2 \
    in-interface=bridge-lan new-dscp=46 out-interface-list=WAN-interfaces \
    comment="ether2 upload EF"
add chain=forward action=change-dscp connection-mark=gaming-ether2 \
    in-interface-list=WAN-interfaces new-dscp=46 comment="ether2 download EF"
add chain=forward action=change-dscp dscp=0 in-interface=bridge-wifi5 \
    new-dscp=8 out-interface-list=WAN-interfaces comment="WiFi5 upload CS1 bulk"
add chain=forward action=change-dscp dscp=0 in-interface=bridge-wifi24 \
    new-dscp=8 out-interface-list=WAN-interfaces comment="WiFi24 upload CS1 bulk"
add chain=postrouting action=mark-packet out-interface-list=WAN-interfaces \
    new-packet-mark=pkt-wan-up passthrough=no \
    comment="Mark WAN upload for SQM (pkt-wan-up)"

# --- NAT: hairpin для UPnP с LAN + WAN list ---
/ip firewall nat
:foreach i in=[find] do={ remove $i }
add chain=srcnat action=masquerade src-address=192.168.10.0/24 \
    dst-address=192.168.10.0/24 comment="Hairpin LAN"
add chain=srcnat action=masquerade out-interface-list=WAN-interfaces \
    comment="WAN NAT"

:log info "almanac: optimize done"
:put "OK. Cloud DDNS: /ip cloud print"
:put "Дальше: /lab → сгенерировать WG → вставить overlay."
