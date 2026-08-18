# OpenAPI-to-CLI Command Mapping Rules

This document defines how WPS 365 OpenAPI paths map to CLI commands, both for curated commands and the raw `api` escape hatch.

## Mapping Overview

```
OpenAPI Path                          CLI Command
─────────────────                     ──────────────────────────────
/v7/calendars                    →   calendar list
/v7/calendars/{id}/events/create →   calendar events create <id>
/v7/messages/batch_create        →   im messages send --to ... --text ...
/v7/coop/dbsheet/{fid}/schema    →   dbsheet schema get <fid>
/v7/aiopen/aigc/compose          →   api post "/v7/aiopen/aigc/compose"
```

The mapping is defined declaratively in two spec files:
- **API spec** (`spec/api/365.yaml`): Full OpenAPI 3.0 definition with paths, schemas, and security.
- **Curated spec** (`spec/curated/365.yaml`): Hand-crafted command definitions that reference the API spec.

## Path-to-Command Transformation Rules

### Rule 1: Resource Extraction

Strip `/v7/` prefix and API version, then split the remaining path into resource segments:

```
/v7/calendars/{calendar_id}/events/create
     ────────────────────── ────── ──────
     resource path           sub    verb
```

### Rule 2: Path Parameters → Positional Args

OpenAPI path parameters `{calendar_id}`, `{event_id}` become positional CLI args:

| OpenAPI Path Parameter | CLI Arg Name | Position |
|------------------------|-------------|----------|
| `{calendar_id}` | `calendar-id` | 1st |
| `{event_id}` | `event-id` | 2nd |
| `{drive_id}` | `drive-id` | 1st |
| `{file_id}` | `file-id` | 2nd |

Naming: always use `{resource}-id` format in kebab-case (e.g., `calendar-id`, `file-id`). Do not strip the `-id` suffix even when the resource name implies it — consistency across all commands is more important than brevity.

### Rule 3: Verb Normalization

OpenAPI operations use various naming conventions. Curated commands normalize to a fixed verb set:

| OpenAPI Operation / Path Suffix | CLI Verb | Examples |
|-------------------------------|----------|----------|
| `GET /collection` | `list` | `calendar list`, `user list` |
| `GET /resource/{id}` | `get` | `calendar get`, `drive files get` |
| `POST /collection/create` | `create` | `calendar events create` |
| `POST /resource/{id}/update` | `update` | `calendar events update` |
| `POST /resource/{id}/delete` | `delete` | `calendar events delete` |
| `POST /collection/batch_create` | `batch-create` | `calendar events batch-create` |
| `POST /collection/batch_read` | `batch-get` | `user batch-get` |
| `POST /collection/batch_delete` | `batch-delete` | `drive files batch-delete` |
| `POST /subcollection/batch_create` | `add` | `calendar event-attendee add` |
| `POST /subcollection/batch_delete` | `remove` | `calendar event-attendee remove` |
| `GET /search` | `search` | `drive files search` |
| `POST /search` | `search` | `dbsheet records search` |
| Custom action | Action verb | `meeting end`, `im messages recall` |

Key normalization decisions:
- **Write endpoints are POST, not PATCH/PUT**: WPS 365 OpenAPI uses POST for all mutations with explicit verb suffixes (`/create`, `/update`, `/delete`). The CLI reflects this — there are no PATCH/PUT curated commands.
- **Batch mutations on sub-collections use `add`/`remove`**: `batch_create` on a sub-collection (attendees, members) reads as "add to collection" from the user's perspective.
- **Mixed read verbs**: `POST /batch_read` → `batch-get`; `POST /search` → `search`.

### Rule 4: Resource Nesting

Sub-resources become nested command groups:

```
/v7/calendars/{id}/events              → calendar events
/v7/calendars/{id}/events/{eid}/attendees → calendar event-attendee
/v7/meetings/{id}/participants         → meeting participants
/v7/meetings/{id}/recordings           → meeting recordings
/v7/drives/{did}/files/{fid}/permissions → drive file-permission
/v7/drives/{did}/files/{fid}/versions  → drive file-version
```

Rules:
- Flatten deep nesting: `calendar event-attendee` not `calendar events attendee`.
- Use compound nouns with hyphens: `event-attendee`, `file-permission`, `room-level`.
- Maximum depth: 3 command segments (`resource sub-resource verb`). Deeper paths flatten the middle.

### Rule 5: Non-Standard Path Patterns

Some API paths don't follow the `/resource/{id}/action` pattern:

| API Path | CLI Command | Mapping Strategy |
|----------|-------------|------------------|
| `/v7/users/current` | `user me` | Semantic alias for current user |
| `/v7/free_busy_list` | `calendar free-busy list` | Reassign to most relevant domain |
| `/v7/chats/get_p2p_chat` | `im p2p-chat get` | Action-as-resource pattern |
| `/v7/messages/batch_create` | `im messages send` | Semantic rename (send ≠ batch_create) |
| `/v7/drive_latest/items` | `drive recent-file list` | Reassign to resource context |
| `/v7/files/search` | `drive files search` | Cross-resource search assigned to primary domain |

These require manual curation — automated mapping produces awkward results.

## Query Parameter Mapping

OpenAPI query parameters map to CLI flags with `to: query.param_name`:

