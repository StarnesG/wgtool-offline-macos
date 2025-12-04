# 更新日志

## 2024-12-04 - 修复版本

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
