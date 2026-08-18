# WPS365 CLI Architecture

## Overview

WPS365 CLI is a Go-based command-line tool that provides structured access to the WPS 365 Open Platform APIs. It follows a **spec-driven architecture** — the OpenAPI specification files define the API surface, and curated YAML files define the human-friendly command mapping. The Go binary reads these specs at runtime to build its command tree, perform request validation, and manage authentication.

```
┌─────────────────────────────────────────────────────────┐
│                      User / Script                       │
└──────────────────────┬──────────────────────────────────┘
                       │
          ┌────────────┴────────────┐
          │     CLI Flag Parsing     │  cobra + pflag
          │  (cobra command tree)    │
          └────────────┬────────────┘
                       │
       ┌───────────────┴───────────────┐
       │          Command Router        │
       │  ┌──────────┐  ┌──────────┐   │
       │  │ Curated   │  │ Raw API  │   │
       │  │ Commands  │  │ (api get │   │
       │  │           │  │  /path)  │   │
       │  └─────┬─────┘  └────┬─────┘   │
       └─────────┼────────────┼─────────┘
                 │            │
          ┌──────┴────────────┴──────┐
          │     Request Builder       │
          │  - Resolve path params    │
          │  - Bind flags → body/que  │
          │  - Apply transforms       │
          │  - Validate via schema    │
          └──────────┬───────────────┘
                     │
          ┌──────────┴───────────────┐
          │    Auth Middleware        │
          │  - Select token type     │
          │  - Auto-refresh (10s)    │
          │  - 401 → retry once      │
          └──────────┬───────────────┘
                     │
          ┌──────────┴───────────────┐
          │    HTTP Client           │
          │  - Send request          │
          │  - Dry-run support       │
          └──────────┬───────────────┘
                     │
          ┌──────────┴───────────────┐
          │    Output Formatter       │
          │  json | yaml | table | tsv│
          └──────────────────────────┘
```

## Directory Layout

Since the Go source code is not published in this repository, the layout shown here reflects the **runtime data directory** and the **published repo contents**.

### Repository (this repo)

```
.
├── README.md              # Chinese documentation
├── README.en.md           # English documentation
├── install.sh             # macOS/Linux installer
├── install.ps1            # Windows PowerShell installer
└── docs/
    ├── prerequisites.md   # OAuth app setup guide
    └── assets/            # Screenshot images for docs
```

### Runtime data directory

macOS: `~/Library/Application Support/wps365-cli/`
Linux: `~/.local/share/wps365-cli/` (or `$XDG_DATA_HOME/wps365-cli/`)
Windows: `%APPDATA%\wps365-cli\`

```
wps365-cli/
├── spec/
│   ├── api/
│   │   ├── 365.yaml           # Official OpenAPI 3.0 spec (~74k lines, 801 endpoints)
│   │   └── customs/          # User-provided custom API specs
│   └── curated/
│       ├── 365.yaml           # Curated command definitions (152 commands)
│       └── customs/           # User-provided custom curated specs
└── config.json               # Non-secret configuration (client_id, redirect_uri, etc.)
```

**Credential storage** (never in the data directory):
- **macOS**: Keychain (via `keyring` Go package)
- **Windows**: Credential Manager
- **Linux**: Encrypted file (`AES-256-GCM`), key auto-generated and stored separately

## Dual-Track Command System

### Track 1: Curated Commands

Curated commands map complex API interactions to semantic CLI verbs. They are defined in `curated/365.yaml`.

Example definition:

```yaml
- id: calendar.events.create
  command: calendar events create
  summary: 创建日程
  method: POST
  path: /v7/calendars/{calendar_id}/events/create
  args:
    - name: calendar-id
      required: true
      to: path.calendar_id
  flags:
    - name: from
      type: string
      required: true
      to: body.start_time
    - name: name
      type: string
      to: body.summary
  body:
    bindings:
      - from_flag: from
        to: start_time
        transform: passthrough
