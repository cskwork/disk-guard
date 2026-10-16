[CmdletBinding()]
param(
    [switch]$DryRun,
    [int]$CloneTtlMinutes = $(if ($env:DISK_GUARD_CLONE_TTL_MINUTES) { [int]$env:DISK_GUARD_CLONE_TTL_MINUTES } else { 180 }),
    [int]$ArtifactTtlDays = $(if ($env:DISK_GUARD_ARTIFACT_TTL_DAYS) { [int]$env:DISK_GUARD_ARTIFACT_TTL_DAYS } else { 3 }),
    [int]$PipelineTtlDays = $(if ($env:DISK_GUARD_PIPELINE_TTL_DAYS) { [int]$env:DISK_GUARD_PIPELINE_TTL_DAYS } else { 1 })
)

$ErrorActionPreference = 'SilentlyContinue'

function Get-FreeSpaceGB {
    $sysDrive = if ($env:SystemDrive) { $env:SystemDrive.TrimEnd('\') } else { 'C:' }
    $drive = Get-PSDrive -Name $sysDrive.TrimEnd(':')
    if ($drive -and $drive.Free) {
        return ("{0:N1}Gi" -f ($drive.Free / 1GB))
    }
    return "unknown"
}

function Write-GuardLog([string]$Message) {
    $ts = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    Write-Output "[$ts] $Message"
}

function Remove-StaleEntries {
    param(
        [string]$BasePath,
        [string[]]$FilterPatterns,
        [datetime]$Cutoff
    )
    if (-not (Test-Path -LiteralPath $BasePath)) { return }
    foreach ($pattern in $FilterPatterns) {
        Get-ChildItem -Path $BasePath -Filter $pattern -Force | Where-Object {
            $_.LastWriteTime -lt $Cutoff
        } | ForEach-Object {
            if ($DryRun) {
                Write-Output "  [dry-run] delete $($_.FullName)"
            } else {
                Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

$CurrentUser = if ($env:USERNAME) { $env:USERNAME } elseif ($env:USER) { $env:USER } else { [Environment]::UserName }
$TempRoot = if ($env:TEMP) { $env:TEMP } else { [System.IO.Path]::GetTempPath() }
$Now = Get-Date
$CloneCutoff = $Now.AddMinutes(-$CloneTtlMinutes)
$PipelineCutoff = $Now.AddDays(-$PipelineTtlDays)
$ArtifactCutoff = $Now.AddDays(-$ArtifactTtlDays)

Write-GuardLog "disk-guard start (user: $CurrentUser, dry-run: $($DryRun.IsPresent), free: $(Get-FreeSpaceGB))"

# 1. Stale Chromium / WebDriver / Electron transient directories in %TEMP%
Remove-StaleEntries -BasePath $TempRoot -FilterPatterns @(
    "scoped_dir*",
    "chrome_BITS_*",
    "chrome_drag*",
    "*.code_sign_clone*"
) -Cutoff $CloneCutoff

# 2. Stale Playwright / Puppeteer / build pipeline directories in %TEMP%
Remove-StaleEntries -BasePath $TempRoot -FilterPatterns @(
    "playwright*",
    "puppeteer_dev_chrome_profile-*",
    "XcodeDistPipeline.*"
) -Cutoff $PipelineCutoff

# 3. Stale pytest temp folders
$PytestDir = Join-Path $TempRoot "pytest-of-$CurrentUser"
if (Test-Path -LiteralPath $PytestDir) {
    Remove-StaleEntries -BasePath $PytestDir -FilterPatterns @("*") -Cutoff $ArtifactCutoff
}

# 4. Stale Codex visualizations
$UserHome = if ($env:USERPROFILE) { $env:USERPROFILE } else { $HOME }
$CodexVisDir = Join-Path (Join-Path $UserHome ".codex") "visualizations"
if (Test-Path -LiteralPath $CodexVisDir) {
    Remove-StaleEntries -BasePath $CodexVisDir -FilterPatterns @("*") -Cutoff $ArtifactCutoff
}

# 5. User-defined extra semicolon-separated directories
if ($env:DISK_GUARD_EXTRA_PATHS) {
    foreach ($extraDir in ($env:DISK_GUARD_EXTRA_PATHS -split ';')) {
        if ($extraDir -and (Test-Path -LiteralPath $extraDir)) {
            Remove-StaleEntries -BasePath $extraDir -FilterPatterns @("*") -Cutoff $ArtifactCutoff
        }
    }
}

Write-GuardLog "disk-guard done  (free: $(Get-FreeSpaceGB))"
