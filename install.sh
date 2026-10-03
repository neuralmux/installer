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

# The public download host.
#
# The installer is built by neuralmux/nmux.rs, but that repository is private,
# so its release assets are not anonymously downloadable — and this script runs
# with no credentials. The binaries are published here instead, which is also
# why this repository exists.
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

# --- Resolve the release ---
#
# The tag is resolved before anything is downloaded, and every asset then comes
# from that one tag. `releases/latest/download/...` looks simpler and is wrong:
# it is served through a CDN whose redirect is cached *per asset path*, so
# immediately after a release it can hand back the new `checksums.txt` and the
# previous release's binary — which is a checksum mismatch at best, and an old
# binary at worst if the verification were absent.
#
# Verified: after publishing v2026.40.1, that alias still redirected the arm64
# binary to v2026.40.0 while serving v2026.40.1's checksums.
resolve_tag() {
	# An explicit tag wins, so an operator can pin a version.
	if [[ -n "${NMUX_INSTALLER_TAG:-}" ]]; then
		printf '%s' "$NMUX_INSTALLER_TAG"
		return 0
	fi

	local api="https://api.github.com/repos/${REPO}/releases/latest"
	local auth=()
	# Unauthenticated callers get 60 requests an hour per address, which is
	# ample for an install; a token raises it when one is present.
	if [[ -n "${GITHUB_TOKEN:-}" ]]; then
		auth=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
	fi

	local body
	if ! body=$(curl -fsSL "${auth[@]}" -H "Accept: application/vnd.github+json" "$api"); then
		echo "Could not resolve the latest release of ${REPO}." >&2
		echo "Set NMUX_INSTALLER_TAG to install a specific version." >&2
		return 1
	fi

	local tag
	tag=$(printf '%s' "$body" | grep -o '"tag_name": *"[^"]*"' | head -1 | sed 's/.*"\([^"]*\)"$/\1/')
	if [[ -z "$tag" ]]; then
		echo "The release metadata for ${REPO} named no tag." >&2
		return 1
	fi
	printf '%s' "$tag"
}

TAG="$(resolve_tag)" || exit 1

# --- Download ---
BASE="https://github.com/${REPO}/releases/download/${TAG}"
ASSET="nmux-installer-linux-${ARCH}"

TMP=$(mktemp)
SUMS=$(mktemp)
trap 'rm -f "$TMP" "$SUMS"' EXIT

echo "Downloading nmux-installer ${TAG} for linux/${ARCH}..."
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
