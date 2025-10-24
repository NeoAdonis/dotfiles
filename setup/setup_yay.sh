#!/usr/bin/env bash

set -euo pipefail

# For security, yay should not be built as root
if [ $EUID -eq 0 ]; then
	echo "error: this script must not be run as root" >&2
	exit 1
fi

echo "Installing tools to build yay..."
sudo pacman -S --needed --noconfirm base-devel git go

echo "Cloning and building yay..."
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -ic
cd ..
rm -rf yay
