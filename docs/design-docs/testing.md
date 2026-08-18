# 测试策略与 E2E 约束

wps365-cli 是闭源二进制分发，仓库中不包含测试代码。本文档描述 CLI 的测试约束、可用的验证手段，以及针对开源贡献场景的测试建议。

## 约束

### 1. 闭源二进制，无单元测试可参考

Go 源码未公开，无法直接运行或调试单元测试。所有行为观测依赖黑盒方式——运行二进制、检查输出与退出码。

### 2. 需要真实企业账号

WPS365 开放平台 API 要求：
- 已创建的企业自建应用
- 已申请并通过审批的 API 权限
- 有效的 OAuth 凭证（client_id + client_secret）

没有企业账号，无法完成端到端调用。

### 3. OAuth 授权流程需要浏览器

`auth login --scopes "..."` 启动本地 HTTP 服务监听回调，需要用户在浏览器中完成授权。这不适合 CI/CD 环境，也无法在无头环境中自动完成。

App 模式登录（`auth login --app`）不依赖浏览器，可在 CI/CD 中使用：
```bash
export WPS365_CLIENT_ID="<client-id>"
export WPS365_CLIENT_SECRET="<client-secret>"
wps365-cli auth login --app
```

### 4. API 调用有速率限制

WPS365 开放平台对 API 调用有频率限制。自动化测试若短时间大量调用，可能触发限流导致误判。

### 5. 接口依赖特定数据状态

许多接口需要特定的前置数据才能正常返回。例如：
- 日历操作需要已存在的日历 ID
- 群聊操作需要有效的群 ID
- 文件操作需要有效的 drive ID 和文件 ID

没有这些前置数据，接口返回 404 或业务错误，不代表 CLI 本身有 bug。

## 验证手段

### Dry Run

`--dry-run` 是最核心的测试工具。它使 CLI 构造请求但不实际发送，输出将要发出的 HTTP 请求详情：

```bash
# 验证精装命令的请求构造
wps365-cli --dry-run calendar events create primary \
  --name "周会" --from "2024-01-15T14:00:00+08:00" --to "2024-01-15T15:00:00+08:00"

# 验证 api 命令的路径和参数
wps365-cli --dry-run api get "/v7/users/current"

# 验证 body 序列化
wps365-cli --dry-run -o json im messages send --to u1 --text "hello"
```

dry-run 输出包含：
- HTTP 方法与路径
- 请求头（含 Authorization 类型）
- 查询参数
- 请求 body（JSON）
- 目标 API base URL

这足以验证：
- 命令参数到 API 参数的映射是否正确
- body 绑定与 transform 管道是否生效
- 认证模式选择是否符合 security 约束

#### 当前限制

当前版本（v0.1.0）的 dry-run 在未登录状态下返回 "not logged in" 错误（exit code 5），而非直接输出请求构造。这意味着 dry-run 仍需有效的认证状态才能使用。在 CI/CD 场景中，可先用 `auth login --app` 建立 app token，再运行 dry-run 验证。

### 结构化输出

`-o` 参数控制输出格式，可用于断言：

```bash
# JSON 输出，适合 jq 断言
wps365-cli -o json user me

# YAML 输出
wps365-cli -o yaml calendar list

# 表格输出，适合人工检查
wps365-cli -o table calendar list

# TSV 输出，适合管道处理
wps365-cli -o tsv calendar list | cut -f2
```

### 退出码

| 退出码 | 含义 |
|--------|------|
| 0 | 成功 |
| 1 | 一般错误 |
| 2 | 参数错误（无效 flag、缺少必需参数等） |
| 5 | 未登录 / 认证失败 |
| 7 | 网络错误（连接超时、DNS 解析失败等） |

脚本可通过退出码判断命令是否成功，无需解析输出。

### 静默模式

`--quiet` 或 `WPS365_QUIET=true` 抑制 stderr 信息输出，仅保留 stdout 数据。这避免了信息文本对输出解析的干扰。

