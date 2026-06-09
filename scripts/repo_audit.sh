#!/bin/bash
# License: MIT
set -euo pipefail

# KibaOS Repository Audit Script
# Consolidates multiple repository health and security checks
# Each check is defined as a function starting with audit_

EXIT_CODE=0

log_error() {
    echo "ERROR: $1"
    EXIT_CODE=1
}

log_warn() {
    echo "WARN: $1"
}

# --- Audit Functions ---

audit_build_sh_customize_set_e() {
    if [ -f "build.sh" ]; then
        if ! grep -A 2 "cat > \"\${AIROOTFS}/root/customize_airootfs.sh\"" build.sh | grep -q "set -e"; then
            log_error "customize_airootfs.sh in build.sh is missing set -e"
        fi
    fi
}

audit_build_sh_pacman_populate() {
    if [ -f "build.sh" ]; then
        if ! grep -q "pacman-key --populate archlinux" build.sh; then
            log_error "build.sh is missing pacman-key --populate archlinux"
        fi
    fi
}

audit_build_sh_relative_symlinks() {
    if [ -f "build.sh" ]; then
        if grep -q "ln -s /" build.sh | grep -vE "(/dev/|/proc/|/sys/)"; then
            log_warn "build.sh may contain absolute symlinks"
        fi
    fi
}

audit_build_sh_paperde_ldconfig() {
    if [ -f "build.sh" ]; then
        if grep -q "paperde" build.sh && ! grep -A 20 "paperde" build.sh | grep -q "ldconfig"; then
            log_warn "ldconfig might be missing after PaperDE build"
        fi
    fi
}

audit_build_sh_desktop_entry_kiba() {
    if [ -f "build.sh" ]; then
        if ! grep -q "kiba.desktop" build.sh; then
            log_warn "Kiba desktop entry not referenced in build.sh"
        fi
    fi
}

audit_build_sh_sudoers_perms() {
    if [ -f "build.sh" ]; then
        if grep -q "sudoers" build.sh && ! grep -q "0440" build.sh; then
            log_error "sudoers file in build.sh may have incorrect permissions (should be 0440)"
        fi
    fi
}

audit_build_sh_liveuser_uid() {
    if [ -f "build.sh" ]; then
        if grep -q "liveuser" build.sh && ! grep -q "1000:1000" build.sh; then
            log_error "liveuser UID/GID 1000 is not explicitly set in build.sh"
        fi
    fi
}

audit_build_sh_wallpaper_consistency() {
    if [ -f "build.sh" ]; then
        if grep -q "wallpaper" build.sh && ! ls branding/wallpaper.png >/dev/null 2>&1; then
            log_warn "Wallpaper reference in build.sh but file missing in branding/"
        fi
    fi
}

audit_build_sh_octopi_usage() {
    if [ -f "build.sh" ]; then
        if ! grep -q "octopi" build.sh; then
            log_warn "Octopi package manager not found in build.sh"
        fi
    fi
}

audit_build_sh_zsh_default() {
    if [ -f "build.sh" ]; then
        if ! grep -q "chsh -s /usr/bin/zsh" build.sh; then
            log_warn "Zsh is not set as default shell in build.sh"
        fi
    fi
}

audit_markdown_empty_link_check() {
    if grep -rE "\[[^]]*\]\(\)" . --include="*.md" | grep -v "node_modules"; then
        log_error "Found empty markdown targets"
    fi
}

audit_repo_license_sanity() {
    if [ ! -f "LICENSE" ]; then
        log_error "LICENSE file missing"
    fi
}

audit_repo_readme_badge_https() {
    if grep -q "http://" README.md | grep "img.shields.io"; then
        log_error "Shields.io badges in README should use HTTPS"
    fi
}

audit_repo_no_chmod_777_strict() {
    if grep -rE "chmod (0?777|777)" . --exclude-dir=.git --exclude="repo_audit.sh"; then
        log_error "Found dangerous chmod 777"
    fi
}

audit_repo_no_plaintext_chpasswd() {
    if grep -r "chpasswd" . --exclude-dir=.git --exclude="repo_audit.sh" | grep -v "\-e"; then
        log_error "Found plaintext chpasswd usage (use -e with encrypted hashes)"
    fi
}

audit_repo_markdown_anchor_links() {
    BAD_ANCHORS=$(grep -rhE "\[[^]]+\]\(#[^)]+\)" . --include="*.md" | grep -vE "\(#[a-z0-9-]+\)" || true)
    if [ -n "$BAD_ANCHORS" ]; then
        log_warn "Malformed internal anchors (recommend #lowercase-kebab): $BAD_ANCHORS"
    fi
}

