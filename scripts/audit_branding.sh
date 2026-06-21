#!/usr/bin/env bash
# License: MIT
set -e

BUILD_SCRIPT="build.sh"
EXIT_CODE=0

echo "=== Auditing Branding Assets in $BUILD_SCRIPT ==="

# Extract URLs from build.sh
URLS=$(grep -oP 'https?://[^\s"]+' "$BUILD_SCRIPT" | grep -E 'png|jpg|asc|logo|wallpaper' | sort -u)

for URL in $URLS; do
    echo "Checking asset: $URL"
    if curl --output /dev/null --silent --head --fail "$URL"; then
        echo "  [OK] Reachable"
    else
        echo "  [FAIL] Unreachable or returned error"
        EXIT_CODE=1
    fi
done

if [ $EXIT_CODE -eq 0 ]; then
    echo "All branding assets are reachable."
else
    echo "One or more branding assets failed audit."
fi

exit $EXIT_CODE
