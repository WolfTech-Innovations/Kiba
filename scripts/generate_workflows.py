import os
import datetime

WORKFLOWS = [
    ("Audit Build SH Customize Set E", "audit-build-sh-customize-set-e.yml", "--audit-build-sh-customize-set-e"),
    ("Audit Build SH Pacman Populate", "audit-build-sh-pacman-populate.yml", "--audit-build-sh-pacman-populate"),
    ("Audit Build SH Relative Symlinks", "audit-build-sh-relative-symlinks.yml", "--audit-build-sh-relative-symlinks"),
    ("Audit Build SH PaperDE ldconfig", "audit-build-sh-paperde-ldconfig.yml", "--audit-build-sh-paperde-ldconfig"),
    ("Audit Build SH Desktop Entry Kiba", "audit-build-sh-desktop-entry-kiba.yml", "--audit-build-sh-desktop-entry-kiba"),
    ("Audit Build SH Sudoers Perms", "audit-build-sh-sudoers-perms.yml", "--audit-build-sh-sudoers-perms"),
    ("Audit Build SH Liveuser UID", "audit-build-sh-liveuser-uid.yml", "--audit-build-sh-liveuser-uid"),
    ("Audit Build SH Wallpaper Consistency", "audit-build-sh-wallpaper-consistency.yml", "--audit-build-sh-wallpaper-consistency"),
    ("Audit Build SH Octopi Usage", "audit-build-sh-octopi-usage.yml", "--audit-build-sh-octopi-usage"),
    ("Audit Build SH Zsh Default", "audit-build-sh-zsh-default.yml", "--audit-build-sh-zsh-default"),
    ("Audit Markdown Empty Link Check", "audit-markdown-empty-link-check.yml", "--audit-markdown-empty-link-check"),
    ("Audit Repo License Sanity", "audit-repo-license-sanity.yml", "--audit-repo-license-sanity"),
    ("Audit Repo README Badge HTTPS", "audit-repo-readme-badge-https.yml", "--audit-repo-readme-badge-https"),
    ("Audit Repo No Chmod 777 Strict", "audit-repo-no-chmod-777-strict.yml", "--audit-repo-no-chmod-777-strict"),
    ("Audit Repo No Plaintext Chpasswd", "audit-repo-no-plaintext-chpasswd.yml", "--audit-repo-no-plaintext-chpasswd"),
    ("Audit Repo Markdown Anchor Links", "audit-repo-markdown-anchor-links.yml", "--audit-repo-markdown-anchor-links"),
    ("Audit Repo Gitkeep No Extension", "audit-repo-gitkeep-no-extension.yml", "--audit-repo-gitkeep-no-extension"),
    ("Audit Repo Shell Extension Consistency", "audit-repo-shell-extension-consistency.yml", "--audit-repo-shell-extension-consistency"),
    ("Audit Repo Trailing Whitespace All", "audit-repo-trailing-whitespace-all.yml", "--audit-repo-trailing-whitespace-all"),
    ("Audit Repo No Nested Git Dir", "audit-repo-no-nested-git-dir.yml", "--audit-repo-no-nested-git-dir"),
    ("Audit Workflow Checkout V4", "audit-workflow-checkout-v4.yml", "--audit-workflow-checkout-v4"),
    ("Audit Workflow No Node 16 Actions", "audit-workflow-no-node-16-actions.yml", "--audit-workflow-no-node-16-actions"),
    ("Audit Workflow Explicit Bash Shell", "audit-workflow-explicit-bash-shell.yml", "--audit-workflow-explicit-bash-shell"),
    ("Audit Workflow No Empty Run Blocks", "audit-workflow-no-empty-run-blocks.yml", "--audit-workflow-no-empty-run-blocks"),
    ("Audit Workflow Job Permissions Only", "audit-workflow-job-permissions-only.yml", "--audit-workflow-job-permissions-only"),
    ("Audit Workflow Timeout Reasonable", "audit-workflow-timeout-reasonable.yml", "--audit-workflow-timeout-reasonable"),
    ("Audit Workflow Kebab Filenames Strict", "audit-workflow-kebab-filenames-strict.yml", "--audit-workflow-kebab-filenames-strict"),
    ("Audit Workflow No Absolute Script Paths", "audit-workflow-no-absolute-script-paths.yml", "--audit-workflow-no-absolute-script-paths"),
    ("Audit Workflow Unused Workflow Inputs", "audit-workflow-unused-workflow-inputs.yml", "--audit-workflow-unused-workflow-inputs"),
    ("Audit Workflow No GitHub Token Leak", "audit-workflow-no-github-token-leak.yml", "--audit-workflow-no-github-token-leak"),
    ("Audit Repo Snake Case Scripts", "audit-repo-snake-case-scripts.yml", "--audit-repo-snake-case-scripts"),
    ("Audit Repo Lowercase Directories", "audit-repo-lowercase-directories.yml", "--audit-repo-lowercase-directories"),
    ("Audit Repo No Temp Files", "audit-repo-no-temp-files.yml", "--audit-repo-no-temp-files"),
    ("Audit Repo No Backup Files Hygiene", "audit-repo-no-backup-files-hygiene.yml", "--audit-repo-no-backup-files-hygiene"),
    ("Audit Repo No Pyc", "audit-repo-no-pyc.yml", "--audit-repo-no-pyc"),
    ("Audit Shell Script Pipefail", "audit-shell-script-pipefail.yml", "--audit-shell-script-pipefail"),
    ("Audit Shell Script Readonly Constants", "audit-shell-script-readonly-constants.yml", "--audit-shell-script-readonly-constants"),
    ("Audit Shell Shebang No Space", "audit-shell-shebang-no-space.yml", "--audit-shell-shebang-no-space"),
    ("Audit Markdown No Tabs", "audit-markdown-no-tabs.yml", "--audit-markdown-no-tabs"),
    ("Audit Markdown Horizontal Rule Style", "audit-markdown-hr-style.yml", "--audit-markdown-hr-style"),
    ("Audit Workflow Permissions", "audit-workflow-permissions.yml", "--audit-workflow-permissions"),
    ("Audit Workflow Concurrency", "audit-workflow-concurrency.yml", "--audit-workflow-concurrency"),
    ("Audit Workflow On Pull Request Types", "audit-workflow-on-pull-request-types.yml", "--audit-workflow-on-pull-request-types"),
    ("Audit Workflow Push Branch Filter", "audit-workflow-push-branch-filter.yml", "--audit-workflow-push-branch-filter"),
    ("Audit Workflow Timeout All Jobs", "audit-workflow-timeout-all-jobs.yml", "--audit-workflow-timeout-all-jobs"),
]

