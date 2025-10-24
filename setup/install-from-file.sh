#!/usr/bin/env bash

set -euo pipefail

FILE="${1:-packages.txt}"

if [[ ! -f "$FILE" ]]; then
	echo "error: '$FILE' not found." >&2
	exit 1
fi

mapfile -t PKGS < <(sed 's/#.*//' "$FILE" | tr -d '\r' | awk 'NF')

if ((${#PKGS[@]} == 0)); then
	echo "No packages listed in $FILE."
	exit 0
fi

yay -S --needed "${PKGS[@]}"
