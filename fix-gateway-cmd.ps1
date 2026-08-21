# fix-gateway-cmd.ps1 - repair gateway.cmd node path to ASCII junction before launch
# Fixes the OpenClaw Windows gateway bug where a UTF-8 encoded .cmd file containing
# a Chinese/UTF-8 path (e.g. E:\小龙虾\node.exe) is parsed by cmd.exe as GBK,
# producing mojibake like 'E:\灏忛緳铏綷node.exe' and silently failing to start.

$ErrorActionPreference = 'Stop'

# --- auto-detect paths (override with -Path / -Junction if needed) ---
param(
    [string]$Path = '',
    [string]$Junction = ''
)
if (-not $Path)   { $Path = Join-Path $env:USERPROFILE '.openclaw\gateway.cmd' }
if (-not $Junction) { $Junction = Join-Path $env:USERPROFILE '.openclaw\nodejs-link\node.exe' }

$dist = Join-Path $env:APPDATA 'npm\node_modules\openclaw\dist\index.js'
if (-not (Test-Path $dist)) { $dist = Join-Path $env:USERPROFILE 'AppData\Roaming\npm\node_modules\openclaw\dist\index.js' }

try {
    $content = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)

    # Already fixed - junction path present, nothing to do.
    if ($content -match [regex]::Escape($Junction)) {
        exit 0
    }

    # Replace any X:\...\node.exe style path with the ASCII junction path.
    # Handles both UTF-8 CJK and GBK-mangled variants by regex on drive prefix.
    $newContent = $content -replace '[A-Za-z]:\\[^\r\n]*?\\node\.exe', $Junction
    if ($newContent -ne $content) {
        [System.IO.File]::WriteAllText($Path, $newContent, (New-Object System.Text.UTF8Encoding($false)))
    }
    exit 0
}
catch {
    # Fallback: if the file cannot be read as UTF-8 at all, rewrite it from scratch.
    try {
        $script = @'
@echo off
rem OpenClaw Gateway (v2026.7.1)
set "TMPDIR=%TEMP%"
set "OPENCLAW_GATEWAY_PORT=18789"
set "OPENCLAW_SYSTEMD_UNIT=openclaw-gateway.service"
set "OPENCLAW_WINDOWS_TASK_NAME=OpenClaw Gateway"
set "OPENCLAW_WINDOWS_TASK_HIDDEN_LAUNCHER=1"
set "OPENCLAW_SERVICE_MARKER=openclaw"
set "OPENCLAW_SERVICE_KIND=gateway"
set "OPENCLAW_SERVICE_VERSION=2026.7.1"
'@
        $script += "`n" + $Junction + ' ' + $dist + ' gateway --port 18789'
        [System.IO.File]::WriteAllText($Path, $script, (New-Object System.Text.UTF8Encoding($false)))
        exit 0
    }
    catch {
        exit 1
    }
}
