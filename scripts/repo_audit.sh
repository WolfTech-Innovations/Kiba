#!/bin/bash
set -euo pipefail

# KibaOS Repository Audit Script
# Consolidates multiple repository health and security checks

EXIT_CODE=0
RUN_ALL=true

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
        if grep -q "ln -s /" build.sh; then
            log_error "Found absolute symlinks in build.sh, use relative instead"
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
        if ! grep -q "kibaos-install.desktop" build.sh; then
             log_warn "build.sh might be missing kibaos-install.desktop entry installation"
        fi
    fi
}

audit_build_sh_sudoers_perms() {
    if [ -f "build.sh" ]; then
        if grep -q "etc/sudoers" build.sh && ! grep -q "440" build.sh; then
            log_error "Potential insecure permissions for sudoers in build.sh (should be 440)"
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
        WALLPAPER_COUNT=$(grep -c "wallpaper" build.sh || true)
        if [ "$WALLPAPER_COUNT" -gt 10 ]; then
             log_warn "High number of wallpaper references in build.sh ($WALLPAPER_COUNT), check for consistency"
        fi
    fi
}

audit_build_sh_octopi_usage() {
    if [ -f "build.sh" ]; then
        if grep -q "octopi" build.sh && ! grep -q "octopi-notifier" build.sh; then
            log_warn "Octopi found in build.sh but octopi-notifier might be missing"
        fi
    fi
}

audit_build_sh_zsh_default() {
    if [ -f "build.sh" ]; then
        if grep -q "chsh" build.sh && ! grep -q "/usr/bin/zsh" build.sh; then
            log_warn "chsh used but zsh might not be set as default"
        fi
    fi
}

audit_markdown_empty_link_check() {
    if grep -rE "\[[^]]*\]\(\)" . --include="*.md" --exclude-dir=.git | grep -v "node_modules" | grep -v ".Jules"; then
        log_error "Found empty markdown targets"
    fi
}

audit_repo_license_sanity() {
    if [ ! -f "LICENSE" ]; then
        log_error "LICENSE file is missing"
    fi
}

audit_repo_readme_badge_https() {
    if [ -f "README.md" ]; then
        if grep "http://" README.md | grep -q "img.shields.io"; then
            log_error "README badges should use HTTPS"
        fi
    fi
}

audit_repo_no_chmod_777_strict() {
    if grep -rE "chmod (0?777|777)" . --exclude-dir=.git --exclude-dir=.github --exclude="workflows_to_add.txt" --exclude="*.md" --exclude="repo_audit.sh" --exclude="build.sh"; then
        log_error "Found dangerous chmod 777"
    fi
}

audit_repo_no_plaintext_chpasswd() {
    if grep -r "chpasswd" . --exclude-dir=.git --exclude-dir=.github --exclude="workflows_to_add.txt" --exclude="*.md" --exclude="repo_audit.sh" | grep -v "chpasswd -e"; then
        log_error "Found chpasswd usage without -e (potential plaintext password)"
    fi
}

audit_repo_markdown_anchor_links() {
    BAD_ANCHORS=$(grep -rhE "\[[^]]+\]\(#[^)]+\)" . --include="*.md" --exclude-dir=.git | grep -vE "\(#[a-z0-9-]+\)" || true)
    if [ -n "$BAD_ANCHORS" ]; then
        log_warn "Malformed internal anchors (recommend #lowercase-kebab):"
        echo "$BAD_ANCHORS"
    fi
}

audit_repo_gitkeep_no_extension() {
    BAD_GITKEEP=$(find . -name ".gitkeep.*" -not -path "*/.git/*")
    if [ -n "$BAD_GITKEEP" ]; then
        log_error ".gitkeep files should not have extensions: $BAD_GITKEEP"
    fi
}

audit_repo_shell_extension_consistency() {
    if find . -name "*.bash" -type f -not -path "*/.git/*" | grep -q "."; then
        log_warn "Found .bash extension; project standard is .sh"
    fi
}

