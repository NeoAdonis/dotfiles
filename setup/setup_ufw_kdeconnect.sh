#!/usr/bin/env bash

set -euo pipefail

if [ $EUID -ne 0 ]; then
	echo "This script must be run as root" >&2
	exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Set up KDE Connect
if command -v ufw >/dev/null 2>&1; then
	install -m 644 -o root -g root "$SCRIPT_DIR/ufw__applications.d__kdeconnect" /etc/ufw/applications.d/kdeconnect
	ufw app update "KDE Connect"
	ufw allow "KDE Connect"
fi