audit_repo_gitkeep_no_extension() {
    if find . -name "*.gitkeep" | grep -q ".gitkeep"; then
        log_error "Found .gitkeep with extension (should be exactly '.gitkeep')"
    fi
}

audit_repo_shell_extension_consistency() {
    if find . -maxdepth 1 -name "*.shell" | grep -q ".shell"; then
        log_warn "Found .shell extension (recommend .sh for consistency)"
    fi
}

audit_repo_trailing_whitespace_all() {
    if grep -rI "[[:blank:]]$" . --exclude-dir=.git --exclude="pnpm-lock.yaml" --exclude="*.png" --exclude="*.jpg" --exclude="*.webp" --exclude="*.ico"; then
        log_error "Found trailing whitespace"
    fi
}

audit_repo_no_nested_git_dir() {
    NESTED_GIT=$(find . -mindepth 2 -name ".git" -type d)
    if [ -n "$NESTED_GIT" ]; then
        log_error "Found nested .git directories"
    fi
}

audit_workflow_checkout_v4() {
    if grep -r "uses: actions/checkout@" .github/workflows/ | grep -vE "@v4|@[a-f0-9]{40}"; then
        log_error "Outdated actions/checkout version (upgrade to @v4)"
    fi
}

audit_workflow_no_node_16_actions() {
    if grep -r "node16" .github/workflows/; then
        log_error "Found actions using Node 16 (deprecated)"
    fi
}

audit_workflow_explicit_bash_shell() {
    if grep -r "run:" .github/workflows/ | grep -v "shell: bash"; then
        log_warn "Workflow steps with 'run' should explicitly set 'shell: bash'"
    fi
}

audit_workflow_no_empty_run_blocks() {
    if grep -r "run: \"\"" .github/workflows/ || grep -r "run: ''" .github/workflows/; then
        log_error "Empty run blocks found in workflows"
    fi
}

audit_workflow_job_permissions_only() {
    if grep -q "permissions:" .github/workflows/*.yml && ! grep -q "jobs:.*permissions:" .github/workflows/*.yml; then
         log_warn "Global permissions found; prefer per-job permissions for least privilege"
    fi
}

audit_workflow_timeout_reasonable() {
    if grep -r "timeout-minutes:" .github/workflows/ | grep -vE "timeout-minutes: [1-9][0-9]?"; then
        log_warn "Workflows should have reasonable timeouts (e.g., < 100 minutes)"
    fi
}

audit_workflow_kebab_filenames_strict() {
    for f in .github/workflows/*; do
        filename=$(basename "$f")
        if [[ "$filename" =~ [A-Z_] ]]; then
             log_warn "Workflow filename '$filename' should be kebab-case"
        fi
    done
}

audit_workflow_no_absolute_script_paths() {
    if grep -r "/home/runner/work" .github/workflows/; then
        log_error "Absolute paths found in workflows; use GITHUB_WORKSPACE instead"
    fi
}

audit_workflow_unused_workflow_inputs() {
    # Check for defined inputs that aren't referenced by ${{ inputs.
    for f in .github/workflows/*.yml; do
        if grep -q "inputs:" "$f"; then
            # This is a bit complex for a shell script but we can try
            inputs=$(sed -n '/inputs:/,/^[a-z]/p' "$f" | grep "^  [a-z]" | sed 's/://;s/ //g')
            for i in $inputs; do
                if ! grep -q "\${{ inputs.$i }}" "$f"; then
                    log_warn "Input '$i' in $f might be unused"
                fi
            done
        fi
    done
}

audit_workflow_no_github_token_leak() {
    # Avoid false positive on this script by excluding repo_audit.sh
    if grep -rE "echo.*(github\.token|secrets\.)" .github/workflows/ --exclude="repo_audit.sh"; then
        log_error "Potential GitHub Token/Secret leak via echo in workflows"
    fi
}

# --- Dispatcher ---

run_all() {
    echo "=== Running All Audits ==="
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
    echo "=== Audits Complete ==="
}

if [[ $# -eq 0 ]]; then
    run_all
elif [[ "$1" == "--check" ]]; then
    check_name="$2"
    # Prefix with audit_ if not present
    if [[ ! "$check_name" =~ ^audit_ ]]; then
        check_name="audit_$check_name"
    fi
    # Check if function exists
    if declare -f "$check_name" > /dev/null; then
        echo "Running check: $check_name"
        "$check_name"
    else
        echo "Error: Check '$check_name' not found."
        exit 1
    fi
else
    echo "Usage: $0 [--check <audit_function_name>]"
    exit 1
fi

exit $EXIT_CODE
