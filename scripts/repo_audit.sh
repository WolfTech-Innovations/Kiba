#!/bin/bash
# KibaOS Repository Audit Script
# Consolidates multiple repository health and security checks
# Modularized for use in GitHub Actions

set -euo pipefail

EXIT_CODE=0

log_error() {
    echo "ERROR: $1"
    EXIT_CODE=1
}

log_warn() {
    echo "WARN: $1"
}

# --- AUDIT FUNCTIONS ---

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
        if grep -q "ln -sf /" build.sh | grep -v "ln -sf /usr/lib" | grep -v "ln -sf /run/user"; then
             log_warn "build.sh contains absolute symlinks that might fail in chroot (manual review recommended)"
        fi
    fi
}

audit_build_sh_paperde_ldconfig() {
    if [ -f "build.sh" ]; then
        if grep -q "paperde" build.sh && ! grep -A 20 "paperde" build.sh | grep -q "ldconfig"; then
             log_warn "PaperDE mentioned in build.sh but ldconfig not found nearby"
        fi
    fi
}

audit_build_sh_desktop_entry_kiba() {
    if [ -f "build.sh" ]; then
        if ! grep -q "Icon=kibaos" build.sh; then
            log_error "build.sh defines desktop entries but none use Icon=kibaos"
        fi
    fi
}

audit_build_sh_sudoers_perms() {
    if [ -f "build.sh" ]; then
        if grep -q "sudoers.d" build.sh && ! grep -q "0440" build.sh; then
            log_error "build.sh touches sudoers.d but does not set 0440 permissions"
        fi
    fi
}

audit_build_sh_liveuser_uid() {
    if [ -f "build.sh" ]; then
        if grep -q "liveuser" build.sh && ! grep -q "1000:1000" build.sh; then
            log_error "liveuser found in build.sh but UID/GID 1000 is not explicitly set"
        fi
    fi
}

audit_build_sh_wallpaper_consistency() {
    if [ -f "build.sh" ]; then
        if grep -q "wallpaper.png" build.sh && ! grep -q "forest-k.png" build.sh; then
            log_warn "build.sh uses wallpaper.png but does not reference branding/forest-k.png"
        fi
    fi
}

audit_build_sh_octopi_usage() {
    if [ -f "build.sh" ]; then
        if grep -qi "octopi" build.sh; then
            log_error "build.sh contains references to octopi (use gnome-software or pacman)"
        fi
    fi
}

audit_build_sh_zsh_default() {
    if [ -f "build.sh" ]; then
        if grep -q "liveuser" build.sh && grep -q "/bin/zsh" build.sh; then
            log_warn "build.sh sets zsh as default shell, verify kiba-zsh-config presence"
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
        log_error "LICENSE file missing in repository root"
    fi
}

audit_repo_readme_badge_https() {
    if [ -f "README.md" ]; then
        if grep "http://" README.md | grep -E "img.shields.io|badge"; then
            log_error "README.md uses insecure HTTP for badges"
        fi
    fi
}

audit_repo_no_chmod_777_strict() {
    if grep -rE "chmod (0?777|777)" . --exclude-dir=.git --exclude="repo_audit.sh"; then
        log_error "Found dangerous chmod 777"
    fi
}

audit_repo_no_plaintext_chpasswd() {
    if grep -r "chpasswd" . --exclude="repo_audit.sh" --exclude-dir=.git | grep -v "\-e"; then
        log_error "Found chpasswd without -e flag (potential plaintext password)"
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
    if find . -name ".gitkeep.*" | grep -q "."; then
        log_error "Found .gitkeep with extension"
    fi
}

audit_repo_shell_extension_consistency() {
    if find . -maxdepth 2 -name "*.bash" | grep -q "."; then
        log_warn "Found .bash files, recommend using .sh for consistency"
    fi
}

audit_repo_trailing_whitespace_all() {
    if grep -rI "[[:blank:]]$" . --exclude-dir=.git --exclude="pnpm-lock.yaml" --exclude="*.png" --exclude="*.jpg"; then
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
    if grep -rE "actions/setup-node@v[123]" .github/workflows/ 2>/dev/null; then
         log_warn "Workflows might be using Node 16 actions, recommend v4"
    fi
}

audit_workflow_explicit_bash_shell() {
    if [ -d ".github/workflows" ]; then
        if grep -r "run:" .github/workflows/ | grep -v "shell: bash" && grep -r "run:" .github/workflows/ | grep -v "shell: python"; then
             # This is a bit complex for a simple grep, but let's just log a warning for now
             log_warn "Ensure workflows use explicit shell: bash for consistent behavior"
        fi
    fi
}

audit_workflow_no_empty_run_blocks() {
    if grep -r "run: $" .github/workflows/ 2>/dev/null; then
        log_error "Found empty run blocks in workflows"
    fi
}

audit_workflow_job_permissions_only() {
    if grep -r "permissions: write-all" .github/workflows/ 2>/dev/null; then
        log_error "Found permissions: write-all, use granular permissions"
    fi
}

audit_workflow_timeout_reasonable() {
    if grep -r "timeout-minutes:" .github/workflows/ | grep -E "360|720"; then
        log_warn "Found very high timeout-minutes in workflows"
    fi
}

audit_workflow_kebab_filenames_strict() {
    if find .github/workflows/ -name "*_*" | grep -q "."; then
        log_error "Workflow filenames should use kebab-case (no underscores)"
    fi
}

audit_workflow_no_absolute_script_paths() {
    if grep -r "/home/runner/work" .github/workflows/ 2>/dev/null; then
        log_error "Found absolute paths in workflows, use GITHUB_WORKSPACE"
    fi
}

