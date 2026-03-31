# WPS365 CLI

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Go Version](https://img.shields.io/badge/go-%3E%3D1.25-blue.svg)](https://go.dev/)

[中文](README.md) | English

The official WPS 365 CLI tool — a command-line gateway for developers and AI Agents. Covers 7 business domains including Calendar, Messenger, Contacts, Mail, Drive, DbSheet, and Meetings. Uncovered endpoints are accessible via `api get|post`.

[Install](#installation--quick-start) · [Commands](#dual-track-command-system) · [Auth](#authentication) · [Advanced](#advanced-usage) · [Security](#credentials--security) · [Development](#development) · [Contributing](#contributing)

## Features

| Category | Capabilities |
|----------|-------------|
| 📅 Calendar | List calendars, create/update/delete events, manage attendees & rooms, free/busy queries, time-off events, batch operations |
| 💬 Messenger | Send/reply/recall messages, chat CRUD, member management, message lists, urgent messages, bookmarks |
| 👤 Contacts | Current user, user list, search by name/email/phone, batch queries, department & offboarding management |
| 📧 Mail | Mailbox management, folder browsing, message list/detail/search, send & drafts, mail groups & contacts |
| 📁 Drive | Drive management, file list/upload/download/search, batch operations, permissions, versions, share links |
| 📋 DbSheet | Table/field/view management, record CRUD & search, dashboards, webhooks, attachments |
| 🎥 Meetings | Online meeting management, participant management, reservations, minutes & recordings, room & level management |

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
wps365-cli calendar events create primary \
  --name "Weekly Sync" --from "2024-01-15T14:00:00+08:00" --to "2024-01-15T15:00:00+08:00"
wps365-cli im messages send --to u1 --to u2 --text "hello"
```

Run `wps365-cli <resource> --help` to see all subcommands.

### 2. Raw API Calls

Call any WPS 365 Open Platform endpoint directly, covering all APIs.

```bash
wps365-cli api get "/v7/users/current"
wps365-cli api post "/v7/calendars/create" \
  --data '{"summary": "Project Calendar"}'
```

## Authentication

| Command | Description |
|---------|-------------|
| `auth setup` | Configure OAuth client credentials (interactive, supports CLI flags and env vars) |
| `auth login` | Log in with `--scopes` for user identity, or `--app` for application identity |
| `auth token` | View current token info |
| `auth status` | View authentication status |

### Auth Modes

| Mode | Description | Acquisition |
|------|-------------|-------------|
| `delegated` | User authorization, for user-scoped endpoints (current user, personal tasks, etc.) | `auth login --scopes "..."` |
| `app` | Application identity, for server-to-server or app-only endpoints | `auth login --app` |

Commands automatically select the compatible auth mode based on OpenAPI `security`. Use `--token-type` to override explicitly. Incompatible overrides produce an error rather than silently switching.

```bash
# Delegated login (browser-based OAuth)
wps365-cli auth login --scopes "kso.user_base.read,kso.calendar.read"

# App login (client credentials grant)
wps365-cli auth login --app

# Non-interactive (CI/CD)
export WPS365_CLIENT_ID="<client-id>"
export WPS365_CLIENT_SECRET="<client-secret>"
wps365-cli auth login --app
```

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
wps365-cli --dry-run -o json im messages send --to u1 --text "hello"
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

- **Keychain** (default on macOS): uses system Keychain
- **Encrypted file**: provide a key via `WPS365_KEYRING_PASSWORD`, encrypted with AES-256-GCM

Token lifecycle is fully automatic:

- Access tokens are proactively refreshed 10 seconds before expiry
- 401 responses trigger transparent refresh and retry
- Delegated tokens are refreshed via refresh_token; if the refresh token itself expires, the CLI prompts to `auth login` again
- App tokens are re-acquired via client_credentials when expired


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
