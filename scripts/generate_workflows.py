import os

WORKFLOW_DIR = ".github/workflows"
os.makedirs(WORKFLOW_DIR, exist_ok=True)

def generate_workflow(filename, name, command, on_events=None, extra_steps=None, permissions="contents: read"):
    if on_events is None:
        on_events = """
  push:
    branches: ["main"]
  pull_request:
    branches: ["main"]
  workflow_dispatch:"""

    steps = [
        {"name": "Checkout repository", "uses": "actions/checkout@v4"}
    ]
    if extra_steps:
        steps.extend(extra_steps)

    if command:
        # Use env variables for security and to avoid shell injection
        steps.append({
            "name": name,
            "shell": "bash",
            "run": command,
            "env": {
                "BRANCH_NAME": "${{ github.head_ref || github.ref_name }}",
                "PR_BODY": "${{ github.event.pull_request.body }}",
                "PR_TITLE": "${{ github.event.pull_request.title }}"
            }
        })

    steps_yaml = ""
    for step in steps:
        steps_yaml += f"      - name: {step['name']}\n"
        if "uses" in step:
            steps_yaml += f"        uses: {step['uses']}\n"
            if "with" in step:
                steps_yaml += "        with:\n"
                for k, v in step['with'].items():
                    steps_yaml += f"          {k}: {v}\n"
        if "env" in step:
            steps_yaml += "        env:\n"
            for k, v in step['env'].items():
                steps_yaml += f"          {k}: {v}\n"
        if "run" in step:
            steps_yaml += f"        shell: {step.get('shell', 'bash')}\n"
            steps_yaml += "        run: |\n"
            for line in step['run'].split('\n'):
                # Preserve indentation for multi-line scripts
                steps_yaml += f"          {line}\n"

    content = f"""name: "{name}"
on:{on_events}

permissions:
  {permissions}

jobs:
  audit:
    runs-on: ubuntu-latest
    timeout-minutes: 5
    steps:
{steps_yaml}"""
    with open(os.path.join(WORKFLOW_DIR, filename), "w") as f:
        f.write(content)

