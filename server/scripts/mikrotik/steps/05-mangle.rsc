# ЭТАП 5 — SQM CAKE. На секунду сбросит марки, лимит 475M не меняем.
# FastTrack не добавлять — CAKE его не видит.

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

:put "этап 5 ok"
/ip firewall mangle print
