#!/bin/bash
# Removes yubikey-touch-notification. Pass --purge to also delete the config.
set -euo pipefail

LABEL="io.github.armin-x86.yubikey-touch-notification"
BIN_DIR="$HOME/.local/bin"
CONFIG_DIR="$HOME/.config/yubikey-touch-notification"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
LOG="$HOME/Library/Logs/yubikey-touch-notification.log"

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
rm -f "$PLIST" "$BIN_DIR/yubikey-touch-notify" "$BIN_DIR/yknotify" "$LOG"

if [[ "${1:-}" == "--purge" ]]; then
  rm -rf "$CONFIG_DIR"
  echo "Removed yubikey-touch-notification and its config."
else
  echo "Removed yubikey-touch-notification. Config kept at $CONFIG_DIR (use --purge to delete it)."
fi
