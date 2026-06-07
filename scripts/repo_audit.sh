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

# Helper for iterating workflows to avoid false positives from grep on the whole repo
iterate_workflows() {
    local pattern=$1
    local msg=$2
    for wf in .github/workflows/*.yml; do
        if grep -qE "$pattern" "$wf"; then
            log_error "$msg in $wf"
        fi
    done
}

# --- Audit Functions ---

# 1
audit_build_sh_customize_set_e() {
    if [ -f "build.sh" ]; then
        if ! grep -A 3 "customize_airootfs.sh" build.sh | grep -q "set -e"; then
            log_error "customize_airootfs.sh in build.sh is missing set -e"
        fi
    fi
}

# 2
audit_build_sh_pacman_populate() {
    if [ -f "build.sh" ]; then
        if ! grep -q "pacman-key --populate archlinux" build.sh; then
            log_error "build.sh is missing pacman-key --populate archlinux"
        fi
    fi
}

# 3
audit_build_sh_relative_symlinks() {
    if [ -f "build.sh" ]; then
        output=$(grep "ln -sf /" build.sh | grep -vE "usr/lib|usr/bin|etc/systemd|var/lib/sddm|root/customize_airootfs.sh|pixmaps/kibaos.png" || true)
        if [ -n "$output" ]; then
            log_warn "Potential absolute symlink in build.sh (prefer relative for airootfs):"
            echo "$output"
        fi
    fi
}

# 4
audit_build_sh_paperde_ldconfig() {
    if [ -f "build.sh" ]; then
        if grep -q "paperde" build.sh && ! grep -A 20 "paperde" build.sh | grep -q "ldconfig"; then
             log_warn "ldconfig might be missing after paperde build in build.sh"
        fi
    fi
}

# 5
audit_build_sh_desktop_entry_kiba() {
    if [ -f "build.sh" ]; then
        if ! grep -q "kibaos.desktop" build.sh && ! grep -q "kibaos-install.desktop" build.sh; then
            log_error "build.sh missing kibaos desktop entry references"
        fi
    fi
}

# 6
audit_build_sh_sudoers_perms() {
    if [ -f "build.sh" ]; then
        if grep -q "sudoers" build.sh && ! grep -q "0440" build.sh; then
            log_error "build.sh found sudoers modification without explicit 0440 permissions"
        fi
    fi
}

# 7
audit_build_sh_liveuser_uid() {
    if [ -f "build.sh" ]; then
        if grep -q "liveuser" build.sh; then
            if ! grep -q "1000:1000" build.sh; then
                log_error "liveuser found in build.sh but UID/GID 1000 is not explicitly set"
            fi
        fi
    fi
}

# 8
audit_build_sh_wallpaper_consistency() {
    if [ -f "build.sh" ]; then
        if grep -q "wallpaper.png" build.sh && ! grep -q "branding/forest-k.png" build.sh; then
            log_warn "build.sh wallpaper reference might be inconsistent with branding/forest-k.png"
        fi
    fi
}

# 9
audit_build_sh_octopi_usage() {
    if [ -f "build.sh" ]; then
        if grep -q "octopi" build.sh; then
            log_warn "octopi detected in build.sh; ensure it is intended over gnome-software"
        fi
    fi
}

# 10
audit_build_sh_zsh_default() {
    if [ -f "build.sh" ]; then
        if grep -q "SHELL=" build.sh && ! grep -q "bash" build.sh; then
            log_warn "Non-bash shell detected in build.sh; verify compatibility"
        fi
    fi
}

# 11
audit_markdown_empty_link_check() {
    output=$(grep -rE "\[[^]]*\]\(\)" . --include="*.md" | grep -v "node_modules" || true)
    if [ -n "$output" ]; then
        log_error "Found empty markdown targets:"
        echo "$output"
    fi
}

# 12
audit_repo_license_sanity() {
    if [ ! -f "LICENSE" ]; then
        log_error "LICENSE file is missing"
    fi
}

# 13
audit_repo_readme_badge_https() {
    if [ -f "README.md" ]; then
        output=$(grep "http://" README.md | grep -E "img.shields.io|github.com/.*/actions/workflows" || true)
        if [ -n "$output" ]; then
            log_error "Non-HTTPS badge link found in README.md"
            echo "$output"
        fi
    fi
}

