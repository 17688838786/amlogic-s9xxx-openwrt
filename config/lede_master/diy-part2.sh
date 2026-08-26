#!/bin/bash
#========================================================================================================================
# https://github.com/ophub/amlogic-s9xxx-openwrt
# Description: Automatically Build OpenWrt
# Function: Diy script (After Update feeds, Modify the default IP, hostname, theme, add/remove software packages, etc.)
# Source code repository: https://github.com/coolsnowwolf/lede / Branch: master
#========================================================================================================================

# ------------------------------- Main source started -------------------------------
#
# Set default IP address
default_ip="192.168.1.1"
ip_regex="^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$"
# Modify default IP if an argument is provided and it matches the IP format
[[ -n "${1}" && "${1}" != "${default_ip}" && "${1}" =~ ${ip_regex} ]] && {
    echo "Modify default IP address to: ${1}"
    sed -i "/lan) ipad=\${ipaddr:-/s/\${ipaddr:-\"[^\"]*\"}/\${ipaddr:-\"${1}\"}/" package/base-files/*/bin/config_generate
}

# Modify default theme（FROM uci-theme-bootstrap CHANGE TO luci-theme-material）
# sed -i 's/luci-theme-bootstrap/luci-theme-material/g' ./feeds/luci/collections/luci/Makefile

# Add autocore support for armsr-armv8
sed -i 's/TARGET_rockchip/TARGET_rockchip\|\|TARGET_armsr/g' package/lean/autocore/Makefile

# Set etc/openwrt_release
sed -i "s|DISTRIB_REVISION='.*'|DISTRIB_REVISION='R$(date +%Y.%m.%d)'|g" package/lean/default-settings/files/zzz-default-settings
echo "DISTRIB_SOURCEREPO='github.com/coolsnowwolf/lede'" >>package/base-files/files/etc/openwrt_release
echo "DISTRIB_SOURCECODE='lede'" >>package/base-files/files/etc/openwrt_release
echo "DISTRIB_SOURCEBRANCH='master'" >>package/base-files/files/etc/openwrt_release

# Set ccache
# Remove existing ccache settings
sed -i '/CONFIG_DEVEL/d' .config
sed -i '/CONFIG_CCACHE/d' .config
# Apply new ccache configuration
if [[ "${2}" == "true" ]]; then
    echo "CONFIG_DEVEL=y" >>.config
    echo "CONFIG_CCACHE=y" >>.config
    echo 'CONFIG_CCACHE_DIR="$(TOPDIR)/.ccache"' >>.config
else
    echo '# CONFIG_DEVEL is not set' >>.config
    echo "# CONFIG_CCACHE is not set" >>.config
    echo 'CONFIG_CCACHE_DIR=""' >>.config
fi
#
# ------------------------------- Main source ends -------------------------------

# ------------------------------- Other started -------------------------------
#
# Add luci-app-amlogic
rm -rf package/luci-app-amlogic
git clone -b main https://github.com/ophub/luci-app-amlogic.git package/luci-app-amlogic
#
# Apply patch
# git apply ../config/patches/{0001*,0002*}.patch --directory=feeds/luci
#
# ------------------------------- Other ends -------------------------------

#=============================================
# Fine3399 GPIO138 usb‑pwr (GPIO3_A6) power control
#=============================================
mkdir -p "${TOPDIR}/files/usr/bin"
cat > "${TOPDIR}/files/usr/bin/usbpower-ctrl" <<'EOF'
#!/bin/sh
GPIO_NUM=138
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

# 必须: 创建开机自启软链接
mkdir -p "${TOPDIR}/files/etc/rc.d"

ln -sf ../init.d/usbpower "${TOPDIR}/files/etc/rc.d/S95usbpower"
