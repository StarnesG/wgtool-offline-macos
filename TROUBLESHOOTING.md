# 故障排查指南

## 重要说明

### macOS 接口命名

⚠️ **重要**：macOS 上 wireguard-go 使用 `utun` 接口名（如 `utun3`、`utun4`），不是 `wg0`。

- **配置文件名**：仍然使用 `wg0.conf`、`wg1.conf` 等
- **实际接口名**：系统自动分配为 `utun3`、`utun4` 等
- **控制脚本**：自动处理接口名映射

示例：
```bash
# 配置文件
/usr/local/etc/wireguard/wg0.conf

# 启动后实际接口
utun3

# 使用控制脚本（自动处理）
sudo /usr/local/scripts/wg-control.sh up wg0
```

---

## 快速诊断

运行诊断命令查看系统状态：

```bash
sudo /usr/local/scripts/wg-control.sh diag
```

这会显示：
- 命令是否存在
- 配置文件状态（wg0.conf）
- 实际接口名（utun3）
- 进程运行情况
- 网络接口状态
- 日志信息

---

## 常见问题

### 1. 错误：接口创建超时或接口名错误

**症状**：
```
启动 wireguard-go...
错误：接口创建超时
```

或

```
ERROR: Failed to create TUN device: Interface name must be utun[0-9]*
```

**原因**：
- macOS 上 wireguard-go 要求接口名必须是 `utun` 开头加数字
- 不能使用 `wg0`、`wg1` 等名称

**解决方案**：

✅ **已修复**：最新版本的控制脚本会自动使用 `utun` 接口名。

#### 步骤 1：重新构建和安装

```bash
# 重新构建（获取最新修复）
cd wgtool-offline-macos
./build.sh

# 重新安装
sudo ./install.sh
```

#### 步骤 2：手动测试 wireguard-go

```bash
# 正确的方式：让 wireguard-go 自动分配接口名
sudo /usr/local/bin/wireguard-go utun
```

观察输出：
- 成功：会显示类似 `INFO: (utun3) ...`
- 失败：会显示错误信息

常见错误：
- `operation not permitted`: 权限问题，确保使用 sudo
- `address already in use`: 端口被占用
- `Interface name must be utun[0-9]*`: 接口名错误（已修复）

#### 步骤 3：检查 utun 设备

```bash
ls -l /dev/utun*
```

应该看到类似：
```
crw-rw-rw-  1 root  wheel   38,   0 Dec  5 10:00 /dev/utun0
crw-rw-rw-  1 root  wheel   38,   1 Dec  5 10:00 /dev/utun1
```

如果没有 utun 设备，可能需要重启系统。

#### 步骤 4：查看日志

```bash
# 查看 wireguard-go 日志
cat /var/log/wireguard-wg0.log

# 查看系统日志
log show --predicate 'process == "wireguard-go"' --last 5m
```

#### 步骤 5：检查是否有其他 VPN 冲突

```bash
# 查看所有 utun 接口
ifconfig | grep utun

# 查看所有 wireguard-go 进程
ps aux | grep wireguard-go
```

如果有其他 VPN 运行，可能需要先停止。

---

### 2. 错误：配置文件中未找到 PrivateKey

**症状**：
```
错误：配置文件中未找到 PrivateKey
```

**原因**：配置文件格式错误或缺少必要字段

**解决步骤**：

#### 检查配置文件

```bash
sudo cat /usr/local/etc/wireguard/wg0.conf
```

确保包含 `[Interface]` 部分和 `PrivateKey`：

```ini
[Interface]
PrivateKey = YOUR_PRIVATE_KEY_HERE
Address = 10.0.0.2/24

[Peer]
PublicKey = SERVER_PUBLIC_KEY_HERE
Endpoint = vpn.example.com:51820
AllowedIPs = 0.0.0.0/0
```

#### 生成密钥

如果没有密钥：

```bash
# 生成私钥
wg genkey | sudo tee /usr/local/etc/wireguard/privatekey

# 生成公钥
sudo cat /usr/local/etc/wireguard/privatekey | wg pubkey | sudo tee /usr/local/etc/wireguard/publickey

# 查看密钥
echo "私钥:"
sudo cat /usr/local/etc/wireguard/privatekey
echo "公钥:"
sudo cat /usr/local/etc/wireguard/publickey
```

然后将私钥添加到配置文件。

---

### 3. 隧道启动但无法连接

**症状**：隧道显示已启动，但无法访问网络

**诊断步骤**：

#### 步骤 1：检查接口状态

```bash
sudo /usr/local/scripts/wg-control.sh status
```

应该显示：
- 接口信息
- Peer 信息
- 最后握手时间
- 传输数据量

#### 步骤 2：检查 Peer 握手

```bash
sudo wg show wg0
```

查看 `latest handshake` 字段：
- 如果显示时间，说明连接正常
- 如果没有显示，说明未建立连接

#### 步骤 3：测试连接

```bash
# Ping VPN 网关
ping -c 4 10.0.0.1

# 如果配置了全局路由，测试外网
ping -c 4 8.8.8.8
```

#### 步骤 4：检查路由

```bash
# 查看路由表
netstat -rn | grep utun

# 应该看到类似：
# 0/1                10.0.0.1           UGSc           utun3
# 128.0.0.0/1        10.0.0.1           UGSc           utun3
```

#### 步骤 5：检查防火墙

macOS 防火墙可能阻止连接：

```bash
# 查看防火墙状态
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate

# 如果启用，可能需要添加例外
```

---

### 4. 权限错误

**症状**：
```
错误：此脚本需要 root 权限
```

