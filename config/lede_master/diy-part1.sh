#!/bin/bash
#========================================================================================================================
# https://github.com/ophub/amlogic-s9xxx-openwrt
# Description: Automatically Build OpenWrt
# Function: Diy script (Before Update feeds, Modify the default IP, hostname, theme, add/remove software packages, etc.)
# Source code repository: https://github.com/coolsnowwolf/lede / Branch: master
#========================================================================================================================

# Add a feed source
# sed -i '$a src-git lienol https://github.com/Lienol/openwrt-package' feeds.conf.default

# other
# rm -rf package/lean/{samba4,luci-app-samba4,luci-app-ttyd}


# ==============================================
# Fine3399 RK3399 GPIO138 控制 QCNFA765 PCI‑WiFi 上电时序
# ==============================================
mkdir -p "${TOPDIR}/files/usr/bin"
cat > "${TOPDIR}/files/usr/bin/usbpower-ctrl" <<'EOF'
#!/bin/sh
case "$1" in
on|1)
    echo 138 > /sys/class/gpio/export 2>/dev/null
    echo out > /sys/class/gpio/gpio138/direction
    echo 1 > /sys/class/gpio/gpio138/value
    ;;
off|0)
    echo 138 > /sys/class/gpio/export 2>/dev/null
    echo out > /sys/class/gpio/gpio138/direction
    echo 0 > /sys/class/gpio/gpio138/value
    ;;
status)
    echo 138 > /sys/class/gpio/export 2>/dev/null
    cat /sys/class/gpio/gpio138/value
    ;;
unexport)
    echo 138 > /sys/class/gpio/unexport 2>/dev/null
    ;;
*)
    echo "usbpower-ctrl on|off|status|unexport"
    exit 1
    ;;
esac
EOF
chmod +x "${TOPDIR}/files/usr/bin/usbpower-ctrl"

mkdir -p "${TOPDIR}/files/etc/init.d"
cat > "${TOPDIR}/files/etc/init.d/usbpower" <<'EOF'
#!/bin/sh /etc/rc.common
START=95
STOP=10
USE_PROCD=1

start_service() {
    (
        usbpower-ctrl off
        sleep 3
        usbpower-ctrl on
    ) &
}

stop_service() {
    usbpower-ctrl off
}
EOF
chmod +x "${TOPDIR}/files/etc/init.d/usbpower"

mkdir -p "${TOPDIR}/files/etc/rc.d"
ln -sf ../init.d/usbpower "${TOPDIR}/files/etc/rc.d/S95usbpower"
