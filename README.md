<div align="center">

# disk-guard

**Zero-dependency scheduled temp & clone cleaner for macOS and Windows**

[![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Windows-0052CC?style=flat-square)](#quick-start)
[![License: MIT](https://img.shields.io/badge/license-MIT-2ea44f?style=flat-square)](./LICENSE)
[![Zero Dependencies](https://img.shields.io/badge/dependencies-0-informational?style=flat-square)](#how-it-works)
[![Landing Page](https://img.shields.io/badge/website-cskwork.github.io%2Fdisk--guard-0969da?style=flat-square)](https://cskwork.github.io/disk-guard/)

[**English**](./README.md) · [**한국어**](./README.ko.md) · [**Website**](https://cskwork.github.io/disk-guard/)

</div>

---

## Why `disk-guard`?

Every headless browser session, Electron update, Xcode build, and test run leaves multi-gigabyte temporary directories in per-user system folders:

- **macOS (`$DARWIN_USER_DIR`)**: Google Chrome and Electron apps duplicate entire `.app` bundles into `X/*.code_sign_clone` during background code-signature checks. When processes crash or get killed, those gigabytes remain until a full OS reboot.
- **Windows (`%TEMP%`)**: Chromium, Playwright, and Puppeteer sessions leave orphaned `scoped_dir*`, `chrome_BITS_*`, and profile directories behind.
- **Dev & AI Tooling**: `pytest-of-$USER`, `XcodeDistPipeline.*`, Apple `Instruments` traces, and `~/.codex/visualizations` accumulate silently over weeks.

`disk-guard` registers a native user-space scheduled job (**macOS `LaunchAgent`** or **Windows `Scheduled Task`**) that sweeps stale directories at login and **04:00 daily**—without a background daemon burning CPU or requiring root/admin permissions.

---

## What It Cleans

| Target Category | macOS Path Pattern | Windows Path Pattern | Default TTL |
| :--- | :--- | :--- | :--- |
| **Chromium & Electron Clones** | `$DARWIN_USER_DIR/X/*.code_sign_clone/*` | `%TEMP%\scoped_dir*`, `chrome_BITS_*`, `chrome_drag*` | **> 180 min** |
| **Build & Browser Pipelines** | `$DARWIN_USER_DIR/T/XcodeDistPipeline.*`, `scoped_dir*` | `%TEMP%\playwright*`, `puppeteer_dev_chrome_profile-*` | **> 1 day** |
| **Test & Profiling Artifacts** | `$DARWIN_USER_DIR/C/com.apple.dt.Instruments`, `$DARWIN_USER_DIR/T/pytest-of-$USER` | `%TEMP%\pytest-of-%USERNAME%` | **> 3 days** |
| **Coding Agent Caches** | `~/.codex/visualizations/*` | `%USERPROFILE%\.codex\visualizations\*` | **> 3 days** |

> [!NOTE]
> All usernames (`$USER`, `%USERNAME%`) and per-user temp roots (`getconf DARWIN_USER_DIR`, `%TEMP%`) are resolved dynamically at runtime. No hardcoded paths.

---

## Quick Start

### macOS (`bash` + `LaunchAgent`)

```bash
git clone https://github.com/cskwork/disk-guard.git
cd disk-guard
./install.sh
```

| Item | Location / Value |
| :--- | :--- |
| **Installed Script** | `~/.local/bin/disk-guard.sh` |
| **LaunchAgent Plist** | `~/Library/LaunchAgents/com.disk-guard.agent.plist` |
| **Schedule** | At user login (`RunAtLoad`) + daily at **04:00** |
| **Log File** | `~/Library/Logs/disk-guard.log` |

<details>
<summary><strong>macOS Dry-Run, Manual Run & Uninstall</strong></summary>

```bash
# Preview what would be deleted without removing anything
~/.local/bin/disk-guard.sh --dry-run

# Run cleanup immediately
~/.local/bin/disk-guard.sh

# Check LaunchAgent status
launchctl list | grep com.disk-guard.agent

# Uninstall script and LaunchAgent
./uninstall.sh
```

</details>

---

### Windows (`PowerShell` + `Scheduled Task`)

Run in **PowerShell** (no Administrator privileges required):

```powershell
git clone https://github.com/cskwork/disk-guard.git
cd disk-guard
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

| Item | Location / Value |
| :--- | :--- |
| **Installed Script** | `%LOCALAPPDATA%\disk-guard\disk-guard.ps1` |
| **Scheduled Tasks** | `DiskGuard-Daily` (daily at **04:00**) + `DiskGuard-Logon` (at user logon) |
| **Log File** | `%LOCALAPPDATA%\disk-guard\disk-guard.log` |

<details>
<summary><strong>Windows Dry-Run, Manual Run & Uninstall</strong></summary>

```powershell
# Preview candidate directories without deleting
powershell -ExecutionPolicy Bypass -File "$env:LOCALAPPDATA\disk-guard\disk-guard.ps1" -DryRun

# Run cleanup immediately
powershell -ExecutionPolicy Bypass -File "$env:LOCALAPPDATA\disk-guard\disk-guard.ps1"

# Verify Scheduled Tasks
schtasks /Query /TN DiskGuard-Daily

# Uninstall tasks and script
powershell -ExecutionPolicy Bypass -File .\uninstall.ps1
```

</details>

---

## Configuration & Overrides

Tune retention windows per machine using CLI flags or environment variables:

| Environment Variable | macOS Flag | Windows Flag | Default | Description |
| :--- | :--- | :--- | :--- | :--- |
| `DISK_GUARD_CLONE_TTL_MINUTES` | `--clone-ttl-minutes N` | `-CloneTtlMinutes N` | `180` | Age in minutes before Chromium `code_sign_clone` / `scoped_dir*` directories are deleted |
| `DISK_GUARD_PIPELINE_TTL_DAYS` | `--pipeline-ttl-days N` | `-PipelineTtlDays N` | `1` | Age in days before transient build/browser pipeline directories are deleted |
| `DISK_GUARD_ARTIFACT_TTL_DAYS` | `--artifact-ttl-days N` | `-ArtifactTtlDays N` | `3` | Age in days before `pytest`, `Instruments`, and `.codex/visualizations` are deleted |
| `DISK_GUARD_EXTRA_PATHS` | *(env only, `:`-separated)* | *(env only, `;`-separated)* | *(empty)* | Additional directories to prune using `ARTIFACT_TTL_DAYS` |
| `DISK_GUARD_HOUR` / `DISK_GUARD_TIME` | `DISK_GUARD_HOUR=4` | `-DailyTime "04:00"` | `04:00` | Daily scheduled execution time during installation |

---

## Repository Structure

```text
disk-guard/
├── install.sh              # Top-level macOS installer entrypoint
├── uninstall.sh            # Top-level macOS uninstaller entrypoint
├── install.ps1             # Top-level Windows installer entrypoint
├── uninstall.ps1           # Top-level Windows uninstaller entrypoint
├── macos/
│   ├── disk-guard.sh       # macOS cleanup script (bash)
│   ├── install.sh          # LaunchAgent generator & bootstrapper
│   └── uninstall.sh        # LaunchAgent unloader & cleaner
├── windows/
│   ├── disk-guard.ps1      # Windows cleanup script (PowerShell)
│   ├── install.ps1         # Scheduled Task installer (schtasks.exe)
│   └── uninstall.ps1       # Scheduled Task uninstaller
├── tests/
│   └── smoke_test.sh       # Automated dry-run & TTL retention verification
└── docs/
    └── index.html          # Project landing page (GitHub Pages)
```

## Testing

Run the isolated smoke test suite on macOS/Linux:

```bash
./tests/smoke_test.sh
```

## License

Released under the [MIT License](./LICENSE).
