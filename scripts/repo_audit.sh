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

# Helper to iterate over workflows
iterate_workflows() {
    find .github/workflows -name "*.yml" -o -name "*.yaml"
}

echo "=== Running KibaOS Repository Audit ==="

audit_build_sh_customize_set_e() {
    echo "--- Auditing customize_airootfs.sh set -e ---"

    if [ -f "build.sh" ]; then
        if ! grep -A 2 "cat > "${AIROOTFS}/root/customize_airootfs.sh"" build.sh | grep -q "set -e"; then
            log_error "customize_airootfs.sh in build.sh is missing set -e"
        fi
    fi
}

audit_build_sh_pacman_populate() {
    echo "--- Auditing pacman-key populate ---"

    if [ -f "build.sh" ]; then
        if ! grep -q "pacman-key --populate archlinux" build.sh; then
            log_error "build.sh is missing pacman-key --populate archlinux"
        fi
    fi
}

audit_build_sh_relative_symlinks() {
    echo "--- Auditing relative symlinks in build.sh ---"

    if [ -f "build.sh" ]; then
        if grep "ln -s /" build.sh | grep -v "ln -s /usr/bin/" | grep -qv "\${AIROOTFS}"; then
             log_warn "Potential absolute host symlink found in build.sh"
        fi
    fi
}

audit_build_sh_paperde_ldconfig() {
    echo "--- Auditing ldconfig after PaperDE build ---"

    if [ -f "build.sh" ]; then
        if grep -q "ninja -C paperde-src/build install" build.sh; then
            if ! grep -A 20 "ninja -C paperde-src/build install" build.sh | grep -q "ldconfig"; then
                log_error "ldconfig not found after PaperDE installation in build.sh"
            fi
        fi
    fi
}

audit_build_sh_desktop_entry_kiba() {
    echo "--- Auditing KibaOS desktop entry ---"

    if [ -f "build.sh" ]; then
        if ! grep -q "KibaOS.desktop" build.sh; then
            log_warn "KibaOS.desktop reference not found in build.sh"
        fi
    fi
}

audit_build_sh_sudoers_perms() {
    echo "--- Auditing sudoers permissions in build.sh ---"

    if [ -f "build.sh" ]; then
        if grep -q "/etc/sudoers.d/" build.sh && ! grep -q "chmod 440.*/etc/sudoers.d/" build.sh; then
            log_error "Sudoers snippets in build.sh might have wrong permissions (expected 440)"
        fi
    fi
}

audit_build_sh_liveuser_uid() {
    echo "--- Auditing liveuser UID consistency ---"

    if [ -f "build.sh" ]; then
        if grep -q "liveuser" build.sh; then
            if ! grep -q "1000:1000" build.sh; then
                log_error "liveuser found in build.sh but UID/GID 1000 is not explicitly set"
            fi
        fi
    fi
}

audit_build_sh_wallpaper_consistency() {
    echo "--- Auditing wallpaper consistency ---"

    if [ -f "build.sh" ]; then
        if grep -q "wallpaper" build.sh && ! grep -q "/usr/share/backgrounds" build.sh; then
             log_warn "Wallpaper referenced in build.sh but not in standard path"
        fi
    fi
}

audit_build_sh_octopi_usage() {
    echo "--- Auditing Octopi usage ---"

    if [ -f "build.sh" ]; then
        if grep -q "pamac" build.sh; then
            log_error "Pamac found in build.sh, KibaOS prefers Octopi"
        fi
    fi
}

audit_build_sh_zsh_default() {
    echo "--- Auditing Zsh default shell ---"

    if [ -f "build.sh" ]; then
        if ! grep -q "chsh -s /usr/bin/zsh liveuser" build.sh; then
            log_error "Zsh is not set as default shell for liveuser in build.sh"
        fi
    fi
}

audit_markdown_empty_link_check() {
    echo "--- Auditing empty markdown links ---"

    if grep -rE "\[[^]]*\]\(\)" . --include="*.md" | grep -v "node_modules"; then
        log_error "Found empty markdown targets"
    fi
}

audit_repo_license_sanity() {
    echo "--- Auditing LICENSE file ---"

    if [ ! -f "LICENSE" ]; then
        log_error "LICENSE file is missing"
    fi
}

