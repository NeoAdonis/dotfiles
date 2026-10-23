#!/usr/bin/env bash

# Enables OTP for SSH logins using pam_google_authenticator.so, except from
# the networks allowed in /etc/security/access-local.conf.
# Usage: sudo ./setup_ssh_otp.sh

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
PAM_DIR="/usr/lib/security"
PAM_FILE="/etc/pam.d/sshd"
ACCESS_SRC="$SCRIPT_DIR/etc__security__access-local.conf"
ACCESS_DEST="/etc/security/access-local.conf"
OTP_SRC="$SCRIPT_DIR/etc__ssh__sshd_config.d__20-otp.conf"
OTP_DEST="/etc/ssh/sshd_config.d/20-otp.conf"
PAM_ACCESS_LINE="auth [success=1 default=ignore] pam_access.so accessfile=$ACCESS_DEST"
PAM_OTP_LINE="auth            required        pam_google_authenticator.so"
CIDR_REGEX='^([0-9]{1,3}\.){3}[0-9]{1,3}/([0-9]|[12][0-9]|3[0-2])$'

# Prints the network address of an IPv4 CIDR (e.g. 192.168.4.2/22 -> 192.168.4.0/22).
network_of() {
	local ip=${1%/*} prefix=${1#*/} octets network=() i bits
	IFS=. read -ra octets <<<"$ip"
	for i in 0 1 2 3; do
		bits=$((prefix - 8 * i))
		if ((bits < 0)); then
			bits=0
		elif ((bits > 8)); then
			bits=8
		fi
		network+=($((octets[i] & (256 - 2 ** (8 - bits)))))
	done
	echo "${network[0]}.${network[1]}.${network[2]}.${network[3]}/$prefix"
}

# Check requirements.
if [ ! -f "$PAM_DIR/pam_google_authenticator.so" ]; then
	echo "error: $PAM_DIR/pam_google_authenticator.so not found (install 'libpam-google-authenticator')" >&2
	exit 1
fi
if [ ! -f "$PAM_DIR/pam_access.so" ]; then
	echo "error: $PAM_DIR/pam_access.so not found (install 'pam')" >&2
	exit 1
fi
MISSING_OTP_USERS=()
FIX_PERM_FILES=()
for HOME_DIR in /home/*/; do
	[ -d "$HOME_DIR" ] || continue
	HOME_DIR="${HOME_DIR%/}"
	OTP_FILE="$HOME_DIR/.google_authenticator"
	if [ ! -f "$OTP_FILE" ]; then
		MISSING_OTP_USERS+=("${HOME_DIR##*/}")
	elif [ "$(stat -c '%a %U' "$OTP_FILE")" != "400 $(stat -c '%U' "$HOME_DIR")" ]; then
		FIX_PERM_FILES+=("$OTP_FILE")
	fi
done
for SRC in "$ACCESS_SRC" "$OTP_SRC"; do
	if [ ! -f "$SRC" ]; then
		echo "error: $SRC not found" >&2
		exit 1
	fi
done
if [ ! -f "$PAM_FILE" ]; then
	echo "error: $PAM_FILE not found" >&2
	exit 1
fi
if ! grep -qE '^\s*auth\s' "$PAM_FILE"; then
	echo "error: no 'auth' entries found in $PAM_FILE" >&2
	exit 1
fi

# Ask for the local network.
# Defaults to the one already configured, or else to the default route's interface network.
DEFAULT_NETWORK=""
if [ -f "$ACCESS_DEST" ]; then
	DEFAULT_NETWORK=$(sed -nE 's/^\s*\+\s*:\s*ALL\s*:\s*([0-9./]+)\s*$/\1/p' "$ACCESS_DEST" | head -n 1)
fi
if [ -z "$DEFAULT_NETWORK" ]; then
	DEFAULT_IFACE=$(ip -4 route show default | awk '{ for (i = 1; i < NF; i++) if ($i == "dev") { print $(i + 1); exit } }')
	if [ -n "$DEFAULT_IFACE" ]; then
		DEFAULT_ADDR=$(ip -4 -o addr show dev "$DEFAULT_IFACE" | awk '{ print $4; exit }')
		if [[ $DEFAULT_ADDR =~ $CIDR_REGEX ]]; then
			DEFAULT_NETWORK=$(network_of "$DEFAULT_ADDR")
		fi
	fi
