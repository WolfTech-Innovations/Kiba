#!/bin/bash
set -euo pipefail

# KibaOS Repository Audit Script
# Consolidates 45 granular repository health and security checks

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
    if [ -f "build.sh" ] && ! grep -q "pacman-key --populate archlinux" build.sh; then
        log_error "build.sh is missing pacman-key --populate archlinux"
    fi
}

audit_build_sh_relative_symlinks() {
    if [ -f "build.sh" ] && grep -q "ln -s /" build.sh; then
        log_warn "build.sh might contain absolute symlinks (ln -s /...)"
    fi
}

audit_build_sh_paperde_ldconfig() {
    if [ -f "build.sh" ] && grep -q "ninja -C paperde-src/build install" build.sh; then
        if ! grep -A 20 "ninja -C paperde-src/build install" build.sh | grep -q "ldconfig"; then
            log_error "ldconfig not found after PaperDE installation in build.sh"
        fi
    fi
}

audit_build_sh_desktop_entry_kiba() {
    if [ -f "build.sh" ] && ! grep -q "KibaOS.desktop" build.sh; then
        log_warn "build.sh does not seem to handle KibaOS.desktop entry"
    fi
}

audit_build_sh_sudoers_perms() {
    if [ -f "build.sh" ] && grep -q "etc/sudoers" build.sh && ! grep -q "chmod 440" build.sh; then
        log_warn "build.sh modifies sudoers but might not set 440 permissions"
    fi
}

audit_build_sh_liveuser_uid() {
    if [ -f "build.sh" ] && grep -q "liveuser" build.sh && ! grep -q "1000:1000" build.sh; then
        log_error "liveuser found in build.sh but UID/GID 1000 is not explicitly set"
    fi
}

audit_build_sh_wallpaper_consistency() {
    if [ -f "build.sh" ] && ! grep -q "branding/.*\.png" build.sh; then
        log_warn "build.sh might not be using branding wallpapers correctly"
    fi
}

audit_build_sh_octopi_usage() {
    if [ -f "build.sh" ] && grep -q "octopi" build.sh && ! grep -q "octopi-notifier" build.sh; then
        log_warn "octopi found in build.sh but octopi-notifier might be missing"
    fi
}

audit_build_sh_zsh_default() {
    if [ -f "build.sh" ] && ! grep -q "chsh -s /usr/bin/zsh" build.sh; then
        log_warn "zsh is not explicitly set as default shell in build.sh"
    fi
}

audit_markdown_empty_link_check() {
    if grep -rE "\[[^]]*\]\(\)" . --include="*.md" | grep -v "node_modules" | grep -v ".Jules"; then
        log_error "Found empty markdown targets"
    fi
}

audit_repo_license_sanity() {
    if [ ! -f "LICENSE" ]; then
        log_error "LICENSE file is missing"
    elif ! grep -q "Copyright" LICENSE; then
        log_warn "LICENSE file might be missing Copyright notice"
    fi
}

audit_repo_readme_badge_https() {
    if [ -f "README.md" ] && grep -q "http://" README.md | grep -q "img.shields.io"; then
        log_error "README badges should use HTTPS"
    fi
}

audit_repo_no_chmod_777_strict() {
    if grep -rE "chmod (0?777|777)" . --exclude-dir=.git --exclude-dir=.Jules; then
        log_error "Found dangerous chmod 777"
    fi
}

audit_repo_no_plaintext_chpasswd() {
    if grep -r "chpasswd" . --exclude-dir=.git --exclude-dir=.Jules --exclude="repo_audit.sh" | grep -v "chpasswd -e"; then
        log_error "Found chpasswd usage without -e flag (plaintext risk)"
    fi
}

audit_repo_markdown_anchor_links() {
    BAD_ANCHORS=$(grep -rhE "\[[^]]+\]\(#[^)]+\)" . --include="*.md" | grep -vE "\(#[a-z0-9-]+\)" | grep -v ".Jules" || true)
    if [ -n "$BAD_ANCHORS" ]; then
        log_warn "Malformed internal anchors (recommend #lowercase-kebab):"
        echo "$BAD_ANCHORS"
    fi
}

