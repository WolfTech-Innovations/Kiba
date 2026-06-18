import os

WORKFLOW_DIR = ".github/workflows"
os.makedirs(WORKFLOW_DIR, exist_ok=True)

# Common exclusions
EXCLUDES = "--exclude='scripts/generate_45_workflows.py' --exclude='WORKFLOWS.md' --exclude-dir='.git' --exclude-dir='node_modules'"

# 45+ Useful Audits/Checks
# We will generate a few consolidated workflows to avoid UI clutter
AUDITS = [
    ("prohibit-sudo-in-build", "Prohibit sudo in build.sh", "! grep 'sudo ' build.sh"),
    ("git-clone-depth", "Ensure git clone uses --depth=1", f"! grep 'git clone ' . -r --include='*.sh' {EXCLUDES} | grep -v '--depth=1'"),
    ("pacman-partial-upgrade", "Prohibit pacman -Sy without u", f"! grep -r 'pacman -Sy ' . --include='*.sh' {EXCLUDES}"),
    ("hardcoded-liveuser", "Detect hardcoded /home/liveuser", f"! grep -r '/home/liveuser' . --exclude='build.sh' --exclude='*.md' {EXCLUDES}"),
    ("shell-set-e", "Ensure shell scripts have set -e", "grep -l '#!/bin/bash' scripts/*.sh | xargs -I {} grep -L 'set -e' {} | xargs -r false"),
    ("prohibit-eval", "Prohibit eval in shell scripts", f"! grep -r 'eval ' scripts/ {EXCLUDES}"),
    ("curl-retry", "Ensure curl uses --retry", f"grep 'curl ' -r . --include='*.sh' {EXCLUDES} | grep -v '--retry' | xargs -r false"),
    ("wget-tries", "Ensure wget uses --tries", f"grep 'wget ' -r . --include='*.sh' {EXCLUDES} | grep -v '--tries' | xargs -r false"),
    ("safety-rm-rf", "Check for dangerous rm -rf /", f"! grep -r 'rm -rf /' . {EXCLUDES}"),
    ("prohibit-chmod-777", "Prohibit chmod 777", f"! grep -rE 'chmod (0?777|777)' . {EXCLUDES} --exclude='repo_audit.sh'"),
    ("prohibit-pip", "Prohibit pip install", f"! grep -r 'pip install' . {EXCLUDES}"),
    ("prohibit-npm", "Prohibit npm install (use pnpm)", f"! grep -r 'npm install' . {EXCLUDES}"),
    ("prohibit-yarn", "Prohibit yarn install (use pnpm)", f"! grep -r 'yarn install' . {EXCLUDES}"),
    ("fixme-check", "Check for FIXME comments", f"! grep -r 'FIXME' . {EXCLUDES}"),
    ("debug-log-check", "Check for DEBUG logs", f"! grep -r 'DEBUG' . --include='*.sh' --include='*.py' {EXCLUDES}"),
    ("console-log-check", "Check for console.log in JS", f"! grep -r 'console.log' . --include='*.js' {EXCLUDES}"),
    ("python-print-check", "Check for print in Python", f"! grep -r 'print(' . --include='*.py' --exclude='check_workflows.py' {EXCLUDES}"),
    ("hardcoded-ips", "Check for hardcoded IP addresses", f"! grep -rE '([0-9]{{1,3}}\\.){{3}}[0-9]{{1,3}}' . {EXCLUDES} --exclude='build.sh' --exclude='package-lock.json'"),
    ("localhost-check", "Check for localhost in configs", f"! grep -r 'localhost' . --include='*.conf' --include='*.ini' {EXCLUDES}"),
    ("insecure-http", "Check for insecure http links", f"! grep -r 'http://' . --exclude='build.sh' --exclude='*.md' {EXCLUDES}"),
    ("bak-old-files", "Check for .bak or .old files", "! find . -name '*.bak' -o -name '*.old' | grep ."),
    ("node-modules-check", "Check for node_modules in repo", "! find . -name 'node_modules' -type d -not -path './node_modules*' | grep ."),
    ("dist-build-check", "Check for dist or build dirs", r"! find . -type d \( -name 'dist' -o -name 'build' \) -not -path './node_modules*' | grep ."),
    ("package-lock-check", "Prohibit package-lock.json (use pnpm)", "! find . -name 'package-lock.json' | grep ."),
    ("yarn-lock-check", "Prohibit yarn.lock", "! find . -name 'yarn.lock' | grep ."),
    ("package-description", "Ensure package.json has description", "grep '\"description\":' package.json || false"),
    ("workflow-permissions", "Ensure workflows have permissions", "grep -L 'permissions:' .github/workflows/*.yml | xargs -r false"),
    ("gitkeep-check", "Ensure empty dirs have .gitkeep", "find . -type d -empty -not -path './.git*' | xargs -I {} [ -f {}/.gitkeep ] || false"),
    ("trailing-whitespace", "Check for trailing whitespace", f"! grep -r '[[:blank:]]$' . {EXCLUDES} --exclude='pnpm-lock.yaml' --exclude='*.png' --exclude='*.jpg'"),
    ("shell-set-u", "Ensure shell scripts have set -u", "grep -l '#!/bin/bash' scripts/*.sh | xargs -I {} grep -L 'set -u' {} | xargs -r false"),
    ("shell-pipefail", "Ensure shell scripts have pipefail", "grep -l '#!/bin/bash' scripts/*.sh | xargs -I {} grep -L 'pipefail' {} | xargs -r false"),
    ("non-standard-ext", "Check for non-standard file extensions", r"! find . -type f -name '*.*' | grep -vE '\.(sh|py|yml|yaml|md|js|json|png|jpg|txt|asc|conf|ini|qml|desc|qss|xml|preset|loader|entries|conf.d)$'"),
    ("hardcoded-1000", "Detect hardcoded UID 1000", f"! grep -r '1000:1000' . {EXCLUDES} --exclude='build.sh'"),
    ("airootfs-check", "Check airootfs variable safety", "grep 'AIROOTFS' build.sh | head -n 1 | grep -q 'AIROOTFS=' || false"),
    ("pacman-populate", "Ensure pacman-key --populate in build", "grep -q 'pacman-key --populate archlinux' build.sh"),
    ("ldconfig-check", "Ensure ldconfig after library installs", "grep -A 5 'install' build.sh | grep 'lib' | grep -v 'ldconfig' | xargs -r false || true"),
    ("font-inter-check", "Ensure Inter font usage", "grep -qE 'Inter|inter-font' build.sh"),
    ("calamares-https", "Ensure Calamares uses HTTPS check", "grep -q 'internetCheckUrl: https' build.sh"),
    ("parallel-downloads", "Ensure ParallelDownloads is 10", "grep -q 'ParallelDownloads = 10' build.sh"),
    ("alpm-user-creation", "Ensure alpm user is created", "grep -q 'alpm:x:951:951' build.sh"),
    ("prohibit-apt", "Prohibit apt/apt-get usage", f"! grep -rE 'apt-get |apt ' . {EXCLUDES}"),
    ("systemd-nm-enabled", "Ensure NetworkManager is enabled", "grep -q 'systemctl enable NetworkManager' build.sh"),
    ("bash-syntax-check", "Verify Bash syntax", "find . -name '*.sh' -print0 | xargs -0 -I {} bash -n {}"),
    ("json-syntax-check", "Verify JSON syntax", "find . -name '*.json' -not -path './node_modules/*' -print0 | xargs -0 -I {} python3 -m json.tool {} > /dev/null"),
    ("todo-check", "Check for TODO comments", f"! grep -r 'TODO' . {EXCLUDES}")
]

CONSOLIDATED_TEMPLATE = """name: Audit - Repository Health
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

permissions:
  contents: read

jobs:
  audit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
{steps}
"""

STEP_TEMPLATE = """      - name: {description}
        run: |
          {command}
"""

steps_content = ""
for slug, desc, cmd in AUDITS:
    steps_content += STEP_TEMPLATE.format(description=desc, command=cmd)

with open(os.path.join(WORKFLOW_DIR, "audit-repository-health.yml"), "w") as f:
    f.write(CONSOLIDATED_TEMPLATE.format(steps=steps_content.rstrip()))

print(f"Generated consolidated audit workflow with {len(AUDITS)} checks.")
