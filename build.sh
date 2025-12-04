#!/usr/bin/env bash
# build.sh  ––  生成静态 wg + 离线包
set -e

########## 0. 准备 ##########
DEST="$PWD/WireGuard-Offline"
rm -rf "$DEST" wg-macos-universal.tar.gz
mkdir -p "$DEST"/{bin,config,service,scripts}

########## 1. 拉源码 ##########
[[ -d wireguard-tools ]] || git clone https://git.zx2c4.com/wireguard-tools
cd wireguard-tools
git checkout 1.0.20210914   # 可换最新 tag

########## 2. 静态编译 ##########
make -C src clean
CFLAGS="-static" LDFLAGS="-static" make -C src -j$(sysctl -n hw.ncpu)

########## 3. 拷二进制 ##########
cp src/wg  "$DEST/bin/"
cp src/wg-quick "$DEST/bin/"
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
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><false/>
</dict>
</plist>
EOF

# ③ 卸载脚本
cat > "$DEST/uninstall.sh" <<'EOF'
#!/bin/bash
sudo wg-quick down /usr/local/etc/wireguard/wg0.conf 2>/dev/null
sudo launchctl unload -w /Library/LaunchDaemons/com.wireguard.offline.plist 2>/dev/null
sudo rm -f /Library/LaunchDaemons/com.wireguard.offline.plist
sudo rm -f /usr/local/bin/{wg,wg-quick}
echo "WireGuard-offline removed."
EOF
chmod +x "$DEST/uninstall.sh"

########## 5. 打包 ##########
cd ..
tar -czf wireguard-tools-macos-universal.tar.gz WireGuard-Offline/
echo ">>> 离线包已生成：wireguard-tools-macos-universal.tar.gz" 