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

# --- Audit Functions ---

# 1. audit-build-sh-customize-set-e.yml
audit_build_sh_customize_set_e() {
    echo "--- Auditing build.sh: customize_airootfs set -e ---"
    if [ -f "build.sh" ]; then
        if ! grep -A 2 "cat > \"\${AIROOTFS}/root/customize_airootfs.sh\"" build.sh | grep -q "set -e"; then
            log_error "customize_airootfs.sh in build.sh is missing set -e"
        fi
    fi
}

# 2. audit-build-sh-pacman-populate.yml
audit_build_sh_pacman_populate() {
    echo "--- Auditing build.sh: pacman-key populate ---"
    if [ -f "build.sh" ]; then
        if ! grep -q "pacman-key --populate archlinux" build.sh; then
            log_error "build.sh is missing pacman-key --populate archlinux"
        fi
    fi
}

# 3. audit-build-sh-relative-symlinks.yml
audit_build_sh_relative_symlinks() {
    echo "--- Auditing build.sh: relative symlinks ---"
    if [ -f "build.sh" ]; then
        if grep "ln -s" build.sh | grep -v "ln -sf" | grep -v "\.\./" | grep -q "/"; then
             log_warn "Potential absolute symlink in build.sh"
        fi
    fi
}

# 4. audit-build-sh-paperde-ldconfig.yml
audit_build_sh_paperde_ldconfig() {
    echo "--- Auditing build.sh: ldconfig after PaperDE ---"
    if [ -f "build.sh" ]; then
        if grep -q "ninja -C paperde-src/build install" build.sh; then
            if ! grep -A 20 "ninja -C paperde-src/build install" build.sh | grep -q "ldconfig"; then
                log_error "ldconfig not found after PaperDE installation in build.sh"
            fi
        fi
    fi
}

# 5. audit-build-sh-desktop-entry-kiba.yml
audit_build_sh_desktop_entry_kiba() {
    echo "--- Auditing build.sh: Kiba desktop entries ---"
    if [ -f "build.sh" ]; then
        if ! grep -q "kibaos-install.desktop" build.sh; then
            log_error "KibaOS install desktop entry missing in build.sh"
        fi
    fi
}

# 6. audit-build-sh-sudoers-perms.yml
audit_build_sh_sudoers_perms() {
    echo "--- Auditing build.sh: sudoers permissions ---"
    if [ -f "build.sh" ]; then
        if grep -q "etc/sudoers.d" build.sh; then
            if ! grep -q "chmod 0440" build.sh; then
                log_error "sudoers.d file found but chmod 0440 is missing"
            fi
        fi
    fi
}

# 7. audit-build-sh-liveuser-uid.yml
audit_build_sh_liveuser_uid() {
    echo "--- Auditing build.sh: liveuser UID consistency ---"
    if [ -f "build.sh" ]; then
        if grep -q "liveuser" build.sh; then
            if ! grep -q "1000:1000" build.sh; then
                log_error "liveuser found in build.sh but UID/GID 1000 is not explicitly set"
            fi
        fi
    fi
}

# 8. audit-build-sh-wallpaper-consistency.yml
audit_build_sh_wallpaper_consistency() {
    echo "--- Auditing build.sh: wallpaper consistency ---"
    if [ -f "build.sh" ]; then
        if grep -q "wallpaper.png" build.sh; then
            if ! grep -q "gsettings set org.gnome.desktop.background picture-uri" build.sh; then
                log_error "wallpaper.png defined but gsettings background not set"
            fi
        fi
    fi
}

# 9. audit-build-sh-octopi-usage.yml
audit_build_sh_octopi_usage() {
    echo "--- Auditing build.sh: octopi usage (deprecated) ---"
    if [ -f "build.sh" ]; then
        if grep -qi "octopi" build.sh; then
            log_warn "Octopi usage detected in build.sh (deprecated)"
        fi
    fi
}

