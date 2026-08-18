# 常见问题

## 多维表（DbSheet）

### 获取不了在线表格中的图片链接？

多维表中的图片和附件需要两步获取：

**第一步：获取记录中的 attachment_id**

```bash
wps365-cli dbsheet records list <file-id> <sheet-id> --fields "图片字段名"
```

返回的记录中，附件类型字段的值是 JSON 字符串，其中包含 `attachment_id`。

**第二步：通过附件接口获取下载链接**

```bash
wps365-cli api get "/v7/coop/dbsheet/<file-id>/attachments/<attachment-id>"
```

响应中的 `data.attachment.value.download_url` 即为图片/附件的下载链接。

**注意事项：**
- 需要 `kso.dbsheet.read` 或 `kso.dbsheet.readwrite` 权限
- `delegated` 和 `app` 两种认证模式均支持
- 下载链接可能有时效限制，建议获取后及时使用

> 目前 `dbsheet attachments get` 尚未收录为精装命令，需通过 `api get` 调用。后续版本将支持直接使用精装命令。

## 个人版

### 个人版能否使用 wps365-cli？

wps365-cli 依赖 WPS 365 开放平台的 OAuth2 认证体系，需要企业版管理员创建应用并审批权限。个人版用户暂无法使用。

详见 [前置准备：创建应用与权限配置](prerequisites.md)。

## 认证与权限

### 权限申请后为什么没有生效？

权限申请后需要完成「创建版本 → 申请发布 → 企业管理员审批」的完整流程才会生效。仅申请权限而不提交版本审批，权限会一直处于「待提交审核」状态。

详见 [前置准备：创建应用与权限配置](prerequisites.md)。

### CLIENT_SECRET 泄露了怎么办？

立即在开发者后台「应用凭证」区域点击「重置」生成新密钥，旧密钥立即失效。然后重新执行 `wps365-cli auth setup` 配置新凭证。

## Agent 集成

### AI Agent 如何调用 wps365-cli？

wps365-cli 提供两个 Agent 友好特性：

- `--dry-run`：预览请求而不实际发送，适合 Agent 试探式调用
- `-o json`：结构化 JSON 输出，方便 Agent 解析

```bash
# Agent 先预览请求
wps365-cli --dry-run -o json user me

# 确认无误后实际执行
wps365-cli -o json user me
```

> 更深度的 Agent 集成（如 MCP 协议适配）正在规划中，欢迎关注后续更新。
