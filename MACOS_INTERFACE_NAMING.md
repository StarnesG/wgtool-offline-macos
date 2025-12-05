# macOS 接口命名说明

## 核心概念

在 macOS 上，WireGuard 使用的接口名与配置文件名**不同**：

| 概念 | 名称 | 示例 | 说明 |
|------|------|------|------|
| **配置文件** | `wg0.conf` | `/usr/local/etc/wireguard/wg0.conf` | 用户创建的配置文件 |
| **配置名** | `wg0` | `wg0`, `wg1`, `home`, `office` | 用于控制脚本的标识符 |
| **实际接口** | `utunX` | `utun3`, `utun4`, `utun5` | 系统自动分配的接口名 |

## 为什么不同？

### Linux 行为
```bash
# Linux 上可以指定接口名
wg-quick up wg0
# 创建接口：wg0
```

### macOS 限制
```bash
# macOS 上必须使用 utun 接口名
wireguard-go wg0
# ❌ 错误：Interface name must be utun[0-9]*

wireguard-go utun
# ✅ 成功：自动分配 utun3
```

**原因**：macOS 的 TUN/TAP 驱动要求接口名必须是 `utun` 开头加数字。

## 控制脚本的处理

控制脚本自动处理接口名映射：

```bash
# 1. 用户使用配置名
sudo /usr/local/scripts/wg-control.sh up wg0

# 2. 脚本启动 wireguard-go
wireguard-go utun  # 自动分配 utun3

# 3. 脚本记录映射关系
echo "utun3" > /var/run/wireguard/wg0.name

# 4. 后续操作使用实际接口名
wg set utun3 ...
ifconfig utun3 ...
```

## 使用示例

### 创建配置

```bash
# 配置文件名：wg0.conf
sudo nano /usr/local/etc/wireguard/wg0.conf
```

### 启动隧道

```bash
# 使用配置名 wg0
sudo /usr/local/scripts/wg-control.sh up wg0

# 输出：
# 启动 WireGuard 隧道: wg0
# 启动 wireguard-go...
# ✅ 接口 utun3 已创建
# ...
# ✅ 隧道启动成功
#    配置: wg0
#    接口: utun3
```

### 查看状态

```bash
sudo /usr/local/scripts/wg-control.sh status wg0

# 输出：
# WireGuard 隧道 wg0 状态 (接口: utun3):
# interface: utun3
# public key: ...
# private key: (hidden)
# listening port: 51820
```

### 使用 wg 命令

```bash
# 方式 1：使用控制脚本（推荐）
sudo /usr/local/scripts/wg-control.sh status wg0

# 方式 2：直接使用 wg 命令（需要知道实际接口名）
sudo wg show utun3

# 方式 3：查看所有接口
sudo wg show
```

### 停止隧道

```bash
# 使用配置名
sudo /usr/local/scripts/wg-control.sh down wg0

# 脚本会自动找到对应的 utun3 接口并停止
```

## 多隧道场景

### 配置文件

```bash
/usr/local/etc/wireguard/
├── wg0.conf    # 家庭网络
├── wg1.conf    # 公司网络
└── vpn.conf    # 其他 VPN
```

### 启动多个隧道

```bash
# 启动家庭网络
sudo /usr/local/scripts/wg-control.sh up wg0
# 实际接口：utun3

# 启动公司网络
sudo /usr/local/scripts/wg-control.sh up wg1
# 实际接口：utun4

# 启动其他 VPN
sudo /usr/local/scripts/wg-control.sh up vpn
# 实际接口：utun5
```

### 查看所有隧道

```bash
# 查看所有 WireGuard 接口
sudo wg show

# 输出：
# interface: utun3
# ...
# 
# interface: utun4
# ...
# 
# interface: utun5
# ...
```

### 状态文件

```bash
/var/run/wireguard/
├── wg0.name    # 内容：utun3
├── wg1.name    # 内容：utun4
└── vpn.name    # 内容：utun5
```

## 诊断命令

```bash
sudo /usr/local/scripts/wg-control.sh diag wg0

# 输出：
# === WireGuard 诊断信息 ===
# 
# 2. 配置文件:
#    名称: wg0
#    路径: /usr/local/etc/wireguard/wg0.conf
#    状态: ✅ 存在
# 
# 4. 接口状态:
#    配置名: wg0
#    接口名: utun3
#    状态: ✅ 运行中
# 
# 7. 状态文件:
#    路径: /var/run/wireguard/wg0.name
#    状态: ✅ 存在
#    内容: utun3
```

## 手动操作

如果需要手动操作，需要知道实际接口名：

### 查找接口名

```bash
# 方式 1：从状态文件读取
cat /var/run/wireguard/wg0.name
# 输出：utun3

# 方式 2：查看所有 utun 接口
ifconfig | grep utun
# 输出：
# utun0: flags=...
# utun1: flags=...
# utun3: flags=...  <- WireGuard 接口
```

### 手动配置

```bash
# 获取接口名
IFACE=$(cat /var/run/wireguard/wg0.name)

# 使用 wg 命令
sudo wg show $IFACE
sudo wg set $IFACE peer ...

# 使用 ifconfig
sudo ifconfig $IFACE
sudo ifconfig $IFACE down
```

## 常见问题

### Q: 为什么不能使用 wg0 作为接口名？

A: macOS 的 TUN/TAP 驱动限制，接口名必须是 `utun[0-9]*` 格式。这是系统级限制，无法绕过。

### Q: 接口号会变吗？

A: 会。每次启动时系统会自动分配下一个可用的 utun 号码。控制脚本使用状态文件记录映射关系。

### Q: 如何固定接口号？

A: 无法固定。但控制脚本会自动处理，用户无需关心实际接口号。

### Q: 可以手动指定 utun3 吗？

A: 可以尝试，但如果 utun3 已被占用，会失败。推荐让系统自动分配。

```bash
# 手动指定（可能失败）
sudo wireguard-go utun3

# 自动分配（推荐）
sudo wireguard-go utun
```

### Q: 重启后接口号会变吗？

A: 会。重启后需要重新启动 WireGuard，系统会分配新的接口号。

### Q: 如何在脚本中使用？

A: 使用控制脚本或读取状态文件：

```bash
# 方式 1：使用控制脚本
sudo /usr/local/scripts/wg-control.sh up wg0

# 方式 2：读取状态文件
IFACE=$(cat /var/run/wireguard/wg0.name)
sudo wg show $IFACE
```

## 总结

| 操作 | 使用配置名 | 使用实际接口名 |
|------|-----------|--------------|
| 启动隧道 | `wg-control.sh up wg0` | ❌ 不需要 |
| 停止隧道 | `wg-control.sh down wg0` | ❌ 不需要 |
| 查看状态 | `wg-control.sh status wg0` | `wg show utun3` |
| 配置 Peer | ❌ 不支持 | `wg set utun3 peer ...` |
| 查看接口 | ❌ 不支持 | `ifconfig utun3` |

**推荐**：始终使用控制脚本，它会自动处理接口名映射。

## 参考

- [wireguard-go 源码](https://git.zx2c4.com/wireguard-go/)
- [macOS TUN/TAP 文档](https://developer.apple.com/documentation/network)
- [项目文档](README.md)
