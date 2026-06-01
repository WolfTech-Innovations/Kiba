import os
import json

checks = [
    "build-sh-customize-set-e",
    "build-sh-pacman-populate",
    "build-sh-paperde-ldconfig",
    "build-sh-liveuser-uid",
    "build-sh-octopi-usage",
    "build-sh-zsh-default",
    "build-sh-relative-symlinks",
    "build-sh-desktop-entry-kiba",
    "build-sh-sudoers-perms",
    "build-sh-wallpaper-consistency",
    "build-sh-pacman-su",
    "build-sh-no-duplicate-packages",
    "repo-no-chmod-777-strict",
    "repo-no-plaintext-chpasswd",
    "repo-gitkeep-no-extension",
    "repo-shell-extension-consistency",
    "repo-trailing-whitespace-all",
    "repo-no-nested-git-dir",
    "repo-license-sanity",
    "repo-readme-badge-https",
    "repo-readme-toc-required",
    "repo-lowercase-directories",
    "repo-snake-case-scripts",
    "repo-no-temp-files",
    "repo-no-backup-files",
    "markdown-empty-link-check",
    "markdown-anchor-links",
    "markdown-no-tabs",
    "markdown-no-fixme",
    "markdown-inclusive-language",
    "markdown-header-punctuation",
    "workflow-checkout-v4",
    "workflow-no-node-16-actions",
    "workflow-explicit-bash-shell",
    "workflow-no-empty-run-blocks",
    "workflow-job-permissions-only",
    "workflow-timeout-reasonable",
    "workflow-kebab-filenames-strict",
    "workflow-no-absolute-script-paths",
    "workflow-unused-workflow-inputs",
    "workflow-no-github-token-leak",
    "zenity-dimensions-strict",
    "zenity-standard-dimensions",
    "build-welcome-apps",
    "build-welcome-screenshot-help"
]

matrix_workflow_content = f"""name: KibaOS Repository Comprehensive Audit

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]
  workflow_dispatch:
  schedule:
    - cron: '0 0 * * 1'

permissions:
  contents: read

jobs:
  audit:
    name: "Audit: ${{{{ matrix.check }}}}"
    runs-on: ubuntu-latest
    timeout-minutes: 10
    strategy:
      fail-fast: false
      matrix:
        check: {json.dumps(checks)}
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Run audit check
        run: bash scripts/repo_audit.sh --audit-${{{{ matrix.check }}}}
"""

def generate_matrix_workflow():
    workflow_dir = ".github/workflows"
    os.makedirs(workflow_dir, exist_ok=True)

    filepath = os.path.join(workflow_dir, "repo-comprehensive-audit.yml")
    with open(filepath, "w") as f:
        f.write(matrix_workflow_content)
    print(f"Generated: {filepath}")
    return "KibaOS Repository Comprehensive Audit", filepath

def update_workflows_md():
    workflow_dir = ".github/workflows"

    existing_content = ""
    if os.path.exists("WORKFLOWS.md"):
        with open("WORKFLOWS.md", "r") as f:
            existing_content = f.read()

    # Extract headers and existing table rows
    lines = existing_content.splitlines()
    header = "# GitHub Workflows Manual"
    rows = []

    in_table = False
    for line in lines:
        if "|" in line and "---" not in line and "Workflow Name" not in line:
            # Check if this row is already in our list (to avoid duplicates)
            parts = [p.strip() for p in line.split("|") if p.strip()]
            if len(parts) >= 2:
                rows.append((parts[0], parts[1]))

    # Current workflows in .github/workflows
    current_workflows = []
    for f in sorted(os.listdir(workflow_dir)):
        if f.endswith(".yml") or f.endswith(".yaml"):
            filepath = f".github/workflows/{f}"
            # Try to get name from the file if possible, else guess
            name = f.replace(".yml", "").replace(".yaml", "").replace("-", " ").title()
            if f == "repo-comprehensive-audit.yml":
                name = "KibaOS Repository Comprehensive Audit"
            current_workflows.append((name, f"`{filepath}`"))

    # Merge rows, keeping current ones
    merged_rows = {}
    for name, path in rows:
        merged_rows[name] = path
    for name, path in current_workflows:
        merged_rows[name] = path

    md_content = f"{header}\n"
    md_content += f"Last Audit Update: {os.popen('date').read().strip()}\n\n"
    md_content += "| Workflow Name | File Path |\n"
    md_content += "|---------------|-----------|\n"

    for name in sorted(merged_rows.keys()):
        md_content += f"| {name} | {merged_rows[name]} |\n"

    with open("WORKFLOWS.md", "w") as f:
        f.write(md_content)
    print("Updated WORKFLOWS.md")

if __name__ == "__main__":
    generate_matrix_workflow()
    update_workflows_md()
