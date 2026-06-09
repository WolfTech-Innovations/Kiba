#!/bin/bash
set -euo pipefail

# KibaOS Repository Audit Script
# Modularized for individual workflow execution

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
    echo "--- Auditing build.sh for customize_airootfs set -e ---"
    if [ -f "build.sh" ]; then
        if ! grep -A 2 "cat > \"\${AIROOTFS}/root/customize_airootfs.sh\"" build.sh | grep -q "set -e"; then
            log_error "customize_airootfs.sh in build.sh is missing set -e"
        fi
    fi
}

audit_build_sh_pacman_populate() {
    echo "--- Auditing build.sh for pacman-key --populate ---"
    if [ -f "build.sh" ]; then
        if ! grep -q "pacman-key --populate archlinux" build.sh; then
            log_error "build.sh is missing pacman-key --populate archlinux"
        fi
    fi
}

audit_build_sh_relative_symlinks() {
    echo "--- Auditing build.sh for relative symlinks ---"
    if [ -f "build.sh" ]; then
        if grep "ln -s" build.sh | grep -q "/home/"; then
            log_error "build.sh contains absolute symlinks to /home/"
        fi
    fi
}

audit_build_sh_paperde_ldconfig() {
    echo "--- Auditing build.sh for PaperDE ldconfig ---"
    if [ -f "build.sh" ]; then
        if ! grep -A 20 "ninja -C paperde-src/build install" build.sh | grep -q "ldconfig"; then
            log_error "ldconfig not found after PaperDE installation in build.sh"
        fi
    fi
}

audit_build_sh_desktop_entry_kiba() {
    echo "--- Auditing build.sh for kiba desktop entry ---"
    if [ -f "build.sh" ]; then
        if ! grep -q "kiba.desktop" build.sh; then
            log_error "build.sh missing kiba.desktop configuration"
        fi
    fi
}

audit_build_sh_sudoers_perms() {
    echo "--- Auditing build.sh for sudoers permissions ---"
    if [ -f "build.sh" ]; then
        if ! grep -q "chmod 440.*sudoers" build.sh; then
            log_error "build.sh does not set correct permissions (440) for sudoers"
        fi
    fi
}

audit_build_sh_liveuser_uid() {
    echo "--- Auditing build.sh for liveuser UID ---"
    if [ -f "build.sh" ]; then
        if grep -q "liveuser" build.sh && ! grep -q "1000:1000" build.sh; then
            log_error "liveuser found in build.sh but UID/GID 1000 is not explicitly set"
        fi
    fi
}

audit_build_sh_wallpaper_consistency() {
    echo "--- Auditing build.sh for wallpaper consistency ---"
    if [ -f "build.sh" ]; then
        WALLPAPER_PATHS=$(grep -o "/usr/share/backgrounds/[^\"' ]*" build.sh | sort | uniq | wc -l)
        if [ "$WALLPAPER_PATHS" -gt 1 ]; then
             log_warn "Multiple wallpaper paths found in build.sh: $(grep -o "/usr/share/backgrounds/[^\"' ]*" build.sh | sort | uniq | xargs)"
        fi
    fi
}

audit_build_sh_octopi_usage() {
    echo "--- Auditing build.sh for octopi usage ---"
    if [ -f "build.sh" ]; then
        if grep -q "octopi" build.sh && ! grep -q "octopi-notifier" build.sh; then
            log_warn "Octopi found but octopi-notifier might be missing in build.sh"
        fi
    fi
}

audit_build_sh_zsh_default() {
    echo "--- Auditing build.sh for zsh as default ---"
    if [ -f "build.sh" ]; then
        if ! grep -q "chsh -s /usr/bin/zsh" build.sh; then
            log_error "build.sh does not set zsh as default shell"
        fi
    fi
}

audit_markdown_empty_link_check() {
    echo "--- Auditing Markdown files for empty links ---"
    if grep -rE "\[[^]]*\]\(\)" . --include="*.md" | grep -v "node_modules"; then
        log_error "Found empty markdown targets"
    fi
}

