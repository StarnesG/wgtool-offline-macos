#!/usr/bin/env bash
# build.sh  ––  生成静态 wg + 离线包
set -e

########## 0. 准备 ##########
DEST="$PWD/WireGuard-Offline"
rm -rf "$DEST" wireguard-tools-macos-universal.tar.gz
mkdir -p "$DEST"/{bin,config,service,scripts}

########## 1. 拉源码 ##########
# wireguard-tools
if [[ ! -d wireguard-tools ]]; then
  git clone https://git.zx2c4.com/wireguard-tools
fi
cd wireguard-tools
git fetch --tags 2>/dev/null || true
git checkout v1.0.20210914   # 可换最新 tag
cd ..

# wireguard-go (macOS 需要用户态实现)
if [[ ! -d wireguard-go ]]; then
  git clone https://git.zx2c4.com/wireguard-go
fi
cd wireguard-go
git fetch --tags 2>/dev/null || true
git checkout 0.0.20220316   # 稳定版本
cd ..

########## 2. 编译 ##########
# 编译 wg 和 wg-quick (macOS 不支持 -static，使用动态链接)
cd wireguard-tools
make -C src clean
make -C src -j$(sysctl -n hw.ncpu 2>/dev/null || echo 4)
cd ..

# 编译 wireguard-go
cd wireguard-go
make
cd ..

########## 3. 拷二进制 ##########
cp wireguard-tools/src/wg "$DEST/bin/"
cp wireguard-tools/src/wg-quick/darwin.bash "$DEST/bin/wg-quick"
cp wireguard-go/wireguard-go "$DEST/bin/"
chmod +x "$DEST/bin/"*

########## 4. 生成脚本 ##########
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
tar -czf wireguard-tools-macos-universal.tar.gz WireGuard-Offline/
echo ">>> 离线包已生成：wireguard-tools-macos-universal.tar.gz"
echo ">>> 包含文件："
tar -tzf wireguard-tools-macos-universal.tar.gz | head -20 