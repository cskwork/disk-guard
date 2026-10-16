<div align="center">

# disk-guard

**macOS 및 Windows용 무의존성(Zero-dependency) 임시 파일·크롬 클론 자동 정리 스케줄러**

[![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Windows-0052CC?style=flat-square)](#빠른-시작-quick-start)
[![License: MIT](https://img.shields.io/badge/license-MIT-2ea44f?style=flat-square)](./LICENSE)
[![Zero Dependencies](https://img.shields.io/badge/dependencies-0-informational?style=flat-square)](#정리-대상)
[![Landing Page](https://img.shields.io/badge/website-cskwork.github.io%2Fdisk--guard-0969da?style=flat-square)](https://cskwork.github.io/disk-guard/)

[**English**](./README.md) · [**한국어**](./README.ko.md) · [**웹사이트**](https://cskwork.github.io/disk-guard/)

</div>

---

## 왜 `disk-guard`인가요?

브라우저 자동화(Chromium/Playwright), Electron 앱 업데이트, Xcode 빌드, 테스트 실행이 반복되면 OS의 사용자별 임시 디렉터리에 수십 기가바이트(GB)의 고아 폴더가 쌓입니다.

- **macOS (`$DARWIN_USER_DIR`)**: Google Chrome 및 Electron 기반 앱이 코드 서명 검증 과정에서 `X/*.code_sign_clone` 아래에 앱 번들 전체를 복제합니다. 프로세스가 비정상 종료되면 재부팅 전까지 수십 GB가 그대로 남습니다.
- **Windows (`%TEMP%`)**: Chromium, Playwright, Puppeteer 실행 후 정리되지 않은 `scoped_dir*`, `chrome_BITS_*` 임시 프로필이 누적됩니다.
- **개발 및 AI 에이전트 캐시**: `pytest-of-$USER`, `XcodeDistPipeline.*`, Apple `Instruments` 트레이스, `~/.codex/visualizations` 파일이 디스크를 잠식합니다.

`disk-guard`는 상주 데몬 없이 OS 기본 스케줄러(**macOS `LaunchAgent`**, **Windows `작업 스케줄러`**)에 등록되어 **로그인 시점 및 매일 새벽 04:00**에 보존 주기가 지난 임시 폴더만 안전하게 정리합니다.

---

## 정리 대상

| 구분 | macOS 경로 패턴 | Windows 경로 패턴 | 기본 보존 기준 (TTL) |
| :--- | :--- | :--- | :--- |
| **Chromium / Electron 클론 및 임시 폴더** | `$DARWIN_USER_DIR/X/*.code_sign_clone/*` | `%TEMP%\scoped_dir*`, `chrome_BITS_*`, `chrome_drag*` | **180분 경과** |
| **빌드 및 브라우저 자동화 파이프라인** | `$DARWIN_USER_DIR/T/XcodeDistPipeline.*`, `scoped_dir*` | `%TEMP%\playwright*`, `puppeteer_dev_chrome_profile-*` | **1일 경과** |
| **테스트 및 프로파일링 산출물** | `$DARWIN_USER_DIR/C/com.apple.dt.Instruments`, `$DARWIN_USER_DIR/T/pytest-of-$USER` | `%TEMP%\pytest-of-%USERNAME%` | **3일 경과** |
| **코딩 에이전트 시각화 캐시** | `~/.codex/visualizations/*` | `%USERPROFILE%\.codex\visualizations\*` | **3일 경과** |

> [!NOTE]
> 사용자 계정(`$USER`, `%USERNAME%`) 및 OS별 임시 디렉터리 경로(`getconf DARWIN_USER_DIR`, `%TEMP%`)는 실행 시점에 동적으로 감지되므로 어떤 PC에서도 코드 수정 없이 그대로 작동합니다.

---

## 빠른 시작 (Quick Start)

### macOS (`bash` + `LaunchAgent`)

```bash
git clone https://github.com/cskwork/disk-guard.git
cd disk-guard
./install.sh
```

| 항목 | 경로 및 설정값 |
| :--- | :--- |
| **설치 스크립트** | `~/.local/bin/disk-guard.sh` |
| **LaunchAgent 설정** | `~/Library/LaunchAgents/com.disk-guard.agent.plist` |
| **작동 스케줄** | 로그인 시 1회(`RunAtLoad`) + **매일 04:00** |
| **실행 로그** | `~/Library/Logs/disk-guard.log` |

<details>
<summary><strong>macOS 미리보기(--dry-run), 수동 실행 및 삭제 방법</strong></summary>

```bash
# 실제 삭제 없이 정리 대상만 미리 확인
~/.local/bin/disk-guard.sh --dry-run

# 즉시 정리 실행
~/.local/bin/disk-guard.sh

# LaunchAgent 등록 상태 확인
launchctl list | grep com.disk-guard.agent

# 스케줄 및 스크립트 제거
./uninstall.sh
```

</details>

---

### Windows (`PowerShell` + `Scheduled Task`)

**PowerShell**에서 실행합니다 (관리자 권한 불필요):

```powershell
git clone https://github.com/cskwork/disk-guard.git
cd disk-guard
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

| 항목 | 경로 및 설정값 |
| :--- | :--- |
| **설치 스크립트** | `%LOCALAPPDATA%\disk-guard\disk-guard.ps1` |
| **작업 스케줄러** | `DiskGuard-Daily` (매일 **04:00**) + `DiskGuard-Logon` (로그온 시) |
| **실행 로그** | `%LOCALAPPDATA%\disk-guard\disk-guard.log` |

<details>
<summary><strong>Windows 미리보기(-DryRun), 수동 실행 및 삭제 방법</strong></summary>

```powershell
# 실제 삭제 없이 정리 대상만 미리 확인
powershell -ExecutionPolicy Bypass -File "$env:LOCALAPPDATA\disk-guard\disk-guard.ps1" -DryRun

# 즉시 정리 실행
powershell -ExecutionPolicy Bypass -File "$env:LOCALAPPDATA\disk-guard\disk-guard.ps1"

# 등록된 작업 스케줄 확인
schtasks /Query /TN DiskGuard-Daily

# 스케줄 및 스크립트 제거
powershell -ExecutionPolicy Bypass -File .\uninstall.ps1
```

</details>

---

## 설정 및 환경변수 (Configuration)

스크립트 수정 없이 CLI 플래그 또는 환경변수로 보존 기간을 조정할 수 있습니다.

| 환경변수 | macOS 플래그 | Windows 플래그 | 기본값 | 설명 |
| :--- | :--- | :--- | :--- | :--- |
| `DISK_GUARD_CLONE_TTL_MINUTES` | `--clone-ttl-minutes N` | `-CloneTtlMinutes N` | `180` | Chromium `code_sign_clone` / `scoped_dir*` 삭제 기준 시간(분) |
| `DISK_GUARD_PIPELINE_TTL_DAYS` | `--pipeline-ttl-days N` | `-PipelineTtlDays N` | `1` | 빌드·브라우저 파이프라인 임시 폴더 삭제 기준(일) |
| `DISK_GUARD_ARTIFACT_TTL_DAYS` | `--artifact-ttl-days N` | `-ArtifactTtlDays N` | `3` | `pytest`, `Instruments`, `.codex/visualizations` 삭제 기준(일) |
| `DISK_GUARD_EXTRA_PATHS` | *(환경변수 전용, `:` 구분)* | *(환경변수 전용, `;` 구분)* | *(없음)* | `ARTIFACT_TTL_DAYS` 기준으로 함께 정리할 추가 디렉터리 목록 |
| `DISK_GUARD_HOUR` / `DISK_GUARD_TIME` | `DISK_GUARD_HOUR=4` | `-DailyTime "04:00"` | `04:00` | 설치 시 등록할 일일 자동 실행 시각 |

---

## 프로젝트 구조

```text
disk-guard/
├── install.sh              # macOS 설치 엔트리포인트
├── uninstall.sh            # macOS 제거 엔트리포인트
├── install.ps1             # Windows 설치 엔트리포인트
├── uninstall.ps1           # Windows 제거 엔트리포인트
├── macos/
│   ├── disk-guard.sh       # macOS 정리 스크립트 (bash)
│   ├── install.sh          # LaunchAgent 생성 및 등록
│   └── uninstall.sh        # LaunchAgent 해제 및 삭제
├── windows/
│   ├── disk-guard.ps1      # Windows 정리 스크립트 (PowerShell)
│   ├── install.ps1         # 작업 스케줄러 등록 (schtasks.exe)
│   └── uninstall.ps1       # 작업 스케줄러 해제 및 삭제
├── tests/
│   └── smoke_test.sh       # 격리된 임시 디렉터리 기반 스모크 테스트
└── docs/
    └── index.html          # 프로젝트 랜딩 페이지 (GitHub Pages)
```

## 테스트

macOS/Linux 환경에서 격리된 스모크 테스트를 실행합니다:

```bash
./tests/smoke_test.sh
```

## 라이선스

[MIT License](./LICENSE)에 따라 배포됩니다.
