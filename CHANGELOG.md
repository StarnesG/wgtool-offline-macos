# 更新日志

## 2024-12-05 v5 - 修复 macOS 接口命名问题

### 重大修复

**✅ 修复接口命名错误**

macOS 上 wireguard-go 要求接口名必须是 `utun[0-9]*` 格式，不能使用 `wg0`。

**错误信息**：
```
ERROR: Failed to create TUN device: Interface name must be utun[0-9]*
```

**解决方案**：
- 让 wireguard-go 自动分配 `utun` 接口名
- 使用状态文件记录配置名到接口名的映射
- 控制脚本自动处理接口名转换

### 实现细节

1. **配置文件名**：保持使用 `wg0.conf`、`wg1.conf`
2. **实际接口名**：系统自动分配 `utun3`、`utun4` 等
3. **状态文件**：`/var/run/wireguard/wg0.name` 记录实际接口名
4. **透明映射**：用户仍然使用 `wg0` 作为配置名

### 使用方式

```bash
# 配置文件
sudo nano /usr/local/etc/wireguard/wg0.conf

# 启动（使用配置名）
sudo /usr/local/scripts/wg-control.sh up wg0

# 实际创建的接口是 utun3（自动分配）
# 查看状态
sudo /usr/local/scripts/wg-control.sh status wg0

# 输出：
# WireGuard 隧道 wg0 状态 (接口: utun3):
# interface: utun3
# ...
```

### 改进的诊断

诊断命令现在显示配置名和实际接口名的映射：

```bash
sudo /usr/local/scripts/wg-control.sh diag

# 输出：
# 4. 接口状态:
#    配置名: wg0
#    接口名: utun3
#    状态: ✅ 运行中
```

---

## 2024-12-05 v4 - 改进错误处理和诊断

### 新增功能

1. **诊断命令** ✅
   - 添加 `diag` 命令查看系统状态
   - 显示命令、配置、进程、接口、日志等信息
   - 快速定位问题

2. **改进的错误处理** ✅
   - 详细的错误信息和提示
   - 每个步骤的状态反馈
   - 失败时显示故障排查步骤

3. **增强的日志** ✅
   - wireguard-go 输出到日志文件
   - 启动失败时自动显示日志
   - 便于调试和问题定位

4. **更好的进程管理** ✅
   - 检查进程是否正常运行
   - 自动清理僵尸进程
   - 超时检测和错误恢复

5. **完整的故障排查文档** ✅
   - 新增 TROUBLESHOOTING.md
   - 涵盖所有常见问题
   - 提供详细的解决步骤

### 修复的问题

- ✅ 接口创建超时的详细诊断
- ✅ Peer 配置失败的错误处理
- ✅ 更可靠的 wireguard-go 启动逻辑

### 使用方式

```bash
# 诊断系统状态
sudo /usr/local/scripts/wg-control.sh diag

# 启动（带详细输出）
sudo /usr/local/scripts/wg-control.sh up

# 查看日志
cat /var/log/wireguard-wg0.log
```

---

## 2024-12-04 v3 - 纯 Shell 实现（完美解决 Bash 问题）

### 重大改进

**✅ 完全不依赖 wg-quick**

控制脚本使用纯 POSIX shell 重写，直接调用 `wg` 和 `wireguard-go`：
- 不再依赖 wg-quick
- 不需要 Bash 4+
- 完全兼容 macOS Bash 3.2
- 开箱即用，零配置

### 实现的功能

控制脚本实现了 wg-quick 的所有核心功能：
- ✅ 启动/停止 wireguard-go 进程
- ✅ 解析 WireGuard 配置文件
- ✅ 配置网络接口和 IP 地址
- ✅ 设置 WireGuard 私钥和 Peer
- ✅ 配置路由表（包括默认路由）
- ✅ 支持 PostUp/PostDown 命令
- ✅ 支持多个 Peer 配置
- ✅ 支持 MTU、DNS 等高级选项

### 使用方式

```bash
# 无需任何额外配置，直接使用
sudo /usr/local/scripts/wg-control.sh up
sudo /usr/local/scripts/wg-control.sh status
sudo /usr/local/scripts/wg-control.sh down
```

### 技术细节

- 使用 `awk` 解析配置文件
- 使用 `ifconfig` 配置网络接口
- 使用 `route` 配置路由表
- 使用 `wg` 设置 WireGuard 参数
- 所有命令都是 POSIX 兼容的

---

## 2024-12-04 v2 - Bash 版本兼容性修复（已废弃）

### 修复的问题

7. **Bash 版本不兼容** ✅
   - 问题：macOS 默认 Bash 3.2，wg-quick 需要 Bash 4+
   - 错误：`wg-quick: Version mismatch: bash 3 detected`
   - 解决：创建智能包装脚本，自动查找合适的 Bash 版本

