#!/usr/bin/env pwsh
[CmdletBinding()]
param(
    [Alias("v")]
    [string]$Version = "latest",
    [Alias("d")]
    [string]$InstallDir = "",
    [switch]$NoModifyPath,
    [Alias("f")]
    [switch]$Force,
    [switch]$Insecure
)

$ErrorActionPreference = "Stop"

if (-not $InstallDir) {
    if ($env:WPS365_INSTALL_DIR) {
        $InstallDir = $env:WPS365_INSTALL_DIR
    } else {
        $homeDir = if ($HOME) { $HOME } else { $env:USERPROFILE }
        $InstallDir = Join-Path $homeDir ".local\bin"
    }
}

$BinName = "wps365-cli"
$GithubRepo = "wps365-open/cli"
$CdnBaseUrl = if ($env:WPS365_CDN_URL) { $env:WPS365_CDN_URL } else { "https://open-docs.wpscdn.cn/cli/releases/download" }
$CdnLatestUrl = if ($env:WPS365_CDN_LATEST_URL) { $env:WPS365_CDN_LATEST_URL } else { "https://open-docs.wpscdn.cn/cli/latest.txt" }
$GithubBaseUrl = "https://github.com/$GithubRepo/releases/download"
$GithubApiUrl = "https://api.github.com/repos/$GithubRepo/releases/latest"

function Write-Info($msg) { Write-Host "==> $msg" -ForegroundColor Cyan }
function Write-WarnMsg($msg) { Write-Host "Warning: $msg" -ForegroundColor Yellow }
function Fail($msg) { throw $msg }

function Resolve-Arch {
    # Prefer RuntimeInformation (PS7+ / .NET 4.7.1+); fall back for Windows PowerShell 5.1.
    $arch = $null
    try {
        $arch = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString()
    } catch {
        $arch = $env:PROCESSOR_ARCHITECTURE
    }
    if (-not $arch) {
        $arch = $env:PROCESSOR_ARCHITECTURE
    }
    switch -Regex ($arch) {
        '^(X64|AMD64|x86_64)$' { return "x86_64" }
        '^(Arm64|ARM64|aarch64)$' { return "aarch64" }
        default { Fail "Unsupported architecture: $arch" }
    }
}

function Resolve-Target {
    param([string]$Arch)
    switch ($Arch) {
        "x86_64" { return "x86_64-pc-windows-gnu" }
        "aarch64" { return "aarch64-pc-windows-gnu" }
        default { Fail "No prebuilt binary for windows/$Arch" }
    }
}

function Resolve-Version {
    param([string]$InputVersion)
    if ($InputVersion -eq "latest") {
        Write-Info "Fetching latest version..."
        $tag = $null
        try {
            # Invoke-RestMethod returns string for text/plain; more reliable than
            # IWR.Content on Windows PowerShell 5.1 (Content can be $null → Trim() crash).
            $tag = [string](Invoke-RestMethod -Uri $CdnLatestUrl)
            if ($tag) { $tag = $tag.Trim() }
        } catch {
            Write-WarnMsg "CDN latest.txt unavailable, falling back to GitHub API..."
        }
        if (-not $tag) {
            try {
                $resp = Invoke-RestMethod -Uri $GithubApiUrl
            } catch {
                Fail "Failed to resolve latest version ($($_.Exception.Message)). Specify -Version vX.Y.Z."
            }
            if (-not $resp -or -not $resp.tag_name) {
                Fail "Failed to resolve latest version. Specify -Version vX.Y.Z."
            }
            $tag = [string]$resp.tag_name
        }
        return $tag
    }
    if ($InputVersion -and $InputVersion.StartsWith("v")) {
        return $InputVersion
    }
    return "v$InputVersion"
}

function Download-WithFallback {
    param(
        [string]$PrimaryUrl,
        [string]$FallbackUrl,
        [string]$Destination
    )
    # -UseBasicParsing: required on Windows PowerShell 5.1 without IE engine.
    $iwr = @{ UseBasicParsing = $true }
    try {
        Invoke-WebRequest -Uri $PrimaryUrl -OutFile $Destination @iwr
        return
    } catch {
        Write-WarnMsg "CDN download failed, trying GitHub Releases..."
        Invoke-WebRequest -Uri $FallbackUrl -OutFile $Destination @iwr
    }
}

