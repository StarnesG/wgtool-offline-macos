# wireguard-go 启动问题诊断

## 症状

wireguard-go 进程启动后立即退出，没有日志输出：

```
启动 wireguard-go...
执行: /usr/local/bin/wireguard-go utun
wireguard-go 进程 PID: 98032
❌ wireguard-go 进程已退出
```

## 诊断步骤

### 步骤 1：测试 wireguard-go

使用测试命令查看详细错误：

```bash
sudo /usr/local/scripts/wg-control.sh test
```

这会在前台运行 wireguard-go，显示所有输出。

**预期输出**（成功）：
```
INFO: (utun3) 2024/12/05 14:30:00 Starting wireguard-go version ...
```

**常见错误**：

#### 错误 1：权限问题
```
ERROR: Failed to create TUN device: operation not permitted
```

**解决**：确保使用 sudo
```bash
sudo /usr/local/scripts/wg-control.sh test
```

#### 错误 2：库依赖问题
```
dyld: Library not loaded: ...
```

**解决**：重新构建 wireguard-go
```bash
cd wireguard-go
make clean
make
```

#### 错误 3：无输出直接退出

可能是二进制文件问题。

### 步骤 2：检查二进制文件

```bash
# 检查文件类型
file /usr/local/bin/wireguard-go

# 应该显示：
# /usr/local/bin/wireguard-go: Mach-O 64-bit executable arm64

# 检查权限
ls -l /usr/local/bin/wireguard-go

# 应该显示：
# -rwxr-xr-x  1 root  wheel  4587442 Dec  5 14:22 /usr/local/bin/wireguard-go

# 检查扩展属性（可能阻止执行）
xattr -l /usr/local/bin/wireguard-go
```

如果有 `com.apple.quarantine` 属性：

```bash
# 移除隔离属性
sudo xattr -d com.apple.quarantine /usr/local/bin/wireguard-go
```

### 步骤 3：检查系统日志

```bash
# 查看系统日志
log show --predicate 'process == "wireguard-go"' --last 5m --info

# 或查看所有相关日志
log show --predicate 'eventMessage contains "wireguard"' --last 5m
```

### 步骤 4：检查进程

```bash
# 查看是否有僵尸进程
ps aux | grep wireguard-go

# 如果有多个进程，清理它们
sudo pkill -9 wireguard-go
```

### 步骤 5：手动测试完整流程

```bash
# 1. 启动 wireguard-go（前台）
sudo /usr/local/bin/wireguard-go utun3

# 如果成功，会显示：
# INFO: (utun3) ...

# 2. 在另一个终端，检查接口
ifconfig utun3

# 3. 配置接口（使用你的私钥）
echo "YOUR_PRIVATE_KEY" | sudo wg set utun3 private-key /dev/stdin

# 4. 查看状态
sudo wg show utun3

# 5. 停止（Ctrl+C 或）
sudo pkill wireguard-go
```

## 常见问题和解决方案

### 问题 1：二进制文件被隔离

**症状**：无输出直接退出

**检查**：
```bash
xattr -l /usr/local/bin/wireguard-go
```

**解决**：
```bash
sudo xattr -d com.apple.quarantine /usr/local/bin/wireguard-go
sudo xattr -d com.apple.quarantine /usr/local/bin/wg
```

### 问题 2：架构不匹配

**症状**：
```
Bad CPU type in executable
```

**检查**：
```bash
# 检查系统架构
uname -m
# arm64 (Apple Silicon) 或 x86_64 (Intel)

# 检查二进制架构
file /usr/local/bin/wireguard-go
```

**解决**：在正确的架构上重新构建

### 问题 3：权限问题

**症状**：
```
operation not permitted
```

**解决**：
```bash
# 确保使用 sudo
sudo /usr/local/scripts/wg-control.sh up wg0

# 检查文件权限
sudo chmod +x /usr/local/bin/wireguard-go
sudo chmod +x /usr/local/bin/wg
```

### 问题 4：端口被占用

**症状**：wireguard-go 启动但无法监听端口

**检查**：
```bash
# 查看配置的端口
grep ListenPort /usr/local/etc/wireguard/wg0.conf

# 检查端口占用（假设端口 51820）
sudo lsof -i :51820
```

**解决**：
```bash
# 停止占用端口的进程
sudo kill <PID>

# 或修改配置使用其他端口
```

### 问题 5：utun 设备不可用

**症状**：
```
Failed to create TUN device
```

**检查**：
```bash
# 查看现有 utun 设备
ifconfig | grep utun

# 查看设备文件
ls -l /dev/utun*
```

**解决**：
- 如果没有 utun 设备，可能需要重启系统
- 检查是否有其他 VPN 占用了所有 utun 设备

