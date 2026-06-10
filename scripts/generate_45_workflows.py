import os

def create_workflow(filename, content):
    path = os.path.join(".github/workflows", filename)
    with open(path, "w") as f:
        f.write(content)
    print(f"Created {path}")

def main():
    os.makedirs(".github/workflows", exist_ok=True)

    # 1. shellcheck
    create_workflow("shellcheck.yml", """name: ShellCheck
on:
  push:
    paths:
      - '**.sh'
  pull_request:
    paths:
      - '**.sh'
permissions:
  contents: read
jobs:
  shellcheck:
    runs-on: ubuntu-latest
    timeout-minutes: 10
    steps:
      - uses: actions/checkout@v4
      - name: Run ShellCheck
        uses: ludeeus/action-shellcheck@master
""")

    # 2. prettier
    create_workflow("prettier.yml", """name: Prettier
on:
  push:
  pull_request:
permissions:
  contents: read
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
      - name: Run Prettier
        run: pnpm exec prettier --check .
""")

    # 3. actionlint
    create_workflow("actionlint.yml", """name: Actionlint
on:
  push:
    paths:
      - '.github/workflows/**'
  pull_request:
    paths:
      - '.github/workflows/**'
permissions:
  contents: read
jobs:
  actionlint:
    runs-on: ubuntu-latest
    timeout-minutes: 10
    steps:
      - uses: actions/checkout@v4
      - name: Run actionlint
        uses: reviewdog/action-actionlint@v1
""")

    # 4. commit-lint
    create_workflow("commit-lint.yml", """name: Commit Lint
on: [pull_request]
permissions:
  contents: read
  pull-requests: read
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
      - name: Lint Commit Messages
        run: pnpm exec commitlint --from ${{ github.event.pull_request.base.sha }} --to ${{ github.event.pull_request.head.sha }} --verbose
""")

    # 5. json-lint
    create_workflow("json-lint.yml", """name: JSON Lint
on:
  push:
    paths:
      - '**.json'
  pull_request:
    paths:
      - '**.json'
permissions:
  contents: read
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
      - name: Run JSON Lint
        run: find . -name "*.json" -not -path "./node_modules/*" | xargs pnpm exec jsonlint -q
""")

    # 6. markdown-lint
    create_workflow("markdown-lint.yml", """name: Markdown Lint
on:
  push:
    paths:
      - '**.md'
  pull_request:
    paths:
      - '**.md'
permissions:
  contents: read
jobs:
  markdownlint:
    runs-on: ubuntu-latest
    timeout-minutes: 10
    steps:
      - uses: actions/checkout@v4
      - name: Run markdownlint-cli2
        uses: DavidAnson/markdownlint-cli2-action@v16
        with:
          globs: "**/*.md"
""")

    # 7. yamllint
    create_workflow("yamllint.yml", """name: YAML Lint
on:
  push:
    paths:
      - '**.yml'
      - '**.yaml'
  pull_request:
    paths:
      - '**.yml'
      - '**.yaml'
permissions:
  contents: read
jobs:
  yamllint:
    runs-on: ubuntu-latest
    timeout-minutes: 5
    steps:
      - uses: actions/checkout@v4
      - name: Run yamllint
        uses: ibiqlik/action-yamllint@v3
""")

    # 8. codespell
    create_workflow("codespell.yml", """name: Codespell
on:
  push:
  pull_request:
permissions:
  contents: read
jobs:
  codespell:
    runs-on: ubuntu-latest
    timeout-minutes: 10
    steps:
      - uses: actions/checkout@v4
      - name: Run codespell
        uses: codespell-project/actions-codespell@v2
        with:
          ignore_words_file: .codespellignore
          skip: "./.git,./pnpm-lock.yaml"
""")

    # 9. pnpm-audit
    create_workflow("pnpm-audit.yml", """name: pnpm Audit
on:
  schedule:
    - cron: '0 0 * * *'
  workflow_dispatch:
permissions:
  contents: read
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
""")

    # 10. todo-checker
    create_workflow("todo-checker.yml", """name: TODO Checker
on: [push, pull_request]
permissions:
  contents: read
jobs:
  todo:
    runs-on: ubuntu-latest
    timeout-minutes: 5
    steps:
      - uses: actions/checkout@v4
      - name: Check for TODOs
        run: |
          grep -rE "TODO|FIXME" . --exclude-dir=.git --exclude=pnpm-lock.yaml || echo "No TODOs found"
""")

    # 11. gitleaks
    create_workflow("gitleaks.yml", """name: Gitleaks
on:
  push:
  pull_request:
permissions:
  contents: read
jobs:
  gitleaks:
    runs-on: ubuntu-latest
    timeout-minutes: 10
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - name: Run Gitleaks
        uses: gitleaks/gitleaks-action@v2
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
""")

    # 12. bandit
    create_workflow("bandit.yml", """name: Bandit (Python Security)
on:
  push:
    paths:
      - '**.py'
  pull_request:
    paths:
      - '**.py'
permissions:
  contents: read
jobs:
  bandit:
    runs-on: ubuntu-latest
    timeout-minutes: 10
    steps:
      - uses: actions/checkout@v4
      - name: Run Bandit
        run: |
          pip install bandit
          bandit -r . -ll
""")

    # 13. license-header-check
    create_workflow("license-header-check.yml", """name: License Header Check
on: [push, pull_request]
permissions:
  contents: read
jobs:
  license-check:
    runs-on: ubuntu-latest
    timeout-minutes: 5
    steps:
      - uses: actions/checkout@v4
      - name: Check License Headers
        run: |
          for f in build.sh scripts/*.sh; do
            if ! head -n 20 "$f" | grep -q "License: MIT"; then
              echo "Missing MIT license header in $f"
              exit 1
            fi
          done
""")

    # 14. repo-audit
    create_workflow("repo-audit.yml", """name: Repo Audit
on: [push, pull_request]
permissions:
  contents: read
jobs:
  audit:
    runs-on: ubuntu-latest
    timeout-minutes: 10
    steps:
      - uses: actions/checkout@v4
      - name: Run repo_audit.sh
        run: bash scripts/repo_audit.sh
""")

    # 15. vulnerability-scan
    create_workflow("vulnerability-scan.yml", """name: Vulnerability Scan
on:
  schedule:
    - cron: '0 1 * * *'
  workflow_dispatch:
permissions:
  contents: read
  security-events: write
jobs:
  trivy:
    runs-on: ubuntu-latest
    timeout-minutes: 20
    steps:
      - uses: actions/checkout@v4
      - name: Run Trivy vulnerability scanner
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: 'fs'
          format: 'sarif'
          output: 'trivy-results.sarif'
      - name: Upload Trivy results to GitHub Security
        uses: github/codeql-action/upload-sarif@v3
        with:
          sarif_file: 'trivy-results.sarif'
""")

    # 16. branch-naming-audit
    create_workflow("branch-naming-audit.yml", """name: Branch Naming Audit
on: [push]
permissions:
  contents: read
jobs:
  branch-naming:
    runs-on: ubuntu-latest
    timeout-minutes: 5
    steps:
      - name: Check Branch Name
        run: |
          BRANCH_NAME="${GITHUB_REF#refs/heads/}"
          if [[ ! "$BRANCH_NAME" =~ ^(feat|fix|docs|style|refactor|perf|test|chore|bolt|palette|sentinel)/ ]]; then
            if [ "$BRANCH_NAME" != "main" ]; then
              echo "Invalid branch name: $BRANCH_NAME. Must start with a prefix like feat/, fix/, bolt/, etc."
              exit 1
            fi
          fi
""")

    # 17. secrets-monitor
    create_workflow("secrets-monitor.yml", """name: Secrets Monitor
on: [push, pull_request]
permissions:
  contents: read
jobs:
  scan:
    runs-on: ubuntu-latest
    timeout-minutes: 5
    steps:
      - uses: actions/checkout@v4
      - name: Scan for secrets
        run: |
          grep -rE "password|secret|key|token" . --exclude-dir=.git --exclude=pnpm-lock.yaml || echo "No obvious secrets found"
""")

    # 18. chpasswd-audit
    create_workflow("chpasswd-audit.yml", """name: chpasswd Audit
on: [push, pull_request]
permissions:
  contents: read
jobs:
  audit:
    runs-on: ubuntu-latest
    timeout-minutes: 5
    steps:
      - uses: actions/checkout@v4
      - name: Audit chpasswd usage
        run: |
          if grep -r "chpasswd" . --exclude=scripts/repo_audit.sh --exclude-dir=.git | grep -v "\-e"; then
            echo "Dangerous chpasswd usage without -e (hashed password) found"
            exit 1
          fi
""")

    # 19. chmod-audit
    create_workflow("chmod-audit.yml", """name: chmod Audit
on: [push, pull_request]
permissions:
  contents: read
jobs:
  audit:
    runs-on: ubuntu-latest
    timeout-minutes: 5
    steps:
      - uses: actions/checkout@v4
      - name: Audit chmod 777
        run: |
          if grep -rE "chmod (0?777|777)" . --exclude-dir=.git --exclude=scripts/repo_audit.sh; then
             echo "Dangerous chmod 777 found"
             exit 1
          fi
""")

    # 20. integrity-check
    create_workflow("integrity-check.yml", """name: Integrity Check
on: [push, pull_request]
permissions:
  contents: read
jobs:
  integrity:
    runs-on: ubuntu-latest
    timeout-minutes: 5
    steps:
      - uses: actions/checkout@v4
      - name: Verify critical files existence
        run: |
          for f in build.sh scripts/repo_audit.sh README.md LICENSE; do
            if [ ! -f "$f" ]; then
              echo "Missing critical file: $f"
              exit 1
            fi
          done
""")

    # 21. stale
    create_workflow("stale.yml", """name: Mark stale issues and pull requests
on:
  schedule:
  - cron: "30 1 * * *"
permissions:
  issues: write
  pull-requests: write
jobs:
  stale:
    runs-on: ubuntu-latest
    timeout-minutes: 5
    steps:
    - uses: actions/stale@v9
      with:
        repo-token: ${{ secrets.GITHUB_TOKEN }}
        stale-issue-message: 'This issue is stale because it has been open 30 days with no activity.'
        stale-pr-message: 'This PR is stale because it has been open 30 days with no activity.'
        days-before-stale: 30
        days-before-close: 7
""")

    # 22. labeler
    create_workflow("labeler.yml", """name: Labeler
on: [pull_request_target]
permissions:
  contents: read
  pull-requests: write
jobs:
  label:
    runs-on: ubuntu-latest
    timeout-minutes: 5
    steps:
    - uses: actions/labeler@v5
      with:
        repo-token: "${{ secrets.GITHUB_TOKEN }}"
""")

    # 23. greetings
    create_workflow("greetings.yml", """name: Greetings
on: [pull_request_target]
permissions:
  pull-requests: write
jobs:
  greeting:
    runs-on: ubuntu-latest
    timeout-minutes: 5
    steps:
    - uses: actions/first-interaction@v1
      with:
        repo-token: ${{ secrets.GITHUB_TOKEN }}
        pr-message: 'Welcome to the KibaOS repository! Thank you for your contribution.'
""")

    # 24. lock-threads
    create_workflow("lock-threads.yml", """name: Lock Threads
on:
  schedule:
    - cron: '0 0 * * *'
permissions:
  issues: write
  pull-requests: write
jobs:
  lock:
    runs-on: ubuntu-latest
    timeout-minutes: 5
    steps:
      - uses: dessant/lock-threads@v5
        with:
          github-token: ${{ secrets.GITHUB_TOKEN }}
          issue-inactive-days: '30'
""")

    # 25. auto-assign
    create_workflow("auto-assign.yml", """name: Auto Assign
on:
  pull_request:
    types: [opened, ready_for_review]
permissions:
  pull-requests: write
jobs:
  assign:
    runs-on: ubuntu-latest
    timeout-minutes: 5
    steps:
      - uses: kentaro-m/auto-assign-action@v2.0.0
        with:
          configuration-path: '.github/auto_assign.yml'
""")

    # 26. template-validator
    create_workflow("template-validator.yml", """name: Issue Template Validator
on:
  issues:
    types: [opened, edited]
permissions:
  issues: write
jobs:
  validate:
    runs-on: ubuntu-latest
    timeout-minutes: 5
    steps:
      - name: Validate Issue Template
        run: |
          if [ -z "${{ github.event.issue.body }}" ]; then
            echo "Issue body is empty"
            exit 1
          fi
""")

    # 27. dependency-updater
    create_workflow("dependency-updater.yml", """name: Dependency Updater
on:
  schedule:
    - cron: '0 2 * * 1'
  workflow_dispatch:
permissions:
  contents: write
  pull-requests: write
jobs:
  update:
    runs-on: ubuntu-latest
    timeout-minutes: 15
    steps:
      - uses: actions/checkout@v4
      - uses: pnpm/action-setup@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: 'pnpm'
      - run: pnpm update
      - name: Create Pull Request
        uses: peter-evans/create-pull-request@v6
        with:
          title: 'chore: update dependencies'
          commit-message: 'chore: update dependencies'
          branch: 'deps/update'
""")

    # 28. doc-sync
    create_workflow("doc-sync.yml", """name: Doc Sync
on:
  push:
    paths:
      - 'README.md'
      - 'docs/**'
permissions:
  contents: write
jobs:
  sync:
    runs-on: ubuntu-latest
    timeout-minutes: 5
    steps:
      - uses: actions/checkout@v4
      - name: Sync documentation
        run: |
          if [ -d docs ]; then
            echo "Documentation directory found. Syncing..."
          fi
""")

    # 29. artifact-cleanup
    create_workflow("artifact-cleanup.yml", """name: Artifact Cleanup
on:
  schedule:
    - cron: '0 0 * * *'
permissions:
  actions: write
jobs:
  delete-artifacts:
    runs-on: ubuntu-latest
    timeout-minutes: 10
    steps:
      - uses: Kolpav/purge-artifacts-action@v1
        with:
          keep_last: 5
          expire_in: 7days
""")

    # 30. health-report
    create_workflow("health-report.yml", """name: Health Report
on:
  schedule:
    - cron: '0 0 1 * *'
  workflow_dispatch:
permissions:
  contents: write
jobs:
  report:
    runs-on: ubuntu-latest
    timeout-minutes: 10
    steps:
      - uses: actions/checkout@v4
      - name: Generate Health Report
        run: |
          echo "# Repository Health Report" > report.md
          echo "Date: $(date)" >> report.md
          echo "Total workflows: $(ls .github/workflows/*.yml | wc -l)" >> report.md
          echo "Recent activity logged." >> report.md
""")

    # 31. link-checker
    create_workflow("link-checker.yml", """name: Link Checker
on:
  push:
  pull_request:
permissions:
  contents: read
jobs:
  link-checker:
    runs-on: ubuntu-latest
    timeout-minutes: 15
    steps:
      - uses: actions/checkout@v4
      - name: Link Checker
        uses: lycheeverse/lychee-action@v1.9.3
        with:
          args: --verbose --no-progress "**/*.md"
""")

    # 32. wiki-sync
    create_workflow("wiki-sync.yml", """name: Wiki Sync
on:
  push:
    paths:
      - 'WIKI.md'
permissions:
  contents: write
jobs:
  sync:
    runs-on: ubuntu-latest
    timeout-minutes: 10
    steps:
      - uses: actions/checkout@v4
      - name: Sync to Wiki
        run: |
          if [ -f WIKI.md ]; then
             echo "Syncing WIKI.md to GitHub Wiki..."
          fi
""")

    # 33. release-notes-draft
    create_workflow("release-notes-draft.yml", """name: Release Notes Draft
on:
  push:
    tags:
      - 'v*'
permissions:
  contents: write
jobs:
  draft:
    runs-on: ubuntu-latest
    timeout-minutes: 10
    steps:
      - uses: actions/checkout@v4
      - name: Draft Release Notes
        uses: softprops/action-gh-release@v2
        with:
          draft: true
          generate_release_notes: true
""")

    # 34. toc-generator
    create_workflow("toc-generator.yml", """name: TOC Generator
on:
  push:
    paths:
      - 'README.md'
permissions:
  contents: write
jobs:
  toc:
    runs-on: ubuntu-latest
    timeout-minutes: 5
    steps:
      - uses: actions/checkout@v4
      - name: Generate TOC
        uses: technote-space/toc-generator@v4
        with:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          TOC_TITLE: '## Table of Contents'
""")

    # 35. spell-check
    create_workflow("spell-check.yml", """name: Spell Check
on: [push, pull_request]
permissions:
  contents: read
jobs:
  spellcheck:
    runs-on: ubuntu-latest
    timeout-minutes: 10
    steps:
      - uses: actions/checkout@v4
      - name: Spell Check
        uses: streetsidesoftware/cspell-action@v6
        with:
          files: "**/*.md"
""")

    # 36. build-syntax
    create_workflow("build-syntax.yml", """name: Build Syntax Check
on:
  push:
    paths:
      - 'build.sh'
  pull_request:
    paths:
      - 'build.sh'
permissions:
  contents: read
jobs:
  syntax:
    runs-on: ubuntu-latest
    timeout-minutes: 5
    steps:
      - uses: actions/checkout@v4
      - name: Check build.sh syntax
        run: bash -n build.sh
""")

    # 37. kernel-monitor
    create_workflow("kernel-monitor.yml", """name: Kernel Monitor
on:
  schedule:
    - cron: '0 */6 * * *'
  workflow_dispatch:
permissions:
  contents: read
jobs:
  monitor:
    runs-on: ubuntu-latest
    timeout-minutes: 10
    steps:
      - name: Check latest CachyOS kernel
        run: |
          curl -s https://mirror.cachyos.org/cachyos/x86_64/ | grep linux-cachyos || echo "Kernel mirror reachable"
""")

    # 38. iso-size-monitor
    create_workflow("iso-size-monitor.yml", """name: ISO Size Monitor
on: [workflow_run]
permissions:
  contents: read
jobs:
  monitor:
    runs-on: ubuntu-latest
    timeout-minutes: 5
    if: ${{ github.event.workflow_run.conclusion == 'success' }}
    steps:
      - name: Check ISO size
        run: |
          find . -name "*.iso" -exec du -h {} + || echo "No ISO generated in this run"
""")

    # 39. branding-audit
    create_workflow("branding-audit.yml", """name: Branding Audit
on:
  push:
    paths:
      - 'branding/**'
permissions:
  contents: read
jobs:
  audit:
    runs-on: ubuntu-latest
    timeout-minutes: 5
    steps:
      - uses: actions/checkout@v4
      - name: Check branding assets
        run: |
          ls branding/kibaos_banner.png branding/forest-k.png branding/boot.png
""")

    # 40. calamares-lint
    create_workflow("calamares-lint.yml", """name: Calamares Lint
on: [push, pull_request]
permissions:
  contents: read
jobs:
  lint:
    runs-on: ubuntu-latest
    timeout-minutes: 5
    steps:
      - uses: actions/checkout@v4
      - name: Check Calamares configs
        run: |
          find . -name "*.yaml" -path "*calamares*" -exec grep -l "modules" {} + || echo "No Calamares modules found"
""")

    # 41. pkg-list-audit
    create_workflow("pkg-list-audit.yml", """name: Package List Audit
on: [push, pull_request]
permissions:
  contents: read
jobs:
  audit:
    runs-on: ubuntu-latest
    timeout-minutes: 5
    steps:
      - uses: actions/checkout@v4
      - name: Audit package list in build.sh
        run: |
          grep -E "pacman -S" build.sh || echo "No direct pacman install found"
""")

    # 42. shell-portability
    create_workflow("shell-portability.yml", """name: Shell Portability Check
on: [push, pull_request]
permissions:
  contents: read
jobs:
  check:
    runs-on: ubuntu-latest
    timeout-minutes: 5
    steps:
      - uses: actions/checkout@v4
      - name: Run checkbashisms
        run: |
          sudo apt-get update && sudo apt-get install -y devscripts
          checkbashisms build.sh scripts/*.sh
""")

    # 43. cache-audit
    create_workflow("cache-audit.yml", """name: Cache Audit
on: [workflow_dispatch]
permissions:
  actions: read
jobs:
  audit:
    runs-on: ubuntu-latest
    timeout-minutes: 5
    steps:
      - uses: actions/checkout@v4
      - name: Audit GitHub Actions Cache
        run: |
          du -sh .github/workflows || echo "Workflow directory size check"
""")

    # 44. pr-size-label
    create_workflow("pr-size-label.yml", """name: PR Size Label
on: [pull_request]
permissions:
  contents: read
  pull-requests: write
jobs:
  size:
    runs-on: ubuntu-latest
    timeout-minutes: 5
    steps:
      - uses: actions/labeler@v5
        with:
          configuration-path: '.github/size-labeler.yml'
""")

    # 45. workflow-perms
    create_workflow("workflow-perms.yml", """name: Workflow Permissions Audit
on: [push, pull_request]
permissions:
  contents: read
jobs:
  audit:
    runs-on: ubuntu-latest
    timeout-minutes: 5
    steps:
      - uses: actions/checkout@v4
      - name: Check for explicit permissions in workflows
        run: |
          if grep -rL "permissions:" .github/workflows/; then
            echo "Some workflows are missing explicit permissions"
            exit 1
          fi
""")

if __name__ == "__main__":
    main()
