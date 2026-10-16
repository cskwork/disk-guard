#!/bin/bash
set -euo pipefail

LABEL="${DISK_GUARD_LABEL:-com.disk-guard.agent}"
PLIST_PATH="${HOME}/Library/LaunchAgents/${LABEL}.plist"
INSTALL_SCRIPT="${HOME}/.local/bin/disk-guard.sh"

if [[ -f "$PLIST_PATH" ]]; then
  launchctl bootout "gui/$(id -u)" "$PLIST_PATH" 2>/dev/null || launchctl unload "$PLIST_PATH" 2>/dev/null || true
  rm -f "$PLIST_PATH"
  echo "Removed LaunchAgent: $PLIST_PATH"
fi

if [[ -f "$INSTALL_SCRIPT" ]]; then
  rm -f "$INSTALL_SCRIPT"
  echo "Removed script: $INSTALL_SCRIPT"
fi
