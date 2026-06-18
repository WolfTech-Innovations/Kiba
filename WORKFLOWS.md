# GitHub Workflows Manual
Generated on Thu Jun 18 14:30:12 UTC 2026

| Workflow Name | File Path | Details |
|---------------|-----------|---------|
| Actionlint | `./.github/workflows/actionlint.yml` |  |
| Audit - Repository Health | `./.github/workflows/audit-repository-health.yml` | <details><summary>Included Checks</summary><ul><li>Prohibit sudo in build.sh</li><li>Ensure git clone uses --depth=1</li><li>Prohibit pacman -Sy without u</li><li>Detect hardcoded /home/liveuser</li><li>Ensure shell scripts have set -e</li><li>Prohibit eval in shell scripts</li><li>Ensure curl uses --retry</li><li>Ensure wget uses --tries</li><li>Check for dangerous rm -rf /</li><li>Prohibit chmod 777</li><li>Prohibit pip install</li><li>Prohibit npm install (use pnpm)</li><li>Prohibit yarn install (use pnpm)</li><li>Check for FIXME comments</li><li>Check for DEBUG logs</li><li>Check for console.log in JS</li><li>Check for print in Python</li><li>Check for hardcoded IP addresses</li><li>Check for localhost in configs</li><li>Check for insecure http links</li><li>Check for .bak or .old files</li><li>Check for node_modules in repo</li><li>Check for dist or build dirs</li><li>Prohibit package-lock.json (use pnpm)</li><li>Prohibit yarn.lock</li><li>Ensure package.json has description</li><li>Ensure workflows have permissions</li><li>Ensure empty dirs have .gitkeep</li><li>Check for trailing whitespace</li><li>Ensure shell scripts have set -u</li><li>Ensure shell scripts have pipefail</li><li>Check for non-standard file extensions</li><li>Detect hardcoded UID 1000</li><li>Check airootfs variable safety</li><li>Ensure pacman-key --populate in build</li><li>Ensure ldconfig after library installs</li><li>Ensure Inter font usage</li><li>Ensure Calamares uses HTTPS check</li><li>Ensure ParallelDownloads is 10</li><li>Ensure alpm user is created</li><li>Prohibit apt/apt-get usage</li><li>Ensure NetworkManager is enabled</li><li>Verify Bash syntax</li><li>Verify JSON syntax</li><li>Check for TODO comments</li></ul></details> |
| Auto Assign | `./.github/workflows/auto-assign.yml` |  |
| Automated Repo Health Report | `./.github/workflows/automated-repo-health-report.yml` |  |
| Bandit | `./.github/workflows/bandit.yml` |  |
| Broken Link Checker | `./.github/workflows/broken-link-checker.yml` |  |
| Build KibaOS | `./.github/workflows/build.yml` |  |
| CachyOS Kernel Monitor | `./.github/workflows/cachyos-kernel-monitor.yml` |  |
| Check JSON Syntax | `./.github/workflows/check-json-syntax.yml` |  |
| Check Python Syntax | `./.github/workflows/check-py-syntax.yml` |  |
| Close Inactive PRs | `./.github/workflows/close-inactive-prs.yml` |  |
| CodeQL | `./.github/workflows/codeql.yml` |  |
| Commit Lint | `./.github/workflows/commit-lint.yml` |  |
| Dependency Review | `./.github/workflows/dependency-review.yml` |  |
| Gitleaks | `./.github/workflows/gitleaks.yml` |  |
| Greetings | `./.github/workflows/greetings.yml` |  |
| Labeler | `./.github/workflows/labeler.yml` |  |
| Lock Threads | `./.github/workflows/lock-threads.yml` |  |
| Markdownlint | `./.github/workflows/markdownlint.yml` |  |
| Monitor CachyOS Kernel | `./.github/workflows/monitor-cachyos-kernel.yml` |  |
| Notify SourceForge Release | `./.github/workflows/notify-release-sourceforge-upload.yml` |  |
| Prettier | `./.github/workflows/prettier.yml` |  |
| Release Drafter | `./.github/workflows/release-drafter.yml` |  |
| Repository Audit | `./.github/workflows/repo-audit.yml` |  |
| Repo Stats | `./.github/workflows/repo-stats.yml` |  |
| Scorecard supply-chain security | `./.github/workflows/scorecards.yml` |  |
| Semgrep | `./.github/workflows/semgrep.yml` |  |
| ShellCheck | `./.github/workflows/shellcheck.yml` |  |
| Size Labeler | `./.github/workflows/size-labeler.yml` |  |
| Spell Check | `./.github/workflows/spell-check.yml` |  |
| Stale | `./.github/workflows/stale.yml` |  |
| TODO Checker | `./.github/workflows/todo-checker.yml` |  |
| Trivy | `./.github/workflows/trivy.yml` |  |
