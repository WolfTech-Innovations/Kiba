#!/bin/bash
set -euo pipefail

# KibaOS Repository Audit Script
# Consolidates multiple repository health and security checks

EXIT_CODE=0
REQUESTED_AUDITS=()

log_error() {
    echo "ERROR: $1"
    EXIT_CODE=1
}

log_warn() {
    echo "WARN: $1"
}

# --- Audit Functions ---

# 1. build-sh-customize-set-e
audit_build_sh_customize_set_e() {
    if [ -f "build.sh" ]; then
        if ! grep -A 2 "cat > \"\${AIROOTFS}/root/customize_airootfs.sh\"" build.sh | grep -q "set -e"; then
            log_error "customize_airootfs.sh in build.sh is missing set -e"
        fi
    fi
}

# 2. build-sh-pacman-populate
audit_build_sh_pacman_populate() {
    if [ -f "build.sh" ]; then
        if ! grep -q "pacman-key --populate archlinux" build.sh; then
            log_error "build.sh is missing pacman-key --populate archlinux"
        fi
    fi
}

# 3. build-sh-relative-symlinks
audit_build_sh_relative_symlinks() {
    if [ -f "build.sh" ]; then
        if grep -q "ln -s /" build.sh | grep -vE "(/dev/|/proc/|/sys/)"; then
             log_warn "Possible absolute symlink detected in build.sh"
        fi
    fi
}

# 4. build-sh-paperde-ldconfig
audit_build_sh_paperde_ldconfig() {
    if [ -f "build.sh" ]; then
        if grep -q "ninja -C paperde-src/build install" build.sh; then
            if ! grep -A 20 "ninja -C paperde-src/build install" build.sh | grep -q "ldconfig"; then
                log_error "ldconfig not found after PaperDE installation in build.sh"
            fi
        fi
    fi
}

# 5. build-sh-desktop-entry-kiba
audit_build_sh_desktop_entry_kiba() {
    if [ -f "build.sh" ]; then
        if ! grep -q "kiba-welcome.desktop" build.sh; then
            log_warn "kiba-welcome.desktop entry not found in build.sh"
        fi
    fi
}

# 6. build-sh-sudoers-perms
audit_build_sh_sudoers_perms() {
    if [ -f "build.sh" ]; then
        if grep -q "/etc/sudoers" build.sh && ! grep -q "chmod 440" build.sh; then
            log_warn "sudoers file mentioned but chmod 440 not found in build.sh"
        fi
    fi
}

# 7. build-sh-liveuser-uid
audit_build_sh_liveuser_uid() {
    if [ -f "build.sh" ]; then
        if grep -q "liveuser" build.sh; then
            if ! grep -q "1000:1000" build.sh; then
                log_error "liveuser found in build.sh but UID/GID 1000 is not explicitly set"
            fi
        fi
    fi
}

# 8. build-sh-wallpaper-consistency
audit_build_sh_wallpaper_consistency() {
    if [ -f "build.sh" ]; then
        if grep -q "wallpaper" build.sh && ! grep -q ".jpg\|.png" build.sh; then
            log_warn "Wallpaper mentioned but no extension found in build.sh"
        fi
    fi
}

# 9. build-sh-octopi-usage
audit_build_sh_octopi_usage() {
    if [ -f "build.sh" ]; then
        if ! grep -q "octopi" build.sh; then
            log_warn "Octopi not found in build.sh"
        fi
    fi
}

# 10. build-sh-zsh-default
audit_build_sh_zsh_default() {
    if [ -f "build.sh" ]; then
        if ! grep -q "chsh -s /usr/bin/zsh" build.sh; then
            log_warn "Zsh not set as default shell in build.sh"
        fi
    fi
}

# 11. markdown-empty-link-check
audit_markdown_empty_link_check() {
    if grep -rE "\[[^]]*\]\(\)" . --include="*.md" | grep -v "node_modules"; then
        log_error "Found empty markdown targets"
    fi
}

# 12. repo-license-sanity
audit_repo_license_sanity() {
    if [ ! -f "LICENSE" ]; then
        log_error "LICENSE file missing"
    fi
}

# 13. repo-readme-badge-https
audit_repo_readme_badge_https() {
    if [ -f "README.md" ]; then
        if grep -q "http://" README.md | grep "badge"; then
            log_error "Non-HTTPS badge found in README.md"
        fi
    fi
}