## 测试策略建议

### 第一层：Dry Run 验证（无需真实数据）

在 app token 建立后，用 dry-run 验证命令参数映射：

```bash
# 建立 app token（一次性）
export WPS365_CLIENT_ID="<client-id>"
export WPS365_CLIENT_SECRET="<client-secret>"
wps365-cli auth login --app

# 验证精装命令
wps365-cli --dry-run -o json calendar events create primary \
  --name "测试" --from "2024-01-15T14:00:00+08:00" --to "2024-01-15T15:00:00+08:00"
```

断言 dry-run 输出中的：
- HTTP method 为 POST
- path 包含 `/v7/calendars/primary/events/create`
- body 中 `summary` 字段为 "测试"
- body 中 `start_time` 字段正确

这类测试可在 CI/CD 中运行，不需要特定数据状态。

### 第二层：只读接口验证（需要真实账号）

对只读接口做轻量端到端验证：

```bash
wps365-cli user me
wps365-cli calendar list
wps365-cli -o json user me | jq '.data.user_id'
```

断言：
- 退出码为 0
- 输出为合法 JSON
- 关键字段存在且类型正确

注意控制调用频率，避免触发限流。

### 第三层：写入接口验证（手动 / 隔离环境）

写入接口（创建日程、发送消息等）应在隔离测试环境中进行，手动验证。建议：
- 使用专门的测试应用，避免污染生产数据
- 每次测试后清理创建的资源
- 记录请求与响应用于回归比对

#### 幂等测试模式

对于写入接口，可采用"创建-验证-删除"模式确保测试不留下残留数据：

```bash
# 创建日程
EVENT_ID=$(wps365-cli -o json calendar events create primary \
  --name "测试日程" --from "2024-01-15T14:00:00+08:00" --to "2024-01-15T15:00:00+08:00" \
  | jq -r '.data.event_id')

# 验证日程存在
wps365-cli calendar events get primary "$EVENT_ID"

# 清理：删除测试日程
wps365-cli calendar events delete primary "$EVENT_ID"
```

此模式要求删除接口可用。若接口不支持删除（如发送消息），则应在专门的测试群聊中执行，并标记测试数据以便后续人工清理。

### CI/CD 集成示例

以下 GitHub Actions 工作流展示如何在 PR 中自动验证文档引用的命令参数是否正确：

```yaml
name: CLI dry-run validation
on: pull_request
jobs:
  dry-run:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install wps365-cli
        run: curl -fsSL https://raw.githubusercontent.com/wps365-open/cli/main/install.sh | bash
      - name: Login as app
        env:
          WPS365_CLIENT_ID: ${{ secrets.WPS365_CLIENT_ID }}
          WPS365_CLIENT_SECRET: ${{ secrets.WPS365_CLIENT_SECRET }}
        run: wps365-cli auth login --app
      - name: Validate calendar command
        run: |
          wps365-cli --dry-run -o json calendar events create primary \
            --name "CI test" --from "2024-01-15T14:00:00+08:00" \
            --to "2024-01-15T15:00:00+08:00" \
            | jq -e '.method == "POST" and (.path | contains("/v7/calendars/primary/events/create"))'
      - name: Validate user command
        run: |
          wps365-cli --dry-run -o json user me \
            | jq -e '.method == "GET" and (.path == "/v7/users/current")'
```

`jq -e` 标志使 jq 在表达式结果为 `false` 或 `null` 时以 exit 1 退出，搭配 `set -e` 可实现断言效果——表达式为真则继续，为假则中断流水线。

## 文档贡献的测试

本仓库当前主要接受文档贡献。文档测试的重点是：

1. **链接可达性**：所有文档内链接（特别是指向 `docs/design-docs/` 下其他文档的引用）应指向实际存在的文件
2. **命令准确性**：文档中出现的 CLI 命令和参数应与实际行为一致，可用 `--help` 或 `--dry-run` 交叉验证
3. **示例可复现**：代码块中的示例在具备凭证的前提下应可运行