# 14
audit_repo_no_chmod_777_strict() {
    output=$(grep -rE "chmod (0?777|777)" . --exclude-dir=.git --exclude="repo_audit.sh" --exclude="*.md" || true)
    if [ -n "$output" ]; then
        log_error "Found dangerous chmod 777"
        echo "$output"
    fi
}

# 15
audit_repo_no_plaintext_chpasswd() {
    output=$(grep -r "chpasswd" . --include="*.sh" --exclude="repo_audit.sh" | grep -v "\-e" || true)
    if [ -n "$output" ]; then
        log_error "chpasswd used without -e (prefer encrypted hashes):"
        echo "$output"
    fi
}

# 16
audit_repo_markdown_anchor_links() {
    BAD_ANCHORS=$(grep -rhE "\[[^]]+\]\(#[^)]+\)" . --include="*.md" | grep -vE "\(#[a-z0-9-]+\)" || true)
    if [ -n "$BAD_ANCHORS" ]; then
        log_warn "Malformed internal anchors (recommend #lowercase-kebab):"
        echo "$BAD_ANCHORS"
    fi
}

# 17
audit_repo_gitkeep_no_extension() {
    NON_EMPTY_GITKEEP=$(find . -name ".gitkeep" -type f -size +0)
    if [ -n "$NON_EMPTY_GITKEEP" ]; then
        log_error ".gitkeep files must be empty: $NON_EMPTY_GITKEEP"
    fi
}

# 18
audit_repo_shell_extension_consistency() {
    output=$(find scripts/ -type f ! -name "*.sh" ! -name "*.py" ! -name "*.txt" || true)
    if [ -n "$output" ]; then
        log_error "Scripts without proper extension found in scripts/:"
        echo "$output"
    fi
}

# 19
audit_repo_trailing_whitespace_all() {
    output=$(grep -rI "[[:blank:]]$" . --exclude-dir=.git --exclude="pnpm-lock.yaml" --exclude="*.png" --exclude="*.jpg" --exclude="*.webm" --exclude-dir="node_modules" || true)
    if [ -n "$output" ]; then
        log_error "Found trailing whitespace:"
        echo "$output"
    fi
}

# 20
audit_repo_no_nested_git_dir() {
    NESTED_GIT=$(find . -mindepth 2 -name ".git" -type d)
    if [ -n "$NESTED_GIT" ]; then
        log_error "Found nested .git directories: $NESTED_GIT"
    fi
}

# 21
audit_workflow_checkout_v4() {
    # Check for actions/checkout@v1, @v2, @v3 or unpinned @master
    output=$(grep -r "uses: actions/checkout@" .github/workflows/ | grep -vE "@v4|@[a-f0-9]{40}" || true)
    if [ -n "$output" ]; then
        log_error "Outdated actions/checkout version (upgrade to @v4):"
        echo "$output"
    fi
}

# 22
audit_workflow_no_node_16_actions() {
    iterate_workflows "node16" "Workflow uses deprecated node16 action runner"
}