# 14. repo-no-chmod-777-strict
audit_repo_no_chmod_777_strict() {
    if grep -rE "chmod (0?777|777)" . --exclude-dir=.git --exclude-dir=.Jules --exclude="*.md" --exclude="scripts/repo_audit.sh" | grep -v "log_error"; then
        log_error "Found dangerous chmod 777"
    fi
}

# 15. repo-no-plaintext-chpasswd
audit_repo_no_plaintext_chpasswd() {
    if grep -r "chpasswd" . --exclude-dir=.git --exclude-dir=.github --exclude=".Jules/*" --exclude="*.md" --exclude="scripts/repo_audit.sh" | grep -v "chpasswd -e"; then
        log_error "Potential plaintext chpasswd usage (use -e for encrypted)"
    fi
}

# 16. repo-markdown-anchor-links
audit_repo_markdown_anchor_links() {
    BAD_ANCHORS=$(grep -rhE "\[[^]]+\]\(#[^)]+\)" . --include="*.md" | grep -vE "\(#[a-z0-9-]+\)" || true)
    if [ -n "$BAD_ANCHORS" ]; then
        log_warn "Malformed internal anchors (recommend #lowercase-kebab):"
        echo "$BAD_ANCHORS"
    fi
}

# 17. repo-gitkeep-no-extension
audit_repo_gitkeep_no_extension() {
    if find . -name ".gitkeep.*" | grep -q .; then
        log_error "Found .gitkeep with extension"
    fi
}

# 18. repo-shell-extension-consistency
audit_repo_shell_extension_consistency() {
    if find . -maxdepth 2 -name "*.bash" | grep -q .; then
        log_warn "Found .bash files, project standard is .sh"
    fi
}

# 19. repo-trailing-whitespace-all
audit_repo_trailing_whitespace_all() {
    if grep -rI "[[:blank:]]$" . --exclude-dir=.git --exclude-dir=node_modules --exclude="pnpm-lock.yaml" --exclude="*.png" --exclude="*.jpg"; then
        log_error "Found trailing whitespace"
    fi
}

# 20. repo-no-nested-git-dir
audit_repo_no_nested_git_dir() {
    NESTED_GIT=$(find . -mindepth 2 -name ".git" -type d)
    if [ -n "$NESTED_GIT" ]; then
        log_error "Found nested .git directories"
    fi
}

# 21. workflow-checkout-v4
audit_workflow_checkout_v4() {
    if grep -r "uses: actions/checkout@" .github/workflows/ | grep -vE "@v4|@[a-f0-9]{40}"; then
        log_error "Outdated actions/checkout version (upgrade to @v4)"
    fi
}

# 22. workflow-no-node-16-actions
audit_workflow_no_node_16_actions() {
    if grep -r "node16" .github/workflows/ --include="*.yml"; then
        log_warn "Found actions using Node 16 (deprecated)"
    fi
}

# 23. workflow-explicit-bash-shell
audit_workflow_explicit_bash_shell() {
    # Verify that workflows either have a top-level shell: bash or each run: block has it.
    # We check if 'run:' exists but 'shell: bash' is missing in the file.
    FILES_MISSING_SHELL=$(grep -rL "shell: bash" .github/workflows/ --include="*.yml")
    if [ -n "$FILES_MISSING_SHELL" ]; then
        log_warn "Workflows missing 'shell: bash': $FILES_MISSING_SHELL"
    fi
}

# 24. workflow-no-empty-run-blocks
audit_workflow_no_empty_run_blocks() {
    if grep -r "run: $" .github/workflows/ --include="*.yml"; then
        log_error "Empty run block found in workflow"
    fi
}

# 25. workflow-job-permissions-only
audit_workflow_job_permissions_only() {
    if grep -r "permissions: write-all" .github/workflows/ --include="*.yml"; then
        log_error "Avoid permissions: write-all, use specific permissions"
    fi
}

# 26. workflow-timeout-reasonable
audit_workflow_timeout_reasonable() {
    if grep -r "timeout-minutes:" .github/workflows/ --include="*.yml" | grep -vE "[1-9][0-9]?"; then
        log_warn "Unusually large or missing timeout-minutes"
    fi
}

# 27. workflow-kebab-filenames-strict
audit_workflow_kebab_filenames_strict() {
    if ls .github/workflows/ | grep -vE "^[a-z0-9-]+\.ya?ml$"; then
        log_error "Workflow filenames must be kebab-case"
    fi
}

