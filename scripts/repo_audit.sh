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

# --- 1-12: build.sh Checks ---

audit_build_sh_customize_set_e() {
    echo "--- Auditing build.sh: customize_airootfs.sh set -e ---"
    if [ -f "build.sh" ]; then
        if ! grep -A 5 "cat > \"\${AIROOTFS}/root/customize_airootfs.sh\"" build.sh | grep -q "set -e"; then
            log_error "customize_airootfs.sh in build.sh is missing set -e"
        fi
    fi
}

audit_build_sh_pacman_populate() {
    echo "--- Auditing build.sh: pacman-key --populate ---"
    if [ -f "build.sh" ] && ! grep -q "pacman-key --populate archlinux" build.sh; then
        log_error "build.sh is missing pacman-key --populate archlinux"
    fi
}

audit_build_sh_paperde_ldconfig() {
    echo "--- Auditing build.sh: PaperDE ldconfig ---"
    if [ -f "build.sh" ] && grep -q "paperde" build.sh; then
        if ! grep -A 20 "ninja -C paperde" build.sh | grep -q "ldconfig" && ! grep -q "ldconfig" build.sh; then
             log_warn "ldconfig might be missing after PaperDE build"
        fi
    fi
}

audit_build_sh_liveuser_uid() {
    echo "--- Auditing build.sh: liveuser UID ---"
    if [ -f "build.sh" ] && grep -q "liveuser" build.sh && ! grep -q "1000:1000" build.sh; then
        log_error "liveuser UID/GID 1000 not explicitly set in build.sh"
    fi
}

audit_build_sh_octopi_usage() {
    echo "--- Auditing build.sh: Octopi usage ---"
    if [ -f "build.sh" ] && grep -q "octopi" build.sh; then
        log_error "Forbidden 'octopi' usage found in build.sh"
    fi
}

audit_build_sh_zsh_default() {
    echo "--- Auditing build.sh: Zsh default shell ---"
    if [ -f "build.sh" ] && grep -q "zsh" build.sh && ! grep -q "chsh -s /usr/bin/zsh" build.sh; then
        log_warn "Zsh mentioned but not set as default shell via chsh"
    fi
}

audit_build_sh_relative_symlinks() {
    echo "--- Auditing build.sh: Relative symlinks ---"
    if [ -f "build.sh" ] && grep "ln -s /" build.sh | grep -v "/usr/lib" | grep -v "/usr/bin" | grep -v "/run/user"; then
        log_warn "Potential absolute symlink found in build.sh"
    fi
}

audit_build_sh_desktop_entry_kiba() {
    echo "--- Auditing build.sh: Kiba Desktop Entry ---"
    if [ -f "build.sh" ] && grep -q "kibaos.desktop" build.sh && ! grep -q "Categories=System;" build.sh; then
        log_error "Kiba Desktop Entry missing System category in build.sh"
    fi
}

audit_build_sh_sudoers_perms() {
    echo "--- Auditing build.sh: Sudoers permissions ---"
    if [ -f "build.sh" ] && grep -q "sudoers.d" build.sh && ! grep -q "0440" build.sh; then
        log_error "Sudoers snippet in build.sh missing 0440 permissions"
    fi
}

audit_build_sh_wallpaper_consistency() {
    echo "--- Auditing build.sh: Wallpaper path ---"
    if [ -f "build.sh" ] && grep -q "wallpaper" build.sh && ! grep -q "/usr/share/kibaos/wallpaper.png" build.sh; then
        log_warn "Wallpaper path in build.sh might be inconsistent"
    fi
}

audit_build_sh_pacman_su() {
    echo "--- Auditing build.sh: pacman -Su ---"
    if [ -f "build.sh" ] && ! grep -q "pacman -S.*u" build.sh; then
        log_error "build.sh is missing pacman -Su (system upgrade)"
    fi
}