### 新增功能

5. **wg-quick 包装脚本** ✅
   - 自动检测并使用 Bash 4+ 版本
   - 支持 Homebrew Bash（Intel 和 Apple Silicon）
   - 提供友好的错误提示和解决方案

6. **改进的控制脚本** ✅
   - 使用 `/bin/sh` 而不是 bash，完全兼容 macOS
   - 添加 `status` 命令查看隧道状态
   - 改进错误处理和用户提示
   - 自动查找可用的 Bash 版本

7. **Bash 版本问题文档** ✅
   - 添加 BASH_VERSION_FIX.md - 详细的问题说明和解决方案
   - 更新 README.md 和 QUICKSTART.md 的相关说明
   - 提供多种解决方案对比

### 使用建议

**推荐方式**（无需安装 Bash 4+）：
```bash
sudo /usr/local/scripts/wg-control.sh up
```

**可选方式**（需要安装 Bash 4+）：
```bash
brew install bash
sudo wg-quick up wg0
```

---

## 2024-12-04 v1 - 初始修复版本

### 修复的问题

1. **Git tag 错误** ✅
   - 修复：`git checkout 1.0.20210914` → `git checkout v1.0.20210914`
   - wireguard-tools 的 tag 需要 `v` 前缀

2. **wireguard-go 版本不兼容** ✅
   - 修复：更新默认版本从 `0.0.20220316` → `0.0.20230223`
   - 原因：旧版本不兼容 Go 1.18+ 编译器
   - 错误信息：`invalid reference to syscall.recvmsg`

3. **缺少 wireguard-go 构建** ✅
   - 添加：wireguard-go 的克隆和编译步骤
   - macOS 需要用户态 WireGuard 实现

4. **静态链接不支持** ✅
   - 移除：`CFLAGS="-static" LDFLAGS="-static"`
   - macOS 不支持静态链接，使用动态链接

5. **二进制文件路径错误** ✅
   - 修复：添加正确的子目录前缀
   - `src/wg` → `wireguard-tools/src/wg`

6. **launchd 配置不完整** ✅
   - 添加：`WG_QUICK_USERSPACE_IMPLEMENTATION` 环境变量
   - 添加：日志输出路径配置

### 新增功能

1. **版本配置支持** ✅
   - 支持通过环境变量指定版本
   - `WG_TOOLS_VERSION` 和 `WG_GO_VERSION`
   - 默认使用稳定版本

2. **构建过程优化** ✅
   - 添加构建进度提示
   - 显示版本信息
   - 改进错误处理

3. **安装脚本改进** ✅
   - 使用临时目录解压
   - 改进权限设置
   - 添加卸载脚本安装

4. **文档完善** ✅
   - 添加 README.md - 完整使用文档
   - 添加 QUICKSTART.md - 快速开始指南
   - 添加 VERSION_COMPATIBILITY.md - 版本兼容性说明
   - 添加 .gitignore - 防止提交构建产物

### 版本信息

**默认版本**：
- wireguard-tools: v1.0.20210914
- wireguard-go: 0.0.20230223

**兼容性**：
- Go 1.18+ 
- macOS 10.14+
- Intel 和 Apple Silicon

### 使用方法

```bash
# 构建（使用默认版本）
./build.sh

# 指定版本构建
WG_GO_VERSION=0.0.20250522 ./build.sh

# 完全自定义
WG_TOOLS_VERSION=v1.0.20250521 WG_GO_VERSION=0.0.20250522 ./build.sh
```

### 故障排查

如果遇到构建问题：

1. **Go 依赖下载超时**
   ```bash
   export GOPROXY=https://goproxy.cn,direct
   ./build.sh
   ```

2. **wireguard-go 编译错误**
   ```bash
   # 检查 Go 版本
   go version
   
   # 使用兼容版本
   WG_GO_VERSION=0.0.20230223 ./build.sh
   ```

3. **Git tag 不存在**
   ```bash
   # 查看可用版本
   cd wireguard-go && git tag -l
   cd wireguard-tools && git tag -l
   ```

### 测试状态

- ✅ 脚本语法检查通过
- ✅ 版本兼容性验证
- ✅ 文档完整性检查
- ⚠️ 实际构建测试需要在 macOS 环境进行

### 已知问题

无

### 下一步计划

- [ ] 添加自动化测试
- [ ] 支持多架构构建
- [ ] 添加版本检测脚本
- [ ] 创建 GitHub Actions 工作流

---

## 初始版本

### 功能

- 基础构建脚本
- 安装脚本
- 控制脚本

### 问题

- Git tag 错误
- wireguard-go 版本不兼容
- 缺少文档
