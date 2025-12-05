# WireGuard Tools - macOS 离线安装包

将 WireGuard 命令行工具（wg、wg-quick）和 wireguard-go 打包成离线安装包，用于无网络或受限网络环境的 macOS 系统。

## 重要提示

✅ **完全兼容 macOS Bash 3.2**：本项目的控制脚本使用纯 POSIX shell 实现，**不依赖 wg-quick**，无需安装 Bash 4+。

**推荐使用控制脚本**（开箱即用）：
```bash
sudo /usr/local/scripts/wg-control.sh up
```

控制脚本直接调用 `wg` 和 `wireguard-go`，实现了 wg-quick 的核心功能，完全兼容 macOS 默认环境。

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
- 已安装 Go 编译器 1.18+ （用于编译 wireguard-go）
  - 检查版本：`go version`
  - 安装：`brew install go` 或从 [golang.org](https://golang.org/dl/) 下载

### 构建步骤

```bash
# 1. 克隆本仓库
git clone https://github.com/StarnesG/wgtool-offline-macos.git
cd wgtool-offline-macos

# 2. 执行构建脚本
chmod +x build.sh
./build.sh

# 3. （可选）指定版本构建
WG_TOOLS_VERSION=v1.0.20210914 WG_GO_VERSION=0.0.20230223 ./build.sh

# 4. （可选）使用最新版本
WG_GO_VERSION=0.0.20250522 ./build.sh
```

构建完成后会生成 `wireguard-tools-macos-universal.tar.gz` 离线安装包。

**注意**：如果构建时遇到网络问题（无法下载 Go 依赖），需要配置代理：

```bash
# 设置代理（根据实际情况修改）
export https_proxy=http://127.0.0.1:7890
export http_proxy=http://127.0.0.1:7890
export all_proxy=socks5://127.0.0.1:7890

# 或使用 Go 代理
export GOPROXY=https://goproxy.cn,direct

# 然后执行构建
./build.sh
```

### 构建过程说明

脚本会自动完成以下操作：

1. 克隆 wireguard-tools 和 wireguard-go 源码
2. 检出稳定版本标签（默认：wireguard-tools v1.0.20210914，wireguard-go 0.0.20230223）
3. 编译二进制文件（wg、wg-quick、wireguard-go）
4. 生成启停脚本和 launchd 服务配置
5. 打包成 tar.gz 压缩包

**版本说明**：
- wireguard-tools v1.0.20210914 是稳定的命令行工具版本
- wireguard-go 0.0.20230223 兼容现代 Go 版本（Go 1.18+）
- 可通过环境变量 `WG_TOOLS_VERSION` 和 `WG_GO_VERSION` 自定义版本

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

### 使用控制脚本（推荐，无需 Bash 4+）

控制脚本使用纯 POSIX shell 实现，**不依赖 wg-quick**，完全兼容 macOS Bash 3.2：

```bash
# 启动隧道（默认 wg0）
sudo /usr/local/scripts/wg-control.sh up

# 启动指定隧道
sudo /usr/local/scripts/wg-control.sh up wg1

# 停止隧道
sudo /usr/local/scripts/wg-control.sh down

# 重启隧道
sudo /usr/local/scripts/wg-control.sh restart

# 查看状态
sudo /usr/local/scripts/wg-control.sh status
```

### 使用 wg-quick 命令（可选）

**注意**：wg-quick 需要 Bash 4+，但 macOS 默认使用 Bash 3.2。**推荐使用控制脚本**，无需安装额外软件。

如果确实需要使用 wg-quick，需要先安装 Bash 4+：

```bash
# 安装 Homebrew Bash
brew install bash

# 验证版本
bash --version  # 应该显示 5.x

# 使用 wg-quick
sudo wg-quick up wg0
sudo wg-quick down wg0
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

### Bash 版本问题

#### wg-quick: Version mismatch: bash 3 detected

**症状**：运行 `wg-quick` 时提示 Bash 版本不匹配

**原因**：macOS 默认使用 Bash 3.2，但 wg-quick 需要 Bash 4+

**解决方案**：

**方案 1：使用控制脚本（推荐，无需安装）**
```bash
sudo /usr/local/scripts/wg-control.sh up
```

**方案 2：安装 Bash 4+**
```bash
# 安装 Homebrew（如果未安装）
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 安装新版 Bash
brew install bash

# 验证
bash --version  # 应该显示 5.x
```

**方案 3：使用包装脚本**
```bash
# wg-quick 包装脚本会自动查找 Bash 4+
sudo wg-quick up wg0
```

### 构建失败

#### Go 依赖下载超时

**症状**：构建时出现 `dial tcp xxx:443: i/o timeout` 错误

**解决方案**：
```bash
# 方案 1：使用国内 Go 代理
export GOPROXY=https://goproxy.cn,direct
./build.sh

# 方案 2：配置网络代理
export https_proxy=http://127.0.0.1:7890
export http_proxy=http://127.0.0.1:7890
./build.sh
```

#### wireguard-go 编译错误

**症状**：`invalid reference to syscall.recvmsg` 或其他链接错误

**原因**：wireguard-go 版本与 Go 编译器版本不兼容

**解决方案**：
```bash
# 检查 Go 版本
go version

# 使用兼容的 wireguard-go 版本
# Go 1.18-1.20: 使用 0.0.20230223
WG_GO_VERSION=0.0.20230223 ./build.sh

# Go 1.21+: 使用最新版本
WG_GO_VERSION=0.0.20250522 ./build.sh
```

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

A: 重新运行 build.sh 构建最新版本，然后重新安装：

```bash
# 更新到最新版本
cd wgtool-offline-macos
git pull
WG_TOOLS_VERSION=v1.0.20250521 WG_GO_VERSION=0.0.20250522 ./build.sh

# 在目标机器上重新安装
sudo ./install.sh
```

### Q: 离线包可以在其他 Mac 上使用吗？

A: 可以，但需要确保目标机器的 macOS 版本和架构兼容。

## 版本信息

**默认版本**：
- wireguard-tools: v1.0.20210914
- wireguard-go: 0.0.20230223

**可用版本**：

wireguard-tools:
- v1.0.20250521 (最新)
- v1.0.20210914 (稳定，推荐)
- v1.0.20210424

wireguard-go:
- 0.0.20250522 (最新，需要 Go 1.21+)
- 0.0.20230223 (稳定，兼容 Go 1.18+，推荐)
- 0.0.20220316 (旧版本，可能不兼容新 Go)

**自定义版本**：

```bash
# 使用环境变量指定版本
WG_TOOLS_VERSION=v1.0.20250521 WG_GO_VERSION=0.0.20250522 ./build.sh

# 或编辑 build.sh 文件，修改以下行：
# WG_TOOLS_VERSION="${WG_TOOLS_VERSION:-v1.0.20210914}"
# WG_GO_VERSION="${WG_GO_VERSION:-0.0.20230223}"
```

**版本兼容性**：
- Go 1.18-1.20: 推荐 wireguard-go 0.0.20230223
- Go 1.21+: 可使用 wireguard-go 0.0.20250522
- macOS 10.14+: 所有版本均支持

## 参考资料

- [WireGuard 官方网站](https://www.wireguard.com/)
- [wireguard-tools 源码](https://git.zx2c4.com/wireguard-tools/)
- [wireguard-go 源码](https://git.zx2c4.com/wireguard-go/)
- [WireGuard 快速入门](https://www.wireguard.com/quickstart/)

## 许可证

本项目脚本采用 MIT 许可证。WireGuard 相关组件遵循其原始许可证（GPLv2）。

## 贡献

欢迎提交 Issue 和 Pull Request。