# 10. audit-build-sh-zsh-default.yml
audit_build_sh_zsh_default() {
    echo "--- Auditing build.sh: zsh default check ---"
    if [ -f "build.sh" ]; then
        if grep -q "/bin/zsh" build.sh && ! grep -q "chsh -s /bin/zsh" build.sh; then
            log_warn "zsh mentioned but not set as default shell"
        fi
    fi
}

# 11. audit-markdown-empty-link-check.yml
audit_markdown_empty_link_check() {
    echo "--- Auditing Markdown: Empty links ---"
    if grep -rE "\[[^]]*\]\(\)" . --include="*.md" | grep -v "node_modules" | grep -v ".git" | grep -q "."; then
        log_error "Found empty markdown targets"
    fi
}

# 12. audit-repo-license-sanity.yml
audit_repo_license_sanity() {
    echo "--- Auditing Repo: License sanity ---"
    if [ ! -f "LICENSE" ]; then
        log_error "LICENSE file missing in root"
    fi
    if grep -r "License" . --include="*.md" | grep -qi "proprietary"; then
        log_error "Proprietary license mention found in markdown"
    fi
}

# 13. audit-repo-readme-badge-https.yml
audit_repo_readme_badge_https() {
    echo "--- Auditing Repo: README badge HTTPS ---"
    if [ -f "README.md" ]; then
        if grep "http://img.shields.io" README.md; then
            log_error "Insecure shields.io badge link found in README.md"
        fi
    fi
}

# 14. audit-repo-no-chmod-777-strict.yml
audit_repo_no_chmod_777_strict() {
    echo "--- Auditing Security: No chmod 777 ---"
    if grep -rE "chmod (0?777|777)" . --exclude-dir=.git --exclude-dir=.github --exclude="scripts/repo_audit.sh" --exclude="*.md" | grep -q "."; then
        log_error "Found dangerous chmod 777"
    fi
}

# 15. audit-repo-no-plaintext-chpasswd.yml
audit_repo_no_plaintext_chpasswd() {
    echo "--- Auditing Security: No plaintext chpasswd ---"
    if grep -r "chpasswd" . --exclude-dir=.git --exclude-dir=.github --exclude="scripts/repo_audit.sh" --exclude="*.md" | grep -v "chpasswd -e" | grep -q "."; then
        log_error "Found chpasswd without -e flag (potential plaintext password)"
    fi
}

# 16. audit-repo-markdown-anchor-links.yml
audit_repo_markdown_anchor_links() {
    echo "--- Auditing Markdown: Anchor links format ---"
    BAD_ANCHORS=$(grep -rhE "\[[^]]+\]\(#[^)]+\)" . --include="*.md" | grep -vE "\(#[a-z0-9-]+\)" || true)
    if [ -n "$BAD_ANCHORS" ]; then
        log_warn "Malformed internal anchors (recommend #lowercase-kebab):"
        echo "$BAD_ANCHORS"
    fi
}

# 17. audit-repo-gitkeep-no-extension.yml
audit_repo_gitkeep_no_extension() {
    echo "--- Auditing Repo: Empty .gitkeep ---"
    NON_EMPTY_GITKEEP=$(find . -name ".gitkeep" -type f -size +0)
    if [ -n "$NON_EMPTY_GITKEEP" ]; then
        log_error ".gitkeep files must be empty: $NON_EMPTY_GITKEEP"
    fi
}

# 18. audit-repo-shell-extension-consistency.yml
audit_repo_shell_extension_consistency() {
    echo "--- Auditing Repo: Shell extension consistency ---"
    SHELL_WITHOUT_EXT=$(find scripts/ -type f ! -name "*.*" -exec grep -l "^#!/bin/bash" {} +)
    if [ -n "$SHELL_WITHOUT_EXT" ]; then
        log_warn "Shell scripts without .sh extension: $SHELL_WITHOUT_EXT"
    fi
}

