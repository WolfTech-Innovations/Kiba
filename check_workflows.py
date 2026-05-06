import yaml
import os
import sys

workflows = [
    ".github/workflows/check-branch-naming-v3.yml",
    ".github/workflows/pr-no-revert-commits-check.yml",
    ".github/workflows/pr-check-for-merge-commits.yml",
    ".github/workflows/check-pull-request-size-v3.yml",
    ".github/workflows/audit-build-parallel-jobs-enforcement.yml",
    ".github/workflows/notify-release-sourceforge-upload.yml",
    ".github/workflows/verify-acknowledgments-git-history.yml",
    ".github/workflows/verify-apt-repo-gpg-signed-strict.yml",
    ".github/workflows/check-build-idempotency-v3.yml",
    ".github/workflows/check-build-cleanup-v3.yml",
    ".github/workflows/check-build-nbd-v3.yml",
    ".github/workflows/check-zshrc-performance-v3.yml",
    ".github/workflows/audit-build-calamares-sidebar-bg.yml",
    ".github/workflows/audit-build-plymouth-color.yml",
    ".github/workflows/audit-build-grub-timeout-check.yml",
    ".github/workflows/audit-build-konsole-opacity-check.yml",
    ".github/workflows/audit-build-zsh-alias-check.yml",
    ".github/workflows/kiba-welcome-emoji-label-check.yml",
    ".github/workflows/kiba-welcome-shortcut-advertisement.yml",
    ".github/workflows/kiba-welcome-window-icon-audit.yml",
    ".github/workflows/package-list-distro-purity.yml",
    ".github/workflows/prohibit-apt-trusted-yes.yml",
    ".github/workflows/secure-apt-keyring-paths.yml",
    ".github/workflows/shell-quoting-checker.yml",
    ".github/workflows/workflow-timeout-minutes-check.yml",
    ".github/workflows/repo-large-file-prevention.yml",
    ".github/workflows/zenity-literal-newline-checker.yml",
    ".github/workflows/zsh-compinit-u-check.yml",
    ".github/workflows/zsh-extendedglob-safety.yml",
    ".github/workflows/zshrc-prompt-optimization-audit.yml"
]

all_passed = True
for f in workflows:
    if not os.path.exists(f):
        print(f"Error: {f} does not exist")
        all_passed = False
        continue
    try:
        with open(f, 'r') as stream:
            yaml.safe_load(stream)
        print(f"Passed: {f}")
    except yaml.YAMLError as exc:
        print(f"Failed: {f} - {exc}")
        all_passed = False

if not all_passed:
    sys.exit(1)
else:
    print(f"All {len(workflows)} workflows passed YAML syntax check.")
