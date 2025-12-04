#!/usr/bin/env bash
# build.sh  ––  生成静态 wg + 离线包
set -e

# 版本配置（可根据需要修改）
WG_TOOLS_VERSION="${WG_TOOLS_VERSION:-v1.0.20210914}"
WG_GO_VERSION="${WG_GO_VERSION:-0.0.20230223}"

echo "==> 构建配置："
echo "    wireguard-tools: $WG_TOOLS_VERSION"
echo "    wireguard-go: $WG_GO_VERSION"
echo ""

########## 0. 准备 ##########
DEST="$PWD/WireGuard-Offline"
rm -rf "$DEST" wireguard-tools-macos-universal.tar.gz
mkdir -p "$DEST"/{bin,config,service,scripts}

########## 1. 拉源码 ##########
echo "==> 克隆/更新 wireguard-tools..."
if [[ ! -d wireguard-tools ]]; then
  git clone https://git.zx2c4.com/wireguard-tools
fi
cd wireguard-tools
git fetch --tags 2>/dev/null || true
git checkout "$WG_TOOLS_VERSION"
cd ..

echo "==> 克隆/更新 wireguard-go..."
if [[ ! -d wireguard-go ]]; then
  git clone https://git.zx2c4.com/wireguard-go
fi
cd wireguard-go
git fetch --tags 2>/dev/null || true
git checkout "$WG_GO_VERSION"
cd ..

########## 2. 编译 ##########
echo "==> 编译 wireguard-tools..."
cd wireguard-tools
make -C src clean
make -C src -j$(sysctl -n hw.ncpu 2>/dev/null || echo 4)
cd ..

echo "==> 编译 wireguard-go..."
cd wireguard-go
make
cd ..

########## 3. 拷二进制 ##########
echo "==> 拷贝二进制文件..."
cp wireguard-tools/src/wg "$DEST/bin/"
cp wireguard-tools/src/wg-quick/darwin.bash "$DEST/bin/wg-quick"
cp wireguard-go/wireguard-go "$DEST/bin/"
chmod +x "$DEST/bin/"*

########## 4. 生成脚本 ##########
echo "==> 生成配置脚本..."
# ① 启停脚本
cat > "$DEST/scripts/wg-control.sh" <<'EOF'
#!/bin/bash
# usage: sudo ./wg-control.sh up|down|restart [conf-name]
CONF_DIR="/usr/local/etc/wireguard"
IFACE="${2:-wg0}"
CONF="$CONF_DIR/$IFACE.conf"
case "$1" in
  up)     WG_QUICK_USERSPACE_IMPLEMENTATION=wireguard-go /usr/local/bin/wg-quick up "$CONF" ;;
  down)   WG_QUICK_USERSPACE_IMPLEMENTATION=wireguard-go /usr/local/bin/wg-quick down "$CONF" ;;
  restart) $0 down "$IFACE" && sleep 1 && $0 up "$IFACE" ;;
  *) echo "Usage: $0 up|down|restart [conf-name]"; exit 1 ;;
esac
EOF
chmod +x "$DEST/scripts/wg-control.sh"

# ② launchd 自启
cat > "$DEST/service/com.wireguard.offline.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>com.wireguard.offline</string>
  <key>ProgramArguments</key>
  <array>
    <string>/usr/local/bin/wg-quick</string>
    <string>up</string>
    <string>/usr/local/etc/wireguard/wg0.conf</string>
  </array>
  <key>EnvironmentVariables</key>
  <dict>
    <key>WG_QUICK_USERSPACE_IMPLEMENTATION</key>
    <string>wireguard-go</string>
  </dict>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><false/>
  <key>StandardOutPath</key><string>/var/log/wireguard.log</string>
  <key>StandardErrorPath</key><string>/var/log/wireguard.log</string>
</dict>
</plist>
EOF

# ③ 卸载脚本
cat > "$DEST/uninstall.sh" <<'EOF'
#!/bin/bash
# 停止运行中的隧道
wg-quick down /usr/local/etc/wireguard/wg0.conf 2>/dev/null || true

# 卸载自启服务
launchctl unload -w /Library/LaunchDaemons/com.wireguard.offline.plist 2>/dev/null || true
rm -f /Library/LaunchDaemons/com.wireguard.offline.plist

# 删除二进制文件
rm -f /usr/local/bin/{wg,wg-quick,wireguard-go,wg-uninstall}
rm -f /usr/local/scripts/wg-control.sh
rmdir /usr/local/scripts 2>/dev/null || true

echo "WireGuard-offline 已卸载"
echo "配置文件保留在 /usr/local/etc/wireguard/"
read -p "是否删除配置文件？(y/n) " DEL
if [[ $DEL == "y" ]]; then
  rm -rf /usr/local/etc/wireguard
  echo "配置文件已删除"
fi
EOF
chmod +x "$DEST/uninstall.sh"

########## 5. 打包 ##########
echo "==> 打包..."
tar -czf wireguard-tools-macos-universal.tar.gz WireGuard-Offline/

echo ""
echo "✅ 离线包已生成：wireguard-tools-macos-universal.tar.gz"
echo ""
echo "包含文件："
tar -tzf wireguard-tools-macos-universal.tar.gz | head -20
echo ""
echo "版本信息："
echo "  wireguard-tools: $WG_TOOLS_VERSION"
echo "  wireguard-go: $WG_GO_VERSION"
echo ""
echo "使用方法："
echo "  1. 将 wireguard-tools-macos-universal.tar.gz 和 install.sh 复制到目标机器"
echo "  2. 运行: sudo ./install.sh" 