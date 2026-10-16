#!/bin/bash
set -euo pipefail

DRY_RUN=0
CLONE_TTL_MINUTES="${DISK_GUARD_CLONE_TTL_MINUTES:-180}"
ARTIFACT_TTL_DAYS="${DISK_GUARD_ARTIFACT_TTL_DAYS:-3}"
PIPELINE_TTL_DAYS="${DISK_GUARD_PIPELINE_TTL_DAYS:-1}"
EXTRA_PATHS="${DISK_GUARD_EXTRA_PATHS:-}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run|-n)
      DRY_RUN=1
      shift
      ;;
    --clone-ttl-minutes)
      CLONE_TTL_MINUTES="$2"
      shift 2
      ;;
    --artifact-ttl-days)
      ARTIFACT_TTL_DAYS="$2"
      shift 2
      ;;
    --pipeline-ttl-days)
      PIPELINE_TTL_DAYS="$2"
      shift 2
      ;;
    --help|-h)
      cat <<'EOF'
Usage: disk-guard.sh [--dry-run|-n] [--clone-ttl-minutes N] [--artifact-ttl-days N] [--pipeline-ttl-days N]

Cleans stale Chromium code_sign_clone bundles, Xcode/Instruments/pytest temp artifacts,
and agent visualization caches on macOS.
EOF
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

CURRENT_USER="${USER:-$(id -un)}"
VAR_USER_DIR="$(getconf DARWIN_USER_DIR 2>/dev/null | sed 's:/0/*$::' || true)"
if [[ -z "$VAR_USER_DIR" || ! -d "$VAR_USER_DIR" ]]; then
  if [[ -n "${TMPDIR:-}" && -d "${TMPDIR}" ]]; then
    VAR_USER_DIR="$(cd "${TMPDIR}/.." && pwd)"
  fi
fi

get_free_space() {
  if [[ -d /System/Volumes/Data ]]; then
    df -h /System/Volumes/Data | awk 'NR==2 {print $4}'
  else
    df -h / | awk 'NR==2 {print $4}'
  fi
}

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

purge_children_by_minutes() {
  local dir="$1"
  local mins="$2"
  [[ -d "$dir" ]] || return 0
  if [[ "$DRY_RUN" -eq 1 ]]; then
    find "$dir" -mindepth 1 -maxdepth 1 -mmin +"$mins" -print 2>/dev/null | sed 's/^/  [dry-run] delete /' || true
  else
    find "$dir" -mindepth 1 -maxdepth 1 -mmin +"$mins" -exec find {} -delete \; 2>/dev/null || true
  fi
}

purge_tree_by_days() {
  local dir="$1"
  local days="$2"
  [[ -d "$dir" ]] || return 0
  if [[ "$DRY_RUN" -eq 1 ]]; then
    find "$dir" -mindepth 1 -mtime +"$days" -print 2>/dev/null | sed 's/^/  [dry-run] delete /' || true
  else
    find "$dir" -mindepth 1 -mtime +"$days" -delete 2>/dev/null || true
  fi
}

log "disk-guard start (user: $CURRENT_USER, dry-run: $DRY_RUN, free: $(get_free_space))"

if [[ -n "$VAR_USER_DIR" && -d "$VAR_USER_DIR" ]]; then
  # 1. Stale Chromium / Electron code_sign_clone directories
  if [[ -d "$VAR_USER_DIR/X" ]]; then
    while IFS= read -r -d '' clone_root; do
      purge_children_by_minutes "$clone_root" "$CLONE_TTL_MINUTES"
    done < <(find "$VAR_USER_DIR/X" -mindepth 1 -maxdepth 1 -type d -name "*.code_sign_clone" -print0 2>/dev/null || true)
  fi

  # 2. Stale Instruments & pytest temp directories
  for tmp_target in \
    "$VAR_USER_DIR/C/com.apple.dt.Instruments" \
    "$VAR_USER_DIR/T/pytest-of-$CURRENT_USER"; do
    purge_tree_by_days "$tmp_target" "$ARTIFACT_TTL_DAYS"
  done

  # 3. Stale XcodeDistPipeline and transient build folders in T/
  if [[ -d "$VAR_USER_DIR/T" ]]; then
    if [[ "$DRY_RUN" -eq 1 ]]; then
      find "$VAR_USER_DIR/T" -mindepth 1 -maxdepth 1 \( -name "XcodeDistPipeline.*" -o -name "scoped_dir*" \) -mtime +"$PIPELINE_TTL_DAYS" -print 2>/dev/null | sed 's/^/  [dry-run] delete /' || true
    else
      find "$VAR_USER_DIR/T" -mindepth 1 -maxdepth 1 \( -name "XcodeDistPipeline.*" -o -name "scoped_dir*" \) -mtime +"$PIPELINE_TTL_DAYS" -exec find {} -delete \; 2>/dev/null || true
    fi
  fi
fi

# 4. Stale Codex visualizations
if [[ -d "$HOME/.codex/visualizations" ]]; then
  purge_tree_by_days "$HOME/.codex/visualizations" "$ARTIFACT_TTL_DAYS"
fi

# 5. User-defined extra colon-separated directories (cleaned by ARTIFACT_TTL_DAYS)
if [[ -n "$EXTRA_PATHS" ]]; then
  IFS=':' read -r -a extra_arr <<< "$EXTRA_PATHS"
  for extra_dir in "${extra_arr[@]}"; do
    [[ -n "$extra_dir" ]] && purge_tree_by_days "$extra_dir" "$ARTIFACT_TTL_DAYS"
  done
fi

log "disk-guard done  (free: $(get_free_space))"
