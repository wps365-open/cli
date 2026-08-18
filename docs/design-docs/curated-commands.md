# Curated Command Design Principles

This document describes the design principles behind WPS365 CLI's curated commands — the hand-crafted, high-level CLI verbs that sit atop the raw OpenAPI surface.

## Why Curated Commands?

The WPS 365 Open Platform exposes 800+ endpoints. Calling them directly via `api get|post` works, but raw API paths are verbose, require understanding of request body schemas, and offer no guardrails for auth or required fields.

Curated commands solve three problems:

1. **Discoverability** — `wps365-cli calendar events create` is self-documenting; `api post "/v7/calendars/{calendar_id}/events/create" --data '{...}'` is not.
2. **Safety** — Required flags surface immediately. Auth constraints (`delegated` vs `app`) are validated before the request is sent. Incompatible overrides produce errors, not silent 403s.
3. **Ergonomics** — Semantic flags with smart defaults and transforms replace manual JSON body construction.

## Dual-Track Architecture

```
User input
    │
    ├─ Curated command? ──► Spec-driven resolution ──► HTTP request
    │   (e.g. calendar events create)
    │
    └─ API command? ──────► Direct path + body ──────► HTTP request
        (e.g. api post "/v7/...")
```

Curated commands are not a separate API layer — they resolve to the same HTTP calls. The `api` track exists as an escape hatch for endpoints not yet curated.

## Curated Spec Schema

Each curated command is defined in a YAML spec (`spec/curated/365.yaml`) with this structure:

```yaml
version: 1
commands:
  - id: calendar.events.create        # Unique dot-separated identifier
    command: calendar events create    # CLI invocation path
    summary: 创建日程                   # One-line description
    description: ...                   # Extended help text
    method: POST                       # HTTP method
    path: /v7/calendars/{calendar_id}/events/create
    request_schema_ref: "#/components/schemas/..."   # Optional: OpenAPI request body schema ref
    response_schema_ref: "#/components/schemas/..."   # OpenAPI response schema ref
    args:                              # Positional arguments
    flags:                             # Named flags
    headers:                           # Dynamic headers
    body:                              # Request body mapping
      defaults:                        # Implicit body values
      bindings:                        # Flag → body field mappings
    examples:                          # Usage examples for --help
```

### Key Design Decisions

**1. `id` mirrors `command` with dots**

`calendar.events.create` → `wps365-cli calendar events create`. This makes the spec searchable and the relationship between spec entry and CLI path trivial.

**2. `method` is explicit, not inferred**

Even though most mutations are POST, we record the actual HTTP verb. This prevents ambiguity for edge cases like `user.batch-get` (POST for bulk read).

**3. `path` uses OpenAPI parameter syntax**

Path templates like `{calendar_id}` match the OpenAPI spec. The runtime resolves them from `args` with `to: path.calendar_id`.

## Argument vs Flag Design

### Positional Arguments (`args`)

Use for **resource identifiers** — the primary object the command operates on:

```yaml
args:
  - name: calendar-id
    required: true
    description: 日历 id，可使用 primary 指代主日历
    to: path.calendar_id
```

Design rules:

- Limit to 1–2 positional args (the resource and sometimes a sub-resource).
- IDs are positional; everything else is a flag.
- Use kebab-case for arg names; the CLI auto-translates to the path parameter.

### Named Flags (`flags`)

Use for **all other parameters** — query params, body fields, and metadata:

```yaml
flags:
  - name: page-size
    type: integer
    default: 20
    description: 每页返回的日历数量
    to: query.page_size
  - name: name
    type: string
    description: 日程标题
```

Design rules:

- Use `to:` to explicitly map to the target location (`query.`, `path.`, or body field).
- Provide `default:` for commonly accepted values (page sizes, receiver types).
- Mark `required: true` for flags that have no sensible default.

## Body Mapping System

The body mapping system translates flat CLI flags into nested JSON request bodies.

### Defaults

Implicit body values that don't come from user flags:

```yaml
body:
  defaults:
    type: text
    receivers[0].type: user
    content.text.type: plain
```

These are injected before flag bindings, providing baseline structure.

### Bindings

Flag-to-field mappings with optional transforms:

```yaml
body:
  bindings:
    - from_flag: to
      to: receivers[0].receiver_ids
    - from_flag: text
      to: content.text.content
    - from_flag: reminders
      to: reminders
      transform: "split_csv | to_int | wrap(minutes)"
    - from_flag: recurrence-body
      to: recurrence
      transform: parse_json
```

### Transform Pipeline

Transforms modify flag values before injection:

| Transform | Input | Output | Usage |
|-----------|-------|--------|-------|
| `split_csv` | `"30,10"` | `["30","10"]` | Comma-separated → array |
| `to_int` | `["30","10"]` | `[30,10]` | String → integer |
| `to_bool` | `"true"` | `true` | String → boolean |
| `negate` | `true` | `false` | Boolean flip |
| `wrap(key=value)` | `[30,10]` | `[{"minutes":30},{"minutes":10}]` | Array of objects |
| `parse_json` | `'{"RRULE":"FREQ=WEEKLY"}'` | `{"RRULE":"FREQ=WEEKLY"}` | JSON string → object |