# 23
audit_workflow_explicit_bash_shell() {
    # Ensure that if a shell is specified, it is bash
    for wf in .github/workflows/*.yml; do
        output=$(grep "shell:" "$wf" | grep -v "bash" || true)
        if [ -n "$output" ]; then
            log_error "Explicit non-bash shell found in $wf"
            echo "$output"
        fi
    done
}

# 24
audit_workflow_no_empty_run_blocks() {
    # Check for 'run: ""' or 'run: >' followed by nothing
    for wf in .github/workflows/*.yml; do
        if grep -qE "run:[[:space:]]*['\"]+['\"]" "$wf"; then
             log_error "Empty run block found in $wf"
        fi
    done
}

# 25
audit_workflow_job_permissions_only() {
    output=$(grep -r "permissions: write-all" .github/workflows/ || true)
    if [ -n "$output" ]; then
        log_error "Workflows should use granular permissions, not write-all:"
        echo "$output"
    fi
}

# 26
audit_workflow_timeout_reasonable() {
    for wf in .github/workflows/*.yml; do
        if ! grep -q "timeout-minutes:" "$wf"; then
            log_warn "Workflow missing timeout-minutes (default is 360m): $wf"
        fi
    done
}

# 27
audit_workflow_kebab_filenames_strict() {
    for f in .github/workflows/*.yml; do
        base=$(basename "$f")
        if [[ ! "$base" =~ ^[a-z0-9-]+.yml$ ]]; then
            log_error "Workflow filename not kebab-case: $base"
        fi
    done
}

# 28
audit_workflow_no_absolute_script_paths() {
    # Match run: /... but allow run: | \n /... and common absolute paths like /usr/bin /bin
    # Actually, repo scripts should be called via path from root, e.g. scripts/repo_audit.sh
    # This check looks for runs starting with / (absolute)
    for wf in .github/workflows/*.yml; do
        output=$(grep -E "run:[[:space:]]*/" "$wf" || true)
        if [ -n "$output" ]; then
             log_error "Absolute path used in workflow run block in $wf"
             echo "$output"
        fi
    done
}

# 29
audit_workflow_unused_workflow_inputs() {
    for wf in .github/workflows/*.yml; do
        inputs=$(grep -oE "inputs\.[a-zA-Z0-9_-]+" "$wf" | sed 's/inputs.//' | sort -u || true)
        for input in $inputs; do
            # Check if input is used in the same file excluding the definition
            count=$(grep -c "inputs.$input" "$wf" || true)
            if [ "$count" -le 1 ]; then
                 log_warn "Workflow input '$input' might be unused in $wf"
            fi
        done
    done
}

# 30
audit_workflow_no_github_token_leak() {
    output=$(grep -rE "echo.*(github\.token|secrets\.)" .github/workflows/ || true)
    if [ -n "$output" ]; then
        log_error "Potential GitHub Token/Secret leak via echo in workflows:"
        echo "$output"
    fi
}

# 31
audit_repo_no_temp_files() {
    TEMP_FILES=$(find . -name "*.swp" -o -name "*.bak" -o -name "*~")
    if [ -n "$TEMP_FILES" ]; then
        log_error "Temporary files found: $TEMP_FILES"
    fi
}

# 32
audit_repo_lowercase_directories() {
    output=$(find . -maxdepth 2 -type d -not -path '*/.*' | grep -E '[A-Z]' | grep -vE "Notes|Jules" || true)
    if [ -n "$output" ]; then
        log_warn "Directories with uppercase letters found (prefer lowercase):"
        echo "$output"
    fi
}