audit_repo_gitkeep_no_extension() {
    if find . -name "*.gitkeep" | grep -v ".Jules"; then
        log_error ".gitkeep files should not have extensions"
    fi
}

audit_repo_shell_extension_consistency() {
    if find scripts -type f ! -name "*.sh" ! -name ".*" | grep -v ".Jules"; then
        log_warn "Files in scripts/ should have .sh extension"
    fi
}

audit_repo_trailing_whitespace_all() {
    if grep -rI "[[:blank:]]$" . --exclude-dir=.git --exclude-dir=.Jules --exclude="pnpm-lock.yaml" --exclude="*.png" --exclude="*.jpg"; then
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
    if grep -r "uses: actions/setup-node@" .github/workflows/ | grep -q "@v3"; then
        log_warn "Outdated setup-node version (consider @v4 for Node 20+)"
    fi
}

audit_workflow_explicit_bash_shell() {
    if grep -r "run:" .github/workflows/ | xargs grep -L "shell: bash"; then
        log_warn "Workflows should explicitly specify shell: bash"
    fi
}

audit_workflow_no_empty_run_blocks() {
    if grep -r "run: \"\"" .github/workflows/ || grep -r "run: ''" .github/workflows/; then
        log_error "Found empty run blocks in workflows"
    fi
}

audit_workflow_job_permissions_only() {
    if grep -r "permissions:" .github/workflows/ | grep -v "jobs:" | grep -q "write"; then
        log_warn "Consider setting granular permissions at the job level"
    fi
}

audit_workflow_timeout_reasonable() {
    if grep -r "timeout-minutes:" .github/workflows/ | grep -vE "5|10|15|20|30|60"; then
        log_warn "Workflow timeout-minutes might be unusually high or missing"
    fi
}

audit_workflow_kebab_filenames_strict() {
    if find .github/workflows -name "*_*" -o -name "*[A-Z]*"; then
        log_error "Workflow filenames should be kebab-case"
    fi
}

audit_workflow_no_absolute_script_paths() {
    if grep -r "/home/runner/work" .github/workflows/; then
        log_error "Found absolute paths in workflows"
    fi
}