fi
while true; do
	read -rp "Network allowed to log in without OTP${DEFAULT_NETWORK:+ [$DEFAULT_NETWORK]}: " LOCAL_NETWORK </dev/tty
	LOCAL_NETWORK=${LOCAL_NETWORK:-$DEFAULT_NETWORK}
	if [[ $LOCAL_NETWORK =~ $CIDR_REGEX ]]; then
		LOCAL_NETWORK=$(network_of "$LOCAL_NETWORK")
		break
	fi
	echo "Enter an IPv4 network in CIDR notation (e.g. 192.168.1.0/24)." >&2
done
ACCESS_CONTENT=$(sed "s|@LOCAL_NETWORK@|$LOCAL_NETWORK|" "$ACCESS_SRC")

echo
echo "This script will:"
echo "- Install $ACCESS_DEST, allowing logins without OTP from:"
grep -E '^\s*\+' <<<"$ACCESS_CONTENT" | sed 's/^/    /'
echo "- Install $OTP_DEST to enable keyboard-interactive authentication"
echo "- Add the following lines before the first 'auth' entry in $PAM_FILE:"
echo "    $PAM_ACCESS_LINE"
echo "    $PAM_OTP_LINE"
if ((${#FIX_PERM_FILES[@]} > 0)); then
	echo "- Set mode 0400 and the home directory's owner on:"
	for OTP_FILE in "${FIX_PERM_FILES[@]}"; do
		echo "    $OTP_FILE"
	done
fi
echo "- Validate the sshd configuration and reload sshd if it's running"
echo
echo "Users without a ~/.google_authenticator file will not be able to log in from other networks."
if ((${#MISSING_OTP_USERS[@]} > 0)); then
	echo "The following users don't have one yet; run 'google-authenticator' as each of them to create it:"
	for NAME in "${MISSING_OTP_USERS[@]}"; do
		echo "    $NAME"
	done
fi
echo
read -rp "Press Enter to continue or Ctrl+C to abort..." </dev/tty

# Fix secret key file permissions.
for OTP_FILE in "${FIX_PERM_FILES[@]}"; do
	chown "$(stat -c '%U' "$(dirname "$OTP_FILE")"):" "$OTP_FILE"
	chmod 400 "$OTP_FILE"
	echo "Fixed permissions of $OTP_FILE"
done

# Install access file.
if [ -f "$ACCESS_DEST" ]; then
	cp "$ACCESS_DEST" "$ACCESS_DEST.bak"
	echo "Backed up existing $ACCESS_DEST to $ACCESS_DEST.bak"
fi
install -m 644 -o root -g root /dev/stdin "$ACCESS_DEST" <<<"$ACCESS_CONTENT"
echo "Installed $ACCESS_DEST"

# Install sshd config.
mkdir -p "$(dirname "$OTP_DEST")"
if [ -f "$OTP_DEST" ]; then
	cp "$OTP_DEST" "$OTP_DEST.bak"
fi
install -m 644 -o root -g root "$OTP_SRC" "$OTP_DEST"
echo "Installed $OTP_DEST"

restore_otp_conf() {
	if [ -f "$OTP_DEST.bak" ]; then
		mv "$OTP_DEST.bak" "$OTP_DEST"
	else
		rm -f "$OTP_DEST"
	fi
}

# Edit PAM config.
# Any existing entries are removed first, since pam_access must come right before
# pam_google_authenticator for 'success=1' to skip it.
cp "$PAM_FILE" "$PAM_FILE.bak"
if ! awk -v access="$PAM_ACCESS_LINE" -v otp="$PAM_OTP_LINE" '
	/pam_access\.so.*accessfile=\/etc\/security\/access-local\.conf/ { next }
	/pam_google_authenticator\.so/ { next }
	!done && /^[[:space:]]*auth[[:space:]]/ { print access; print otp; done = 1 }
	{ print }
' "$PAM_FILE.bak" >"$PAM_FILE.new" || ! mv "$PAM_FILE.new" "$PAM_FILE"; then
	echo "error: failed to edit $PAM_FILE; restoring previous files" >&2
	rm -f "$PAM_FILE.new"
	mv "$PAM_FILE.bak" "$PAM_FILE"
	restore_otp_conf
	exit 1
fi
echo "Updated $PAM_FILE"

# Validate the configuration.
if ! sshd -t; then
	echo "error: sshd configuration is invalid; restoring previous files" >&2
	mv "$PAM_FILE.bak" "$PAM_FILE"
	restore_otp_conf
	exit 1
fi

rm -f "$PAM_FILE.bak" "$OTP_DEST.bak"

# Reload sshd.
if systemctl is-active --quiet sshd; then
	systemctl reload sshd
	echo "Reloaded sshd"
else
	echo "sshd is not running; the configuration will apply the next time it starts."
fi
echo "Keep your current SSH session open and test logging in from another terminal before closing it."
