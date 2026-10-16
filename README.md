# disk-guard

Lightweight, zero-dependency scheduled disk cleaner for **macOS** and **Windows** that reclaims gigabytes of leaked temporary directories left behind by Chromium/Electron browsers (`code_sign_clone`, `scoped_dir*`), test runners (`pytest`), build pipelines (`XcodeDistPipeline.*`, Playwright/Puppeteer temp profiles), and coding-agent caches (`~/.codex/visualizations`).

## What It Cleans

| Target | macOS Path | Windows Path | Default Retention |
| :--- | :--- | :--- | :--- |
| **Chromium / Electron clones & temp dirs** | `$DARWIN_USER_DIR/X/*.code_sign_clone/*` | `%TEMP%\scoped_dir*`, `chrome_BITS_*`, `chrome_drag*` | Older than **180 minutes** |
| **Build & browser automation pipelines** | `$DARWIN_USER_DIR/T/XcodeDistPipeline.*`, `scoped_dir*` | `%TEMP%\playwright*`, `puppeteer_dev_chrome_profile-*` | Older than **1 day** |
| **Test & profiling artifacts** | `$DARWIN_USER_DIR/C/com.apple.dt.Instruments`, `$DARWIN_USER_DIR/T/pytest-of-$USER` | `%TEMP%\pytest-of-%USERNAME%` | Older than **3 days** |
| **Coding agent visualizations** | `~/.codex/visualizations` | `%USERPROFILE%\.codex\visualizations` | Older than **3 days** |

All user paths and per-user Darwin/Windows temp directories are detected dynamically at runtime—no hardcoded usernames or machine-specific paths.

---

## Quick Start

### macOS (`LaunchAgent`)

```bash
git clone https://github.com/cskwork/disk-guard.git
cd disk-guard
./install.sh
```

- Installs the script to `~/.local/bin/disk-guard.sh`
- Registers `~/Library/LaunchAgents/com.disk-guard.agent.plist` (runs at login and daily at **04:00**)
- Logs output to `~/Library/Logs/disk-guard.log`

**Preview without deleting (`--dry-run`):**

```bash
~/.local/bin/disk-guard.sh --dry-run
```

**Uninstall:**

```bash
./uninstall.sh
```

---

### Windows (`PowerShell` + `Scheduled Task`)

Run in PowerShell (no Administrator privileges required):

```powershell
git clone https://github.com/cskwork/disk-guard.git
cd disk-guard
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

- Installs the script to `%LOCALAPPDATA%\disk-guard\disk-guard.ps1`
- Registers `DiskGuard-Daily` (daily at **04:00**) and `DiskGuard-Logon` (at user logon) in Windows Task Scheduler
- Logs output to `%LOCALAPPDATA%\disk-guard\disk-guard.log`

**Preview without deleting (`-DryRun`):**

```powershell
powershell -ExecutionPolicy Bypass -File "$env:LOCALAPPDATA\disk-guard\disk-guard.ps1" -DryRun
```

**Uninstall:**

```powershell
powershell -ExecutionPolicy Bypass -File .\uninstall.ps1
```

---

## Configuration

Override defaults via CLI flags or environment variables:

| Environment Variable | macOS Flag | Windows Flag | Default | Description |
| :--- | :--- | :--- | :--- | :--- |
| `DISK_GUARD_CLONE_TTL_MINUTES` | `--clone-ttl-minutes` | `-CloneTtlMinutes` | `180` | Minutes before Chromium `code_sign_clone` / `scoped_dir*` folders are deleted |
| `DISK_GUARD_PIPELINE_TTL_DAYS` | `--pipeline-ttl-days` | `-PipelineTtlDays` | `1` | Days before transient pipeline/automation folders are deleted |
| `DISK_GUARD_ARTIFACT_TTL_DAYS` | `--artifact-ttl-days` | `-ArtifactTtlDays` | `3` | Days before Instruments, `pytest`, and `.codex/visualizations` are deleted |
| `DISK_GUARD_EXTRA_PATHS` | *(env only)* | *(env only)* | *(empty)* | Extra directories to clean using `ARTIFACT_TTL_DAYS` (`:`-separated on macOS, `;`-separated on Windows) |

## License

MIT
