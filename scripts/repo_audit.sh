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
    # Verify ldconfig after PaperDE build (conditional)
    PAPERDE_LINE=$(grep -n "ninja -C paperde-src/build install" build.sh | cut -d: -f1 || true)
    if [ -n "$PAPERDE_LINE" ]; then
        if ! tail -n +"$PAPERDE_LINE" build.sh | head -n 21 | grep -q "ldconfig"; then
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
EMPTY_LINKS=$(grep -rE "\[[^]]*\]\(\)" . --include="*.md" | grep -v "node_modules" || true)
if [ -n "$EMPTY_LINKS" ]; then
    log_error "Found empty markdown targets:"
    echo "$EMPTY_LINKS"
fi
# Internal anchors format (should be lowercase-kebab)
BAD_ANCHORS=$(grep -rhE "\[[^]]+\]\(#[^)]+\)" . --include="*.md" | grep -vE "\(#[a-z0-9-]+\)" || true)
if [ -n "$BAD_ANCHORS" ]; then
    log_warn "Malformed internal anchors (recommend #lowercase-kebab):"
    echo "$BAD_ANCHORS"
fi

# 3. Security Checks
echo "--- Auditing Security ---"
# Common exclusions for security greps
EXCLUDE_ARGS=(
    --exclude-dir=.git
    --exclude-dir=.github
    --exclude-dir=.Jules
    --exclude-dir=node_modules
    --exclude="*.md"
    --exclude="workflows_to_add.txt"
    --exclude="repo_audit.sh"
)

# chmod 777
CHMOD_777=$(grep -rE "chmod (0?777|777)" . "${EXCLUDE_ARGS[@]}" || true)
if [ -n "$CHMOD_777" ]; then
    log_error "Found dangerous chmod 777:"
    echo "$CHMOD_777"
fi

# chpasswd without -e
CHPASSWD_PLAIN=$(grep -r "chpasswd" . "${EXCLUDE_ARGS[@]}" | grep -v "chpasswd -e" || true)
if [ -n "$CHPASSWD_PLAIN" ]; then
    log_error "Found chpasswd without -e (plaintext risk):"
    echo "$CHPASSWD_PLAIN"
fi

# Token leaks in workflows
TOKEN_LEAKS=$(grep -rE "echo.*(github\.token|secrets\.)" .github/workflows/ || true)
if [ -n "$TOKEN_LEAKS" ]; then
    log_error "Potential GitHub Token/Secret leak via echo in workflows:"
    echo "$TOKEN_LEAKS"
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
TRAILING_WHITESPACE=$(grep -rIn "[[:blank:]]$" . \
    --exclude-dir=.git --exclude-dir=.github --exclude-dir=.Jules --exclude-dir=node_modules \
    --exclude="pnpm-lock.yaml" --exclude="*.png" --exclude="*.jpg" --exclude="*.md" --exclude="workflows_to_add.txt" --exclude="repo_audit.sh" || true)
if [ -n "$TRAILING_WHITESPACE" ]; then
    log_error "Found trailing whitespace:"
    echo "$TRAILING_WHITESPACE"
fi

# 5. Workflow Best Practices
echo "--- Auditing Workflows ---"
# actions/checkout version
OUTDATED_CHECKOUT=$(grep -r "uses: actions/checkout@" .github/workflows/ | grep -vE "@v4|@[a-f0-9]{40}" || true)
if [ -n "$OUTDATED_CHECKOUT" ]; then
    log_error "Outdated actions/checkout version (upgrade to @v4):"
    echo "$OUTDATED_CHECKOUT"
fi

echo "=== Audit Complete ==="
return $EXIT_CODE 2>/dev/null || exit $EXIT_CODE
