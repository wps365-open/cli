#!/usr/bin/env bash
# WPS 365 CLI installer
# Usage: curl -fsSL https://open-docs.wpscdn.cn/cli/install.sh | bash
#   or:  curl -fsSL https://open-docs.wpscdn.cn/cli/install.sh | bash -s -- --version v0.3.2
#
# Inspired by Homebrew, rustup, Starship install scripts.

set -euo pipefail

BIN_NAME="wps365-cli"
GITHUB_REPO="wps365-open/cli"
GO_MODULE_PATH="wps365-cli"

CDN_BASE_URL="${WPS365_CDN_URL:-https://open-docs.wpscdn.cn/cli/releases/download}"
CDN_LATEST_URL="${WPS365_CDN_LATEST_URL:-https://open-docs.wpscdn.cn/cli/latest.txt}"
GITHUB_BASE_URL="https://github.com/${GITHUB_REPO}/releases/download"
GITHUB_API_URL="https://api.github.com/repos/${GITHUB_REPO}/releases/latest"

VERSION="latest"
# Default to ~/.local/bin (no sudo). Override with WPS365_INSTALL_DIR or --install-dir.
INSTALL_DIR="${WPS365_INSTALL_DIR:-${HOME}/.local/bin}"
MODIFY_PATH=true
FORCE=false
INSECURE=false
TMP_DIR=""

# ------------------------------------------------------------------
# Logging
# ------------------------------------------------------------------
info()  { printf "\033[1;34m==>\033[0m %s\n" "$*"; }
warn()  { printf "\033[1;33mWarning:\033[0m %s\n" "$*" >&2; }
error() { printf "\033[1;31mError:\033[0m %s\n" "$*" >&2; }
abort() { error "$@"; exit 1; }

# ------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------
has_cmd() { command -v "$1" >/dev/null 2>&1; }

need_cmd() {
    if ! has_cmd "$1"; then
        abort "Required command '$1' not found. Please install it and retry."
    fi
}

# Portable download: prefers curl, falls back to wget
do_download() {
    local url="$1" dest="$2"
    if has_cmd curl; then
        # Allow plain HTTP for local/private URLs (e.g. WPS365_CDN_URL=http://...)
        case "$url" in
            http://127.0.0.1*|http://localhost*)
                curl -fsSL --retry 3 -o "$dest" "$url"
                ;;
            *)
                curl --proto '=https' --tlsv1.2 -fsSL --retry 3 -o "$dest" "$url"
                ;;
        esac
    elif has_cmd wget; then
        case "$url" in
            http://127.0.0.1*|http://localhost*)
                wget -q --tries=3 -O "$dest" "$url"
                ;;
            *)
                wget --https-only -q --tries=3 -O "$dest" "$url"
                ;;
        esac
    else
        abort "Either 'curl' or 'wget' is required for downloading."
    fi
}

# Download with fallback: CDN first, then GitHub
do_download_with_fallback() {
    local cdn_url="$1" gh_url="$2" dest="$3"
    if do_download "$cdn_url" "$dest" 2>/dev/null; then
        return 0
    fi
    warn "CDN download failed, trying GitHub Releases..."
    do_download "$gh_url" "$dest"
}

# ------------------------------------------------------------------
# parse_args
# ------------------------------------------------------------------
parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --version|-v)
                shift
                [ $# -eq 0 ] && abort "--version requires a value (e.g. v0.2.0)"
                VERSION="$1"
                ;;
            --install-dir|-d)
                shift
                [ $# -eq 0 ] && abort "--install-dir requires a path"
                INSTALL_DIR="$1"
                ;;
            --no-modify-path)
                MODIFY_PATH=false
                ;;
            --force|-f)
                FORCE=true
                ;;
            --insecure)
                INSECURE=true
                ;;
            --help|-h)
                print_help
                exit 0
                ;;
            *)
                abort "Unknown option: $1 (see --help)"
                ;;
        esac
        shift
    done
}

