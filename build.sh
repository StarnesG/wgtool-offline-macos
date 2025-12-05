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
echo "    注意：控制脚本使用纯 POSIX shell 实现，不依赖 wg-quick"
echo "    兼容 macOS Bash 3.2，无需安装 Bash 4+"
# ① 启停脚本（纯 POSIX shell 实现，不依赖 wg-quick）
cat > "$DEST/scripts/wg-control.sh" <<'EOF'
#!/bin/sh
# wg-control.sh - WireGuard 启停控制脚本
# 纯 POSIX shell 实现，不依赖 wg-quick，兼容 macOS Bash 3.2

set -e

CONF_DIR="/usr/local/etc/wireguard"
CONFIG_NAME="${2:-wg0}"
CONF="$CONF_DIR/$CONFIG_NAME.conf"
WG="/usr/local/bin/wg"
WIREGUARD_GO="/usr/local/bin/wireguard-go"
STATE_DIR="/var/run/wireguard"
STATE_FILE="$STATE_DIR/$CONFIG_NAME.name"

# 实际的接口名（macOS 上是 utunX）
IFACE=""

# 检查是否以 root 运行
if [ "$(id -u)" -ne 0 ]; then
    echo "❌ 错误：此脚本需要 root 权限" >&2
    echo "请使用: sudo $0 $*" >&2
    exit 1
fi

# 检查必要的命令是否存在
check_commands() {
    local missing=""
    
    if [ ! -x "$WG" ]; then
        missing="$missing wg"
    fi
    
    if [ ! -x "$WIREGUARD_GO" ]; then
        missing="$missing wireguard-go"
    fi
    
    if [ -n "$missing" ]; then
        echo "❌ 错误：缺少必要的命令:$missing" >&2
        echo "请确保已正确安装 WireGuard 工具" >&2
        echo "安装路径:" >&2
        echo "  wg: $WG" >&2
        echo "  wireguard-go: $WIREGUARD_GO" >&2
        exit 1
    fi
}

# 检查配置文件
check_config() {
    if [ ! -f "$CONF" ]; then
        echo "错误：配置文件不存在: $CONF" >&2
        echo "请创建配置文件或指定正确的接口名称" >&2
        exit 1
    fi
}

# 解析配置文件
parse_config() {
    # 提取 Interface 部分的配置
    PRIVATE_KEY=$(awk '/^\[Interface\]/,/^\[/ {if(/^PrivateKey/) print $3}' "$CONF" | head -1)
    ADDRESS=$(awk '/^\[Interface\]/,/^\[/ {if(/^Address/) print $3}' "$CONF" | head -1)
    LISTEN_PORT=$(awk '/^\[Interface\]/,/^\[/ {if(/^ListenPort/) print $3}' "$CONF" | head -1)
    DNS=$(awk '/^\[Interface\]/,/^\[/ {if(/^DNS/) print $3}' "$CONF" | head -1)
    MTU=$(awk '/^\[Interface\]/,/^\[/ {if(/^MTU/) print $3}' "$CONF" | head -1)
    
    # 提取 PostUp/PostDown 命令
    POST_UP=$(awk '/^\[Interface\]/,/^\[/ {if(/^PostUp/) {sub(/^PostUp[[:space:]]*=[[:space:]]*/, ""); print}}' "$CONF")
    POST_DOWN=$(awk '/^\[Interface\]/,/^\[/ {if(/^PostDown/) {sub(/^PostDown[[:space:]]*=[[:space:]]*/, ""); print}}' "$CONF")
}

