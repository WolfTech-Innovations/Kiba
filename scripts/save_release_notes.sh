#!/bin/bash
set -e

# Centralized script to save release notes to the Notes/ folder
# Convention: NTE-DDHYM.md

RELEASE_ID=$1

if [ -z "$RELEASE_ID" ]; then
  echo "Error: Release ID is required as the first argument."
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
H=$(echo $HOURS | cut -c $((H_VAL + 1)))

Y=$(date +%y | cut -c 2)

M_VAL=$(date +%-m)
MONTHS="123456789ABC"
M=$(echo $MONTHS | cut -c $M_VAL)

FILENAME="Notes/NTE-${DD}${H}${Y}${M}.md"

# 2. Ensure Notes directory and .gitkeep exist
mkdir -p Notes
if [ ! -f Notes/.gitkeep ]; then
  touch Notes/.gitkeep
fi

# 3. Fetch release body using GitHub CLI
# Uses GH_TOKEN from environment
gh release view "$RELEASE_ID" --template '{{.body}}' > "$FILENAME"

# 4. Handle empty release notes
if [ ! -s "$FILENAME" ]; then
  echo "No release notes provided for this release." > "$FILENAME"
fi

# 5. Git operations
git config user.name "github-actions[bot]"
git config user.email "github-actions[bot]@users.noreply.github.com"
git add "$FILENAME" Notes/.gitkeep
git commit -m "docs: add release notes $FILENAME [skip ci]" || echo "No changes to commit"
git pull --rebase origin main
git push origin main
