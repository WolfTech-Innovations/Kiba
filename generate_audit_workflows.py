import os

workflows_to_add = [
    "audit-build-sh-customize-set-e.yml",
    "audit-build-sh-pacman-populate.yml",
    "audit-build-sh-relative-symlinks.yml",
    "audit-build-sh-paperde-ldconfig.yml",
    "audit-build-sh-desktop-entry-kiba.yml",
    "audit-build-sh-sudoers-perms.yml",
    "audit-build-sh-liveuser-uid.yml",
    "audit-build-sh-wallpaper-consistency.yml",
    "audit-build-sh-octopi-usage.yml",
    "audit-build-sh-zsh-default.yml",
    "audit-markdown-empty-link-check.yml",
    "audit-repo-license-sanity.yml",
    "audit-repo-readme-badge-https.yml",
    "audit-repo-no-chmod-777-strict.yml",
    "audit-repo-no-plaintext-chpasswd.yml",
    "audit-repo-markdown-anchor-links.yml",
    "audit-repo-gitkeep-no-extension.yml",
    "audit-repo-shell-extension-consistency.yml",
    "audit-repo-trailing-whitespace-all.yml",
    "audit-repo-no-nested-git-dir.yml",
    "audit-workflow-checkout-v4.yml",
    "audit-workflow-no-node-16-actions.yml",
    "audit-workflow-explicit-bash-shell.yml",
    "audit-workflow-no-empty-run-blocks.yml",
    "audit-workflow-job-permissions-only.yml",
    "audit-workflow-timeout-reasonable.yml",
    "audit-workflow-kebab-filenames-strict.yml",
    "audit-workflow-no-absolute-script-paths.yml",
    "audit-workflow-unused-workflow-inputs.yml",
    "audit-workflow-no-github-token-leak.yml",
]

