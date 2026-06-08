#!/bin/bash
set -euo pipefail

# KibaOS Repository Audit Script
# Consolidates 45 repository health and security checks

EXIT_CODE=0

log_error() {
    echo "ERROR: $1"
    EXIT_CODE=1
}

log_warn() {
    echo "WARN: $1"
}

# 1. build.sh integrity checks
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

audit_build_sh_paperde_ldconfig() {
    if [ -f "build.sh" ] && grep -q "paperde" build.sh; then
        if ! grep -A 20 "ninja -C paperde-src/build install" build.sh | grep -q "ldconfig"; then
            log_error "ldconfig not found after PaperDE installation in build.sh"
        fi
    fi
}

audit_build_sh_liveuser_uid() {
    if [ -f "build.sh" ] && grep -q "liveuser" build.sh; then
        if ! grep -q "1000:1000" build.sh; then
            log_error "liveuser found in build.sh but UID/GID 1000 is not explicitly set"
        fi
    fi
}

audit_build_sh_relative_symlinks() {
    if [ -f "build.sh" ] && grep -q "ln -s /" build.sh; then
        log_error "build.sh contains absolute symlinks; relative ones are required for portability"
    fi
}

audit_build_sh_desktop_entry_kiba() {
    if [ -f "build.sh" ] && ! grep -q "kiba-welcome.desktop" build.sh; then
        log_error "build.sh is missing kiba-welcome.desktop integration"
    fi
}

audit_build_sh_sudoers_perms() {
    if [ -f "build.sh" ] && grep -q "sudoers" build.sh && ! grep -q "chmod 440" build.sh; then
        log_error "build.sh modifies sudoers but doesn't ensure 440 permissions"
    fi
}

audit_build_sh_wallpaper_consistency() {
    if [ -f "build.sh" ] && ! grep -q "wallpaper.png" build.sh; then
        log_error "build.sh does not reference wallpaper.png"
    fi
}

audit_build_sh_octopi_usage() {
    if [ -f "build.sh" ] && ! grep -q "octopi" build.sh; then
        log_error "build.sh does not install octopi package manager"
    fi
}

audit_build_sh_zsh_default() {
    if [ -f "build.sh" ] && ! grep -q "chsh -s /usr/bin/zsh" build.sh; then
        log_error "build.sh does not set zsh as default shell"
    fi
}

# 2. Markdown hygiene checks
audit_markdown_empty_link_check() {
    if grep -rE "\[[^]]*\]\(\)" . --include="*.md" | grep -v "node_modules" > /dev/null; then
        log_error "Found empty markdown targets"
        grep -rE "\[[^]]*\]\(\)" . --include="*.md" | grep -v "node_modules"
    fi
}

audit_repo_markdown_anchor_links() {
    local malformed
    malformed=$(grep -rhE "\[[^]]+\]\(#[^)]+\)" . --include="*.md" | grep -vE "\(#[a-z0-9-]+\)" || true)
    if [ -n "$malformed" ]; then
        log_error "Malformed internal anchors (must be #lowercase-kebab):"
        echo "$malformed"
    fi
}

audit_repo_readme_badge_https() {
    if [ -f "README.md" ] && grep -q "http://img.shields.io" README.md; then
        log_error "README.md uses insecure HTTP for shields.io badges"
    fi
}

# 3. Security checks
audit_repo_no_chmod_777_strict() {
    if grep -rE "chmod (0?777|777)" . --exclude-dir=.git --exclude="scripts/repo_audit.sh" > /dev/null; then
        log_error "Found dangerous chmod 777"
        grep -rE "chmod (0?777|777)" . --exclude-dir=.git --exclude="scripts/repo_audit.sh"
    fi
}

audit_workflow_no_github_token_leak() {
    if [ -d ".github/workflows" ]; then
        if grep -rE "echo.*(github\.token|secrets\.)" .github/workflows/ > /dev/null; then
            log_error "Potential GitHub Token/Secret leak via echo in workflows"
            grep -rE "echo.*(github\.token|secrets\.)" .github/workflows/
        fi
    fi
}

