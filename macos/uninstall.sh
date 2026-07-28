#!/bin/bash
# Remove ProxyToggle.app, its login item and the privileged helper it installed.
set -euo pipefail

APP="${1:-$HOME/Applications/ProxyToggle.app}"
AGENT="$HOME/Library/LaunchAgents/local.proxytoggle.agent.plist"

/usr/bin/pkill -f 'ProxyToggle.app/Contents/MacOS/ProxyToggle' 2>/dev/null || true

# The LaunchAgent fallback would otherwise keep trying to start a deleted app at login.
# An SMAppService registration (macOS 13+) is dropped by the system with the bundle.
if [ -f "$AGENT" ]; then
  /bin/launchctl bootout "gui/$(id -u)/local.proxytoggle.agent" 2>/dev/null || true
  rm -f "$AGENT"
  echo "removed: $AGENT"
fi

rm -rf "$APP"
echo "removed: $APP"

echo "Removing the privileged helper (requires admin):"
sudo rm -f /usr/local/bin/proxyctl /etc/sudoers.d/proxyctl
echo "removed: /usr/local/bin/proxyctl, /etc/sudoers.d/proxyctl"