print_help() {
    cat <<EOF
WPS 365 CLI Installer

USAGE:
    curl -fsSL https://open-docs.wpscdn.cn/cli/install.sh | bash
    curl -fsSL https://open-docs.wpscdn.cn/cli/install.sh | bash -s -- [OPTIONS]

OPTIONS:
    -v, --version <VERSION>       Install a specific version (e.g. v0.3.2) [default: latest]
    -d, --install-dir <DIR>       Installation directory [default: ~/.local/bin]
        --no-modify-path          Do not modify shell profile for PATH
    -f, --force                   Overwrite existing binary without prompting
        --insecure                Skip checksum verification (NOT recommended)
    -h, --help                    Show this help message

ENVIRONMENT:
    WPS365_CDN_URL                Override CDN base URL for downloads
    WPS365_CDN_LATEST_URL         Override CDN latest.txt URL
    WPS365_INSTALL_DIR            Override installation directory [default: ~/.local/bin]

EXAMPLES:
    # Install latest version
    curl -fsSL https://open-docs.wpscdn.cn/cli/install.sh | bash

    # Install specific version
    curl -fsSL https://open-docs.wpscdn.cn/cli/install.sh | bash -s -- -v v0.3.2

    # Install to /usr/local/bin
    curl -fsSL https://open-docs.wpscdn.cn/cli/install.sh | bash -s -- -d /usr/local/bin

    # Uninstall
    rm ~/.local/bin/wps365-cli
EOF
}

# ------------------------------------------------------------------
# detect_platform: returns darwin / linux
# ------------------------------------------------------------------
detect_platform() {
    local os
    os="$(uname -s)"
    case "$os" in
        Darwin)  echo "darwin" ;;
        Linux)   echo "linux" ;;
        MINGW*|MSYS*|CYGWIN*)
            echo "windows" ;;
        *)
            abort "Unsupported operating system: $os"
            ;;
    esac
}

# ------------------------------------------------------------------
# detect_arch: returns x86_64 / aarch64
# ------------------------------------------------------------------
detect_arch() {
    local arch
    arch="$(uname -m)"
    case "$arch" in
        x86_64|amd64)   echo "x86_64" ;;
        arm64|aarch64)   echo "aarch64" ;;
        *)
            abort "Unsupported architecture: $arch"
            ;;
    esac
}

# ------------------------------------------------------------------
# resolve_target: maps OS+arch to release target triple
# ------------------------------------------------------------------
resolve_target() {
    local platform="$1" arch="$2"
    case "${platform}-${arch}" in
        darwin-aarch64) echo "aarch64-apple-darwin" ;;
        darwin-x86_64)  echo "x86_64-apple-darwin" ;;
        linux-x86_64)   echo "x86_64-unknown-linux-gnu" ;;
        linux-aarch64)  echo "aarch64-unknown-linux-gnu" ;;
        windows-x86_64) echo "x86_64-pc-windows-gnu" ;;
        windows-aarch64) echo "aarch64-pc-windows-gnu" ;;
        *)
            abort "No prebuilt binary for ${platform}/${arch}. Try building from source: go install github.com/${GITHUB_REPO}/cmd/wps365-cli@latest"
            ;;
    esac
}

# ------------------------------------------------------------------
# resolve_version: fetch latest tag or validate user-provided version
# ------------------------------------------------------------------
resolve_version() {
    if [ "$VERSION" = "latest" ]; then
        info "Fetching latest version..."
        local tag=""

        # Prefer CDN latest.txt to avoid GitHub API rate limits.
        if has_cmd curl; then
            tag="$(curl --proto '=https' --tlsv1.2 -fsSL "$CDN_LATEST_URL" 2>/dev/null | tr -d '[:space:]' || true)"
        elif has_cmd wget; then
            tag="$(wget --https-only -qO- "$CDN_LATEST_URL" 2>/dev/null | tr -d '[:space:]' || true)"
        else
            abort "Either 'curl' or 'wget' is required."
        fi

        if [ -z "$tag" ]; then
            warn "CDN latest.txt unavailable, falling back to GitHub API..."
            if has_cmd curl; then
                tag="$(curl --proto '=https' --tlsv1.2 -fsSL "$GITHUB_API_URL" | grep '"tag_name"' | head -1 | sed 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')"
            elif has_cmd wget; then
                tag="$(wget --https-only -qO- "$GITHUB_API_URL" | grep '"tag_name"' | head -1 | sed 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')"
            fi
        fi

        if [ -z "$tag" ]; then
            abort "Failed to resolve latest version. Specify a version with --version."
        fi
        VERSION="$tag"
    fi

    # Normalize: ensure version starts with 'v'
    case "$VERSION" in
        v*) ;;
        *)  VERSION="v${VERSION}" ;;
    esac
}

