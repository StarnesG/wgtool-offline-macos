# WireGuard macOS 离线包 - 完整解决方案

## 问题总结

### 原始问题
1. ❌ `pathspec '1.0.20210914' did not match any file(s)` - Git tag 错误
2. ❌ `invalid reference to syscall.recvmsg` - wireguard-go 版本不兼容
3. ❌ `wg-quick: Version mismatch: bash 3 detected` - Bash 版本问题

### 解决方案
1. ✅ 修正 Git tag 为 `v1.0.20210914`
2. ✅ 更新 wireguard-go 到 `0.0.20230223`（兼容 Go 1.18+）
3. ✅ 创建智能包装脚本和控制脚本，自动处理 Bash 版本

---

## 文件清单

### 核心脚本
- `build.sh` (4.2K) - 构建脚本，生成离线包
- `install.sh` (1.4K) - 安装脚本，部署到目标机器
- `wg-control.sh` (493B) - 控制脚本模板

### 文档
- `README.md` (9.7K) - 完整使用文档
- `QUICKSTART.md` (3.1K) - 快速开始指南
- `BASH_VERSION_FIX.md` (5.8K) - Bash 版本问题详解
- `VERSION_COMPATIBILITY.md` (3.2K) - 版本兼容性说明
- `USAGE_EXAMPLES.md` (7.2K) - 使用示例集合
- `CHANGELOG.md` (2.9K) - 更新日志

### 配置
- `.gitignore` - Git 忽略规则

---

## 快速使用

### 构建（有网络的机器）

```bash
git clone https://github.com/StarnesG/wgtool-offline-macos.git
cd wgtool-offline-macos

# 配置代理（如果需要）
export GOPROXY=https://goproxy.cn,direct

# 构建
chmod +x build.sh
./build.sh
```

### 安装（目标机器）

```bash
chmod +x install.sh
sudo ./install.sh
```

### 配置

```bash
sudo nano /usr/local/etc/wireguard/wg0.conf
sudo chmod 600 /usr/local/etc/wireguard/wg0.conf
```

### 启动

```bash
# 推荐方式（无需 Bash 4+）
sudo /usr/local/scripts/wg-control.sh up

# 查看状态
sudo /usr/local/scripts/wg-control.sh status
```

---

## 核心特性

### 1. Bash 版本兼容
- ✅ 智能包装脚本，自动查找 Bash 4+
- ✅ 控制脚本使用 POSIX sh，完全兼容
- ✅ 提供多种解决方案

### 2. 版本管理
- ✅ 支持环境变量自定义版本
- ✅ 默认使用稳定版本
- ✅ 兼容 Go 1.18+

### 3. 完整功能
- ✅ wg - 命令行工具
- ✅ wg-quick - 快速启停
- ✅ wireguard-go - 用户态实现
- ✅ 控制脚本 - 友好接口
- ✅ launchd 服务 - 开机自启
- ✅ 卸载脚本 - 完整清理

### 4. 文档完善
- ✅ 详细的使用文档
- ✅ 快速开始指南
- ✅ 故障排查方案
- ✅ 使用示例集合

---

## 版本信息

### 默认版本（推荐）
- wireguard-tools: v1.0.20210914
- wireguard-go: 0.0.20230223
- 兼容：Go 1.18+, macOS 10.14+

### 最新版本
- wireguard-tools: v1.0.20250521
- wireguard-go: 0.0.20250522
- 需要：Go 1.21+

### 自定义版本
```bash
WG_TOOLS_VERSION=v1.0.20250521 WG_GO_VERSION=0.0.20250522 ./build.sh
```

---

## 常见问题

### Q1: Bash 版本错误怎么办？
**A**: 使用控制脚本（推荐）
```bash
sudo /usr/local/scripts/wg-control.sh up
```
或安装 Bash 4+：
```bash
brew install bash
```

### Q2: Go 依赖下载超时？
**A**: 配置代理或使用国内镜像
```bash
export GOPROXY=https://goproxy.cn,direct
```

### Q3: wireguard-go 编译失败？
**A**: 检查 Go 版本并使用兼容版本
```bash
go version
WG_GO_VERSION=0.0.20230223 ./build.sh
```

### Q4: 如何查看隧道状态？
**A**: 使用控制脚本或 wg 命令
```bash
sudo /usr/local/scripts/wg-control.sh status
sudo wg show wg0
```

### Q5: 如何配置开机自启？
**A**: 安装时选择 'y'，或手动配置
```bash
sudo cp /usr/local/service/com.wireguard.offline.plist /Library/LaunchDaemons/
sudo launchctl load -w /Library/LaunchDaemons/com.wireguard.offline.plist
```

---

## 推荐工作流

### 日常使用
```bash
# 启动
sudo /usr/local/scripts/wg-control.sh up

# 查看状态
sudo /usr/local/scripts/wg-control.sh status

# 停止
sudo /usr/local/scripts/wg-control.sh down
```

### 故障排查
```bash
# 检查配置
sudo wg-quick strip wg0

# 查看详细状态
sudo wg show wg0 dump

# 查看日志
tail -f /var/log/wireguard.log
```

### 更新版本
```bash
# 构建新版本
cd wgtool-offline-macos
git pull
./build.sh

# 重新安装
sudo ./install.sh
```

---

## 技术亮点

1. **智能 Bash 检测**
   - 自动查找 Homebrew Bash（Intel/Apple Silicon）
   - 降级到系统 Bash 并处理错误
   - 提供友好的错误提示

2. **POSIX Shell 兼容**
   - 控制脚本使用 `/bin/sh`
   - 完全兼容 macOS 默认环境
   - 无需安装额外依赖

3. **版本灵活配置**
   - 环境变量控制版本
   - 默认使用稳定版本
   - 支持最新版本

4. **完整的生命周期**
   - 构建 → 安装 → 配置 → 使用 → 卸载
   - 每个环节都有详细文档
   - 提供多种使用方式

---

## 文档导航

- **新手入门**: [QUICKSTART.md](QUICKSTART.md)
- **完整文档**: [README.md](README.md)
- **Bash 问题**: [BASH_VERSION_FIX.md](BASH_VERSION_FIX.md)
- **版本说明**: [VERSION_COMPATIBILITY.md](VERSION_COMPATIBILITY.md)
- **使用示例**: [USAGE_EXAMPLES.md](USAGE_EXAMPLES.md)
- **更新日志**: [CHANGELOG.md](CHANGELOG.md)

---

## 贡献

欢迎提交 Issue 和 Pull Request！

## 许可证

本项目脚本采用 MIT 许可证。WireGuard 相关组件遵循其原始许可证（GPLv2）。
