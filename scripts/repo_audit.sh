#!/bin/bash
set -euo pipefail

# KibaOS Repository Audit Script
# Consolidates multiple repository health and security checks
# Supports modular execution via flags

EXIT_CODE=0

log_error() {
    echo "ERROR: $1"
    EXIT_CODE=1
}

log_warn() {
    echo "WARN: $1"
}

# 1. build.sh: customize_airootfs set -e
audit_build_sh_customize_set_e() {
    echo "--- Auditing build.sh: customize_airootfs set -e ---"
    if [ -f "build.sh" ]; then
        if ! grep -A 2 "cat > \"\${AIROOTFS}/root/customize_airootfs.sh\"" build.sh | grep -q "set -e"; then
            log_error "customize_airootfs.sh in build.sh is missing set -e"
        fi
    fi
}

# 2. build.sh: pacman-key populate
audit_build_sh_pacman_populate() {
    echo "--- Auditing build.sh: pacman-key populate ---"
    if [ -f "build.sh" ]; then
        if ! grep -q "pacman-key --populate archlinux" build.sh; then
            log_error "build.sh is missing pacman-key --populate archlinux"
        fi
    fi
}

# 3. build.sh: relative symlinks
audit_build_sh_relative_symlinks() {
    echo "--- Auditing build.sh: relative symlinks ---"
    if [ -f "build.sh" ]; then
        # Check for absolute symlinks that should likely be relative
        if grep -q "ln -sf /" build.sh | grep -vE "/usr/lib/systemd/system/|/usr/share/pixmaps/|/run/user/"; then
             log_warn "Found absolute symlinks in build.sh, verify if they should be relative"
        fi
    fi
}

# 4. build.sh: PaperDE ldconfig
audit_build_sh_paperde_ldconfig() {
    echo "--- Auditing build.sh: PaperDE ldconfig ---"
    if [ -f "build.sh" ]; then
        if grep -q "ninja -C paperde-src/build install" build.sh; then
            if ! grep -A 20 "ninja -C paperde-src/build install" build.sh | grep -q "ldconfig"; then
                log_error "ldconfig not found after PaperDE installation in build.sh"
            fi
        fi
    fi
}

# 5. build.sh: desktop entry kiba
audit_build_sh_desktop_entry_kiba() {
    echo "--- Auditing build.sh: desktop entry kiba ---"
    if [ -f "build.sh" ]; then
        if ! grep -q "kibaos-install.desktop" build.sh; then
            log_error "build.sh is missing kibaos-install.desktop entry"
        fi
    fi
}

# 6. build.sh: sudoers perms
audit_build_sh_sudoers_perms() {
    echo "--- Auditing build.sh: sudoers perms ---"
    if [ -f "build.sh" ]; then
        if grep -q "etc/sudoers.d/" build.sh; then
            if ! grep -q "chmod 0440.*etc/sudoers.d/" build.sh; then
                log_error "build.sh modifies sudoers.d but might be missing strict 0440 permissions"
            fi
        fi
    fi
}

# 7. build.sh: liveuser UID/GID
audit_build_sh_liveuser_uid() {
    echo "--- Auditing build.sh: liveuser UID ---"
    if [ -f "build.sh" ]; then
        if grep -q "liveuser" build.sh; then
            if ! grep -q "1000:1000" build.sh; then
                log_error "liveuser found in build.sh but UID/GID 1000 is not explicitly set"
            fi
        fi
    fi
}

# 8. build.sh: wallpaper consistency
audit_build_sh_wallpaper_consistency() {
    echo "--- Auditing build.sh: wallpaper consistency ---"
    if [ -f "build.sh" ]; then
        WP_DEST=$(grep "WALLPAPER_DEST=" build.sh | cut -d'"' -f2 || true)
        if [ -n "$WP_DEST" ]; then
            if ! grep -q "gsettings set.*background picture-uri.*$WP_DEST" build.sh; then
                log_error "Wallpaper destination $WP_DEST does not match gsettings configuration"
            fi
        fi
    fi
}

# 9. build.sh: octopi usage
audit_build_sh_octopi_usage() {
    echo "--- Auditing build.sh: octopi usage ---"
    if [ -f "build.sh" ]; then
        if grep -qi "octopi" build.sh; then
            log_warn "Octopi detected in build.sh, ensure it is configured correctly for KibaOS"
        fi
    fi
}