def generate_workflow(filename):
    name = filename.replace("audit-", "Audit ").replace(".yml", "").replace("-", " ").title()

    # Mapping audit logic
    logic = ""
    if filename == "audit-build-sh-customize-set-e.yml":
        logic = 'grep -A 2 "cat > \\"\\${AIROOTFS}/root/customize_airootfs.sh\\"" build.sh | grep -q "set -e"'
    elif filename == "audit-build-sh-pacman-populate.yml":
        logic = 'grep -q "pacman-key --populate archlinux" build.sh'
    elif filename == "audit-build-sh-relative-symlinks.yml":
        logic = '! grep -E "ln -s /" build.sh'
    elif filename == "audit-build-sh-paperde-ldconfig.yml":
        logic = 'if grep -q "ninja -C paperde-src/build install" build.sh; then grep -A 20 "ninja -C paperde-src/build install" build.sh | grep -q "ldconfig"; else echo "PaperDE not found, skipping"; fi'
    elif filename == "audit-build-sh-desktop-entry-kiba.yml":
        logic = 'grep -q "Icon=kibaos" build.sh'
    elif filename == "audit-build-sh-sudoers-perms.yml":
        logic = 'grep -q "chmod 0440" build.sh'
    elif filename == "audit-build-sh-liveuser-uid.yml":
        logic = 'if grep -q "liveuser" build.sh; then grep -q "1000:1000" build.sh; else echo "liveuser not found"; fi'
    elif filename == "audit-build-sh-wallpaper-consistency.yml":
        logic = 'grep -q "WALLPAPER_DEST" build.sh && grep -q "WALLPAPER_URL" build.sh'
    elif filename == "audit-build-sh-octopi-usage.yml":
        logic = '! grep -qi "octopi" build.sh'
    elif filename == "audit-build-sh-zsh-default.yml":
        logic = '! grep -q "SHELL=/usr/bin/zsh" build.sh' # Ensure Zsh is not default
    elif filename == "audit-markdown-empty-link-check.yml":
        logic = '! grep -rE "\\[[^\\]]*\\]\\(\\)" . --include="*.md" | grep -v "node_modules"'
    elif filename == "audit-repo-license-sanity.yml":
        logic = '[ -f LICENSE ] && grep -q "Copyright" LICENSE'
    elif filename == "audit-repo-readme-badge-https.yml":
        logic = '! grep "http://" README.md | grep "img.shields.io"'
    elif filename == "audit-repo-no-chmod-777-strict.yml":
        logic = '! grep -rE "chmod (0?777|777)" . --exclude-dir=.git'
    elif filename == "audit-repo-no-plaintext-chpasswd.yml":
        logic = '! grep -r "chpasswd" . --exclude="build.sh" --exclude-dir=.git'
    elif filename == "audit-repo-markdown-anchor-links.yml":
        logic = '! grep -rhE "\\[[^\\]]+\\]\\(#[^)]+\\)" . --include="*.md" | grep -vE "\\(#[a-z0-9-]+\\)"'
    elif filename == "audit-repo-gitkeep-no-extension.yml":
        logic = '! find . -name ".gitkeep.*"'
    elif filename == "audit-repo-shell-extension-consistency.yml":
        logic = '! find scripts -name "*.shell"'
    elif filename == "audit-repo-trailing-whitespace-all.yml":
        logic = '! grep -rI "[[:blank:]]$" . --exclude-dir=.git --exclude="pnpm-lock.yaml" --exclude="*.png" --exclude="*.jpg"'
    elif filename == "audit-repo-no-nested-git-dir.yml":
        logic = '[ -z "$(find . -mindepth 2 -name ".git" -type d)" ]'
    elif filename == "audit-workflow-checkout-v4.yml":
        logic = '! grep -r "uses: actions/checkout@" .github/workflows/ | grep -vE "@v4|@[a-f0-9]{40}"'
    elif filename == "audit-workflow-no-node-16-actions.yml":
        logic = '! grep -r "node16" .github/workflows/'
    elif filename == "audit-workflow-explicit-bash-shell.yml":
        logic = '! grep -B 1 "run:" .github/workflows/*.yml | grep -v "shell: bash" | grep -vE "run: |---|^--" | grep -v "uses:"'
    elif filename == "audit-workflow-no-empty-run-blocks.yml":
        logic = '! grep -r "run: \'\'" .github/workflows/'
    elif filename == "audit-workflow-job-permissions-only.yml":
        logic = '! grep -r "permissions: write-all" .github/workflows/'
    elif filename == "audit-workflow-timeout-reasonable.yml":
        logic = '! grep -r "timeout-minutes:" .github/workflows/ | grep -vE " [1-9][0-9]?$"'
    elif filename == "audit-workflow-kebab-filenames-strict.yml":
        logic = '! ls .github/workflows/ | grep "_"'
    elif filename == "audit-workflow-no-absolute-script-paths.yml":
        logic = '! grep -r "/home/runner/work" .github/workflows/'
    elif filename == "audit-workflow-unused-workflow-inputs.yml":
        logic = 'for f in .github/workflows/*.yml; do inputs=$(grep -A 20 "inputs:" "$f" | grep -E "^  [a-zA-Z0-9_-]+:" | awk -F: \'{print $1}\' | tr -d " "); for i in $inputs; do if ! grep -q "github.event.inputs.$i" "$f"; then echo "Unused input $i in $f"; exit 1; fi; done; done'
    elif filename == "audit-workflow-no-github-token-leak.yml":
        logic = '! grep -rE "echo.*(github\\.token|secrets\\.)" .github/workflows/'

    content = f"""name: "{name}"
on:
  push:
    branches: [ "main" ]
  pull_request:
    branches: [ "main" ]
  workflow_dispatch:

jobs:
  audit:
    runs-on: ubuntu-latest
    timeout-minutes: 10
    permissions:
      contents: read
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Run audit
        shell: bash
        run: |
          {logic}
"""
    with open(f".github/workflows/{filename}", "w") as f:
        f.write(content)

if __name__ == "__main__":
    if not os.path.exists(".github/workflows"):
        os.makedirs(".github/workflows")
    for workflow in workflows_to_add:
        generate_workflow(workflow)
    print(f"Generated {len(workflows_to_add)} workflows.")