# ------------------------------------------------------------------
# verify_checksum: SHA256 verification
# ------------------------------------------------------------------
verify_checksum() {
    local archive="$1" checksums_file="$2" archive_name="$3"

    if [ "$INSECURE" = "true" ]; then
        warn "Checksum verification is disabled (--insecure)."
        return 0
    fi

    if [ ! -f "$checksums_file" ]; then
        abort "Checksum file not available: ${checksums_file}"
    fi

    local expected
    expected="$(awk -v target="$archive_name" '$2 == target {print $1}' "$checksums_file" | head -1)"
    if [ -z "$expected" ]; then
        abort "No checksum found for ${archive_name} in ${checksums_file}"
    fi

    local actual
    if has_cmd sha256sum; then
        actual="$(sha256sum "$archive" | awk '{print $1}')"
    elif has_cmd shasum; then
        actual="$(shasum -a 256 "$archive" | awk '{print $1}')"
    else
        abort "Neither sha256sum nor shasum found; cannot verify archive checksum."
    fi

    if [ "$expected" != "$actual" ]; then
        abort "Checksum verification failed!\n  Expected: ${expected}\n  Actual:   ${actual}\nThe downloaded file may be corrupted or tampered with."
    fi

    info "Checksum verified (SHA-256)"
}

# ------------------------------------------------------------------
# install_binary: extract archive and place binary
# ------------------------------------------------------------------
install_binary() {
    local archive="$1" install_dir="$2" platform="$3"

    mkdir -p "$install_dir"

    local ext=""
    [ "$platform" = "windows" ] && ext=".exe"

    case "$archive" in
        *.tar.gz)
            tar xzf "$archive" -C "$install_dir" "${BIN_NAME}${ext}"
            ;;
        *.zip)
            need_cmd unzip
            unzip -oq "$archive" "${BIN_NAME}${ext}" -d "$install_dir"
            ;;
        *)
            abort "Unknown archive format: $archive"
            ;;
    esac

    chmod +x "${install_dir}/${BIN_NAME}${ext}"
}

# ------------------------------------------------------------------
# detect_profile: find the user's shell profile file
# ------------------------------------------------------------------
detect_profile() {
    local shell_name
    shell_name="$(basename "${SHELL:-/bin/sh}")"

    case "$shell_name" in
        zsh)
            local zshrc="${ZDOTDIR:-$HOME}/.zshrc"
            if [ -f "$zshrc" ]; then
                echo "$zshrc"
            elif [ -f "$HOME/.zprofile" ]; then
                echo "$HOME/.zprofile"
            else
                echo "$zshrc"
            fi
            ;;
        bash)
            if [ -f "$HOME/.bashrc" ]; then
                echo "$HOME/.bashrc"
            elif [ -f "$HOME/.bash_profile" ]; then
                echo "$HOME/.bash_profile"
            else
                echo "$HOME/.bashrc"
            fi
            ;;
        fish)
            echo "${XDG_CONFIG_HOME:-$HOME/.config}/fish/config.fish"
            ;;
        *)
            if [ -f "$HOME/.profile" ]; then
                echo "$HOME/.profile"
            else
                echo ""
            fi
            ;;
    esac
}

# ------------------------------------------------------------------
# configure_path: add install dir to PATH via shell profile
# ------------------------------------------------------------------
configure_path() {
    local install_dir="$1"

    # Already in PATH? Nothing to do.
    case ":${PATH}:" in
        *":${install_dir}:"*)
            return 0
            ;;
    esac

    if [ "$MODIFY_PATH" != "true" ]; then
        warn "${install_dir} is not in your PATH. Add it manually:"
        warn "  export PATH=\"${install_dir}:\$PATH\""
        return 0
    fi

    local profile
    profile="$(detect_profile)"
    if [ -z "$profile" ]; then
        warn "Could not detect shell profile. Add to your PATH manually:"
        warn "  export PATH=\"${install_dir}:\$PATH\""
        return 0
    fi

    local shell_name
    shell_name="$(basename "${SHELL:-/bin/sh}")"

    local path_line
    if [ "$shell_name" = "fish" ]; then
        path_line="set -gx PATH \"${install_dir}\" \$PATH"
    else
        path_line="export PATH=\"${install_dir}:\$PATH\""
    fi

    if [ -f "$profile" ] && grep -qF "$install_dir" "$profile" 2>/dev/null; then
        return 0
    fi

    info "Adding ${install_dir} to PATH in ${profile}"
    {
        echo ""
        echo "# wps365-cli"
        echo "$path_line"
    } >> "$profile"
}