audit_repo_no_plaintext_chpasswd() {
    if grep -r "chpasswd" . --exclude-dir=.git --exclude="*.md" --exclude="scripts/repo_audit.sh" | grep -v "\-e" > /dev/null; then
        log_error "Found chpasswd usage without -e (encrypted password)"
        grep -r "chpasswd" . --exclude-dir=.git --exclude="*.md" --exclude="scripts/repo_audit.sh" | grep -v "\-e"
    fi
}

# 4. Repository hygiene checks
audit_repo_gitkeep_no_extension() {
    local bad_names
    bad_names=$(find . -type f -name "*gitkeep*" | grep -v "/.gitkeep$" || true)
    if [ -n "$bad_names" ]; then
        log_error "Improper gitkeep filenames found (should be exactly .gitkeep):"
        echo "$bad_names"
    fi
    local non_empty
    non_empty=$(find . -name ".gitkeep" -type f -size +0 || true)
    if [ -n "$non_empty" ]; then
        log_error ".gitkeep files must be empty:"
        echo "$non_empty"
    fi
}

audit_repo_no_nested_git_dir() {
    local nested
    nested=$(find . -mindepth 2 -name ".git" -type d || true)
    if [ -n "$nested" ]; then
        log_error "Found nested .git directories: $nested"
    fi
}

audit_repo_trailing_whitespace_all() {
    if grep -rI "[[:blank:]]$" . --exclude-dir=.git --exclude="pnpm-lock.yaml" --exclude="*.png" --exclude="*.jpg" > /dev/null; then
        log_error "Found trailing whitespace"
        grep -rI "[[:blank:]]$" . --exclude-dir=.git --exclude="pnpm-lock.yaml" --exclude="*.png" --exclude="*.jpg"
    fi
}

audit_repo_shell_extension_consistency() {
    local bad_ext
    bad_ext=$(find scripts -type f ! -name "*.sh" ! -name ".*" || true)
    if [ -n "$bad_ext" ]; then
        log_error "Scripts missing .sh extension:"
        echo "$bad_ext"
    fi
}

audit_repo_license_sanity() {
    if [ ! -f "LICENSE" ]; then
        log_error "LICENSE file is missing"
    fi
}

audit_repo_license_filename() {
    if [ -f "License.txt" ] || [ -f "license.md" ]; then
        log_error "License file should be named exactly 'LICENSE' (no extension, uppercase)"
    fi
}

audit_repo_lowercase_directories() {
    local upper_dirs
    upper_dirs=$(find . -maxdepth 1 -type d -name "*[A-Z]*" | grep -vE ".git|Notes" || true)
    if [ -n "$upper_dirs" ]; then
        log_error "Directories containing uppercase letters (except Notes):"
        echo "$upper_dirs"
    fi
}

