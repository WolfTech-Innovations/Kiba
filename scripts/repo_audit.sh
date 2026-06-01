#!/bin/bash
set -euo pipefail

# KibaOS Repository Audit Script
# Consolidates multiple repository health and security checks

EXIT_CODE=0
AUDIT_MODE="all"

log_error() {
    echo "ERROR: $1"
    EXIT_CODE=1
}

log_warn() {
    echo "WARN: $1"
}

run_check() {
    local check_name=$1
    if [[ "$AUDIT_MODE" == "all" || "$AUDIT_MODE" == "$check_name" ]]; then
        return 0
    fi
    return 1
}

# Parse flags
if [[ $# -gt 0 ]]; then
    AUDIT_MODE="$1"
fi

echo "=== Running KibaOS Repository Audit ($AUDIT_MODE) ==="

# --- build.sh Checks ---
if [ -f "build.sh" ]; then
    if run_check "--audit-build-sh-customize-set-e"; then
        if ! grep -A 5 "cat > \"\${AIROOTFS}/root/customize_airootfs.sh\"" build.sh | grep -q "set -e"; then
            log_error "customize_airootfs.sh in build.sh is missing set -e"
        fi
    fi

    if run_check "--audit-build-sh-pacman-populate"; then
        if ! grep -q "pacman-key --populate archlinux" build.sh; then
            log_error "build.sh is missing pacman-key --populate archlinux"
        fi
    fi

    if run_check "--audit-build-sh-relative-symlinks"; then
        if grep "ln -s" build.sh | grep -v "ln -sf" | grep -q "/"; then
             log_warn "Potential absolute symlink found in build.sh"
        fi
    fi

    if run_check "--audit-build-sh-paperde-ldconfig"; then
        if grep -q "paperde" build.sh && ! grep -A 20 "paperde" build.sh | grep -q "ldconfig"; then
            log_error "ldconfig might be missing after paperde install"
        fi
    fi

    if run_check "--audit-build-sh-desktop-entry-kiba"; then
        if ! grep -q "kibaos.desktop" build.sh && ! grep -q "kibaos-install.desktop" build.sh; then
            log_error "build.sh might be missing Kiba desktop entry configuration"
        fi
    fi

    if run_check "--audit-build-sh-sudoers-perms"; then
        if grep -q "sudoers.d" build.sh && ! grep -q "0440" build.sh; then
            log_error "Potential insecure permissions for sudoers.d in build.sh"
        fi
    fi

    if run_check "--audit-build-sh-liveuser-uid"; then
        if grep -q "liveuser" build.sh && ! grep -q "1000" build.sh; then
             log_error "liveuser UID 1000 not explicitly set in build.sh"
        fi
    fi

    if run_check "--audit-build-sh-octopi-usage"; then
        if grep -q "octopi" build.sh; then
            log_warn "Octopi usage detected in build.sh"
        fi
    fi

    if run_check "--audit-build-sh-wallpaper-consistency"; then
        if grep -q "WALLPAPER_URL" build.sh && ! grep -q "wallpaper.png" build.sh; then
            log_error "Wallpaper URL defined but destination name is inconsistent in build.sh"
        fi
    fi

    if run_check "--audit-build-sh-zsh-default"; then
        if grep -q "zsh" build.sh && ! grep -q "chsh -s /usr/bin/zsh" build.sh && ! grep -q "SHELL=/usr/bin/zsh" build.sh; then
            log_warn "Zsh is mentioned but might not be set as default shell in build.sh"
        fi
    fi
fi

# --- Security Checks ---
if run_check "--audit-repo-no-chmod-777-strict"; then
    if grep -rE "chmod (0?777|777)" . --exclude-dir=.git --exclude="repo_audit.sh" --exclude="*.md" --exclude="pnpm-lock.yaml" --exclude-dir="node_modules" --exclude="workflows_to_add.txt"; then
        log_error "Found dangerous chmod 777"
    fi
fi

if run_check "--audit-repo-no-plaintext-chpasswd"; then
    if grep -r "chpasswd" . --exclude-dir=.git --exclude="repo_audit.sh" --exclude="*.md" --exclude="build.sh" --exclude="workflows_to_add.txt" | grep -v "\-e"; then
        log_error "Found chpasswd usage without -e (potential plaintext password)"
    fi
fi

if run_check "--audit-repo-no-nested-git-dir"; then
    NESTED=$(find . -mindepth 2 -name ".git" -type d)
    if [ -n "$NESTED" ]; then
        log_error "Found nested .git directory: $NESTED"
    fi
fi

# --- Hygiene Checks ---
if run_check "--audit-repo-trailing-whitespace-all"; then
    if grep -rI "[[:blank:]]$" . --exclude-dir=.git --exclude="pnpm-lock.yaml" --exclude-dir="node_modules" --exclude="*.png" --exclude="*.jpg" --exclude="*.ico"; then
        log_error "Found trailing whitespace"
    fi
fi

if run_check "--audit-repo-gitkeep-no-extension"; then
    BAD_GITKEEP=$(find . -name ".gitkeep.*")
    if [ -n "$BAD_GITKEEP" ]; then
        log_error ".gitkeep files should not have extensions: $BAD_GITKEEP"
    fi
fi

if run_check "--audit-repo-shell-extension-consistency"; then
    if find . -name "*.shell" -type f | grep -q "."; then
        log_error "Use .sh extension instead of .shell for consistency"
    fi
fi

if run_check "--audit-repo-license-sanity"; then
    if [ ! -f "LICENSE" ]; then
        log_error "LICENSE file is missing"
    fi
fi

# --- Markdown Checks ---
if run_check "--audit-markdown-empty-link-check"; then
    if grep -rE "\[[^]]*\]\(\)" . --include="*.md" --exclude-dir="node_modules"; then
        log_error "Found empty markdown targets"
    fi
fi

if run_check "--audit-repo-markdown-anchor-links"; then
     # Check for malformed anchors (e.g. including spaces)
     if grep -rE "\[.*\]\(#.* .*\)" . --include="*.md" --exclude-dir="node_modules"; then
         log_error "Found markdown anchors with spaces"
     fi
fi

if run_check "--audit-repo-readme-badge-https"; then
    if grep "http://" README.md 2>/dev/null | grep "img.shields.io" ; then
        log_error "Use HTTPS for README badges"
    fi
fi

# --- Workflow Checks ---
if run_check "--audit-workflow-checkout-v4"; then
    if [ -d ".github/workflows" ]; then
        if grep -r "uses: actions/checkout@" .github/workflows/ | grep -vE "@v4|@[a-f0-9]{40}"; then
            log_error "Outdated actions/checkout version (upgrade to @v4)"
        fi
    fi
fi

if run_check "--audit-workflow-no-node-16-actions"; then
    if grep -r "node16" .github/workflows/ 2>/dev/null; then
        log_warn "Workflow might be using Node 16 which is deprecated"
    fi
fi

if run_check "--audit-workflow-explicit-bash-shell"; then
     if grep -r "run:" .github/workflows/ | grep -v "shell: bash" && grep -r "run:" .github/workflows/ | grep -v "uses:"; then
        log_warn "Workflows should explicitly specify shell: bash for run blocks"
     fi
fi

if run_check "--audit-workflow-no-empty-run-blocks"; then
    if grep -r "run: $" .github/workflows/ 2>/dev/null; then
        log_error "Found empty run block in workflows"
    fi
fi

if run_check "--audit-workflow-job-permissions-only"; then
    if grep -r "^permissions:" .github/workflows/ 2>/dev/null; then
        log_warn "Top-level permissions found; prefer per-job permissions for security"
    fi
fi

if run_check "--audit-workflow-timeout-reasonable"; then
    if grep -r "timeout-minutes:" .github/workflows/ | grep -vE "timeout-minutes: [0-9]{1,2}$" ; then
        log_warn "Workflow timeout might be excessively long"
    fi
fi

if run_check "--audit-workflow-kebab-filenames-strict"; then
    BAD_WF=$(find .github/workflows -name "*_*" -o -name "*[A-Z]*" | grep -v "build.yml")
    if [ -n "$BAD_WF" ]; then
        log_error "Workflow filenames should be kebab-case: $BAD_WF"
    fi
fi

if run_check "--audit-workflow-no-absolute-script-paths"; then
    if grep -r "run: /" .github/workflows/ | grep -v "run: /usr/bin" | grep -v "run: /bin"; then
        log_warn "Potential absolute path used in workflow run block"
    fi
fi

if run_check "--audit-workflow-unused-workflow-inputs"; then
    # Placeholder: complex to check via grep, but we can look for inputs not used via ${{ inputs. }}
    log_warn "Manual audit recommended for unused workflow inputs"
fi

if run_check "--audit-workflow-no-github-token-leak"; then
    if grep -rE "echo.*(github\.token|secrets\.)" .github/workflows/; then
        log_error "Potential GitHub Token/Secret leak via echo in workflows"
    fi
fi

echo "=== Audit Complete ==="
exit $EXIT_CODE