TEMPLATE = """name: "{name}"
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  workflow_dispatch:

permissions:
  contents: read

jobs:
  audit:
    runs-on: ubuntu-latest
    timeout-minutes: 5
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Run audit
        run: bash scripts/repo_audit.sh {flag}
"""

def generate():
    workflow_dir = ".github/workflows"
    os.makedirs(workflow_dir, exist_ok=True)

    for name, filename, flag in WORKFLOWS:
        filepath = os.path.join(workflow_dir, filename)
        content = TEMPLATE.format(name=name, flag=flag)
        with open(filepath, "w") as f:
            f.write(content)
        print(f"Generated {filepath}")

    # Generate WORKFLOWS.md
    with open("WORKFLOWS.md", "w") as f:
        f.write("# GitHub Workflows Manual\n")
        f.write(f"Generated on {datetime.datetime.utcnow().strftime('%a %b %d %H:%M:%S UTC %Y')}\n\n")
        f.write("| Workflow Name | File Path |\n")
        f.write("|---------------|-----------|\n")
        # Add the main build workflow manually or scan
        f.write("| KibaOS Build | `.github/workflows/build.yml` |\n")
        for name, filename, _ in sorted(WORKFLOWS):
            f.write(f"| {name} | `.github/workflows/{filename}` |\n")

if __name__ == "__main__":
    generate()
