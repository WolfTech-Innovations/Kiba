#
# MIT License
# Copyright (c) 2026 WolfTech-Innovations
#
#
# Copyright (c) 2026 WolfTech-Innovations
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.
#
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

set -euo pipefail

trap 'printf "Interrupted. Cleaning up...
" >&2' INT TERM

# Centralized script to save release notes to the Notes/ folder
# Convention: NTE-DDHYM.md

save_release_notes() {
  if [ "$#" -ne 1 ] && [ -z "${RELEASE_ID:-}" ]; then
    printf "Usage: %s [release_id]
" "$0" >&2
  fi

  local release_id; release_id="${1:-${RELEASE_ID:-}}"
  local github_token; github_token="${GH_TOKEN:-}"
  local repo; repo="${GITHUB_REPOSITORY:-}"

  if [ -z "$release_id" ]; then
    printf "Error: RELEASE_ID environment variable or argument is required.
" >&2
    return 1
  fi

  if [ -z "$github_token" ]; then
    printf "Error: GH_TOKEN environment variable is required.
" >&2
    return 1
  fi

  if [ -z "$repo" ]; then
    printf "Error: GITHUB_REPOSITORY environment variable is required.
" >&2
    return 1
  fi

  # 1. Generate filename: NTE-DDHYM
  # Optimization: Single date call reduces process spawning.
  # Using Bash string manipulation instead of cut/printf.
  # DD: Day of month (01-31)
  # H: Hour of day (0-N for 0-23)
  # Y: Last digit of year
  # M: Month (1-C for 1-12)

  local dd h_val y_val m_val vars
  vars=$(date "+%d %-H %y %-m")

  read -r dd h_val y_val m_val <<EOV
$vars
EOV

  local hours="0123456789ABCDEFGHIJKLMN"
  local h; h="${hours:$h_val:1}"
  local y; y="${y_val:1:1}"
  local months="123456789ABC"
  local m_idx; m_idx=$((m_val - 1))
  local m; m="${months:$m_idx:1}"

  local filename="Notes/NTE-${dd}${h}${y}${m}.md"

  # 2. Ensure Notes directory and .gitkeep exist
  mkdir -p Notes
  if [ ! -f Notes/.gitkeep ]; then
    touch Notes/.gitkeep
  fi

  # 3. Fetch release body using curl -fsS and jq
  local api_url="https://api.github.com/repos/${repo}/releases/${release_id}"
  local body
  body=$(curl -fsS -H "Authorization: token ${github_token}" \
              -H "Accept: application/vnd.github.v3+json" \
              "$api_url" | jq -r '.body')

  # 4. Handle empty release notes
  if [ -z "$body" ] || [ "$body" = "null" ]; then
    printf "No release notes provided for this release.
" > "$filename"
  else
    printf "%s
" "$body" > "$filename"
  fi

  # 5. Git operations
  # Optimization: Only perform network operations if there are changes to push.
  git config user.name "github-actions[bot]"
  git config user.email "github-actions[bot]@users.noreply.github.com"
  git add "$filename" Notes/.gitkeep

  if git commit -m "docs: add release notes $filename [skip ci]"; then
    git pull --rebase origin main
    git push origin main
  else
    printf "No changes to commit
"
  fi
}

save_release_notes "$@"
