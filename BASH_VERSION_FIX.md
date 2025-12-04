# macOS Bash 版本问题解决方案

## 问题说明

运行 `wg-quick` 时出现错误：

```
wg-quick: Version mismatch: bash 3 detected, when bash 4+ required
```

**原因**：
- macOS 默认使用 Bash 3.2（2007年发布）
- wg-quick 需要 Bash 4.0+（2009年发布）
- Apple 因为 GPLv3 许可证问题，未更新系统 Bash

## 解决方案

### 方案 1：使用控制脚本（推荐）✅

**优点**：
- 无需安装额外软件
- 自动处理 Bash 版本问题
- 提供更友好的命令接口

**使用方法**：

```bash
# 启动
sudo /usr/local/scripts/wg-control.sh up

# 停止
sudo /usr/local/scripts/wg-control.sh down

# 重启
sudo /usr/local/scripts/wg-control.sh restart

# 查看状态
sudo /usr/local/scripts/wg-control.sh status
```

**工作原理**：
- 控制脚本使用 `/bin/sh`（POSIX shell），兼容所有 macOS 版本
- 自动查找可用的 Bash 4+ 版本
- 如果找不到，会尝试使用系统 Bash 并处理错误

---

### 方案 2：安装 Bash 4+

**优点**：
- 可以直接使用 `wg-quick` 命令
- 获得最新 Bash 特性

**步骤**：

#### 1. 安装 Homebrew（如果未安装）

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

#### 2. 安装 Bash

```bash
brew install bash
```

#### 3. 验证安装

```bash
# Intel Mac
/usr/local/bin/bash --version

# Apple Silicon
/opt/homebrew/bin/bash --version

# 应该显示类似：
# GNU bash, version 5.2.x
```

#### 4. 使用 wg-quick

安装后，`wg-quick` 包装脚本会自动使用新版 Bash：

```bash
sudo wg-quick up wg0
sudo wg-quick down wg0
```

---

### 方案 3：使用包装脚本

本项目已经包含了智能包装脚本，会自动处理 Bash 版本问题。

**包装脚本工作流程**：

1. 查找 Homebrew Bash（Apple Silicon）：`/opt/homebrew/bin/bash`
2. 查找 Homebrew Bash（Intel）：`/usr/local/bin/bash`
3. 检查系统 Bash：`/bin/bash`
4. 检查 PATH 中的 bash

如果找到 Bash 4+，自动使用；否则提示安装。

**使用方法**：

```bash
# 直接使用 wg-quick（包装脚本会处理版本问题）
sudo wg-quick up wg0
sudo wg-quick down wg0
```

---

### 方案 4：手动指定 Bash

如果已经安装了 Bash 4+，可以手动指定：

```bash
# Intel Mac
sudo /usr/local/bin/bash /usr/local/bin/wg-quick.bash up wg0

# Apple Silicon
sudo /opt/homebrew/bin/bash /usr/local/bin/wg-quick.bash up wg0
```

---

## 检查 Bash 版本

```bash
# 系统默认 Bash（通常是 3.2）
/bin/bash --version

# Homebrew Bash（Intel）
/usr/local/bin/bash --version

# Homebrew Bash（Apple Silicon）
/opt/homebrew/bin/bash --version

# PATH 中的 bash
bash --version
```

---

## 为什么 macOS 使用旧版 Bash？

1. **许可证问题**：
   - Bash 4.0+ 使用 GPLv3 许可证
   - Apple 不愿意接受 GPLv3 的条款
   - Bash 3.2 是最后一个 GPLv2 版本

2. **替代方案**：
   - macOS 10.15+ 默认 shell 改为 zsh
   - zsh 使用更宽松的许可证
   - 但 wg-quick 仍然需要 Bash

---

## 推荐方案对比

| 方案 | 优点 | 缺点 | 推荐度 |
|------|------|------|--------|
| 控制脚本 | 无需安装，开箱即用 | 命令稍长 | ⭐⭐⭐⭐⭐ |
| 安装 Bash 4+ | 可直接用 wg-quick | 需要安装 Homebrew | ⭐⭐⭐⭐ |
| 包装脚本 | 自动处理版本 | 需要 Bash 4+ | ⭐⭐⭐⭐ |
| 手动指定 | 完全控制 | 命令复杂 | ⭐⭐⭐ |

---

## 常见问题

### Q: 为什么不能直接修改 wg-quick 使其兼容 Bash 3？

A: wg-quick 使用了 Bash 4+ 的特性（如关联数组），修改会破坏功能。官方也不支持 Bash 3。

### Q: 安装 Bash 4+ 会影响系统吗？

A: 不会。Homebrew 安装的 Bash 在独立目录，不会覆盖系统 Bash。

### Q: 可以把 Homebrew Bash 设为默认 shell 吗？

A: 可以，但不推荐。建议保持 zsh 为默认 shell，仅在需要时使用 Bash。

### Q: 控制脚本和 wg-quick 有什么区别？

A: 控制脚本是对 wg-quick 的封装，功能相同，但处理了 Bash 版本问题，更适合 macOS。

---

## 技术细节

### wg-quick 的 Bash 版本检查

wg-quick 在脚本开头检查 Bash 版本：

```bash
if [[ ${BASH_VERSINFO[0]} -lt 4 ]]; then
    echo "wg-quick: Version mismatch: bash ${BASH_VERSINFO[0]} detected, when bash 4+ required" >&2
    exit 1
fi
```

### 包装脚本的版本检测

```bash
check_bash_version() {
    local bash_path="$1"
    local version=$("$bash_path" --version 2>/dev/null | head -n1 | sed 's/.*version \([0-9]\).*/\1/')
    [ "$version" -ge 4 ] 2>/dev/null
}
```

---

## 总结

**最简单的方案**：使用控制脚本

```bash
sudo /usr/local/scripts/wg-control.sh up
```

**最灵活的方案**：安装 Bash 4+

```bash
brew install bash
sudo wg-quick up wg0
```

选择适合你的方案即可！