# 19. audit-repo-trailing-whitespace-all.yml
audit_repo_trailing_whitespace_all() {
    echo "--- Auditing Repo: Trailing whitespace ---"
    if grep -rI "[[:blank:]]$" . --exclude-dir=.git --exclude-dir=node_modules --exclude="pnpm-lock.yaml" --exclude="*.png" --exclude="*.jpg" | grep -q "."; then
        log_error "Found trailing whitespace"
    fi
}

# 20. audit-repo-no-nested-git-dir.yml
audit_repo_no_nested_git_dir() {
    echo "--- Auditing Repo: No nested .git ---"
    NESTED_GIT=$(find . -mindepth 2 -name ".git" -type d)
    if [ -n "$NESTED_GIT" ]; then
        log_error "Found nested .git directories"
    fi
}

# 21. audit-workflow-checkout-v4.yml
audit_workflow_checkout_v4() {
    echo "--- Auditing Workflows: actions/checkout v4 ---"
    if grep -r "uses: actions/checkout@" .github/workflows/ | grep -vE "@v4|@[a-f0-9]{40}" | grep -q "."; then
        log_error "Outdated actions/checkout version (upgrade to @v4)"
    fi
}

# 22. audit-workflow-no-node-16-actions.yml
audit_workflow_no_node_16_actions() {
    echo "--- Auditing Workflows: No Node 16 actions ---"
    if grep -r "uses: actions/setup-node@" .github/workflows/ | grep -vE "@v[34]" | grep -q "."; then
        log_error "Outdated actions/setup-node version (upgrade to @v4)"
    fi
}