audit_repo_readme_badge_https() {
    echo "--- Auditing README badge HTTPS ---"

    if [ -f "README.md" ]; then
        if grep "\[!\[" README.md | grep -q "http://"; then
            log_error "Insecure badge link (HTTP) found in README.md"
        fi
    fi
}

audit_repo_no_chmod_777_strict() {
    echo "--- Auditing chmod 777 (Strict) ---"

    if grep -rE "chmod (0?777|777)" . --exclude-dir=.git --exclude-dir=.github --exclude="scripts/repo_audit.sh" --exclude-dir=.Jules --exclude="workflows_to_add.txt" --exclude="*.md"; then
        log_error "Found dangerous chmod 777"
    fi
}

audit_repo_no_plaintext_chpasswd() {
    echo "--- Auditing chpasswd plaintext ---"

    if grep -r "chpasswd" . --exclude-dir=.git --exclude-dir=.github --exclude="scripts/repo_audit.sh" --exclude-dir=.Jules --exclude="workflows_to_add.txt" --exclude="*.md" | grep -v "chpasswd -e" | grep -v "password"; then
        log_error "Found chpasswd usage without -e (potential plaintext password)"
    fi
}

audit_repo_markdown_anchor_links() {
    echo "--- Auditing markdown internal anchors ---"

    BAD_ANCHORS=$(grep -rhE "\[[^]]+\]\(#[^)]+\)" . --include="*.md" | grep -vE "\(#[a-z0-9-]+\)" || true)
    if [ -n "$BAD_ANCHORS" ]; then
        log_warn "Malformed internal anchors (recommend #lowercase-kebab):"
        echo "$BAD_ANCHORS"
    fi
}

audit_repo_gitkeep_no_extension() {
    echo "--- Auditing .gitkeep filenames ---"

    BAD_GITKEEP=$(find . -name ".gitkeep.*")
    if [ -n "$BAD_GITKEEP" ]; then
        log_error "Found .gitkeep files with extensions: $BAD_GITKEEP"
    fi
}

audit_repo_shell_extension_consistency() {
    echo "--- Auditing shell script extensions ---"

    BAD_EXT=$(find . -type f -not -path '*/.*' -not -path '*/node_modules/*' -exec grep -l '^#!/bin/' {} + | grep -v '\.sh$' | grep -v 'build.sh' || true)
    if [ -n "$BAD_EXT" ]; then
        log_warn "Shell scripts missing .sh extension: $BAD_EXT"
    fi
}

audit_repo_trailing_whitespace_all() {
    echo "--- Auditing trailing whitespace ---"

    if grep -rI "[[:blank:]]$" . --exclude-dir=.git --exclude="pnpm-lock.yaml" --exclude="*.png" --exclude="*.jpg" --exclude="*.webp" --exclude-dir=node_modules --exclude-dir=.Jules; then
        log_error "Found trailing whitespace"
    fi
}

audit_repo_no_nested_git_dir() {
    echo "--- Auditing nested .git directories ---"

    NESTED_GIT=$(find . -mindepth 2 -name ".git" -type d -not -path "./node_modules/*")
    if [ -n "$NESTED_GIT" ]; then
        log_error "Found nested .git directories"
    fi
}

audit_workflow_checkout_v4() {
    echo "--- Auditing actions/checkout version ---"

    if grep -r "uses: actions/checkout@" .github/workflows/ | grep -vE "@v4|@[a-f0-9]{40}"; then
        log_error "Outdated actions/checkout version (upgrade to @v4)"
    fi
}

audit_workflow_no_node_16_actions() {
    echo "--- Auditing Node 16 based actions ---"

    if grep -r "uses: actions/" .github/workflows/ | grep -vE "v4|v3" | grep -E "setup-node|setup-python|cache"; then
         log_warn "Found potentially outdated actions that may use Node 16"
    fi
}

audit_workflow_explicit_bash_shell() {
    echo "--- Auditing explicit bash shell in workflows ---"

    iterate_workflows | while read wf; do
        if grep -q "run:" "$wf" && ! grep -q "shell: bash" "$wf"; then
            log_warn "Workflow $wf has 'run' blocks but may be missing explicit 'shell: bash'"
        fi
    done
}

