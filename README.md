# WPS365 CLI

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Go Version](https://img.shields.io/badge/go-%3E%3D1.25-blue.svg)](https://go.dev/)

中文 | [English](README.en.md)

WPS 365 官方 CLI 工具 — 面向开发者与 AI Agent 的命令行入口。覆盖日历、即时通讯、通讯录、邮箱、云文档、智能文档、智能表格、多维表、会议 9 大业务域，提供 120 条精装命令；未覆盖的接口（如电子表格等）通过 `api` 命令直接访问。

[安装](#安装与快速开始) · [命令体系](#双轨命令体系) · [认证](#认证) · [进阶用法](#进阶用法) · [安全](#凭证与安全) · [开发](#开发) · [贡献](#贡献)

## 为什么选 wps365-cli？

- **覆盖面广** — 9 大业务域、120 条精装命令，一个工具操作整个 WPS 365 平台
- **双轨架构** — 精装命令（语义化、参数友好）+ `api get|post|put|patch|delete|head`（全 API 覆盖），按需选择粒度
- **CDN spec 驱动** — 首次运行自动从 CDN 下载官方命令定义，开箱即用；支持本地覆盖与自定义扩展
- **安全可控** — OS 原生钥匙串或 AES-256-GCM 加密存储凭证，明文 secret 永远不落盘
- **脚本友好** — 统一退出码、结构化输出、`--dry-run` 预览、环境变量驱动，CI/CD 开箱即用
- **自动 token 管理** — 过期前主动刷新、401 透明重试，开发者无需关心 token 生命周期
- **开源零门槛** — MIT 协议，一行命令安装即用

## 功能

| 类别 | 精装命令数 | 能力 |
|------|-----------|------|
| 📅 日历 | 25 | 日历增删改查、日程增删改查与搜索、参会人与会议室管理、忙闲查询、重复日程实例、会议纪要、批量查询主日历 |
| 💬 即时通讯 | 15 | 消息发送/回复/撤回、群聊增删改查、群成员管理、会话消息记录、单聊查询、未读统计 |
| 👤 通讯录 | 5 | 当前用户信息、用户列表与搜索（姓名/邮箱/手机号）、用户详情、所属部门查询 |
| 📧 邮箱 | 8 | 邮箱列表、文件夹与子文件夹浏览、邮件列表/详情/搜索、草稿创建与发送 |
| 📁 云文档 | 23 | 驱动器管理、文档库/团队文档、文件增删改查/搜索/下载/重命名、批量复制与移动、正文提取、版本管理、分享链接、最近/收藏/常用文件 |
| 📝 智能文档 | 9 | 创建/读取智能文档、v2 块读写（`--content` 写入纯文本）、OTL JSON 导入、导出 docx/json |
| 📊 智能表格 | 8 | 创建智能表格、工作表、选区读写/查找、追加行 |
| 📋 多维表 | 14 | 数据表结构查询、数据表/字段增删改、记录增删改查与搜索、分页查询 |
| 🎥 会议 | 13 | 会议列表/详情/结束、转让主持人、参会人邀请/移除/列表、会议纪要与摘要、录制与转写 |

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

macOS / Linux 默认安装到 `~/.local/bin`（无需 sudo）。可通过环境变量自定义：

```bash
# 安装指定版本
curl -fsSL https://raw.githubusercontent.com/wps365-open/cli/main/install.sh | WPS365_VERSION=v0.3.5 bash

# 自定义安装目录
curl -fsSL https://raw.githubusercontent.com/wps365-open/cli/main/install.sh | WPS365_INSTALL_DIR=~/.local/bin bash
```

```powershell
# PowerShell: 安装指定版本
$env:WPS365_VERSION="v0.3.5"; irm https://raw.githubusercontent.com/wps365-open/cli/main/install.ps1 | iex

# PowerShell: 自定义安装目录
$env:WPS365_INSTALL_DIR="C:\tools"; irm https://raw.githubusercontent.com/wps365-open/cli/main/install.ps1 | iex
```

**手动下载**

从 [Release 页面](https://github.com/wps365-open/cli/releases) 下载对应平台的二进制文件。

### 三步开始

```bash
# 1. 新建/绑定应用（仅需一次）
wps365-cli config init
# 2. 登录授权
wps365-cli auth login --device
# 3. 确认当前登录用户信息
wps365-cli user me
```

> 企业管理员建议预先设置 CLI 应用免审规则。`config init` 会打开浏览器完成应用创建/绑定与授权确认；已有凭证可用 `auth setup`。详见 [前置准备：创建应用与权限配置](docs/prerequisites.md)。

## 双轨命令体系

CLI 提供两种粒度的调用方式，精装命令覆盖高频场景，`api` 命令兜底全量 API：

### 1. 精装命令

语义化参数、智能默认值、auth 约束自动校验，对人类与脚本友好。

```bash
wps365-cli user me
wps365-cli calendar event create primary \
  --name "周会" --start "2026-09-01T14:00:00+08:00" --end "2026-09-01T15:00:00+08:00"
wps365-cli im message send --to "u1,u2" --text "hello"
```

运行 `wps365-cli <resource> --help` 查看所有子命令。

### 2. 通用 API 调用

直接调用任意 WPS 365 开放平台端点，覆盖全部 API。

```bash
wps365-cli api get "/v7/users/current"
wps365-cli api post "/v7/messages/batch_create" \
  --data '{
    "type": "text",
    "receivers": [{"type": "user", "receiver_ids": ["u1"]}],
    "content": {"text": {"type": "plain", "content": "hello"}}
  }'
```

## 认证

### 常用命令

| 命令 | 说明 | 使用场景 |
|------|------|----------|
| `config init` | 一键应用注册 | 首次使用推荐；浏览器创建/绑定应用并写入 `client_id`/`client_secret` |
| `auth setup` | 配置 OAuth 客户端凭证 | 已有凭证、手动管理；交互式保存 `client_id` 和 `client_secret` |
| `auth login` | 登录授权 | `--device` 设备码授权（可省略 `--scopes`）；授权码模式需 `--scopes` |
| `auth status` | 查看认证状态 | 检查当前 token 是否有效、过期时间、认证模式等 |
| `auth token` | 输出当前 access token | 将 token 传递给其他工具或脚本；默认输出 delegated token，`--app` 输出应用身份 token |
| `auth refresh` | 手动刷新 token | 主动刷新即将过期的 token，需指定 `--delegated` 或 `--app` |
| `auth logout` | 删除本地 delegated token | 退出当前用户授权登录；凭证保留，可直接重新 `login` |
| `auth clean` | 清理所有认证数据 | 凭证损坏、密钥不匹配或需要完全重置时使用；清除 token/secret，并清空配置中的 `client_id`/`redirect_uri`，之后需从 `setup`/`config init` 重新开始。`--force` 跳过确认 |
| `auth qrcode` | 把 URL 编成二维码 | `--file qr.png` 写 PNG（相对当前目录）；`--ascii` 打印终端码。全局 `-o/--output` 是格式不是路径 |

```bash
# 1a. 一键应用注册（推荐）
wps365-cli config init

# 1b. 手动配置凭证
wps365-cli auth setup

# 2. 用户身份登录（设备码，推荐）
wps365-cli auth login --device

# 3. 非交互式（CI/CD / app-only 场景）
export WPS365_CLIENT_ID="<client-id>"
export WPS365_CLIENT_SECRET="<client-secret>"
wps365-cli im message send --to "<OPEN_ID>" --text "hello"

# 4. 查看当前认证状态
wps365-cli auth status

# 5. 将 token 传给其他工具（默认 delegated token，--app 输出应用身份 token）
curl -H "Authorization: Bearer $(wps365-cli auth token)" https://openapi.wps.cn/v7/users/current

# 6. 退出登录（保留凭证，下次可直接 login）
wps365-cli auth logout

# 7. 完全重置（清除所有 token、凭证和自动密钥）
wps365-cli auth clean --force
```

### 认证模式

| 模式 | 说明 | 获取方式 |
|------|------|----------|
| `delegated` | 用户授权身份，适用于当前用户等用户态接口 | `auth login --device` 或 `auth login --scopes "..."` |
| `app` | 应用身份，适用于服务端调用或应用态接口 | 直接执行目标命令，必要时加 `--token-type app` |

命令根据底层 OpenAPI `security` 自动选择认证模式，`--token-type` 可显式覆盖。不兼容时直接报错；delegated token 不可用时自动回退到 app 模式。

## 进阶用法

### 输出格式

```bash
-o json      # JSON（默认）
-o yaml      # YAML
-o table     # 易读表格
-o tsv       # Tab 分隔（适合管道处理）
```

```bash
wps365-cli -o yaml user me
wps365-cli -o table calendar list
```

### Dry Run

预览请求而不实际发送，方便调试和脚本验证：

```bash
wps365-cli --dry-run user me
wps365-cli --dry-run api get "/v7/users/current"
wps365-cli --dry-run -o json im message send --to "u1" --text "hello"
```

### HTTP 超时

业务 API 请求默认 30 秒超时，可用 `--timeout`、环境变量 `WPS365_TIMEOUT` 或 `config set timeout` 调整。`0` / `none` / `unlimited` 表示不限制。

```bash
wps365-cli --timeout 2m user me
wps365-cli --timeout 0 api get "/v7/users/current"
wps365-cli config set timeout 2m
```

### Spec 管理

首次运行时 CLI 自动从 CDN 下载官方 spec，无需手动配置即可使用全部命令。

```bash
wps365-cli spec status      # 查看当前 spec 状态（含来源与版本）
wps365-cli spec update      # 检查并更新官方 spec 文件
```

### 自我更新

```bash
wps365-cli update           # 与 CDN latest 比对，落后则替换当前二进制
wps365-cli update --check   # 只比对，不下载
```

升级二进制后若缺少新命令，再执行 `wps365-cli spec update -y`。

### 环境变量

| 变量 | 用途 |
|------|------|
| `WPS365_CLIENT_ID` | OAuth 客户端 ID |
| `WPS365_CLIENT_SECRET` | OAuth 客户端密钥 |
| `WPS365_AUTH` | 默认认证模式（`app` / `delegated`） |
| `WPS365_ACCESS_TOKEN` | 直接注入 access token（跳过存储和刷新） |
| `WPS365_API_BASE` | API 基础地址 |
| `WPS365_TIMEOUT` | 业务 API HTTP 超时（如 `60s`、`2m`；`0`/`none` 表示不限制），默认 `30s` |
| `WPS365_AUTH_URL` | 自定义 OAuth 授权端点 |
| `WPS365_TOKEN_URL` | 自定义 OAuth token 端点 |
| `WPS365_REDIRECT_URI` | OAuth 回调地址 |
| `WPS365_CONFIG_DIR` | 配置文件目录 |
| `WPS365_KEYRING_BACKEND` | 凭证存储后端（`keychain` / `file`） |
| `WPS365_KEYRING_PASSWORD` | 文件后端加密密码（可选，未设置时自动生成） |
| `WPS365_OUTPUT` | 默认输出格式 |
| `WPS365_QUIET` | 静默 stderr 信息输出 |
| `WPS365_CDN_LATEST_URL` | 覆盖 CLI 自我更新的 latest.txt 地址 |
| `WPS365_CDN_URL` | 覆盖 CLI 发布包 CDN 前缀（含 `/releases/download`） |

## 凭证与安全

`client_secret` 和 token 存储在安全后端，明文永远不落盘：

- **钥匙串**（macOS/Windows 默认）：使用系统 Keychain / Credential Manager
- **加密文件**（Linux 默认）：AES-256-GCM 加密。未设置 `WPS365_KEYRING_PASSWORD` 时自动生成随机密钥并持久化到本地，无需额外配置

Token 生命周期完全自动管理：

- access token 过期前 10 秒主动刷新
- 401 响应时透明刷新并重试
- delegated token 通过 refresh_token 刷新；refresh token 过期时提示重新 `auth login`
- app token 过期时自动通过 client_credentials 重新获取

## 开发

### 目录结构

```
cmd/wps365-cli/       CLI 主入口
internal/
  cli/                根命令、基础命令与命令挂载
  curated/            精装命令 catalog 与参数绑定
  api/                api get|post|put|patch|delete|head 兜底命令
  openapi/            OpenAPI 解析、路径匹配与契约校验
  auth/               认证、token 存储、刷新与 401 重试
  transport/          HTTP 客户端，自动 token 注入与 401 重试
  config/             配置加载与环境变量解析
specs/                仓库内置官方 spec
docs/design-docs/     设计文档
```

### 构建与测试

```bash
make build            # 构建当前平台
make build-all        # 构建全平台（macOS/Linux/Windows）
make install          # 安装到 $GOPATH/bin
make test             # 单元测试
make test-e2e         # 黑盒 E2E 测试
make quality-report   # 运行质量检查报告
make help             # 查看所有 Make 目标
```

### 相关文档

- [ARCHITECTURE.md](ARCHITECTURE.md) — 项目架构与目录职责
- [docs/design-docs/auth.md](docs/design-docs/auth.md) — 认证与凭证设计
- [docs/design-docs/spec-discovery.md](docs/design-docs/spec-discovery.md) — spec 文件管理与加载顺序
- [docs/design-docs/curated-commands.md](docs/design-docs/curated-commands.md) — 精装命令设计原则
- [docs/design-docs/openapi-cli-mapping.md](docs/design-docs/openapi-cli-mapping.md) — 命令到 API 的映射规则
- [docs/design-docs/testing.md](docs/design-docs/testing.md) — 测试策略与 E2E 约束

## 贡献

欢迎社区贡献！如果你发现 bug 或有功能建议，请提交 Issue 或 Pull Request。

对于较大的改动，建议先通过 Issue 讨论。

## 许可证

本项目基于 [MIT 许可证](LICENSE) 开源。