### 问题 6：Go 运行时问题

**症状**：无输出或崩溃

**检查**：
```bash
# 检查 Go 版本（如果系统有 Go）
go version

# 检查二进制依赖
otool -L /usr/local/bin/wireguard-go
```

**解决**：重新构建 wireguard-go

## 重新构建 wireguard-go

如果二进制文件有问题，重新构建：

```bash
# 1. 进入源码目录
cd /path/to/wgtool-offline-macos

# 2. 清理旧文件
rm -rf wireguard-go

# 3. 重新构建
./build.sh

# 4. 重新安装
sudo ./install.sh
```

## 手动安装 wireguard-go

如果自动构建失败，可以手动下载预编译版本：

### 方式 1：从官方下载

```bash
# 下载最新版本
curl -LO https://git.zx2c4.com/wireguard-go/snapshot/wireguard-go-0.0.20230223.tar.xz

# 解压
tar -xf wireguard-go-0.0.20230223.tar.xz
cd wireguard-go-0.0.20230223

# 构建
make

# 安装
sudo cp wireguard-go /usr/local/bin/
sudo chmod +x /usr/local/bin/wireguard-go
```

### 方式 2：使用 Homebrew

```bash
# 安装 wireguard-tools（包含 wireguard-go）
brew install wireguard-tools

# 链接到标准位置
sudo ln -sf $(brew --prefix)/bin/wireguard-go /usr/local/bin/wireguard-go
```

## 验证安装

```bash
# 1. 检查文件
ls -l /usr/local/bin/wireguard-go
file /usr/local/bin/wireguard-go

# 2. 测试运行
sudo /usr/local/scripts/wg-control.sh test

# 3. 查看版本（如果支持）
/usr/local/bin/wireguard-go --version 2>&1 || echo "版本信息不可用"

# 4. 完整测试
sudo /usr/local/scripts/wg-control.sh up wg0
```

## 调试技巧

### 启用详细日志

编辑控制脚本，在 wireguard-go 启动命令前添加：

```bash
# 设置日志级别
export LOG_LEVEL=verbose

# 或使用 strace（如果可用）
sudo dtruss -f /usr/local/bin/wireguard-go utun 2>&1 | tee debug.log
```

### 使用 lldb 调试

如果 wireguard-go 崩溃：

```bash
# 使用 lldb 运行
sudo lldb /usr/local/bin/wireguard-go

# 在 lldb 中：
(lldb) run utun
(lldb) bt  # 如果崩溃，查看堆栈
```

### 检查系统限制

```bash
# 检查文件描述符限制
ulimit -n

# 检查进程限制
ulimit -u

# 如果太低，增加限制
ulimit -n 4096
```

## 获取帮助

如果以上方法都无法解决：

1. **收集信息**：
   ```bash
   # 系统信息
   sw_vers > system-info.txt
   uname -a >> system-info.txt
   
   # 二进制信息
   file /usr/local/bin/wireguard-go >> system-info.txt
   ls -l /usr/local/bin/wireguard-go >> system-info.txt
   xattr -l /usr/local/bin/wireguard-go >> system-info.txt
   
   # 测试输出
   sudo /usr/local/scripts/wg-control.sh test 2>&1 | tee test-output.txt
   
   # 诊断信息
   sudo /usr/local/scripts/wg-control.sh diag > diag-output.txt
   ```

2. **查看官方文档**：
   - [wireguard-go GitHub](https://github.com/WireGuard/wireguard-go)
   - [WireGuard 官方网站](https://www.wireguard.com/)

3. **社区支持**：
   - [WireGuard 邮件列表](https://lists.zx2c4.com/mailman/listinfo/wireguard)
   - [WireGuard Reddit](https://www.reddit.com/r/WireGuard/)

## 临时解决方案

如果 wireguard-go 无法工作，可以考虑：

### 方案 1：使用 Homebrew 版本

```bash
# 安装 Homebrew 版本
brew install wireguard-tools

# 使用 Homebrew 的 wg-quick
sudo $(brew --prefix)/bin/wg-quick up wg0
```

### 方案 2：使用 WireGuard 官方 App

从 App Store 安装 WireGuard 官方应用，导入配置文件。

### 方案 3：使用其他 VPN 方案

如果 WireGuard 无法工作，考虑其他 VPN 解决方案。

## 参考资料

- [wireguard-go 源码](https://git.zx2c4.com/wireguard-go/)
- [WireGuard macOS 文档](https://www.wireguard.com/install/)
- [macOS TUN/TAP 文档](https://developer.apple.com/documentation/network)
- [项目故障排查](TROUBLESHOOTING.md)
