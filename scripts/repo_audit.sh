#!/bin/bash
set -euo pipefail

# KibaOS Repository Audit Script
# Consolidates multiple repository health and security checks

EXIT_CODE=0

log_error() {
    echo "ERROR: $1"
    EXIT_CODE=1
}

log_warn() {
    echo "WARN: $1"
}

# --- Audit Implementations ---

check_build_sh_set_e() {
    if [ -f "build.sh" ]; then
        if ! grep -A 2 "cat > \"\${AIROOTFS}/root/customize_airootfs.sh\"" build.sh | grep -q "set -e"; then
            log_error "customize_airootfs.sh in build.sh is missing set -e"
        fi
    fi
}

check_build_sh_pacman_populate() {
    if [ -f "build.sh" ] && ! grep -q "pacman-key --populate archlinux" build.sh; then
        log_error "build.sh is missing pacman-key --populate archlinux"
    fi
}

check_build_sh_relative_symlinks() {
    if [ -f "build.sh" ] && grep -q "ln -s /" build.sh; then
        log_warn "build.sh may contain absolute symlinks"
    fi
}

check_build_sh_paperde_ldconfig() {
    if [ -f "build.sh" ] && grep -q "paperde" build.sh; then
        if ! grep -A 20 "ninja -C paperde-src/build install" build.sh | grep -q "ldconfig"; then
            log_error "ldconfig missing after PaperDE installation"
        fi
    fi
}

check_build_sh_desktop_entry_kiba() {
    if [ -f "build.sh" ] && ! grep -q "kiba.desktop" build.sh; then
         log_warn "kiba.desktop not mentioned in build.sh"
    fi
}

check_build_sh_sudoers_perms() {
    if [ -f "build.sh" ] && grep -q "sudoers" build.sh; then
        if ! grep -q "chmod 440" build.sh; then
            log_error "sudoers file in build.sh might have wrong permissions"
        fi
    fi
}

check_build_sh_liveuser_uid() {
    if [ -f "build.sh" ] && grep -q "liveuser" build.sh; then
        if ! grep -q "1000:1000" build.sh; then
            log_error "liveuser UID/GID 1000 not explicitly set"
        fi
    fi
}

check_build_sh_wallpaper_consistency() {
    if [ -f "build.sh" ] && grep -q "wallpaper" build.sh; then
        if ! grep -q "branding/wallpaper.png" build.sh; then
             log_warn "Wallpaper path in build.sh might be inconsistent"
        fi
    fi
}

check_build_sh_octopi_usage() {
    if [ -f "build.sh" ] && grep -q "octopi" build.sh; then
        log_warn "Octopi is used in build.sh"
    fi
}

check_build_sh_zsh_default() {
    if [ -f "build.sh" ] && ! grep -q "chsh -s /usr/bin/zsh" build.sh; then
        log_error "Zsh is not set as default shell in build.sh"
    fi
}

check_markdown_empty_links() {
    if grep -rE "\[[^]]*\]\(\)" . --include="*.md" | grep -v "node_modules" | grep -v ".git"; then
        log_error "Found empty markdown targets"
    fi
}

check_repo_license_sanity() {
    if [ ! -f "LICENSE" ]; then
        log_error "LICENSE file is missing"
    fi
}

check_repo_readme_badge_https() {
    if [ -f "README.md" ] && grep -q "http://" README.md; then
        log_warn "README contains non-HTTPS badge or link"
    fi
}

check_security_chmod_777() {
    if grep -rE "chmod (0?777|777)" . --exclude-dir=.git --exclude="scripts/repo_audit.sh" --exclude="*.md"; then
        log_error "Found dangerous chmod 777"
    fi
}

check_security_no_plaintext_chpasswd() {
    if grep -r "chpasswd" . --include="*.sh" | grep -v "echo \".*\$.*\" | chpasswd -e"; then
         log_error "Found potential plaintext chpasswd"
    fi
}

check_markdown_anchor_links() {
    if grep -rhE "\[[^]]+\]\(#[A-Z]+\)" . --include="*.md"; then
        log_warn "Uppercase markdown anchors found"
    fi
}

check_hygiene_gitkeep() {
    NON_EMPTY_GITKEEP=$(find . -name ".gitkeep" -type f -size +0)
    if [ -n "$NON_EMPTY_GITKEEP" ]; then
        log_error ".gitkeep files must be empty: $NON_EMPTY_GITKEEP"
    fi
}

check_repo_shell_extension_consistency() {
    if find scripts/ -type f ! -name "*.sh" ! -name ".*"; then
        log_warn "Non-sh scripts found in scripts directory"
    fi
}

check_hygiene_trailing_whitespace() {
    if grep -rI "[[:blank:]]$" . --exclude-dir=.git --exclude="pnpm-lock.yaml" --exclude="*.png" --exclude="*.jpg" --exclude="*.md"; then
        log_error "Found trailing whitespace"
    fi
}

check_repo_no_nested_git_dir() {
    if find . -mindepth 2 -name ".git" -type d | grep -v "node_modules"; then
        log_error "Found nested .git directories"
    fi
}

check_workflow_checkout_v4() {
    if [ -d ".github/workflows" ] && grep -r "uses: actions/checkout@" .github/workflows/ | grep -v "@v4"; then
        log_error "Outdated actions/checkout version"
    fi
}

check_workflow_no_node_16_actions() {
    if [ -d ".github/workflows" ] && grep -r "node16" .github/workflows/; then
        log_error "Workflows using deprecated Node 16"
    fi
}

