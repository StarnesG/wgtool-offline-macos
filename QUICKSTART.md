# WireGuard macOS 离线包 - 快速开始

## 构建机器（有网络）

### 1. 安装依赖

```bash
# 安装 Xcode Command Line Tools
xcode-select --install

# 安装 Go（如果未安装）
brew install go
# 或从 https://golang.org/dl/ 下载

# 验证
go version  # 需要 1.18+
```

### 2. 构建离线包

```bash
# 克隆仓库
git clone https://github.com/StarnesG/wgtool-offline-macos.git
cd wgtool-offline-macos

# 如果网络受限，配置代理
export GOPROXY=https://goproxy.cn,direct
# 或
export https_proxy=http://127.0.0.1:7890

# 构建（使用默认稳定版本）
chmod +x build.sh
./build.sh

# 或指定版本
WG_GO_VERSION=0.0.20250522 ./build.sh
```

### 3. 传输文件

将以下文件复制到目标机器：
- `wireguard-tools-macos-universal.tar.gz`
- `install.sh`

---

## 目标机器（离线/受限网络）

### 1. 安装

```bash
chmod +x install.sh
sudo ./install.sh
# 根据提示选择是否开机自启
```

### 2. 配置

```bash
# 创建配置文件
sudo nano /usr/local/etc/wireguard/wg0.conf
```

配置示例：
```ini
[Interface]
PrivateKey = YOUR_PRIVATE_KEY_HERE
Address = 10.0.0.2/24
DNS = 1.1.1.1

[Peer]
PublicKey = SERVER_PUBLIC_KEY_HERE
Endpoint = vpn.example.com:51820
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
```

```bash
# 设置权限
sudo chmod 600 /usr/local/etc/wireguard/wg0.conf
```

### 3. 启动

```bash
# 启动隧道（使用控制脚本，兼容 Bash 3.2）
sudo /usr/local/scripts/wg-control.sh up

# 查看状态
sudo /usr/local/scripts/wg-control.sh status
# 或
sudo wg

# 停止隧道
sudo /usr/local/scripts/wg-control.sh down
```

**✅ 完全兼容**：控制脚本使用纯 POSIX shell 实现，不依赖 wg-quick，无需安装 Bash 4+。

---

## 常用命令

```bash
# 启动/停止/重启
sudo /usr/local/scripts/wg-control.sh up
sudo /usr/local/scripts/wg-control.sh down
sudo /usr/local/scripts/wg-control.sh restart

# 查看状态
sudo wg
sudo wg show wg0

# 生成密钥
wg genkey | sudo tee /usr/local/etc/wireguard/privatekey
sudo cat /usr/local/etc/wireguard/privatekey | wg pubkey

# 查看日志（如果配置了自启）
tail -f /var/log/wireguard.log

# 卸载
sudo wg-uninstall
```

---

## 故障排查

### Bash 版本问题

**✅ 已解决**：控制脚本使用纯 POSIX shell 实现，不依赖 wg-quick。

**直接使用**：
```bash
sudo /usr/local/scripts/wg-control.sh up
```

无需安装 Bash 4+！

### 构建失败：Go 依赖下载超时

```bash
# 使用国内镜像
export GOPROXY=https://goproxy.cn,direct
./build.sh
```

### 构建失败：wireguard-go 编译错误

```bash
# 检查 Go 版本
go version

# Go 1.18-1.20
WG_GO_VERSION=0.0.20230223 ./build.sh

# Go 1.21+
WG_GO_VERSION=0.0.20250522 ./build.sh
```

### 隧道无法启动

```bash
# 检查配置文件
sudo wg-quick strip wg0

# 检查权限
sudo chmod 700 /usr/local/etc/wireguard
sudo chmod 600 /usr/local/etc/wireguard/wg0.conf

# 手动启动查看错误
sudo WG_QUICK_USERSPACE_IMPLEMENTATION=wireguard-go wg-quick up wg0
```

### 网络不通

```bash
# 检查接口状态
sudo wg show wg0

# 检查路由
netstat -rn

# 测试连接
ping -c 4 10.0.0.1  # VPN 网关
```

---

## 版本选择

| Go 版本 | 推荐 wireguard-go 版本 |
|---------|----------------------|
| 1.18-1.20 | 0.0.20230223 (默认) |
| 1.21+ | 0.0.20250522 |

```bash
# 查看 Go 版本
go version

# 指定版本构建
WG_GO_VERSION=0.0.20230223 ./build.sh
```

---

## 更多信息

详细文档请参考 [README.md](README.md)
