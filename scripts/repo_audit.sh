#!/bin/bash
set -euo pipefail

# KibaOS Repository Audit Script
# Consolidates multiple repository health and security checks
# Supports modular audits via --audit-<name> flags

EXIT_CODE=0

log_error() {
    echo "ERROR: $1"
    EXIT_CODE=1
}

log_warn() {
    echo "WARN: $1"
}

iterate_workflows() {
    local func=$1
    for wf in .github/workflows/*.yml; do
        [ -e "$wf" ] || continue
        "$func" "$wf"
    done
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
        if grep -q "ln -s /" build.sh; then
            log_error "build.sh contains absolute symlinks; use relative paths instead"
        fi
    fi
}

audit_build_sh_paperde_ldconfig() {
    if [ -f "build.sh" ]; then
        if grep -q "ninja -C paperde-src/build install" build.sh; then
            if ! grep -A 20 "ninja -C paperde-src/build install" build.sh | grep -q "ldconfig"; then
                log_error "ldconfig not found after PaperDE installation in build.sh"
            fi
        fi
    fi
}

audit_build_sh_desktop_entry_kiba() {
    if [ -f "build.sh" ]; then
        if ! grep -q "kibaos.desktop" build.sh; then
            log_warn "build.sh might be missing kibaos desktop entry references"
        fi
    fi
}

audit_build_sh_sudoers_perms() {
    if [ -f "build.sh" ]; then
        if grep -q "etc/sudoers.d" build.sh; then
            if ! grep -q "chmod 0440" build.sh; then
                log_error "build.sh modifies sudoers.d but does not enforce 0440 permissions"
            fi
        fi
    fi
}

audit_build_sh_liveuser_uid() {
    if [ -f "build.sh" ]; then
        if grep -q "liveuser" build.sh; then
            if ! grep -q "1000:1000" build.sh; then
                log_error "liveuser found in build.sh but UID/GID 1000 is not explicitly set"
            fi
        fi
    fi
}

audit_build_sh_wallpaper_consistency() {
    if [ -f "build.sh" ]; then
        local wp_url=$(grep "WALLPAPER_URL=" build.sh | cut -d'"' -f2)
        if [[ -n "$wp_url" && "$wp_url" != *"github.com/WolfTech-Innovations/Kiba"* ]]; then
            log_warn "Wallpaper URL in build.sh points to an external domain"
        fi
    fi
}

audit_build_sh_octopi_usage() {
    if [ -f "build.sh" ]; then
        if grep -q "octopi" build.sh; then
            log_warn "build.sh contains references to octopi (deprecated in favor of Budgie tools)"
        fi
    fi
}

audit_build_sh_zsh_default() {
    if [ -f "build.sh" ]; then
        if ! grep -q "chsh -s /usr/bin/zsh" build.sh && ! grep -q "SHELL=/usr/bin/zsh" build.sh; then
            log_warn "build.sh might not be setting Zsh as the default shell"
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
        log_error "LICENSE file is missing"
    fi
    if grep -q "Copyright (c) [0-9]\{4\}" LICENSE; then
        local year=$(date +%Y)
        if ! grep -q "$year" LICENSE; then
            log_warn "LICENSE year might be outdated"
        fi
    fi
}

audit_repo_readme_badge_https() {
    if [ -f "README.md" ]; then
        if grep "http://" README.md | grep -E "\.svg|\.png"; then
            log_error "README.md contains insecure badge links (use HTTPS)"
        fi
    fi
}

audit_repo_no_chmod_777_strict() {
    if grep -rE "chmod (0?777|777)" . --exclude-dir=.git --exclude="repo_audit.sh"; then
        log_error "Found dangerous chmod 777"
    fi
}

audit_repo_no_plaintext_chpasswd() {
    # Check for chpasswd usage without -e flag, excluding allowed paths
    if grep -r "chpasswd" . --exclude-dir={.git,.github,.Jules} --exclude="*.md" --exclude="workflows_to_add.txt" --exclude="repo_audit.sh" | grep -v "chpasswd -e"; then
        log_error "Found chpasswd usage without -e flag (plaintext passwords forbidden)"
    fi
}

audit_repo_markdown_anchor_links() {
    BAD_ANCHORS=$(grep -rhE "\[[^]]+\]\(#[^)]+\)" . --include="*.md" | grep -vE "\(#[a-z0-9-]+\)" || true)
    if [ -n "$BAD_ANCHORS" ]; then
        log_warn "Malformed internal anchors (recommend #lowercase-kebab):"
        echo "$BAD_ANCHORS"
    fi
}

audit_repo_gitkeep_no_extension() {
    BAD_GITKEEP=$(find . -name "?*.gitkeep")
    if [ -n "$BAD_GITKEEP" ]; then
        log_error "Non-standard .gitkeep files found (should not have prefixes): $BAD_GITKEEP"
    fi
}

audit_repo_shell_extension_consistency() {
    if find scripts/ -name "*.bash" | grep -q .; then
        log_warn "Found .bash extension in scripts/; use .sh for consistency"
    fi
}

audit_repo_trailing_whitespace_all() {
    if grep -rI "[[:blank:]]$" . --exclude-dir={.git,.github,.Jules} --exclude="pnpm-lock.yaml" --exclude="*.png" --exclude="*.jpg"; then
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
    _check() {
        if grep "uses: actions/checkout@" "$1" | grep -vE "@v4|@[a-f0-9]{40}"; then
            log_error "$1: Outdated actions/checkout version (upgrade to @v4)"
        fi
    }
    iterate_workflows _check
}

audit_workflow_no_node_16_actions() {
    _check() {
        if grep -qE "actions/setup-node@v[1-3]|actions/github-script@v[1-5]" "$1"; then
            log_error "$1: Uses actions likely dependent on Node 16 (deprecated)"
        fi
    }
    iterate_workflows _check
}

audit_workflow_explicit_bash_shell() {
    _check() {
        if grep -q "run:" "$1" && ! grep -q "shell: bash" "$1"; then
            log_warn "$1: Missing explicit shell: bash for run blocks"
        fi
    }
    iterate_workflows _check
}

audit_workflow_no_empty_run_blocks() {
    _check() {
        if grep -q "run: $" "$1"; then
            log_error "$1: Contains empty run block"
        fi
    }
    iterate_workflows _check
}

audit_workflow_job_permissions_only() {
    _check() {
        if grep -q "^permissions:" "$1"; then
            log_warn "$1: Top-level permissions found; prefer job-level permissions"
        fi
    }
    iterate_workflows _check
}

audit_workflow_timeout_reasonable() {
    _check() {
        local timeout=$(grep "timeout-minutes:" "$1" | awk '{print $2}' | head -1)
        if [[ -n "$timeout" && "$timeout" -gt 60 ]]; then
            log_warn "$1: High timeout-minutes detected ($timeout)"
        fi
    }
    iterate_workflows _check
}

audit_workflow_kebab_filenames_strict() {
    for wf in .github/workflows/*.yml; do
        filename=$(basename "$wf")
        if [[ "$filename" =~ [A-Z_] ]]; then
            log_error "Workflow filename $filename should be kebab-case"
        fi
    done
}

audit_workflow_no_absolute_script_paths() {
    _check() {
        if grep -E "run: .*/scripts/" "$1"; then
            log_error "$1: Found absolute path to scripts in run block"
        fi
    }
    iterate_workflows _check
}

