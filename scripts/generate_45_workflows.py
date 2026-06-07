import os

workflows = [
    ("Audit Build SH Customize Set E", "audit-build-sh-customize-set-e"),
    ("Audit Build SH Pacman Populate", "audit-build-sh-pacman-populate"),
    ("Audit Build SH Relative Symlinks", "audit-build-sh-relative-symlinks"),
    ("Audit Build SH PaperDE ldconfig", "audit-build-sh-paperde-ldconfig"),
    ("Audit Build SH Desktop Entry Kiba", "audit-build-sh-desktop-entry-kiba"),
    ("Audit Build SH Sudoers Perms", "audit-build-sh-sudoers-perms"),
    ("Audit Build SH Liveuser UID", "audit-build-sh-liveuser-uid"),
    ("Audit Build SH Wallpaper Consistency", "audit-build-sh-wallpaper-consistency"),
    ("Audit Build SH Octopi Usage", "audit-build-sh-octopi-usage"),
    ("Audit Build SH Zsh Default", "audit-build-sh-zsh-default"),
    ("Audit Markdown Empty Link Check", "audit-markdown-empty-link-check"),
    ("Audit Repo License Sanity", "audit-repo-license-sanity"),
    ("Audit Repo README Badge HTTPS", "audit-repo-readme-badge-https"),
    ("Audit Repo No Chmod 777 Strict", "audit-repo-no-chmod-777-strict"),
    ("Audit Repo No Plaintext Chpasswd", "audit-repo-no-plaintext-chpasswd"),
    ("Audit Repo Markdown Anchor Links", "audit-repo-markdown-anchor-links"),
    ("Audit Repo Gitkeep No Extension", "audit-repo-gitkeep-no-extension"),
    ("Audit Repo Shell Extension Consistency", "audit-repo-shell-extension-consistency"),
    ("Audit Repo Trailing Whitespace All", "audit-repo-trailing-whitespace-all"),
    ("Audit Repo No Nested Git Dir", "audit-repo-no-nested-git-dir"),
    ("Audit Workflow Checkout V4", "audit-workflow-checkout-v4"),
    ("Audit Workflow No Node 16 Actions", "audit-workflow-no-node-16-actions"),
    ("Audit Workflow Explicit Bash Shell", "audit-workflow-explicit-bash-shell"),
    ("Audit Workflow No Empty Run Blocks", "audit-workflow-no-empty-run-blocks"),
    ("Audit Workflow Job Permissions Only", "audit-workflow-job-permissions-only"),
    ("Audit Workflow Timeout Reasonable", "audit-workflow-timeout-reasonable"),
    ("Audit Workflow Kebab Filenames Strict", "audit-workflow-kebab-filenames-strict"),
    ("Audit Workflow No Absolute Script Paths", "audit-workflow-no-absolute-script-paths"),
    ("Audit Workflow Unused Workflow Inputs", "audit-workflow-unused-workflow-inputs"),
    ("Audit Workflow No GitHub Token Leak", "audit-workflow-no-github-token-leak"),
    ("Audit Repo No Temp Files", "audit-repo-no-temp-files"),
    ("Audit Repo Lowercase Directories", "audit-repo-lowercase-directories"),
    ("Audit Repo Snake Case Scripts", "audit-repo-snake-case-scripts"),
    ("Audit Workflow Extension Strict", "audit-workflow-extension-strict"),
    ("Audit Build SH No skippgpcheck", "audit-build-sh-no-skippgpcheck"),
    ("Audit Repo TODO Format", "audit-repo-todo-format"),
    ("Audit Repo Contributing Existence", "audit-repo-contributing-existence"),
    ("Audit Repo Security Existence", "audit-repo-security-existence"),
    ("Audit Build SH Parallel Downloads", "audit-build-sh-parallel-downloads"),
    ("Audit Repo No Large Binaries", "audit-repo-no-large-binaries"),
    ("Audit Workflow Job ID Kebab Case", "audit-workflow-job-id-kebab-case"),
    ("Audit Workflow Concurrency Val", "audit-workflow-concurrency-val"),
    ("Audit Repo No Broken Symlinks", "audit-repo-no-broken-symlinks"),
    ("Audit Build SH Shebang Strict", "audit-build-sh-shebang-strict"),
    ("Audit Repo No Empty Folders", "audit-repo-no-empty-folders"),
]

template = """name: {name}

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]
  workflow_dispatch:

permissions:
  contents: read

concurrency:
  group: ${{{{ github.workflow }}}}-${{{{ github.ref }}}}
  cancel-in-progress: true

jobs:
  audit:
    runs-on: ubuntu-latest
    timeout-minutes: 10
    steps:
      - uses: actions/checkout@v4
      - name: Run Audit
        run: bash scripts/repo_audit.sh --check {check}
"""

os.makedirs(".github/workflows", exist_ok=True)

# Clean up existing generated workflows to handle renamed files
for f in os.listdir(".github/workflows"):
    if f.startswith("audit-") and f.endswith(".yml"):
        os.remove(os.path.join(".github/workflows", f))

for name, check in workflows:
    filename = f".github/workflows/{check}.yml"
    content = template.format(name=name, check=check)
    with open(filename, "w") as f:
        f.write(content)
    print(f"Generated {filename}")

print(f"Successfully generated {len(workflows)} workflows.")
