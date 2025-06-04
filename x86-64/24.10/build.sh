#!/bin/bash
# Log file for debugging
LOGFILE="/tmp/uci-defaults-log.txt"
echo "Starting 99-custom.sh at $(date)" >> $LOGFILE
echo "编译固件大小为: $PROFILE MB"
echo "Include Docker: $INCLUDE_DOCKER"

echo "Create pppoe-settings"
mkdir -p  /home/build/immortalwrt/files/etc/config

# 创建pppoe配置文件 yml传入环境变量ENABLE_PPPOE等 写入配置文件 供99-custom.sh读取
cat << EOF > /home/build/immortalwrt/files/etc/config/pppoe-settings
enable_pppoe=${ENABLE_PPPOE}
pppoe_account=${PPPOE_ACCOUNT}
pppoe_password=${PPPOE_PASSWORD}
EOF

echo "cat pppoe-settings"
cat /home/build/immortalwrt/files/etc/config/pppoe-settings
# 输出调试信息
echo "$(date '+%Y-%m-%d %H:%M:%S') - 开始编译..."



# 定义所需安装的包列表 下列插件你都可以自行删减
PACKAGES=""
PACKAGES="$PACKAGES curl"
PACKAGES="$PACKAGES luci-i18n-diskman-zh-cn"
PACKAGES="$PACKAGES luci-i18n-firewall-zh-cn"
# 服务——FileBrowser 用户名admin 密码admin
PACKAGES="$PACKAGES luci-i18n-filebrowser-go-zh-cn"
PACKAGES="$PACKAGES luci-app-argon-config"
PACKAGES="$PACKAGES luci-i18n-argon-config-zh-cn"
#24.10
PACKAGES="$PACKAGES luci-i18n-package-manager-zh-cn"
PACKAGES="$PACKAGES luci-i18n-ttyd-zh-cn"
PACKAGES="$PACKAGES luci-app-openclash"
PACKAGES="$PACKAGES luci-i18n-homeproxy-zh-cn"
PACKAGES="$PACKAGES openssh-sftp-server"
PACKAGES="$PACKAGES luci-app-frpc"
PACKAGES="$PACKAGES luci-app-aria2"
PACKAGES="$PACKAGES luci-app-watchcat"
PACKAGES="$PACKAGES luci-i18n-upnp-zh-cn"
PACKAGES="$PACKAGES luci-i18n-alist-zh-cn"
# 增加几个必备组件 方便用户安装iStore
git clone --depth=1 https://github.com/nikkinikki-org/OpenWrt-nikki package/luci-app-nikki
PACKAGES="$PACKAGES fdisk"
PACKAGES="$PACKAGES script-utils"
PACKAGES="$PACKAGES luci-i18n-samba4-zh-cn"
# 判断是否需要编译 Docker 插件
if [ "$INCLUDE_DOCKER" = "yes" ]; then
    PACKAGES="$PACKAGES luci-i18n-dockerman-zh-cn"
    echo "Adding package: luci-i18n-dockerman-zh-cn"
# nikki
if curl -s "$mirror/openwrt/24-config-common" | grep -q "^CONFIG_PACKAGE_luci-app-nikki=y"; then
    git clone https://$github/morytyann/OpenWrt-nikki package/new/openwrt-nikki --depth=1
    mkdir -p files/etc/opkg/keys
    curl -skL https://github.com/nikkinikki-org/OpenWrt-nikki/raw/gh-pages/key-build.pub >files/etc/opkg/keys/ab017c88aab7a08b
    echo "src/gz nikki https://nikkinikki.pages.dev/openwrt-24.10/$arch/nikki" >>files/etc/opkg/customfeeds.conf
    mkdir -p files/etc/nikki/run/ui
    curl -skLo files/etc/nikki/run/Country.mmdb https://$github/NobyDa/geoip/raw/release/Private-GeoIP-CN.mmdb
    curl -skLo files/etc/nikki/run/GeoIP.dat https://$github/MetaCubeX/meta-rules-dat/releases/download/latest/geoip-lite.dat
    curl -skLo files/etc/nikki/run/GeoSite.dat https://$github/MetaCubeX/meta-rules-dat/releases/download/latest/geosite.dat
    curl -skLo gh-pages.zip https://$github/Zephyruso/zashboard/archive/refs/heads/gh-pages.zip
    unzip gh-pages.zip
    mv zashboard-gh-pages files/etc/nikki/run/ui/zashboard
    rm -rf gh-pages.zip
    # make sure nikki is always latest
    git clone -b Alpha --depth=1 https://github.com/metacubex/mihomo --depth=1 nikki
    nikki_sha=$(git -C nikki rev-parse HEAD)
    nikki_short_sha=$(git -C nikki rev-parse --short HEAD)
    git -C nikki config tar.xz.command "xz -c"
    git -C nikki archive --output=nikki.tar.xz HEAD
    nikki_checksum=$(sha256sum nikki/nikki.tar.xz | cut -d ' ' -f 1)
    sed -i "s/PKG_SOURCE_DATE:=.*/PKG_SOURCE_DATE:=$(git -C nikki log -n 1 --format=%cs)/" package/new/openwrt-nikki/nikki/Makefile
    sed -i "s/PKG_SOURCE_VERSION:=.*/PKG_SOURCE_VERSION:=$nikki_sha/" package/new/openwrt-nikki/nikki/Makefile
    sed -i "s/PKG_MIRROR_HASH:=.*/PKG_MIRROR_HASH:=$nikki_checksum/" package/new/openwrt-nikki/nikki/Makefile
    sed -i "s/PKG_BUILD_VERSION:=.*/PKG_BUILD_VERSION:=alpha-$nikki_short_sha/" package/new/openwrt-nikki/nikki/Makefile
    rm -rf nikki
    
fi
git clone https://$github/JohnsonRan/packages_net_speedtest-ex package/new/speedtest-ex
# 构建镜像
echo "$(date '+%Y-%m-%d %H:%M:%S') - Building image with the following packages:"
echo "$PACKAGES"

make image PROFILE="generic" PACKAGES="$PACKAGES" FILES="/home/build/immortalwrt/files" ROOTFS_PARTSIZE=$PROFILE

if [ $? -ne 0 ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Error: Build failed!"
    exit 1
fi

echo "$(date '+%Y-%m-%d %H:%M:%S') - Build completed successfully."
