# Changelog

本文件记录 WPS365 CLI 各版本的主要变更。格式遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)。

## [Unreleased]

### 变更

- macOS / Linux 默认安装目录从 `/usr/local/bin` 改为 `~/.local/bin`，无需 sudo

## [v0.3.2] - 2026-08-13

### 新增

- 业务 API HTTP 超时可配置：全局 `--timeout`、环境变量 `WPS365_TIMEOUT`、`config set timeout`（如 `2m`/`2min`，默认 `30s`；`0`/`none`/`unlimited` 表示不限制）

### 变更

- 安装示例指定版本改为 `WPS365_VERSION=v0.3.2`

## [v0.3.1] - 2026-07-22

### 修复

- README 精装命令示例对齐当前 CLI：`calendar event create` 使用 `--start`/`--end`；`im message send` 使用逗号分隔的 `--to`

### 变更

- 安装示例指定版本改为 `WPS365_VERSION=v0.3.1`

## [v0.3.0] - 2026-07-22

### 新增

- `config init`：浏览器一键完成开放平台应用创建/绑定，自动写入 `client_id` / `client_secret`（公网推荐首次配置路径）
- OAuth2 Device Authorization Grant（`auth login --device`），适配远程 / WSL / CI 等无本地回调场景
- Device 登录可按需省略 `--scopes`
- 用户文档：同步中英文 README 与使用指南，补充 `config init` / `auth setup` FAQ 与前置准备说明

### 变更

- 推荐快速开始改为：`config init` → `auth login --device` → `user me`（已有凭证仍可用 `auth setup`）
- README 功能概览与认证命令表对齐当前产品能力
- 安装示例指定版本改为 `WPS365_VERSION=v0.3.0`

### 修复

- **`auth setup` 旧 secret 不可读**：从安全存储读取已有 `client_secret` 失败（钥匙串不可用、密文损坏等，且非 NotFound）时不再中止；视为无旧值并继续写入，凭证变更时清理旧 token
- **公网 scope**：去掉不存在的 `kso.file.search`，文件搜索路径仅使用 `kso.file_search.readwrite`
- **`auth clean`**：同时清理 `client_id` 等相关配置，完整重置后需重新 `setup` / `config init`
- **登录成功 JSON**：不再输出 `granted_scopes`
- **`config init` 文案**：精简成功提示，减少用户文档中内部环境变量暴露

## [v0.2.0] - 2026-06-26

### ⚠️ 不兼容变更

#### 1. 命令重命名（复数 → 单数）

所有资源名统一为单数形式，使用旧名称的脚本需更新：

| v0.1.0（旧） | v0.2.0（新） |
|--------------|-------------|
| `calendar events *` | `calendar event *` |
| `calendar event-attendees *` | `calendar event-attendee *` |
| `calendar event-instances *` | `calendar event-instance *` |
| `calendar event-rooms *` | `calendar event-room *` |
| `im messages *` | `im message *` |
| `im chats *` | `im chat *` |
| `im chat-members *` | `im chat-member *` |
| `im chat-messages *` | `im chat-message *` |
| `mail mailboxes *` | `mail mailbox *` |
| `mail mailbox-folders *` | `mail mailbox-folder *` |
| `mail mailbox-subfolders *` | `mail mailbox-subfolder *` |
| `mail messages *` | `mail message *` |
| `mail drafts *` | `mail draft *` |
| `drive files *` | `drive file *` |
| `drive file-versions *` | `drive file-version *` |
| `drive file-link *` | `drive link *` |
| `dbsheet sheets *` | `dbsheet sheet *` |
| `dbsheet fields *` | `dbsheet field *` |
| `dbsheet records *` | `dbsheet record *` |
| `dbsheet record-pages *` | `dbsheet record-page *` |
| `dbsheet views *` | `dbsheet view *` |
| `meeting participants *` | `meeting participant *` |
| `meeting minutes *` | `meeting minute *` |
| `meeting recordings *` | `meeting recording *` |