# 33
audit_repo_snake_case_scripts() {
    for f in scripts/*; do
        base=$(basename "$f")
        if [[ "$base" =~ [A-Z] ]]; then
            log_error "Script filename contains uppercase letters: $base"
        fi
    done
}

# 34
audit_workflow_extension_strict() {
    output=$(ls .github/workflows/*.yaml 2>/dev/null || true)
    if [ -n "$output" ]; then
        log_error "Workflows should use .yml extension, not .yaml:"
        echo "$output"
    fi
}

# 35
audit_build_sh_no_skippgpcheck() {
    if [ -f "build.sh" ]; then
        if grep -q "makepkg.*--skippgpcheck" build.sh; then
            log_error "build.sh uses --skippgpcheck with makepkg"
        fi
    fi
}

# 36
audit_repo_todo_format() {
    # Check if TODOs follow a standard format like TODO: (name) description
    output=$(grep -r "TODO" . --exclude-dir=.git --exclude-dir=node_modules | grep -vE "TODO: \([a-zA-Z]+\)" || true)
    if [ -n "$output" ]; then
        log_warn "TODOs found without standard format 'TODO: (name)':"
        echo "$output"
    fi
}

# 37
audit_repo_contributing_existence() {
    if [ ! -f "CONTRIBUTING.md" ]; then
        log_error "CONTRIBUTING.md file is missing"
    fi
}

# 38
audit_repo_security_existence() {
    if [ ! -f "SECURITY.md" ]; then
        log_error "SECURITY.md file is missing"
    fi
}

# 39
audit_build_sh_parallel_downloads() {
    if [ -f "build.sh" ]; then
        if ! grep -q "ParallelDownloads" build.sh; then
            log_warn "ParallelDownloads not configured in build.sh"
        fi
    fi
}

# 40
audit_repo_no_large_binaries() {
    LARGE_FILES=$(find . -type f -size +10M -not -path "./branding/*" -not -path "./.git/*" -not -path "./node_modules/*")
    if [ -n "$LARGE_FILES" ]; then
        log_error "Large files (>10MB) found outside branding/: $LARGE_FILES"
    fi
}

# 41
audit_workflow_job_id_kebab_case() {
    # Identify job IDs (usually first-level keys under 'jobs:')
    for wf in .github/workflows/*.yml; do
        output=$(sed -n '/^jobs:/,$p' "$wf" | grep -E "^  [a-zA-Z0-9_]+:" | grep "_" || true)
        if [ -n "$output" ]; then
             log_error "Job ID with underscores found in $wf (use kebab-case):"
             echo "$output"
        fi
    done
}

# 42
audit_workflow_concurrency_val() {
    for wf in .github/workflows/*.yml; do
        if ! grep -q "concurrency:" "$wf"; then
            log_warn "Workflow missing concurrency group: $wf"
        fi
    done
}

# 43
audit_repo_no_broken_symlinks() {
    BROKEN_SYMLINKS=$(find . -xtype l)
    if [ -n "$BROKEN_SYMLINKS" ]; then
        log_error "Broken symlinks found: $BROKEN_SYMLINKS"
    fi
}

# 44
audit_build_sh_shebang_strict() {
    if [ -f "build.sh" ]; then
        if ! head -n 1 build.sh | grep -q "^#!/bin/bash"; then
            log_error "build.sh missing #!/bin/bash shebang"
        fi
    fi
}

# 45
audit_repo_no_empty_folders() {
    EMPTY_FOLDERS=$(find . -type d -empty -not -path "./.git/*" -not -path "./node_modules/*")
    if [ -n "$EMPTY_FOLDERS" ]; then
        log_error "Empty folders found (add .gitkeep): $EMPTY_FOLDERS"
    fi
}

# --- Execution Logic ---

run_all=true
specific_check=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --check)
            specific_check="$2"
            run_all=false
            shift 2
            ;;
        *)
            echo "Unknown argument: $1"
            exit 1
            ;;
    esac
done

if [ "$run_all" = true ]; then
    echo "=== Running all 45 KibaOS Repository Audits ==="
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
    audit_repo_no_temp_files
    audit_repo_lowercase_directories
    audit_repo_snake_case_scripts
    audit_workflow_extension_strict
    audit_build_sh_no_skippgpcheck
    audit_repo_todo_format
    audit_repo_contributing_existence
    audit_repo_security_existence
    audit_build_sh_parallel_downloads
    audit_repo_no_large_binaries
    audit_workflow_job_id_kebab_case
    audit_workflow_concurrency_val
    audit_repo_no_broken_symlinks
    audit_build_sh_shebang_strict
    audit_repo_no_empty_folders
    echo "=== Audit Complete ==="
else
    # Normalize check name if it contains dashes
    specific_check=$(echo "$specific_check" | tr '-' '_')
    if [[ ! "$specific_check" =~ ^audit_ ]]; then
        specific_check="audit_$specific_check"
    fi

    if declare -f "$specific_check" > /dev/null; then
        echo "=== Running check: $specific_check ==="
        "$specific_check"
    else
        echo "ERROR: Check function '$specific_check' not found."
        EXIT_CODE=1
    fi
fi

exit $EXIT_CODE
