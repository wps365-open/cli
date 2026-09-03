# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.3.5] - 2026-09-03

### Added
- `config init`：在验证 URL 旁输出 ASCII 二维码，便于手机扫码（编码失败则省略码，仍打印 URL）
- `wps365-cli update`：从官方 CDN 比对版本，落后则下载、校验并原地替换当前二进制；`--check` 只比对；`--force` 强制重装。不静默后台升级，也不自动刷新 spec
- `auth qrcode`：把验证 URL 写成 PNG（`--file`，相对当前目录）或 ASCII（`--ascii`）；全局 `-o/--output` 仍是输出格式，不是文件路径
- `mcp serve` / `mcp tools` / `mcp config` / `mcp doctor`：把精装 catalog 暴露为本地 stdio MCP tools，Workbuddy / Claude / Cursor 可作为自定义连接器接入（`mcp config --app workbuddy` 输出可粘贴片段）
- WorkBuddy 连接器片段 `connectors/workbuddy/mcp.json` 与 skill `wps365-mcp`：企业账号 `config init` + `auth login --device` 后接本地 `mcp serve`；与金山文档个人 MCP（mcp-center）分开

### Changed
- `auth login --device` 不再内嵌 ASCII 二维码，只打印验证 URL 与 `user_code`。需要码时用 `auth qrcode` 或走 `config init`
- MCP / `auth login` 缺凭证时优先引导 `config init --new`，再 `auth login --device --scopes "..."`，不再把主路径写成 `auth setup`（避免 WorkBuddy Agent 走错）
- MCP tool 名去掉 `wps365_` 前缀（`user_me` 而非 `wps365_user_me`），避免 WorkBuddy 用 server 名再拼一层变成 `wps365_wps365_*`。Cursor / Claude 仍靠 server 名隔离。已接入的客户端需重载 MCP。

### Fixed
- API 错误提示：识别 `403000001` / `ErrPrivileges`（含权益点如 `interface_company_doc`）时，在 stderr 追加 hint，引导联系企业管理员开通【商业高级版】/【商业旗舰版】，并明确非 OAuth scope
- Skills：纠正「CLI 不能创建应用」误判——公有云重新初始化优先 `config init [--new] [--force]`；`provider bootstrap` 为可选且需先 `--help` 探测；写入 getting-started（中英文）与 shared

## [0.3.4] - 2026-08-27

### Fixed
- 凭证存储：keychain 写入后立即读回校验；macOS 上 `Set` 假成功时不再静默通过，`auto` 会回退 `file`，`keychain` 后端会报错并提示 `WPS365_KEYRING_BACKEND=file`
- Skills / curated：`airsheet data update` 的 `--range-data-body` 示例改为 `row_from`/`row_to`/`col_from`/`col_to`；误用 `row`/`col` 会被服务端忽略并写到 A1
- Skills：`403000001` / `ErrPrivileges: interface_*` 明确为企业套餐权益不足，引导联系企业管理员开通商业高级版或商业旗舰版（非 OAuth scope）；写入 shared / getting-started，并同步 drive/airpage/airsheet 提示
- Skills：`wps365-drive` 去掉易误导的「upload 通常 ≥ 0.4.3」表述，改为以 `drive file upload --help` 探测；并注明开源 0.3.x 预置 CLI 不含该命令