check_workflow_explicit_bash_shell() {
    if [ -d ".github/workflows" ] && grep -r "run:" .github/workflows/ | grep -v "shell: bash" && grep -l "run:" .github/workflows/*.yml; then
         log_warn "Workflows might be missing explicit bash shell"
    fi
}

check_workflow_no_empty_run_blocks() {
    if [ -d ".github/workflows" ] && grep -r "run: $" .github/workflows/; then
        log_error "Empty run blocks found in workflows"
    fi
}

check_workflow_job_permissions_only() {
    if [ -d ".github/workflows" ] && ! grep -q "permissions:" .github/workflows/*.yml; then
        log_warn "Workflows might be missing explicit permissions"
    fi
}

check_workflow_timeout_reasonable() {
    if [ -d ".github/workflows" ] && ! grep -q "timeout-minutes:" .github/workflows/*.yml; then
        log_warn "Workflows missing timeout-minutes"
    fi
}

check_workflow_kebab_filenames_strict() {
    if find .github/workflows/ -name "*_*" -o -name "*[A-Z]*"; then
        log_error "Workflow filenames should be kebab-case"
    fi
}

check_workflow_no_absolute_script_paths() {
    if [ -d ".github/workflows" ] && grep -r "/home/runner/work" .github/workflows/; then
        log_error "Absolute paths found in workflows"
    fi
}

check_workflow_unused_workflow_inputs() {
    log_warn "Unused inputs check not fully implemented"
}

check_security_token_leaks() {
    if [ -d ".github/workflows" ] && grep -rE "echo.*(github\.token|secrets\.)" .github/workflows/; then
        log_error "Potential GitHub Token/Secret leak via echo in workflows"
    fi
}

# --- Main Entry Point ---

if [ $# -eq 0 ]; then
    echo "=== Running All KibaOS Repository Audits ==="
    check_build_sh_set_e
    check_build_sh_pacman_populate
    check_build_sh_relative_symlinks
    check_build_sh_paperde_ldconfig
    check_build_sh_desktop_entry_kiba
    check_build_sh_sudoers_perms
    check_build_sh_liveuser_uid
    check_build_sh_wallpaper_consistency
    check_build_sh_octopi_usage
    check_build_sh_zsh_default
    check_markdown_empty_links
    check_repo_license_sanity
    check_repo_readme_badge_https
    check_security_chmod_777
    check_security_no_plaintext_chpasswd
    check_markdown_anchor_links
    check_hygiene_gitkeep
    check_repo_shell_extension_consistency
    check_hygiene_trailing_whitespace
    check_repo_no_nested_git_dir
    check_workflow_checkout_v4
    check_workflow_no_node_16_actions
    check_workflow_explicit_bash_shell
    check_workflow_no_empty_run_blocks
    check_workflow_job_permissions_only
    check_workflow_timeout_reasonable
    check_workflow_kebab_filenames_strict
    check_workflow_no_absolute_script_paths
    check_workflow_unused_workflow_inputs
    check_security_token_leaks
else
    case "$1" in
        --build-sh-set-e) check_build_sh_set_e ;;
        --build-sh-pacman-populate) check_build_sh_pacman_populate ;;
        --build-sh-relative-symlinks) check_build_sh_relative_symlinks ;;
        --build-sh-paperde-ldconfig) check_build_sh_paperde_ldconfig ;;
        --build-sh-desktop-entry-kiba) check_build_sh_desktop_entry_kiba ;;
        --build-sh-sudoers-perms) check_build_sh_sudoers_perms ;;
        --build-sh-liveuser-uid) check_build_sh_liveuser_uid ;;
        --build-sh-wallpaper-consistency) check_build_sh_wallpaper_consistency ;;
        --build-sh-octopi-usage) check_build_sh_octopi_usage ;;
        --build-sh-zsh-default) check_build_sh_zsh_default ;;
        --markdown-empty-links) check_markdown_empty_links ;;
        --repo-license-sanity) check_repo_license_sanity ;;
        --repo-readme-badge-https) check_repo_readme_badge_https ;;
        --security-chmod-777) check_security_chmod_777 ;;
        --security-no-plaintext-chpasswd) check_security_no_plaintext_chpasswd ;;
        --markdown-anchor-links) check_markdown_anchor_links ;;
        --hygiene-gitkeep) check_hygiene_gitkeep ;;
        --repo-shell-extension-consistency) check_repo_shell_extension_consistency ;;
        --hygiene-trailing-whitespace) check_hygiene_trailing_whitespace ;;
        --repo-no-nested-git-dir) check_repo_no_nested_git_dir ;;
        --workflow-checkout-v4) check_workflow_checkout_v4 ;;
        --workflow-no-node-16-actions) check_workflow_no_node_16_actions ;;
        --workflow-explicit-bash-shell) check_workflow_explicit_bash_shell ;;
        --workflow-no-empty-run-blocks) check_workflow_no_empty_run_blocks ;;
        --workflow-job-permissions-only) check_workflow_job_permissions_only ;;
        --workflow-timeout-reasonable) check_workflow_timeout_reasonable ;;
        --workflow-kebab-filenames-strict) check_workflow_kebab_filenames_strict ;;
        --workflow-no-absolute-script-paths) check_workflow_no_absolute_script_paths ;;
        --workflow-unused-workflow-inputs) check_workflow_unused_workflow_inputs ;;
        --security-token-leaks) check_security_token_leaks ;;
        *) echo "Unknown check: $1"; exit 1 ;;
    esac
fi

exit $EXIT_CODE
