[CmdletBinding()]
param(
    [string]$TaskName = $(if ($env:DISK_GUARD_TASK_NAME) { $env:DISK_GUARD_TASK_NAME } else { "DiskGuard" }),
    [string]$DailyTime = $(if ($env:DISK_GUARD_TIME) { $env:DISK_GUARD_TIME } else { "04:00" })
)

$ErrorActionPreference = 'Stop'

$InstallDir = Join-Path $env:LOCALAPPDATA "disk-guard"
$InstallScript = Join-Path $InstallDir "disk-guard.ps1"
$LogPath = Join-Path $InstallDir "disk-guard.log"
$SourceScript = Join-Path $PSScriptRoot "disk-guard.ps1"

New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
Copy-Item -LiteralPath $SourceScript -Destination $InstallScript -Force

$Command = "powershell.exe -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -Command `"& '$InstallScript' *>> '$LogPath'`""

$DailyTaskName = "$TaskName-Daily"
$LogonTaskName = "$TaskName-Logon"

& schtasks.exe /Create /F /TN $DailyTaskName /SC DAILY /ST $DailyTime /TR $Command | Out-Null
& schtasks.exe /Create /F /TN $LogonTaskName /SC ONLOGON /TR $Command | Out-Null

Write-Output "Installed disk-guard:"
Write-Output "  Script:   $InstallScript"
Write-Output "  Schedule: $DailyTaskName (daily at $DailyTime) + $LogonTaskName (on logon)"
Write-Output "  Log:      $LogPath"
