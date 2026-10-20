# install.ps1 - One-click install of the OpenClaw Windows gateway CJK path fix
# 1. Creates an ASCII junction (nodejs-link) pointing at the real node install dir
# 2. Writes the protected gateway.vbs launcher + fix-gateway-cmd.ps1 + gateway.cmd
# 3. Registers the scheduled task to launch via the protected vbs at logon

param(
    [string]$NodeExe = '',
    [string]$OpenClawDist = (Join-Path $env:APPDATA 'npm\node_modules\openclaw\dist\index.js'),
    [int]$Port = 18789,
    [string]$TaskName = 'OpenClaw Gateway'
)

$ErrorActionPreference = 'Stop'
$ocDir = Join-Path $env:USERPROFILE '.openclaw'
$junction = Join-Path $ocDir 'nodejs-link'

# ---- 1. locate node.exe if not provided ----
if (-not $NodeExe) {
    $nodeCmd = Get-Command node -ErrorAction SilentlyContinue
    if ($nodeCmd) {
        $NodeExe = (Split-Path $nodeCmd.Source) + '\node.exe'
    }
}
if (-not $NodeExe -or -not (Test-Path $NodeExe)) {
    throw "node.exe not found. Pass -NodeExe 'E:\your\path\node.exe'"
}
Write-Host "node.exe: $NodeExe"

# ---- 2. create junction (ASCII path -> real path) ----
$realDir = Split-Path -Parent $NodeExe
if (-not (Test-Path $junction)) {
    cmd /c mklink /J "$junction" "$realDir" | Out-Null
    Write-Host "junction created: $junction -> $realDir"
} else {
    Write-Host "junction exists: $junction"
}

# ---- 3. write gateway.cmd (ASCII junction path, UTF-8 safe) ----
$gwCmd = @"
@echo off
rem OpenClaw Gateway (v2026.7.1)
set "TMPDIR=$env:TEMP"
set "OPENCLAW_GATEWAY_PORT=$Port"
set "OPENCLAW_SYSTEMD_UNIT=openclaw-gateway.service"
set "OPENCLAW_WINDOWS_TASK_NAME=$TaskName"
set "OPENCLAW_WINDOWS_TASK_HIDDEN_LAUNCHER=1"
set "OPENCLAW_SERVICE_MARKER=openclaw"
set "OPENCLAW_SERVICE_KIND=gateway"
set "OPENCLAW_SERVICE_VERSION=2026.7.1"
$junction\node.exe $OpenClawDist gateway --port $Port
"@
$gwCmdPath = Join-Path $ocDir 'gateway.cmd'
[System.IO.File]::WriteAllText($gwCmdPath, $gwCmd, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "gateway.cmd written: $gwCmdPath"

# ---- 4. write fix-gateway-cmd.ps1 (copy from this repo) ----
$fixSrc = Join-Path $PSScriptRoot 'fix-gateway-cmd.ps1'
if (Test-Path $fixSrc) {
    Copy-Item $fixSrc (Join-Path $ocDir 'fix-gateway-cmd.ps1') -Force
    Write-Host "fix-gateway-cmd.ps1 copied"
}

# ---- 5. write protected gateway.vbs ----
$vbs = @"
' OpenClaw Gateway - protected launcher
CreateObject("WScript.Shell").Run "powershell -NoProfile -ExecutionPolicy Bypass -File ""$ocDir\fix-gateway-cmd.ps1""", 0, True
CreateObject("WScript.Shell").Run """$ocDir\gateway.cmd""", 0, False
"@
$vbsPath = Join-Path $ocDir 'gateway.vbs'
[System.IO.File]::WriteAllText($vbsPath, $vbs, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "gateway.vbs written: $vbsPath"

# ---- 6. register scheduled task (logon trigger) ----
$action = New-ScheduledTaskAction -Execute 'wscript.exe' -Argument "`"$vbsPath`"" -WorkingDirectory $ocDir
$trigger = New-ScheduledTaskTrigger -AtLogOn -User "$env:USERDOMAIN\$env:USERNAME"
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Seconds 0) -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)
Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings -RunLevel Limited -Force | Out-Null
Write-Host "scheduled task registered: $TaskName"

Write-Host "`nDone. Start gateway with:  Start-ScheduledTask -TaskName '$TaskName'"
Write-Host "Verify:  http://127.0.0.1:$Port"
