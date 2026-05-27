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

echo "=== Running KibaOS Repository Audit ==="

# 1. build.sh Integrity
if [ -f "build.sh" ]; then
    echo "--- Auditing build.sh ---"
    # Verify set -e in embedded customize_airootfs
    if ! grep -A 2 "cat > \"\${AIROOTFS}/root/customize_airootfs.sh\"" build.sh | grep -q "set -e"; then
        log_error "customize_airootfs.sh in build.sh is missing set -e"
    fi
    # Verify pacman-key populate
    if ! grep -q "pacman-key --populate archlinux" build.sh; then
        log_error "build.sh is missing pacman-key --populate archlinux"
    fi
    # Verify ldconfig after PaperDE build (if PaperDE is built)
    if grep -q "ninja -C paperde-src/build install" build.sh; then
        if ! grep -A 20 "ninja -C paperde-src/build install" build.sh | grep -q "ldconfig"; then
            log_error "ldconfig not found after PaperDE installation in build.sh"
        fi
    fi
    # Verify liveuser UID consistency
    if grep -q "liveuser" build.sh; then
        if ! grep -q "1000:1000" build.sh; then
            log_error "liveuser found in build.sh but UID/GID 1000 is not explicitly set"
        fi
    fi
fi

# 2. Markdown Hygiene
echo "--- Auditing Markdown files ---"
# Empty links
if grep -rE "\[[^]]*\]\(\)" . --include="*.md" | grep -v "node_modules"; then
    log_error "Found empty markdown targets"
fi
# Internal anchors format (should be lowercase-kebab)
BAD_ANCHORS=$(grep -rhE "\[[^]]+\]\(#[^)]+\)" . --include="*.md" | grep -vE "\(#[a-z0-9-]+\)" || true)
if [ -n "$BAD_ANCHORS" ]; then
    log_warn "Malformed internal anchors (recommend #lowercase-kebab):"
    echo "$BAD_ANCHORS"
fi

# 3. Security Checks
echo "--- Auditing Security ---"
# chmod 777
if grep -rE "chmod (0?777|777)" . --exclude-dir=.git --exclude="repo_audit.sh"; then
    log_error "Found dangerous chmod 777"
fi
# Token leaks in workflows
if grep -rE "echo.*(github\.token|secrets\.)" .github/workflows/; then
    log_error "Potential GitHub Token/Secret leak via echo in workflows"
fi

# 4. Repository Hygiene
echo "--- Auditing Repository Hygiene ---"
# .gitkeep should be empty
NON_EMPTY_GITKEEP=$(find . -name ".gitkeep" -type f -size +0)
if [ -n "$NON_EMPTY_GITKEEP" ]; then
    log_error ".gitkeep files must be empty: $NON_EMPTY_GITKEEP"
fi
# Nested .git dirs
NESTED_GIT=$(find . -mindepth 2 -name ".git" -type d)
if [ -n "$NESTED_GIT" ]; then
    log_error "Found nested .git directories"
fi
# Trailing whitespace (excluding some files if needed)
if grep -rI "[[:blank:]]$" . --exclude-dir=.git --exclude="pnpm-lock.yaml" --exclude="*.png" --exclude="*.jpg"; then
    log_error "Found trailing whitespace"
fi

# 5. Workflow Best Practices
echo "--- Auditing Workflows ---"
# actions/checkout version
if grep -r "uses: actions/checkout@" .github/workflows/ | grep -vE "@v4|@[a-f0-9]{40}"; then
    log_error "Outdated actions/checkout version (upgrade to @v4)"
fi

echo "=== Audit Complete ==="
return $EXIT_CODE 2>/dev/null || exit $EXIT_CODE
