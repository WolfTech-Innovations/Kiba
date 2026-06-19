#!/usr/bin/env bash
# Monitor CachyOS kernel version by scraping the mirror
set -e

MIRROR_URL="https://mirror.cachyos.org/repo/x86_64/cachyos/"
# Regex to match linux-cachyos-x.y.z-a-x86_64.pkg.tar.zst and extract version
# Uses PCRE lookarounds to extract only the version part without sub-processes.
REGEX='(?<=linux-cachyos-)[0-9][^"-]*(?=-[0-9]+-x86_64\.pkg\.tar\.zst)'

echo "Fetching CachyOS kernel version from $MIRROR_URL..."
HTML=$(curl -sL "$MIRROR_URL")

# Extract versions, sort them and get the latest
LATEST_VERSION=$(echo "$HTML" | grep -oP "$REGEX" | sort -V | tail -n 1)

if [ -z "$LATEST_VERSION" ]; then
    echo "Error: Could not find kernel version on mirror."
    exit 1
fi

echo "latest_version=$LATEST_VERSION" >> "${GITHUB_OUTPUT:-/dev/null}"
echo "Found latest CachyOS kernel: $LATEST_VERSION"

# Optional: Store version for comparison if GITHUB_WORKSPACE is set
if [ -n "${GITHUB_WORKSPACE:-}" ]; then
    echo "$LATEST_VERSION" > "$GITHUB_WORKSPACE/latest_kernel.txt"
fi