#### 2. 移除的精装命令（改用 `api get|post`）

以下命令不再提供精装入口，可通过 `api` 直接调用对应端点：

**日历**

| 移除的命令 | 替代方式 |
|-----------|---------|
| `calendar timeoff-events create` | `api post "/v7/calendars/primary/timeoff_events/create"` |
| `calendar timeoff-events delete` | `api post "/v7/calendars/primary/timeoff_events/{id}/delete"` |
| `calendar events batch-create` | `api post "/v7/calendars/{calendar_id}/events/batch_create"` |

**即时通讯**

| 移除的命令 | 替代方式 |
|-----------|---------|
| `im chat-bookmark add` | `api post "/v7/chats/{chat_id}/bookmarks/batch_create"` |
| `im chat-bookmark remove` | `api post "/v7/chats/{chat_id}/bookmarks/batch_delete"` |
| `im in-chat-member check` | `api get "/v7/chats/{chat_id}/members/is_in_chat"` |
| `im link-chat share` | `api post "/v7/chats/{chat_id}/share_link"` |

> `im chat-bookmark list` 保留。

**通讯录**

| 移除的命令 | 替代方式 |
|-----------|---------|
| `user by-email get` | 合并至 `user get --type email`，或 `api post "/v7/users/by_emails"` |
| `user by-phone get` | 合并至 `user get --type phone`，或 `api post "/v7/users/by_phones"` |
| `user by-ex-id get` | 合并至 `user get --type external-id`，或 `api post "/v7/users/by_ex_user_ids"` |

**邮箱**

| 移除的命令 | 替代方式 |
|-----------|---------|
| `mail contact list` | `api get "/v7/mail_contacts"` |
| `mail contact create` | `api post "/v7/mail_contacts"` |
| `mail contact delete` | `api post "/v7/mail_contacts/{id}/delete"` |

**云文档**

| 移除的命令 | 替代方式 |
|-----------|---------|
| `drive files batch-delete` | `api post "/v7/drives/{drive_id}/files/batch_delete"` |
| `drive files batch-get` | `api post "/v7/drives/{drive_id}/files/batch_get"` |
| `drive file-owner update` | `api post "/v7/drives/{drive_id}/files/{file_id}/transfer_owner"` |
| `drive file-permission list` | `api get "/v7/drives/{drive_id}/files/{file_id}/permissions"` |
| `drive file-permission batch-create` | `api post "/v7/drives/{drive_id}/files/{file_id}/permissions/batch_create"` |
| `drive file-permission batch-delete` | `api post "/v7/drives/{drive_id}/files/{file_id}/permissions/batch_delete"` |
| `drive roles list` | `api get "/v7/drives/{drive_id}/roles"` |

**多维表**

| 移除的命令 | 替代方式 |
|-----------|---------|
| `dbsheet views delete` | `api post "/v7/coop/dbsheet/{file_id}/views/{view_id}/delete"` |
| `dbsheet views get` | `api get "/v7/coop/dbsheet/{file_id}/views/{view_id}"` |
| `dbsheet views list` | `api get "/v7/coop/dbsheet/{file_id}/views"` |
| `dbsheet views update` | `api post "/v7/coop/dbsheet/{file_id}/views/{view_id}/update"` |
| `dbsheet hooks create` | `api post "/v7/coop/dbsheet/{file_id}/hooks/create"` |
| `dbsheet hooks list` | `api get "/v7/coop/dbsheet/{file_id}/hooks"` |
| `dbsheet hooks delete` | `api post "/v7/coop/dbsheet/{file_id}/hooks/{hook_id}/delete"` |

> `dbsheet view create` 保留。

**会议**