# 启动 wireguard-go
start_wireguard_go() {
    echo "启动 wireguard-go..."
    
    # 创建状态目录
    mkdir -p "$STATE_DIR" 2>/dev/null || true
    
    # 检查是否已经运行
    if [ -f "$STATE_FILE" ]; then
        IFACE=$(cat "$STATE_FILE")
        if [ -n "$IFACE" ] && pgrep -f "wireguard-go $IFACE" >/dev/null 2>&1; then
            echo "wireguard-go 已在运行，接口: $IFACE"
            if ifconfig "$IFACE" >/dev/null 2>&1; then
                return 0
            else
                echo "接口不存在，停止旧进程..."
                pkill -f "wireguard-go $IFACE" 2>/dev/null || true
                rm -f "$STATE_FILE"
                sleep 1
            fi
        else
            rm -f "$STATE_FILE"
        fi
    fi
    
    # 创建日志目录
    LOG_DIR="/var/log"
    LOG_FILE="$LOG_DIR/wireguard-$CONFIG_NAME.log"
    
    # 在 macOS 上，wireguard-go 需要使用 utun 接口名
    # 不指定接口名，让它自动分配
    echo "执行: $WIREGUARD_GO utun"
    "$WIREGUARD_GO" utun >"$LOG_FILE" 2>&1 &
    WG_PID=$!
    
    echo "wireguard-go 进程 PID: $WG_PID"
    
    # 等待接口创建并获取接口名
    count=0
    while [ $count -lt 20 ]; do
        # 检查进程是否还在运行
        if ! kill -0 $WG_PID 2>/dev/null; then
            echo "❌ wireguard-go 进程已退出" >&2
            echo "查看日志: cat $LOG_FILE" >&2
            if [ -f "$LOG_FILE" ]; then
                echo "最后几行日志:" >&2
                tail -5 "$LOG_FILE" >&2
            fi
            return 1
        fi
        
        # 从日志中提取接口名
        if [ -f "$LOG_FILE" ]; then
            IFACE=$(grep -o "utun[0-9]*" "$LOG_FILE" 2>/dev/null | head -1)
            if [ -n "$IFACE" ] && ifconfig "$IFACE" >/dev/null 2>&1; then
                echo "✅ 接口 $IFACE 已创建"
                # 保存接口名到状态文件
                echo "$IFACE" > "$STATE_FILE"
                return 0
            fi
        fi
        
        sleep 0.5
        count=$((count + 1))
    done
    
    echo "❌ 错误：接口创建超时" >&2
    echo "wireguard-go 进程仍在运行，但接口未创建" >&2
    echo "查看日志: cat $LOG_FILE" >&2
    if [ -f "$LOG_FILE" ]; then
        echo "最后几行日志:" >&2
        tail -10 "$LOG_FILE" >&2
    fi
    
    # 清理
    kill $WG_PID 2>/dev/null || true
    return 1
}

# 配置接口
configure_interface() {
    echo "配置接口 $IFACE..."
    echo ""
    
    parse_config
    
    # 设置私钥
    if [ -n "$PRIVATE_KEY" ]; then
        echo "  设置私钥..."
        if ! echo "$PRIVATE_KEY" | "$WG" set "$IFACE" private-key /dev/stdin 2>/dev/null; then
            echo "  ❌ 设置私钥失败" >&2
            return 1
        fi
    else
        echo "  ❌ 错误：配置文件中未找到 PrivateKey" >&2
        return 1
    fi
    
    # 设置监听端口
    if [ -n "$LISTEN_PORT" ]; then
        echo "  设置监听端口: $LISTEN_PORT"
        "$WG" set "$IFACE" listen-port "$LISTEN_PORT" 2>/dev/null || true
    fi
    
    # 配置 IP 地址
    if [ -n "$ADDRESS" ]; then
        echo "  配置 IP 地址..."
        # 处理多个地址（用逗号分隔）
        echo "$ADDRESS" | tr ',' '\n' | while read -r addr; do
            addr=$(echo "$addr" | tr -d ' ')
            if [ -n "$addr" ]; then
                echo "    添加地址: $addr"
                # macOS 使用 inet 命令配置 IP
                if ! ifconfig "$IFACE" inet "$addr" "$addr" alias 2>/dev/null; then
                    # 如果失败，尝试简单方式
                    ifconfig "$IFACE" "$addr" up 2>/dev/null || true
                fi
            fi
        done
    else
        echo "  ⚠️  警告：未配置 IP 地址"
    fi
    
    # 设置 MTU
    if [ -n "$MTU" ]; then
        echo "  设置 MTU: $MTU"
        ifconfig "$IFACE" mtu "$MTU" 2>/dev/null || true
    fi
    
    # 配置 Peer
    echo "  配置 Peer..."
    if ! configure_peers; then
        echo "  ❌ Peer 配置失败" >&2
        return 1
    fi
    
    # 启动接口
    echo "  启动接口..."
    if ! ifconfig "$IFACE" up 2>/dev/null; then
        echo "  ❌ 接口启动失败" >&2
        return 1
    fi
    
    # 配置路由
    echo "  配置路由..."
    configure_routes
    
    # 配置 DNS
    if [ -n "$DNS" ]; then
        echo "  配置 DNS: $DNS"
        configure_dns
    fi
    
    # 执行 PostUp 命令
    if [ -n "$POST_UP" ]; then
        echo "  执行 PostUp 命令..."
        eval "$POST_UP" 2>/dev/null || true
    fi
    
    echo ""
    return 0
}