# 28. workflow-no-absolute-script-paths
audit_workflow_no_absolute_script_paths() {
    if grep -r "run: /home/" .github/workflows/ --include="*.yml"; then
        log_error "Found absolute path in workflow run block"
    fi
}

# 29. workflow-unused-workflow-inputs
audit_workflow_unused_workflow_inputs() {
    log_warn "Heuristic: Check for unused workflow inputs manually"
}

# 30. workflow-no-github-token-leak
audit_workflow_no_github_token_leak() {
    if grep -rE "echo.*(github\.token|secrets\.)" .github/workflows/; then
        log_error "Potential GitHub Token/Secret leak via echo in workflows"
    fi
}

# --- New Grounded Audits ---

# 31. build-sh-zenity-dimensions
audit_build_sh_zenity_dimensions() {
    if [ -f "build.sh" ]; then
        if grep "zenity" build.sh | grep -F -- "--list" | grep -qv "\-\-width=450 \-\-height=500"; then
            log_error "Zenity list dialogs in build.sh must use 450x500 dimensions"
        fi
    fi
}

# 32. build-sh-zenity-bg-subdialogs
audit_build_sh_zenity_bg_subdialogs() {
    if [ -f "build.sh" ]; then
        if grep "zenity" build.sh | grep -vE "\(.*\) &" | grep -q "\-\-info\|\-\-warning"; then
             log_warn "Informational Zenity sub-dialogs should be backgrounded ( ... ) &"
        fi
    fi
}

# 33. build-sh-pacman-refresh-optimization
audit_build_sh_pacman_refresh_optimization() {
    if [ -f "build.sh" ]; then
        if [ $(grep -c "pacman -Syy" build.sh) -gt 1 ]; then
            log_error "Redundant pacman -Syy calls found in build.sh"
        fi
    fi
}

# 34. build-sh-eatmydata-usage
audit_build_sh_eatmydata_usage() {
    if [ -f "build.sh" ]; then
        if grep -q "pacman -S" build.sh && ! grep -q "eatmydata" build.sh; then
            log_warn "eatmydata recommended for heavy pacman operations in build.sh"
        fi
    fi
}

# 35. readme-toc-requirement
audit_readme_toc_requirement() {
    if [ -f "README.md" ]; then
        if [ $(wc -l < README.md) -gt 100 ] && ! grep -iq "table of contents" README.md; then
            log_error "README.md > 100 lines requires a Table of Contents"
        fi
    fi
}

# 36. build-sh-clean-customize
audit_build_sh_clean_customize() {
    if [ -f "build.sh" ]; then
        if ! grep -q "rm.*customize_airootfs.sh" build.sh; then
            log_error "build.sh should delete customize_airootfs.sh at the end"
        fi
    fi
}

# 37. build-sh-cachyos-keyring
audit_build_sh_cachyos_keyring() {
    if [ -f "build.sh" ]; then
        if ! grep -q "F3B607488DB35A47" build.sh; then
            log_error "CachyOS keyring (F3B607488DB35A47) not found in build.sh"
        fi
    fi
}

# 38. build-sh-kernel-vmlinuz-path
audit_build_sh_kernel_vmlinuz_path() {
    if [ -f "build.sh" ]; then
        if ! grep -q "/boot/vmlinuz-linux-cachyos" build.sh; then
            log_error "Bootloader path should target /boot/vmlinuz-linux-cachyos"
        fi
    fi
}

# 39. python-csafeloader-usage
audit_python_csafeloader_usage() {
    # Check for yaml.load without CSafeLoader, ignoring the definition in check_workflows.py
    if grep -r "yaml.load" . --include="*.py" | grep -vE "CSafeLoader|Loader=Loader"; then
        log_error "Python scripts should use yaml.CSafeLoader for performance"
    fi
}

# 40. repo-gitkeep-empty
audit_repo_gitkeep_empty() {
    NON_EMPTY_GITKEEP=$(find . -name ".gitkeep" -type f -size +0)
    if [ -n "$NON_EMPTY_GITKEEP" ]; then
        log_error ".gitkeep files must be strictly 0 bytes: $NON_EMPTY_GITKEEP"
    fi
}

# 41. build-sh-magick-optimization
audit_build_sh_magick_optimization() {
    if [ -f "build.sh" ]; then
        if [ $(grep -c "magick" build.sh) -gt 5 ]; then
            log_warn "Consider consolidating multiple magick calls in build.sh"
        fi
    fi
}