# 10. build.sh: zsh default
audit_build_sh_zsh_default() {
    echo "--- Auditing build.sh: zsh default ---"
    if [ -f "build.sh" ]; then
        if grep -q "chsh -s /usr/bin/zsh" build.sh; then
            log_warn "zsh is set as default shell, ensure bash is still available for scripts"
        fi
    fi
}

# 11. Markdown: empty link check
audit_markdown_empty_link_check() {
    echo "--- Auditing Markdown: empty links ---"
    if grep -rE "\[[^]]*\]\(\)" . --include="*.md" | grep -vE "node_modules|\.Jules"; then
        log_error "Found empty markdown targets"
    fi
}

# 12. Repo: license sanity
audit_repo_license_sanity() {
    echo "--- Auditing Repo: license sanity ---"
    if [ ! -f "LICENSE" ]; then
        log_error "LICENSE file missing"
    fi
}

# 13. Repo: readme badge https
audit_repo_readme_badge_https() {
    echo "--- Auditing Repo: readme badge https ---"
    if [ -f "README.md" ]; then
        if grep -q "http://" README.md | grep -E "img.shields.io|badge"; then
            log_error "Insecure badge link (http) found in README.md"
        fi
    fi
}

# 14. Repo: no chmod 777 strict
audit_repo_no_chmod_777_strict() {
    echo "--- Auditing Repo: no chmod 777 ---"
    if grep -rE "chmod (0?777|777)" . --exclude-dir={.git,.Jules,node_modules} --exclude="repo_audit.sh"; then
        log_error "Found dangerous chmod 777"
    fi
}

# 15. Repo: no plaintext chpasswd
audit_repo_no_plaintext_chpasswd() {
    echo "--- Auditing Repo: no plaintext chpasswd ---"
    if grep -r "chpasswd" . --exclude-dir={.git,.Jules} --include="*.sh" --include="build.sh" --exclude="repo_audit.sh" | grep -vE "chpasswd -e|LIVE_HASH"; then
        log_error "Potential plaintext password in chpasswd usage"
    fi
}

# 16. Repo: markdown anchor links
audit_repo_markdown_anchor_links() {
    echo "--- Auditing Repo: markdown anchor links ---"
    BAD_ANCHORS=$(grep -rhE "\[[^]]+\]\(#[^)]+\)" . --include="*.md" | grep -vE "node_modules|\.Jules" | grep -vE "\(#[a-z0-9-]+\)" || true)
    if [ -n "$BAD_ANCHORS" ]; then
        log_warn "Malformed internal anchors (recommend #lowercase-kebab):"
        echo "$BAD_ANCHORS"
    fi
}

# 17. Repo: gitkeep no extension
audit_repo_gitkeep_no_extension() {
    echo "--- Auditing Repo: gitkeep no extension ---"
    # Find files ending in .gitkeep that are not exactly .gitkeep
    BAD_GITKEEP=$(find . -name "?*.gitkeep" | grep -vE "/node_modules/|/\.git/")
    if [ -n "$BAD_GITKEEP" ]; then
        log_error "Found .gitkeep with extension (should be just .gitkeep): $BAD_GITKEEP"
    fi
}

# 18. Repo: shell extension consistency
audit_repo_shell_extension_consistency() {
    echo "--- Auditing Repo: shell extension consistency ---"
    # Scripts in scripts/ should have .sh
    NON_SH_SCRIPTS=$(find scripts -type f ! -name "*.sh" ! -name ".*")
    if [ -n "$NON_SH_SCRIPTS" ]; then
        log_warn "Scripts without .sh extension in scripts/ directory: $NON_SH_SCRIPTS"
    fi
}

# 19. Repo: trailing whitespace all
audit_repo_trailing_whitespace_all() {
    echo "--- Auditing Repo: trailing whitespace ---"
    if grep -rI "[[:blank:]]$" . --exclude-dir={.git,.Jules,node_modules} --exclude="pnpm-lock.yaml" --exclude="*.png" --exclude="*.jpg" --exclude="*.svg"; then
        log_error "Found trailing whitespace"
    fi
}

# 20. Repo: no nested git dir
audit_repo_no_nested_git_dir() {
    echo "--- Auditing Repo: no nested git dir ---"
    NESTED_GIT=$(find . -mindepth 2 -name ".git" -type d | grep -vE "/node_modules/|/\.Jules/")
    if [ -n "$NESTED_GIT" ]; then
        log_error "Found nested .git directories"
    fi
}

