#!/bin/bash
# Installs yubikey-touch-notification on macOS.
# Usage: curl -fsSL https://raw.githubusercontent.com/armin-x86/yubikey-touch-notification/main/install.sh | bash
set -euo pipefail

REPO="armin-x86/yubikey-touch-notification"
REF="${YTN_REF:-main}"
# Pinned so every install builds the same reviewed upstream code.
YKNOTIFY_MODULE="github.com/noperator/yknotify@v0.0.0-20260324103239-0c773bdadedb"
MIN_GO_MINOR=21

LABEL="io.github.armin-x86.yubikey-touch-notification"
BIN_DIR="$HOME/.local/bin"
CONFIG_DIR="$HOME/.config/yubikey-touch-notification"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
LOG="$HOME/Library/Logs/yubikey-touch-notification.log"

info() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mwarning:\033[0m %s\n' "$*" >&2; }
die() { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

[[ "$(uname -s)" == "Darwin" ]] || die "This installer supports macOS only."

SCRIPT_DIR=""
if [[ -n "${BASH_SOURCE[0]:-}" && -f "${BASH_SOURCE[0]}" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

# Uses the local clone when run from one, otherwise downloads from GitHub.
fetch() {
  local path="$1" dest="$2"
  if [[ -n "$SCRIPT_DIR" && -f "$SCRIPT_DIR/$path" ]]; then
    cp "$SCRIPT_DIR/$path" "$dest"
  else
    curl -fsSL "https://raw.githubusercontent.com/$REPO/$REF/$path" -o "$dest"
  fi
}

go_is_recent() {
  local minor
  minor="$("$1" env GOVERSION 2>/dev/null | sed -nE 's/^go1\.([0-9]+).*/\1/p')"
  [[ -n "$minor" ]] && (( minor >= MIN_GO_MINOR ))
}

find_go() {
  local candidate
  for candidate in "$(command -v go 2>/dev/null || true)" /opt/homebrew/bin/go /usr/local/bin/go; do
    if [[ -n "$candidate" && -x "$candidate" ]] && go_is_recent "$candidate"; then
      echo "$candidate"
      return
    fi
  done
  command -v brew >/dev/null 2>&1 || die "Go 1.$MIN_GO_MINOR+ is required. Install it from https://go.dev/dl/ or install Homebrew, then rerun."
  info "Installing Go with Homebrew (needed once to build yknotify)"
  brew install go >&2
  candidate="$(brew --prefix)/bin/go"
  go_is_recent "$candidate" || die "Go at $candidate is older than 1.$MIN_GO_MINOR."
  echo "$candidate"
}

if pgrep -f yknotify >/dev/null && ! launchctl print "gui/$(id -u)/$LABEL" >/dev/null 2>&1; then
  warn "Another yknotify process is already running. You may hear double alerts."
fi

mkdir -p "$BIN_DIR" "$CONFIG_DIR" "$(dirname "$PLIST")" "$(dirname "$LOG")"

GO="$(find_go)"
info "Building yknotify with $("$GO" env GOVERSION)"
GOBIN="$BIN_DIR" "$GO" install "$YKNOTIFY_MODULE"

info "Installing notifier to $BIN_DIR/yubikey-touch-notify"
fetch bin/yubikey-touch-notify "$BIN_DIR/yubikey-touch-notify"
chmod +x "$BIN_DIR/yubikey-touch-notify"

if [[ -f "$CONFIG_DIR/config" ]]; then
  info "Keeping existing config at $CONFIG_DIR/config"
else
  info "Writing default config to $CONFIG_DIR/config"
  fetch config.example "$CONFIG_DIR/config"
fi

info "Installing LaunchAgent $PLIST"
cat > "$PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>$BIN_DIR/yubikey-touch-notify</string>
  </array>
  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key>
    <string>/usr/bin:/bin:/usr/sbin:/sbin</string>
  </dict>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>StandardOutPath</key>
  <string>$LOG</string>
  <key>StandardErrorPath</key>
  <string>$LOG</string>
</dict>
</plist>
PLIST
plutil -lint -s "$PLIST"

DOMAIN="gui/$(id -u)"
launchctl bootout "$DOMAIN/$LABEL" 2>/dev/null || true
# A label disabled with `launchctl disable` refuses to bootstrap, even from a fresh plist.
launchctl enable "$DOMAIN/$LABEL"
# bootout finishes asynchronously, so an immediate bootstrap can fail.
for attempt in 1 2 3 4 5; do
  if launchctl bootstrap "$DOMAIN" "$PLIST" 2>/dev/null; then
    break
  fi
  (( attempt == 5 )) && die "Could not load the LaunchAgent. Try: launchctl bootstrap $DOMAIN $PLIST"
  sleep 1
done

info "Done. Playing a test alert."
"$BIN_DIR/yubikey-touch-notify" --test || true

cat <<DONE

yubikey-touch-notification is running and starts automatically at login.
  Config:  $CONFIG_DIR/config
  Logs:    $LOG
  Test:    $BIN_DIR/yubikey-touch-notify --test
DONE
