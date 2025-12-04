# 版本兼容性说明

## 问题背景

构建 wireguard-go 时可能遇到以下错误：

```
link: golang.org/x/net/internal/socket: invalid reference to syscall.recvmsg
```

这是因为 wireguard-go 的旧版本与新版本的 Go 编译器不兼容。

## 版本对照表

### wireguard-go 版本

| 版本 | 发布日期 | Go 版本要求 | 状态 | 说明 |
|------|---------|------------|------|------|
| 0.0.20250522 | 2024-05 | Go 1.21+ | 最新 | 支持最新 Go 特性 |
| 0.0.20250515 | 2024-05 | Go 1.21+ | 稳定 | 近期更新 |
| 0.0.20230223 | 2023-02 | Go 1.18+ | **推荐** | 兼容性好，稳定 |
| 0.0.20220316 | 2022-03 | Go 1.17 | 过时 | 不兼容新 Go |
| 0.0.20220117 | 2022-01 | Go 1.17 | 过时 | 不兼容新 Go |

### wireguard-tools 版本

| 版本 | 发布日期 | 状态 | 说明 |
|------|---------|------|------|
| v1.0.20250521 | 2024-05 | 最新 | 最新功能 |
| v1.0.20210914 | 2021-09 | **推荐** | 稳定，功能完整 |
| v1.0.20210424 | 2021-04 | 稳定 | 较旧但可用 |

## 推荐组合

### 默认配置（推荐）

适用于大多数场景：

```bash
WG_TOOLS_VERSION=v1.0.20210914
WG_GO_VERSION=0.0.20230223
```

**优点**：
- 稳定性好
- 兼容 Go 1.18-1.22
- 功能完整

### 最新版本

追求最新特性：

```bash
WG_TOOLS_VERSION=v1.0.20250521
WG_GO_VERSION=0.0.20250522
```

**要求**：
- Go 1.21+
- 可能存在未知问题

### 保守配置

追求最大稳定性：

```bash
WG_TOOLS_VERSION=v1.0.20210914
WG_GO_VERSION=0.0.20230223
```

## Go 版本检查

```bash
# 检查当前 Go 版本
go version

# 输出示例：
# go version go1.21.0 darwin/arm64
```

## 构建命令示例

### 使用默认版本（推荐）

```bash
./build.sh
```

### 指定版本

```bash
# Go 1.18-1.20
WG_GO_VERSION=0.0.20230223 ./build.sh

# Go 1.21+
WG_GO_VERSION=0.0.20250522 ./build.sh

# 完全自定义
WG_TOOLS_VERSION=v1.0.20250521 WG_GO_VERSION=0.0.20250522 ./build.sh
```

## 常见错误及解决方案

### 错误 1：invalid reference to syscall.recvmsg

**原因**：wireguard-go 版本太旧，不兼容新 Go

**解决**：
```bash
WG_GO_VERSION=0.0.20230223 ./build.sh
```

### 错误 2：dial tcp xxx:443: i/o timeout

**原因**：网络问题，无法下载 Go 依赖

**解决**：
```bash
# 方案 1：使用国内镜像
export GOPROXY=https://goproxy.cn,direct
./build.sh

# 方案 2：配置代理
export https_proxy=http://127.0.0.1:7890
./build.sh
```

### 错误 3：pathspec 'xxx' did not match any file(s)

**原因**：Git tag 不存在或格式错误

**解决**：
```bash
# 检查可用 tag
cd wireguard-go
git tag -l

# 使用正确的 tag（注意有些有 v 前缀，有些没有）
WG_GO_VERSION=0.0.20230223 ./build.sh  # 无 v 前缀
WG_TOOLS_VERSION=v1.0.20210914 ./build.sh  # 有 v 前缀
```

## 更新历史

- **2024-12**: 更新默认 wireguard-go 版本为 0.0.20230223，解决 Go 兼容性问题
- **2021-09**: 初始版本，使用 wireguard-tools v1.0.20210914

## 参考链接

- [wireguard-tools 官方仓库](https://git.zx2c4.com/wireguard-tools/)
- [wireguard-go 官方仓库](https://git.zx2c4.com/wireguard-go/)
- [Go 下载页面](https://golang.org/dl/)
