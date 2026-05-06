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
    ".github/workflows/zshrc-prompt-optimization-audit.yml",
    ".github/workflows/audit-wf-checkout-persist-credentials.yml",
    ".github/workflows/audit-sh-license-mit.yml",
    ".github/workflows/audit-mksquashfs-zstd-15.yml",
    ".github/workflows/audit-build-eatmydata-usage.yml",
    ".github/workflows/audit-build-password-length.yml",
    ".github/workflows/audit-ksplashrc-theme.yml",
    ".github/workflows/audit-shell-func-alias-comment.yml",
    ".github/workflows/audit-zsh-compinit-age-check.yml",
    ".github/workflows/audit-python-yaml-explicit-on-key.yml",
    ".github/workflows/audit-build-kernel-purge-order.yml",
    ".github/workflows/audit-wf-no-continue-on-error.yml",
    ".github/workflows/audit-wf-fetch-depth-zero-git-history.yml",
    ".github/workflows/audit-kiba-welcome-discovery-loop.yml",
    ".github/workflows/audit-build-absolute-paths-utilities.yml",
    ".github/workflows/audit-build-su-c-eatmydata.yml",
    ".github/workflows/audit-build-su-c-grouping.yml",
    ".github/workflows/audit-build-debian-trixie-debootstrap.yml",
    ".github/workflows/audit-python-subprocess-shell-false.yml",
    ".github/workflows/audit-markdown-no-consecutive-blank-lines.yml",
    ".github/workflows/audit-repo-no-empty-folders-except-gitkeep.yml",
    ".github/workflows/audit-wf-job-name-no-placeholder.yml",
    ".github/workflows/audit-shell-script-mktemp-var.yml",
    ".github/workflows/audit-python-open-encoding-utf8.yml",
    ".github/workflows/audit-markdown-fenced-code-blocks-strict.yml",
    ".github/workflows/audit-repo-dot-env-forbidden.yml",
    ".github/workflows/audit-shell-script-readonly-constants.yml",
    ".github/workflows/audit-python-is-none-strict.yml",
    ".github/workflows/audit-markdown-no-tabs.yml",
    ".github/workflows/audit-repo-snake-case-scripts.yml",
    ".github/workflows/audit-python-f-string-pref.yml",
    ".github/workflows/audit-markdown-link-relative-repo.yml",
    ".github/workflows/audit-shell-script-trap-err-cleanup.yml",
    ".github/workflows/audit-python-unused-import-vulture.yml",
    ".github/workflows/audit-repo-readme-toc-required.yml",
    ".github/workflows/audit-python-docstring-style.yml",
    ".github/workflows/audit-shell-script-header-description.yml",
    ".github/workflows/audit-wf-step-timeout-enforcement.yml",
    ".github/workflows/audit-repo-no-symlink-to-self.yml",
    ".github/workflows/audit-python-bare-except.yml",
    ".github/workflows/audit-markdown-link-title-quotes.yml",
    ".github/workflows/audit-shell-script-parameter-validation.yml",
    ".github/workflows/audit-wf-run-name-consistency.yml",
    ".github/workflows/audit-repo-forbidden-filenames-case-insensitive.yml",
    ".github/workflows/audit-python-redundant-parentheses.yml",
    ".github/workflows/audit-markdown-ordered-list-consistency.yml"
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
