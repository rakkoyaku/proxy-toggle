#!/bin/bash
# Remove ProxyToggle.app and the privileged helper it installed.
set -euo pipefail

APP="${1:-$HOME/Applications/ProxyToggle.app}"

/usr/bin/pkill -f 'ProxyToggle.app/Contents/MacOS/ProxyToggle' 2>/dev/null || true
rm -rf "$APP"
echo "removed: $APP"

echo "Removing the privileged helper (requires admin):"
sudo rm -f /usr/local/bin/proxyctl /etc/sudoers.d/proxyctl
echo "removed: /usr/local/bin/proxyctl, /etc/sudoers.d/proxyctl"