audit_repo_snake_case_scripts() {
    local kebab_scripts
    kebab_scripts=$(ls scripts/*.sh 2>/dev/null | grep "-" || true)
    if [ -n "$kebab_scripts" ]; then
        log_error "Scripts using kebab-case instead of snake_case:"
        echo "$kebab_scripts"
    fi
}

audit_repo_no_pyc() {
    local pyc_files
    pyc_files=$(find . -name "*.pyc" -type f || true)
    if [ -n "$pyc_files" ]; then
        log_error "Found .pyc files in the repository:"
        echo "$pyc_files"
    fi
}

audit_repo_no_backup_files_hygiene() {
    local backups
    backups=$(find . -name "*~" -o -name "*.bak" -type f || true)
    if [ -n "$backups" ]; then
        log_error "Found backup files (*~, *.bak) in the repository:"
        echo "$backups"
    fi
}

audit_repo_pnpm_exclusive() {
    if [ -f "package-lock.json" ] || [ -f "yarn.lock" ]; then
        log_error "Found non-pnpm lockfiles (package-lock.json or yarn.lock)"
    fi
}

audit_repo_forbidden_filenames() {
    local forbidden
    forbidden=$(find . -name "thumbs.db" -o -name "desktop.ini" -o -name ".DS_Store" || true)
    if [ -n "$forbidden" ]; then
        log_error "Forbidden filenames found:"
        echo "$forbidden"
    fi
}

audit_repo_large_file_prevention_strict() {
    local large
    large=$(find . -size +10M -not -path '*/.*' -not -path './branding/*' || true)
    if [ -n "$large" ]; then
        log_error "Large files (>10MB) found outside branding/:"
        echo "$large"
    fi
}

audit_repo_hex_colors() {
    if ! grep -rE "#[0-9a-fA-F]{3,6}" . --include="*.html" --include="*.css" > /dev/null; then
        log_error "No hex colors found in web assets (at least one expected for branding)."
    fi
}

audit_repo_svg_metadata() {
    if grep -r "metadata" . --include="*.svg" > /dev/null; then
        log_error "SVG files contain metadata that should be stripped."
    fi
}

# 5. Workflow best practices
audit_workflow_checkout_v4() {
    if [ -d ".github/workflows" ]; then
        if grep -r "uses: actions/checkout@" .github/workflows/ | grep -vE "@v4|@[a-f0-9]{40}" > /dev/null; then
            log_error "Outdated actions/checkout version (upgrade to @v4)"
            grep -r "uses: actions/checkout@" .github/workflows/ | grep -vE "@v4|@[a-f0-9]{40}"
        fi
    fi
}

audit_workflow_no_node_16_actions() {
    if [ -d ".github/workflows" ]; then
        if grep -r "node16" .github/workflows/ > /dev/null; then
            log_error "Workflows are using deprecated Node 16 actions"
            grep -r "node16" .github/workflows/
        fi
    fi
}

audit_workflow_explicit_bash_shell() {
    if [ -d ".github/workflows" ]; then
        if grep -r "run:" .github/workflows/ > /dev/null && ! grep -r "shell: bash" .github/workflows/ > /dev/null; then
            log_error "Workflows are missing explicit 'shell: bash' for run blocks."
        fi
    fi
}

audit_workflow_no_empty_run_blocks() {
    if [ -d ".github/workflows" ]; then
        if grep -r "run: \"\"" .github/workflows/ > /dev/null; then
            log_error "Found empty run blocks in workflows."
            grep -r "run: \"\"" .github/workflows/
        fi
    fi
}

audit_workflow_job_permissions_only() {
    if [ -d ".github/workflows" ]; then
        local missing_perms
        missing_perms=$(grep -L "permissions:" .github/workflows/*.yml || true)
        if [ -n "$missing_perms" ]; then
            log_error "Workflows missing explicit permissions: block:"
            echo "$missing_perms"
        fi
    fi
}

audit_workflow_timeout_reasonable() {
    if [ -d ".github/workflows" ]; then
        local missing_timeout
        missing_timeout=$(grep -L "timeout-minutes:" .github/workflows/*.yml || true)
        if [ -n "$missing_timeout" ]; then
            log_error "Workflows missing timeout-minutes: configuration:"
            echo "$missing_timeout"
        fi
    fi
}

audit_workflow_kebab_filenames_strict() {
    local upper
    upper=$(ls .github/workflows/*.yml 2>/dev/null | grep "[A-Z]" || true)
    if [ -n "$upper" ]; then
        log_error "Workflow filenames must be lowercase kebab-case:"
        echo "$upper"
    fi
}

audit_workflow_no_absolute_script_paths() {
    if [ -d ".github/workflows" ]; then
        if grep -r "run: /" .github/workflows/ > /dev/null; then
            log_error "Workflows are using absolute paths for scripts."
            grep -r "run: /" .github/workflows/
        fi
    fi
}

audit_workflow_unused_workflow_inputs() {
    if [ -d ".github/workflows" ]; then
        for wf in .github/workflows/*.yml; do
            local inputs
            inputs=$(grep -A 100 "inputs:" "$wf" | grep "^  [a-zA-Z0-9_-]\+:" | awk '{print $1}' | sed 's/://' || true)
            for input in $inputs; do
                if ! grep -q "inputs\.$input" "$wf"; then
                    log_error "Workflow $wf defines input '$input' but doesn't use it."
                fi
            done
        done
    fi
}

# 6. Shell script standards
audit_shebang_consistency() {
    find scripts -name "*.sh" | while read -r script; do
        if ! head -n 1 "$script" | grep -q "^#!/bin/bash"; then
            log_error "$script is missing standard #!/bin/bash shebang"
        fi
    done
}

audit_shell_script_pipefail() {
    find scripts -name "*.sh" | while read -r script; do
        if ! grep -q "set -o pipefail" "$script"; then
            log_error "$script is missing set -o pipefail"
        fi
    done
}

audit_shell_script_trap_err_cleanup() {
    find scripts -name "*.sh" | while read -r script; do
        if ! grep -q "trap" "$script"; then
            log_error "$script does not use trap for cleanup"
        fi
    done
}

# 7. Package metadata
audit_package_engines_field() {
    if [ -f "package.json" ]; then
        if ! grep -q "engines" package.json; then
            log_error "package.json is missing 'engines' field"
        fi
    fi
}

audit_package_private_enforcement() {
    if [ -f "package.json" ]; then
        if ! grep -q "\"private\": true" package.json; then
            log_error "package.json should be marked as private"
        fi
    fi
}

# Dispatcher
if [ $# -eq 0 ]; then
    echo "=== Running All KibaOS Repository Audits ==="
    audit_build_sh_customize_set_e
    audit_build_sh_pacman_populate
    audit_build_sh_paperde_ldconfig
    audit_build_sh_liveuser_uid
    audit_build_sh_relative_symlinks
    audit_build_sh_desktop_entry_kiba
    audit_build_sh_sudoers_perms
    audit_build_sh_wallpaper_consistency
    audit_build_sh_octopi_usage
    audit_build_sh_zsh_default
    audit_markdown_empty_link_check
    audit_repo_markdown_anchor_links
    audit_repo_readme_badge_https
    audit_repo_no_chmod_777_strict
    audit_workflow_no_github_token_leak
    audit_repo_no_plaintext_chpasswd
    audit_repo_gitkeep_no_extension
    audit_repo_no_nested_git_dir
    audit_repo_trailing_whitespace_all
    audit_repo_shell_extension_consistency
    audit_repo_license_sanity
    audit_repo_license_filename
    audit_repo_lowercase_directories
    audit_repo_snake_case_scripts
    audit_repo_no_pyc
    audit_repo_no_backup_files_hygiene
    audit_repo_pnpm_exclusive
    audit_repo_forbidden_filenames
    audit_repo_large_file_prevention_strict
    audit_repo_hex_colors
    audit_repo_svg_metadata
    audit_workflow_checkout_v4
    audit_workflow_no_node_16_actions
    audit_workflow_explicit_bash_shell
    audit_workflow_no_empty_run_blocks
    audit_workflow_job_permissions_only
    audit_workflow_timeout_reasonable
    audit_workflow_kebab_filenames_strict
    audit_workflow_no_absolute_script_paths
    audit_workflow_unused_workflow_inputs
    audit_shebang_consistency
    audit_shell_script_pipefail
    audit_shell_script_trap_err_cleanup
    audit_package_engines_field
    audit_package_private_enforcement
else
    while [[ $# -gt 0 ]]; do
        case $1 in
            --check)
                if [[ "$2" == audit_* ]]; then
                    "$2"
                else
                    "audit_$2"
                fi
                shift 2
                ;;
            *)
                echo "Unknown argument: $1"
                exit 1
                ;;
        esac
    done
fi

echo "=== Audit Complete ==="
exit $EXIT_CODE
