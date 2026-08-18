# Spec 文件管理与加载机制

wps365-cli 基于 OpenAPI 3.0 规范文件驱动命令生成。本文档描述 spec 文件的存储位置、自动下载、增量更新与自定义覆盖的完整机制。

## 概述

CLI 在运行时读取两类 spec 文件：

| 文件 | 路径 | 内容 | 行数 |
|------|------|------|------|
| API 规范 | `spec/api/365.yaml` | OpenAPI 3.0 全量接口定义（801 paths） | ~74k |
| 精装目录 | `spec/curated/365.yaml` | 精装命令的声明式目录（152 commands） | ~5k |

此外还有自定义覆盖目录（详见[自定义覆盖](#自定义覆盖)）。

## 存储位置

spec 文件存放在配置目录下，路径因操作系统而异：

| OS | 路径 |
|----|------|
| macOS | `~/Library/Application Support/wps365-cli/spec/` |
| Linux | `~/.local/share/wps365-cli/spec/` 或 `$XDG_DATA_HOME/wps365-cli/spec/` |
| Windows | `%APPDATA%\wps365-cli\spec\` |

目录结构：

```
spec/
├── api/
│   ├── 365.yaml              # 官方 API 规范
│   ├── 365.yaml.md5          # 缓存校验
│   └── customs/              # 用户自定义 API 覆盖
│       └── my-extension.yaml
├── curated/
│   ├── 365.yaml              # 官方精装目录
│   ├── 365.yaml.md5          # 缓存校验
│   └── customs/              # 用户自定义精装覆盖
│       └── my-commands.yaml
└── osh/                      # OSH 网关 spec（按需下载）
    └── ...
```

## 自动下载

### 触发时机

当 CLI 执行任何精装命令时，内部调用 `EnsureLocalSpecs` → `ensureSpecs`，检查 spec 文件是否存在：

- 两个 spec 文件都存在 → 跳过下载，直接加载
- 任一文件缺失 → 自动从远程下载

可通过环境变量控制：

```bash
# 禁止自动下载（缺省：true）
WPS365_SPEC_AUTO_DOWNLOAD=false
```

禁用后，若 spec 文件缺失，精装命令将不可用，但仍可使用 `api` 命令直接调用接口。

### 下载源

默认远程地址：

```
https://open.wps.cn/cli/specs/v1/{api,curated}/365.yaml
```

可通过环境变量覆盖：

```bash
WPS365_SPEC_BASE_URL=https://your-mirror.example.com/specs
```

内部通过 `effectiveSpecBaseURL` 解析最终地址。

### 缓存与增量更新

每次下载后，CLI 将文件的 MD5 哈希存为 `.md5` 后缀文件。下次启动时 `checkSpecUpdates` 比对远程哈希：

- 哈希未变 → 跳过下载
- 哈希变化 → 重新下载并更新 `.md5` 文件

`specURLWithHash` 函数在下载 URL 后追加哈希后缀用于缓存控制。

### 手动更新

```bash
# 检查并下载最新 spec
wps365-cli spec update
```

## 加载流程

```
用户执行命令
  │
  ├─ EnsureLocalSpecs()           # 确保本地 spec 存在
  │   └─ ensureSpecs()            # 缺失时触发自动下载
  │
  ├─ Load() / LoadWithOverrides() # 加载 spec 到内存
  │   ├─ loadAPISpec()            # 解析 api/365.yaml
  │   ├─ loadOfficialCatalog()    # 解析 curated/365.yaml
  │   ├─ loadOshCatalog()        # 解析 osh/ 目录（如存在）
  │   └─ loadCatalogDir()        # 解析 customs/ 目录
  │
  └─ 命令执行                      # 根据加载的 spec 路由到具体处理逻辑
```

加载后，CLI 将 OpenAPI paths 注册为 `api` 子命令，将 curated commands 注册为语义化子命令。

## spec 子命令

| 命令 | 说明 |
|------|------|
| `spec update` | 检查远程更新并下载 |
| `spec set --api <file>` | 替换官方 API 规范文件 |
| `spec set --curated <file>` | 替换官方精装目录文件 |
| `spec add --custom-api <file>` | 添加自定义 API 覆盖到 customs 目录 |
| `spec add --custom-curated <file>` | 添加自定义精装覆盖到 customs 目录 |

`spec set` 是替换操作——将官方 spec 替换为指定文件，CLI 后续使用替换后的版本。

`spec add` 是叠加操作——在官方 spec 基础上添加自定义覆盖，两者合并生效。

## 自定义覆盖

### API 覆盖

将 OpenAPI 3.0 格式的 YAML 文件放入 `spec/api/customs/` 目录（或使用 `spec add --custom-api`）。CLI 加载时会合并官方 spec 与所有 customs 文件。

适用场景：
- 补充官方 spec 尚未收录的接口
- 覆盖官方 spec 中描述不准确的字段
- 内部测试环境使用不同的接口定义

### 精装命令覆盖

将精装目录格式的 YAML 文件放入 `spec/curated/customs/` 目录（或使用 `spec add --custom-curated`）。CLI 加载时会合并官方目录与所有 customs 文件。

适用场景：
- 为高频接口添加更友好的命令别名
- 为团队内部接口创建专用命令
- 调整官方命令的默认参数或 body 绑定

### 自定义 API spec 格式要求

`spec/api/customs/` 下的文件必须符合 OpenAPI 3.0 规范。只需定义需要覆盖或补充的 paths，不需要重复官方 spec 中已有的内容。

示例——补充一个内部接口：

```yaml
openapi: "3.0.0"
info:
  title: Custom API extensions
  version: "1.0"
paths:
  /v7/internal/reports:
    get:
      summary: 获取内部报表
      operationId: getInternalReport
      responses:
        "200":
          description: 成功
```

### 自定义精装目录格式要求

`spec/curated/customs/` 下的文件必须遵循精装目录格式：

```yaml
version: 1
commands:
  - id: my.resource.action
    command: my resource action
    summary: 我的自定义命令
    method: GET
    path: /v7/my/resource
    args: []
    flags:
      - name: verbose
        type: bool
        required: false
        to: query.verbose
    body:
      bindings: []
    examples:
      - command: 'wps365-cli my resource action --verbose'
```

关键字段：
- `version` 必须为 `1`
- `id` 在所有目录中必须唯一，冲突时 customs 优先
- `command` 定义 CLI 命令路径（空格分隔资源层级）
- `body.bindings` 的 `transform` 支持：`split_csv`、`to_int`、`to_bool`、`parse_json`、`trim`、`wrap`、`negate`

### 合并优先级

当官方 spec 与 customs 存在相同 ID 的定义时，customs 中的定义整体替换官方定义（非字段级合并）。多个 customs 文件存在相同 ID 时，按文件名字典序排列，后者覆盖前者。

完整优先级（从低到高）：

| 优先级 | 来源 | 说明 |
|--------|------|------|
| 1 | 内嵌 spec | 编译到二进制中的官方 spec |
| 2 | 本地官方 spec | `spec/api/365.yaml` / `spec/curated/365.yaml` |
| 3 | 自定义 spec | `customs/` 目录中的文件，按文件名字典序 |

- **精装目录**：以 `id` 为键，customs 中的命令整体替换同 id 的官方命令（非字段级合并）
- **API 规范**：以 path 为键，customs 中的 path 定义覆盖同 path 的官方定义（path 级替换，非字段级合并）

### 自定义精装命令编写格式

customs 目录中的 YAML 文件与官方精装目录格式相同：

```yaml
version: 1
commands:
  - id: myteam.deploy.notify
    command: myteam deploy notify
    summary: 部署完成通知
    description: 部署完成后向指定用户发送 IM 通知
    method: POST
    path: /v7/messages/batch_create
    flags:
      - name: to
        type: string[]
        required: true
        description: 接收人 open_id 列表
      - name: text
        type: string
        required: true
        description: 通知内容
    body:
      defaults:
        type: text
        receivers[0].type: user
        content.text.type: plain
      bindings:
        - from_flag: to
          to: receivers[0].receiver_ids
        - from_flag: text
          to: content.text.content
    examples:
      - command: 'wps365-cli myteam deploy notify --to ou_abc --text "v2.3 已上线"'
        description: 部署完成后发送通知
```

编写规则：

1. **`id` 全局唯一** — 官方命令使用 `{domain}.{resource}.{verb}` 格式。自定义命令建议加组织前缀（如 `myteam.`）避免与官方冲突。
2. **`path` 必须存在于 API spec** — 如果是内部 API，需同时在 `spec/api/customs/` 中添加对应路径定义。
3. **`method` 必须与 API spec 一致** — GET 路径写 POST 会运行时报错。
4. **body 绑定使用点记法** — `content.text.content` 对应 JSON 嵌套层级。
5. **数组索引从 0 开始** — `receivers[0].receiver_ids` 对应第一个数组元素。
6. **transform 支持 pipe 组合** — 详见 [curated-commands.md](curated-commands.md) 的 Transform Pipeline 章节。
7. **`request_schema_ref` 和 `response_schema_ref` 可选** — 非所有命令都有 schema 引用，但推荐添加以增强 `--help` 输出的参数说明。

### 覆盖官方命令

在 customs 文件中使用与官方命令相同的 `id`，即可覆盖其定义：

```yaml
version: 1
commands:
  - id: calendar.list
    command: calendar list
    summary: 查询日历列表（默认50条）
    method: GET
    path: /v7/calendars
    flags:
      - name: page-size
        type: integer
        default: 50    # 覆盖官方默认值 20
        description: 每页返回的日历数量
        to: query.page_size
```

## OSH 网关 Spec

OSH（企业网关）模式的 spec 处理与标准模式不同：

- 通过 `pullOSHSpecs` / `syncOSHZip` 单独下载
- 以 ZIP 格式传输，本地解压
- 存放在 `spec/osh/` 目录下
- 由 `loadOshCatalog` 加载

OSH spec 的下载受 OSH 认证状态控制，仅在 `auth login --osh` 后才可获取。

## 调试与排查

### 命令未找到

```
Error: unknown command "calendar events create"
```

排查步骤：
1. `wps365-cli spec status` — 确认 curated spec 存在且来源正确
2. `wps365-cli calendar --help` — 检查已注册的子命令
3. 若自定义 spec 未生效，检查 `id` 是否拼写正确、文件名排序是否靠后

### 请求路径 404

```
Error: API returned 404 for POST /v7/calendars/{calendar_id}/events/create
```

排查步骤：
1. 确认 API spec 中存在该路径：`grep "/v7/calendars" spec/api/365.yaml`
2. 确认 `method` 是否正确
3. 运行 `spec update` 确保是最新 spec

### Body 映射不生效

排查步骤：
1. 使用 `--dry-run -o json` 查看实际构造的请求体
2. 检查 `to:` 字段的点记法是否与 API schema 匹配
3. 检查 transform 是否正确（如 `parse_json` 需要合法 JSON 输入）
4. 检查 `defaults` 中是否有覆盖 flag 绑定的值

### 自定义 spec 未被加载

排查步骤：
1. `wps365-cli spec status` — 确认 `custom_count` 不为 0
2. 确认文件在正确目录（`customs/` 而非根 spec 目录）
3. 确认文件格式为合法 YAML（注意缩进和 `version: 1` 顶层声明）
4. 多个 customs 文件存在同名命令时，文件名字典序靠后的优先

## 环境变量速查

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `WPS365_SPEC_AUTO_DOWNLOAD` | `true` | 是否自动下载缺失的 spec |
| `WPS365_SPEC_BASE_URL` | `https://open.wps.cn/cli/specs/v1` | spec 远程下载地址 |
| `WPS365_CONFIG_DIR` | 系统默认 | 配置目录（含 spec 子目录） |

> **注意区分**：`WPS365_SPEC_BASE_URL` 控制 spec 文件的下载源（YAML 规范文件从哪里拉取），而 `WPS365_API_BASE` 控制 API 请求的目标端点（运行时 HTTP 请求发往哪里）。两者相互独立——可以使用官方 spec 描述文件，同时将 API 请求指向内部测试环境。

## 实现包

核心逻辑位于 `wps365-cli/internal/specfile` 包：

| 函数 | 职责 |
|------|------|
| `EnsureLocalSpecs` | 入口：确保本地 spec 就绪 |
| `ensureSpecs` | 检查并触发下载 |
| `checkSpecUpdates` | 增量更新检查 |
| `downloadSpec` | 下载单个 spec 文件 |
| `specURLWithHash` | 构造带哈希的下载 URL |
| `effectiveSpecBaseURL` | 解析远程地址 |
| `Load` / `LoadWithOverrides` | 加载并合并所有 spec |
| `loadAPISpec` | 解析 OpenAPI 3.0 YAML |
| `loadOfficialCatalog` | 解析精装目录 |
| `loadOshCatalog` | 解析 OSH 目录 |
| `loadCatalogDir` | 解析 customs 目录 |
| `pullOSHSpecs` / `syncOSHZip` | OSH spec 下载与解压 |
