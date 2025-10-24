#!/usr/bin/env bash

# To run this script, use:
# curl -fsSL https://example.com/path/to/setup_1st_run.sh | sudo bash -s -- [new_username] [shell=zsh|bash|fish]

set -euo pipefail

# Check for sudo/root
if [ $EUID -ne 0 ]; then
	echo "error: this script must be run as root" >&2
	exit 1
fi

# Check for pacman
if ! command -v pacman &>/dev/null; then
	echo "error: this script is intended for Arch Linux systems with pacman" >&2
	exit 1
fi

# Detect WSL
if [ -f /proc/sys/fs/binfmt_misc/WSLInterop ]; then
	WSL=1
fi

NEW_USER=${1:-developer}
NEW_USER_SHELL=${2:-zsh}

echo "This script will:"
echo "- Set up locale to en_US.UTF-8"
echo "- Enable color and progress bar in pacman"
echo "- Optimize makepkg.conf"
echo "- Update package database and upgrade system"
echo "- Install essential packages"
echo "- Create user account '$NEW_USER' with shell '$NEW_USER_SHELL'"
if [ "${WSL:-0}" -eq 1 ]; then
	echo "- Set up WSL configuration, including setting default user to '$NEW_USER'"
fi
echo
read -p "Press Enter to continue or Ctrl+C to abort..."

# Set up locale
echo "Generating locale..."
echo 'LANG=en_US.UTF-8' >>/etc/locale.conf
if grep -q '^#en_US.UTF-8 UTF-8' /etc/locale.gen; then
	sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
elif ! grep -q '^en_US.UTF-8 UTF-8' /etc/locale.gen; then
	echo 'en_US.UTF-8 UTF-8' >>/etc/locale.gen
fi
locale-gen
if [ $? -eq 0 ]; then
	echo "Generated locale."
else
	echo "warning: locale-gen failed" >&2
fi

# Enable color and progress bar in pacman
if [ -f /etc/pacman.conf ]; then
	if grep -qE '^\s*#\s*Color' /etc/pacman.conf; then
		sed -i 's/^\s*#\s*Color/Color/' /etc/pacman.conf
		echo "Enabled color in /etc/pacman.conf"
	fi
	if grep -qE '^\s*NoProgressBar' /etc/pacman.conf; then
		sed -i 's/^\s*NoProgressBar/#NoProgressBar/' /etc/pacman.conf
		echo "Enabled progress bar in /etc/pacman.conf"
	fi
fi

# Set up makepkg.conf optimizations
if [ -f /etc/makepkg.conf ]; then
	# Disable debug packages
	if grep -qE '^\s*OPTIONS=.*[^!]debug' /etc/makepkg.conf; then
		sed -i 's/^\(\s*OPTIONS=.*\)debug/\1!debug/' /etc/makepkg.conf
		echo "Disabled debug packages in /etc/makepkg.conf"
	fi

	# Disable LTO
	if grep -qE '^\s*OPTIONS=.*[^!]lto' /etc/makepkg.conf; then
		sed -i 's/^\(\s*OPTIONS=.*\)lto/\1!lto/' /etc/makepkg.conf
		echo "Disabled LTO in /etc/makepkg.conf"
	fi

	# Enable -march=native
	if grep -qE '^\s*CFLAGS=.*-march=[^ ]+' /etc/makepkg.conf && ! grep -qE '^\s*CFLAGS=.*-march=native' /etc/makepkg.conf; then
		sed -i 's/^\(\s*CFLAGS=.*\)-march=[^ ]*/\1-march=native/' /etc/makepkg.conf
		echo "Set -march=native in /etc/makepkg.conf"
	fi

	# Enable target-cpu=native for rust
	if [ -f /etc/makepkg.conf.d/rust.conf ]; then
		if grep -qE '^\s*RUSTFLAGS=' /etc/makepkg.conf.d/rust.conf && ! grep -qE '^\s*RUSTFLAGS=.*-C target-cpu=native' /etc/makepkg.conf.d/rust.conf; then
			if grep -qE '^\s*RUSTFLAGS=.*-C target-cpu=[^ "]+' /etc/makepkg.conf.d/rust.conf; then
				sed -i 's/^\(\s*RUSTFLAGS=.*\)-C target-cpu=[^ "]*/\1-C target-cpu=native/' /etc/makepkg.conf.d/rust.conf
			else
				sed -i 's/^\(\s*RUSTFLAGS=.*\)"/\1 -C target-cpu=native"/' /etc/makepkg.conf.d/rust.conf
			fi
			echo "Set -C target-cpu=native in /etc/makepkg.conf.d/rust.conf"
		fi
	fi
fi

# Update package database and upgrade system
echo "Updating package database and upgrading system..."
pacman -Syu --noconfirm
if [ $? -ne 0 ]; then
	echo "error: failed to update/upgrade packages" >&2
	exit 1
fi

# Install essential packages:
# - base-devel: for building AUR packages
# - git: for cloning repositories
# - sudo: for privilege escalation
echo "Installing essential packages..."
pacman -S --needed --noconfirm base-devel git sudo

# Install shell
echo "Installing shell: $NEW_USER_SHELL..."
case "$NEW_USER_SHELL" in
bash)
	# bash is installed by default on Arch Linux
	NEW_USER_SHELL_PATH="/bin/bash"
	;;
zsh)
	pacman -S --needed --noconfirm zsh
	NEW_USER_SHELL_PATH="/bin/zsh"
	;;
fish)
	pacman -S --needed --noconfirm fish
	NEW_USER_SHELL_PATH="/bin/fish"
	;;
*)
	echo "warning: don't know what to do for shell '$NEW_USER_SHELL'. Defaulting to bash." >&2
	NEW_USER_SHELL_PATH="/bin/bash"
	;;
esac

# Create user account
if ! id $NEW_USER &>/dev/null; then
	useradd -m -s $NEW_USER_SHELL_PATH $NEW_USER
	if [ $? -ne 0 ]; then
		echo "error: failed to create user '$NEW_USER'" >&2
		exit 1
	fi
	echo "$NEW_USER ALL=(ALL) NOPASSWD:ALL" >"/etc/sudoers.d/00_$NEW_USER"
fi

# Copy WSL config
if [ "${WSL:-0}" -eq 1 ]; then
	cat >/etc/wsl.conf <<-EOF
		[automount]
		enabled = true
		options = "metadata"
		mountFsTab = false

		[boot]
		systemd = true

		[user]
		default = $NEW_USER
	EOF
	if [ $? -eq 0 ]; then
		echo "Created /etc/wsl.conf"
	else
		echo "warning: failed to create /etc/wsl.conf" >&2
	fi
fi

if [ "${WSL:-0}" -eq 1 ]; then
	echo "Initial complete. Start a new WSL instance to log in as '$NEW_USER'."
else
	echo "Initial setup complete. Proceed to log in as '$NEW_USER'."
fi
echo "You can then install chezmoi ('sudo pacman -S chezmoi') and call 'chezmoi init --apply <chezmoi-repo>' to download setup scripts and dotfiles."
