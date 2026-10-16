[CmdletBinding()]
param(
    [string]$TaskName = $(if ($env:DISK_GUARD_TASK_NAME) { $env:DISK_GUARD_TASK_NAME } else { "DiskGuard" })
)
& (Join-Path $PSScriptRoot "windows\uninstall.ps1") -TaskName $TaskName