| 移除的命令 | 替代方式 |
|-----------|---------|
| `meeting recordings start` | `api post "/v7/meetings/{meeting_id}/recordings/start"` |
| `meeting recordings stop` | `api post "/v7/meetings/{meeting_id}/recordings/stop"` |
| `meeting rooms list` | `api get "/v7/meeting_rooms"` |
| `meeting rooms get` | `api get "/v7/meeting_rooms/{room_id}"` |
| `meeting rooms create` | `api post "/v7/meeting_rooms/create"` |
| `meeting rooms update` | `api post "/v7/meeting_rooms/{room_id}/update"` |
| `meeting rooms delete` | `api post "/v7/meeting_rooms/{room_id}/delete"` |
| `meeting rooms batch-get` | `api post "/v7/meeting_rooms/batch_get"` |
| `meeting rooms search` | `api post "/v7/meeting_rooms/search"` |
| `meeting room-bookings batch-get` | `api post "/v7/meeting_room_bookings/batch_get"` |
| `meeting room-bookings-status update` | `api post "/v7/meeting_room_bookings/{booking_id}/update_status"` |
| `meeting room-levels list` | `api get "/v7/meeting_room_levels"` |
| `meeting room-levels get` | `api get "/v7/meeting_room_levels/{room_level_id}"` |
| `meeting room-levels create` | `api post "/v7/meeting_room_levels/create"` |
| `meeting room-levels update` | `api post "/v7/meeting_room_levels/{room_level_id}/update"` |
| `meeting room-levels delete` | `api post "/v7/meeting_room_levels/{room_level_id}/delete"` |
| `meeting room-levels batch-get` | `api post "/v7/meeting_room_levels/batch_get"` |
| `meeting room-settings batch-get` | `api post "/v7/meeting_room_settings/batch_get"` |
| `meeting room-settings update` | `api post "/v7/meeting_room_settings/{room_id}/update"` |

#### 3. 认证命令变更

| v0.1.0（旧） | v0.2.0（新） | 说明 |
|--------------|-------------|------|
| `auth login --app` | 设置 `WPS365_CLIENT_ID` + `WPS365_CLIENT_SECRET` 环境变量 | 应用身份不再需要显式 login，CLI 自动获取 token |
| `auth refresh` | 已移除 | token 刷新完全自动化，无需手动操作 |

### 新增

- `--jq` 内置过滤器：无需安装 jq，直接在命令行过滤 JSON 输出
- `--flatten` 扁平化：嵌套对象展开为平坦结构，适合 table/tsv/csv 列式输出
- `--no-color` 禁色模式：适合日志采集和 CI/CD 管道
- `ndjson` / `csv` 输出格式：支持流式处理和电子表格导入
- `provider` 子命令：统一管理 provider 配置（add / list / show / update / remove）

### 改进

- Provider 统一运行时：收敛所有命令到统一的 provider 模型，简化扩展与维护
- Token 并发安全：文件锁序列化 token 刷新，避免多进程竞争
- Spec 生命周期管理：支持 spec 文件自动下载与按需更新

## [v0.1.0] - 2026-05-20

### 新增

- 首次发布，覆盖日历、即时通讯、通讯录、邮箱、云文档、多维表、会议 7 大业务域
- `api get|post` 通用命令兜底全量 OpenAPI 端点
- OAuth 2.0 认证（用户授权 + 应用身份）
- 多格式输出：json / yaml / table / tsv
- Dry Run 模式
- 跨平台安装脚本（bash / PowerShell）
- 安全凭证存储（Keychain / AES-256-GCM 加密文件）

[v0.3.2]: https://github.com/wps365-open/cli/releases/tag/v0.3.2
[v0.3.1]: https://github.com/wps365-open/cli/releases/tag/v0.3.1
[v0.3.0]: https://github.com/wps365-open/cli/releases/tag/v0.3.0
[v0.2.0]: https://github.com/wps365-open/cli/releases/tag/v0.2.0
[v0.1.0]: https://github.com/wps365-open/cli/releases/tag/v0.1.0
