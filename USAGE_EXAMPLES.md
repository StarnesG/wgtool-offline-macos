# 使用示例

## 场景 1：基本使用（推荐）

### 1. 构建离线包

```bash
# 在有网络的机器上
git clone https://github.com/StarnesG/wgtool-offline-macos.git
cd wgtool-offline-macos

# 配置代理（如果需要）
export GOPROXY=https://goproxy.cn,direct

# 构建
./build.sh
```

### 2. 传输到目标机器

```bash
# 将以下文件复制到目标机器
# - wireguard-tools-macos-universal.tar.gz
# - install.sh
```

### 3. 安装

```bash
# 在目标机器上
chmod +x install.sh
sudo ./install.sh
# 选择 'y' 启用开机自启（可选）
```

### 4. 配置

```bash
# 创建配置文件
sudo nano /usr/local/etc/wireguard/wg0.conf
```

配置内容：
```ini
[Interface]
PrivateKey = YOUR_PRIVATE_KEY
Address = 10.0.0.2/24
DNS = 1.1.1.1

[Peer]
PublicKey = SERVER_PUBLIC_KEY
Endpoint = vpn.example.com:51820
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
```

```bash
# 设置权限
sudo chmod 600 /usr/local/etc/wireguard/wg0.conf
```

### 5. 启动

```bash
# 启动隧道
sudo /usr/local/scripts/wg-control.sh up

# 查看状态
sudo /usr/local/scripts/wg-control.sh status
```

---

## 场景 2：多隧道配置

### 创建多个配置文件

```bash
# 创建 wg0.conf（家庭网络）
sudo nano /usr/local/etc/wireguard/wg0.conf

# 创建 wg1.conf（公司网络）
sudo nano /usr/local/etc/wireguard/wg1.conf

# 设置权限
sudo chmod 600 /usr/local/etc/wireguard/*.conf
```

### 管理多个隧道

```bash
# 启动家庭网络
sudo /usr/local/scripts/wg-control.sh up wg0

# 启动公司网络
sudo /usr/local/scripts/wg-control.sh up wg1

# 查看所有隧道
sudo wg

# 停止特定隧道
sudo /usr/local/scripts/wg-control.sh down wg0
```

---

## 场景 3：使用 Bash 4+（可选）

### 安装 Bash 4+

```bash
# 安装 Homebrew（如果未安装）
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 安装 Bash
brew install bash

# 验证
bash --version
```

### 使用 wg-quick

```bash
# 现在可以直接使用 wg-quick
sudo wg-quick up wg0
sudo wg-quick down wg0
```

---

## 场景 4：开机自启

### 配置自启服务

```bash
# 如果安装时未配置，可以手动配置
sudo cp /usr/local/service/com.wireguard.offline.plist /Library/LaunchDaemons/
sudo launchctl load -w /Library/LaunchDaemons/com.wireguard.offline.plist
```

### 管理自启服务

```bash
# 查看服务状态
sudo launchctl list | grep wireguard

# 停止服务
sudo launchctl unload /Library/LaunchDaemons/com.wireguard.offline.plist

# 启动服务
sudo launchctl load /Library/LaunchDaemons/com.wireguard.offline.plist

# 禁用自启
sudo launchctl unload -w /Library/LaunchDaemons/com.wireguard.offline.plist
sudo rm /Library/LaunchDaemons/com.wireguard.offline.plist
```

### 查看日志

```bash
# 查看服务日志
tail -f /var/log/wireguard.log

# 查看系统日志
log show --predicate 'process == "wg-quick"' --last 1h
```

---

## 场景 5：生成密钥对

### 生成新的密钥对

```bash
# 生成私钥
wg genkey | sudo tee /usr/local/etc/wireguard/privatekey

# 从私钥生成公钥
sudo cat /usr/local/etc/wireguard/privatekey | wg pubkey | sudo tee /usr/local/etc/wireguard/publickey

# 查看密钥
echo "私钥:"
sudo cat /usr/local/etc/wireguard/privatekey
echo "公钥:"
sudo cat /usr/local/etc/wireguard/publickey
```

### 生成预共享密钥（可选）

```bash
# 生成预共享密钥（增强安全性）
wg genpsk | sudo tee /usr/local/etc/wireguard/presharedkey

# 在配置文件中使用
# [Peer]
# PresharedKey = <生成的预共享密钥>
```

---

## 场景 6：故障排查

### 检查配置文件

```bash
# 验证配置文件语法
sudo wg-quick strip wg0

# 查看配置文件
sudo cat /usr/local/etc/wireguard/wg0.conf
```

### 检查网络连接