# 23. audit-workflow-explicit-bash-shell.yml
audit_workflow_explicit_bash_shell() {
    echo "--- Auditing Workflows: Explicit bash shell ---"
    for f in .github/workflows/*.yml; do
        if grep -q "run:" "$f" && ! grep -q "shell: bash" "$f"; then
            log_error "Workflow $f contains run blocks without explicit shell: bash"
        fi
    done
}

# 24. audit-workflow-no-empty-run-blocks.yml
audit_workflow_no_empty_run_blocks() {
    echo "--- Auditing Workflows: No empty run blocks ---"
    if grep -r "run: \"\"" .github/workflows/ | grep -q "."; then
        log_error "Found empty run blocks in workflows"
    fi
}

# 25. audit-workflow-job-permissions-only.yml
audit_workflow_job_permissions_only() {
    echo "--- Auditing Workflows: Job-level permissions ---"
    if grep -r "^permissions:" .github/workflows/ | grep -v "  permissions:" | grep -q "."; then
         log_warn "Top-level permissions found, prefer job-level permissions"
    fi
}

# 26. audit-workflow-timeout-reasonable.yml
audit_workflow_timeout_reasonable() {
    echo "--- Auditing Workflows: Reasonable timeout ---"
    for f in .github/workflows/*.yml; do
        if ! grep -q "timeout-minutes:" "$f"; then
            log_error "Workflow $f is missing timeout-minutes"
        fi
    done
}

# 27. audit-workflow-kebab-filenames-strict.yml
audit_workflow_kebab_filenames_strict() {
    echo "--- Auditing Workflows: Kebab-case filenames ---"
    for f in .github/workflows/*; do
        basename=$(basename "$f")
        if [[ $basename =~ [A-Z_] ]]; then
            log_error "Workflow filename $basename should be kebab-case"
        fi
    done
}

# 28. audit-workflow-no-absolute-script-paths.yml
audit_workflow_no_absolute_script_paths() {
    echo "--- Auditing Workflows: No absolute script paths ---"
    if grep -r "run: /" .github/workflows/ | grep -v "run: /usr/bin" | grep -v "run: /bin" | grep -q "."; then
        log_error "Potential absolute path to repository script in workflow"
    fi
}

# 29. audit-workflow-unused-workflow-inputs.yml
audit_workflow_unused_workflow_inputs() {
    echo "--- Auditing Workflows: Unused inputs ---"
    # Placeholder: complex to check via grep, logging skip
    echo "Skipping unused inputs check (requires AST parsing)"
}

# 30. audit-workflow-no-github-token-leak.yml
audit_workflow_no_github_token_leak() {
    echo "--- Auditing Security: No GitHub Token leak ---"
    if grep -rE "echo.*(github\.token|secrets\.)" .github/workflows/ | grep -q "."; then
        log_error "Potential GitHub Token/Secret leak via echo in workflows"
    fi
}

# 31. audit-repo-shell-check-syntax
audit_repo_shell_check_syntax() {
    echo "--- Auditing Repo: Shell syntax check ---"
    for f in $(find . -name "*.sh" -not -path "./.git/*"); do
        if ! bash -n "$f"; then
            log_error "Syntax error in $f"
        fi
    done
}

# 32. audit-build-sh-parallel-downloads
audit_build_sh_parallel_downloads() {
    echo "--- Auditing build.sh: ParallelDownloads ---"
    if [ -f "build.sh" ]; then
        if ! grep -q "ParallelDownloads = 10" build.sh; then
            log_warn "ParallelDownloads = 10 not found in build.sh"
        fi
    fi
}

# 33. audit-build-sh-consolidated-chown
audit_build_sh_consolidated_chown() {
    echo "--- Auditing build.sh: Consolidated chown ---"
    if [ -f "build.sh" ]; then
        CHOWN_COUNT=$(grep -c "chown -R 1000:1000 /home/liveuser" build.sh)
        if [ "$CHOWN_COUNT" -gt 3 ]; then
            log_warn "Redundant chown operations on /home/liveuser in build.sh ($CHOWN_COUNT found)"
        fi
    fi
}

# 34. audit-build-sh-welcome-accessibility
audit_build_sh_welcome_accessibility() {
    echo "--- Auditing build.sh: Welcome accessibility ---"
    if [ -f "build.sh" ]; then
        if ! grep -q "role=\"list\"" build.sh; then
             log_warn "ARIA list roles missing in welcome.html heredoc"
        fi
    fi
}

# 35. audit-repo-no-broken-symlinks
audit_repo_no_broken_symlinks() {
    echo "--- Auditing Repo: Broken symlinks ---"
    BROKEN=$(find . -xtype l)
    if [ -n "$BROKEN" ]; then
        log_error "Found broken symlinks: $BROKEN"
    fi
}

# 36. audit-repo-gitignore-check
audit_repo_gitignore_check() {
    echo "--- Auditing Repo: .gitignore check ---"
    if [ ! -f ".gitignore" ]; then
        log_error ".gitignore missing"
    fi
}

# 37. audit-repo-security-md-exists
audit_repo_security_md_exists() {
    echo "--- Auditing Repo: SECURITY.md exists ---"
    if [ ! -f "SECURITY.md" ]; then
        log_error "SECURITY.md missing"
    fi
}

# 38. audit-repo-contributing-md-exists
audit_repo_contributing_md_exists() {
    echo "--- Auditing Repo: CONTRIBUTING.md exists ---"
    if [ ! -f "CONTRIBUTING.md" ]; then
        log_error "CONTRIBUTING.md missing"
    fi
}

# 39. audit-repo-license-year-2026
audit_repo_license_year_2026() {
    echo "--- Auditing Repo: License year 2026 ---"
    if [ -f "LICENSE" ]; then
        if ! grep -q "2026" LICENSE; then
            log_warn "License year 2026 not found in LICENSE"
        fi
    fi
}

# 40. audit-repo-no-conflict-markers
audit_repo_no_conflict_markers() {
    echo "--- Auditing Repo: No conflict markers ---"
    if grep -rE "<<<<<<<|=======|>>>>>>>" . --exclude-dir=.git | grep -q "."; then
        log_error "Found git conflict markers"
    fi
}

# 41. audit-repo-eof-newline
audit_repo_eof_newline() {
    echo "--- Auditing Repo: EOF newline ---"
    if [ -f "build.sh" ]; then
        if [ "$(tail -c 1 build.sh | wc -l)" -eq 0 ]; then
            log_warn "build.sh missing newline at end of file"
        fi
    fi
}

# 42. audit-repo-todo-comments
audit_repo_todo_comments() {
    echo "--- Auditing Repo: TODO comments ---"
    if grep -ri "TODO" . --exclude-dir=.git | grep -q "."; then
        log_warn "Found TODO comments"
    fi
}

# 43. audit-repo-large-files
audit_repo_large_files() {
    echo "--- Auditing Repo: Large files (>10MB) ---"
    LARGE=$(find . -type f -size +10M -not -path '*/.git/*')
    if [ -n "$LARGE" ]; then
        log_warn "Found large files: $LARGE"
    fi
}

# 44. audit-repo-secrets-basic-scan
audit_repo_secrets_basic_scan() {
    echo "--- Auditing Repo: Secrets basic scan ---"
    if grep -rE "AIza[0-9A-Za-z-_]{35}" . --exclude-dir=.git | grep -q "."; then
        log_error "Potential Google API Key found"
    fi
}

# 45. audit-build-sh-chpasswd-secure
audit_build_sh_chpasswd_secure() {
    echo "--- Auditing build.sh: Secure chpasswd ---"
    if [ -f "build.sh" ]; then
        if grep "chpasswd" build.sh | grep -v "chpasswd -e" | grep -q "."; then
            log_error "Insecure chpasswd usage in build.sh"
        fi
    fi
}

# --- Flag Parsing ---

ARGS=()
while [ $# -gt 0 ]; do
    case "$1" in
        --audit-build-sh-customize-set-e) ARGS+=("audit_build_sh_customize_set_e") ;;
        --audit-build-sh-pacman-populate) ARGS+=("audit_build_sh_pacman_populate") ;;
        --audit-build-sh-relative-symlinks) ARGS+=("audit_build_sh_relative_symlinks") ;;
        --audit-build-sh-paperde-ldconfig) ARGS+=("audit_build_sh_paperde_ldconfig") ;;
        --audit-build-sh-desktop-entry-kiba) ARGS+=("audit_build_sh_desktop_entry_kiba") ;;
        --audit-build-sh-sudoers-perms) ARGS+=("audit_build_sh_sudoers_perms") ;;
        --audit-build-sh-liveuser-uid) ARGS+=("audit_build_sh_liveuser_uid") ;;
        --audit-build-sh-wallpaper-consistency) ARGS+=("audit_build_sh_wallpaper_consistency") ;;
        --audit-build-sh-octopi-usage) ARGS+=("audit_build_sh_octopi_usage") ;;
        --audit-build-sh-zsh-default) ARGS+=("audit_build_sh_zsh_default") ;;
        --audit-markdown-empty-link-check) ARGS+=("audit_markdown_empty_link_check") ;;
        --audit-repo-license-sanity) ARGS+=("audit_repo_license_sanity") ;;
        --audit-repo-readme-badge-https) ARGS+=("audit_repo_readme_badge_https") ;;
        --audit-repo-no-chmod-777-strict) ARGS+=("audit_repo_no_chmod_777_strict") ;;
        --audit-repo-no-plaintext-chpasswd) ARGS+=("audit_repo_no_plaintext_chpasswd") ;;
        --audit-repo-markdown-anchor-links) ARGS+=("audit_repo_markdown_anchor_links") ;;
        --audit-repo-gitkeep-no-extension) ARGS+=("audit_repo_gitkeep_no_extension") ;;
        --audit-repo-shell-extension-consistency) ARGS+=("audit_repo_shell_extension_consistency") ;;
        --audit-repo-trailing-whitespace-all) ARGS+=("audit_repo_trailing_whitespace_all") ;;
        --audit-repo-no-nested-git-dir) ARGS+=("audit_repo_no_nested_git_dir") ;;
        --audit-workflow-checkout-v4) ARGS+=("audit_workflow_checkout_v4") ;;
        --audit-workflow-no-node-16-actions) ARGS+=("audit_workflow_no_node_16_actions") ;;
        --audit-workflow-explicit-bash-shell) ARGS+=("audit_workflow_explicit_bash_shell") ;;
        --audit-workflow-no-empty-run-blocks) ARGS+=("audit_workflow_no_empty_run_blocks") ;;
        --audit-workflow-job-permissions-only) ARGS+=("audit_workflow_job_permissions_only") ;;
        --audit-workflow-timeout-reasonable) ARGS+=("audit_workflow_timeout_reasonable") ;;
        --audit-workflow-kebab-filenames-strict) ARGS+=("audit_workflow_kebab_filenames_strict") ;;
        --audit-workflow-no-absolute-script-paths) ARGS+=("audit_workflow_no_absolute_script_paths") ;;
        --audit-workflow-unused-workflow-inputs) ARGS+=("audit_workflow_unused_workflow_inputs") ;;
        --audit-workflow-no-github-token-leak) ARGS+=("audit_workflow_no_github_token_leak") ;;
        --audit-repo-shell-check-syntax) ARGS+=("audit_repo_shell_check_syntax") ;;
        --audit-build-sh-parallel-downloads) ARGS+=("audit_build_sh_parallel_downloads") ;;
        --audit-build-sh-consolidated-chown) ARGS+=("audit_build_sh_consolidated_chown") ;;
        --audit-build-sh-welcome-accessibility) ARGS+=("audit_build_sh_welcome_accessibility") ;;
        --audit-repo-no-broken-symlinks) ARGS+=("audit_repo_no_broken_symlinks") ;;
        --audit-repo-gitignore-check) ARGS+=("audit_repo_gitignore_check") ;;
        --audit-repo-security-md-exists) ARGS+=("audit_repo_security_md_exists") ;;
        --audit-repo-contributing-md-exists) ARGS+=("audit_repo_contributing_md_exists") ;;
        --audit-repo-license-year-2026) ARGS+=("audit_repo_license_year_2026") ;;
        --audit-repo-no-conflict-markers) ARGS+=("audit_repo_no_conflict_markers") ;;
        --audit-repo-eof-newline) ARGS+=("audit_repo_eof_newline") ;;
        --audit-repo-todo-comments) ARGS+=("audit_repo_todo_comments") ;;
        --audit-repo-large-files) ARGS+=("audit_repo_large_files") ;;
        --audit-repo-secrets-basic-scan) ARGS+=("audit_repo_secrets_basic_scan") ;;
        --audit-build-sh-chpasswd-secure) ARGS+=("audit_build_sh_chpasswd_secure") ;;
        *) echo "Unknown flag: $1"; exit 1 ;;
    esac
    shift
done

if [ ${#ARGS[@]} -eq 0 ]; then
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
    audit_repo_shell_check_syntax
    audit_build_sh_parallel_downloads
    audit_build_sh_consolidated_chown
    audit_build_sh_welcome_accessibility
    audit_repo_no_broken_symlinks
    audit_repo_gitignore_check
    audit_repo_security_md_exists
    audit_repo_contributing_md_exists
    audit_repo_license_year_2026
    audit_repo_no_conflict_markers
    audit_repo_eof_newline
    audit_repo_todo_comments
    audit_repo_large_files
    audit_repo_secrets_basic_scan
    audit_build_sh_chpasswd_secure
else
    for func in "${ARGS[@]}"; do
        $func
    done
fi

exit $EXIT_CODE
