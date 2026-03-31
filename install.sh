#!/usr/bin/env bash
set -euo pipefail

REPO="wps365-open/cli"
BINARY_NAME="wps365-cli"
GITHUB_BASE="https://github.com/${REPO}/releases"

# Windows (Git Bash / MINGW) 使用用户目录，其他系统使用 /usr/local/bin
case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*) _DEFAULT_DIR="$HOME/.wps365/bin" ;;
    *)                    _DEFAULT_DIR="/usr/local/bin" ;;
esac
INSTALL_DIR="${WPS365_INSTALL_DIR:-$_DEFAULT_DIR}"
TMPDIR_CLEANUP=""

RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[0;33m'
CYAN=$'\033[0;36m'
BOLD=$'\033[1m'
RESET=$'\033[0m'

info()  { printf "%s\n" "${CYAN}▸${RESET} $*"; }
ok()    { printf "%s\n" "${GREEN}✔${RESET} $*"; }
warn()  { printf "%s\n" "${YELLOW}⚠${RESET} $*"; }
error() { printf "%s\n" "${RED}✘${RESET} $*" >&2; exit 1; }

cleanup() { [ -n "$TMPDIR_CLEANUP" ] && rm -rf "$TMPDIR_CLEANUP"; }
trap cleanup EXIT

need_cmd() {
    command -v "$1" > /dev/null 2>&1 || error "需要 '$1'，请先安装后重试"
}

detect_platform() {
    local os arch

    os="$(uname -s)"
    arch="$(uname -m)"

    case "$os" in
        Linux*)  os="unknown-linux-gnu" ;;
        Darwin*) os="apple-darwin" ;;
        MINGW*|MSYS*|CYGWIN*) os="pc-windows-gnu" ;;
        *) error "不支持的操作系统: $os" ;;
    esac

    case "$arch" in
        x86_64|amd64)  arch="x86_64" ;;
        aarch64|arm64) arch="aarch64" ;;
        *) error "不支持的 CPU 架构: $arch" ;;
    esac

    PLATFORM="${arch}-${os}"
}

detect_version() {
    if [ -n "${WPS365_VERSION:-}" ]; then
        VERSION="$WPS365_VERSION"
        info "使用指定版本: ${VERSION}"
        return
    fi

    info "正在获取最新版本号..."
    need_cmd curl

    local latest_url="${GITHUB_BASE}/latest"
    local redirect
    redirect="$(curl -fsSI -o /dev/null -w '%{redirect_url}' "$latest_url" 2>/dev/null)" || true

    if [ -n "$redirect" ]; then
        VERSION="${redirect##*/}"
    else
        local body
        body="$(curl -fsSL "$latest_url" 2>/dev/null)" || error "无法获取最新版本信息，请检查网络连接"
        VERSION="$(echo "$body" | grep -oE 'tag/v[0-9]+\.[0-9]+\.[0-9]+[^"]*' | head -1 | sed 's|tag/||')"
    fi

    [ -n "$VERSION" ] || error "无法解析最新版本号"
    info "最新版本: ${BOLD}${VERSION}${RESET}"
}

download_and_install() {
    local ext="tar.gz"
    case "$PLATFORM" in
        *windows*) ext="zip" ;;
    esac

    local filename="${BINARY_NAME}-${PLATFORM}.${ext}"
    local url="${GITHUB_BASE}/download/${VERSION}/${filename}"
    local tmpdir
    tmpdir="$(mktemp -d)"
    TMPDIR_CLEANUP="$tmpdir"

    info "下载 ${BOLD}${filename}${RESET} ..."
    need_cmd curl

    local http_code
    http_code="$(curl -fsSL -w '%{http_code}' -o "${tmpdir}/${filename}" "$url" 2>/dev/null)" || true

    [ -f "${tmpdir}/${filename}" ] && [ -s "${tmpdir}/${filename}" ] || \
        error "下载失败 (HTTP ${http_code:-unknown})\n  URL: ${url}\n  请检查网络或版本号是否正确"

    info "解压中..."
    case "$ext" in
        tar.gz)
            tar xzf "${tmpdir}/${filename}" -C "$tmpdir"
            ;;
        zip)
            need_cmd unzip
            unzip -qo "${tmpdir}/${filename}" -d "$tmpdir"
            ;;
    esac

    local binary
    binary="$(find "$tmpdir" -name "$BINARY_NAME" -type f | head -1)"
    [ -n "$binary" ] || binary="$(find "$tmpdir" -name "${BINARY_NAME}.exe" -type f | head -1)"
    [ -n "$binary" ] || error "解压后未找到 ${BINARY_NAME} 可执行文件"

    chmod +x "$binary"

    info "安装到 ${BOLD}${INSTALL_DIR}${RESET} ..."
    mkdir -p "$INSTALL_DIR" 2>/dev/null || true

    if [ -w "$INSTALL_DIR" ]; then
        mv "$binary" "${INSTALL_DIR}/${BINARY_NAME}"
    elif command -v sudo > /dev/null 2>&1; then
        warn "需要管理员权限写入 ${INSTALL_DIR}"
        sudo mv "$binary" "${INSTALL_DIR}/${BINARY_NAME}"
    else
        error "无法写入 ${INSTALL_DIR}，请使用 WPS365_INSTALL_DIR 指定其他目录"
    fi

    ok "安装完成！"
}

verify_install() {
    if command -v "$BINARY_NAME" > /dev/null 2>&1; then
        local installed_path
        installed_path="$(command -v "$BINARY_NAME")"
        ok "${BINARY_NAME} 已安装到 ${installed_path}"

        local ver_output
        ver_output="$("$BINARY_NAME" --version 2>/dev/null || echo '(无法获取版本)')"
        info "版本: ${ver_output}"
    else
        warn "${BINARY_NAME} 已安装到 ${INSTALL_DIR}/${BINARY_NAME}"
        warn "但 ${INSTALL_DIR} 不在 PATH 中"
        echo ""
        echo "  请将以下内容添加到你的 shell 配置文件 (~/.bashrc 或 ~/.zshrc):"
        echo ""
        echo "    export PATH=\"${INSTALL_DIR}:\$PATH\""
        echo ""
    fi
}

main() {
    echo ""
    printf "${BOLD}${CYAN}  WPS365 CLI Installer${RESET}\n"
    echo "  ────────────────────"
    echo ""

    detect_platform
    info "检测到平台: ${BOLD}${PLATFORM}${RESET}"

    detect_version
    download_and_install
    verify_install

    echo ""
    printf "${GREEN}${BOLD}  快速开始:${RESET}\n"
    echo "    ${BINARY_NAME} auth setup        # 配置 OAuth 客户端凭证"
    echo "    ${BINARY_NAME} auth login        # 登录授权"
    echo "    ${BINARY_NAME} user me           # 查看当前用户"
    echo ""
}

main "$@"