audit_workflow_unused_workflow_inputs() {
    _check() {
        local wf_file="$1"
        local inputs=$(grep -oE "inputs\.[a-zA-Z0-9_-]+" "$wf_file" | sed 's/inputs\.//' | sort -u)
        local declared=$(grep -A 100 "workflow_dispatch:" "$wf_file" | grep -E "^[[:space:]]+[a-zA-Z0-9_-]+:" | sed -E 's/^[[:space:]]+//;s/://' | grep -vE "description|required|default|type|options" | sort -u || true)

        for input in $declared; do
            if ! grep -qE "inputs\.$input|github\.event\.inputs\.$input" "$wf_file"; then
                log_warn "$wf_file: Input '$input' is declared but never used"
            fi
        done
    }
    iterate_workflows _check
}

audit_workflow_no_github_token_leak() {
    _check() {
        if grep -rE "echo.*(github\.token|secrets\.)" "$1"; then
            log_error "$1: Potential GitHub Token/Secret leak via echo"
        fi
    }
    iterate_workflows _check
}

# --- Argument Parsing ---

if [ $# -eq 0 ]; then
    echo "=== Running Full KibaOS Repository Audit ==="
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
    echo "=== Audit Complete ==="
else
    while [[ $# -gt 0 ]]; do
        case $1 in
            --audit-*)
                # Convert --audit-some-flag to audit_some_flag
                func_name=$(echo "$1" | sed 's/^--audit-/audit_/' | sed 's/-/_/g')
                if declare -f "$func_name" > /dev/null; then
                    "$func_name"
                else
                    log_error "Unknown audit: $1 (function $func_name not found)"
                fi
                shift
                ;;
            *)
                log_error "Unknown argument: $1"
                shift
                ;;
        esac
    done
fi

exit $EXIT_CODE
