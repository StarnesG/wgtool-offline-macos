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
cp wireguard-tools/src/wg-quick/darwin.bash "$DEST/bin/wg-quick.bash"
cp wireguard-go/wireguard-go "$DEST/bin/"

# 创建 wg-quick 包装脚本（处理 Bash 版本问题）
cat > "$DEST/bin/wg-quick" <<'WRAPPER_EOF'
#!/bin/sh
# wg-quick wrapper - 自动选择合适的 Bash 版本

# macOS 默认 Bash 是 3.2，但 wg-quick 需要 4+
# 此脚本会尝试使用 Homebrew 安装的 Bash 或系统 Bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WG_QUICK_SCRIPT="$SCRIPT_DIR/wg-quick.bash"

# 检查 Bash 版本
check_bash_version() {
    local bash_path="$1"
    if [ ! -x "$bash_path" ]; then
        return 1
    fi
    local version=$("$bash_path" --version 2>/dev/null | head -n1 | sed 's/.*version \([0-9]\).*/\1/')
    [ "$version" -ge 4 ] 2>/dev/null
}

# 尝试查找合适的 Bash
find_bash() {
    # 1. 尝试 Homebrew Bash (Intel)
    if check_bash_version "/usr/local/bin/bash"; then
        echo "/usr/local/bin/bash"
        return 0
    fi
    
    # 2. 尝试 Homebrew Bash (Apple Silicon)
    if check_bash_version "/opt/homebrew/bin/bash"; then
        echo "/opt/homebrew/bin/bash"
        return 0
    fi
    
    # 3. 尝试系统 Bash（可能已升级）
    if check_bash_version "/bin/bash"; then
        echo "/bin/bash"
        return 0
    fi
    
    # 4. 尝试 PATH 中的 bash
    if check_bash_version "$(command -v bash 2>/dev/null)"; then
        command -v bash
        return 0
    fi
    
    return 1
}

# 查找 Bash
BASH_BIN=$(find_bash)

if [ -z "$BASH_BIN" ]; then
    echo "错误：未找到 Bash 4+ 版本" >&2
    echo "" >&2
    echo "wg-quick 需要 Bash 4 或更高版本，但 macOS 默认使用 Bash 3.2" >&2
    echo "" >&2
    echo "解决方案：" >&2
    echo "  1. 安装 Homebrew Bash:" >&2
    echo "     brew install bash" >&2
    echo "" >&2
    echo "  2. 或使用控制脚本（推荐）:" >&2
    echo "     sudo /usr/local/scripts/wg-control.sh up" >&2
    echo "" >&2
    exit 1
fi

# 使用找到的 Bash 执行脚本
exec "$BASH_BIN" "$WG_QUICK_SCRIPT" "$@"
WRAPPER_EOF

chmod +x "$DEST/bin/"*

########## 4. 生成脚本 ##########
echo "==> 生成配置脚本..."
# ① 启停脚本
cat > "$DEST/scripts/wg-control.sh" <<'EOF'
#!/bin/sh
# wg-control.sh - WireGuard 启停控制脚本
# 使用 sh 而不是 bash，兼容 macOS 默认环境

CONF_DIR="/usr/local/etc/wireguard"
IFACE="${2:-wg0}"
CONF="$CONF_DIR/$IFACE.conf"

# 检查是否以 root 运行
if [ "$(id -u)" -ne 0 ]; then
    echo "错误：此脚本需要 root 权限" >&2
    echo "请使用: sudo $0 $*" >&2
    exit 1
fi

# 检查配置文件
check_config() {
    if [ ! -f "$CONF" ]; then
        echo "错误：配置文件不存在: $CONF" >&2
        echo "请创建配置文件或指定正确的接口名称" >&2
        exit 1
    fi
}

# 查找合适的 Bash（用于 wg-quick）
find_bash() {
    for bash_path in /opt/homebrew/bin/bash /usr/local/bin/bash /bin/bash; do
        if [ -x "$bash_path" ]; then
            local version=$("$bash_path" --version 2>/dev/null | head -n1 | sed 's/.*version \([0-9]\).*/\1/')
            if [ "$version" -ge 4 ] 2>/dev/null; then
                echo "$bash_path"
                return 0
            fi
        fi
    done
    return 1
}

# 启动隧道
do_up() {
    check_config
    echo "启动 WireGuard 隧道: $IFACE"
    
    BASH_BIN=$(find_bash)
    if [ -z "$BASH_BIN" ]; then
        echo "警告：未找到 Bash 4+，尝试使用系统 Bash" >&2
        BASH_BIN="/bin/bash"
    fi
    
    WG_QUICK_USERSPACE_IMPLEMENTATION=wireguard-go \
        "$BASH_BIN" /usr/local/bin/wg-quick.bash up "$CONF"
}

# 停止隧道
do_down() {
    echo "停止 WireGuard 隧道: $IFACE"
    
    BASH_BIN=$(find_bash)
    if [ -z "$BASH_BIN" ]; then
        BASH_BIN="/bin/bash"
    fi
    
    WG_QUICK_USERSPACE_IMPLEMENTATION=wireguard-go \
        "$BASH_BIN" /usr/local/bin/wg-quick.bash down "$CONF" 2>/dev/null || true
}

# 重启隧道
do_restart() {
    do_down
    sleep 1
    do_up
}

# 显示状态
do_status() {
    if /usr/local/bin/wg show "$IFACE" >/dev/null 2>&1; then
        echo "WireGuard 隧道 $IFACE 状态:"
        /usr/local/bin/wg show "$IFACE"
    else
        echo "WireGuard 隧道 $IFACE 未运行"
        exit 1
    fi
}

# 主逻辑
case "$1" in
    up)
        do_up
        ;;
    down)
        do_down
        ;;
    restart)
        do_restart
        ;;
    status)
        do_status
        ;;
    *)
        echo "用法: $0 {up|down|restart|status} [接口名]"
        echo ""
        echo "示例:"
        echo "  $0 up              # 启动 wg0"
        echo "  $0 down wg1        # 停止 wg1"
        echo "  $0 restart         # 重启 wg0"
        echo "  $0 status          # 查看 wg0 状态"
        exit 1
        ;;
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