audit_build_sh_no_duplicate_packages() {
    echo "--- Auditing build.sh: Duplicate packages ---"
    if [ -f "build.sh" ]; then
        # Extract only the PACKAGES section properly
        DUPS=$(sed -n '/^cat > "${PROFILE}\/packages.x86_64" << '\''PACKAGES'\''/,/^PACKAGES/p' build.sh | grep -v "PACKAGES" | sort | uniq -d || true)
        if [ -n "$DUPS" ]; then
            log_error "Duplicate packages in build.sh: $DUPS"
        fi
    fi
}

# --- 13-25: Repository Hygiene & Security ---

audit_repo_no_chmod_777_strict() {
    echo "--- Auditing Security: No chmod 777 ---"
    if grep -rE "chmod (0?777|777)" . --exclude-dir=.git --exclude-dir=.Jules --exclude="*.md" --exclude="workflows_to_add.txt" --exclude="repo_audit.sh"; then
        log_error "Found dangerous chmod 777"
    fi
}

audit_repo_no_plaintext_chpasswd() {
    echo "--- Auditing Security: No plaintext chpasswd ---"
    if grep -r "chpasswd" . --exclude-dir=.git --exclude-dir=.Jules --exclude="*.md" --exclude="workflows_to_add.txt" | grep -v "\-e"; then
        log_error "Found chpasswd without -e (potential plaintext password)"
    fi
}

audit_repo_gitkeep_no_extension() {
    echo "--- Auditing Hygiene: .gitkeep format ---"
    NON_EMPTY_GITKEEP=$(find . -name ".gitkeep" -type f -size +0)
    if [ -n "$NON_EMPTY_GITKEEP" ]; then
        log_error ".gitkeep files must be empty: $NON_EMPTY_GITKEEP"
    fi
}

audit_repo_shell_extension_consistency() {
    echo "--- Auditing Hygiene: Shell extension consistency ---"
    # Files with .sh should have shebang
    for f in $(find . -name "*.sh" -type f -not -path '*/.*'); do
        if ! head -n 1 "$f" | grep -q "^#!"; then
            log_error "File $f has .sh extension but missing shebang"
        fi
    done
}

audit_repo_trailing_whitespace_all() {
    echo "--- Auditing Hygiene: Trailing whitespace ---"
    if grep -rI "[[:blank:]]$" . --exclude-dir=.git --exclude-dir=.Jules --exclude="pnpm-lock.yaml" --exclude="*.png" --exclude="*.jpg" --exclude="*.ico"; then
        log_error "Found trailing whitespace"
    fi
}

audit_repo_no_nested_git_dir() {
    echo "--- Auditing Hygiene: No nested .git ---"
    NESTED_GIT=$(find . -mindepth 2 -name ".git" -type d)
    if [ -n "$NESTED_GIT" ]; then
        log_error "Found nested .git directories"
    fi
}

audit_repo_license_sanity() {
    echo "--- Auditing Hygiene: License file ---"
    if [ ! -f "LICENSE" ] && [ ! -f "LICENSE.md" ]; then
        log_error "Missing LICENSE file"
    fi
}

audit_repo_readme_badge_https() {
    echo "--- Auditing README: Badge HTTPS ---"
    if [ -f "README.md" ] && grep "http://" README.md | grep -E "img.shields.io|badge"; then
        log_error "README badges should use HTTPS"
    fi
}

audit_repo_readme_toc_required() {
    echo "--- Auditing README: Table of Contents ---"
    if [ -f "README.md" ]; then
        LINES=$(wc -l < README.md)
        if [ "$LINES" -gt 100 ] && ! grep -qi "Table of Contents" README.md && ! grep -q "^- \[.*\](#.*)" README.md; then
            log_error "README.md is long (>100 lines) but missing Table of Contents"
        fi
    fi
}

audit_repo_lowercase_directories() {
    echo "--- Auditing Hygiene: Lowercase directories ---"
    UPPER_DIRS=$(find . -maxdepth 2 -type d -not -path '*/.*' | grep -E "/[A-Z]" | grep -v "./Notes" || true)
    if [ -n "$UPPER_DIRS" ]; then
        log_warn "Found directories with uppercase letters (recommend lowercase): $UPPER_DIRS"
    fi
}

audit_repo_snake_case_scripts() {
    echo "--- Auditing Hygiene: Snake case scripts ---"
    KEBAB_SCRIPTS=$(find scripts -name "*-*" -type f || true)
    if [ -n "$KEBAB_SCRIPTS" ]; then
        log_warn "Found scripts with kebab-case (recommend snake_case): $KEBAB_SCRIPTS"
    fi
}

audit_repo_no_temp_files() {
    echo "--- Auditing Hygiene: No temp files ---"
    TEMP_FILES=$(find . -name "*.tmp" -o -name "*~" -o -name "*.swp" -type f | grep -v "node_modules" || true)
    if [ -n "$TEMP_FILES" ]; then
        log_error "Found temporary/backup files: $TEMP_FILES"
    fi
}

audit_repo_no_backup_files() {
    echo "--- Auditing Hygiene: No backup files ---"
    BAK_FILES=$(find . -name "*.bak" -type f || true)
    if [ -n "$BAK_FILES" ]; then
        log_error "Found .bak files: $BAK_FILES"
    fi
}

# --- 26-31: Markdown Standards ---

audit_markdown_empty_link_check() {
    echo "--- Auditing Markdown: Empty links ---"
    if grep -rE "\[[^]]*\]\(\)" . --include="*.md" --exclude-dir=node_modules; then
        log_error "Found empty markdown targets"
    fi
}

audit_markdown_anchor_links() {
    echo "--- Auditing Markdown: Anchor links ---"
    BAD_ANCHORS=$(grep -rhE "\[[^]]+\]\(#[^)]+\)" . --include="*.md" --exclude-dir=node_modules | grep -vE "\(#[a-z0-9-]+\)" || true)
    if [ -n "$BAD_ANCHORS" ]; then
        log_warn "Malformed internal anchors (recommend #lowercase-kebab): $BAD_ANCHORS"
    fi
}

audit_markdown_no_tabs() {
    echo "--- Auditing Markdown: No tabs ---"
    if grep -rP "\t" . --include="*.md" --exclude-dir=node_modules; then
        log_error "Found tabs in Markdown files"
    fi
}

audit_markdown_no_fixme() {
    echo "--- Auditing Markdown: No FIXME ---"
    if grep -ri "FIXME" . --include="*.md" --exclude-dir=node_modules; then
        log_warn "Found FIXME in Markdown files"
    fi
}

audit_markdown_inclusive_language() {
    echo "--- Auditing Markdown: Inclusive language ---"
    if grep -riE "\b(white-?list|black-?list|master|slave)\b" . --include="*.md" --exclude-dir=.git; then
        log_warn "Found potentially non-inclusive language"
    fi
}

audit_markdown_header_punctuation() {
    echo "--- Auditing Markdown: Header punctuation ---"
    if grep -rE "^#+ .*[.!?:;,]$" . --include="*.md" --exclude-dir=node_modules; then
        log_warn "Markdown headers should generally not end in punctuation"
    fi
}

# --- 32-41: Workflow Best Practices ---

audit_workflow_checkout_v4() {
    echo "--- Auditing Workflows: actions/checkout version ---"
    if [ -d ".github/workflows" ]; then
        if grep -r "uses: actions/checkout@" .github/workflows/ | grep -vE "@v4|@[a-f0-9]{40}"; then
            log_error "Outdated actions/checkout version (upgrade to @v4)"
        fi
    fi
}

audit_workflow_no_node_16_actions() {
    echo "--- Auditing Workflows: Node 16 actions ---"
    if [ -d ".github/workflows" ]; then
        if grep -r "uses: actions/setup-node@" .github/workflows/ | grep -vE "@v3|@v4"; then
            log_warn "Potential Node 16 setup-node version found"
        fi
    fi
}

audit_workflow_explicit_bash_shell() {
    echo "--- Auditing Workflows: Explicit bash shell ---"
    if [ -d ".github/workflows" ]; then
        # Check for 'run:' not followed by 'shell:' or 'uses:' within next few lines
        if grep -r "run:" .github/workflows/ -A 1 | grep -v "\-\-" | sed '/run:/n; /shell:/d; /uses:/d' | grep -v "^$" | grep -v "run:"; then
             log_warn "Some workflow steps might be missing explicit shell: bash"
        fi
    fi
}

audit_workflow_no_empty_run_blocks() {
    echo "--- Auditing Workflows: No empty run blocks ---"
    if [ -d ".github/workflows" ]; then
        if grep -r "run: $" .github/workflows/; then
            log_error "Found empty run blocks in workflows"
        fi
    fi
}

audit_workflow_job_permissions_only() {
    echo "--- Auditing Workflows: Job-level permissions ---"
    if [ -d ".github/workflows" ]; then
        if grep -q "^permissions:" .github/workflows/*.yml 2>/dev/null; then
            log_warn "Top-level permissions found (recommend job-level for least privilege)"
        fi
    fi
}

audit_workflow_timeout_reasonable() {
    echo "--- Auditing Workflows: Reasonable timeouts ---"
    if [ -d ".github/workflows" ]; then
        if find .github/workflows -name "*.yml" -exec grep -L "timeout-minutes:" {} + | grep -q ".yml"; then
            log_warn "Some workflows are missing timeout-minutes"
        fi
    fi
}

audit_workflow_kebab_filenames_strict() {
    echo "--- Auditing Workflows: Kebab-case filenames ---"
    if [ -d ".github/workflows" ]; then
        BAD_NAMES=$(find .github/workflows -name "*_*" -o -name "*[A-Z]*" -type f || true)
        if [ -n "$BAD_NAMES" ]; then
            log_warn "Workflow filenames should be kebab-case: $BAD_NAMES"
        fi
    fi
}

audit_workflow_no_absolute_script_paths() {
    echo "--- Auditing Workflows: No absolute script paths ---"
    if [ -d ".github/workflows" ]; then
        if grep -r "run: /" .github/workflows/ | grep -vE "/bin/bash|/usr/bin|/run/user"; then
            log_warn "Absolute path used in workflow run block"
        fi
    fi
}

audit_workflow_unused_workflow_inputs() {
    echo "--- Auditing Workflows: Unused inputs ---"
    if [ -d ".github/workflows" ]; then
        for f in .github/workflows/*.yml; do
            # Simple check for inputs in workflow_dispatch
            INPUTS=$(grep -oP "(?<=  )[a-zA-Z0-9_-]+(?=:)" "$f" | sed -n '/inputs:/,$p' | grep -v "inputs:" | grep -v "description:" | grep -v "required:" | grep -v "default:" | grep -v "type:" || true)
            for input in $INPUTS; do
                if ! grep -q "github.event.inputs.$input" "$f"; then
                    log_warn "Input '$input' in $f might be unused"
                fi
            done
        done
    fi
}

audit_workflow_no_github_token_leak() {
    echo "--- Auditing Workflows: No token leak ---"
    if [ -d ".github/workflows" ]; then
        if grep -rE "echo.*(github\.token|secrets\.)" .github/workflows/; then
            log_error "Potential GitHub Token/Secret leak via echo in workflows"
        fi
    fi
}

# --- 42-45: UX & Welcome Page ---

audit_zenity_dimensions_strict() {
    echo "--- Auditing UX: Zenity dimensions ---"
    if grep -r "zenity" . --exclude-dir=.git | grep -v "\-\-width=450 \-\-height=500"; then
        log_warn "Zenity dialog found with non-standard dimensions (expected 450x500 for KibaTV/OS)"
    fi
}

audit_zenity_standard_dimensions() {
    echo "--- Auditing UX: Zenity standard dimensions ---"
    if grep -r "zenity" . --exclude-dir=.git | grep -v "\-\-width="; then
        log_error "Zenity dialog found without explicit dimensions"
    fi
}

audit_build_welcome_apps() {
    echo "--- Auditing build.sh: Welcome apps ---"
    if [ -f "build.sh" ] && ! grep -q "firefox" build.sh; then
        log_error "Firefox missing from welcome.html apps in build.sh"
    fi
}

audit_build_welcome_screenshot_help() {
    echo "--- Auditing build.sh: Welcome screenshot alt ---"
    if [ -f "build.sh" ] && grep -q "welcome.html" build.sh && ! grep -q "alt=" build.sh; then
        log_error "Image in welcome.html missing alt text"
    fi
}

# --- Dispatcher ---

ALL_CHECKS=(
    build_sh_customize_set_e
    build_sh_pacman_populate
    build_sh_paperde_ldconfig
    build_sh_liveuser_uid
    build_sh_octopi_usage
    build_sh_zsh_default
    build_sh_relative_symlinks
    build_sh_desktop_entry_kiba
    build_sh_sudoers_perms
    build_sh_wallpaper_consistency
    build_sh_pacman_su
    build_sh_no_duplicate_packages
    repo_no_chmod_777_strict
    repo_no_plaintext_chpasswd
    repo_gitkeep_no_extension
    repo_shell_extension_consistency
    repo_trailing_whitespace_all
    repo_no_nested_git_dir
    repo_license_sanity
    repo_readme_badge_https
    repo_readme_toc_required
    repo_lowercase_directories
    repo_snake_case_scripts
    repo_no_temp_files
    repo_no_backup_files
    markdown_empty_link_check
    markdown_anchor_links
    markdown_no_tabs
    markdown_no_fixme
    markdown_inclusive_language
    markdown_header_punctuation
    workflow_checkout_v4
    workflow_no_node_16_actions
    workflow_explicit_bash_shell
    workflow_no_empty_run_blocks
    workflow_job_permissions_only
    workflow_timeout_reasonable
    workflow_kebab_filenames_strict
    workflow_no_absolute_script_paths
    workflow_unused_workflow_inputs
    workflow_no_github_token_leak
    zenity_dimensions_strict
    zenity_standard_dimensions
    build_welcome_apps
    build_welcome_screenshot_help
)

if [ $# -eq 0 ]; then
    echo "=== Running all KibaOS Repository Audit checks ==="
    for check in "${ALL_CHECKS[@]}"; do
        "audit_$check"
    done
else
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --audit-*)
                check_name=$(echo "$1" | sed 's/--audit-//' | tr '-' '_')
                if declare -f "audit_$check_name" > /dev/null; then
                    "audit_$check_name"
                else
                    echo "Unknown audit check: $1"
                    exit 1
                fi
                ;;
            --help)
                echo "Usage: $0 [--audit-<check-name>]"
                echo "Available checks:"
                for check in "${ALL_CHECKS[@]}"; do
                    echo "  --audit-$(echo "$check" | tr '_' '-')"
                done
                exit 0
                ;;
            *)
                echo "Unknown flag: $1"
                exit 1
                ;;
        esac
        shift
    done
fi

echo "=== Audit Complete ==="
exit $EXIT_CODE
