#!/usr/bin/env bash
# License: MIT
set -e

PACKAGES=("calamares" "libinput-gestures")

for PKG in "${PACKAGES[@]}"; do
    echo "Checking AUR version for $PKG..."
    REMOTE_VERSION=$(curl -s "https://aur.archlinux.org/rpc/?v=5&type=info&arg[]=$PKG" | jq -r '.results[0].Version')

    STATE_FILE="aur_state_${PKG}.txt"
    if [ -f "$STATE_FILE" ]; then
        LOCAL_VERSION=$(cat "$STATE_FILE")
        if [ "$REMOTE_VERSION" != "$LOCAL_VERSION" ]; then
            echo "UPDATE_FOUND=true" >> "$GITHUB_OUTPUT"
            echo "PKG_NAME=$PKG" >> "$GITHUB_OUTPUT"
            echo "NEW_VERSION=$REMOTE_VERSION" >> "$GITHUB_OUTPUT"
            echo "NEW version found for $PKG: $REMOTE_VERSION (was $LOCAL_VERSION)"
            echo "$REMOTE_VERSION" > "$STATE_FILE"
        else
            echo "No updates for $PKG (version $LOCAL_VERSION)"
        fi
    else
        echo "Initializing state for $PKG at version $REMOTE_VERSION"
        echo "$REMOTE_VERSION" > "$STATE_FILE"
    fi
done
