#!/bin/bash
#
# Copyright (c) 2025 WolfTech Innovations
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

set -euo pipefail

# Centralized script to save release notes to the Notes/ folder
# Convention: NTE-DDHYM.md

RELEASE_ID="${RELEASE_ID:-${1:-}}"

if [ -z "$RELEASE_ID" ]; then
  echo "Error: RELEASE_ID environment variable or first argument is required."
  exit 1
fi

# 1. Generate filename: NTE-DDHYM
# DD: Day of month (01-31)
# H: Hour of day (0-N for 0-23)
# Y: Last digit of year
# M: Month (1-C for 1-12)

DD=$(date +%d)
H_VAL=$(date +%-H)
HOURS="0123456789ABCDEFGHIJKLMN"
H=$(echo "$HOURS" | cut -c $((H_VAL + 1)))
Y=$(date +%y | cut -c 2)
M_VAL=$(date +%-m)
MONTHS="123456789ABC"
M=$(echo "$MONTHS" | cut -c "$M_VAL")

FILENAME="Notes/NTE-${DD}${H}${Y}${M}.md"

# 2. Ensure Notes directory and .gitkeep exist
echo "Ensuring Notes/ directory exists..."
mkdir -p Notes
if [ ! -f Notes/.gitkeep ]; then
  touch Notes/.gitkeep
fi

# 3. Fetch release body using GitHub CLI
# Uses GH_TOKEN from environment
echo "Fetching release notes for $RELEASE_ID..."
gh release view -- "$RELEASE_ID" --template '{{.body}}' > "$FILENAME"

# 4. Handle empty release notes
if [ ! -s "$FILENAME" ]; then
  echo "No release notes provided for this release." > "$FILENAME"
fi

# 5. Git operations
echo "Committing release notes: $FILENAME"
git config user.name "github-actions[bot]"
git config user.email "github-actions[bot]@users.noreply.github.com"
git add "$FILENAME" Notes/.gitkeep
git commit -m "docs: add release notes $FILENAME [skip ci]

Signed-off-by: github-actions[bot] <github-actions[bot]@users.noreply.github.com>" || echo "No changes to commit"
git pull --rebase origin main
git push origin main
