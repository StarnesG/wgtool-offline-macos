#!/usr/bin/env bash
# install.sh  ––  在目标机部署离线包
set -e
[[ $UID -ne 0 ]] && echo "请用 sudo 运行" && exit 1

TAR=$(dirname "$0")/wireguard-tools-macos-universal.tar.gz
[[ -f $TAR ]] || { echo "离线包 $TAR 不存在"; exit 1; }

# 1. 解压到临时目录
TMPDIR=$(mktemp -d)
tar -xf "$TAR" -C "$TMPDIR"

# 2. 安装二进制文件
cp "$TMPDIR/WireGuard-Offline/bin/"* /usr/local/bin/
chmod +x /usr/local/bin/{wg,wg-quick,wireguard-go}

# 3. 安装脚本
mkdir -p /usr/local/scripts
cp "$TMPDIR/WireGuard-Offline/scripts/wg-control.sh" /usr/local/scripts/
chmod +x /usr/local/scripts/wg-control.sh

# 4. 建配置目录
mkdir -p /usr/local/etc/wireguard
chmod 700 /usr/local/etc/wireguard

# 5. 安装自启（可选）
read -p "是否开机自启？(y/n) " AUTO
if [[ $AUTO == "y" ]]; then
  cp "$TMPDIR/WireGuard-Offline/service/com.wireguard.offline.plist" /Library/LaunchDaemons/
  launchctl load -w /Library/LaunchDaemons/com.wireguard.offline.plist
fi

# 6. 安装卸载脚本
cp "$TMPDIR/WireGuard-Offline/uninstall.sh" /usr/local/bin/wg-uninstall
chmod +x /usr/local/bin/wg-uninstall

# 清理
rm -rf "$TMPDIR"

echo ">>> 安装完成！"
echo ">>> 配置文件请放到 /usr/local/etc/wireguard/wg0.conf"
echo ">>> 手动启停：sudo /usr/local/scripts/wg-control.sh up/down"
echo ">>> 卸载命令：sudo wg-uninstall"