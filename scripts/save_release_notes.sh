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

trap 'printf "Interrupted. Cleaning up...\n" >&2' INT TERM

# Centralized script to save release notes to the Notes/ folder
# Convention: NTE-DDHYM.md

save_release_notes() {
  # Support both env var and argument for RELEASE_ID
  local rid="${1:-${RELEASE_ID:-}}"
  local token="${GH_TOKEN:-}"
  local repository="${GITHUB_REPOSITORY:-}"

  if [ -z "$rid" ]; then
    printf "Error: RELEASE_ID is required.\n" >&2
    exit 1
  fi

  if [ -z "$token" ]; then
    printf "Error: GH_TOKEN is required.\n" >&2
    exit 1
  fi

  if [ -z "$repository" ]; then
    printf "Error: GITHUB_REPOSITORY is required.\n" >&2
    exit 1
  fi

  # 1. Generate filename: NTE-DDHYM
  # DD: Day of month (01-31)
  # H: Hour of day (0-N for 0-23)
  # Y: Last digit of year (e.g., 6 for 2026)
  # M: Month (1-C for 1-12)

  local dd h y m vars h_val y_val m_val h_idx m_idx
  vars=$(date "+%d %H %y %m")
  dd=$(echo "$vars" | cut -d' ' -f1)
  h_val=$(echo "$vars" | cut -d' ' -f2)
  y_val=$(echo "$vars" | cut -d' ' -f3)
  m_val=$(echo "$vars" | cut -d' ' -f4)

  # Remove leading zeros for arithmetic
  h_idx=$(echo "$h_val" | sed 's/^0//'); h_idx="${h_idx:-0}"
  m_idx=$(echo "$m_val" | sed 's/^0//'); m_idx="${m_idx:-0}"

  local hours="0123456789ABCDEFGHIJKLMN"
  h=$(echo "$hours" | cut -c "$((h_idx + 1))")

  y=$(echo "$y_val" | cut -c 2)

  local months="123456789ABC"
  m=$(echo "$months" | cut -c "$((m_idx))")

  local filename="Notes/NTE-${dd}${h}${y}${m}.md"

  # 2. Ensure Notes directory and .gitkeep exist
  mkdir -p Notes
  if [ ! -f "Notes/.gitkeep" ] || [ -s "Notes/.gitkeep" ]; then
    : > Notes/.gitkeep
  fi

  # 3. Fetch release body
  local api_url="https://api.github.com/repos/${repository}/releases/${rid}"
  local body
  body=$(curl -fsS -H "Authorization: token ${token}" \
              -H "Accept: application/vnd.github.v3+json" \
              "$api_url" | jq -r '.body')

  # 4. Handle empty release notes
  if [ -z "$body" ] || [ "$body" = "null" ]; then
    printf "No release notes provided for this release.\n" > "$filename"
  else
    printf "%s\n" "$body" > "$filename"
  fi

  printf "Successfully saved release notes to %s\n" "$filename"
}

save_release_notes "$@"