Transforms compose with `|` (pipe), evaluated left to right.

### Design Rules for Body Mapping

1. **Flat flags, nested bodies** — Never require users to pass raw JSON for common fields.
2. **`parse_json` escape hatch** — Complex sub-objects (recurrence rules, online meeting config) accept a JSON string via `parse_json`.
3. **Wrap for array-of-objects** — When the API expects `[{minutes:30}]`, use `split_csv | to_int | wrap(minutes)` so the user just types `--reminders "30,10"`.

## Header Binding

Some APIs require custom headers (e.g., `X-Kso-Id-Type`). Curated commands expose these as flags and bind them:

```yaml
flags:
  - name: id-type
    type: string
    default: internal
    description: 对应请求头 X-Kso-Id-Type
headers:
  - name: X-Kso-Id-Type
    from_flag: id-type
```

## Auth Constraint Validation

Each curated command inherits `security` requirements from the OpenAPI spec. The runtime checks whether the current auth mode (delegated/app) is compatible before sending the request. If not, it errors immediately:

```
Error: this endpoint requires delegated auth; current session is app-only.
Run: wps365-cli auth login --scopes "..."
```

Users can override with `--token-type`, but incompatible overrides still error rather than silently failing.

## Naming Conventions

### Resource Names

| API Concept | CLI Resource | Example |
|-------------|-------------|---------|
| Calendar | `calendar` | `calendar list` |
| Calendar Event | `calendar events` | `calendar events create` |
| Event Attendee | `calendar event-attendee` | `calendar event-attendee add` |
| Meeting Room | `meeting rooms` | `meeting rooms search` |
| Meeting Recording | `meeting recordings` | `meeting recordings start` |

Rules:

- **Plural sub-resources**: `calendar events`, `drive files`, `dbsheet records`.
- **Hyphenated compounds**: `event-attendee`, `free-busy`, `room-level`.
- **Consistent verbs**: `list`, `get`, `create`, `update`, `delete` for CRUD; `add`/`remove` for collection mutations; `search` for full-text; `batch-*` for bulk operations.

### Verb Selection Guide

| Intent | Verb | When to Use |
|--------|------|-------------|
| List collection | `list` | Paginated read of a collection |
| Get single item | `get` | Read by ID |
| Create new item | `create` | POST that creates a resource |
| Modify existing | `update` | Partial/full modification |
| Remove existing | `delete` | Destructive removal |
| Add to collection | `add` | Append members to a group (e.g., attendees to event) |
| Remove from collection | `remove` | Remove members from a group |
| Full-text search | `search` | Query by keyword |
| Bulk create | `batch-create` | Multiple items in one call |
| Bulk read | `batch-get` | Multiple reads by IDs |
| Bulk delete | `batch-delete` | Multiple deletions |
| State transition | Action verb (`end`, `respond`, `recall`) | Non-CRUD operations |

## Curated Command Coverage

Current stats (v0.1.0):

| Domain | Curated Commands | API Paths |
|--------|-----------------|-----------|
| Calendar | 28 | ~35 |
| IM | 20 | ~25 |
| User | 9 | ~10 |
| Mail | 11 | ~12 |
| Drive | 29 | ~40 |
| DbSheet | 22 | ~30 |
| Meeting | 33 | ~45 |
| **Total** | **152** | **~197** |

The remaining ~600 API paths are accessible via `api get|post`. Curation is an ongoing process — high-traffic endpoints are prioritized.

## Comparison with Slock CLI (kscc)

| Dimension | wps365-cli | kscc (Slock) |
|-----------|------------|-------------|
| Spec source | OpenAPI YAML + curated YAML | Internal TypeScript definitions |
| Command count | 152 curated | ~20 commands |
| Auth modes | delegated + app (OAuth2) | agent token (device-code flow) |
| Body mapping | Declarative YAML bindings | Code-based argument parsing |
| Agent integration | `--dry-run` + `-o json` | Native MCP protocol + hook system |
| Extensibility | Custom spec files via `spec add` | Plugin manifest + integration login |

Key insight: kscc's MCP-first design is more agent-native, while wps365-cli's spec-driven approach is more scalable for large API surfaces. A future MCP adapter layer for wps365-cli (see [openapi-cli-mapping.md](openapi-cli-mapping.md)) could bridge this gap.

## Contributing New Curated Commands

To add a new curated command:

1. Identify the target API endpoint in `spec/api/365.yaml`.
2. Add an entry to `spec/curated/365.yaml` following the schema above.
3. Test with `wps365-cli spec set --curated <path-to-your-yaml>`.
4. Verify with `--dry-run` that the request is correct.
5. Submit a PR with both the spec change and example output.

See [openapi-cli-mapping.md](openapi-cli-mapping.md) for the mapping rules between OpenAPI paths and CLI commands.
