#!/bin/bash
set -euo pipefail

# KibaOS Repository Audit Script
# Consolidates modular repository health and security checks

EXIT_CODE=0

log_error() { echo "ERROR: $1" >&2; EXIT_CODE=1; }
log_warn() { echo "WARN: $1" >&2; }

# --- Helper ---
iterate_workflows() {
    local func=$1
    for f in .github/workflows/*.yml; do
        [ -e "$f" ] || continue
        $func "$f"
    done
}

# --- Build.sh Checks ---

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
        log_warn "build.sh may contain absolute symlinks; relative symlinks are preferred for airootfs"
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
    if [ -f "build.sh" ] && ! grep -q "Icon=kibaos" build.sh; then
        log_error "build.sh defines desktop entries but might be missing Icon=kibaos branding"
    fi
}

audit_build_sh_sudoers_perms() {
    if [ -f "build.sh" ] && grep -q "sudoers" build.sh; then
        if ! grep -E "chmod 0440.*/etc/sudoers" build.sh > /dev/null; then
            log_warn "build.sh modifies sudoers but may not be setting 0440 permissions"
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

audit_build_sh_wallpaper_consistency() {
    if [ -f "build.sh" ]; then
        if grep -q "WALLPAPER_DEST=" build.sh && ! grep -q "gsettings set.*background picture-uri" build.sh; then
            log_warn "build.sh defines wallpaper but may not be setting it via gsettings"
        fi
    fi
}

audit_build_sh_octopi_usage() {
    if [ -f "build.sh" ] && grep -qi "octopi" build.sh; then
        log_warn "Octopi found in build.sh; ensure KibaOS UX standards prefer GNOME Software for consistency"
    fi
}

audit_build_sh_zsh_default() {
    if [ -f "build.sh" ] && grep -q "chsh" build.sh && ! grep -q "/bin/zsh" build.sh; then
        log_warn "build.sh changes shell but doesn't seem to set zsh as default (KibaOS standard)"
    fi
}

# --- Markdown Checks ---

audit_markdown_empty_link_check() {
    if grep -rE "\[[^]]*\]\(\)" . --include="*.md" | grep -v "node_modules" > /dev/null; then
        log_error "Found empty markdown targets"
    fi
}

audit_repo_markdown_anchor_links() {
    local bad_anchors
    bad_anchors=$(grep -rhE "\[[^]]+\]\(#[^)]+\)" . --include="*.md" | grep -vE "\(#[a-z0-9-]+\)" || true)
    if [ -n "$bad_anchors" ]; then
        log_warn "Malformed internal anchors (recommend #lowercase-kebab): $bad_anchors"
    fi
}

# --- Repository Hygiene ---

audit_repo_license_sanity() {
    if [ ! -f "LICENSE" ] && [ ! -f "LICENSE.md" ]; then
        log_error "Repository missing LICENSE file"
    fi
}

audit_repo_readme_badge_https() {
    if [ -f "README.md" ] && grep -q "http://" README.md | grep "img.shields.io" > /dev/null; then
        log_error "README.md uses insecure HTTP for badges"
    fi
}

audit_repo_no_chmod_777_strict() {
    if grep -rE "chmod (0?777|777)" . --exclude-dir=.git --exclude="repo_audit.sh" > /dev/null; then
        log_error "Found dangerous chmod 777"
    fi
}

audit_repo_no_plaintext_chpasswd() {
    if grep -r "chpasswd" . --exclude-dir=.git --exclude="repo_audit.sh" --exclude="*.md" | grep -v "chpasswd -e" > /dev/null; then
        log_error "Found chpasswd usage without -e (potential plaintext password)"
    fi
}

audit_repo_gitkeep_no_extension() {
    local bad_gitkeep
    bad_gitkeep=$(find . -name "*.gitkeep" -not -name ".gitkeep")
    if [ -n "$bad_gitkeep" ]; then
        log_error "Found .gitkeep with extension or prefix: $bad_gitkeep"
    fi
}

audit_repo_shell_extension_consistency() {
    if [ -d "scripts" ]; then
        find scripts -type f ! -name "*.*" -executable -exec grep -q "#!/bin/bash" {} \; -print | while read -r f; do
            log_warn "Script $f missing .sh extension"
        done
    fi
}

audit_repo_trailing_whitespace_all() {
    if grep -rI "[[:blank:]]$" . --exclude-dir=.git --exclude="pnpm-lock.yaml" --exclude="*.png" --exclude="*.jpg" --exclude="*.iso" > /dev/null; then
        log_error "Found trailing whitespace"
    fi
}

audit_repo_no_nested_git_dir() {
    local nested_git
    nested_git=$(find . -mindepth 2 -name ".git" -type d)
    if [ -n "$nested_git" ]; then
        log_error "Found nested .git directories: $nested_git"
    fi
}

audit_repo_no_temp_files() {
    local temp_files
    temp_files=$(find . -name "*.tmp" -o -name "*.swp" -o -name "*~")
    if [ -n "$temp_files" ]; then
        log_error "Found temporary files: $temp_files"
    fi
}

audit_repo_no_pyc() {
    local pyc_files
    pyc_files=$(find . -name "*.pyc" -o -name "__pycache__")
    if [ -n "$pyc_files" ]; then
        log_error "Found python bytecode files: $pyc_files"
    fi
}

audit_repo_no_empty_folders_except_gitkeep() {
    find . -type d -empty | while read -r d; do
        if [[ "$d" != *".git"* ]]; then
            log_warn "Empty directory found (add .gitkeep): $d"
        fi
    done
}

audit_repo_large_file_prevention_strict() {
    local large_files
    large_files=$(find . -type f -size +5M -not -path "./.git/*" -not -path "./branding/*" -not -path "./*.iso")
    if [ -n "$large_files" ]; then
        log_error "Large files (>5MB) found outside branding/: $large_files"
    fi
}

audit_repo_forbidden_filenames_case_insensitive() {
    find . -not -path "./.git/*" | tr '[:upper:]' '[:lower:]' | sort | uniq -d | while read -r d; do
        if [ -n "$d" ]; then
            log_warn "Potential case collision for filename (lowercase version): $d"
        fi
    done
}

audit_repo_license_filename() {
    if [ -f "license" ]; then
        log_error "LICENSE file should be uppercase"
    fi
}

audit_repo_readme_toc_required() {
    if [ -f "README.md" ] && [ "$(wc -l < README.md)" -gt 100 ] && ! grep -qi "Table of Contents" README.md; then
        log_warn "README.md is long but missing Table of Contents"
    fi
}

audit_repo_readme_mandatory_sections() {
    if [ -f "README.md" ]; then
        for section in "Installation" "Usage" "License"; do
            if ! grep -qi "$section" README.md; then
                log_warn "README.md missing mandatory section: $section"
            fi
        done
    fi
}

# --- Workflow Checks ---

audit_workflow_checkout_v4() {
    iterate_workflows _audit_workflow_checkout_v4
}
_audit_workflow_checkout_v4() {
    if grep -q "uses: actions/checkout@" "$1" && ! grep -qE "actions/checkout@v4|actions/checkout@[a-f0-9]{40}" "$1"; then
        log_error "$1: Outdated actions/checkout version (upgrade to @v4)"
    fi
}

audit_workflow_no_node_16_actions() {
    iterate_workflows _audit_workflow_no_node_16_actions
}
_audit_workflow_no_node_16_actions() {
    if grep -q "uses: actions/setup-node@" "$1" && grep -qE "actions/setup-node@v1|actions/setup-node@v2" "$1"; then
        log_warn "$1: Actions may be using Node 16 (setup-node < v3)"
    fi
}

audit_workflow_explicit_bash_shell() {
    iterate_workflows _audit_workflow_explicit_bash_shell
}
_audit_workflow_explicit_bash_shell() {
    if grep -q "run:" "$1" && ! grep -q "shell: bash" "$1"; then
        log_warn "$1: Workflows should explicitly specify shell: bash"
    fi
}

audit_workflow_no_empty_run_blocks() {
    iterate_workflows _audit_workflow_no_empty_run_blocks
}
_audit_workflow_no_empty_run_blocks() {
    if grep -q "run: ''" "$1"; then
        log_error "$1: Found empty run blocks"
    fi
}

audit_workflow_job_permissions_only() {
    iterate_workflows _audit_workflow_job_permissions_only
}
_audit_workflow_job_permissions_only() {
    if grep -q "permissions: write-all" "$1"; then
        log_error "$1: Avoid permissions: write-all; use granular permissions"
    fi
}

audit_workflow_timeout_reasonable() {
    iterate_workflows _audit_workflow_timeout_reasonable
}
_audit_workflow_timeout_reasonable() {
    if grep -E "timeout-minutes: [0-9]{3,}" "$1" > /dev/null; then
        log_warn "$1: Workflow timeout seems excessively high"
    fi
}

audit_workflow_kebab_filenames_strict() {
    for f in .github/workflows/*.yml; do
        [ -e "$f" ] || continue
        base=$(basename "$f")
        if [[ "$base" =~ [A-Z_] ]]; then
            log_error "Workflow filename $f should be lowercase-kebab-case.yml"
        fi
    done
}

audit_workflow_no_absolute_script_paths() {
    iterate_workflows _audit_workflow_no_absolute_script_paths
}
_audit_workflow_no_absolute_script_paths() {
    if grep -q "run: /" "$1"; then
         log_warn "$1: Absolute paths found in run blocks"
    fi
}

audit_workflow_unused_workflow_inputs() {
    iterate_workflows _audit_workflow_unused_workflow_inputs
}
_audit_workflow_unused_workflow_inputs() {
    local inputs
    inputs=$(grep -A 20 "inputs:" "$1" | grep -E "^  [a-zA-Z0-9_-]+:" | awk -F: '{print $1}' | tr -d ' ' || true)
    for input in $inputs; do
        if ! grep -q "inputs.$input" "$1"; then
            log_warn "$1: Input '$input' might be unused"
        fi
    done
}

audit_workflow_no_github_token_leak() {
    iterate_workflows _audit_workflow_no_github_token_leak
}
_audit_workflow_no_github_token_leak() {
    if grep -rE "echo.*(github\.token|secrets\.)" "$1" > /dev/null; then
        log_error "$1: Potential GitHub Token/Secret leak via echo"
    fi
}

audit_workflow_concurrency() {
    iterate_workflows _audit_workflow_concurrency
}
_audit_workflow_concurrency() {
    if ! grep -q "concurrency:" "$1"; then
        log_warn "$1: Missing concurrency group"
    fi
}

audit_workflow_on_pull_request_types() {
    iterate_workflows _audit_workflow_on_pull_request_types
}
_audit_workflow_on_pull_request_types() {
    if grep -q "pull_request:" "$1" && ! grep -q "types:" "$1"; then
        log_warn "$1: pull_request trigger without explicit types"
    fi
}

audit_workflow_permissions() {
    iterate_workflows _audit_workflow_permissions
}
_audit_workflow_permissions() {
    if ! grep -q "permissions:" "$1"; then
        log_warn "$1: Missing explicit permissions"
    fi
}

audit_workflow_shell_specification() {
    iterate_workflows _audit_workflow_shell_specification
}
_audit_workflow_shell_specification() {
    # Check if every 'run:' has a 'shell:'
    local runs shells
    runs=$(grep -c "run:" "$1")
    shells=$(grep -c "shell:" "$1")
    if [ "$runs" -gt "$shells" ]; then
        log_warn "$1: Some steps missing shell specification"
    fi
}

audit_workflow_concurrency_cancel() {
    iterate_workflows _audit_workflow_concurrency_cancel
}
_audit_workflow_concurrency_cancel() {
    if grep -q "concurrency:" "$1" && ! grep -q "cancel-in-progress: true" "$1"; then
        log_warn "$1: Concurrency group missing cancel-in-progress: true"
    fi
}

audit_workflow_step_naming() {
    iterate_workflows _audit_workflow_step_naming
}
_audit_workflow_step_naming() {
    local runs names
    runs=$(grep -c "run:" "$1")
    names=$(grep -c "name:" "$1")
    # subtract 1 from names because of job name or workflow name
    if [ "$runs" -ge "$names" ]; then
        log_warn "$1: Some steps missing names"
    fi
}

audit_workflow_timeout_all_jobs() {
    iterate_workflows _audit_workflow_timeout_all_jobs
}
_audit_workflow_timeout_all_jobs() {
    if ! grep -q "timeout-minutes:" "$1"; then
        log_warn "$1: Missing timeout-minutes for jobs or workflow"
    fi
}

# --- Dispatcher ---

if [ $# -eq 0 ]; then
    echo "Usage: $0 --audit-<check-name>"
    echo "Running all audits..."
    # Run all functions starting with audit_
    for func in $(declare -F | awk '{print $3}' | grep "^audit_"); do
        echo "Running $func..."
        $func
    done
else
    for arg in "$@"; do
        if [[ $arg == --audit-* ]]; then
            FUNC_NAME=$(echo "$arg" | sed 's/--audit-/audit_/' | sed 's/-/_/g')
            if declare -F "$FUNC_NAME" > /dev/null; then
                $FUNC_NAME
            else
                log_error "Unknown audit check: $arg ($FUNC_NAME)"
            fi
        fi
    done
fi

exit $EXIT_CODE