### Changed
- 安装脚本默认从国内 CDN 拉取 release，GitHub 作为回退；安装完成后的首次指引改为三步：`config init` → `auth login --device` → `user me`（与 README / `--help` 对齐）
- Skills：`wps365-im` 明确 `im chat-message list` 默认使用 `--order desc` 从最近消息往前查，避免长群聊按 asc 从最早翻导致极慢
- OpenAPI / Skills：`POST /v7/messages/batch_create`（`im message send`）补齐 `delegated` security，默认优先用户授权发消息；需应用身份时显式 `--token-type app`
- Skills：存量升级引导强化——Agent 须优先用 skills 包内 `spec/api.yaml`+`curated.yaml` 覆盖本机 `$(wps365-cli config path)/spec/`（CDN 可能滞后）；写入 `wps365-shared` / `wps365-getting-started`（中英文）/ `wps365-im`
- Skills：`wps365-airpage` 补齐本地插图（coop 附件三步 + picture block）、heading/picture/有序列表 JSON 示例；`wps365-drive` 单列「上传附件」与 `drive file upload` 区分，避免 Agent 走断头路
- Skills：`wps365-airpage` 强化写入禁令——禁止 v1 `--arg`、禁止用 `import` 写正文、v2 `api` body 勿包 `request`；查块优先 `airpage block get`
- Skills：`wps365-im` 用户授权发消息一律 `POST /v7/messages/create`（`receiver.type=user|chat`）；多用户则循环多次；`batch_create` / 精装 send 仅作应用身份批量

## [0.3.3] - 2026-08-20

### Added
- 精装命令：`drive doclib list` / `drive doclib get`，查询当前用户有权限的文档库/团队文档；列团队文件再走已有 `drive file list <drive_id> 0`（全员团队客户端筛 `group.type == "whole"`）
- 精装命令：智能文档 `airpage`（创建/读取、v2 块读写、OTL JSON 导入、导出 docx/json）；pdf 完整请求体走 `api` 兜底
- 精装命令：智能表格 `airsheet`（创建文件、工作表、选区读写/查找、追加行）；复杂 JSON 用 `--*-body`
- Skills：新增快速接入入口 `wps365-getting-started`（中英文），以及 `scripts/package-skills.sh`（可打包 skills，可选 `--cli-dir` 预置 CLI 归档）；客户包 `wps365-skills-0.3.2.zip` 预置 CLI v0.3.2 多平台归档

### Fixed
- `airsheet` 精装示例对齐 OpenAPI：`op_type` 使用 `cell_operation_type_formula`；`data find` 的 `--filter-body` 使用 `condition` / `search` / `duplicates`

### Changed
- `airpage block get/create/update/delete` 改绑 v2 结构化 JSON：`airpage block create --content "一段字"` 即可写入正文（不再使用无法在开源侧编码的 v1 `--arg`）
- v2 块接口 HTTP body 对齐网关：发送未包 `request` 的块请求（`{"block_id":"doc",...}`）；OpenAPI path 的 requestBody 改为内层 schema
- OpenAPI 补齐 airpage v2 块协议、`import_from_docx` 与 airsheet worksheets/range_data/rows，供 `api` 兜底
- `scripts/install.sh` / `scripts/install.ps1`：支持 `WPS365_INSTALL_DIR` 覆盖安装目录；默认 `~/.local/bin`，无需 sudo
- 根命令 `--help` 增加开始使用三步（`config init` / `auth login --device` / `user me`），`config` 与 `auth login` 帮助文案同步
- README 快速开始改为使用指南中的三步路径：`config init` → `auth login --device` → `user me`
- Skills：`user list` / `user search` 翻页指引改为跟 `next_page_token`（`--page-token`）；因通讯录可见性，`--with-total` / `total` 不可靠，勿用来控制翻页（`wps365-user`、`wps365-contacts`）
- Skills：禁止 Agent 使用 `dept list <root_id>`、`dept member list <root_id> --recursive --all` 及等价 `api` 递归遍历全企业部门/成员（`wps365-contacts`、`wps365-user`、`wps365-shared`、`wps365-getting-started`）
- Skills：`wps365-im` 补充 `im chats list` 支持用户授权（delegated + `kso.chat.read`）查看消息会话列表；命令名对齐运行时 `im chats`（复数）
- Skills：说明旧版升级到新版 CLI 后须执行 `wps365-cli spec update -y`，以拉取 CDN 最新 YAML（`wps365-getting-started`、`wps365-shared`）
- Skills：`wps365-drive` 移植本地上传说明（`drive file upload`、分块参数与常见报错）；客户包 `wps365-skills-0.3.4.zip` 仅更新该 skill，预置 CLI 仍与 `0.3.2` 相同
- Skills：能力地图挂上 `airpage` / `airsheet` / `drive doclib`；`wps365-airpage` / `wps365-airsheet` / `wps365-drive` 登录示例对齐 `--device --scopes`，并说明创建文件需 `kso.file.readwrite`、列盘/文档库依赖企业套餐权益

