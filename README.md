# WPS365 CLI

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Go Version](https://img.shields.io/badge/go-%3E%3D1.25-blue.svg)](https://go.dev/)

中文 | [English](README.en.md)

WPS 365 官方 CLI 工具 — 面向开发者与 AI Agent 的命令行入口。覆盖日历、协作、通讯录、邮箱、云文档、多维表、会议等 7 大业务域，未覆盖的接口通过 `api get|post` 直接访问。

[安装](#安装与快速开始) · [命令](#双轨命令体系) · [认证](#认证) · [进阶用法](#进阶用法) · [安全](#凭证与安全) · [贡献](#贡献)

## 功能

| 类别 | 能力 |
|------|------|
| 📅 日历 | 日历增删改查与订阅、日程增删改查/搜索、参与者管理、会议室管理、忙闲查询、会议纪要、重复日程实例 |
| 💬 即时通讯 | 发送/回复/撤回消息、群聊增删改查、成员管理、消息列表、P2P 会话、未读数 |
| 👤 通讯录 | 查询当前用户、用户列表与搜索、部门列表 |
| 📧 邮箱 | 邮箱管理、文件夹浏览、邮件列表/详情/搜索、发送与草稿 |
| 📁 云文档 | 驱动器管理、文件增删改查/搜索、批量复制/移动、版本管理、分享链接 |
| 📋 多维表 | 数据表/字段管理、记录增删改查与搜索 |
| 🎥 会议 | 在线会议管理、参会人管理、会议纪要与录制 |

## 安装与快速开始

### 安装

**macOS / Linux**

```bash
curl -fsSL https://raw.githubusercontent.com/wps365-open/cli/main/install.sh | bash
```

**Windows（PowerShell）**

```powershell
irm https://raw.githubusercontent.com/wps365-open/cli/main/install.ps1 | iex
```

**Windows（Git Bash）**

```bash
curl -fsSL https://raw.githubusercontent.com/wps365-open/cli/main/install.sh | bash
```

可通过环境变量自定义：

```bash
# 安装指定版本
curl -fsSL https://raw.githubusercontent.com/wps365-open/cli/main/install.sh | WPS365_VERSION=v0.0.2 bash

# 自定义安装目录
curl -fsSL https://raw.githubusercontent.com/wps365-open/cli/main/install.sh | WPS365_INSTALL_DIR=~/.local/bin bash
```

```powershell
# PowerShell: 安装指定版本
$env:WPS365_VERSION="v0.0.2"; irm https://raw.githubusercontent.com/wps365-open/cli/main/install.ps1 | iex

# PowerShell: 自定义安装目录
$env:WPS365_INSTALL_DIR="C:\tools"; irm https://raw.githubusercontent.com/wps365-open/cli/main/install.ps1 | iex
```

**手动下载**

[Release 页面](https://github.com/wps365-open/cli/releases) 

### 三步开始

> 首次使用前需要在 WPS 365 开放平台完成应用创建与权限配置，详见 [前置准备：创建应用与权限配置](docs/prerequisites.md)。

```bash
# 1. 配置 OAuth 客户端凭证（仅需一次，交互式引导）
wps365-cli auth setup

# 2. 登录授权
wps365-cli auth login --scopes "kso.user_base.read,kso.calendar.read"

# 3. 开始使用
wps365-cli user me
```

## 双轨命令体系

CLI 提供两种粒度的调用方式，精装命令覆盖高频场景，`api` 命令兜底全量 API：

### 1. 精装命令

语义化参数、智能默认值、auth 约束自动校验，对人类与脚本友好。

```bash
wps365-cli user me
wps365-cli calendar event create primary \
  --name "周会" --from "2024-01-15T14:00:00+08:00" --to "2024-01-15T15:00:00+08:00"
wps365-cli im message send --to u1 --to u2 --text "hello"
```

运行 `wps365-cli <resource> --help` 查看所有子命令。

### 2. 通用 API 调用

未覆盖的接口通过 `api get|post` 直接调用任意 WPS 365 开放平台端点：

```bash
wps365-cli api get "/v7/users/current"
wps365-cli api post "/v7/calendars/create" \
  --data '{"summary": "项目日历"}'
```

## 认证

### 常用命令

| 命令 | 说明 | 使用场景 |
|------|------|----------|
| `auth setup` | 配置 OAuth 客户端凭证 | 首次使用，交互式引导保存 `client_id` 和 `client_secret` |
| `auth login` | 登录授权 | `--scopes` 指定权限进行用户授权（浏览器 OAuth） |
| `auth status` | 查看认证状态 | 检查当前 token 是否有效、过期时间、认证模式等 |
| `auth token` | 输出当前 access token | 将 token 传递给其他工具或脚本，如 `curl -H "Authorization: Bearer $(wps365-cli auth token)"` |
| `auth logout` | 删除本地 token | 退出登录；凭证保留，可直接重新 `login` |
| `auth clean` | 清理所有认证数据 | 凭证损坏或需要完全重置时使用；清除后需从 `setup` 重新开始 |

```bash
# 1. 首次配置（交互式引导）
wps365-cli auth setup

# 2. 用户身份登录（浏览器 OAuth 授权）
wps365-cli auth login --scopes "kso.user_base.read,kso.calendar.read"

# 3. 应用身份（CI/CD 场景，通过环境变量，无需 login）
export WPS365_CLIENT_ID="<client-id>"
export WPS365_CLIENT_SECRET="<client-secret>"
wps365-cli user list   # 自动使用 client_credentials 获取 app token

# 4. 查看当前认证状态
wps365-cli auth status

# 5. 将 token 传给其他工具
curl -H "Authorization: Bearer $(wps365-cli auth token)" https://open.wps.cn/v7/users/current

# 6. 退出登录（保留凭证，下次可直接 login）
wps365-cli auth logout

# 7. 完全重置（清除所有 token、凭证和自动密钥）
wps365-cli auth clean --force
```

### 认证模式

| 模式 | 说明 | 获取方式 |
|------|------|----------|
| `delegated` | 用户授权身份，适用于当前用户、个人待办等用户态接口 | `auth login --scopes "..."` |
| `app` | 应用身份，适用于服务端调用或应用态接口 | 设置 `WPS365_CLIENT_ID` + `WPS365_CLIENT_SECRET` 环境变量，CLI 自动获取 |

命令根据底层 OpenAPI `security` 自动选择认证模式，`--token-type` 可显式覆盖。不兼容时直接报错，不静默切换。

## 进阶用法

### 输出格式

```bash
-o json      # JSON（默认）
-o yaml      # YAML
-o table     # 易读表格
-o tsv       # Tab 分隔（适合管道处理）
-o ndjson    # 换行分隔 JSON（适合流式处理）
-o csv       # CSV 格式
```

```bash
wps365-cli -o yaml user me
wps365-cli -o table calendar list
wps365-cli -o csv dbsheet record list --file-id <id> --sheet-id <id>
```

### 输出管线

```bash
# 内置 jq 过滤器（无需安装 jq）
wps365-cli user me --jq '.name'

# 扁平化嵌套对象，适合 table/tsv/csv 输出
wps365-cli -o table drive file list --flatten

# 禁用彩色输出（适合日志或 CI 场景）
wps365-cli --no-color user list
```

### Dry Run

预览请求而不实际发送，方便调试和脚本验证：

```bash
wps365-cli --dry-run user me
wps365-cli --dry-run api get "/v7/users/current"
wps365-cli --dry-run -o json im message send --to u1 --text "hello"
```


### 环境变量

| 变量 | 用途 |
|------|------|
| `WPS365_CLIENT_ID` | OAuth 客户端 ID |
| `WPS365_CLIENT_SECRET` | OAuth 客户端密钥 |
| `WPS365_AUTH` | 默认认证模式（`app` / `delegated`） |
| `WPS365_ACCESS_TOKEN` | 直接注入 access token（跳过存储和刷新） |
| `WPS365_API_BASE` | API 基础地址 |
| `WPS365_AUTH_URL` | 自定义 OAuth 授权端点 |
| `WPS365_TOKEN_URL` | 自定义 OAuth token 端点 |
| `WPS365_REDIRECT_URI` | OAuth 回调地址 |
| `WPS365_CONFIG_DIR` | 配置文件目录 |
| `WPS365_KEYRING_BACKEND` | 凭证存储后端（`keychain` / `file`） |
| `WPS365_KEYRING_PASSWORD` | 文件后端加密密码（可选，未设置时自动生成） |
| `WPS365_OUTPUT` | 默认输出格式 |
| `WPS365_QUIET` | 静默 stderr 信息输出 |

## 凭证与安全

`client_secret` 和 token 存储在安全后端，明文永远不落盘：

- **钥匙串**（macOS/Windows 默认）：使用系统 Keychain / Credential Manager
- **加密文件**（Linux 默认）：AES-256-GCM 加密。未设置 `WPS365_KEYRING_PASSWORD` 时自动生成随机密钥并持久化到本地，无需额外配置

Token 生命周期完全自动管理：

- access token 过期前 10 秒主动刷新
- 401 响应时透明刷新并重试
- delegated token 通过 refresh_token 刷新；refresh token 过期时提示重新 `auth login`
- app token 过期时自动通过 client_credentials 重新获取


## 贡献

欢迎社区贡献！如果你发现 bug 或有功能建议，请提交 Issue 或 Pull Request。

对于较大的改动，建议先通过 Issue 讨论。

## 许可证

本项目基于 [MIT 许可证](LICENSE) 开源。
