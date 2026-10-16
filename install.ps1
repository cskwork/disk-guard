[CmdletBinding()]
param(
    [string]$TaskName = $(if ($env:DISK_GUARD_TASK_NAME) { $env:DISK_GUARD_TASK_NAME } else { "DiskGuard" }),
    [string]$DailyTime = $(if ($env:DISK_GUARD_TIME) { $env:DISK_GUARD_TIME } else { "04:00" })
)
& (Join-Path $PSScriptRoot "windows\install.ps1") -TaskName $TaskName -DailyTime $DailyTime
