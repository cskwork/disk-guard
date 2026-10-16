#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LABEL="${DISK_GUARD_LABEL:-com.disk-guard.agent}"
HOUR="${DISK_GUARD_HOUR:-4}"
MINUTE="${DISK_GUARD_MINUTE:-0}"
INSTALL_BIN_DIR="${HOME}/.local/bin"
INSTALL_SCRIPT="${INSTALL_BIN_DIR}/disk-guard.sh"
LAUNCH_AGENTS_DIR="${HOME}/Library/LaunchAgents"
PLIST_PATH="${LAUNCH_AGENTS_DIR}/${LABEL}.plist"
LOG_PATH="${HOME}/Library/Logs/disk-guard.log"

mkdir -p "$INSTALL_BIN_DIR" "$LAUNCH_AGENTS_DIR" "${HOME}/Library/Logs"
cp "$SCRIPT_DIR/disk-guard.sh" "$INSTALL_SCRIPT"
chmod +x "$INSTALL_SCRIPT"

# Unload legacy or existing labels cleanly
CURRENT_USER="${USER:-$(id -un)}"
for old_label in "com.${CURRENT_USER}.disk-guard" "$LABEL"; do
  old_plist="${LAUNCH_AGENTS_DIR}/${old_label}.plist"
  if [[ -f "$old_plist" ]]; then
    launchctl bootout "gui/$(id -u)" "$old_plist" 2>/dev/null || launchctl unload "$old_plist" 2>/dev/null || true
    if [[ "$old_label" != "$LABEL" ]]; then
      rm -f "$old_plist"
    fi
  fi
done

cat > "$PLIST_PATH" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>${LABEL}</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>${INSTALL_SCRIPT}</string>
  </array>
  <key>StartCalendarInterval</key>
  <dict>
    <key>Hour</key>
    <integer>${HOUR}</integer>
    <key>Minute</key>
    <integer>${MINUTE}</integer>
  </dict>
  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key>
    <string>${HOME}/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
    <key>HOME</key>
    <string>${HOME}</string>
  </dict>
  <key>StandardOutPath</key>
  <string>${LOG_PATH}</string>
  <key>StandardErrorPath</key>
  <string>${LOG_PATH}</string>
  <key>RunAtLoad</key>
  <true/>
</dict>
</plist>
EOF

launchctl bootstrap "gui/$(id -u)" "$PLIST_PATH" 2>/dev/null || launchctl load "$PLIST_PATH"

echo "Installed disk-guard:"
echo "  Script:   $INSTALL_SCRIPT"
echo "  Schedule: $PLIST_PATH (daily at $(printf '%02d:%02d' "$HOUR" "$MINUTE") + on login)"
echo "  Log:      $LOG_PATH"