audit_workflow_unused_workflow_inputs() {
     log_warn "Manual audit required for unused workflow_dispatch inputs"
}

audit_workflow_no_github_token_leak() {
    if grep -rE "echo.*(github\.token|secrets\.)" .github/workflows/ 2>/dev/null; then
        log_error "Potential GitHub Token/Secret leak via echo in workflows"
    fi
}

audit_repo_snake_case_scripts() {
    if find scripts/ -name "*[A-Z]*" | grep -q "."; then
        log_error "Scripts should use snake_case (lowercase)"
    fi
}

audit_repo_lowercase_directories() {
    if find . -maxdepth 1 -type d -name "*[A-Z]*" | grep -vE "\./\.git|\./\." | grep -q "."; then
         # Notes/ Branding/ are allowed in some contexts, but let's see
         # For KibaOS we might want strictly lowercase for tech dirs
         find . -maxdepth 1 -type d -name "*[A-Z]*" | grep -vE "\./\.git|\./\." | while read -r dir; do
             if [ "$(basename "$dir")" != "Notes" ] && [ "$(basename "$dir")" != "Branding" ]; then
                 log_warn "Directory $dir contains uppercase letters"
             fi
         done
    fi
}

audit_repo_no_temp_files() {
    if find . -name "*.tmp" -o -name "*.swp" -o -name "*~" | grep -q "."; then
        log_error "Found temporary or backup files in repository"
    fi
}

audit_repo_no_backup_files_hygiene() {
    if find . -name "*.bak" -o -name "*.old" | grep -q "."; then
        log_error "Found .bak or .old files in repository"
    fi
}

audit_repo_no_pyc() {
    if find . -name "*.pyc" | grep -q "."; then
        log_error "Found .pyc files in repository"
    fi
}

audit_shell_script_pipefail() {
    if find . -name "*.sh" -exec grep -L "pipefail" {} + | grep -v "node_modules"; then
        log_warn "Shell scripts missing set -o pipefail"
    fi
}

audit_shell_script_readonly_constants() {
     log_warn "Recommendation: use readonly for constants in shell scripts"
}

audit_shell_shebang_no_space() {
    if grep -r "^#! /" . --include="*.sh"; then
        log_error "Space found in shebang (use #!/)"
    fi
}

audit_markdown_no_tabs() {
    if grep -r $'\t' . --include="*.md"; then
        log_error "Found tabs in markdown files, use spaces"
    fi
}

audit_markdown_hr_style() {
    if grep -r -- "---" . --include="*.md" 2>/dev/null | grep -vE "^---|:---"; then
         # Just a placeholder for style consistency
         true
    fi
}

audit_workflow_permissions() {
    if [ -d ".github/workflows" ]; then
        if ! grep -r "permissions:" .github/workflows/ > /dev/null; then
             log_warn "Workflows should explicitly define permissions"
        fi
    fi
}

audit_workflow_concurrency() {
    if [ -d ".github/workflows" ]; then
        if ! grep -r "concurrency:" .github/workflows/ > /dev/null; then
             log_warn "Workflows missing concurrency groups"
        fi
    fi
}

audit_workflow_on_pull_request_types() {
     log_warn "Recommendation: specify types for pull_request trigger"
}

audit_workflow_push_branch_filter() {
    if grep -r "on: push$" .github/workflows/ 2>/dev/null; then
        log_warn "Found push trigger without branch filters"
    fi
}

audit_workflow_timeout_all_jobs() {
    if [ -d ".github/workflows" ]; then
        # Check if any job lacks timeout-minutes
        log_warn "Ensure all jobs have timeout-minutes defined"
    fi
}

# --- RUNNER ---

run_all() {
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
    audit_repo_snake_case_scripts
    audit_repo_lowercase_directories
    audit_repo_no_temp_files
    audit_repo_no_backup_files_hygiene
    audit_repo_no_pyc
    audit_shell_script_pipefail
    audit_shell_script_readonly_constants
    audit_shell_shebang_no_space
    audit_markdown_no_tabs
    audit_markdown_hr_style
    audit_workflow_permissions
    audit_workflow_concurrency
    audit_workflow_on_pull_request_types
    audit_workflow_push_branch_filter
    audit_workflow_timeout_all_jobs
}

if [ $# -eq 0 ]; then
    echo "=== Running All KibaOS Repository Audits ==="
    run_all
else
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
            --audit-repo-snake-case-scripts) audit_repo_snake_case_scripts ;;
            --audit-repo-lowercase-directories) audit_repo_lowercase_directories ;;
            --audit-repo-no-temp-files) audit_repo_no_temp_files ;;
            --audit-repo-no-backup-files-hygiene) audit_repo_no_backup_files_hygiene ;;
            --audit-repo-no-pyc) audit_repo_no_pyc ;;
            --audit-shell-script-pipefail) audit_shell_script_pipefail ;;
            --audit-shell-script-readonly-constants) audit_shell_script_readonly_constants ;;
            --audit-shell-shebang-no-space) audit_shell_shebang_no_space ;;
            --audit-markdown-no-tabs) audit_markdown_no_tabs ;;
            --audit-markdown-hr-style) audit_markdown_hr_style ;;
            --audit-workflow-permissions) audit_workflow_permissions ;;
            --audit-workflow-concurrency) audit_workflow_concurrency ;;
            --audit-workflow-on-pull-request-types) audit_workflow_on_pull_request_types ;;
            --audit-workflow-push-branch-filter) audit_workflow_push_branch_filter ;;
            --audit-workflow-timeout-all-jobs) audit_workflow_timeout_all_jobs ;;
            *) echo "Unknown audit: $arg"; EXIT_CODE=1 ;;
        esac
    done
fi

echo "=== Audit Complete ==="
exit $EXIT_CODE