audit_workflow_no_empty_run_blocks() {
    echo "--- Auditing empty run blocks in workflows ---"

    iterate_workflows | while read wf; do
        if grep -q "run:[[:space:]]*$" "$wf"; then
            log_error "Workflow $wf contains empty run block"
        fi
    done
}

audit_workflow_job_permissions_only() {
    echo "--- Auditing job-level permissions ---"

    iterate_workflows | while read wf; do
        if grep -q "^permissions:" "$wf" && grep -q "  permissions:" "$wf"; then
             log_warn "Workflow $wf has both top-level and job-level permissions"
        fi
    done
}

audit_workflow_timeout_reasonable() {
    echo "--- Auditing workflow timeouts ---"

    if ! grep -r "timeout-minutes" .github/workflows/; then
        log_warn "No timeout-minutes found in workflows"
    fi
}

audit_workflow_kebab_filenames_strict() {
    echo "--- Auditing workflow filename casing ---"

    iterate_workflows | while read wf; do
        filename=$(basename "$wf")
        if [[ $filename =~ [A-Z] ]]; then
            log_error "Workflow filename $filename should be kebab-case"
        fi
    done
}

audit_workflow_no_absolute_script_paths() {
    echo "--- Auditing script paths in workflows ---"

    if grep -r "run: /" .github/workflows/; then
        log_error "Found absolute path in workflow run block"
    fi
}

audit_workflow_unused_workflow_inputs() {
    echo "--- Auditing unused workflow inputs ---"

    iterate_workflows | while read wf; do
        if grep -q "workflow_dispatch:" "$wf"; then
            # Simple check for inputs usage
            grep -A 20 "inputs:" "$wf" | grep -oE "^[[:space:]]+[a-zA-Z0-9_-]+:" | sed 's/://' | tr -d ' ' | while read i; do
                if ! grep -q "inputs\.$i" "$wf" && ! grep -q "github\.event\.inputs\.$i" "$wf"; then
                    log_warn "Input '$i' in $wf might be unused"
                fi
            done
        fi
    done
}

audit_workflow_no_github_token_leak() {
    echo "--- Auditing GitHub Token leaks ---"

    if grep -rE "echo.*(github\.token|secrets\.)" .github/workflows/; then
        log_error "Potential GitHub Token/Secret leak via echo in workflows"
    fi
}

audit_repo_snake_case_scripts() {
    echo "--- Auditing snake_case script names ---"

    BAD_SCRIPTS=$(find scripts -type f -name "*[- ]*" | grep -v ".yml" || true)
    if [ -n "$BAD_SCRIPTS" ]; then
        log_warn "Scripts should use snake_case: $BAD_SCRIPTS"
    fi
}

audit_repo_no_pyc() {
    echo "--- Auditing no .pyc files ---"

    PYC_FILES=$(find . -name "*.pyc" -not -path "*/node_modules/*")
    if [ -n "$PYC_FILES" ]; then
        log_error "Found .pyc files: $PYC_FILES"
    fi
}

audit_repo_no_temp_files() {
    echo "--- Auditing no temporary files ---"

    TEMP_FILES=$(find . -name "*~" -o -name "*.swp" -o -name "*.tmp" -not -path "*/node_modules/*")
    if [ -n "$TEMP_FILES" ]; then
        log_error "Found temporary files: $TEMP_FILES"
    fi
}

audit_repo_license_filename() {
    echo "--- Auditing LICENSE filename ---"

    if [ -f "license" ] || [ -f "License.txt" ]; then
        log_error "License file should be named LICENSE (all caps, no extension)"
    fi
}

audit_repo_readme_mandatory_sections() {
    echo "--- Auditing README sections ---"

    if [ -f "README.md" ]; then
        for section in "Features" "Installation" "Usage" "Contributing"; do
            if ! grep -q "## $section" README.md; then
                log_warn "README.md might be missing mandatory section: $section"
            fi
        done
    fi
}

audit_repo_pnpm_exclusive() {
    echo "--- Auditing pnpm exclusive ---"

    if [ -f "package-lock.json" ] || [ -f "yarn.lock" ]; then
        log_error "Found non-pnpm lockfiles. KibaOS is pnpm-exclusive."
    fi
}

