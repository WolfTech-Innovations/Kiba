import yaml
import os
import sys

workflows = [
    ".github/workflows/auto-fix-prettier-format.yml",
    ".github/workflows/auto-label-pr-size-v2.yml",
    ".github/workflows/auto-welcome-new-contributor-kiba.yml",
    ".github/workflows/notify-release-sourceforge-upload.yml",
    ".github/workflows/stale-issue-activity-ping-v2.yml",
    ".github/workflows/check-commit-description-quality-v2.yml",
    ".github/workflows/audit-repo-duplicate-asset-scanner-v2.yml",
    ".github/workflows/verify-acknowledgments-git-history.yml",
    ".github/workflows/check-todo-priority-enforcement.yml",
    ".github/workflows/audit-wf-permission-isolation-strict-v2.yml",
    ".github/workflows/check-wf-secret-leak-patterns-deep-v2.yml",
    ".github/workflows/verify-action-sha-tag-integrity-v2.yml",
    ".github/workflows/audit-wf-concurrency-efficiency-check-v2.yml",
    ".github/workflows/check-wf-deprecated-actions-scanner-v2.yml",
    ".github/workflows/verify-apt-repo-gpg-signed-strict.yml",
    ".github/workflows/audit-wf-no-curl-pipe-bash-strict-v2.yml",
    ".github/workflows/check-github-token-permissions-explicit.yml",
    ".github/workflows/audit-build-parallel-jobs-enforcement.yml",
    ".github/workflows/check-build-idempotency-logic-v2.yml",
    ".github/workflows/check-rootfs-cleanup-audit-v2.yml",
    ".github/workflows/audit-shell-script-trap-handler-safety-v2.yml",
    ".github/workflows/check-grub-config-syntax-validation-v2.yml",
    ".github/workflows/verify-plymouth-theme-asset-existence-v2.yml",
    ".github/workflows/audit-zshrc-plugin-loading-speed-v2.yml",
    ".github/workflows/check-calamares-branding-consistency-audit-v2.yml",
    ".github/workflows/audit-repo-license-compatibility-deep-v2.yml",
    ".github/workflows/audit-shell-variable-quoting-strict.yml",
    ".github/workflows/check-workflow-timeout-minutes-standard.yml",
    ".github/workflows/audit-repo-large-file-prevention-strict.yml",
    ".github/workflows/check-docs-terminology-consistency-v2.yml"
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
    print("All 30 workflows passed YAML syntax check.")