**解决**：使用 sudo 运行

```bash
sudo /usr/local/scripts/wg-control.sh up
```

---

### 5. 命令不存在

**症状**：
```
错误：缺少必要的命令: wg wireguard-go
```

**原因**：未正确安装或路径错误

**解决步骤**：

#### 检查安装

```bash
# 检查文件是否存在
ls -l /usr/local/bin/wg
ls -l /usr/local/bin/wireguard-go

# 检查权限
ls -l /usr/local/bin/wg*
```

#### 重新安装

```bash
sudo ./install.sh
```

#### 手动安装

如果自动安装失败：

```bash
# 解压离线包
tar -xzf wireguard-tools-macos-universal.tar.gz

# 手动复制文件
sudo cp WireGuard-Offline/bin/* /usr/local/bin/
sudo chmod +x /usr/local/bin/{wg,wireguard-go}
sudo cp WireGuard-Offline/scripts/wg-control.sh /usr/local/scripts/
sudo chmod +x /usr/local/scripts/wg-control.sh
```

---

### 6. 端口被占用

**症状**：wireguard-go 启动失败，日志显示端口被占用

**解决步骤**：

#### 检查端口占用

```bash
# 查看配置的端口
grep ListenPort /usr/local/etc/wireguard/wg0.conf

# 检查端口是否被占用（假设端口是 51820）
sudo lsof -i :51820
```

#### 解决方案

1. 停止占用端口的程序
2. 或修改配置文件使用其他端口

```ini
[Interface]
ListenPort = 51821  # 使用其他端口
```

---

### 7. DNS 不工作

**症状**：可以 ping IP 但无法解析域名

**原因**：DNS 配置未生效

**解决步骤**：

#### 方案 1：手动配置 DNS

```bash
# 查看当前 DNS
scutil --dns

# 使用 networksetup 配置 DNS
sudo networksetup -setdnsservers Wi-Fi 1.1.1.1 8.8.8.8
```

#### 方案 2：使用 PostUp 命令

在配置文件中添加：

```ini
[Interface]
PrivateKey = ...
Address = 10.0.0.2/24
PostUp = networksetup -setdnsservers Wi-Fi 1.1.1.1
PostDown = networksetup -setdnsservers Wi-Fi Empty
```

---

### 8. 路由配置失败

**症状**：接口启动但路由未添加

**诊断**：

```bash
# 查看路由表
netstat -rn

# 手动添加路由测试
sudo route add -net 10.0.0.0/24 -interface utun3
```

**常见问题**：
- 路由冲突：已存在相同的路由
- 接口未启动：先确保接口 up
- 权限问题：确保使用 sudo

---

### 9. 多个隧道冲突

**症状**：启动第二个隧道时失败

**解决**：

```bash
# 查看所有 WireGuard 接口
sudo wg show

# 停止不需要的隧道
sudo /usr/local/scripts/wg-control.sh down wg0

# 启动新隧道
sudo /usr/local/scripts/wg-control.sh up wg1
```

---

### 10. 配置文件权限错误

**症状**：无法读取配置文件

**解决**：

```bash
# 设置正确的权限
sudo chmod 700 /usr/local/etc/wireguard
sudo chmod 600 /usr/local/etc/wireguard/*.conf

# 检查所有者
sudo chown root:wheel /usr/local/etc/wireguard/*.conf
```

---

## 调试技巧

### 启用详细日志

编辑控制脚本，在开头添加：

```bash
set -x  # 显示执行的命令
```

### 手动执行步骤

```bash
# 1. 启动 wireguard-go
sudo /usr/local/bin/wireguard-go wg0

# 2. 设置私钥
echo "YOUR_PRIVATE_KEY" | sudo wg set wg0 private-key /dev/stdin

# 3. 配置 IP
sudo ifconfig wg0 inet 10.0.0.2/24 10.0.0.2 alias

# 4. 添加 Peer
sudo wg set wg0 peer SERVER_PUBLIC_KEY \
    endpoint vpn.example.com:51820 \
    allowed-ips 0.0.0.0/0 \
    persistent-keepalive 25

# 5. 启动接口
sudo ifconfig wg0 up

# 6. 添加路由
sudo route add -net 0.0.0.0/1 -interface wg0
sudo route add -net 128.0.0.0/1 -interface wg0
```

### 查看实时日志

```bash
# 监控 wireguard-go 日志
tail -f /var/log/wireguard-wg0.log

# 监控系统日志
log stream --predicate 'process == "wireguard-go"'
```

---

## 获取帮助

如果以上方法都无法解决问题：

1. **运行诊断命令**：
   ```bash
   sudo /usr/local/scripts/wg-control.sh diag > wg-diag.txt
   ```

2. **收集日志**：
   ```bash
   cat /var/log/wireguard-wg0.log > wg-log.txt
   ```

3. **检查配置**（移除敏感信息）：
   ```bash
   sudo cat /usr/local/etc/wireguard/wg0.conf | \
       sed 's/PrivateKey.*/PrivateKey = [REDACTED]/' | \
       sed 's/PresharedKey.*/PresharedKey = [REDACTED]/' > wg-config.txt
   ```

4. **提供系统信息**：
   ```bash
   sw_vers > system-info.txt
   uname -a >> system-info.txt
   ```

然后将这些文件提供给技术支持。

---

## 参考资料

- [WireGuard 官方文档](https://www.wireguard.com/)
- [macOS 网络配置](https://developer.apple.com/documentation/network)
- [项目 README](README.md)
- [技术实现细节](TECHNICAL_DETAILS.md)