# 42. build-sh-chown-consolidation
audit_build_sh_chown_consolidation() {
    if [ -f "build.sh" ]; then
        if [ $(grep -c "chown -R liveuser" build.sh) -gt 1 ]; then
            log_error "Redundant chown -R liveuser calls in build.sh (consolidate at end)"
        fi
    fi
}

# 43. build-sh-systemctl-consolidation
audit_build_sh_systemctl_consolidation() {
    if [ -f "build.sh" ]; then
        if [ $(grep -c "systemctl enable" build.sh) -gt 10 ]; then
            log_warn "High number of systemctl enable calls in build.sh (consider consolidation)"
        fi
    fi
}

# 44. build-sh-welcome-accessibility
audit_build_sh_welcome_accessibility() {
    if [ -f "build.sh" ]; then
        if grep -q "welcome.html" build.sh; then
            if ! grep -q "<main>" build.sh || ! grep -q ":focus-visible" build.sh; then
                log_error "welcome.html in build.sh missing semantic <main> or :focus-visible"
            fi
        fi
    fi
}

# 45. build-sh-trailing-whitespace
audit_build_sh_trailing_whitespace() {
    if [ -f "build.sh" ]; then
        if grep -q "[[:blank:]]$" build.sh; then
            log_error "Trailing whitespace found in build.sh"
        fi
    fi
}

# --- Argument Parsing ---

ALL_AUDITS=(
    "build-sh-customize-set-e"
    "build-sh-pacman-populate"
    "build-sh-relative-symlinks"
    "build-sh-paperde-ldconfig"
    "build-sh-desktop-entry-kiba"
    "build-sh-sudoers-perms"
    "build-sh-liveuser-uid"
    "build-sh-wallpaper-consistency"
    "build-sh-octopi-usage"
    "build-sh-zsh-default"
    "markdown-empty-link-check"
    "repo-license-sanity"
    "repo-readme-badge-https"
    "repo-no-chmod-777-strict"
    "repo-no-plaintext-chpasswd"
    "repo-markdown-anchor-links"
    "repo-gitkeep-no-extension"
    "repo-shell-extension-consistency"
    "repo-trailing-whitespace-all"
    "repo-no-nested-git-dir"
    "workflow-checkout-v4"
    "workflow-no-node-16-actions"
    "workflow-explicit-bash-shell"
    "workflow-no-empty-run-blocks"
    "workflow-job-permissions-only"
    "workflow-timeout-reasonable"
    "workflow-kebab-filenames-strict"
    "workflow-no-absolute-script-paths"
    "workflow-unused-workflow-inputs"
    "workflow-no-github-token-leak"
    "build-sh-zenity-dimensions"
    "build-sh-zenity-bg-subdialogs"
    "build-sh-pacman-refresh-optimization"
    "build-sh-eatmydata-usage"
    "readme-toc-requirement"
    "build-sh-clean-customize"
    "build-sh-cachyos-keyring"
    "build-sh-kernel-vmlinuz-path"
    "python-csafeloader-usage"
    "repo-gitkeep-empty"
    "build-sh-magick-optimization"
    "build-sh-chown-consolidation"
    "build-sh-systemctl-consolidation"
    "build-sh-welcome-accessibility"
    "build-sh-trailing-whitespace"
)

while [[ $# -gt 0 ]]; do
    case "$1" in
        --audit-*)
            REQUESTED_AUDITS+=("${1#--audit-}")
            shift
            ;;
        *)
            echo "Unknown argument: $1"
            exit 1
            ;;
    esac
done

echo "=== Running KibaOS Repository Audit ==="

# --- Execution ---

run_audit() {
    local audit_name="$1"
    local func_name="audit_${audit_name//-/_}"
    if declare -f "$func_name" > /dev/null; then
        echo "--- Running Audit: $audit_name ---"
        "$func_name"
    else
        log_error "Audit function $func_name not found for $audit_name"
    fi
}

if [ ${#REQUESTED_AUDITS[@]} -eq 0 ]; then
    for audit in "${ALL_AUDITS[@]}"; do
        run_audit "$audit"
    done
else
    for audit in "${REQUESTED_AUDITS[@]}"; do
        run_audit "$audit"
    done
fi

echo "=== Audit Complete ==="
exit $EXIT_CODE
