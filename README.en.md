# WPS365 CLI

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Go Version](https://img.shields.io/badge/go-%3E%3D1.25-blue.svg)](https://go.dev/)

[中文](README.md) | English

The official WPS 365 CLI tool — a command-line gateway for developers and AI Agents. Covers 7 business domains including Calendar, Messenger, Contacts, Mail, Drive, DbSheet, and Meetings. Uncovered endpoints are accessible via `api get|post`.

[Install](#installation--quick-start) · [Commands](#dual-track-command-system) · [Auth](#authentication) · [Advanced](#advanced-usage) · [Security](#credentials--security) · [Development](#development) · [Contributing](#contributing)

## Features

The current release (v0.2.0) provides **101 curated commands** across 7 business domains:

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
curl -fsSL https://raw.githubusercontent.com/wps365-open/cli/main/install.sh | WPS365_VERSION=v0.0.2 bash

# Custom install directory
curl -fsSL https://raw.githubusercontent.com/wps365-open/cli/main/install.sh | WPS365_INSTALL_DIR=~/.local/bin bash
```

```powershell
# PowerShell: install a specific version
$env:WPS365_VERSION="v0.0.2"; irm https://raw.githubusercontent.com/wps365-open/cli/main/install.ps1 | iex

# PowerShell: custom install directory
$env:WPS365_INSTALL_DIR="C:\tools"; irm https://raw.githubusercontent.com/wps365-open/cli/main/install.ps1 | iex
```

**Manual download**

[Release Page](https://github.com/wps365-open/cli/releases) 

### Three Steps to Start

> Before first use, you need to create an app and configure permissions on the WPS 365 Open Platform. See [Prerequisites: App Creation & Permission Setup](docs/prerequisites.md) for details.

```bash
# 1. Configure OAuth client credentials (one-time, interactive guided setup)
wps365-cli auth setup

# 2. Log in
wps365-cli auth login --scopes "kso.user_base.read,kso.calendar.read"

# 3. Start using
wps365-cli user me
```

## Dual-Track Command System

The CLI provides two levels of granularity: curated commands for high-frequency scenarios, and `api` commands as a fallback for full API coverage.

### 1. Curated Commands

Semantic parameters, smart defaults, automatic auth constraint validation — friendly for both humans and scripts.

```bash
wps365-cli user me
wps365-cli calendar event create primary \
  --name "Weekly Sync" --from "2024-01-15T14:00:00+08:00" --to "2024-01-15T15:00:00+08:00"
wps365-cli im message send --to u1 --to u2 --text "hello"
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

| Command | Description | Use Case |
|---------|-------------|----------|
| `auth setup` | Configure OAuth client credentials | First-time setup, interactive guided |
| `auth login` | Log in with `--scopes` | Browser-based OAuth user authorization |
| `auth status` | View authentication status | Check token validity and expiry |
| `auth token` | Output current access token | Pass to external tools: `curl -H "Authorization: Bearer $(wps365-cli auth token)"` |
| `auth logout` | Remove local tokens | Sign out; credentials retained for re-login |
| `auth clean` | Clear all auth data | Full reset; requires `auth setup` again |

### Auth Modes

| Mode | Description | Acquisition |
|------|-------------|-------------|
| `delegated` | User authorization, for user-scoped endpoints (current user, personal tasks, etc.) | `auth login --scopes "..."` |
| `app` | Application identity, for server-to-server or app-only endpoints | Set `WPS365_CLIENT_ID` + `WPS365_CLIENT_SECRET` env vars; CLI auto-acquires token |

Commands automatically select the compatible auth mode based on OpenAPI `security`. Use `--token-type` to override explicitly. Incompatible overrides produce an error rather than silently switching.

```bash
# Delegated login (browser-based OAuth)
wps365-cli auth login --scopes "kso.user_base.read,kso.calendar.read"

# App identity (CI/CD — no login needed, uses env vars)
export WPS365_CLIENT_ID="<client-id>"
export WPS365_CLIENT_SECRET="<client-secret>"
wps365-cli user list   # auto-acquires app token via client_credentials
```

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


### Environment Variables

| Variable | Purpose |
|----------|---------|
| `WPS365_CLIENT_ID` | OAuth client ID |
| `WPS365_CLIENT_SECRET` | OAuth client secret |
| `WPS365_AUTH` | Default auth mode (`app` / `delegated`) |
| `WPS365_ACCESS_TOKEN` | Direct access token injection (bypasses store and refresh) |
| `WPS365_API_BASE` | API base URL |
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

## Contributing

Community contributions are welcome! If you find a bug or have feature suggestions, please submit an Issue or Pull Request.

For major changes, we recommend discussing with us first via an Issue.

## License

This project is licensed under the [MIT License](LICENSE).
