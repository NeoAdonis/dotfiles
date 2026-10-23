#!/usr/bin/env bash

# Installs the sshd config files listed in CONFIG_FILES into /etc/ssh/sshd_config.d,
# validates the resulting configuration (restoring the previous files if it's
# invalid) and reloads sshd if it's running.
# Usage: sudo ./setup_ssh.sh

set -euo pipefail

if [ $EUID -ne 0 ]; then
	echo "error: this script must be run as root" >&2
	exit 1
fi

if ! command -v sshd >/dev/null 2>&1; then
	echo "error: sshd is not installed (install 'openssh')" >&2
	exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST_DIR="/etc/ssh/sshd_config.d"

# Config files to install.
# Each etc__ssh__sshd_config.d__<name> maps to /etc/ssh/sshd_config.d/<name>.
CONFIG_FILES=(
	20-deny_root.conf
)

for NAME in "${CONFIG_FILES[@]}"; do
	if [ ! -f "$SCRIPT_DIR/etc__ssh__sshd_config.d__$NAME" ]; then
		echo "error: $SCRIPT_DIR/etc__ssh__sshd_config.d__$NAME not found" >&2
		exit 1
	fi
done

mkdir -p "$DEST_DIR"

INSTALLED=()
for NAME in "${CONFIG_FILES[@]}"; do
	SRC="$SCRIPT_DIR/etc__ssh__sshd_config.d__$NAME"
	DEST="$DEST_DIR/$NAME"
	if [ -f "$DEST" ]; then
		cp "$DEST" "$DEST.bak"
	fi
	install -m 644 -o root -g root "$SRC" "$DEST"
	INSTALLED+=("$DEST")
	echo "Installed $DEST"
done

# Validate the configuration.
if ! sshd -t; then
	echo "error: sshd configuration is invalid; restoring previous files" >&2
	for DEST in "${INSTALLED[@]}"; do
		if [ -f "$DEST.bak" ]; then
			mv "$DEST.bak" "$DEST"
		else
			rm -f "$DEST"
		fi
	done
	exit 1
fi

for DEST in "${INSTALLED[@]}"; do
	rm -f "$DEST.bak"
done

# Reload sshd if it's running.
if systemctl is-active --quiet sshd; then
	systemctl reload sshd
	echo "Reloaded sshd"
else
	echo "sshd is not running; the configuration will apply the next time it starts."
fi
