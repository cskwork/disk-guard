[CmdletBinding()]
param(
    [string]$TaskName = $(if ($env:DISK_GUARD_TASK_NAME) { $env:DISK_GUARD_TASK_NAME } else { "DiskGuard" })
)

$ErrorActionPreference = 'SilentlyContinue'

foreach ($name in @("$TaskName-Daily", "$TaskName-Logon", $TaskName)) {
    & schtasks.exe /Delete /F /TN $name 2>$null | Out-Null
}

$InstallDir = Join-Path $env:LOCALAPPDATA "disk-guard"
$InstallScript = Join-Path $InstallDir "disk-guard.ps1"
if (Test-Path -LiteralPath $InstallScript) {
    Remove-Item -LiteralPath $InstallScript -Force
    Write-Output "Removed script: $InstallScript"
}
Write-Output "Removed scheduled tasks for $TaskName"
