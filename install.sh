#!/usr/bin/env bash
# install.sh  ––  在目标机部署离线包
set -e
[[ $UID -ne 0 ]] && echo "请用 sudo 运行" && exit 1

TAR=$(dirname "$0")/wireguard-tools-macos-universal.tar.gz
[[ -f $TAR ]] || { echo "离线包 $TAR 不存在"; exit 1; }

# 1. 解压
tar -xf "$TAR" -C /usr/local --strip=1

# 2. 建配置目录
mkdir -p /usr/local/etc/wireguard

# 3. 安装自启（可选）
read -p "是否开机自启？(y/n) " AUTO
if [[ $AUTO == "y" ]]; then
  cp /usr/local/service/com.wireguard.offline.plist /Library/LaunchDaemons/
  launchctl load -w /Library/LaunchDaemons/com.wireguard.offline.plist
fi

echo ">>> 安装完成。配置文件请放到 /usr/local/etc/wireguard/wg0.conf"
echo ">>> 手动启停：sudo /usr/local/scripts/wg-control.sh up/down"