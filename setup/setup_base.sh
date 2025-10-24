#!/usr/bin/env bash

set -euo pipefail

if [ $EUID -eq 0 ]; then
	echo "error: this script must not be run as root" >&2
	exit 1
fi

# Install base packages
./install-from-file.sh packages_base.txt

# Set up Rust toolchain
rustup default stable

# Rebuild bat cache to include new themes
bat cache --build

# Log in with GitHub CLI (if not already logged in)
if ! gh auth status >/dev/null 2>&1; then
	gh auth login
fi

# Reload zsh configuration
if [[ -n "${ZSH_VERSION:-}" ]]; then
	source ~/.zshrc
fi