# ------------------------------------------------------------------
# print_summary
# ------------------------------------------------------------------
print_summary() {
    local install_dir="$1" version="$2" profile="$3" bin_name="$4"

    echo ""
    printf "\033[1;32m✓\033[0m WPS 365 CLI %s installed to %s/%s\n" "$version" "$install_dir" "$bin_name"
    echo ""

    # Check if available in current session
    case ":${PATH}:" in
        *":${install_dir}:"*)
            echo "  Run 'wps365-cli --version' to verify."
            ;;
        *)
            if [ -n "$profile" ]; then
                echo "  Restart your terminal or run:"
                echo "    source ${profile}"
            else
                echo "  Add to your PATH:"
                echo "    export PATH=\"${install_dir}:\$PATH\""
            fi
            ;;
    esac

    echo ""
    echo "  快速开始:"
    echo "    ${bin_name} config init            # 浏览器创建/绑定应用（仅需一次）"
    echo "    ${bin_name} auth login --device    # 设备码授权（可省略 --scopes）"
    echo "    ${bin_name} user me                # 确认当前登录用户"
    echo ""
    echo "  To uninstall:"
    echo "    rm ${install_dir}/${bin_name}"
    echo ""
}

# ------------------------------------------------------------------
# main
# ------------------------------------------------------------------
main() {
    parse_args "$@"

    info "WPS 365 CLI Installer"
    echo ""

    local platform arch target
    platform="$(detect_platform)"
    arch="$(detect_arch)"
    target="$(resolve_target "$platform" "$arch")"

    info "Detected platform: ${platform}/${arch} -> ${target}"

    resolve_version
    info "Version: ${VERSION}"

    # Archive name and extension
    local archive_ext="tar.gz"
    [ "$platform" = "windows" ] && archive_ext="zip"
    local archive_name="${BIN_NAME}-${target}.${archive_ext}"

    # Create temp dir with cleanup trap
    TMP_DIR="$(mktemp -d)"
    trap 'rm -rf "$TMP_DIR"' EXIT

    # Download archive
    local cdn_url="${CDN_BASE_URL}/${VERSION}/${archive_name}"
    local gh_url="${GITHUB_BASE_URL}/${VERSION}/${archive_name}"
    local archive_path="${TMP_DIR}/${archive_name}"

    info "Downloading ${archive_name}..."
    do_download_with_fallback "$cdn_url" "$gh_url" "$archive_path"

    # Download and verify checksum
    local checksums_path="${TMP_DIR}/checksums-sha256.txt"
    local cdn_checksums="${CDN_BASE_URL}/${VERSION}/checksums-sha256.txt"
    local gh_checksums="${GITHUB_BASE_URL}/${VERSION}/checksums-sha256.txt"

    do_download_with_fallback "$cdn_checksums" "$gh_checksums" "$checksums_path"
    verify_checksum "$archive_path" "$checksums_path" "$archive_name"

    local ext=""
    [ "$platform" = "windows" ] && ext=".exe"
    local bin_name="${BIN_NAME}${ext}"

    # Check for existing installation
    local install_path="${INSTALL_DIR}/${bin_name}"
    if [ -f "$install_path" ] && [ "$FORCE" != "true" ]; then
        local existing_ver
        existing_ver="$("$install_path" --version 2>/dev/null || echo "unknown")"
        info "Existing installation found: ${existing_ver}"
        info "Upgrading to ${VERSION}..."
    fi

    # Check write permission, use sudo if needed
    local use_sudo=""
    if [ -d "$INSTALL_DIR" ] && [ ! -w "$INSTALL_DIR" ]; then
        warn "${INSTALL_DIR} is not writable. Using sudo..."
        use_sudo="sudo"
    elif [ ! -d "$INSTALL_DIR" ]; then
        mkdir -p "$INSTALL_DIR" 2>/dev/null || {
            warn "Cannot create ${INSTALL_DIR}. Using sudo..."
            use_sudo="sudo"
            $use_sudo mkdir -p "$INSTALL_DIR"
        }
    fi

    # Extract to temp, then move (supports sudo)
    local staging_dir="${TMP_DIR}/staging"
    mkdir -p "$staging_dir"
    install_binary "$archive_path" "$staging_dir" "$platform"

    if [ -n "$use_sudo" ]; then
        $use_sudo cp "${staging_dir}/${BIN_NAME}${ext}" "${INSTALL_DIR}/${BIN_NAME}${ext}"
        $use_sudo chmod +x "${INSTALL_DIR}/${BIN_NAME}${ext}"
    else
        cp "${staging_dir}/${BIN_NAME}${ext}" "${INSTALL_DIR}/${BIN_NAME}${ext}"
        chmod +x "${INSTALL_DIR}/${BIN_NAME}${ext}"
    fi

    info "Installed to ${INSTALL_DIR}/${BIN_NAME}${ext}"

    # Configure PATH
    local profile=""
    configure_path "$INSTALL_DIR"
    profile="$(detect_profile)"

    print_summary "$INSTALL_DIR" "$VERSION" "$profile" "$bin_name"
}

main "$@"