audit_repo_trailing_whitespace_all() {
    if grep -rI "[[:blank:]]$" . --exclude-dir=.git --exclude-dir=.github --exclude="workflows_to_add.txt" --exclude="pnpm-lock.yaml" --exclude="*.png" --exclude="*.jpg" --exclude="*.svg"; then
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
    if [ -d ".github/workflows" ]; then
        if grep -r "uses: actions/checkout@" .github/workflows/ | grep -vE "@v4|@[a-f0-9]{40}"; then
            log_error "Outdated actions/checkout version (upgrade to @v4)"
        fi
    fi
}

audit_workflow_no_node_16_actions() {
    if [ -d ".github/workflows" ]; then
        if grep -r "uses: actions/setup-node@" .github/workflows/ | grep -q "@v1\|@v2\|@v3"; then
             log_warn "Consider upgrading setup-node to @v4"
        fi
    fi
}

audit_workflow_explicit_bash_shell() {
    if [ -d ".github/workflows" ]; then
        # Robust check for run blocks missing shell specification
        grep -rA 2 "run:" .github/workflows/ | grep -v "\--" | grep "run:" | while read -r line; do
            file=$(echo "$line" | cut -d':' -f1)
            content=$(echo "$line" | cut -d':' -f2-)
            if ! grep -A 2 "$content" "$file" | grep -q "shell: bash"; then
                 if [[ ! "$file" =~ audit- ]]; then
                    log_warn "Run block in $file might be missing explicit shell: bash"
                 fi
            fi
        done
    fi
}

audit_workflow_no_empty_run_blocks() {
    if [ -d ".github/workflows" ]; then
        if grep -rE "run: [\"']{2}" .github/workflows/ ; then
            log_error "Found empty run blocks in workflows"
        fi
    fi
}

audit_workflow_job_permissions_only() {
    if [ -d ".github/workflows" ]; then
        if grep -r "permissions: write-all" .github/workflows/; then
            log_error "Avoid permissions: write-all, use granular permissions"
        fi
    fi
}

audit_workflow_timeout_reasonable() {
    if [ -d ".github/workflows" ]; then
        if grep -r "timeout-minutes:" .github/workflows/ | grep -vE " [1-9][0-9]?$"; then
             log_warn "Found potentially unreasonable or missing timeout-minutes"
        fi
    fi
}

audit_workflow_kebab_filenames_strict() {
    if [ -d ".github/workflows" ]; then
        for f in .github/workflows/*.yml; do
            [ -e "$f" ] || continue
            if [[ "$(basename "$f")" =~ [A-Z] ]] || [[ "$(basename "$f")" =~ _ ]]; then
                log_error "Workflow filename $(basename "$f") should be kebab-case"
            fi
        done
    fi
}

audit_workflow_no_absolute_script_paths() {
    if [ -d ".github/workflows" ]; then
        if grep -r "run: /" .github/workflows/ | grep -v "shell: bash"; then
             log_warn "Found potential absolute path in workflow run block"
        fi
    fi
}

audit_workflow_unused_workflow_inputs() {
    if [ -d ".github/workflows" ]; then
        for f in .github/workflows/*.yml; do
            [ -e "$f" ] || continue
            DECLARED=$(grep -A 50 "inputs:" "$f" | grep -oE "^  [a-zA-Z0-9_-]+:" | tr -d ' :' | xargs || true)
            for input in $DECLARED; do
                if ! grep -q "inputs.$input" "$f"; then
                    log_warn "Workflow input '$input' in $f might be unused"
                fi
            done
        done
    fi
}

audit_workflow_no_github_token_leak() {
    if [ -d ".github/workflows" ]; then
        if grep -rE "echo.*(github\.token|secrets\.)" .github/workflows/; then
            log_error "Potential GitHub Token/Secret leak via echo in workflows"
        fi
    fi
}

# --- Argument Parsing ---

if [[ $# -gt 0 ]]; then
    RUN_ALL=false
    while [[ $# -gt 0 ]]; do
        case "$1" in
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
            *) log_error "Unknown argument: $1" ;;
        esac
        shift
    done
fi

if [ "$RUN_ALL" = true ]; then
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
fi

exit $EXIT_CODE
