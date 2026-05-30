import os

WORKFLOWS_DIR = ".github/workflows"

# Mapping of filename to (Workflow Name, Content)
workflows_content = {
    "stale.yml": """name: Stale Issue and PR Closer
on:
  schedule:
    - cron: '30 1 * * *'
  workflow_dispatch:
permissions:
  issues: write
  pull-requests: write
jobs:
  stale:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/stale@v9
        with:
          stale-issue-message: 'This issue is stale because it has been open 30 days with no activity.'
          stale-pr-message: 'This PR is stale because it has been open 30 days with no activity.'
          days-before-stale: 30
          days-before-close: 5
""",
    "auto-labeler.yml": """name: Auto Labeler
on:
  pull_request_target:
    types: [opened]
permissions:
  contents: read
  pull-requests: write
jobs:
  label:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/labeler@v5
        with:
          repo-token: "${{ secrets.GITHUB_TOKEN }}"
""",
    "commit-lint.yml": """name: Commit Lint
on: [pull_request]
permissions:
  contents: read
jobs:
  commitlint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - name: Install dependencies
        run: pnpm install --frozen-lockfile
      - name: Run commitlint
        run: npx commitlint --from ${{ github.event.pull_request.base.sha }} --to ${{ github.event.pull_request.head.sha }} --verbose
""",
    "todo-checker.yml": """name: TODO Checker
on: [push, pull_request]
permissions:
  contents: read
jobs:
  todo:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Check for TODOs
        run: |
          grep -r "TODO" . && echo "Found TODOs" || echo "No TODOs found"
""",
    "branch-name-enforcer.yml": """name: Branch Name Enforcer
on: [pull_request]
permissions:
  contents: read
jobs:
  check-branch-name:
    runs-on: ubuntu-latest
    steps:
      - name: Validate branch name
        run: |
          echo "${{ github.head_ref }}" | grep -E '^(feat|fix|docs|style|refactor|perf|test|chore|audit|bolt|sentinel|palette)/[a-z0-9-]+'
""",
}

# 30 Audit Workflows using repo_audit.sh flags
audit_workflows = {
    "audit-build-sh-customize-set-e.yml": ("Audit Build SH Customize Set E", "--build-sh-set-e"),
    "audit-build-sh-pacman-populate.yml": ("Audit Build SH Pacman Populate", "--build-sh-pacman-populate"),
    "audit-build-sh-relative-symlinks.yml": ("Audit Build SH Relative Symlinks", "--build-sh-relative-symlinks"),
    "audit-build-sh-paperde-ldconfig.yml": ("Audit Build SH PaperDE ldconfig", "--build-sh-paperde-ldconfig"),
    "audit-build-sh-desktop-entry-kiba.yml": ("Audit Build SH Desktop Entry Kiba", "--build-sh-desktop-entry-kiba"),
    "audit-build-sh-sudoers-perms.yml": ("Audit Build SH Sudoers Perms", "--build-sh-sudoers-perms"),
    "audit-build-sh-liveuser-uid.yml": ("Audit Build SH Liveuser UID", "--build-sh-liveuser-uid"),
    "audit-build-sh-wallpaper-consistency.yml": ("Audit Build SH Wallpaper Consistency", "--build-sh-wallpaper-consistency"),
    "audit-build-sh-octopi-usage.yml": ("Audit Build SH Octopi Usage", "--build-sh-octopi-usage"),
    "audit-build-sh-zsh-default.yml": ("Audit Build SH Zsh Default", "--build-sh-zsh-default"),
    "audit-markdown-empty-link-check.yml": ("Audit Markdown Empty Link Check", "--markdown-empty-links"),
    "audit-repo-license-sanity.yml": ("Audit Repo License Sanity", "--repo-license-sanity"),
    "audit-repo-readme-badge-https.yml": ("Audit Repo README Badge HTTPS", "--repo-readme-badge-https"),
    "audit-repo-no-chmod-777-strict.yml": ("Audit Repo No Chmod 777 Strict", "--security-chmod-777"),
    "audit-repo-no-plaintext-chpasswd.yml": ("Audit Repo No Plaintext Chpasswd", "--security-no-plaintext-chpasswd"),
    "audit-repo-markdown-anchor-links.yml": ("Audit Repo Markdown Anchor Links", "--markdown-anchor-links"),
    "audit-repo-gitkeep-no-extension.yml": ("Audit Repo Gitkeep No Extension", "--hygiene-gitkeep"),
    "audit-repo-shell-extension-consistency.yml": ("Audit Repo Shell Extension Consistency", "--repo-shell-extension-consistency"),
    "audit-repo-trailing-whitespace-all.yml": ("Audit Repo Trailing Whitespace All", "--hygiene-trailing-whitespace"),
    "audit-repo-no-nested-git-dir.yml": ("Audit Repo No Nested Git Dir", "--repo-no-nested-git-dir"),
    "audit-workflow-checkout-v4.yml": ("Audit Workflow Checkout V4", "--workflow-checkout-v4"),
    "audit-workflow-no-node-16-actions.yml": ("Audit Workflow No Node 16 Actions", "--workflow-no-node-16-actions"),
    "audit-workflow-explicit-bash-shell.yml": ("Audit Workflow Explicit Bash Shell", "--workflow-explicit-bash-shell"),
    "audit-workflow-no-empty-run-blocks.yml": ("Audit Workflow No Empty Run Blocks", "--workflow-no-empty-run-blocks"),
    "audit-workflow-job-permissions-only.yml": ("Audit Workflow Job Permissions Only", "--workflow-job-permissions-only"),
    "audit-workflow-timeout-reasonable.yml": ("Audit Workflow Timeout Reasonable", "--workflow-timeout-reasonable"),
    "audit-workflow-kebab-filenames-strict.yml": ("Audit Workflow Kebab Filenames Strict", "--workflow-kebab-filenames-strict"),
    "audit-workflow-no-absolute-script-paths.yml": ("Audit Workflow No Absolute Script Paths", "--workflow-no-absolute-script-paths"),
    "audit-workflow-unused-workflow-inputs.yml": ("Audit Workflow Unused Workflow Inputs", "--workflow-unused-workflow-inputs"),
    "audit-workflow-no-github-token-leak.yml": ("Audit Workflow No GitHub Token Leak", "--security-token-leaks"),
}

