#!/usr/bin/env bash

set -euo pipefail

# Install desktop packages
./install-from-file.sh packages_desktop.txt

# Set up GTK dark mode
if [ -n "$DISPLAY" ]; then
	gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
fi
