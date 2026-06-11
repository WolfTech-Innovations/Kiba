import os

# Define the 45 workflows to generate
# Each entry is (filename, workflow_name, content_template)

WORKFLOW_DIR = ".github/workflows"
os.makedirs(WORKFLOW_DIR, exist_ok=True)

def generate_workflow(filename, name, content):
    with open(os.path.join(WORKFLOW_DIR, filename), "w") as f:
        f.write(content)

workflows = [
    ("actionlint.yml", "Actionlint", """name: Actionlint
on:
  push:
    paths:
      - '.github/workflows/**'
  pull_request:
    paths:
      - '.github/workflows/**'
  workflow_dispatch:

jobs:
  actionlint:
    runs-on: ubuntu-latest
    timeout-minutes: 5
    steps:
      - uses: actions/checkout@v4
      - name: Run actionlint
        uses: reviewdog/action-actionlint@v1
"""),
    ("auto-assign.yml", "Auto Assign", """name: Auto Assign
on:
  pull_request:
    types: [opened, ready_for_review]

jobs:
  assign:
    runs-on: ubuntu-latest
    timeout-minutes: 5
    permissions:
      pull-requests: write
    steps:
      - name: Assign author
        uses: actions/github-script@v7
        with:
          script: |
            github.rest.issues.addAssignees({
              owner: context.repo.owner,
              repo: context.repo.repo,
              issue_number: context.issue.number,
              assignees: [context.payload.pull_request.user.login]
            })
"""),
    ("auto-merge.yml", "Auto Merge", """name: Auto Merge
on:
  pull_request:
    types:
      - labeled
      - synchronize
      - opened
      - edited
      - ready_for_review
      - reopened
      - unlocked
  pull_request_review:
    types:
      - submitted
  check_suite:
    types:
      - completed
  status: {}

jobs:
  automerge:
    runs-on: ubuntu-latest
    timeout-minutes: 5
    if: github.event.pull_request.user.login == 'dependabot[bot]'
    steps:
      - id: automerge
        uses: "pascalgn/automerge-action@v0.16.4"
        env:
          GITHUB_TOKEN: "${{ secrets.GITHUB_TOKEN }}"
"""),
    ("bandit.yml", "Bandit", """name: Bandit
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  workflow_dispatch:

jobs:
  bandit:
    runs-on: ubuntu-latest
    timeout-minutes: 10
    steps:
      - uses: actions/checkout@v4
      - name: Install Bandit
        run: pip install bandit
      - name: Run Bandit
        run: bandit -r . -ll
"""),
    ("broken-link-checker.yml", "Broken Link Checker", """name: Broken Link Checker
on:
  push:
    paths:
      - '**.md'
  pull_request:
    paths:
      - '**.md'
  schedule:
    - cron: '0 0 * * 0'
  workflow_dispatch:

jobs:
  link-checker:
    runs-on: ubuntu-latest
    timeout-minutes: 20
    steps:
      - uses: actions/checkout@v4
      - name: Link Checker
        uses: lycheeverse/lychee-action@v2
        with:
          args: --verbose --no-progress '**/*.md'
"""),
    ("cachyos-kernel-monitor.yml", "CachyOS Kernel Monitor", """name: Monitor CachyOS Kernel
on:
  schedule:
    - cron: '0 */6 * * *'
  workflow_dispatch:

jobs:
  check-kernel:
    runs-on: ubuntu-latest
    timeout-minutes: 5
    steps:
      - name: Check latest version
        run: |
          curl -s https://mirror.cachyos.org/cachyos/x86_64/ | grep linux-cachyos | tail -n 1
"""),
    ("check-commit-message.yml", "Commit Lint", """name: Commit Lint
on: [pull_request]

jobs:
  commitlint:
    runs-on: ubuntu-latest
    timeout-minutes: 5
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - uses: pnpm/action-setup@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: 'pnpm'
      - run: pnpm install
      - run: pnpm exec commitlint --from ${{ github.event.pull_request.base.sha }} --to ${{ github.event.pull_request.head.sha }} --verbose
"""),
    ("check-issue-templates.yml", "Issue Template Validator", """name: Issue Template Validator
on:
  push:
    paths:
      - '.github/ISSUE_TEMPLATE/**'
  pull_request:
    paths:
      - '.github/ISSUE_TEMPLATE/**'

jobs:
  validate:
    runs-on: ubuntu-latest
    timeout-minutes: 5
    steps:
      - uses: actions/checkout@v4
      - name: Validate YAML
        run: |
          for f in .github/ISSUE_TEMPLATE/*.yml; do
            [ -e "$f" ] || continue
            python3 -c "import yaml, sys; yaml.safe_load(open('$f'))" || exit 1
          done
"""),
    ("check-license-headers.yml", "License Header Enforcer", """name: License Header Check
on: [push, pull_request]

jobs:
  license-check:
    runs-on: ubuntu-latest
    timeout-minutes: 5
    steps:
      - uses: actions/checkout@v4
      - name: Check MIT Header
        run: |
          grep -r "License: MIT" . --include="*.sh" --include="*.py"
"""),
    ("check-pnpm-lock.yml", "pnpm Integrity Check", """name: pnpm Integrity Check
on: [push, pull_request]

jobs:
  check-lock:
    runs-on: ubuntu-latest
    timeout-minutes: 5
    steps:
      - uses: actions/checkout@v4
      - uses: pnpm/action-setup@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: 'pnpm'
      - run: pnpm install --frozen-lockfile
"""),
    ("check-python-syntax.yml", "Python Syntax Check", """name: Python Syntax Check
on: [push, pull_request]

jobs:
  syntax:
    runs-on: ubuntu-latest
    timeout-minutes: 5
    steps:
      - uses: actions/checkout@v4
      - name: Compile check
        run: python3 -m py_compile scripts/*.py *.py
"""),
    ("check-shell-script-lint.yml", "ShellCheck", """name: ShellCheck
on: [push, pull_request]

jobs:
  shellcheck:
    runs-on: ubuntu-latest
    timeout-minutes: 10
    steps:
      - uses: actions/checkout@v4
      - name: Run ShellCheck
        uses: ludeeus/action-shellcheck@master
"""),
    ("check-yaml-syntax.yml", "YAML Lint", """name: YAML Lint
on: [push, pull_request]

jobs:
  yaml-lint:
    runs-on: ubuntu-latest
    timeout-minutes: 5
    steps:
      - uses: actions/checkout@v4
      - name: YAML Lint
        uses: ibiqlik/action-yamllint@v3
"""),
    ("check-json-syntax.yml", "JSON Lint", """name: JSON Lint
on: [push, pull_request]

jobs:
  json-lint:
    runs-on: ubuntu-latest
    timeout-minutes: 5
    steps:
      - uses: actions/checkout@v4
      - uses: pnpm/action-setup@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: 'pnpm'
      - run: pnpm install
      - name: JSON Lint
        run: find . -name "*.json" -not -path "*/node_modules/*" | xargs pnpm exec jsonlint -q
"""),
    ("check-markdown-lint.yml", "Markdown Lint", """name: Markdown Lint
on: [push, pull_request]

jobs:
  markdown-lint:
    runs-on: ubuntu-latest
    timeout-minutes: 5
    steps:
      - uses: actions/checkout@v4
      - name: markdownlint-cli
        uses: nosoterry/markdownlint-action@v3
        with:
          config: .github/markdownlint.json
"""),
    ("close-inactive-prs.yml", "Close Inactive PRs", """name: Close Inactive PRs
on:
  schedule:
    - cron: '30 1 * * *'
  workflow_dispatch:

jobs:
  close-stale:
    runs-on: ubuntu-latest
    timeout-minutes: 5
    steps:
      - uses: actions/stale@v9
        with:
          stale-pr-message: 'This PR is stale because it has been open 30 days with no activity.'
          days-before-pr-stale: 30
          days-before-pr-close: 7
          stale-pr-label: 'stale'
"""),
    ("codeql.yml", "CodeQL", """name: "CodeQL"
on:
  push:
    branches: [ "main" ]
  pull_request:
    branches: [ "main" ]
  schedule:
    - cron: '21 16 * * 1'

jobs:
  analyze:
    name: Analyze
    runs-on: ubuntu-latest
    timeout-minutes: 360
    permissions:
      actions: read
      contents: read
      security-events: write

    steps:
    - name: Checkout repository
      uses: actions/checkout@v4

    - name: Initialize CodeQL
      uses: github/codeql-action/init@v3
      with:
        languages: 'python, javascript'

    - name: Perform CodeQL Analysis
      uses: github/codeql-action/analyze@v3
"""),
    ("codespell.yml", "Spell Check", """name: Spell Check
on: [push, pull_request]

jobs:
  codespell:
    runs-on: ubuntu-latest
    timeout-minutes: 5
    steps:
      - uses: actions/checkout@v4
      - uses: codespell-project/actions-codespell@v2
        with:
          ignore_words_file: .codespellignore
          skip: "./.git,./pnpm-lock.yaml"
"""),
    ("contributors-list-manager.yml", "Update Contributors", """name: Update Contributors
on:
  push:
    branches: [main]
  workflow_dispatch:

jobs:
  update-contributors:
    runs-on: ubuntu-latest
    timeout-minutes: 10
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - name: Update contributors
        run: |
          git log --format='%aN <%aE>' | sort -u > CONTRIBUTORS
"""),
    ("dependabot-auto-approve.yml", "Dependabot Auto-Approve", """name: Dependabot Auto-Approve
on: pull_request

permissions:
  pull-requests: write

jobs:
  dependabot:
    runs-on: ubuntu-latest
    if: github.actor == 'dependabot[bot]'
    steps:
      - name: Dependabot metadata
        id: metadata
        uses: dependabot/fetch-metadata@v2
      - name: Approve a PR
        run: gh pr review --approve "$PR_URL"
        env:
          PR_URL: ${{github.event.pull_request.html_url}}
          GITHUB_TOKEN: ${{secrets.GITHUB_TOKEN}}
"""),
    ("dependency-vulnerability-scan.yml", "Dependency Vulnerability Monitor", """name: Dependency Vulnerability Monitor
on:
  schedule:
    - cron: '0 12 * * *'
  workflow_dispatch:

jobs:
  audit:
    runs-on: ubuntu-latest
    timeout-minutes: 10
    steps:
      - uses: actions/checkout@v4
      - uses: pnpm/action-setup@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: 'pnpm'
      - run: pnpm audit
"""),
    ("gitleaks.yml", "Gitleaks", """name: Gitleaks
on:
  push:
  pull_request:
  workflow_dispatch:

jobs:
  scan:
    runs-on: ubuntu-latest
    timeout-minutes: 10
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - uses: gitleaks/gitleaks-action@v2
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
"""),
    ("greetings.yml", "Greetings", """name: Greetings
on: [pull_request, issues]

jobs:
  greeting:
    runs-on: ubuntu-latest
    timeout-minutes: 5
    steps:
      - uses: actions/first-interaction@v1
        with:
          repo-token: ${{ secrets.GITHUB_TOKEN }}
          issue-message: 'Welcome to the KibaOS issue tracker! We appreciate your feedback.'
          pr-message: 'Thank you for your first pull request to KibaOS! We will review it soon.'
"""),
    ("integrity-manifest-generator.yml", "Integrity Manifest Generator", """name: Integrity Manifest Generator
on:
  push:
    branches: [main]
  workflow_dispatch:

jobs:
  manifest:
    runs-on: ubuntu-latest
    timeout-minutes: 10
    steps:
      - uses: actions/checkout@v4
      - name: Generate manifest
        run: find . -type f -not -path "./.git/*" -exec sha256sum {} + > manifest.sha256
"""),
    ("issue-labeler.yml", "Issue Component Labeler", """name: Issue Component Labeler
on:
  issues:
    types: [opened, edited]

jobs:
  labeler:
    runs-on: ubuntu-latest
    timeout-minutes: 5
    permissions:
      issues: write
    steps:
      - uses: actions/github-script@v7
        with:
          script: |
            const body = context.payload.issue.body.toLowerCase();
            if (body.includes('branding')) {
              await github.rest.issues.addLabels({
                owner: context.repo.owner,
                repo: context.repo.repo,
                issue_number: context.issue.number,
                labels: ['component: branding']
              });
            }
"""),
    ("lock-threads.yml", "Lock Threads", """name: Lock Threads
on:
  schedule:
    - cron: '0 0 * * *'
  workflow_dispatch:

jobs:
  lock:
    runs-on: ubuntu-latest
    timeout-minutes: 10
    steps:
      - uses: dessant/lock-threads@v5
        with:
          issue-inactive-days: '30'
          pr-inactive-days: '30'
"""),
    ("manual-release.yml", "Manual Release", """name: Manual Release
on:
  workflow_dispatch:
    inputs:
      version:
        description: 'Version tag (e.g. v1.0.0)'
        required: true

jobs:
  release:
    runs-on: ubuntu-latest
    timeout-minutes: 20
    steps:
      - uses: actions/checkout@v4
      - name: Create Release
        uses: softprops/action-gh-release@v2
        with:
          tag_name: ${{ github.event.inputs.version }}
          generate_release_notes: true
"""),
    ("package-json-validator.yml", "Package JSON Mandatory Metadata", """name: Package JSON Mandatory Metadata
on: [push, pull_request]

jobs:
  validate:
    runs-on: ubuntu-latest
    timeout-minutes: 5
    steps:
      - uses: actions/checkout@v4
      - name: Check required fields
        run: |
          jq -e '.name and .version and .private and .engines' package.json
"""),
    ("pr-size-labeler.yml", "Size Labeler", """name: Size Labeler
on: pull_request

jobs:
  size-label:
    runs-on: ubuntu-latest
    timeout-minutes: 5
    permissions:
      contents: read
      pull-requests: write
    steps:
      - uses: pascalgn/size-label-action@v0.5.5
        env:
          GITHUB_TOKEN: "${{ secrets.GITHUB_TOKEN }}"
"""),
    ("prettier.yml", "Prettier", """name: Prettier
on: [push, pull_request]

jobs:
  prettier:
    runs-on: ubuntu-latest
    timeout-minutes: 10
    steps:
      - uses: actions/checkout@v4
      - uses: pnpm/action-setup@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: 'pnpm'
      - run: pnpm install
      - run: pnpm exec prettier --check .
"""),
    ("release-drafter.yml", "Release Drafter", """name: Release Drafter
on:
  push:
    branches:
      - main
  pull_request:
    types: [opened, reopened, synchronize]

jobs:
  update_release_draft:
    runs-on: ubuntu-latest
    timeout-minutes: 10
    permissions:
      contents: write
      pull-requests: read
    steps:
      - uses: release-drafter/release-drafter@v6
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
"""),
    ("repo-audit.yml", "Repository Comprehensive Audit", """name: Repository Comprehensive Audit
on:
  push:
    branches: [main]
  pull_request:
  workflow_dispatch:

jobs:
  audit:
    runs-on: ubuntu-latest
    timeout-minutes: 15
    steps:
      - uses: actions/checkout@v4
      - name: Run repo_audit.sh
        run: bash scripts/repo_audit.sh
"""),
    ("repo-stats.yml", "Repo Stats", """name: Repo Stats
on:
  schedule:
    - cron: '0 0 * * 1'
  workflow_dispatch:

jobs:
  stats:
    runs-on: ubuntu-latest
    timeout-minutes: 10
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - name: Generate stats
        run: |
          echo "Commits: $(git rev-list --count HEAD)"
          echo "Files: $(find . -type f | wc -l)"
"""),
    ("scorecards.yml", "Scorecard supply-chain security", """name: Scorecard supply-chain security
on:
  branch_protection_rule:
  schedule:
    - cron: '37 20 * * 4'
  push:
    branches: [ "main" ]

permissions: read-all

jobs:
  analysis:
    name: Scorecard analysis
    runs-on: ubuntu-latest
    timeout-minutes: 10
    permissions:
      security-events: write
      id-token: write

    steps:
      - name: "Checkout code"
        uses: actions/checkout@v4
        with:
          persist-credentials: false

      - name: "Run analysis"
        uses: ossf/scorecard-action@v2.4.0
        with:
          results_file: results.sarif
          results_format: sarif
          publish_results: true

      - name: "Upload artifact"
        uses: actions/upload-artifact@v4
        with:
          name: SARIF file
          path: results.sarif
          retention-days: 5
"""),
    ("semgrep.yml", "Semgrep", """name: Semgrep
on:
  push:
    branches: [main]
  pull_request:
  workflow_dispatch:

jobs:
  semgrep:
    runs-on: ubuntu-latest
    timeout-minutes: 20
    container:
      image: returntocorp/semgrep
    steps:
      - uses: actions/checkout@v4
      - run: semgrep scan --error --config auto
"""),
    ("stale-closer.yml", "Stale Closer", """name: Stale Closer
on:
  schedule:
    - cron: '0 0 * * *'
  workflow_dispatch:

jobs:
  stale:
    runs-on: ubuntu-latest
    timeout-minutes: 10
    steps:
      - uses: actions/stale@v9
        with:
          days-before-stale: 60
          days-before-close: 7
          stale-issue-message: 'This issue is stale because it has been open 60 days with no activity.'
          stale-issue-label: 'stale'
"""),
    ("todo-checker.yml", "TODO Comment Tracker", """name: TODO Comment Tracker
on: [push, pull_request]

jobs:
  todo:
    runs-on: ubuntu-latest
    timeout-minutes: 5
    steps:
      - uses: actions/checkout@v4
      - name: Find TODOs
        run: |
          grep -rn "TODO" . --exclude-dir=.git || true
"""),
    ("trivy.yml", "Trivy", """name: Trivy
on:
  push:
    branches: [main]
  pull_request:
  workflow_dispatch:

jobs:
  scan:
    runs-on: ubuntu-latest
    timeout-minutes: 20
    steps:
      - uses: actions/checkout@v4
      - name: Run Trivy vulnerability scanner
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: 'fs'
          format: 'table'
          exit-code: '1'
          severity: 'CRITICAL,HIGH'
"""),
    ("workflow-documentation-generator.yml", "Workflow Documentation Generator", """name: Workflow Documentation Generator
on:
  push:
    paths:
      - '.github/workflows/**'
  workflow_dispatch:

jobs:
  update-docs:
    runs-on: ubuntu-latest
    timeout-minutes: 10
    steps:
      - uses: actions/checkout@v4
      - name: Run update script
        run: python3 scripts/update_workflow_md.py
      - name: Commit changes
        run: |
          git config --local user.email "action@github.com"
          git config --local user.name "GitHub Action"
          git add WORKFLOWS.md
          git diff --quiet && git diff --staged --quiet || git commit -m "docs: update WORKFLOWS.md"
"""),
    ("zsh-syntax-check.yml", "Check Zshrc Performance", """name: Check Zshrc Performance
on: [push, pull_request]

jobs:
  zsh-lint:
    runs-on: ubuntu-latest
    timeout-minutes: 5
    steps:
      - uses: actions/checkout@v4
      - name: Install zsh
        run: sudo apt-get update && sudo apt-get install -y zsh
      - name: Syntax check
        run: |
          for f in branding/*.zsh; do
            [ -e "$f" ] || continue
            zsh -n "$f"
          done
"""),
    ("branding-assets-validator.yml", "Branding Assets Validator", """name: Branding Assets Validator
on: [push, pull_request]

jobs:
  validate:
    runs-on: ubuntu-latest
    timeout-minutes: 5
    steps:
      - uses: actions/checkout@v4
      - name: Check assets
        run: |
          ls branding/boot.png
          ls branding/forest-k.png
"""),
    ("build-iso-dry-run.yml", "Analyze PR ISO Impact", """name: Analyze PR ISO Impact
on: pull_request

jobs:
  dry-run:
    runs-on: ubuntu-latest
    timeout-minutes: 30
    steps:
      - uses: actions/checkout@v4
      - name: Shell syntax check
        run: bash -n build.sh
"""),
    ("calamares-config-linter.yml", "Calamares Config Linter", """name: Calamares Config Linter
on: [push, pull_request]

jobs:
  lint:
    runs-on: ubuntu-latest
    timeout-minutes: 5
    steps:
      - uses: actions/checkout@v4
      - name: YAML check
        run: |
          find . -name "*.conf" -exec python3 -c "import yaml, sys; yaml.safe_load(open('{}'))" ";"
"""),
    ("desktop-entry-validator.yml", "Desktop Entry Validator", """name: Desktop Entry Validator
on: [push, pull_request]

jobs:
  validate:
    runs-on: ubuntu-latest
    timeout-minutes: 5
    steps:
      - uses: actions/checkout@v4
      - name: desktop-file-validate
        run: |
          sudo apt-get update && sudo apt-get install -y desktop-file-utils
          find . -name "*.desktop" -exec desktop-file-validate {} +
"""),
    ("security-policy-audit.yml", "Audit Security Policy", """name: Audit Security Policy
on: [push, pull_request]

jobs:
  audit:
    runs-on: ubuntu-latest
    timeout-minutes: 5
    steps:
      - uses: actions/checkout@v4
      - name: Check SECURITY.md
        run: |
          grep -i "vulnerability" SECURITY.md
          grep -i "reporting" SECURITY.md
""")
]

if __name__ == "__main__":
    for filename, name, content in workflows:
        generate_workflow(filename, name, content)
    print(f"Successfully generated {len(workflows)} workflows in {WORKFLOW_DIR}")
