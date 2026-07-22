# WPS365 CLI

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Go Version](https://img.shields.io/badge/go-%3E%3D1.23-blue.svg)](https://go.dev/)

[中文](README.md) | English

The official WPS 365 CLI — a command-line gateway for developers and AI Agents. Covers Calendar, Messenger, Contacts, Mail, Drive, DbSheet, and Meetings; supports curated commands and raw `api` calls.

[Install](#installation--quick-start) · [Prerequisites](#prerequisites) · [Commands](#dual-track-command-system) · [Auth](#authentication) · [Advanced](#advanced-usage) · [Security](#credentials--security) · [FAQ](#faq) · [Development](#development) · [Contributing](#contributing)

## Why wps365-cli?

- **Wide coverage** — Seven business domains in one tool for the WPS 365 platform
- **Dual-track architecture** — Curated commands (semantic, friendly) + `api get|post|put|patch|delete|head` (full API coverage)
- **Fast onboarding** — `config init` creates/binds an app in the browser; no manual console setup required for public cloud
- **Headless-friendly** — `auth login --device` for remote/WSL/CI environments without a local callback
- **Secure** — OS keychain or AES-256-GCM encrypted storage; plaintext secrets never touch disk
- **Script-friendly** — Unified exit codes, structured output, `--dry-run`, environment variables
- **Automatic token management** — Proactive refresh and transparent 401 retry
- **Open source** — MIT license, one-line install

## Features

| Category | Capabilities |
|----------|-------------|
| 📅 Calendar | List calendars, create/update/delete events, attendees & rooms, free/busy, leave events, batch ops |
| 💬 Messenger | Send/reply/recall messages, chat CRUD, members, message history, urgent, bookmarks |
| 👤 Contacts | Current user, user list, search by name/email/phone, batch get, departments & resigned users |
| 📧 Mail | Mailboxes, folders, message list/detail/search, send & drafts, groups & contacts |
| 📁 Drive | Drives, file list/upload/download/search, batch ops, permissions, versions, share links |
| 📋 DbSheet | Tables/fields/views, record CRUD & search, dashboards, webhooks, attachments |
| 🎥 Meetings | Online meetings, participants, reservations, minutes & recordings, rooms & hierarchy |

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
curl -fsSL https://raw.githubusercontent.com/wps365-open/cli/main/install.sh | WPS365_VERSION=v0.3.0 bash

# Custom install directory
curl -fsSL https://raw.githubusercontent.com/wps365-open/cli/main/install.sh | WPS365_INSTALL_DIR=~/.local/bin bash
```

```powershell
$env:WPS365_VERSION="v0.3.0"; irm https://raw.githubusercontent.com/wps365-open/cli/main/install.ps1 | iex
$env:WPS365_INSTALL_DIR="C:\tools"; irm https://raw.githubusercontent.com/wps365-open/cli/main/install.ps1 | iex
```

**Manual download**

Download binaries from the [Release page](https://github.com/wps365-open/cli/releases).

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

Cannot use `config init`? See [Path B: manual setup](#path-b-manual-open-platform-setup-advanced).

## Prerequisites

Details for `config init`, troubleshooting, and the manual fallback path.

### Path A: `config init` (recommended)

Public-cloud users do **not** need to create an app in the console first.

```bash
wps365-cli config init
```

Flow:

1. CLI starts open-platform app registration and prints a browser URL (and tries to open it)
2. In the browser: verify identity → create/bind app → confirm authorization (existing apps jump to bind first)
3. After polling succeeds, CLI writes `client_id` to local config and `client_secret` to secure storage

| Flag | Description |
|------|-------------|
| `--new` | Prefer creating a new app in the browser |
| `--force` | Skip confirmation when a binding already exists (required non-interactively) |
| `--debug` | Verbose registration logs |

```bash
wps365-cli config init --new
wps365-cli config init --force
wps365-cli config init --debug
```

Then run `auth login`.

### Path B: Manual Open Platform setup (advanced)

For existing enterprise apps, strict approval workflows, or environments where `config init` is unavailable.

Flow: create app → copy credentials → add redirect URI → request scopes & submit release → admin approval → write credentials into CLI.

1. Open the [WPS 365 Open Platform console](https://open.wps.cn/), create an enterprise app  
2. Copy **App ID** (`client_id`) and **App Secret** (`client_secret`)  
3. Under **Security**, add redirect URI: `http://localhost:18365/callback`  
4. Request API scopes, create a version, and submit for release  
5. Have an enterprise admin approve the app in the admin console  
6. Save credentials:

```bash
wps365-cli auth setup
```

Then run `auth login`. Screenshot-level steps: [Prerequisites](docs/prerequisites.md).

## Dual-Track Command System

CLI offers two call granularities: curated commands for common workflows, and `api` as a full-API fallback.

### 1. Curated Commands

Semantic flags, sensible defaults, and auth-constraint checks — friendly for humans and scripts.

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

| Command | Description | Use case |
|---------|-------------|----------|
| `config init` | One-shot app registration | Browser create/bind; writes credentials automatically |
| `auth setup` | Configure OAuth client credentials | Existing AK/SK; interactive or env injection |
| `auth login` | Authorize | `--scopes` for user auth; `--device` for device flow; `--app` for app identity |
| `auth status` | Show auth status | Token validity, expiry, mode |
| `auth token` | Print access token | Pipe to other tools; `--app` for app token |
| `auth refresh` | Refresh token | Proactive refresh |
| `auth logout` | Delete local delegated token | Keep credentials |
| `auth clean` | Wipe all auth data | Corrupted store or full reset; `--force` skips confirm |

```bash
wps365-cli config init
wps365-cli auth login --device

wps365-cli auth login --scopes "kso.user_base.read,kso.calendar.read"

export WPS365_CLIENT_ID="<client-id>"
export WPS365_CLIENT_SECRET="<client-secret>"
wps365-cli im message send --to "<OPEN_ID>" --text "hello" --token-type app

wps365-cli auth status
wps365-cli auth logout
wps365-cli auth clean --force
```

### Auth Modes

| Mode | Description | How to obtain |
|------|-------------|---------------|
| `delegated` | User identity | `auth login` / `auth login --device` |
| `app` | Application identity | `auth login --app`, or `--token-type app` on a command |

Mode is chosen from OpenAPI `security`; `--token-type` overrides. If delegated is unavailable and the API also allows app, the CLI falls back with a warning.

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

### Spec Management

Official specs are auto-downloaded from CDN on first run — no setup required.

```bash
wps365-cli spec status      # Show current spec status (including source and version)
wps365-cli spec update      # Check and update official spec files
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
| `WPS365_KEYRING_PASSWORD` | Encryption password for file backend (optional, auto-generated if not set) |
| `WPS365_OUTPUT` | Default output format |
| `WPS365_QUIET` | Suppress informational stderr output |

## Credentials & Security

`client_secret` and tokens are stored in a secure backend — plaintext never touches disk:

- **Keychain** (default on macOS/Windows): uses system Keychain / Credential Manager
- **Encrypted file** (default on Linux): AES-256-GCM encrypted. When `WPS365_KEYRING_PASSWORD` is not set, a random key is auto-generated and persisted locally — no extra configuration needed

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

**Q: Scopes requested but not effective?**  
Complete create version → submit release → enterprise admin approval. Requesting scopes alone leaves them pending review.

**Q: Contacts APIs return empty or permission errors?**  
Besides capability scopes, configure availability range and data permissions in the app console.

**Q: `CLIENT_SECRET` leaked?**  
Reset the secret in the developer console (old secret is invalidated immediately), then run `config init` or `auth setup` again.

**Q: Linux/WSL keyring or `auth setup` issues?**  
Use `WPS365_KEYRING_BACKEND=file` (and `WPS365_KEYRING_PASSWORD` if needed). `auth setup` still overwrites credentials when the previous secret cannot be read.

## Development

### Directory Layout

```
cmd/wps365-cli/       CLI entry point
internal/
  cli/                Root & base commands
  curated/            Curated catalog
  api/                Raw API fallback
  openapi/            OpenAPI parsing
  auth/               Auth & token store
  transport/          HTTP client
  config/             Config & env
specs/                Bundled specs
docs/design-docs/     Design docs
```

### Build & Test

```bash
make build
make build-all
make install
make test
make test-e2e
make quality-report
make help
```

### Related Documentation

- [ARCHITECTURE.md](ARCHITECTURE.md)
- [docs/design-docs/auth.md](docs/design-docs/auth.md)
- [docs/prerequisites.md](docs/prerequisites.md)
- [docs/design-docs/spec-discovery.md](docs/design-docs/spec-discovery.md)
- [docs/design-docs/curated-commands.md](docs/design-docs/curated-commands.md)
- [docs/design-docs/testing.md](docs/design-docs/testing.md)

## Resources

- [GitHub repository](https://github.com/wps365-open/cli)
- [Releases](https://github.com/wps365-open/cli/releases)

## Contributing

Issues and PRs are welcome. For large changes, open an Issue first.

## License

[MIT License](LICENSE).