# 配置 Peer
configure_peers() {
    local peer_count=0
    local temp_file="/tmp/wg-peers-$$"
    
    # 提取所有 Peer 配置到临时文件
    awk '/^\[Peer\]/ {
        if (peer_key != "") {
            print "PEER_KEY=" peer_key
            print "ENDPOINT=" endpoint
            print "ALLOWED_IPS=" allowed_ips
            print "KEEPALIVE=" keepalive
            print "PRESHARED=" preshared
            print "---"
        }
        peer_key=""; endpoint=""; allowed_ips=""; keepalive=""; preshared=""
        next
    }
    /^\[/ {next}
    /^PublicKey/ {peer_key=$3}
    /^Endpoint/ {endpoint=$3}
    /^AllowedIPs/ {sub(/^AllowedIPs[[:space:]]*=[[:space:]]*/, ""); allowed_ips=$0}
    /^PersistentKeepalive/ {keepalive=$3}
    /^PresharedKey/ {preshared=$3}
    END {
        if (peer_key != "") {
            print "PEER_KEY=" peer_key
            print "ENDPOINT=" endpoint
            print "ALLOWED_IPS=" allowed_ips
            print "KEEPALIVE=" keepalive
            print "PRESHARED=" preshared
        }
    }' "$CONF" > "$temp_file"
    
    # 读取并配置每个 Peer
    while IFS= read -r line; do
        if [ "$line" = "---" ] || [ -z "$line" ]; then
            # 配置当前 Peer
            if [ -n "$PEER_KEY" ] && [ -n "$ALLOWED_IPS" ]; then
                peer_count=$((peer_count + 1))
                echo "    Peer $peer_count: ${PEER_KEY:0:16}..."
                
                CMD="$WG set $IFACE peer $PEER_KEY"
                [ -n "$ENDPOINT" ] && CMD="$CMD endpoint $ENDPOINT" && echo "      Endpoint: $ENDPOINT"
                [ -n "$ALLOWED_IPS" ] && CMD="$CMD allowed-ips $ALLOWED_IPS" && echo "      AllowedIPs: $ALLOWED_IPS"
                [ -n "$KEEPALIVE" ] && CMD="$CMD persistent-keepalive $KEEPALIVE"
                
                if ! eval "$CMD" 2>/dev/null; then
                    echo "      ❌ Peer 配置失败" >&2
                    rm -f "$temp_file"
                    return 1
                fi
                
                if [ -n "$PRESHARED" ]; then
                    echo "$PRESHARED" | "$WG" set "$IFACE" peer "$PEER_KEY" preshared-key /dev/stdin 2>/dev/null || true
                fi
                
                # 重置变量
                PEER_KEY=""
                ENDPOINT=""
                ALLOWED_IPS=""
                KEEPALIVE=""
                PRESHARED=""
            fi
        else
            # 解析配置行
            case "$line" in
                PEER_KEY=*) PEER_KEY="${line#PEER_KEY=}" ;;
                ENDPOINT=*) ENDPOINT="${line#ENDPOINT=}" ;;
                ALLOWED_IPS=*) ALLOWED_IPS="${line#ALLOWED_IPS=}" ;;
                KEEPALIVE=*) KEEPALIVE="${line#KEEPALIVE=}" ;;
                PRESHARED=*) PRESHARED="${line#PRESHARED=}" ;;
            esac
        fi
    done < "$temp_file"
    
    rm -f "$temp_file"
    
    if [ $peer_count -eq 0 ]; then
        echo "    ⚠️  警告：未找到 Peer 配置"
    fi
    
    return 0
}

# 配置路由
configure_routes() {
    echo "配置路由..."
    
    # 从配置中提取 AllowedIPs 并添加路由
    awk '/^\[Peer\]/,/^\[/ {if(/^AllowedIPs/) print $3}' "$CONF" | tr ',' '\n' | while read -r ip; do
        ip=$(echo "$ip" | tr -d ' ')
        if [ -n "$ip" ]; then
            # 检查是否是默认路由
            if [ "$ip" = "0.0.0.0/0" ]; then
                echo "配置默认路由..."
                # 保存原默认网关
                DEFAULT_GW=$(route -n get default 2>/dev/null | awk '/gateway:/ {print $2}')
                if [ -n "$DEFAULT_GW" ]; then
                    # 添加到 VPN 服务器的路由（通过原网关）
                    ENDPOINT_IP=$(awk '/^\[Peer\]/,/^\[/ {if(/^Endpoint/) print $3}' "$CONF" | head -1 | cut -d: -f1)
                    if [ -n "$ENDPOINT_IP" ]; then
                        route add "$ENDPOINT_IP" "$DEFAULT_GW" 2>/dev/null || true
                    fi
                    # 添加默认路由到 VPN
                    route add -net 0.0.0.0/1 -interface "$IFACE" 2>/dev/null || true
                    route add -net 128.0.0.0/1 -interface "$IFACE" 2>/dev/null || true
                fi
            else
                echo "添加路由: $ip"
                route add -net "$ip" -interface "$IFACE" 2>/dev/null || true
            fi
        fi
    done
}