```yaml
flags:
  - name: page-size
    type: integer
    default: 20
    to: query.page_size
  - name: page-token
    type: string
    to: query.page_token
```

Naming: CLI uses kebab-case; query params use snake_case. The `to:` field handles the translation.

## Request Body Mapping

### Simple Fields

Direct flag-to-field binding:

```yaml
flags:
  - name: name
    type: string
    description: 日程标题
body:
  bindings:
    - from_flag: name
      to: summary              # CLI flag "name" → API field "summary"
```

### Nested Objects

Use dot notation and array indexing:

```yaml
body:
  bindings:
    - from_flag: text
      to: content.text.content     # Deep nesting
    - from_flag: to
      to: receivers[0].receiver_ids # Array element
```

### Type Coercion

OpenAPI schemas declare types; the CLI enforces them:

| OpenAPI Type | CLI Flag Type | Validation |
|-------------|---------------|------------|
| `string` | `string` | None |
| `integer` | `integer` | Must parse as int |
| `boolean` | `boolean` | Accepts true/false/1/0 |
| `array<string>` | `string[]` | Repeatable flag (`--to u1 --to u2`) |
| `object` | `string` + `parse_json` | Accept JSON string |

## Security Mapping

OpenAPI `security` schemes determine auth requirements:

```yaml
# OpenAPI spec
security:
  - oauth2_delegated: [kso.calendar.read]
  - oauth2_app: [kso.calendar.read]
```

This translates to:
- Both `delegated` and `app` auth modes accepted.
- The CLI validates that the current session has at least one compatible mode.
- Scope `kso.calendar.read` is checked against the token's granted scopes.

When only one mode is declared:

```yaml
security:
  - oauth2_delegated: [kso.calendar.read]
```

The CLI requires delegated auth. Running with `--token-type app` produces an immediate error.

## The `api` Escape Hatch

Any endpoint not covered by curated commands is accessible via:

```bash
wps365-cli api get "/v7/some/uncurated/endpoint"
wps365-cli api post "/v7/some/uncurated/endpoint" --data '{"key": "value"}'
```

The `api` command:
- **Reuses the auth session** — no separate login needed.
- **Supports all output formats** (`-o json|yaml|table|tsv`).
- **Supports `--dry-run`** — prints the request without sending.
- **No body mapping** — the user provides raw JSON via `--data`.

This ensures 100% API coverage even before curation.

## Custom Spec Extension

Users can add curated commands for internal or custom endpoints:

```bash
wps365-cli spec add --custom-curated ./my-commands.yaml
```

Custom specs are loaded after the official spec, allowing overrides and additions. See [spec-discovery.md](spec-discovery.md) for the full loading order.

## Mapping Audit: Current Coverage

The table below summarizes path-to-command mapping patterns across all 7 domains:

| Pattern | Count | Example |
|---------|-------|---------|
| `GET /{resource}` → `list` | 18 | `calendar list` |
| `GET /{resource}/{id}` → `get` | 22 | `user get` |
| `POST /{resource}/create` → `create` | 21 | `calendar create` |
| `POST /{resource}/{id}/update` → `update` | 14 | `dbsheet sheets update` |
| `POST /{resource}/{id}/delete` → `delete` | 18 | `im chats delete` |
| `POST /{sub}/batch_create` → `add` | 8 | `calendar event-attendee add` |
| `POST /{sub}/batch_delete` → `remove` | 8 | `im chat-member remove` |
| `POST /batch_*` → `batch-*` | 12 | `user batch-get` |
| `GET/POST /search` → `search` | 5 | `drive files search` |
| Semantic alias | 6 | `user me`, `im messages send` |
| Action verb | 20 | `meeting end`, `im messages recall` |
| **Total** | **152** | |

~649 paths are accessible only via `api get|post` (some curated commands share the same path with different method/auth, so the exact count varies by dedup method).

## Comparison with Slock CLI (kscc)

kscc does not use a spec-driven mapping system. Its commands are defined in TypeScript with explicit argument parsers. Key differences:

| Aspect | wps365-cli | kscc |
|--------|-----------|------|
| Mapping source | Declarative YAML → runtime resolver | Imperative code |
| Adding commands | Edit spec YAML + restart | Write command module |
| API coverage | 152 curated + ~649 raw | 20 commands, no raw fallback |
| Body mapping | `bindings` + `transforms` | `zod` schema parsing |
| Auth validation | Spec-driven per-command | Global middleware |
| Agent integration | `--dry-run` + `-o json` | MCP protocol + hooks |

The spec-driven approach trades flexibility for scalability — adding a command requires no code change, only a spec entry. kscc's code-first approach is more flexible for complex workflows (task lifecycle, thread attention) but harder to scale to 800+ endpoints.

## Recommendations for Future Contributions

1. **Prioritize high-traffic endpoints** — Check `api` command usage logs to find the most-used raw paths; curate those first.
2. **Preserve semantic names** — Don't blindly mirror the API path. `im messages send` is better than `im messages batch-create`.
3. **Minimize positional args** — Only resource IDs should be positional. Everything else is a flag.
4. **Document transforms** — When adding a new transform, add it to the transform registry and document the input/output types.
5. **Test with `--dry-run`** — Every new curated command should produce the correct HTTP request without actually sending it.
