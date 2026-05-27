#!/bin/bash
# License: MIT
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

set -eu
set -o pipefail

trap 'printf "Interrupted. Cleaning up...\n" >&2' INT TERM

# Centralized script to save release notes to the Notes/ folder
# Convention: NTE-DDHYM.md
# DD: Day of month (01-31)
# H: Hour of day (0-23 -> 0123456789ABCDEFGHIJKLMN)
# Y: Last digit of year (e.g., 6 for 2026)
# M: Month (1-12 -> 123456789ABC)

save_release_notes() {
  if [ "$#" -ne 1 ] && [ -z "${RELEASE_ID:-}" ]; then
    printf "Usage: %s [release_id]\n" "$0" >&2
    exit 1
  fi

  release_id="${1:-${RELEASE_ID:-}}"
  github_token="${GH_TOKEN:-}"
  repo="${GITHUB_REPOSITORY:-}"

  if [ -z "$release_id" ]; then
    printf "Error: RELEASE_ID environment variable or argument is required.\n" >&2
    return 1
  fi

  if [ -z "$github_token" ]; then
    printf "Error: GH_TOKEN environment variable is required.\n" >&2
    return 1
  fi

  if [ -z "$repo" ]; then
    printf "Error: GITHUB_REPOSITORY environment variable is required.\n" >&2
    return 1
  fi

  # Check for dependencies
  for cmd in curl jq git; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      printf "Error: %s is required but not installed.\n" "$cmd" >&2
      return 1
    fi
  done

  # 1. Generate filename: NTE-DDHYM
  # Use current date in UTC to avoid timezone issues
  vars=$(date -u "+%d %H %y %m")
  dd=$(echo "$vars" | cut -d' ' -f1)
  h_val=$(echo "$vars" | cut -d' ' -f2)
  y_val=$(echo "$vars" | cut -d' ' -f3)
  m_val=$(echo "$vars" | cut -d' ' -f4)

  # Remove leading zeros to avoid octal interpretation in arithmetic
  h_val_clean=$(echo "$h_val" | sed 's/^0//'); h_val_clean="${h_val_clean:-0}"
  m_val_clean=$(echo "$m_val" | sed 's/^0//'); m_val_clean="${m_val_clean:-0}"

  # 24 characters for 24 hours (0-23)
  hours="0123456789ABCDEFGHIJKLMN"
  h=$(echo "$hours" | cut -c "$((h_val_clean + 1))")
  y=$(echo "$y_val" | cut -c 2)
  # 12 characters for 12 months (1-12)
  months="123456789ABC"
  m=$(echo "$months" | cut -c "$((m_val_clean))")

  filename="Notes/NTE-${dd}${h}${y}${m}.md"

  # 2. Ensure Notes directory and .gitkeep exist
  mkdir -p Notes
  # Ensure .gitkeep is empty as per repository hygiene
  truncate -s 0 Notes/.gitkeep

  # 3. Fetch release body using curl -fsS and jq
  api_url="https://api.github.com/repos/${repo}/releases/${release_id}"
  body=$(curl -fsS -H "Authorization: token ${github_token}" \
              -H "Accept: application/vnd.github.v3+json" \
              "$api_url" | jq -r '.body')

  # 4. Handle empty release notes
  if [ -z "$body" ] || [ "$body" = "null" ]; then
    printf "No release notes provided for this release.\n" > "$filename"
  else
    printf "%s\n" "$body" > "$filename"
  fi

  # 5. Git operations
  # Ensure git is configured for the commit
  git config user.name "github-actions[bot]"
  git config user.email "github-actions[bot]@users.noreply.github.com"

  git add "$filename" Notes/.gitkeep

  # Commit if there are changes
  if git commit -m "docs: add release notes $filename [skip ci]"; then
    # Pull latest changes before pushing to avoid conflicts
    git pull --rebase origin main
    git push origin main
  else
    printf "No changes to commit (or commit failed)\n"
  fi
}

(save_release_notes "$@")
