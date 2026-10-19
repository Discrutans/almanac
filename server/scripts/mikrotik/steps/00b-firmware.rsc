# ЭТАП 0b — RouterBOARD 7.19.6 при ROS 7.24.5. Сначала прошивка, потом этапы 1–8.
# После upgrade будет reboot ~1 мин. WinBox с кабеля 192.168.10.x.

/system routerboard print
/system routerboard upgrade
:put "Подтвердите upgrade, затем:"
:put "/system reboot"