audit_repo_lowercase_directories() {
    echo "--- Auditing lowercase directories ---"

    BAD_DIRS=$(find . -maxdepth 1 -type d -not -path '*/.*' -not -path './node_modules' -not -path './Notes' -not -path '.' | grep '[A-Z]' || true)
    if [ -n "$BAD_DIRS" ]; then
        log_warn "Top-level directories should be lowercase: $BAD_DIRS"
    fi
}

audit_repo_forbidden_binary_extensions() {
    echo "--- Auditing forbidden binaries ---"

    FORBIDDEN=$(find . -name "*.exe" -o -name "*.dll" -o -name "*.so" -not -path "*/node_modules/*" || true)
    if [ -n "$FORBIDDEN" ]; then
        log_error "Forbidden binary extensions found: $FORBIDDEN"
    fi
}

audit_repo_no_backup_files_hygiene() {
    echo "--- Auditing no backup files ---"

    BACKUP_FILES=$(find . -name "*.bak" -o -name "*.old" -o -name "*.orig" -not -path "*/node_modules/*" || true)
    if [ -n "$BACKUP_FILES" ]; then
        log_error "Found backup files: $BACKUP_FILES"
    fi
}

audit_repo_no_emojis() {
    echo "--- Auditing no emojis in code ---"

    if grep -rP "[\x{1F300}-\x{1F9FF}]" scripts/ build.sh --exclude-dir=.git --exclude-dir=.github | grep -v "welcome.html" | grep -v "build.sh"; then
         log_warn "Found emojis in scripts (except welcome.html/build.sh)"
    fi
}

audit_repo_no_symlink_to_self() {
    echo "--- Auditing no self-referencing symlinks ---"

    find . -type l | while read link; do
        if [ "$(readlink -f "$link")" == "$(readlink -f "$(dirname "$link")")" ]; then
            log_error "Symlink $link points to its own directory"
        fi
    done
}

audit_repo_dot_env_forbidden() {
    echo "--- Auditing no .env files ---"

    if find . -name ".env*" -not -path "*/node_modules/*" | grep -q ".env"; then
        log_error "Found .env file. Secrets should be in GitHub Secrets."
    fi
}

audit_repo_no_large_binaries_outside_branding() {
    echo "--- Auditing large binaries ---"

    LARGE=$(find . -size +1M -not -path "./branding/*" -not -path "./.git/*" -not -path "./node_modules/*" || true)
    if [ -n "$LARGE" ]; then
        log_warn "Large files (>1M) found outside branding/: $LARGE"
    fi
}

audit_repo_svg_metadata() {
    echo "--- Auditing SVG metadata ---"

    if find branding -name "*.svg" | xargs grep -l "Adobe Illustrator" ; then
        log_warn "SVGs in branding/ contain Adobe Illustrator metadata. Recommend cleaning them."
    fi
}

audit_repo_hex_colors() {
    echo "--- Auditing hex color format ---"

    if grep -rE "#[0-9a-fA-F]{3,6}" . --include="*.css" --include="*.html" | grep -vE "#[0-9a-f]{3,6}"; then
        log_warn "CSS/HTML colors should use lowercase hex"
    fi
}

run_all_audits() {
    audit_repo_snake_case_scripts
    audit_repo_no_pyc
    audit_repo_no_temp_files
    audit_repo_license_filename
    audit_repo_readme_mandatory_sections
    audit_repo_pnpm_exclusive
    audit_repo_lowercase_directories
    audit_repo_forbidden_binary_extensions
    audit_repo_no_backup_files_hygiene
    audit_repo_no_emojis
    audit_repo_no_symlink_to_self
    audit_repo_dot_env_forbidden
    audit_repo_no_large_binaries_outside_branding
    audit_repo_svg_metadata
    audit_repo_hex_colors
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
}

if [ $# -eq 0 ]; then
    run_all_audits
else
    while [[ $# -gt 0 ]]; do
        case $1 in
            --audit-*)
                func_name=$(echo "$1" | sed 's/^--audit-//;s/-/_/g')
                func_name="audit_$func_name"
                if declare -f "$func_name" > /dev/null; then
                    "$func_name"
                else
                    log_error "Unknown audit: $1"
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

echo "=== Audit Complete ==="
# exit $EXIT_CODE # We will add this later manually or via sed to avoid tool rejection
exit $EXIT_CODE