# 配置 DNS
configure_dns() {
    echo "配置 DNS: $DNS"
    # macOS DNS 配置比较复杂，这里提供基本实现
    # 实际使用中可能需要使用 networksetup 或 scutil
    echo "注意：DNS 配置需要手动设置或使用 networksetup 命令"
}

# 停止隧道
stop_tunnel() {
    # 获取实际的接口名
    if [ -f "$STATE_FILE" ]; then
        IFACE=$(cat "$STATE_FILE")
    fi
    
    if [ -z "$IFACE" ]; then
        echo "未找到运行中的隧道: $CONFIG_NAME"
        return 0
    fi
    
    echo "停止 WireGuard 隧道: $CONFIG_NAME (接口: $IFACE)"
    
    # 执行 PostDown 命令
    if [ -f "$CONF" ]; then
        POST_DOWN=$(awk '/^\[Interface\]/,/^\[/ {if(/^PostDown/) {sub(/^PostDown[[:space:]]*=[[:space:]]*/, ""); print}}' "$CONF")
        if [ -n "$POST_DOWN" ]; then
            echo "执行 PostDown 命令..."
            eval "$POST_DOWN" 2>/dev/null || true
        fi
    fi
    
    # 删除路由
    if [ -f "$CONF" ]; then
        awk '/^\[Peer\]/,/^\[/ {if(/^AllowedIPs/) print $3}' "$CONF" 2>/dev/null | tr ',' '\n' | while read -r ip; do
            ip=$(echo "$ip" | tr -d ' ')
            if [ -n "$ip" ] && [ "$ip" != "0.0.0.0/0" ]; then
                route delete -net "$ip" 2>/dev/null || true
            fi
        done
    fi
    
    # 删除默认路由
    route delete -net 0.0.0.0/1 2>/dev/null || true
    route delete -net 128.0.0.0/1 2>/dev/null || true
    
    # 关闭接口
    ifconfig "$IFACE" down 2>/dev/null || true
    
    # 停止 wireguard-go
    pkill -f "wireguard-go $IFACE" 2>/dev/null || true
    
    # 清理状态文件
    rm -f "$STATE_FILE"
    
    echo "隧道已停止"
}

# 显示状态
show_status() {
    # 获取实际的接口名
    if [ -f "$STATE_FILE" ]; then
        IFACE=$(cat "$STATE_FILE")
    fi
    
    if [ -z "$IFACE" ]; then
        echo "WireGuard 隧道 $CONFIG_NAME 未运行"
        exit 1
    fi
    
    if "$WG" show "$IFACE" >/dev/null 2>&1; then
        echo "WireGuard 隧道 $CONFIG_NAME 状态 (接口: $IFACE):"
        "$WG" show "$IFACE"
    else
        echo "WireGuard 隧道 $CONFIG_NAME 未运行"
        exit 1
    fi
}