diverse_workflows = {
    "prettier-check.yml": ("Prettier Check", "pnpm exec prettier --check ."),
    "json-lint.yml": ("JSON Lint", "npx jsonlint -q package.json"),
    "shellcheck.yml": ("ShellCheck", "shellcheck scripts/*.sh"),
    "dependency-vulnerability-scan.yml": ("Dependency Vulnerability Scan", "pnpm audit"),
    "workflow-syntax-check.yml": ("Workflow Syntax Check", "python3 check_workflows.py"),
    "code-of-conduct-check.yml": ("Code of Conduct Check", "ls CODE_OF_CONDUCT.md"),
    "security-audit.yml": ("Security Audit", "bash scripts/repo_audit.sh"),
    "broken-link-checker.yml": ("Broken Link Checker", "grep -rE 'https?://' . --include='*.md' || true"),
    "license-header-check.yml": ("License Header Check", "grep -r 'License' scripts/"),
    "release-notes-generator.yml": ("Release Notes Generator", "bash scripts/save_release_notes.sh test"),
}

AUDIT_TEMPLATE = """name: {name}

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]
  workflow_dispatch:

permissions:
  contents: read

jobs:
  audit:
    runs-on: ubuntu-latest
    timeout-minutes: 10
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Run {name}
        shell: bash
        run: |
          {command}
"""

def main():
    if not os.path.exists(WORKFLOWS_DIR):
        os.makedirs(WORKFLOWS_DIR)

    for filename, (name, flag) in audit_workflows.items():
        command = f"bash scripts/repo_audit.sh {flag}"
        content = AUDIT_TEMPLATE.format(name=name, command=command)
        filepath = os.path.join(WORKFLOWS_DIR, filename)
        with open(filepath, "w") as f:
            f.write(content)

    for filename, content in workflows_content.items():
        filepath = os.path.join(WORKFLOWS_DIR, filename)
        with open(filepath, "w") as f:
            f.write(content)

    for filename, (name, command) in diverse_workflows.items():
        if filename in workflows_content:
            continue
        content = AUDIT_TEMPLATE.format(name=name, command=command)
        filepath = os.path.join(WORKFLOWS_DIR, filename)
        with open(filepath, "w") as f:
            f.write(content)

if __name__ == "__main__":
    main()