function Verify-Checksum {
    param(
        [string]$ArchivePath,
        [string]$ChecksumsPath,
        [string]$ArchiveName
    )
    if ($Insecure) {
        Write-WarnMsg "Checksum verification is disabled (--Insecure)."
        return
    }
    if (!(Test-Path $ChecksumsPath)) {
        Fail "Checksum file not available: $ChecksumsPath"
    }

    $expected = $null
    foreach ($line in Get-Content -Path $ChecksumsPath) {
        if ($line -match "^\s*([a-fA-F0-9]{64})\s+\*?(.+)\s*$") {
            if ($Matches[2] -eq $ArchiveName) {
                $expected = $Matches[1].ToLowerInvariant()
                break
            }
        }
    }
    if (-not $expected) {
        Fail "No checksum found for $ArchiveName in $ChecksumsPath"
    }

    $actual = (Get-FileHash -Path $ArchivePath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -ne $expected) {
        Fail "Checksum verification failed. Expected=$expected Actual=$actual"
    }
    Write-Info "Checksum verified (SHA-256)"
}

function Ensure-Path {
    param([string]$Dir)
    if ($NoModifyPath) {
        Write-WarnMsg "$Dir is not in PATH. Add it manually if needed."
        return
    }
    $currentUserPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $parts = @()
    if ($currentUserPath) {
        $parts = $currentUserPath -split ';'
    }
    if ($parts -contains $Dir) {
        return
    }
    $newPath = if ($currentUserPath) { "$currentUserPath;$Dir" } else { $Dir }
    [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
    Write-Info "Added $Dir to user PATH. Restart terminal to take effect."
}

Write-Info "WPS 365 CLI Installer (Windows)"
$arch = Resolve-Arch
$target = Resolve-Target -Arch $arch
$resolvedVersion = Resolve-Version -InputVersion $Version
Write-Info "Detected target: $target"
Write-Info "Version: $resolvedVersion"

$archiveName = "$BinName-$target.zip"
$tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) ("wps365-install-" + [System.Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tmpDir | Out-Null

try {
    $archivePath = Join-Path $tmpDir $archiveName
    $checksumsPath = Join-Path $tmpDir "checksums-sha256.txt"

    $cdnArchive = "$CdnBaseUrl/$resolvedVersion/$archiveName"
    $ghArchive = "$GithubBaseUrl/$resolvedVersion/$archiveName"
    $cdnChecksums = "$CdnBaseUrl/$resolvedVersion/checksums-sha256.txt"
    $ghChecksums = "$GithubBaseUrl/$resolvedVersion/checksums-sha256.txt"

    Write-Info "Downloading $archiveName..."
    Download-WithFallback -PrimaryUrl $cdnArchive -FallbackUrl $ghArchive -Destination $archivePath
    Download-WithFallback -PrimaryUrl $cdnChecksums -FallbackUrl $ghChecksums -Destination $checksumsPath
    Verify-Checksum -ArchivePath $archivePath -ChecksumsPath $checksumsPath -ArchiveName $archiveName

    if (!(Test-Path $InstallDir)) {
        New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
    }
    $targetExe = Join-Path $InstallDir "$BinName.exe"
    if ((Test-Path $targetExe) -and (-not $Force)) {
        Write-Info "Existing installation found, upgrading..."
    }

    $extractDir = Join-Path $tmpDir "extract"
    New-Item -ItemType Directory -Path $extractDir | Out-Null
    Expand-Archive -Path $archivePath -DestinationPath $extractDir -Force

    $sourceExe = Join-Path $extractDir "$BinName.exe"
    if (!(Test-Path $sourceExe)) {
        Fail "Archive does not contain $BinName.exe"
    }
    Copy-Item -Path $sourceExe -Destination $targetExe -Force

    Ensure-Path -Dir $InstallDir

    Write-Host ""
    Write-Host "✓ WPS 365 CLI $resolvedVersion installed to $targetExe" -ForegroundColor Green
    Write-Host ""
    Write-Host "  快速开始:" -ForegroundColor Green
    Write-Host "    $BinName config init           # 浏览器创建/绑定应用（仅需一次）"
    Write-Host "    $BinName auth login --device   # 设备码授权（可省略 --scopes）"
    Write-Host "    $BinName user me               # 确认当前登录用户"
    Write-Host ""
    Write-Host "卸载:"
    Write-Host "  Remove-Item `"$targetExe`""
    Write-Host ""
} finally {
    if (Test-Path $tmpDir) {
        Remove-Item -Path $tmpDir -Recurse -Force
    }
}
