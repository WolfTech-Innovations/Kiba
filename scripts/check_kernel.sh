#!/bin/bash
# KibaOS CachyOS Kernel Monitor
# Scrapes the CachyOS mirror to find the latest kernel version

MIRROR_URL="https://mirror.cachyos.org/repo/x86_64/main/"
KERNEL_PATTERN='linux-cachyos-[0-9][^"-]*\.pkg\.tar\.zst'

echo "Checking CachyOS mirror: $MIRROR_URL"

LATEST_KERNEL=$(curl -s "$MIRROR_URL" | grep -oP "$KERNEL_PATTERN" | sort -V | tail -n 1)

if [ -n "$LATEST_KERNEL" ]; then
    VERSION=$(echo "$LATEST_KERNEL" | sed -E 's/linux-cachyos-(.*)\.pkg\.tar\.zst/\1/')
    echo "Latest CachyOS Kernel found: $VERSION"
    echo "filename=$LATEST_KERNEL" >> $GITHUB_OUTPUT
    echo "version=$VERSION" >> $GITHUB_OUTPUT
else
    echo "ERROR: Could not find CachyOS kernel on mirror."
    exit 1
fi
