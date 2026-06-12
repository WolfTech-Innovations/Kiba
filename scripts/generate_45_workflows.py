import os

def main():
    workflows_dir = ".github/workflows"
    os.makedirs(workflows_dir, exist_ok=True)

    # Note: Logic is now fixed.
    # For audits that search for BAD patterns: ! grep -r pattern ... || (error)
    # For audits that search for GOOD patterns: grep -r pattern ... || (error)
    workflows = [
        ("audit-build-sh-customize-set-e.yml", "Audit Build SH Customize Set E", "grep -A 2 'cat > \"${AIROOTFS}/root/customize_airootfs.sh\"' build.sh | grep -q 'set -e'", "build.sh", "Missing 'set -e' in customize_airootfs.sh inside build.sh"),
        ("audit-build-sh-pacman-populate.yml", "Audit Build SH Pacman Populate", "grep -q 'pacman-key --populate archlinux' build.sh", "build.sh", "Missing 'pacman-key --populate archlinux' in build.sh"),
        ("audit-build-sh-relative-symlinks.yml", "Audit Build SH Relative Symlinks", "! grep -q 'ln -s /' build.sh", "build.sh", "Absolute symlinks found in build.sh (use relative)"),
        ("audit-build-sh-paperde-ldconfig.yml", "Audit Build SH PaperDE ldconfig", "grep -A 20 'ninja -C paperde-src/build install' build.sh | grep -q 'ldconfig'", "build.sh", "Missing 'ldconfig' after PaperDE installation in build.sh"),
        ("audit-build-sh-desktop-entry-kiba.yml", "Audit Build SH Desktop Entry Kiba", "grep -q 'kiba-welcome.desktop' build.sh", "build.sh", "Kiba welcome desktop entry missing in build.sh"),
        ("audit-build-sh-sudoers-perms.yml", "Audit Build SH Sudoers Perms", "! grep -q 'chmod 777 /etc/sudoers' build.sh", "build.sh", "Dangerous sudoers permissions in build.sh"),
        ("audit-build-sh-liveuser-uid.yml", "Audit Build SH Liveuser UID", "grep 'liveuser' build.sh | grep -q '1000:1000'", "build.sh", "Liveuser UID/GID is not 1000 in build.sh"),
        ("audit-build-sh-wallpaper-consistency.yml", "Audit Build SH Wallpaper Consistency", "grep -q 'branding/wallpaper.png' build.sh", "build.sh", "Default wallpaper path inconsistency in build.sh"),
        ("audit-build-sh-octopi-usage.yml", "Audit Build SH Octopi Usage", "grep -q 'octopi' build.sh", "build.sh", "Octopi notifier missing in build.sh"),
        ("audit-build-sh-zsh-default.yml", "Audit Build SH Zsh Default", "grep -q 'chsh -s /usr/bin/zsh' build.sh", "build.sh", "Zsh not set as default shell in build.sh"),
        ("audit-repo-trailing-whitespace.yml", "Audit Repo Trailing Whitespace", "! grep -rI '[[:blank:]]$' . --exclude-dir=.git --exclude-dir=node_modules --exclude='pnpm-lock.yaml' --exclude='*.png' --exclude='*.jpg'", "*", "Trailing whitespace found"),
        ("audit-repo-no-chmod-777.yml", "Audit Repo No Chmod 777", "! grep -rE 'chmod (0?777|777)' . --exclude-dir=.git --exclude-dir=node_modules --exclude=repo_audit.sh --exclude=generate_45_workflows.py --exclude='audit-*.yml'", "*", "Dangerous chmod 777 found"),
        ("audit-repo-no-plaintext-chpasswd.yml", "Audit Repo No Plaintext Chpasswd", "! grep -r 'chpasswd' . | grep -v '\\-e' | grep .", "*", "Plaintext password used with chpasswd (use -e)"),
        ("audit-repo-gitkeep-empty.yml", "Audit Repo Gitkeep Empty", "! find . -name '.gitkeep' -type f -size +0 | grep .", ".gitkeep", ".gitkeep files must be empty"),
        ("audit-repo-no-nested-git.yml", "Audit Repo No Nested Git", "! find . -mindepth 2 -name '.git' -type d | grep .", ".git", "Nested .git directories found"),
        ("audit-repo-lowercase-dirs.yml", "Audit Repo Lowercase Directories", "! find . -maxdepth 2 -type d -name '*[A-Z]*' --exclude-dir=.git --exclude-dir=node_modules --exclude-dir=Notes | grep .", "*", "Directories should be lowercase"),
        ("audit-repo-snake-case-scripts.yml", "Audit Repo Snake Case Scripts", "! find . -name '*.sh' -not -path './node_modules/*' | grep -E '[A-Z-]' | grep .", "*.sh", "Shell scripts should use snake_case"),
        ("audit-repo-license-presence.yml", "Audit Repo License Presence", "[ -f LICENSE ]", "LICENSE", "LICENSE file missing"),
        ("audit-repo-readme-mandatory-sections.yml", "Audit Repo README Mandatory Sections", "grep -q '## Table of Contents' README.md", "README.md", "README missing Table of Contents"),
        ("audit-repo-dot-env-forbidden.yml", "Audit Repo Dot Env Forbidden", "! find . -name '.env' -not -path './node_modules/*' | grep .", ".env", ".env files should not be committed"),
        ("audit-workflow-checkout-v4.yml", "Audit Workflow Checkout V4", "! grep -r 'uses: actions/checkout@' .github/workflows/ | grep -vE '@v4|@[a-f0-9]{40}' | grep .", ".github/workflows/*.yml", "actions/checkout should use v4"),
        ("audit-workflow-no-node-16.yml", "Audit Workflow No Node 16", "! grep -r 'node-version:.*16' .github/workflows/ | grep .", ".github/workflows/*.yml", "Node 16 is EOL, use 20+"),
        ("audit-workflow-explicit-bash.yml", "Audit Workflow Explicit Bash", "! grep -r 'run:' .github/workflows/ | grep -v 'shell: bash' | grep .", ".github/workflows/*.yml", "Explicit 'shell: bash' recommended for run blocks"),
        ("audit-workflow-timeout-minutes.yml", "Audit Workflow Timeout Minutes", "grep -r 'jobs:' .github/workflows/ -A 20 | grep -q 'timeout-minutes'", ".github/workflows/*.yml", "Jobs should have timeout-minutes"),
        ("audit-workflow-permissions-least-privilege.yml", "Audit Workflow Permissions", "grep -r 'permissions:' .github/workflows/", ".github/workflows/*.yml", "Workflows should have explicit permissions"),
        ("audit-workflow-no-empty-run.yml", "Audit Workflow No Empty Run", "! grep -r 'run: \"\"' .github/workflows/ | grep .", ".github/workflows/*.yml", "Empty run blocks found"),
        ("audit-workflow-kebab-filenames.yml", "Audit Workflow Kebab Filenames", "! find .github/workflows -name '*_*' | grep .", ".github/workflows/*.yml", "Workflow filenames should use kebab-case"),
        ("audit-workflow-no-token-leak.yml", "Audit Workflow No Token Leak", "! grep -rE 'echo.*(github\\.token|secrets\\.)' .github/workflows/ | grep .", ".github/workflows/*.yml", "Potential token/secret leak via echo"),
        ("audit-workflow-concurrency-cancel.yml", "Audit Workflow Concurrency Cancel", "grep -r 'concurrency:' .github/workflows/ -A 5 | grep -q 'cancel-in-progress'", ".github/workflows/*.yml", "Concurrency should have cancel-in-progress"),
        ("audit-workflow-job-id-kebab.yml", "Audit Workflow Job ID Kebab", "! grep -rE '^[ ]{2}[a-z0-9]+_[a-z0-9]+:' .github/workflows/ | grep .", ".github/workflows/*.yml", "Job IDs should use kebab-case"),
        ("audit-markdown-empty-links.yml", "Audit Markdown Empty Links", "! grep -rE '\\[[^]]*\\]\\(\\)' . --include='*.md' --exclude-dir=node_modules | grep .", "*.md", "Empty markdown links found"),
        ("audit-markdown-internal-anchors.yml", "Audit Markdown Internal Anchors", "! grep -rhE '\\[[^]]+\\]\\(#[^)]+\\)' . --include='*.md' --exclude-dir=node_modules | grep -vE '\\(#[a-z0-9-]+\\)' | grep .", "*.md", "Internal anchors should be #lowercase-kebab"),
        ("audit-markdown-atx-headings.yml", "Audit Markdown ATX Headings", "! grep -r '^[^#].*===$' . --include='*.md' --exclude-dir=node_modules | grep .", "*.md", "Use ATX-style headings (#)"),
        ("audit-markdown-no-tabs.yml", "Audit Markdown No Tabs", "! grep -rP '\\t' . --include='*.md' --exclude-dir=node_modules | grep .", "*.md", "Markdown files should not contain tabs"),
        ("audit-markdown-header-punctuation.yml", "Audit Markdown Header Punctuation", "! grep -rE '^#+ .*[.!?]$' . --include='*.md' --exclude-dir=node_modules | grep .", "*.md", "Headings should not end with punctuation"),
        ("audit-markdown-ordered-list-consistency.yml", "Audit Markdown Ordered List Consistency", "! grep -rE '^[0-9]\\) ' . --include='*.md' --exclude-dir=node_modules | grep .", "*.md", "Use '1.' for ordered lists, not '1)'"),
        ("audit-markdown-no-fixme.yml", "Audit Markdown No Fixme", "! grep -ri 'FIXME' . --include='*.md' --exclude-dir=node_modules | grep .", "*.md", "FIXME found in documentation"),
        ("audit-markdown-fenced-code-blocks.yml", "Audit Markdown Fenced Code Blocks", "! grep -r '^    ' . --include='*.md' --exclude-dir=node_modules | grep .", "*.md", "Use fenced code blocks instead of indentation"),
        ("audit-markdown-hr-style.yml", "Audit Markdown HR Style", "! grep -r '^\\*\\*\\*$' . --include='*.md' --exclude-dir=node_modules | grep .", "*.md", "Use '---' for horizontal rules"),
        ("audit-markdown-link-title-quotes.yml", "Audit Markdown Link Title Quotes", "! grep -rE '\\[.*\\]\\(.* \".*\"\\)' . --include='*.md' --exclude-dir=node_modules | grep -v \"'\" | grep .", "*.md", "Use single quotes for link titles"),
        ("check-json-syntax.yml", "Check JSON Syntax", "find . -name '*.json' -not -path '*/node_modules/*' | xargs -I {} npx jsonlint -q {}", "*.json", "JSON syntax error"),
        ("check-package-json-engines.yml", "Check package.json Engines", "grep -q '\"engines\"' package.json", "package.json", "package.json missing 'engines' field"),
        ("check-pnpm-lock-sync.yml", "Check PNPM Lock Sync", "pnpm install --frozen-lockfile", "pnpm-lock.yaml", "pnpm-lock.yaml out of sync"),
        ("check-commit-message-quality.yml", "Check Commit Message Quality", "npx commitlint --from=HEAD~1", "git", "Commit message does not follow conventional commits"),
        ("check-security-contact-info.yml", "Check Security Contact Info", "grep -q 'security@' SECURITY.md", "SECURITY.md", "SECURITY.md missing contact email")
    ]

    for filename, name, cmd, include, error_msg in workflows:
        content = f"""name: "{name}"
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  workflow_dispatch:

jobs:
  audit:
    runs-on: ubuntu-latest
    permissions:
      contents: read
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Run audit
        shell: bash
        run: |
          {cmd} || (echo "::error::{error_msg}" && exit 1)
"""
        # Special case for pnpm
        if "pnpm" in cmd:
             content = f"""name: "{name}"
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  workflow_dispatch:

jobs:
  audit:
    runs-on: ubuntu-latest
    permissions:
      contents: read
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Setup Node
        uses: actions/setup-node@v4
        with:
          node-version: 20

      - name: Install pnpm
        uses: pnpm/action-setup@v4
        with:
          version: 9

      - name: Run audit
        shell: bash
        run: |
          {cmd} || (echo "::error::{error_msg}" && exit 1)
"""

        # Special case for commitlint
        if "commitlint" in cmd:
             content = f"""name: "{name}"
on:
  pull_request:
    branches: [main]
  workflow_dispatch:

jobs:
  audit:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      pull-requests: read
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Setup Node
        uses: actions/setup-node@v4
        with:
          node-version: 20

      - name: Install dependencies
        run: pnpm install

      - name: Run audit
        shell: bash
        run: |
          npx commitlint --from=${{{{ github.event.pull_request.base.sha }}}} --to=${{{{ github.event.pull_request.head.sha }}}} || (echo "::error::{error_msg}" && exit 1)
"""

        with open(os.path.join(workflows_dir, filename), "w") as f:
            f.write(content)

    print(f"Generated {len(workflows)} workflows in {workflows_dir}")

if __name__ == "__main__":
    main()
