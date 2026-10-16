#!/usr/bin/env bash

set -euo pipefail

if [ $EUID -ne 0 ]; then
	echo "This script must be run as root" >&2
	exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Set up Jellyfin
if command -v ufw >/dev/null 2>&1; then
	install -m 644 -o root -g root "$SCRIPT_DIR/ufw__applications.d__jellyfin" /etc/ufw/applications.d/jellyfin
	ufw app update "Jellyfin"
	ufw allow "Jellyfin"
fi