audit_workflow_unused_workflow_inputs() {
    # Simple check for input usage
    for wf in .github/workflows/*.yml; do
        if grep -q "workflow_dispatch:" "$wf"; then
            INPUTS=$(grep -A 20 "inputs:" "$wf" | grep ":" | grep -v "inputs:" | cut -d':' -f1 | tr -d ' ' || true)
            for input in $INPUTS; do
                if ! grep -q "inputs\.$input" "$wf"; then
                    log_warn "Input '$input' in $wf seems unused"
                fi
            done
        fi
    done
}

audit_workflow_no_github_token_leak() {
    if grep -rE "echo.*(github\.token|secrets\.)" .github/workflows/; then
        log_error "Potential GitHub Token/Secret leak via echo in workflows"
    fi
}

audit_repo_license_filename() {
    if [ -f "license" ] || [ -f "License" ]; then
        log_error "LICENSE filename should be all uppercase"
    fi
}

audit_repo_lowercase_directories() {
    if find . -maxdepth 2 -type d -name "*[A-Z]*" | grep -vE "\.git|\.github|\.Jules"; then
        log_warn "Directories should be lowercase"
    fi
}

audit_repo_no_backup_files_hygiene() {
    if find . -name "*~" -o -name "*.bak" -o -name "*.swp" | grep -v ".Jules"; then
        log_error "Found backup files in repository"
    fi
}

audit_repo_no_pyc() {
    if find . -name "*.pyc" | grep -v ".Jules"; then
        log_error "Found .pyc files in repository"
    fi
}

audit_repo_no_temp_files() {
    if find . -name "tmp.*" -o -name "test.*" | grep -v ".Jules" | grep -vE "scripts/|branding/|docs/"; then
        log_warn "Found potential temporary files"
    fi
}

audit_shell_script_pipefail() {
    if grep -r "set -e" scripts/ | xargs grep -L "pipefail"; then
        log_warn "Shell scripts should use set -o pipefail"
    fi
}

audit_shell_shebang_no_space() {
    if grep -r "^#! /" scripts/ || grep -r "^#! /" build.sh; then
        log_warn "Shebang should not have a space after #!"
    fi
}

audit_workflow_extension_strict() {
    if find .github/workflows -name "*.yaml"; then
        log_warn "Workflows should use .yml extension instead of .yaml"
    fi
}

audit_workflow_permissions() {
    if ! grep -q "permissions: read-all" .github/workflows/*.yml 2>/dev/null; then
        log_warn "Top-level permissions: read-all is recommended"
    fi
}

audit_workflow_step_naming() {
    if grep -r "run:" .github/workflows/ | grep -B 1 "run:" | grep -v "name:"; then
        log_warn "Steps in workflows should have a name"
    fi
}

audit_repo_readme_toc_required() {
    if [ -f "README.md" ]; then
        LINE_COUNT=$(wc -l < README.md)
        if [ "$LINE_COUNT" -gt 100 ] && ! grep -qi "Table of Contents" README.md; then
            log_error "README.md exceeds 100 lines but is missing a Table of Contents"
        fi
    fi
}

audit_repo_readme_mandatory_sections() {
    if [ -f "README.md" ]; then
        for section in "Installation" "Usage" "License"; do
            if ! grep -qi "$section" README.md; then
                log_warn "README.md might be missing mandatory section: $section"
            fi
        done
    fi
}

audit_build_sh_customize_set_u() {
    if [ -f "build.sh" ]; then
        if ! grep -A 2 "cat > \"\${AIROOTFS}/root/customize_airootfs.sh\"" build.sh | grep -q "set -u"; then
            log_warn "customize_airootfs.sh in build.sh is missing set -u"
        fi
    fi
}

audit_repo_gitkeep_strictly_empty() {
    NON_EMPTY_GITKEEP=$(find . -name ".gitkeep" -type f -size +0)
    if [ -n "$NON_EMPTY_GITKEEP" ]; then
        log_error ".gitkeep files must be strictly empty (0 bytes): $NON_EMPTY_GITKEEP"
    fi
}

audit_workflow_timeout_minutes_presence() {
    if grep -r "jobs:" .github/workflows/ | xargs grep -L "timeout-minutes"; then
        log_warn "timeout-minutes should be present in all workflows"
    fi
}

# --- Main Logic ---

if [ $# -eq 0 ]; then
    echo "=== Running all KibaOS Repository Audits ==="
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
    audit_repo_license_filename
    audit_repo_lowercase_directories
    audit_repo_no_backup_files_hygiene
    audit_repo_no_pyc
    audit_repo_no_temp_files
    audit_shell_script_pipefail
    audit_shell_shebang_no_space
    audit_workflow_extension_strict
    audit_workflow_permissions
    audit_workflow_step_naming
    audit_repo_readme_toc_required
    audit_repo_readme_mandatory_sections
    audit_build_sh_customize_set_u
    audit_repo_gitkeep_strictly_empty
    audit_workflow_timeout_minutes_presence
else
    for arg in "$@"; do
        case $arg in
            --audit-*)
                func_name=$(echo "$arg" | sed 's/--audit-/audit_/g' | sed 's/-/_/g')
                if declare -f "$func_name" > /dev/null; then
                    echo "--- Running $arg ---"
                    "$func_name"
                else
                    log_error "Unknown audit: $arg"
                fi
                ;;
            *)
                log_error "Unknown argument: $arg"
                ;;
        esac
    done
fi

echo "=== Audit Complete ==="
exit $EXIT_CODE
