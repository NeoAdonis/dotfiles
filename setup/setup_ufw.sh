#!/usr/bin/env bash

set -euo pipefail

if [ $EUID -ne 0 ]; then
	echo "This script must be run as root" >&2
	exit 1
fi

# Set up ufw
if command -v ufw >/dev/null 2>&1; then
	# Set up ufw default rules
	ufw default deny incoming
	ufw default allow outgoing
	ufw allow from 192.168.0.0/22
	ufw allow qBittorrent
	ufw limit SSH
	ufw allow WWW
	ufw allow "WWW Secure"
	# Enable ufw
	ufw --force enable
fi