audit_repo_license_sanity() {
    echo "--- Auditing LICENSE sanity ---"
    if [ ! -f "LICENSE" ]; then
        log_error "LICENSE file is missing"
    elif ! grep -qi "Copyright" LICENSE; then
        log_error "LICENSE file missing Copyright notice"
    fi
}

audit_repo_readme_badge_https() {
    echo "--- Auditing README badges for HTTPS ---"
    if [ -f "README.md" ]; then
        if grep "http://" README.md | grep -E "img.shields.io|github.com/.*/actions/workflows"; then
            log_error "README contains non-HTTPS badges"
        fi
    fi
}

audit_repo_no_chmod_777_strict() {
    echo "--- Auditing for chmod 777 ---"
    if grep -rE "chmod (0?777|777)" . --exclude-dir=.git --exclude="repo_audit.sh"; then
        log_error "Found dangerous chmod 777"
    fi
}

audit_repo_no_plaintext_chpasswd() {
    echo "--- Auditing for plaintext chpasswd ---"
    if grep -r "chpasswd" . --exclude-dir=.git --exclude="repo_audit.sh" --exclude="*.md" | grep -v "\-e"; then
        log_error "Found potential plaintext chpasswd usage (use -e with hashed passwords)"
    fi
}

audit_repo_markdown_anchor_links() {
    echo "--- Auditing Markdown internal anchors ---"
    BAD_ANCHORS=$(grep -rhE "\[[^]]+\]\(#[^)]+\)" . --include="*.md" | grep -vE "\(#[a-z0-9-]+\)" || true)
    if [ -n "$BAD_ANCHORS" ]; then
        log_warn "Malformed internal anchors (recommend #lowercase-kebab):"
        echo "$BAD_ANCHORS"
    fi
}

audit_repo_gitkeep_no_extension() {
    echo "--- Auditing .gitkeep files ---"
    INVALID_GITKEEP=$(find . -name ".gitkeep.*" -o -name "*.gitkeep")
    if [ -n "$INVALID_GITKEEP" ]; then
        log_error "Found .gitkeep files with extensions or bad naming: $INVALID_GITKEEP"
    fi
}

audit_repo_shell_extension_consistency() {
    echo "--- Auditing shell script extensions ---"
    # Find files with shebang but no .sh extension
    BAD_EXT=$(find . -maxdepth 2 -type f -not -path '*/.*' -not -name "*.sh" -not -name "LICENSE" -not -name "package.json" -not -name "pnpm-lock.yaml" -not -name "ACKNOWLEDGMENTS.md" -not -name "CONTRIBUTING.md" -not -name "README.md" -not -name "SECURITY.md" -not -name "WIKI.md" -not -name "WORKFLOWS.md" -not -name "workflows_to_add.txt" -exec grep -l '^#!/bin/.*sh' {} + || true)
    if [ -n "$BAD_EXT" ]; then
        log_warn "Scripts without .sh extension: $BAD_EXT"
    fi
}

audit_repo_trailing_whitespace_all() {
    echo "--- Auditing trailing whitespace ---"
    if grep -rI "[[:blank:]]$" . --exclude-dir=.git --exclude="pnpm-lock.yaml" --exclude="*.png" --exclude="*.jpg" --exclude="*.webp"; then
        log_error "Found trailing whitespace"
    fi
}

audit_repo_no_nested_git_dir() {
    echo "--- Auditing for nested .git directories ---"
    NESTED_GIT=$(find . -mindepth 2 -name ".git" -type d)
    if [ -n "$NESTED_GIT" ]; then
        log_error "Found nested .git directories"
    fi
}

audit_workflow_checkout_v4() {
    echo "--- Auditing actions/checkout version ---"
    if [ -d ".github/workflows" ]; then
        if grep -r "uses: actions/checkout@" .github/workflows/ | grep -vE "@v4|@[a-f0-9]{40}"; then
            log_error "Outdated actions/checkout version (upgrade to @v4)"
        fi
    fi
}

