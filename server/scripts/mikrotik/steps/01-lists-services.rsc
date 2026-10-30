# ЭТАП 1 — списки и сервисы. Безопасно, firewall не трогает.
# Ожидание: "этап 1 ok"

/interface list
:if ([:len [find name="IOT"]] = 0) do={ add name=IOT comment="2.4 Assist IoT" }

/interface list member
:if ([:len [find where list=IOT and interface=bridge-wifi24]] = 0) do={
  add list=IOT interface=bridge-wifi24
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

/ip cloud
set ddns-enabled=yes update-time=yes

:put "этап 1 ok"
:put "Cloud DDNS hostname:"
/ip cloud print
