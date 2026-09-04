# WPS365 CLI

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Go Version](https://img.shields.io/badge/go-%3E%3D1.25-blue.svg)](https://go.dev/)

[中文](README.md) | English

The official WPS 365 CLI tool — a command-line gateway for developers and AI Agents. Covers 9 business domains including Calendar, Messenger, Contacts, Mail, Drive, Airpage, Airsheet, DbSheet, and Meetings, with 120 curated commands; uncovered endpoints (e.g. Sheets) are accessible via `api` commands.

[Install](#installation--quick-start) · [Commands](#dual-track-command-system) · [Auth](#authentication) · [Advanced](#advanced-usage) · [Security](#credentials--security) · [Development](#development) · [Contributing](#contributing)

## Why wps365-cli?

- **Wide Coverage** — 9 business domains, 120 curated commands, one tool for the entire WPS 365 platform
- **Dual-Track Architecture** — Curated commands (semantic, user-friendly) + `api get|post|put|patch|delete|head` (full API coverage), choose the right granularity
- **CDN Spec-Driven** — Official command specs are auto-downloaded from CDN on first run, ready to use out of the box; local overrides and custom extensions are supported
- **Secure & Controllable** — OS-native keychain or AES-256-GCM encrypted credential storage, plaintext secrets never touch disk
- **Script-Friendly** — Unified exit codes, structured output, `--dry-run` preview, environment-variable driven — CI/CD ready out of the box
- **Automatic Token Management** — Proactive refresh before expiry, transparent 401 retry — developers never worry about token lifecycle
- **Open Source, Zero Barriers** — MIT license, one-line install and you're ready to go

## Features

| Category | Commands | Capabilities |
|----------|----------|-------------|
| 📅 Calendar | 25 | Calendar CRUD, event CRUD & search, attendee & room management, free/busy queries, recurring instances, meeting minutes, batch primary calendar queries |
| 💬 Messenger | 15 | Send/reply/recall messages, chat CRUD, member management, chat message history, P2P chat queries, unread counts |
| 👤 Contacts | 5 | Current user info, user list & search (name/email/phone), user details, department queries |
| 📧 Mail | 8 | Mailbox list, folder & subfolder browsing, message list/detail/search, draft creation & sending |
| 📁 Drive | 23 | Drive management, document libraries/team docs, file CRUD/search/download/rename, batch copy & move, content extraction, version management, share links, recent/starred/frequent files |
| 📝 Airpage | 9 | Create/get smart documents, v2 block CRUD (`--content` writes plain text), OTL JSON import, export to docx/json |
| 📊 Airsheet | 8 | Create smart sheets, worksheets, range read/write/find, append rows |
| 📋 DbSheet | 14 | Schema queries, table/field management, record CRUD & search, paginated queries |
| 🎥 Meetings | 13 | Meeting list/detail/end, host transfer, participant invite/remove/list, minutes & summaries, recordings & transcripts |

## Installation & Quick Start

### Install

**macOS / Linux**

```bash
curl -fsSL https://open-docs.wpscdn.cn/cli/install.sh | bash
```

**Windows (PowerShell)**

```powershell
irm https://open-docs.wpscdn.cn/cli/install.ps1 | iex
```

**Windows (Git Bash)**

```bash
curl -fsSL https://open-docs.wpscdn.cn/cli/install.sh | bash
```

macOS / Linux install to `~/.local/bin` by default (no sudo). Customize via environment variables:

```bash
# Install a specific version
curl -fsSL https://open-docs.wpscdn.cn/cli/install.sh | WPS365_VERSION=v0.3.5 bash

# Custom install directory
curl -fsSL https://open-docs.wpscdn.cn/cli/install.sh | WPS365_INSTALL_DIR=~/.local/bin bash
```

```powershell
# PowerShell: Install a specific version
$env:WPS365_VERSION="v0.3.5"; irm https://open-docs.wpscdn.cn/cli/install.ps1 | iex

# PowerShell: Custom install directory
$env:WPS365_INSTALL_DIR="C:\tools"; irm https://open-docs.wpscdn.cn/cli/install.ps1 | iex
```

**Manual Download**

Download the binary for your platform from the [Release page](https://github.com/wps365-open/cli/releases).

### Three Steps to Start

```bash
# 1. Create or bind an application (one-time)
wps365-cli config init
# 2. Log in
wps365-cli auth login --device
# 3. Confirm the current user
wps365-cli user me
```

> Enterprise admins should configure a CLI app auto-approval rule first. `config init` opens a browser to create or bind an app. If you already have credentials, use `auth setup`. See [Prerequisites: App Creation & Permission Setup](docs/prerequisites.md) for details.

## Dual-Track Command System

The CLI provides two levels of granularity: curated commands for high-frequency scenarios, and `api` commands as a fallback for full API coverage.

### 1. Curated Commands

Semantic parameters, smart defaults, automatic auth constraint validation — friendly for both humans and scripts.

```bash
wps365-cli user me
wps365-cli calendar event create primary \
  --name "Weekly Sync" --start "2026-09-01T14:00:00+08:00" --end "2026-09-01T15:00:00+08:00"
wps365-cli im message send --to "u1,u2" --text "hello"
```

Run `wps365-cli <resource> --help` to see all subcommands.

### 2. Raw API Calls

Call any WPS 365 Open Platform endpoint directly, covering all APIs.

```bash
wps365-cli api get "/v7/users/current"
wps365-cli api post "/v7/messages/batch_create" \
  --data '{
    "type": "text",
    "receivers": [{"type": "user", "receiver_ids": ["u1"]}],
    "content": {"text": {"type": "plain", "content": "hello"}}
  }'
```

## Authentication

### Common Commands

| Command | Description | Use Case |
|---------|-------------|----------|
| `config init` | One-shot app registration | Recommended first-time setup; browser create/bind writes `client_id`/`client_secret` |
| `auth setup` | Configure OAuth client credentials | Existing credentials / manual management; interactive save of `client_id` and `client_secret` |
| `auth login` | Log in for authorization | `--device` for device-code login (`--scopes` optional); auth-code login requires `--scopes` |
| `auth status` | View authentication status | Check if current token is valid, expiry time, auth mode, etc. |
| `auth token` | Print current access token to stdout | Pass token to other tools or scripts; defaults to delegated token, `--app` prints app token |
| `auth refresh` | Manually refresh token | Proactively refresh an expiring token, specify `--delegated` or `--app` |
| `auth logout` | Delete local delegated token | Sign out of current user authorization; credentials are preserved, re-`login` directly |
| `auth clean` | Clean all authentication data | Use when credentials are corrupted, keys mismatch, or a full reset is needed; clears tokens/secrets and `client_id`/`redirect_uri` from config, then restart from `setup`/`config init`. `--force` skips confirmation |
| `auth qrcode` | Encode a URL as a QR code | `--file qr.png` writes PNG (cwd-relative); `--ascii` prints a terminal QR. Global `-o/--output` is format, not a file path |

```bash
# 1a. One-shot app registration (recommended)
wps365-cli config init

# 1b. Manual credential setup (interactive)
wps365-cli auth setup

# 2. User identity login (device code, recommended)
wps365-cli auth login --device

# 3. Non-interactive (CI/CD / app-only scenarios)
export WPS365_CLIENT_ID="<client-id>"
export WPS365_CLIENT_SECRET="<client-secret>"
wps365-cli im message send --to "<OPEN_ID>" --text "hello"

# 4. Check current authentication status
wps365-cli auth status

# 5. Pass token to other tools (defaults to delegated token, --app for app token)
curl -H "Authorization: Bearer $(wps365-cli auth token)" https://openapi.wps.cn/v7/users/current

# 6. Log out (credentials preserved, re-login directly next time)
wps365-cli auth logout

# 7. Full reset (clear all tokens, credentials, and auto-generated keys)
wps365-cli auth clean --force
```

### Auth Modes

| Mode | Description | Acquisition |
|------|-------------|-------------|
| `delegated` | User authorization, for user-scoped endpoints (current user, etc.) | `auth login --device` or `auth login --scopes "..."` |
| `app` | Application identity, for server-to-server or app-only endpoints | Run the target command directly, add `--token-type app` when needed |

Commands automatically select the compatible auth mode based on OpenAPI `security`. Use `--token-type` to override explicitly. Incompatible overrides produce an error; if a delegated token is unavailable, the CLI falls back to app mode automatically.

## Advanced Usage

### Output Formats

```bash
-o json      # JSON (default)
-o yaml      # YAML
-o table     # Human-readable table
-o tsv       # Tab-separated (for piping)
```

```bash
wps365-cli -o yaml user me
wps365-cli -o table calendar list
```

### Dry Run

Preview requests without sending, useful for debugging and script validation:

```bash
wps365-cli --dry-run user me
wps365-cli --dry-run api get "/v7/users/current"
wps365-cli --dry-run -o json im message send --to "u1" --text "hello"
```

### HTTP Timeout

Business API calls time out after 30s by default. Override with `--timeout`, `WPS365_TIMEOUT`, or `config set timeout`. `0` / `none` / `unlimited` disables the limit.

```bash
wps365-cli --timeout 2m user me
wps365-cli --timeout 0 api get "/v7/users/current"
wps365-cli config set timeout 2m
```

### Spec Management

Official specs are auto-downloaded from CDN on first run — no setup required.

```bash
wps365-cli spec status      # Show current spec status (including source and version)
wps365-cli spec update      # Check and update official spec files
```

### Self-update

```bash
wps365-cli update           # Compare with CDN latest and replace this binary if behind
wps365-cli update --check   # Compare only; do not download
```

After upgrading the binary, run `wps365-cli spec update -y` if new commands are missing.

### Environment Variables

| Variable | Purpose |
|----------|---------|
| `WPS365_CLIENT_ID` | OAuth client ID |
| `WPS365_CLIENT_SECRET` | OAuth client secret |
| `WPS365_AUTH` | Default auth mode (`app` / `delegated`) |
| `WPS365_ACCESS_TOKEN` | Direct access token injection (bypasses store and refresh) |
| `WPS365_API_BASE` | API base URL |
| `WPS365_TIMEOUT` | Business API HTTP timeout (e.g. `60s`, `2m`; `0`/`none` = no limit). Default `30s` |
| `WPS365_AUTH_URL` | Custom OAuth authorization endpoint |
| `WPS365_TOKEN_URL` | Custom OAuth token endpoint |
| `WPS365_REDIRECT_URI` | OAuth redirect URI |
| `WPS365_CONFIG_DIR` | Configuration directory |
| `WPS365_KEYRING_BACKEND` | Credential storage backend (`keychain` / `file`) |
| `WPS365_KEYRING_PASSWORD` | Encryption password for file backend (optional, auto-generated if not set) |
| `WPS365_OUTPUT` | Default output format |
| `WPS365_QUIET` | Suppress informational stderr output |
| `WPS365_CDN_LATEST_URL` | Override latest.txt URL for CLI self-update |
| `WPS365_CDN_URL` | Override release archive CDN prefix (including `/releases/download`) |

## Credentials & Security

`client_secret` and tokens are stored in a secure backend — plaintext never touches disk:

- **Keychain** (default on macOS/Windows): uses system Keychain / Credential Manager
- **Encrypted file** (default on Linux): AES-256-GCM encrypted. When `WPS365_KEYRING_PASSWORD` is not set, a random key is auto-generated and persisted locally — no extra configuration needed

Token lifecycle is fully automatic:

- Access tokens are proactively refreshed 10 seconds before expiry
- 401 responses trigger transparent refresh and retry
- Delegated tokens are refreshed via refresh_token; if the refresh token itself expires, the CLI prompts to `auth login` again
- App tokens are re-acquired via client_credentials when expired

## Development

### Directory Layout

```
cmd/wps365-cli/       CLI entry point
internal/
  cli/                Root command, base commands, and command mounting
  curated/            Curated command catalog and parameter binding
  api/                api get|post|put|patch|delete|head fallback commands
  openapi/            OpenAPI parsing, path matching, and contract validation
  auth/               Authentication, token storage, refresh, and 401 retry
  transport/          HTTP client with automatic token injection and 401 retry
  config/             Configuration loading and environment variable resolution
specs/                Repository-bundled official specs
docs/design-docs/     Design documents
```

### Build & Test

```bash
make build            # Build for current platform
make build-all        # Build for all platforms (macOS/Linux/Windows)
make install          # Install to $GOPATH/bin
make test             # Unit tests
make test-e2e         # Black-box E2E tests
make quality-report   # Run quality checks report
make help             # Show all Make targets
```

### Related Documentation

- [ARCHITECTURE.md](ARCHITECTURE.md) — Project architecture and directory responsibilities
- [docs/design-docs/auth.md](docs/design-docs/auth.md) — Authentication and credential design
- [docs/design-docs/spec-discovery.md](docs/design-docs/spec-discovery.md) — Spec file management and loading order
- [docs/design-docs/curated-commands.md](docs/design-docs/curated-commands.md) — Curated command design principles
- [docs/design-docs/openapi-cli-mapping.md](docs/design-docs/openapi-cli-mapping.md) — Command-to-API mapping rules
- [docs/design-docs/testing.md](docs/design-docs/testing.md) — Testing strategy and E2E constraints

## Contributing

Community contributions are welcome! If you find a bug or have feature suggestions, please submit an Issue or Pull Request.

For major changes, we recommend discussing with us first via an Issue.

## License

This project is licensed under the [MIT License](LICENSE).
