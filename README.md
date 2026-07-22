# WPS365 CLI

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Go Version](https://img.shields.io/badge/go-%3E%3D1.23-blue.svg)](https://go.dev/)

中文 | [English](README.en.md)

WPS 365 官方 CLI 工具 — 面向开发者与 AI Agent 的命令行入口。覆盖日历、协作、通讯录、邮箱、云文档、多维表、会议 7 大业务域；提供精装命令与通用 `api` 调用两种模式。

[安装](#安装与快速开始) · [前置准备](#前置准备) · [命令体系](#双轨命令体系) · [认证](#认证) · [进阶用法](#进阶用法) · [安全](#凭证与安全) · [FAQ](#常见问题) · [开发](#开发) · [贡献](#贡献)

## 为什么选 wps365-cli？

- **覆盖面广** — 7 大业务域，一个工具操作整个 WPS 365 平台
- **双轨架构** — 精装命令（语义化、参数友好）+ `api get|post|put|patch|delete|head`（全 API 覆盖）
- **一键上手** — `config init` 浏览器完成应用创建/绑定，无需事先在开放平台手工建应用
- **无头友好** — `auth login --device` 支持远程/WSL/CI 等无法本地回调的场景
- **安全可控** — OS 原生钥匙串或 AES-256-GCM 加密存储凭证，明文 secret 永远不落盘
- **脚本友好** — 统一退出码、结构化输出、`--dry-run` 预览、环境变量驱动
- **自动 token 管理** — 过期前主动刷新、401 透明重试
- **开源零门槛** — MIT 协议，一行命令安装即用

## 功能概览

| 类别 | 能力 |
|------|------|
| 📅 日历 | 查询日历列表、创建/更新/删除日程、管理参会人与会议室、忙闲查询、请假日程、批量操作 |
| 💬 即时通讯 | 发送/回复/撤回消息、群聊增删改查、成员管理、消息列表、加急、书签 |
| 👤 通讯录 | 查询当前用户、用户列表、按姓名/邮箱/手机号搜索、批量查询、部门与离职人员管理 |
| 📧 邮箱 | 邮箱管理、文件夹浏览、邮件列表/详情/搜索、发送与草稿、邮件组与通讯录管理 |
| 📁 云文档 | 驱动器管理、文件列表/上传/下载/搜索、批量操作、权限管理、版本管理、分享链接 |
| 📋 多维表 | 数据表/字段/视图管理、记录增删改查与搜索、仪表盘、Webhook、附件 |
| 🎥 会议 | 在线会议管理、参会人管理、预约会议、会议纪要与录制、会议室与层级管理 |

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
curl -fsSL https://raw.githubusercontent.com/wps365-open/cli/main/install.sh | WPS365_VERSION=v0.3.0 bash

# 自定义安装目录
curl -fsSL https://raw.githubusercontent.com/wps365-open/cli/main/install.sh | WPS365_INSTALL_DIR=~/.local/bin bash
```

```powershell
# PowerShell: 安装指定版本
$env:WPS365_VERSION="v0.3.0"; irm https://raw.githubusercontent.com/wps365-open/cli/main/install.ps1 | iex

# PowerShell: 自定义安装目录
$env:WPS365_INSTALL_DIR="C:\tools"; irm https://raw.githubusercontent.com/wps365-open/cli/main/install.ps1 | iex
```

**手动下载**

从 [Release 页面](https://github.com/wps365-open/cli/releases) 下载对应平台的二进制文件。

### 三步开始

```bash
# 0. 安装（见上一节）

# 1. 新建/绑定应用（推荐，仅需一次）
wps365-cli config init

# 2. 登录授权（远程/WSL 推荐 --device）
wps365-cli auth login --device

# 3. 开始使用
wps365-cli user me
```

无法使用 `config init`？见下方 [路径 B：手动配置应用](#路径-b手动在开放平台配置进阶)。

## 前置准备

本节补充 `config init` 参数、排错，以及无法使用一键注册时的备选方案。

### 路径 A：`config init`（推荐）

公网用户无需事先在开放平台手动创建应用。

```bash
wps365-cli config init
```

流程：

1. CLI 调用开放平台应用注册，输出浏览器链接（并尝试自动打开浏览器）
2. 在浏览器中完成：验证身份 → 创建/绑定应用 → 授权确认（若已有应用会优先进入绑定页）
3. CLI 轮询成功后，自动将 `client_id` 写入本地配置、`client_secret` 存入安全存储

常用参数：

| 参数 | 说明 |
|------|------|
| `--new` | 提示浏览器侧创建新应用 |
| `--force` | 已存在绑定时跳过确认直接覆盖（非交互环境必须） |
| `--debug` | 输出注册各步骤详细日志 |

```bash
wps365-cli config init --new
wps365-cli config init --force
wps365-cli config init --debug
```

完成后直接执行 `auth login`。

### 路径 B：手动在开放平台配置（进阶）

适用于已有企业自建应用、需精细控制权限审批，或无法使用 `config init` 的环境。

整体流程：创建应用 → 获取凭证 → 添加回调地址 → 申请权限并提交发布 → 企业管理员审批 → 写入 CLI。

1. 访问 [WPS 365 开放平台开发者后台](https://open.wps.cn/)，在「企业自建应用」中创建应用  
2. 在应用 **基础信息 → 应用凭证** 记录应用 ID（`client_id`）与应用密钥（`client_secret`）  
3. 在 **开发配置 → 安全设置** 添加回调地址：`http://localhost:18365/callback`  
4. 在 **权限管理** 申请所需 scope，并在 **应用发布 → 版本管理** 创建版本、申请发布  
5. 企业管理员在企业管理后台 **应用市场 → 应用审核** 审批通过  
6. 写入 CLI 凭证：

```bash
wps365-cli auth setup
```

然后执行 `auth login`。更细的截图级说明见 [前置准备：创建应用与权限配置](docs/prerequisites.md)。

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
| `config init` | 一键应用注册 | 浏览器完成应用创建/绑定，自动将凭证写入 CLI |
| `auth setup` | 配置 OAuth 客户端凭证 | 已有 AK/SK 时手动写入；交互式或环境变量注入 |
| `auth login` | 登录授权 | `--scopes` 指定权限；`--device` 无头/远程设备码登录；`--app` 切换应用身份 |
| `auth status` | 查看认证状态 | 检查 token 是否有效、过期时间、认证模式等 |
| `auth token` | 输出当前 access token | 传递给其他工具或脚本；默认 delegated，`--app` 输出应用身份 token |
| `auth refresh` | 手动刷新 token | 主动刷新即将过期的 token |
| `auth logout` | 删除本地 delegated token | 退出登录，保留凭证 |
| `auth clean` | 清理所有认证数据 | 凭证损坏或需要完全重置；`--force` 跳过确认 |

```bash
# 推荐：一键注册 + 设备码登录
wps365-cli config init
wps365-cli auth login --device

# 或指定 scopes 的浏览器回调登录
wps365-cli auth login --scopes "kso.user_base.read,kso.calendar.read"

# CI / app-only
export WPS365_CLIENT_ID="<client-id>"
export WPS365_CLIENT_SECRET="<client-secret>"
wps365-cli im message send --to "<OPEN_ID>" --text "hello" --token-type app

wps365-cli auth status
wps365-cli auth logout
wps365-cli auth clean --force
```

### 认证模式

| 模式 | 说明 | 获取方式 |
|------|------|----------|
| `delegated` | 用户授权身份，适用于当前用户等用户态接口 | `auth login` / `auth login --device` |
| `app` | 应用身份，适用于服务端或应用态接口 | `auth login --app`，或命令加 `--token-type app` |

命令根据底层 OpenAPI `security` 自动选择认证模式，`--token-type` 可显式覆盖。delegated token 不可用时，若接口同时支持 app，会自动回退并提示。

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

### Spec 管理

首次运行时 CLI 自动从 CDN 下载官方 spec，无需手动配置即可使用全部命令。

```bash
wps365-cli spec status      # 查看当前 spec 状态（含来源与版本）
wps365-cli spec update      # 检查并更新官方 spec 文件
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

## 常见问题

**Q：`config init` 一直显示 Waiting for binding？**  
请确认浏览器侧已完成全部步骤，尤其是最后的授权确认。仅创建/绑定应用而未授权，CLI 会持续 pending 直到会话过期。

**Q：`config init` 和 `auth setup` 有什么区别？**

| | `config init` | `auth setup` |
|--|---------------|--------------|
| 适用场景 | 首次使用、快速上手 | 已有凭证、手动管理 |
| 操作方式 | 浏览器引导，自动获取 AK/SK | 交互式输入或环境变量注入 |
| 存储位置 | 相同（`config.json` + 安全存储） | 相同 |

**Q：权限申请后为什么没有生效？**  
需要完成「创建版本 → 申请发布 → 企业管理员审批」。仅申请权限而不提交版本审批，权限会一直处于「待提交审核」。

**Q：通讯录接口返回空数据或权限错误？**  
除「能力权限」外，部分接口还需配置「可用范围」和「数据权限」，请在应用详情页的权限管理中检查。

**Q：`CLIENT_SECRET` 泄露了怎么办？**  
在开发者后台「应用凭证」区域重置密钥，旧密钥立即失效；然后重新执行 `config init` 或 `auth setup`。

**Q：Linux / WSL 上 `auth setup` 或钥匙串异常？**  
可使用 `WPS365_KEYRING_BACKEND=file`（必要时设置 `WPS365_KEYRING_PASSWORD`）。`auth setup` 在无法读取旧 secret 时仍会覆盖写入新凭证。

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
make build
make build-all
make install
make test
make test-e2e
make quality-report
make help
```

### 相关文档

- [ARCHITECTURE.md](ARCHITECTURE.md)
- [docs/design-docs/auth.md](docs/design-docs/auth.md)
- [docs/prerequisites.md](docs/prerequisites.md)
- [docs/design-docs/spec-discovery.md](docs/design-docs/spec-discovery.md)
- [docs/design-docs/curated-commands.md](docs/design-docs/curated-commands.md)
- [docs/design-docs/testing.md](docs/design-docs/testing.md)

## 相关资源

- [GitHub 仓库](https://github.com/wps365-open/cli)
- [Release](https://github.com/wps365-open/cli/releases)

## 贡献

欢迎社区贡献！发现 bug 或有功能建议，请提交 Issue 或 Pull Request。较大改动建议先通过 Issue 讨论。

## 许可证

本项目基于 [MIT 许可证](LICENSE) 开源。
