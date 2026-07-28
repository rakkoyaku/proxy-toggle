#!/bin/bash
# <xbar.title>Proxy Switch</xbar.title>
# <xbar.version>v1.0</xbar.version>
# <xbar.desc>Toggle the HTTP/HTTPS proxy of the active network service</xbar.desc>
# <swiftbar.hideAbout>true</swiftbar.hideAbout>
# <swiftbar.hideRunInTerminal>true</swiftbar.hideRunInTerminal>
# <swiftbar.hideLastUpdated>true</swiftbar.hideLastUpdated>
# <swiftbar.hideSwiftBar>true</swiftbar.hideSwiftBar>
#
# Requires scripts/proxyctl installed at /usr/local/bin/proxyctl — see the README.

export PATH=/usr/local/bin:/usr/sbin:/usr/bin:/bin

IFS='|' read -r SVC HE HS HP SE SS SP < <(/usr/local/bin/proxyctl status)

if [ "$HE" = "Yes" ] && [ "$SE" = "Yes" ]; then
  echo "● PROXY | color=#30d158 font=Menlo size=13"; NEXT=off
elif [ "$HE" = "No" ] && [ "$SE" = "No" ]; then
  echo "○ PROXY | color=#8e8e93 font=Menlo size=13"; NEXT=on
else
  echo "◐ PROXY | color=#ff9f0a font=Menlo size=13"; NEXT=on
fi

echo "---"
echo "ネットワーク: $SVC | color=gray"
echo "HTTP   $HS:$HP  [$HE] | font=Menlo"
echo "HTTPS  $SS:$SP  [$SE] | font=Menlo"
echo "---"
echo "Turn $(echo "$NEXT" | tr '[:lower:]' '[:upper:]') | bash=/usr/bin/sudo param1=-n param2=/usr/local/bin/proxyctl param3=$NEXT terminal=false refresh=true"
echo "ネットワーク設定を開く… | bash=/usr/bin/open param1=x-apple.systempreferences:com.apple.Network-Settings.extension terminal=false"
echo "Refresh | refresh=true"
