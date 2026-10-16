#!/bin/bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_BASE="$(mktemp -d)"
trap 'rm -rf "$TMP_BASE"' EXIT

mkdir -p "$TMP_BASE/var/X/com.google.Chrome.code_sign_clone/old_clone"
mkdir -p "$TMP_BASE/var/X/com.google.Chrome.code_sign_clone/fresh_clone"
mkdir -p "$TMP_BASE/var/T/pytest-of-testuser/old_run"
mkdir -p "$TMP_BASE/var/T/XcodeDistPipeline.old"
mkdir -p "$TMP_BASE/home/.codex/visualizations"
touch "$TMP_BASE/home/.codex/visualizations/old.png"

# Backdate old entries by 5 days
touch -t 202001010000 "$TMP_BASE/var/X/com.google.Chrome.code_sign_clone/old_clone"
touch -t 202001010000 "$TMP_BASE/var/T/pytest-of-testuser/old_run"
touch -t 202001010000 "$TMP_BASE/var/T/XcodeDistPipeline.old"
touch -t 202001010000 "$TMP_BASE/home/.codex/visualizations/old.png"

# Run dry-run with overridden HOME and TMPDIR
DRY_OUTPUT="$(USER=testuser HOME="$TMP_BASE/home" TMPDIR="$TMP_BASE/var/T" bash "$REPO_DIR/macos/disk-guard.sh" --dry-run)"
echo "$DRY_OUTPUT"

[[ -d "$TMP_BASE/var/X/com.google.Chrome.code_sign_clone/old_clone" ]] || { echo "FAIL: dry-run deleted old_clone"; exit 1; }

# Run live cleanup (in fake HOME/TMPDIR) with mock getconf so DARWIN_USER_DIR falls back to TMPDIR/..
PATH_MOCK="$TMP_BASE/mockbin"
mkdir -p "$PATH_MOCK"
cat > "$PATH_MOCK/getconf" <<'EOF'
#!/bin/bash
exit 1
EOF
chmod +x "$PATH_MOCK/getconf"

PATH="$PATH_MOCK:$PATH" USER=testuser HOME="$TMP_BASE/home" TMPDIR="$TMP_BASE/var/T" bash "$REPO_DIR/macos/disk-guard.sh"

[[ ! -d "$TMP_BASE/var/X/com.google.Chrome.code_sign_clone/old_clone" ]] || { echo "FAIL: old_clone not deleted"; exit 1; }
[[ -d "$TMP_BASE/var/X/com.google.Chrome.code_sign_clone/fresh_clone" ]] || { echo "FAIL: fresh_clone was deleted"; exit 1; }
[[ ! -d "$TMP_BASE/var/T/XcodeDistPipeline.old" ]] || { echo "FAIL: XcodeDistPipeline.old not deleted"; exit 1; }
[[ ! -f "$TMP_BASE/home/.codex/visualizations/old.png" ]] || { echo "FAIL: old.png not deleted"; exit 1; }

echo "PASS: all smoke tests succeeded"
