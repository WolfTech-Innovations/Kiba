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

save_release_notes() {
  local release_id="${RELEASE_ID:-}"
  local github_token="${GH_TOKEN:-}"
  local repo="${GITHUB_REPOSITORY:-}"

  if [[ -z "$release_id" ]]; then
    printf "Error: RELEASE_ID environment variable is required.\n" >&2
    exit 1
  fi

  if [[ -z "$github_token" ]]; then
    printf "Error: GH_TOKEN environment variable is required.\n" >&2
    exit 1
  fi

  if [[ -z "$repo" ]]; then
    printf "Error: GITHUB_REPOSITORY environment variable is required.\n" >&2
    exit 1
  fi

  # 1. Generate filename: NTE-DDHYM
  # DD: Day of month (01-31)
  # H: Hour of day (0-N for 0-23)
  # Y: Last digit of year
  # M: Month (1-C for 1-12)

  local dd
  dd=$(date +%d)

  local h_val
  h_val=$(date +%-H)
  local hours="0123456789ABCDEFGHIJKLMN"
  local h
  h=$(printf "%s" "$hours" | cut -c $((h_val + 1)))

  local y
  y=$(date +%y | cut -c 2)

  local m_val
  m_val=$(date +%-m)
  local months="123456789ABC"
  local m
  m=$(printf "%s" "$months" | cut -c "$m_val")

  local filename="Notes/NTE-${dd}${h}${y}${m}.md"

  # 2. Ensure Notes directory and .gitkeep exist
  mkdir -p Notes
  if [[ ! -f Notes/.gitkeep ]]; then
    touch Notes/.gitkeep
  fi

  # 3. Fetch release body using curl and jq
  # Uses GH_TOKEN from environment
  local api_url="https://api.github.com/repos/${repo}/releases/${release_id}"
  local body
  body=$(curl -s -H "Authorization: token ${github_token}" \
              -H "Accept: application/vnd.github.v3+json" \
              "$api_url" | jq -r '.body')

  # 4. Handle empty release notes
  if [[ -z "$body" || "$body" == "null" ]]; then
    printf "No release notes provided for this release.\n" > "$filename"
  else
    printf "%s\n" "$body" > "$filename"
  fi

  # 5. Git operations
  git config user.name "github-actions[bot]"
  git config user.email "github-actions[bot]@users.noreply.github.com"
  git add "$filename" Notes/.gitkeep
  git commit -m "docs: add release notes $filename [skip ci]" || printf "No changes to commit\n"
  git pull --rebase origin main
  git push origin main
}

save_release_notes
