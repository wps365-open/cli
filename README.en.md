# WPS365 CLI

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Go Version](https://img.shields.io/badge/go-%3E%3D1.25-blue.svg)](https://go.dev/)

[中文](README.md) | English

The official WPS 365 CLI tool — a command-line gateway for developers and AI Agents. Covers 7 business domains including Calendar, Messenger, Contacts, Mail, Drive, DbSheet, and Meetings. Uncovered endpoints are accessible via `api get|post`.

For more complete installation, authentication, and command usage details, see the [WPS 365 CLI User Guide](https://365.kdocs.cn/wiki/l/0lcqi8RexYzQKD) (Chinese).

[Install](#installation--quick-start) · [Prerequisites](#prerequisites) · [Commands](#dual-track-command-system) · [Auth](#authentication) · [Advanced](#advanced-usage) · [Security](#credentials--security) · [FAQ](#faq) · [User Guide](https://365.kdocs.cn/wiki/l/0lcqi8RexYzQKD) · [Contributing](#contributing)

## Features

The current release provides **101 curated commands** across 7 business domains:

| Category | Commands | Capabilities |
|----------|:--------:|-------------|
| 📅 Calendar | 25 | Calendar CRUD & subscription, event CRUD & search, attendees, rooms, free/busy, minutes |
| 💬 Messenger | 15 | Send/reply/recall messages, chat CRUD, member management, message history, P2P chat, unread count |
| 👤 Contacts | 5 | Current user, user list & search, department list |
| 📧 Mail | 8 | Mailbox management, folder browsing, message list/detail/search, drafts |
| 📁 Drive | 21 | Drive management, file CRUD & search, batch copy/move, versions, share links |
| 📋 DbSheet | 14 | Table/field management, record CRUD & search |
| 🎥 Meetings | 13 | Meeting management, participants, minutes & recordings |

> Uncovered endpoints are accessible via `api get|post` for full API coverage.

## Installation & Quick Start

### Install

**macOS / Linux**

```bash
curl -fsSL https://raw.githubusercontent.com/wps365-open/cli/main/install.sh | bash
```

**Windows (PowerShell)**

```powershell
irm https://raw.githubusercontent.com/wps365-open/cli/main/install.ps1 | iex
```

**Windows (Git Bash)**

```bash
curl -fsSL https://raw.githubusercontent.com/wps365-open/cli/main/install.sh | bash
```

Customize via environment variables:

```bash
# Install a specific version
curl -fsSL https://raw.githubusercontent.com/wps365-open/cli/main/install.sh | WPS365_VERSION=v0.3.1 bash

# Custom install directory
curl -fsSL https://raw.githubusercontent.com/wps365-open/cli/main/install.sh | WPS365_INSTALL_DIR=~/.local/bin bash
```

```powershell
# PowerShell: install a specific version
$env:WPS365_VERSION="v0.3.1"; irm https://raw.githubusercontent.com/wps365-open/cli/main/install.ps1 | iex

# PowerShell: custom install directory
$env:WPS365_INSTALL_DIR="C:\tools"; irm https://raw.githubusercontent.com/wps365-open/cli/main/install.ps1 | iex
```

**Manual download**

[Release Page](https://github.com/wps365-open/cli/releases)

### Three Steps to Start

```bash
# 0. Install (see above)

# 1. Create / bind an app (recommended, once)
wps365-cli config init

# 2. Log in (use --device for remote / WSL)
wps365-cli auth login --device

# 3. Start using
wps365-cli user me
```

Cannot use `config init`? See [Path B: manual app setup](#path-b-manual-open-platform-setup-advanced) below.

## Prerequisites

This section covers `config init` parameters, troubleshooting, and the fallback when one-shot registration is unavailable.

### Path A: `config init` (recommended)

Public-cloud users do not need to create an app manually in the Open Platform console first.

```bash
wps365-cli config init
```

Flow:

1. CLI starts Open Platform app registration and prints a browser URL (and tries to open it)
2. In the browser: verify identity → create/bind app → authorize (existing apps prefer the bind page)
3. After polling succeeds, CLI writes `client_id` to local config and `client_secret` to the secure store

Common flags:

| Flag | Description |
|------|-------------|
| `--new` | Prefer creating a new app in the browser |
| `--force` | Overwrite an existing binding without confirmation (required in non-interactive envs) |
| `--debug` | Verbose registration step logs |

```bash
wps365-cli config init --new
wps365-cli config init --force
wps365-cli config init --debug
```

Then run `auth login`.

### Path B: Manual Open Platform setup (advanced)

For existing enterprise apps, stricter approval workflows, or environments where `config init` is unavailable.

Overall flow: create app → get credentials → add callback → request scopes & submit release → admin approval → write into CLI.

1. Open the [WPS 365 Open Platform developer console](https://open.wps.cn/) and create an enterprise app  
2. Under **Basic info → App credentials**, copy App ID (`client_id`) and App Secret (`client_secret`)  
3. Under **Development → Security**, add callback: `http://localhost:18365/callback`  
4. Request scopes under **Permissions**, then create a version and submit release under **Version management**  
5. An enterprise admin approves the app in the admin console  
6. Write credentials into the CLI:

```bash
wps365-cli auth setup
```

Then run `auth login`. Screenshot-level steps: [Prerequisites](docs/prerequisites.md).

## Dual-Track Command System

The CLI provides two levels of granularity: curated commands for high-frequency scenarios, and `api` commands as a fallback for full API coverage.

### 1. Curated Commands

Semantic parameters, smart defaults, automatic auth constraint validation — friendly for both humans and scripts.

```bash
wps365-cli user me
wps365-cli calendar event create primary \
  --name "Weekly Sync" \
  --start "2026-07-21T14:00:00+08:00" \
  --end "2026-07-21T15:00:00+08:00"
wps365-cli im message send --to "u1,u2" --text "hello"
```

Run `wps365-cli <resource> --help` to see all subcommands.

### 2. Raw API Calls

Uncovered endpoints are accessible via `api get|post` to call any WPS 365 Open Platform endpoint directly:

```bash
wps365-cli api get "/v7/users/current"
wps365-cli api post "/v7/calendars/create" \
  --data '{"summary": "Project Calendar"}'
```

## Authentication

### Common Commands

| Command | Description | Use Case |
|---------|-------------|----------|
| `config init` | One-shot app registration | Browser create/bind; writes credentials automatically |
| `auth setup` | Configure OAuth client credentials | First-time setup, interactive guided |
| `auth login` | Log in with `--scopes` | Browser OAuth; use `--device` for remote / WSL |
| `auth status` | View authentication status | Check token validity and expiry |
| `auth token` | Output current access token | Pass to external tools: `curl -H "Authorization: Bearer $(wps365-cli auth token)"` |
| `auth logout` | Remove local tokens | Sign out; credentials retained for re-login |
| `auth clean` | Clear all auth data | Full reset; requires `auth setup` / `config init` again |

```bash
# Recommended: one-shot registration + device login
wps365-cli config init
wps365-cli auth login --device

# Or browser callback login with explicit scopes
wps365-cli auth login --scopes "kso.user_base.read,kso.calendar.read"

# App identity (CI/CD — no login needed, uses env vars)
export WPS365_CLIENT_ID="<client-id>"
export WPS365_CLIENT_SECRET="<client-secret>"
wps365-cli user list   # auto-acquires app token via client_credentials

# Check current authentication status
wps365-cli auth status

# Pass token to other tools
curl -H "Authorization: Bearer $(wps365-cli auth token)" https://open.wps.cn/v7/users/current

# Log out (credentials preserved)
wps365-cli auth logout

# Full reset
wps365-cli auth clean --force
```

### Auth Modes

| Mode | Description | Acquisition |
|------|-------------|-------------|
| `delegated` | User authorization, for user-scoped endpoints (current user, personal tasks, etc.) | `auth login --scopes "..."` / `auth login --device` |
| `app` | Application identity, for server-to-server or app-only endpoints | Set `WPS365_CLIENT_ID` + `WPS365_CLIENT_SECRET` env vars; CLI auto-acquires token |

Commands automatically select the compatible auth mode based on OpenAPI `security`. Use `--token-type` to override explicitly. Incompatible overrides produce an error rather than silently switching.

## Advanced Usage

### Output Formats

```bash
-o json      # JSON (default)
-o yaml      # YAML
-o table     # Human-readable table
-o tsv       # Tab-separated (for piping)
-o ndjson    # Newline-delimited JSON (for streaming)
-o csv       # CSV format
```

```bash
wps365-cli -o yaml user me
wps365-cli -o table calendar list
wps365-cli -o csv dbsheet record list --file-id <id> --sheet-id <id>
```

### Output Pipeline

```bash
# Built-in jq filter (no external jq required)
wps365-cli user me --jq '.name'

# Flatten nested objects for columnar outputs
wps365-cli -o table drive file list --flatten

# Disable colorized output (for logs or CI)
wps365-cli --no-color user list
```

### Dry Run

Preview requests without sending, useful for debugging and script validation:

```bash
wps365-cli --dry-run user me
wps365-cli --dry-run api get "/v7/users/current"
wps365-cli --dry-run -o json im message send --to u1 --text "hello"
```

### HTTP Timeout

Business API calls time out after 30s by default. Override with `--timeout`, `WPS365_TIMEOUT`, or `config set timeout`. `0` / `none` / `unlimited` disables the limit.

```bash
wps365-cli --timeout 2m user me
wps365-cli --timeout 0 api get "/v7/users/current"
wps365-cli config set timeout 2m
```

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
| `WPS365_KEYRING_PASSWORD` | Encryption password for file backend |
| `WPS365_OUTPUT` | Default output format |
| `WPS365_QUIET` | Suppress informational stderr output |

## Credentials & Security

`client_secret` and tokens are stored in a secure backend — plaintext never touches disk:

- **Keychain** (macOS/Windows default): uses system Keychain / Credential Manager
- **Encrypted file** (Linux default): AES-256-GCM encrypted. Auto-generates a random key when `WPS365_KEYRING_PASSWORD` is not set

Token lifecycle is fully automatic:

- Access tokens are proactively refreshed 10 seconds before expiry
- 401 responses trigger transparent refresh and retry
- Delegated tokens are refreshed via refresh_token; if the refresh token itself expires, the CLI prompts to `auth login` again
- App tokens are re-acquired via client_credentials when expired

## FAQ

**Q: `config init` keeps showing Waiting for binding?**  
Finish every browser step, especially the final authorization confirmation. Create/bind without authorize leaves the CLI pending until the session expires.

**Q: `config init` vs `auth setup`?**

| | `config init` | `auth setup` |
|--|---------------|--------------|
| When | First use / quick start | Existing credentials |
| How | Browser flow; auto AK/SK | Interactive or env |
| Storage | Same (`config.json` + secure store) | Same |

**Q: Permissions applied but not effective?**  
You still need create version → submit release → admin approval. Requesting scopes alone leaves them pending review.

**Q: Contacts APIs return empty data or permission errors?**  
Besides capability scopes, some APIs also need availability range and data-permission settings in the app console.

**Q: `CLIENT_SECRET` leaked?**  
Reset the secret in the developer console (old secret is invalidated immediately), then run `config init` or `auth setup` again.

## Contributing

Community contributions are welcome! If you find a bug or have feature suggestions, please submit an Issue or Pull Request.

For major changes, we recommend discussing with us first via an Issue.

## License

This project is licensed under the [MIT License](LICENSE).