```

Key design principles:
- **Semantic naming**: `calendar events create` over `api post /v7/calendars/{id}/events/create`
- **Smart defaults**: Pagination defaults, required-scope auto-validation
- **Type transforms**: `split_csv`, `to_bool`, `to_int` convert CLI strings to API types
- **Auth constraint checking**: Each command declares its security requirement; incompatible token types produce errors

### Track 2: Raw API Commands

`api get|post|put|patch|delete|head <path>` accesses any endpoint in the OpenAPI spec directly.

```bash
wps365-cli api get "/v7/users/current"
wps365-cli api post "/v7/calendars/create" --data '{"summary": "New Calendar"}'
```

This ensures **100% API coverage** even before a curated command exists.

## Spec Discovery & Loading

1. On startup, the CLI reads the spec directory path (default or `WPS365_CONFIG_DIR`)
2. It loads `api/365.yaml` to build the full API map
3. It loads `curated/365.yaml` to register curated commands
4. Custom specs in `customs/` are merged, allowing users to extend both raw API and curated commands
5. `spec update` fetches the latest official specs from the remote repository
6. `spec add --custom-api` / `--custom-curated` installs user-provided spec files

## Authentication Architecture

```
┌────────────────────────────────────────────────┐
│              Auth Provider                      │
│                                                │
│  ┌──────────────┐  ┌──────────────┐            │
│  │  Delegated    │  │  App          │            │
│  │  (User OAuth) │  │  (Client      │            │
│  │               │  │   Credentials)│            │
│  └──────┬───────┘  └──────┬───────┘            │
│         │                  │                    │
│  ┌──────┴──────────────────┴───────┐           │
│  │         Token Store              │           │
│  │  Keychain / Credential Manager   │           │
│  │  / Encrypted File                │           │
│  └──────────────────────────────────┘           │
│                                                │
│  Auto-refresh:                                  │
│  - 10s before expiry → proactive refresh       │
│  - 401 response → transparent retry            │
│  - Delegated: use refresh_token                 │
│  - App: re-acquire via client_credentials      │
└────────────────────────────────────────────────┘
```

Three auth modes:
1. **Delegated**: User authorizes via browser OAuth, token includes `refresh_token`
2. **App**: Client credentials grant, no user context, `client_id` + `client_secret`
3. **OSH**: Enterprise gateway credentials for internal environments

The CLI reads the OpenAPI `security` field for each endpoint to determine which token type is required. If the current token is incompatible, it errors rather than silently switching.

## Output Pipeline

All commands route through a shared output pipeline:

1. API response (JSON) → 
2. JMESPath/jsonpath filtering (if `--query` supported) → 
3. Format transformer: `json` (default), `yaml`, `table`, `tsv`

## Global Flags

| Flag | Purpose |
|------|---------|
| `--api-base` | Override API base URL |
| `--dry-run` | Print request without sending |
| `-o, --output` | Output format: json/yaml/table/tsv |
| `--quiet` | Suppress stderr informational output |

## Environment Variables

See [README.md](README.md) for the full list. Key categories:
- **Credentials**: `WPS365_CLIENT_ID`, `WPS365_CLIENT_SECRET`, `WPS365_ACCESS_TOKEN`
- **Endpoints**: `WPS365_API_BASE`, `WPS365_AUTH_URL`, `WPS365_TOKEN_URL`
- **Config**: `WPS365_CONFIG_DIR`, `WPS365_AUTH` (default mode), `WPS365_OUTPUT`
- **Security**: `WPS365_KEYRING_BACKEND`, `WPS365_KEYRING_PASSWORD`

## Extension Points

### Custom Spec Files

Users can extend the CLI without code changes:

```bash
# Add a custom API endpoint definition
wps365-cli spec add --custom-api ./my-api.yaml

# Add a custom curated command
wps365-cli spec add --custom-curated ./my-commands.yaml
```

This is the primary extension mechanism for organizations with private or internal APIs that follow the WPS 365 Open Platform conventions.

### CI/CD Integration

Non-interactive auth via environment variables:

```bash
export WPS365_CLIENT_ID="<client-id>"
export WPS365_CLIENT_SECRET="<client-secret>"
wps365-cli auth login --app
```

Combined with `--dry-run` for safe scripting and `-o tsv` for piping to other tools.