audit_workflow_no_node_16_actions() {
    echo "--- Auditing for Node 16 actions ---"
    if [ -d ".github/workflows" ]; then
        if grep -rE "uses: actions/(setup-node|github-script|cache)@v(1|2|3)" .github/workflows/; then
             log_warn "Found actions using Node 16 (consider upgrading to v4+)"
        fi
    fi
}

audit_workflow_explicit_bash_shell() {
    echo "--- Auditing for explicit bash shell in workflows ---"
    if [ -d ".github/workflows" ]; then
        # Check for 'run:' blocks that don't have a 'shell: bash' in the same job or step
        # This is hard with grep, but we can look for 'run:' and the absence of 'shell: bash' nearby
        if grep -r -A 5 "run:" .github/workflows/ | grep -v "shell: bash" | grep -v "actions/checkout" | grep -v "\--" | grep -q "run:"; then
             log_warn "Some run blocks might be missing explicit shell: bash"
        fi
    fi
}

audit_workflow_no_empty_run_blocks() {
    echo "--- Auditing for empty run blocks in workflows ---"
    if [ -d ".github/workflows" ]; then
        if grep -rE "run:\s*$" .github/workflows/; then
            log_error "Found empty run blocks in workflows"
        fi
    fi
}

audit_workflow_job_permissions_only() {
    echo "--- Auditing workflow permissions ---"
    if [ -d ".github/workflows" ]; then
        if grep -r "^permissions:" .github/workflows/ > /dev/null; then
            log_warn "Top-level permissions found. Job-level permissions are preferred for least privilege."
        fi
    fi
}

audit_workflow_timeout_reasonable() {
    echo "--- Auditing workflow timeouts ---"
    if [ -d ".github/workflows" ]; then
        MISSING_TIMEOUT=$(grep -L "timeout-minutes:" .github/workflows/*.yml || true)
        if [ -n "$MISSING_TIMEOUT" ]; then
            log_warn "Workflows missing timeout-minutes: $MISSING_TIMEOUT"
        fi
    fi
}

audit_workflow_kebab_filenames_strict() {
    echo "--- Auditing workflow filenames ---"
    if [ -d ".github/workflows" ]; then
        BAD_NAMES=$(find .github/workflows -name "*_*" -o -name "*[A-Z]*")
        if [ -n "$BAD_NAMES" ]; then
            log_error "Workflow filenames must be kebab-case (lowercase and dashes): $BAD_NAMES"
        fi
    fi
}

audit_workflow_no_absolute_script_paths() {
    echo "--- Auditing workflow script paths ---"
    if [ -d ".github/workflows" ]; then
        if grep -r "run: /" .github/workflows/ | grep "\.sh"; then
            log_error "Workflows should use relative paths to repository scripts"
        fi
    fi
}

audit_workflow_unused_workflow_inputs() {
    echo "--- Auditing for unused workflow inputs ---"
    echo "Audit for unused workflow inputs - Not fully implemented via grep"
}

audit_workflow_no_github_token_leak() {
    echo "--- Auditing for GitHub Token leaks ---"
    if [ -d ".github/workflows" ]; then
        if grep -rE "echo.*(github\.token|secrets\.)" .github/workflows/; then
            log_error "Potential GitHub Token/Secret leak via echo in workflows"
        fi
    fi
}

# --- Execution Logic ---

if [[ "${1:-}" == "--check" ]]; then
    if [[ -n "${2:-}" ]]; then
        audit_func="audit_$2"
        if [[ "$2" == audit_* ]]; then
            audit_func="$2"
        fi

        if declare -f "$audit_func" > /dev/null; then
            "$audit_func"
        else
            echo "Error: Audit function '$audit_func' not found."
            exit 1
        fi
    else
        echo "Error: --check requires an audit name."
        exit 1
    fi
else
    # Run all audits
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
fi

echo "=== Audit Complete (Exit Code: $EXIT_CODE) ==="
exit $EXIT_CODE