### 链接检查脚本

```bash
#!/usr/bin/env bash
# 检查 markdown 文件中的内部链接是否指向存在的文件
grep -roP '\[.*?\]\(([^)]+)\)' docs/ README.md | \
  sed 's/.*](\([^)]*\))/\1/' | \
  grep -v '^http' | \
  while read -r link; do
    target="$(dirname "$link")/$(basename "$link" | sed 's/#.*//')"
    [ -f "$target" ] || echo "BROKEN: $link"
  done
```

### Spec 完整性检查

验证精装命令引用的路径和 schema 在 API spec 中均存在：

```bash
# 验证所有精装命令的 path 在 API spec 中存在
grep -oP 'path: \K.*' spec/curated/365.yaml | sort -u | while read -r p; do
  escaped_path=$(echo "$p" | sed 's/{[^}]*}/[^\/]+/g')
  if ! grep -qP "^\s+\"?$escaped_path\"?:" spec/api/365.yaml; then
    echo "BROKEN PATH: $p"
  fi
done

# 验证 schema 引用指向存在的组件
grep -oP '(request|response)_schema_ref: \K.*' spec/curated/365.yaml | sort -u | while read -r ref; do
  component=$(echo "$ref" | sed 's|#/components/schemas/||')
  if ! grep -qP "^\s+${component}:" spec/api/365.yaml; then
    echo "BROKEN SCHEMA: $ref"
  fi
done
```

### Dry-run 断言示例

以下示例使用 `jq -e`，其中 `-e` 标志表示当表达式结果为 `false` 或 `null` 时 jq 以退出码 1 退出，便于脚本断言失败时中断。

```bash
# 断言请求方法
wps365-cli --dry-run -o json calendar events create primary \
  --name "测试" --from "2024-01-15T14:00:00+08:00" --to "2024-01-15T15:00:00+08:00" \
  | jq -e '.method == "POST"'

# 断言 transform 结果
wps365-cli --dry-run -o json calendar events create primary \
  --name "测试" --from "2024-01-15T14:00:00+08:00" --to "2024-01-15T15:00:00+08:00" \
  --reminders "30,10" \
  | jq -e '.body.reminders | length == 2'

# 断言默认值注入
wps365-cli --dry-run -o json im messages send \
  --to ou_abc --text "hello" \
  | jq -e '.body | {type, "receivers_type": .receivers[0].type}'
# 期望: {"type": "text", "receivers_type": "user"}
```

## CI/CD 集成

### GitHub Actions 示例

```yaml
name: CLI 冒烟测试
on: [push, pull_request]
jobs:
  dry-run:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: 安装 wps365-cli
        run: curl -fsSL https://raw.githubusercontent.com/wps365-open/cli/main/install.sh | bash
      - name: 配置应用凭证
        env:
          WPS365_CLIENT_ID: ${{ secrets.WPS365_CLIENT_ID }}
          WPS365_CLIENT_SECRET: ${{ secrets.WPS365_CLIENT_SECRET }}
        run: wps365-cli auth login --app
      - name: Dry-run 冒烟测试
        run: |
          wps365-cli --dry-run user me
          wps365-cli --dry-run calendar list
          wps365-cli --dry-run api get "/v7/users/current"
      - name: 验证 spec 完整性
        run: |
          SPEC_DIR=$(wps365-cli spec path)
          grep -oP 'path: \K.*' "$SPEC_DIR/curated/365.yaml" | sort -u | while read -r p; do
            escaped_path=$(echo "$p" | sed 's/{[^}]*}/[^\/]+/g')
            if ! grep -qP "^\s+\"?$escaped_path\"?:" "$SPEC_DIR/api/365.yaml"; then
              echo "BROKEN: $p not found in API spec" && exit 1
            fi
          done
```
