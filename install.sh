#!/usr/bin/env bash
# install.sh — download and run the nmux installer.
#
# Usage:
#   curl -sSL https://raw.githubusercontent.com/neuralmux/installer/main/install.sh | bash
#   curl -sSL .../install.sh | bash -s -- --channel prerelease
#
# This is a lightweight wrapper. It detects the architecture, downloads the
# installer binary and its published checksum, verifies the two agree, runs the
# installer (passing through any CLI arguments), and removes the binary when
# done.
#
# The checksum is not decoration. This script downloads a program and executes
# it with the operator's privileges; without verification, anything able to
# answer for the download URL is executed. GitHub supplies the file and a
# separate `checksums.txt` from the same release, so a substitution has to
# defeat both at once.
#
# The installer itself is built and released by the nmux repository, from the
# same commit as the package it installs.

set -euo pipefail

REPO="neuralmux/nmux.rs"

# --- Architecture detection ---
ARCH=$(uname -m)
case "$ARCH" in
	x86_64|amd64)  ARCH="amd64"  ;;
	aarch64|arm64) ARCH="arm64"  ;;
	*)
		echo "Unsupported architecture: $ARCH"
		echo "nmux supports linux/amd64 and linux/arm64."
		exit 1
		;;
esac

OS=$(uname -s | tr '[:upper:]' '[:lower:]')
if [[ "$OS" != "linux" ]]; then
	echo "Unsupported OS: $OS"
	echo "nmux-installer supports Linux only."
	exit 1
fi

# --- Download ---
BASE="https://github.com/${REPO}/releases/latest/download"
ASSET="nmux-installer-linux-${ARCH}"

TMP=$(mktemp)
SUMS=$(mktemp)
trap 'rm -f "$TMP" "$SUMS"' EXIT

echo "Downloading nmux-installer for linux/${ARCH}..."
if ! curl -fsSL -o "$TMP" "$BASE/$ASSET"; then
	echo "Download failed: $BASE/$ASSET"
	echo "Check that the binary exists for your architecture."
	exit 1
fi

if ! curl -fsSL -o "$SUMS" "$BASE/checksums.txt"; then
	echo "Could not download checksums.txt from the same release."
	echo "Refusing to run an unverified installer."
	exit 1
fi

# The checksum line names the asset, so match the whole name: a prefix match
# would accept a line for a different file.
expected=$(awk -v want="$ASSET" '$2 == want { print $1 }' "$SUMS")
if [[ -z "$expected" ]]; then
	echo "checksums.txt has no entry for $ASSET — refusing to run it."
	exit 1
fi

actual=$(sha256sum "$TMP" | awk '{print $1}')
if [[ "$expected" != "$actual" ]]; then
	echo "Checksum mismatch for $ASSET:"
	echo "  expected $expected"
	echo "  got      $actual"
	echo "Refusing to run it."
	exit 1
fi
echo "Checksum verified."

chmod +x "$TMP"

# --- Run the installer, passing through all arguments ---
#
# Not `exec`: replacing this shell would skip the EXIT trap, leaving the
# installer binary and the checksums file behind in the temporary directory.
# `set -e` propagates a non-zero status after the trap has run.
"$TMP" "$@"
