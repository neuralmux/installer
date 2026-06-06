#!/usr/bin/env bash
# install.sh — Download and run the nmux Linux installer.
#
# Usage:
#   curl -sSL https://raw.githubusercontent.com/neuralmux/installer/main/install.sh | bash
#   curl -sSL https://raw.githubusercontent.com/neuralmux/installer/main/install.sh | bash -s -- --channel nightly
#
# This is a lightweight wrapper. It detects the architecture, downloads the
# installer binary from GitHub Releases, execs it (passing through any CLI
# arguments), and removes the binary when done.

set -euo pipefail

REPO="neuralmux/installer"

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

# --- Download installer binary ---
URL="https://github.com/${REPO}/releases/latest/download/nmux-installer-linux-${ARCH}"
TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT

echo "Downloading nmux-installer for linux/${ARCH}..."
if ! curl -fsSL -o "$TMP" "$URL"; then
	echo "Download failed: $URL"
	echo "Check that the binary exists for your architecture."
	exit 1
fi

chmod +x "$TMP"

# --- Run installer, pass through all arguments ---
exec "$TMP" "$@"