```bash
# 查看接口状态
sudo wg show wg0

# 查看详细信息
sudo wg show wg0 dump

# 测试连接
ping -c 4 10.0.0.1  # VPN 网关

# 查看路由表
netstat -rn | grep utun
```

### 手动启动（查看详细错误）

```bash
# 使用控制脚本（会显示详细错误）
sudo /usr/local/scripts/wg-control.sh up

# 或直接使用 wg-quick（如果安装了 Bash 4+）
sudo wg-quick up wg0
```

### 检查进程

```bash
# 查看 wireguard-go 进程
ps aux | grep wireguard-go

# 查看端口监听
sudo lsof -i -P | grep wireguard
```

---

## 场景 7：更新版本

### 更新到最新版本

```bash
# 在构建机器上
cd wgtool-offline-macos
git pull

# 使用最新版本构建
WG_TOOLS_VERSION=v1.0.20250521 WG_GO_VERSION=0.0.20250522 ./build.sh

# 传输到目标机器并重新安装
sudo ./install.sh
```

### 更新配置但保留数据

```bash
# 停止隧道
sudo /usr/local/scripts/wg-control.sh down

# 备份配置
sudo cp -r /usr/local/etc/wireguard /tmp/wireguard-backup

# 重新安装
sudo ./install.sh

# 恢复配置（如果需要）
sudo cp /tmp/wireguard-backup/*.conf /usr/local/etc/wireguard/

# 重启隧道
sudo /usr/local/scripts/wg-control.sh up
```

---

## 场景 8：完全卸载

### 卸载 WireGuard

```bash
# 使用卸载脚本
sudo wg-uninstall

# 根据提示选择是否删除配置文件
```

### 手动卸载

```bash
# 停止隧道
sudo /usr/local/scripts/wg-control.sh down

# 卸载自启服务
sudo launchctl unload -w /Library/LaunchDaemons/com.wireguard.offline.plist
sudo rm /Library/LaunchDaemons/com.wireguard.offline.plist

# 删除二进制文件
sudo rm /usr/local/bin/{wg,wg-quick,wg-quick.bash,wireguard-go,wg-uninstall}
sudo rm -r /usr/local/scripts

# 删除配置文件（可选）
sudo rm -rf /usr/local/etc/wireguard
```

---

## 场景 9：分流配置

### 仅路由特定网段

```ini
[Interface]
PrivateKey = YOUR_PRIVATE_KEY
Address = 10.0.0.2/24

[Peer]
PublicKey = SERVER_PUBLIC_KEY
Endpoint = vpn.example.com:51820
# 仅路由这些网段通过 VPN
AllowedIPs = 10.0.0.0/24, 192.168.1.0/24
PersistentKeepalive = 25
```

### 全局代理但排除特定网段

```ini
[Interface]
PrivateKey = YOUR_PRIVATE_KEY
Address = 10.0.0.2/24
# 添加路由表规则
PostUp = route add -net 192.168.1.0/24 -interface en0
PostDown = route delete -net 192.168.1.0/24

[Peer]
PublicKey = SERVER_PUBLIC_KEY
Endpoint = vpn.example.com:51820
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
```

---

## 场景 10：性能优化

### 调整 MTU

```ini
[Interface]
PrivateKey = YOUR_PRIVATE_KEY
Address = 10.0.0.2/24
MTU = 1420  # 根据网络环境调整

[Peer]
PublicKey = SERVER_PUBLIC_KEY
Endpoint = vpn.example.com:51820
AllowedIPs = 0.0.0.0/0
```

### 测试 MTU

```bash
# 启动隧道后测试
ping -D -s 1400 10.0.0.1  # 从 1400 开始测试
ping -D -s 1420 10.0.0.1
ping -D -s 1450 10.0.0.1

# 找到不分片的最大值
```

---

## 常用命令速查

```bash
# 启动/停止/重启
sudo /usr/local/scripts/wg-control.sh up
sudo /usr/local/scripts/wg-control.sh down
sudo /usr/local/scripts/wg-control.sh restart
sudo /usr/local/scripts/wg-control.sh status

# 查看状态
sudo wg
sudo wg show wg0

# 生成密钥
wg genkey | sudo tee privatekey
sudo cat privatekey | wg pubkey

# 查看日志
tail -f /var/log/wireguard.log

# 测试连接
ping 10.0.0.1
```

---

## 更多帮助

- 完整文档：[README.md](README.md)
- 快速开始：[QUICKSTART.md](QUICKSTART.md)
- Bash 问题：[BASH_VERSION_FIX.md](BASH_VERSION_FIX.md)
- 版本兼容：[VERSION_COMPATIBILITY.md](VERSION_COMPATIBILITY.md)