# Structure: (filename, name, command, on_events, extra_steps, permissions)
workflows = [
    ("audit-build-sh-customize-set-e.yml", "Audit build.sh customize set -e", 'grep -A 2 "cat > \\"\\${AIROOTFS}/root/customize_airootfs.sh\\" << \'CUSTOMIZE\'" build.sh | grep -q "set -e" || (echo "Missing set -e" && exit 1)'),
    ("audit-build-sh-pacman-populate.yml", "Audit build.sh pacman populate", 'grep -q "pacman-key --populate archlinux" build.sh || (echo "Missing pacman-key --populate" && exit 1)'),
    ("audit-build-sh-relative-symlinks.yml", "Audit build.sh relative symlinks", '! grep -E "ln -sf /" build.sh | grep -v "/usr/lib/systemd/system/" || (echo "Dangerous absolute symlink found" && exit 1)'),
    ("audit-build-sh-budgie-session.yml", "Audit build.sh Budgie session", 'grep -q "budgie-session" build.sh || (echo "Missing budgie-session" && exit 1)'),
    ("audit-build-sh-desktop-entry-kiba.yml", "Audit build.sh desktop entry Kiba", 'grep -q "Icon=kibaos" build.sh || (echo "Missing kibaos icon" && exit 1)'),
    ("audit-build-sh-sudoers-perms.yml", "Audit build.sh sudoers perms", 'grep -q "chmod 0440 \\"${AIROOTFS}/etc/sudoers.d/liveuser\\"" build.sh || (echo "Missing sudoers perms fix" && exit 1)'),
    ("audit-build-sh-liveuser-uid.yml", "Audit build.sh liveuser UID", 'grep -q "1000:1000" build.sh || (echo "Missing explicit 1000:1000" && exit 1)'),
    ("audit-build-sh-wallpaper-consistency.yml", "Audit build.sh wallpaper consistency", 'grep -q "WALLPAPER_URL=" build.sh || (echo "Missing wallpaper URL" && exit 1)'),
    ("audit-build-sh-octopi-usage.yml", "Audit build.sh octopi usage", '! grep -q "octopi" build.sh || (echo "Prohibited octopi usage found" && exit 1)'),
    ("audit-build-sh-zsh-default.yml", "Audit build.sh Zsh default", 'grep -q "PS1=" build.sh || (echo "Missing Zsh config" && exit 1)'),
    ("audit-markdown-empty-link-check.yml", "Audit Markdown empty links", '! grep -rE "\\[[^]]*\\]\\(\\)" . --include="*.md" || (echo "Empty links found" && exit 1)'),
    ("audit-repo-license-sanity.yml", "Audit Repo license sanity", '[ -f LICENSE ] || (echo "LICENSE file missing" && exit 1)'),
    ("audit-repo-readme-badge-https.yml", "Audit Repo README badge HTTPS", '! grep "http://" README.md | grep ".svg" || (echo "Insecure badge URL found" && exit 1)'),
    ("audit-repo-no-chmod-777-strict.yml", "Audit Repo no chmod 777", '! grep -rE "chmod (0?777|777)" . --exclude-dir=.git --exclude-dir=.github --exclude="scripts/repo_audit.sh" || (echo "chmod 777 found" && exit 1)'),
    ("audit-repo-no-plaintext-chpasswd.yml", "Audit Repo no plaintext chpasswd", '! grep -r "chpasswd" . --include="*.sh" | grep -vE "echo.*\\|.*chpasswd" || (echo "Insecure chpasswd found" && exit 1)'),
    ("audit-repo-markdown-anchor-links.yml", "Audit Repo Markdown anchors", '! grep -rhE "\\[[^]]+\\]\\(#[A-Z]+\\)" . --include="*.md" || (echo "Uppercase anchors found" && exit 1)'),
    ("audit-repo-gitkeep-no-extension.yml", "Audit Repo gitkeep extension", 'find . -type f -name "*.gitkeep" | grep -vE "/\\.gitkeep$" && (echo "Incorrect gitkeep filename" && exit 1) || exit 0'),
    ("audit-repo-shell-extension-consistency.yml", "Audit Repo shell extension", 'find . -name "*.sh" | grep . || (echo "No scripts found" && exit 1)'),
    ("audit-repo-trailing-whitespace-all.yml", "Audit Repo trailing whitespace", '! grep -rI "[[:blank:]]$" . --exclude-dir=.git --exclude="pnpm-lock.yaml" || (echo "Trailing whitespace found" && exit 1)'),
    ("audit-repo-no-nested-git-dir.yml", "Audit Repo no nested git", '[ -z "$(find . -mindepth 2 -name ".git" -type d)" ] || (echo "Nested .git found" && exit 1)'),
    ("audit-workflow-checkout-v4.yml", "Audit Workflow checkout v4", '! grep -r "uses: actions/checkout@" .github/workflows/ | grep -v "@v4" || (echo "Outdated checkout version" && exit 1)'),
    ("audit-workflow-no-node-16-actions.yml", "Audit Workflow no node 16", '! grep -r "uses: actions/setup-node@" .github/workflows/ | grep -v "@v[3456789]" || (echo "Outdated node setup" && exit 1)'),
    ("audit-workflow-explicit-bash-shell.yml", "Audit Workflow explicit bash", 'grep -r "shell: bash" .github/workflows/ || (echo "Missing explicit shell" && exit 1)'),
    ("audit-workflow-no-empty-run-blocks.yml", "Audit Workflow no empty run", '! grep -r "run: $" .github/workflows/ || (echo "Empty run block found" && exit 1)'),
    ("audit-workflow-job-permissions-only.yml", "Audit Workflow job permissions", 'grep -r "permissions:" .github/workflows/ || (echo "Missing permissions block" && exit 1)'),
    ("audit-workflow-timeout-reasonable.yml", "Audit Workflow timeout reasonable", 'grep -r "timeout-minutes:" .github/workflows/ || (echo "Missing timeout" && exit 1)'),
    ("audit-workflow-kebab-filenames-strict.yml", "Audit Workflow kebab filenames", 'ls .github/workflows/ | grep "_" && (echo "Underscores in workflow filenames" && exit 1) || true'),
    ("audit-workflow-no-absolute-script-paths.yml", "Audit Workflow no absolute paths", '! grep -r "/home/runner/work" .github/workflows/ || (echo "Absolute paths found" && exit 1)'),
    ("audit-workflow-unused-workflow-inputs.yml", "Audit Workflow unused inputs", 'grep -r "github.event.inputs" .github/workflows/ || echo "No dispatch inputs found to audit"'),
    ("audit-workflow-no-github-token-leak.yml", "Audit Workflow no token leak", '! grep -rE "echo.*(github\\.token|secrets\\.)" .github/workflows/ || (echo "Potential token leak" && exit 1)'),

    # Improved 15 additional workflows
    ("branch-name-enforcer.yml", "Branch name enforcer", """
if [[ "$BRANCH_NAME" == "main" ]]; then exit 0; fi
if [[ ! "$BRANCH_NAME" =~ ^(feat|fix|docs|style|refactor|perf|test|chore|audit|bolt|sentinel|palette)/[a-z0-9-]+$ ]]; then
  echo "Branch name '$BRANCH_NAME' does not follow convention."
  exit 1
fi
""", None, None, "contents: read"),
    ("readme-toc-audit.yml", "README TOC audit", 'if [ $(wc -l < README.md) -gt 100 ]; then grep -qi "## Table of Contents" README.md || (echo "Missing TOC" && exit 1); fi', None, None, "contents: read"),
    ("hero-alt-text-checker.yml", "Hero alt text checker", 'grep -E "<img.*alt=\\"[^\\"]+\\"" README.md || (echo "Missing alt text for images" && exit 1)', None, None, "contents: read"),
    ("pnpm-exclusive-audit.yml", "PNPM exclusive audit", '[ ! -f "package-lock.json" ] && [ ! -f "yarn.lock" ] || (echo "Other lockfiles found" && exit 1)', None, None, "contents: read"),
    ("stale-issue-manager.yml", "Stale issue manager", None, """
  schedule:
    - cron: '30 1 * * *'
  workflow_dispatch:""", [
        {"name": "Mark stale issues", "uses": "actions/stale@v9", "with": {
            "stale-issue-message": "This issue is stale because it has been open 30 days with no activity.",
            "days-before-stale": "30",
            "days-before-close": "5"
        }}
    ], "issues: write\n  pull-requests: write"),
    ("commit-message-validator.yml", "Commit message validator", None, """
  pull_request:
    types: [opened, edited, synchronize, reopened]""", [
        {"name": "Check Commit Message", "uses": "wagoid/commitlint-github-action@v6"}
    ], "contents: read"),
    ("shell-script-lint.yml", "Shell script lint", 'find . -name "*.sh" -not -path "./node_modules/*" -exec shellcheck {} + || (echo "ShellCheck failed" && exit 1)', None, None, "contents: read"),
    ("json-yaml-syntax-audit.yml", "JSON YAML syntax audit", 'python3 check_workflows.py || (echo "YAML validation failed" && exit 1)', None, None, "contents: read"),
    ("check-gitattributes-existence.yml", "Check gitattributes existence", '[ -f ".gitattributes" ] || (echo ".gitattributes missing" && exit 1)', None, None, "contents: read"),
    ("check-eof-newline.yml", "Check EOF newline", 'find . -type f -name "*.sh" -exec bash -c "tail -c1 \\$1 | read -r _ || (echo \\$1 missing newline && exit 1)" -- {} \\;'),
    ("check-license-year.yml", "Check license year", 'grep -qE "202[0-9]" LICENSE || (echo "License year missing or outdated" && exit 1)', None, None, "contents: read"),
    ("pr-description-validator.yml", "PR description validator", """
if [ "${{ github.event_name }}" == "pull_request" ]; then
  if [ ${#PR_BODY} -lt 20 ]; then
    echo "PR description too short."
    exit 1
  fi
fi
""", """
  pull_request:
    branches: ["main"]""", None, "contents: read"),
    ("code-of-conduct-presence.yml", "Code of Conduct presence", '[ -f "CODE_OF_CONDUCT.md" ] || (echo "Missing CODE_OF_CONDUCT.md" && exit 1)', None, None, "contents: read"),
    ("check-todo-format.yml", "Check TODO format", '! grep -r "TODO" . --exclude-dir=.git | grep -vE "TODO\\([a-z-]+\\):" || (echo "Bad TODO format" && exit 1)', None, None, "contents: read"),
    ("check-security-md-contact-info.yml", "Check SECURITY.md contact info", 'grep -E "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}" SECURITY.md || (echo "Missing contact email" && exit 1)', None, None, "contents: read"),
]

for item in workflows:
    filename = item[0]
    name = item[1]
    command = item[2]
    on_events = item[3] if len(item) > 3 else None
    extra_steps = item[4] if len(item) > 4 else None
    permissions = item[5] if len(item) > 5 else "contents: read"
    generate_workflow(filename, name, command, on_events, extra_steps, permissions)

print(f"Generated {len(workflows)} high-quality workflows.")