# 21. Workflow: checkout v4
audit_workflow_checkout_v4() {
    echo "--- Auditing Workflows: actions/checkout@v4 ---"
    if [ -d ".github/workflows" ]; then
        if grep -r "uses: actions/checkout@" .github/workflows/ | grep -vE "@v4|@[a-f0-9]{40}"; then
            log_error "Outdated actions/checkout version (upgrade to @v4)"
        fi
    fi
}

# 22. Workflow: no node 16 actions
audit_workflow_no_node_16_actions() {
    echo "--- Auditing Workflows: no node 16 actions ---"
    if [ -d ".github/workflows" ]; then
        if grep -rE "uses: actions/(setup-node|github-script)@v[1-3]" .github/workflows/; then
             log_warn "Found actions likely using Node 16 (consider upgrading)"
        fi
    fi
}

# 23. Workflow: explicit bash shell
audit_workflow_explicit_bash_shell() {
    echo "--- Auditing Workflows: explicit bash shell ---"
    if [ -d ".github/workflows" ]; then
        # Check if workflows with run: blocks specify shell: bash
        # This is a simplified check
        WORKFLOWS_MISSING_SHELL=$(grep -L "shell: bash" .github/workflows/*.yml || true)
        if [ -n "$WORKFLOWS_MISSING_SHELL" ]; then
             log_warn "Workflows potentially missing explicit 'shell: bash': $WORKFLOWS_MISSING_SHELL"
        fi
    fi
}

# 24. Workflow: no empty run blocks
audit_workflow_no_empty_run_blocks() {
    echo "--- Auditing Workflows: no empty run blocks ---"
    if [ -d ".github/workflows" ]; then
        if grep -r "run: $" .github/workflows/; then
            log_error "Found empty run blocks in workflows"
        fi
    fi
}

# 25. Workflow: job permissions only
audit_workflow_job_permissions_only() {
    echo "--- Auditing Workflows: job permissions only ---"
    if [ -d ".github/workflows" ]; then
        # Top-level permissions are okay if they are broad, but job-level is preferred for least privilege
        if grep -q "^permissions:" .github/workflows/*.yml 2>/dev/null; then
             log_warn "Found top-level permissions in workflows; verify if job-level is more appropriate"
        fi
    fi
}

# 26. Workflow: timeout reasonable
audit_workflow_timeout_reasonable() {
    echo "--- Auditing Workflows: timeout reasonable ---"
    if [ -d ".github/workflows" ]; then
        if grep -r "timeout-minutes:" .github/workflows/ | grep -vE "timeout-minutes: [1-9]$|timeout-minutes: 1[0-5]"; then
             log_warn "Found workflows with potentially excessive timeout-minutes"
        fi
    fi
}

# 27. Workflow: kebab filenames strict
audit_workflow_kebab_filenames_strict() {
    echo "--- Auditing Workflows: kebab filenames ---"
    if [ -d ".github/workflows" ]; then
        BAD_NAMES=$(find .github/workflows -name "*_*" -o -name "*[A-Z]*")
        if [ -n "$BAD_NAMES" ]; then
            log_error "Workflow filenames should be kebab-case: $BAD_NAMES"
        fi
    fi
}

# 28. Workflow: no absolute script paths
audit_workflow_no_absolute_script_paths() {
    echo "--- Auditing Workflows: no absolute script paths ---"
    if [ -d ".github/workflows" ]; then
        if grep -rE "/home/runner/work/|/github/workspace/" .github/workflows/; then
            log_error "Found absolute paths in workflows (use GITHUB_WORKSPACE instead)"
        fi
    fi
}

# 29. Workflow: unused workflow inputs
audit_workflow_unused_workflow_inputs() {
    echo "--- Auditing Workflows: unused inputs ---"
    if [ -d ".github/workflows" ]; then
        for wf in .github/workflows/*.yml; do
            # Find inputs defined in workflow_dispatch
            INPUTS=$(grep -A 100 "workflow_dispatch:" "$wf" | grep -A 50 "inputs:" | grep -E "^[[:space:]]+[a-zA-Z0-9_-]+:" | cut -d':' -f1 | tr -d ' ' || true)
            for input in $INPUTS; do
                if ! grep -qE "inputs\.$input|github\.event\.inputs\.$input" "$wf"; then
                    log_error "Unused input '$input' in $wf"
                fi
            done
        done
    fi
}

# 30. Workflow: no github token leak
audit_workflow_no_github_token_leak() {
    echo "--- Auditing Workflows: no github token leak ---"
    if [ -d ".github/workflows" ]; then
        if grep -rE "echo.*(github\.token|secrets\.)" .github/workflows/; then
            log_error "Potential GitHub Token/Secret leak via echo in workflows"
        fi
    fi
}

# Main execution
if [ $# -eq 0 ]; then
    # Run all audits
    audit_build_sh_customize_set_e
    audit_build_sh_pacman_populate
    audit_build_sh_relative_symlinks
    audit_build_sh_paperde_ldconfig
    audit_build_sh_desktop_entry_kiba
    audit_build_sh_sudoers_perms
    audit_build_sh_liveuser_uid
    audit_build_sh_wallpaper_consistency
    audit_build_sh_octopi_usage
    audit_build_sh_zsh_default
    audit_markdown_empty_link_check
    audit_repo_license_sanity
    audit_repo_readme_badge_https
    audit_repo_no_chmod_777_strict
    audit_repo_no_plaintext_chpasswd
    audit_repo_markdown_anchor_links
    audit_repo_gitkeep_no_extension
    audit_repo_shell_extension_consistency
    audit_repo_trailing_whitespace_all
    audit_repo_no_nested_git_dir
    audit_workflow_checkout_v4
    audit_workflow_no_node_16_actions
    audit_workflow_explicit_bash_shell
    audit_workflow_no_empty_run_blocks
    audit_workflow_job_permissions_only
    audit_workflow_timeout_reasonable
    audit_workflow_kebab_filenames_strict
    audit_workflow_no_absolute_script_paths
    audit_workflow_unused_workflow_inputs
    audit_workflow_no_github_token_leak
else
    # Parse flags
    for arg in "$@"; do
        case $arg in
            --audit-build-sh-customize-set-e) audit_build_sh_customize_set_e ;;
            --audit-build-sh-pacman-populate) audit_build_sh_pacman_populate ;;
            --audit-build-sh-relative-symlinks) audit_build_sh_relative_symlinks ;;
            --audit-build-sh-paperde-ldconfig) audit_build_sh_paperde_ldconfig ;;
            --audit-build-sh-desktop-entry-kiba) audit_build_sh_desktop_entry_kiba ;;
            --audit-build-sh-sudoers-perms) audit_build_sh_sudoers_perms ;;
            --audit-build-sh-liveuser-uid) audit_build_sh_liveuser_uid ;;
            --audit-build-sh-wallpaper-consistency) audit_build_sh_wallpaper_consistency ;;
            --audit-build-sh-octopi-usage) audit_build_sh_octopi_usage ;;
            --audit-build-sh-zsh-default) audit_build_sh_zsh_default ;;
            --audit-markdown-empty-link-check) audit_markdown_empty_link_check ;;
            --audit-repo-license-sanity) audit_repo_license_sanity ;;
            --audit-repo-readme-badge-https) audit_repo_readme_badge_https ;;
            --audit-repo-no-chmod-777-strict) audit_repo_no_chmod_777_strict ;;
            --audit-repo-no-plaintext-chpasswd) audit_repo_no_plaintext_chpasswd ;;
            --audit-repo-markdown-anchor-links) audit_repo_markdown_anchor_links ;;
            --audit-repo-gitkeep-no-extension) audit_repo_gitkeep_no_extension ;;
            --audit-repo-shell-extension-consistency) audit_repo_shell_extension_consistency ;;
            --audit-repo-trailing-whitespace-all) audit_repo_trailing_whitespace_all ;;
            --audit-repo-no-nested-git-dir) audit_repo_no_nested_git_dir ;;
            --audit-workflow-checkout-v4) audit_workflow_checkout_v4 ;;
            --audit-workflow-no-node-16-actions) audit_workflow_no_node_16_actions ;;
            --audit-workflow-explicit-bash-shell) audit_workflow_explicit_bash_shell ;;
            --audit-workflow-no-empty-run-blocks) audit_workflow_no_empty_run_blocks ;;
            --audit-workflow-job-permissions-only) audit_workflow_job_permissions_only ;;
            --audit-workflow-timeout-reasonable) audit_workflow_timeout_reasonable ;;
            --audit-workflow-kebab-filenames-strict) audit_workflow_kebab_filenames_strict ;;
            --audit-workflow-no-absolute-script-paths) audit_workflow_no_absolute_script_paths ;;
            --audit-workflow-unused-workflow-inputs) audit_workflow_unused_workflow_inputs ;;
            --audit-workflow-no-github-token-leak) audit_workflow_no_github_token_leak ;;
            *) echo "Unknown flag: $arg"; EXIT_CODE=1 ;;
        esac
    done
fi

echo "=== Audit Complete ==="
exit $EXIT_CODE
