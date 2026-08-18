# 认证与凭证设计

本文档描述 wps365-cli 的认证架构、凭证存储策略和 token 生命周期管理。

## 认证模式

wps365-cli 支持三种认证模式，命令根据底层 OpenAPI 的 `security` 声明自动选择，`--token-type` 可显式覆盖。模式不兼容时直接报错，不静默切换。

| 模式 | 授权类型 | 适用场景 | 获取方式 |
|------|---------|---------|---------|
| `delegated` | OAuth Authorization Code（浏览器授权） | 当前用户信息、个人日历、个人邮件等用户态接口 | `auth login --scopes "kso.user_base.read,kso.calendar.read"` |
| `app` | Client Credentials | 服务端调用、组织级管理、应用态接口 | `auth login --app` |
| `osh` | OSH 网关 Token | 通过 OSH 网关访问开放能力 | `auth login --osh` |

### Delegated 模式流程

1. CLI 启动本地 HTTP 服务监听 `localhost:18365/callback`
2. 打开浏览器访问 WPS 365 OAuth 授权页面，用户登录并授权
3. 授权完成后浏览器重定向到回调地址，携带 `code`
4. CLI 使用 `code` + `client_secret` 换取 `access_token` 和 `refresh_token`
5. Token 安全存储到后端，后续请求自动携带

### App 模式流程

1. CLI 使用 `client_id` + `client_secret` 请求 `https://openapi.wps.cn/oauth2/token`
2. 返回 `access_token`（无 `refresh_token`，过期后重新获取）
3. 适用于 CI/CD 和服务端场景，支持非交互式

### OSH 模式流程

1. CLI 使用 `client_id` + `client_secret` 请求 `https://open.wps.cn/osh/api/v1/consumers/token`
2. 返回 OSH 网关 access token，用于访问 OSH 开放能力
3. 与 app 模式类似，无 `refresh_token`，过期后重新获取

### 非交互式（CI/CD）

```bash
export WPS365_CLIENT_ID="<client-id>"
export WPS365_CLIENT_SECRET="<client-secret>"
wps365-cli auth login --app
```

通过环境变量注入凭证，跳过交互式 `auth setup`。

### 自定义回调地址

Delegated 模式默认回调地址为 `http://localhost:18365/callback`。如果需要自定义（如远程开发环境端口转发），可通过 `--redirect-uri` 覆盖：

```bash
wps365-cli auth login --scopes "kso.user_base.read" --redirect-uri "http://myhost:18365/callback"
```

> 自定义回调地址必须已在 WPS 365 开放平台「安全设置」中注册。

## 凭证存储

`client_secret` 和 token 永不明文落盘，存储后端按平台选择：

| 平台 | 默认后端 | 备选 |
|------|---------|------|
| macOS | System Keychain | 加密文件 |
| Windows | Credential Manager | 加密文件 |
| Linux | AES-256-GCM 加密文件 | — |

通过 `WPS365_KEYRING_BACKEND` 环境变量可强制切换为 `keychain` 或 `file`。

### 文件后端加密

- 算法：AES-256-GCM
- 密钥来源：`WPS365_KEYRING_PASSWORD` 环境变量，未设置时自动生成随机密钥并持久化到本地
- 无需额外配置即可使用

### 直接注入 Token

`WPS365_ACCESS_TOKEN` 环境变量可直接注入 access token，跳过存储和刷新逻辑。适用于已有 token 的外部集成场景。

`WPS365_OSH_TOKEN` 环境变量可直接注入 OSH 网关 token，效果类似。

## Token 生命周期

### 自动刷新策略

| 事件 | Delegated 模式 | App 模式 | OSH 模式 |
|------|-----------|-----|------|
| 过期前 10 秒 | 使用 `refresh_token` 刷新 | 使用 `client_credentials` 重新获取 | 使用 `client_credentials` 重新获取 |
| 收到 401 响应 | 透明刷新 + 重试 | 透明重新获取 + 重试 | 透明重新获取 + 重试 |
| Refresh token 过期 | 提示重新执行 `auth login` | 不适用 | 不适用 |

### 手动操作

```bash
wps365-cli auth status           # 查看当前 token 状态、过期时间、认证模式
wps365-cli auth token            # 输出 access token（供 curl 等外部工具使用）
wps365-cli auth refresh --delegated   # 手动刷新 delegated token
wps365-cli auth refresh --app         # 手动刷新 app token
wps365-cli auth logout           # 删除 token（保留凭证，可直接重新 login）
wps365-cli auth clean    # 清除所有 token、凭证和自动密钥（完全重置，交互确认）
```

## 命令与认证模式映射

每条命令根据底层 OpenAPI 的 `security` 声明确定所需认证模式：

- `security: [{ oauth2: [user_scope] }]` → delegated
- `security: [{ oauth2: [app_scope] }]` → app
- 同时声明两者时，优先 delegated，`--token-type` 可覆盖

不匹配时 CLI 直接报错，不静默切换模式。这确保用户明确知道当前操作使用的身份。

## 常用 Scope 参考

| 业务域 | 常用 Scope | 说明 |
|--------|-----------|------|
| 用户 | `kso.user_base.read` | 读取当前用户基本信息 |
| 日历 | `kso.calendar.read` | 读取日历和日程 |
| 日历 | `kso.calendar.write` | 创建/修改/删除日程 |
| 即时通讯 | `kso.chat.message.read` | 读取消息 |
| 即时通讯 | `kso.chat.message.write` | 发送消息 |
| 通讯录 | `kso.contact.user.read` | 读取通讯录用户信息 |
| 云文档 | `kso.drive.file.read` | 读取云文档 |
| 云文档 | `kso.drive.file.write` | 上传/修改云文档 |
| 多维表 | `kso.dbsheet.read` | 读取多维表 |
| 邮箱 | `kso.mail.read` | 读取邮件 |

> 完整 Scope 列表和权限申请方式请参考 [前置准备](../prerequisites.md) 和 WPS 365 开放平台开发者后台。

## 安全考量

- OAuth 回调仅监听 `localhost`，不暴露到公网
- `client_secret` 不出现在命令行参数或日志中
- Token 刷新请求中的 `client_secret` 仅在内存中使用
- 401 重试最多一次，避免无限循环
- `auth clean` 同时删除自动生成的加密密钥，确保彻底清除
