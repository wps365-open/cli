<#
.SYNOPSIS
    WPS365 CLI installer for Windows.
.EXAMPLE
    irm https://raw.githubusercontent.com/wps365-open/cli/main/install.ps1 | iex
.EXAMPLE
    $env:WPS365_VERSION = "v0.0.2"; irm https://raw.githubusercontent.com/wps365-open/cli/main/install.ps1 | iex
.EXAMPLE
    powershell -ExecutionPolicy Bypass -File install.ps1
#>
& {
    $ErrorActionPreference = "Stop"

    $Repo       = "wps365-open/cli"
    $BinaryName = "wps365-cli"
    $GitHubBase = "https://github.com/$Repo/releases"

    if ($env:WPS365_INSTALL_DIR) { $InstallDir = $env:WPS365_INSTALL_DIR }
    else { $InstallDir = "$env:USERPROFILE\.wps365\bin" }

    Write-Host ""
    Write-Host "  WPS365 CLI Installer" -ForegroundColor Cyan
    Write-Host "  ────────────────────"
    Write-Host ""

    # --- Detect platform ---
    $cpuArch = $env:PROCESSOR_ARCHITECTURE
    if ($cpuArch -eq "ARM64") { $arch = "aarch64" }
    elseif ($cpuArch -eq "AMD64") { $arch = "x86_64" }
    else { Write-Host "✘ 不支持的 CPU 架构: $cpuArch" -ForegroundColor Red; return }
    $platform = "$arch-pc-windows-gnu"
    Write-Host "▸ 检测到平台: $platform" -ForegroundColor Cyan

    # --- Detect version ---
    if ($env:WPS365_VERSION) {
        $version = $env:WPS365_VERSION
        Write-Host "▸ 使用指定版本: $version" -ForegroundColor Cyan
    } else {
        Write-Host "▸ 正在获取最新版本号..." -ForegroundColor Cyan
        $version = $null
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

        # Method 1: GitHub API
        $prevPref = $ErrorActionPreference
        $ErrorActionPreference = "SilentlyContinue"
        $body = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases/latest" 2>$null
        $ErrorActionPreference = $prevPref
        if ($body) { $version = $body.tag_name }

        # Method 2: follow /releases/latest redirect
        if (-not $version) {
            $prevPref = $ErrorActionPreference
            $ErrorActionPreference = "SilentlyContinue"
            $resp = Invoke-WebRequest -Uri "$GitHubBase/latest" -UseBasicParsing -MaximumRedirection 5 2>$null
            $ErrorActionPreference = $prevPref
            if ($resp -and $resp.BaseResponse) {
                $finalUrl = "$($resp.BaseResponse.ResponseUri)"
                if (-not $finalUrl) { $finalUrl = "$($resp.BaseResponse.RequestMessage.RequestUri)" }
                if ($finalUrl -match '/tag/([^/]+)$') { $version = $Matches[1] }
            }
        }

        # Method 3: parse HTML from releases page
        if (-not $version) {
            $prevPref = $ErrorActionPreference
            $ErrorActionPreference = "SilentlyContinue"
            $html = Invoke-WebRequest -Uri "$GitHubBase" -UseBasicParsing 2>$null
            $ErrorActionPreference = $prevPref
            if ($html -and $html.Content -match '/releases/tag/([^"]+)') { $version = $Matches[1] }
        }

        if (-not $version) { Write-Host "✘ 无法获取最新版本信息，请检查网络连接" -ForegroundColor Red; return }
        Write-Host "▸ 最新版本: $version" -ForegroundColor Cyan
    }

    # --- Download ---
    $filename = "$BinaryName-$platform.zip"
    $url      = "$GitHubBase/download/$version/$filename"
    $tmpDir   = Join-Path ([System.IO.Path]::GetTempPath()) "wps365-cli-install-$(Get-Random)"
    New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null
    $zipPath = Join-Path $tmpDir $filename

    Write-Host "▸ 下载 $filename ..." -ForegroundColor Cyan
    $prevPref2 = $ErrorActionPreference
    $ErrorActionPreference = "SilentlyContinue"
    Invoke-WebRequest -Uri $url -OutFile $zipPath -UseBasicParsing 2>$null
    $ErrorActionPreference = $prevPref2

    if (-not (Test-Path $zipPath) -or (Get-Item $zipPath).Length -eq 0) {
        Write-Host "✘ 下载失败，请检查网络或版本号" -ForegroundColor Red
        Remove-Item -Path $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
        return
    }

    # --- Extract ---
    Write-Host "▸ 解压中..." -ForegroundColor Cyan
    Expand-Archive -Path $zipPath -DestinationPath $tmpDir -Force

    $binary = Get-ChildItem -Path $tmpDir -Filter "$BinaryName.exe" -Recurse | Select-Object -First 1
    if (-not $binary) {
        Write-Host "✘ 解压后未找到 $BinaryName.exe" -ForegroundColor Red
        Remove-Item -Path $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
        return
    }

    # --- Install ---
    if (-not (Test-Path $InstallDir)) {
        New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
    }
    $dest = Join-Path $InstallDir "$BinaryName.exe"
    Copy-Item -Path $binary.FullName -Destination $dest -Force
    Remove-Item -Path $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "✔ 安装完成！" -ForegroundColor Green

    # --- Add to PATH ---
    $currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $found = $false
    foreach ($p in ($currentPath -split ';')) { if ($p -eq $InstallDir) { $found = $true } }
    if (-not $found) {
        Write-Host "▸ 将 $InstallDir 添加到用户 PATH ..." -ForegroundColor Cyan
        [Environment]::SetEnvironmentVariable("Path", "$InstallDir;$currentPath", "User")
        $env:Path = "$InstallDir;$env:Path"
        Write-Host "✔ 已添加到 PATH（新终端窗口自动生效）" -ForegroundColor Green
    }

    # --- Verify ---
    Write-Host "✔ $BinaryName 已安装到 $dest" -ForegroundColor Green
    $ErrorActionPreference = "SilentlyContinue"
    $ver = & $dest --version 2>&1
    $ErrorActionPreference = "Stop"
    if ($ver) { Write-Host "▸ 版本: $ver" -ForegroundColor Cyan }

    Write-Host ""
    Write-Host "  快速开始:" -ForegroundColor Green
    Write-Host "    $BinaryName auth setup        # 配置 OAuth 客户端凭证"
    Write-Host "    $BinaryName auth login        # 登录授权"
    Write-Host "    $BinaryName user me           # 查看当前用户"
    Write-Host ""
}
