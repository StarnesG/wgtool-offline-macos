#!/usr/bin/env bash
# install.sh  ––  在目标机部署离线包
set -e
[[ $UID -ne 0 ]] && echo "请用 sudo 运行" && exit 1

TAR=$(dirname "$0")/wireguard-tools-macos-universal.tar.gz
[[ -f $TAR ]] || { echo "离线包 $TAR 不存在"; exit 1; }
mkdir -p /usr/local/bin /usr/local/etc/wireguard

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

echo ""
echo "✅ 安装完成！"
echo ""
echo "下一步："
echo "  1. 创建配置文件: sudo nano /usr/local/etc/wireguard/wg0.conf"
echo "  2. 启动隧道: sudo /usr/local/scripts/wg-control.sh up"
echo "  3. 查看状态: sudo /usr/local/scripts/wg-control.sh status"
echo ""
echo "其他命令："
echo "  停止: sudo /usr/local/scripts/wg-control.sh down"
echo "  重启: sudo /usr/local/scripts/wg-control.sh restart"
echo "  卸载: sudo wg-uninstall"
echo ""
echo "注意："
echo "  - macOS 默认 Bash 是 3.2，wg-quick 需要 Bash 4+"
echo "  - 推荐使用控制脚本: /usr/local/scripts/wg-control.sh"
echo "  - 或安装新版 Bash: brew install bash"