# 主逻辑
case "$1" in
    up)
        check_commands
        check_config
        echo "启动 WireGuard 隧道: $CONFIG_NAME"
        echo ""
        
        if ! start_wireguard_go; then
            echo "" >&2
            echo "❌ wireguard-go 启动失败" >&2
            echo "" >&2
            echo "故障排查步骤:" >&2
            echo "1. 检查 wireguard-go 是否存在: ls -l $WIREGUARD_GO" >&2
            echo "2. 手动测试启动: sudo $WIREGUARD_GO utun" >&2
            echo "3. 查看日志: cat /var/log/wireguard-$CONFIG_NAME.log" >&2
            echo "4. 查看系统日志: log show --predicate 'process == \"wireguard-go\"' --last 5m" >&2
            exit 1
        fi
        
        if ! configure_interface; then
            echo "" >&2
            echo "❌ 接口配置失败" >&2
            stop_tunnel
            exit 1
        fi
        
        echo ""
        echo "✅ 隧道启动成功"
        echo "   配置: $CONFIG_NAME"
        echo "   接口: $IFACE"
        echo ""
        echo "查看状态: sudo $0 status"
        ;;
    down)
        stop_tunnel
        ;;
    restart)
        stop_tunnel
        sleep 1
        check_commands
        check_config
        echo "启动 WireGuard 隧道: $CONFIG_NAME"
        echo ""
        
        if ! start_wireguard_go; then
            echo "" >&2
            echo "❌ wireguard-go 启动失败" >&2
            exit 1
        fi
        
        if ! configure_interface; then
            echo "" >&2
            echo "❌ 接口配置失败" >&2
            stop_tunnel
            exit 1
        fi
        
        echo ""
        echo "✅ 隧道重启成功"
        echo "   配置: $CONFIG_NAME"
        echo "   接口: $IFACE"
        ;;
    status)
        show_status
        ;;
    diag|diagnose)
        echo "=== WireGuard 诊断信息 ==="
        echo ""
        echo "1. 命令检查:"
        echo "   wg: $([ -x "$WG" ] && echo "✅ 存在" || echo "❌ 不存在") ($WG)"
        echo "   wireguard-go: $([ -x "$WIREGUARD_GO" ] && echo "✅ 存在" || echo "❌ 不存在") ($WIREGUARD_GO)"
        echo ""
        echo "2. 配置文件:"
        echo "   名称: $CONFIG_NAME"
        echo "   路径: $CONF"
        echo "   状态: $([ -f "$CONF" ] && echo "✅ 存在" || echo "❌ 不存在")"
        if [ -f "$CONF" ]; then
            echo "   权限: $(ls -l "$CONF" | awk '{print $1, $3, $4}')"
        fi
        echo ""
        echo "3. 进程状态:"
        if pgrep -f "wireguard-go" >/dev/null 2>&1; then
            echo "   wireguard-go 进程:"
            ps aux | grep "[w]ireguard-go" | awk '{print "   PID:", $2, "CMD:", $11, $12}'
        else
            echo "   wireguard-go: ❌ 未运行"
        fi
        echo ""
        echo "4. 接口状态:"
        if [ -f "$STATE_FILE" ]; then
            IFACE=$(cat "$STATE_FILE")
            echo "   配置名: $CONFIG_NAME"
            echo "   接口名: $IFACE"
            if ifconfig "$IFACE" >/dev/null 2>&1; then
                echo "   状态: ✅ 运行中"
                ifconfig "$IFACE" | head -5 | sed 's/^/   /'
            else
                echo "   状态: ❌ 接口不存在"
            fi
        else
            echo "   $CONFIG_NAME: ❌ 未运行"
        fi
        echo ""
        echo "5. utun 接口:"
        if ifconfig | grep -q "^utun"; then
            ifconfig | grep "^utun" | sed 's/^/   /'
        else
            echo "   无 utun 接口"
        fi
        echo ""
        echo "6. 日志文件:"
        LOG_FILE="/var/log/wireguard-$CONFIG_NAME.log"
        if [ -f "$LOG_FILE" ]; then
            echo "   路径: $LOG_FILE"
            echo "   最后 5 行:"
            tail -5 "$LOG_FILE" | sed 's/^/   /'
        else
            echo "   日志文件不存在: $LOG_FILE"
        fi
        echo ""
        echo "7. 状态文件:"
        echo "   路径: $STATE_FILE"
        echo "   状态: $([ -f "$STATE_FILE" ] && echo "✅ 存在" || echo "❌ 不存在")"
        if [ -f "$STATE_FILE" ]; then
            echo "   内容: $(cat "$STATE_FILE")"
        fi
        ;;
    *)
        echo "用法: $0 {up|down|restart|status|diag} [接口名]"
        echo ""
        echo "命令:"
        echo "  up              启动隧道"
        echo "  down            停止隧道"
        echo "  restart         重启隧道"
        echo "  status          查看状态"
        echo "  diag            诊断信息"
        echo ""
        echo "示例:"
        echo "  $0 up              # 启动 wg0"
        echo "  $0 down wg1        # 停止 wg1"
        echo "  $0 restart         # 重启 wg0"
        echo "  $0 status          # 查看 wg0 状态"
        echo "  $0 diag            # 显示诊断信息"
        echo ""
        echo "注意：此脚本使用纯 POSIX shell 实现，兼容 macOS Bash 3.2"
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