## [0.3.2] - 2026-08-13

### Added
- 业务 API HTTP 超时可配置：全局 `--timeout`、环境变量 `WPS365_TIMEOUT`、`config set timeout`（Go duration 或常见别名如 `2m`/`2min`，默认 `30s`；`0`/`none`/`unlimited` 表示不限制）

## [0.3.1] - 2026-07-22

### Changed
- `auth login --device` 在有浏览器环境时自动打开验证页（与 `config init` 一致）；无浏览器时仅提示，不中断登录

### Fixed
- 移除执行期基于本地 `granted_scopes` 的硬门禁；device login 等账本为空/不全时不再误拦已授权请求（授权以服务端为准）

## [0.3.0] - 2026-07-22

### Added
- OAuth2 Device Authorization Grant（RFC 8628）：`auth login --device`，适配 SSH / Docker / CI 等无浏览器环境
- Device login 允许省略 `--scopes`（授权码登录仍要求显式传入）
- `config init`：开放平台应用绑定流程（begin/poll），凭证写入 config 与 keychain；支持 `--new`（创建新应用）与 `--app-id`（绑定已有应用）

### Fixed
- `auth setup` 读取旧 Secret Key 失败时可覆盖写入；修正废弃的 `file.search` scope
- `auth clean` / provider auth clean 同步清除 `client_id`，避免半配置状态
- 登录成功 JSON 不再输出 `granted_scopes`（改由 `auth status` 查看）
- 精简 `config init` 成功提示文案
- root 环境下跳过 `specfile` chmod 权限测试，修复 CI

## [0.2.0] - 2026-04-08

### Changed
- Module path migrated from internal `wps365-cli` to `github.com/wps365-open/cli`
- Go minimum version downgraded from 1.25 to 1.23 for broader community compatibility
- Error returns wrapped with `fmt.Errorf` context across 13 source files (~100 call sites)
- `ResolvedCredentials.ClientId` unified to `ClientID` (JSON tag unchanged: `client_id`)

### Added
- Per-file MIT license headers on all 48 Go source files
- `LICENSES-THIRD-PARTY.txt` — third-party license compatibility report
- `CONTRIBUTING.md`, GitHub Issue/PR templates
- Unit tests for `providerdef` registry and `cli` provider helpers
- ASCII workflow diagram in `transport/client.go` documenting token acquisition flow
- One-line install scripts: `curl | bash` (macOS/Linux) and `irm | iex` (Windows PowerShell)

### Fixed
- README: "8 domains, 180+ commands" → "7 domains, 100+ commands" (actual counts from `curated.yaml`)
- README: feature table aligned with actual curated command coverage per domain
- README: `api` subcommand shows all 6 HTTP methods; removed non-existent `spec path/set/add`
- README: outdated examples corrected (date, flags, API base URL)
- README: added `auth token --app` usage; synced all changes to English README

[Unreleased]: https://github.com/wps365-open/cli/compare/v0.3.5...HEAD
[0.3.5]: https://github.com/wps365-open/cli/releases/tag/v0.3.5
[0.3.4]: https://github.com/wps365-open/cli/releases/tag/v0.3.4
[0.3.3]: https://github.com/wps365-open/cli/releases/tag/v0.3.3
[0.3.2]: https://github.com/wps365-open/cli/releases/tag/v0.3.2
[0.3.1]: https://github.com/wps365-open/cli/releases/tag/v0.3.1
[0.3.0]: https://github.com/wps365-open/cli/releases/tag/v0.3.0
[0.2.0]: https://github.com/wps365-open/cli/releases/tag/v0.2.0
