#!/bin/bash
# License: MIT
set -euo pipefail

trap 'printf "Interrupted. Cleaning up...\n" >&2' INT TERM

save_release_notes() {
  release_id=${RELEASE_ID:-}
  github_token=${GH_TOKEN:-}
  repo=${GITHUB_REPOSITORY:-}

  if [ -z "$release_id" ]; then
    printf "Error: RELEASE_ID variable required.\n" >&2
    return 1
  fi
  if [ -z "$github_token" ]; then
    printf "Error: GH_TOKEN variable required.\n" >&2
    return 1
  fi
  if [ -z "$repo" ]; then
    printf "Error: GITHUB_REPOSITORY variable required.\n" >&2
    return 1
  fi

  dd=$(date +%d)
  h_val=$(date +%-H)
  hours=0123456789ABCDEFGHIJKLMN
  h=$(printf "%s" "$hours" | cut -c $((h_val + 1)))
  y=$(date +%y | cut -c 2)
  m_val=$(date +%-m)
  months=123456789ABC
  m=$(printf "%s" "$months" | cut -c "$m_val")

  filename=Notes/NTE-${dd}${h}${y}${m}.md
  mkdir -p Notes
  [ -f Notes/.gitkeep ] || touch Notes/.gitkeep

  api_url=https://api.github.com/repos/${repo}/releases/${release_id}
  body=$(curl -s -H "Authorization: token ${github_token}" \
              -H "Accept: application/vnd.github.v3+json" \
              "$api_url" | jq -r '.body')

  if [ -z "$body" ] || [ "$body" = "null" ]; then
    printf "No release notes provided.\n" > "$filename"
  else
    printf "%s\n" "$body" > "$filename"
  fi

  git config user.name "github-actions[bot]"
  git config user.email "github-actions[bot]@users.noreply.github.com"
  git add "$filename" Notes/.gitkeep
  git commit -m "docs: add release notes $filename [skip ci]" || true
  git pull --rebase origin main
  git push origin main
}
save_release_notes
