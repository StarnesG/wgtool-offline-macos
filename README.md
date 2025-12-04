# WireGuard Tools - macOS 离线安装包

将 WireGuard 命令行工具（wg、wg-quick）和 wireguard-go 打包成离线安装包，用于无网络或受限网络环境的 macOS 系统。

## 项目说明

本项目基于官方 [wireguard-tools](https://git.zx2c4.com/wireguard-tools/) 和 [wireguard-go](https://git.zx2c4.com/wireguard-go/)，提供：

- `wg`: WireGuard 配置管理工具
- `wg-quick`: WireGuard 快速启停脚本
- `wireguard-go`: macOS 用户态 WireGuard 实现
- 自动化启停脚本和 launchd 服务配置

## 构建离线包

### 前置要求

- macOS 系统（支持 Intel 和 Apple Silicon）
- 已安装 Xcode Command Line Tools: `xcode-select --install`
- 已安装 Git
- 已安装 Go 编译器（用于编译 wireguard-go）

### 构建步骤

```bash
# 1. 克隆本仓库
git clone https://github.com/StarnesG/wgtool-offline-macos.git
cd wgtool-offline-macos

# 2. 执行构建脚本
chmod +x build.sh
./build.sh
```

构建完成后会生成 `wireguard-tools-macos-universal.tar.gz` 离线安装包。

### 构建过程说明

脚本会自动完成以下操作：

1. 克隆 wireguard-tools 和 wireguard-go 源码
2. 检出稳定版本标签（wireguard-tools v1.0.20210914，wireguard-go 0.0.20220316）
3. 编译二进制文件
4. 生成启停脚本和 launchd 服务配置
5. 打包成 tar.gz 压缩包

## 安装使用

### 方式一：使用安装脚本（推荐）

将 `wireguard-tools-macos-universal.tar.gz` 和 `install.sh` 复制到目标机器：

```bash
# 赋予执行权限
chmod +x install.sh

# 运行安装脚本（需要 sudo）
sudo ./install.sh
```

安装脚本会提示是否配置开机自启。

### 方式二：手动安装

```bash
# 1. 解压离线包
tar -xzf wireguard-tools-macos-universal.tar.gz

# 2. 安装二进制文件
sudo cp WireGuard-Offline/bin/* /usr/local/bin/
sudo chmod +x /usr/local/bin/{wg,wg-quick,wireguard-go}

# 3. 安装控制脚本
sudo mkdir -p /usr/local/scripts
sudo cp WireGuard-Offline/scripts/wg-control.sh /usr/local/scripts/
sudo chmod +x /usr/local/scripts/wg-control.sh

# 4. 创建配置目录
sudo mkdir -p /usr/local/etc/wireguard
sudo chmod 700 /usr/local/etc/wireguard

# 5. （可选）配置开机自启
sudo cp WireGuard-Offline/service/com.wireguard.offline.plist /Library/LaunchDaemons/
sudo launchctl load -w /Library/LaunchDaemons/com.wireguard.offline.plist
```

## 配置 WireGuard

### 创建配置文件

在 `/usr/local/etc/wireguard/` 目录下创建配置文件，例如 `wg0.conf`：

```bash
sudo nano /usr/local/etc/wireguard/wg0.conf
```

配置文件示例：

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

设置正确的权限：

```bash
sudo chmod 600 /usr/local/etc/wireguard/wg0.conf
```

### 生成密钥对

```bash
# 生成私钥
wg genkey | sudo tee /usr/local/etc/wireguard/privatekey

# 从私钥生成公钥
sudo cat /usr/local/etc/wireguard/privatekey | wg pubkey | sudo tee /usr/local/etc/wireguard/publickey

# 查看密钥
sudo cat /usr/local/etc/wireguard/privatekey
sudo cat /usr/local/etc/wireguard/publickey
```

## 启停管理

### 使用控制脚本

```bash
# 启动隧道（默认 wg0）
sudo /usr/local/scripts/wg-control.sh up

# 启动指定隧道
sudo /usr/local/scripts/wg-control.sh up wg1

# 停止隧道
sudo /usr/local/scripts/wg-control.sh down

# 重启隧道
sudo /usr/local/scripts/wg-control.sh restart
```

### 使用 wg-quick 命令

```bash
# 启动
sudo WG_QUICK_USERSPACE_IMPLEMENTATION=wireguard-go wg-quick up wg0

# 停止
sudo WG_QUICK_USERSPACE_IMPLEMENTATION=wireguard-go wg-quick down wg0
```

### 查看状态

```bash
# 查看所有接口
sudo wg

# 查看指定接口
sudo wg show wg0

# 查看详细信息
sudo wg show wg0 dump
```

## 开机自启

### 启用自启服务

如果安装时未配置自启，可手动启用：

```bash
sudo cp WireGuard-Offline/service/com.wireguard.offline.plist /Library/LaunchDaemons/
sudo launchctl load -w /Library/LaunchDaemons/com.wireguard.offline.plist
```

### 禁用自启服务

```bash
sudo launchctl unload -w /Library/LaunchDaemons/com.wireguard.offline.plist
sudo rm /Library/LaunchDaemons/com.wireguard.offline.plist
```

### 查看服务状态

```bash
sudo launchctl list | grep wireguard
```

### 查看服务日志

```bash
tail -f /var/log/wireguard.log
```

## 卸载

### 使用卸载脚本

```bash
sudo wg-uninstall
```

脚本会提示是否删除配置文件。

### 手动卸载

```bash
# 1. 停止隧道
sudo wg-quick down wg0

# 2. 卸载自启服务
sudo launchctl unload -w /Library/LaunchDaemons/com.wireguard.offline.plist
sudo rm /Library/LaunchDaemons/com.wireguard.offline.plist

# 3. 删除二进制文件
sudo rm /usr/local/bin/{wg,wg-quick,wireguard-go,wg-uninstall}
sudo rm /usr/local/scripts/wg-control.sh

# 4. （可选）删除配置文件
sudo rm -rf /usr/local/etc/wireguard
```

## 故障排查

### 隧道无法启动

1. 检查配置文件语法：
   ```bash
   sudo wg-quick strip wg0
   ```

2. 检查 wireguard-go 是否在运行：
   ```bash
   ps aux | grep wireguard-go
   ```

3. 查看详细错误信息：
   ```bash
   sudo WG_QUICK_USERSPACE_IMPLEMENTATION=wireguard-go wg-quick up wg0
   ```

### 权限问题

确保配置文件权限正确：

```bash
sudo chmod 700 /usr/local/etc/wireguard
sudo chmod 600 /usr/local/etc/wireguard/*.conf
```

### 网络连接问题

1. 检查路由表：
   ```bash
   netstat -rn
   ```

2. 测试连接：
   ```bash
   ping -c 4 10.0.0.1  # 替换为你的 VPN 网关地址
   ```

3. 检查 DNS：
   ```bash
   scutil --dns
   ```

### 自启服务不工作

1. 检查 plist 文件语法：
   ```bash
   plutil -lint /Library/LaunchDaemons/com.wireguard.offline.plist
   ```

2. 查看服务状态：
   ```bash
   sudo launchctl list | grep wireguard
   ```

3. 查看系统日志：
   ```bash
   log show --predicate 'process == "wg-quick"' --last 1h
   ```

## 常见问题

### Q: 为什么需要 wireguard-go？

A: macOS 没有内核级 WireGuard 支持，需要使用用户态实现 wireguard-go。

### Q: 支持哪些 macOS 版本？

A: 理论上支持 macOS 10.14+ 的所有版本，包括 Intel 和 Apple Silicon。

### Q: 可以同时运行多个隧道吗？

A: 可以，创建多个配置文件（如 wg0.conf、wg1.conf）并分别启动。

### Q: 如何更新到最新版本？

A: 重新运行 build.sh 构建最新版本，然后重新安装。可以修改 build.sh 中的版本标签。

### Q: 离线包可以在其他 Mac 上使用吗？

A: 可以，但需要确保目标机器的 macOS 版本和架构兼容。

## 版本信息

- wireguard-tools: v1.0.20210914
- wireguard-go: 0.0.20220316

可在 `build.sh` 中修改版本标签以使用其他版本。

## 参考资料

- [WireGuard 官方网站](https://www.wireguard.com/)
- [wireguard-tools 源码](https://git.zx2c4.com/wireguard-tools/)
- [wireguard-go 源码](https://git.zx2c4.com/wireguard-go/)
- [WireGuard 快速入门](https://www.wireguard.com/quickstart/)

## 许可证

本项目脚本采用 MIT 许可证。WireGuard 相关组件遵循其原始许可证（GPLv2）。

## 贡献

欢迎提交 Issue 和 Pull Request。
