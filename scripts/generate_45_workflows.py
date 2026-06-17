import os

def generate_workflows():
    workflow_dir = ".github/workflows"
    os.makedirs(workflow_dir, exist_ok=True)

    # Standard header for all workflows
    def get_template(name, description, command, uses=None):
        steps = [
            {"name": "Checkout code", "uses": "actions/checkout@v4"}
        ]
        if uses:
            steps.extend(uses)
        steps.append({"name": description, "run": command})

        yaml_content = f"name: {name}\non:\n  push:\n    branches: [ main ]\n  pull_request:\n    branches: [ main ]\n  workflow_dispatch:\n\njobs:\n  audit:\n    runs-on: ubuntu-latest\n    steps:\n"
        for step in steps:
            yaml_content += f"      - name: {step['name']}\n"
            if "uses" in step:
                yaml_content += f"        uses: {step['uses']}\n"
                if "with" in step:
                    yaml_content += "        with:\n"
                    for k, v in step["with"].items():
                        yaml_content += f"          {k}: {v}\n"
            if "run" in step:
                yaml_content += "        run: |\n"
                for line in step["run"].split('\n'):
                    yaml_content += f"          {line}\n"
        return yaml_content

    pnpm_setup = [
        {"name": "Install Node.js", "uses": "actions/setup-node@v4", "with": {"node-version": "20"}},
        {"name": "Install pnpm", "uses": "pnpm/action-setup@v4", "with": {"version": "9"}}
    ]

    workflows = [
        ("audit-budgie-migration", "Verify no legacy KDE/Cutefish references", "! grep -riE 'kde|cutefish|plasma' . --exclude-dir=.git --exclude=build.sh --exclude=WORKFLOWS.md --exclude=README.md --exclude=WIKI.md"),
        ("audit-gnome-modernity", "Ensure modern GNOME apps are used", "! grep -E 'gedit|eog' build.sh"),
        ("audit-calamares-security", "Verify Calamares HTTPS internetCheckUrl", "grep -q 'internetCheckUrl: https://' build.sh"),
        ("audit-branding-fonts", "Check for Inter and JetBrains Mono fonts", "grep -q 'inter-font' build.sh && grep -q 'ttf-jetbrains-mono' build.sh"),
        ("audit-branding-icons", "Check for Kora icon and Vimix cursor themes", "grep -q 'kora-icon-theme' build.sh && grep -q 'vimix-cursor-theme' build.sh"),
        ("audit-pacman-parallel", "Ensure ParallelDownloads is optimized", "grep -q 'ParallelDownloads = 10' build.sh"),
        ("audit-alpm-user-creation", "Verify alpm user pre-creation logic", "grep -q 'grep -q \"^alpm:\"' build.sh"),
        ("audit-polkit-gnome-path", "Verify polkit-gnome authentication agent path", "grep -q '/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1' build.sh"),
        ("audit-gvfs-optimization", "Ensure gvfs-goa is used and gvfs-google is absent", "grep -q 'gvfs-goa' build.sh && ! grep -q 'gvfs-google' build.sh"),
        ("audit-cursor-theme-source", "Verify vimix-cursors-git AUR package", "grep -q 'vimix-cursors-git' build.sh"),
        ("audit-mesa-utils-check", "Ensure mesa-utils is used over eglinfo", "grep -q 'mesa-utils' build.sh && ! grep -q 'eglinfo' build.sh"),
        ("audit-html-security", "Verify target=\"_blank\" implies rel=\"noopener noreferrer\"", "grep -r 'target=\"_blank\"' . --include=\"*.html\" | grep -v 'rel=\"noopener noreferrer\"' && exit 1 || exit 0"),
        ("audit-html-aria-labels", "Verify external links have descriptive aria-labels", "grep -r 'target=\"_blank\"' . --include=\"*.html\" | grep -vE 'aria-label=.*opens in a new tab' && exit 1 || exit 0"),
        ("audit-html-tabindex-hygiene", "Ensure no tabindex=\"0\" on static cards", "! grep -r 'tabindex=\"0\"' . --include=\"*.html\""),
        ("audit-palette-consistency", "Verify KibaOS primary blue #0099cc accent color", "grep -r '#0099cc' . --include=\"build.sh\" --include=\"*.html\""),
        ("audit-first-login-gsettings", "Verify first-login font gsettings (Inter)", "grep -q \"gsettings set org.gnome.desktop.interface font-name 'Inter'\" build.sh"),
        ("audit-jules-case-sensitivity", "Ensure .Jules directory is case-correct", "[ -d .Jules ] && ! [ -d .jules ]"),
        ("audit-python-c-extensions", "Check for CSafeLoader in Python scripts", "grep -r 'CSafeLoader' . --include=\"*.py\""),
        ("audit-shell-builtins", "Verify use of shell parameter expansion in release notes script", "grep -q '\\${' scripts/save_release_notes.sh"),
        ("audit-chmod-security", "Check for dangerous chmod 777", "! grep -rE \"chmod (0?777|777)\" . --exclude-dir=.git --exclude=\"repo_audit.sh\" --exclude=\"audit-*.yml\" --exclude=\"scripts/generate_45_workflows.py\""),
        ("audit-gitkeep-emptiness", "Ensure .gitkeep files are empty", "[ -z \"$(find . -name '.gitkeep' -type f -size +0)\" ]"),
        ("audit-nested-git-check", "Check for nested .git directories", "[ -z \"$(find . -mindepth 2 -name '.git' -type d)\" ]"),
        ("audit-trailing-whitespace", "Check for trailing whitespace globally", "! grep -rI \"[[:blank:]]$\" . --exclude-dir=.git --exclude=\"pnpm-lock.yaml\""),
        ("audit-checkout-v4", "Ensure actions/checkout@v4 is used in all workflows", "! grep -r \"uses: actions/checkout@\" .github/workflows/ | grep -vE \"@v4|@[a-f0-9]{40}\""),
        ("audit-secret-leaks", "Check for accidental GitHub Token/Secret leaks via echo", "! grep -rE \"echo.*(github\\.token|secrets\\.)\" .github/workflows/"),
        ("audit-markdown-kebab-anchors", "Verify Markdown internal anchors follow lowercase-kebab", "! grep -rhE \"\\[[^]]+\\]\\(#[^)]+\\)\" . --include=\"*.md\" | grep -vE \"\\(#[a-z0-9-]+\\)\""),
        ("audit-markdown-dead-links", "Check for empty Markdown link targets", "! grep -rE \"\\[[^]]*\\]\\(\\)\" . --include=\"*.md\""),
        ("audit-markdown-alt-text-quality", "Check for generic placeholder alt text", "! grep -rEi \"alt=\\\"(image|screenshot)\\\"\" . --include=\"*.md\""),
        ("audit-sentinel-journal-format", "Verify sentinel.md format compliance", "grep -q '## [0-9]\\{4\\}-[0-9]\\{2\\}-[0-9]\\{2\\} - ' .Jules/sentinel.md"),
        ("audit-bolt-journal-format", "Verify bolt.md format compliance", "grep -q '## [0-9]\\{4\\}-[0-9]\\{2\\}-[0-9]\\{2\\} - ' .Jules/bolt.md"),
        ("audit-palette-journal-format", "Verify palette.md format compliance", "grep -q '## [0-9]\\{4\\}-[0-9]\\{2\\}-[0-9]\\{2\\} - ' .Jules/palette.md"),
        ("audit-build-script-integrity", "Check for set -e in embedded customize_airootfs.sh", "grep -A 2 \"cat > \\\"\\${AIROOTFS}/root/customize_airootfs.sh\\\"\" build.sh | grep -q \"set -e\""),
        ("audit-calamares-branding-name", "Verify Calamares product name in build.sh", "grep -q 'productName:.*KibaOS' build.sh"),
        ("audit-plymouth-set-default", "Verify Plymouth theme activation", "grep -q 'plymouth-set-default-theme kibaos' build.sh"),
        ("audit-sddm-wayland-config", "Verify SDDM Wayland and labwc compositor config", "grep -q 'DisplayServer=wayland' build.sh && grep -q 'CompositorCommand=labwc' build.sh"),
        ("audit-labwc-corner-radius", "Ensure Labwc theme uses rounded corners (14px)", "grep -q '<cornerRadius>14</cornerRadius>' build.sh"),
        ("audit-zram-half-ram", "Verify zram-generator size configuration", "grep -q 'zram-size = ram / 2' build.sh"),
        ("audit-ota-signature-check", "Verify GPG signature verification in OTA script", "grep -q 'gpg .* --verify' build.sh"),
        ("audit-gtk-theme-config", "Verify ChromeOS-Dark as system-wide default", "grep -q 'gtk-theme-name = \"ChromeOS-Dark\"' build.sh"),
        ("audit-welcome-subtext-contrast", "Verify welcome.html sub-text color contrast", "grep -q '#4a5a70' build.sh"),
        ("audit-pacman-needed-flag", "Ensure --needed flag is used for pacman installations", "grep -q 'pacman -S .* --needed' build.sh"),
        ("audit-shell-bash-n", "Verify shell script syntax using bash -n", "find . -name \"*.sh\" -exec bash -n {} +"),
        ("audit-json-syntax", "Verify JSON syntax using jsonlint", "pnpm exec jsonlint -q package.json", pnpm_setup),
        ("audit-prettier-check", "Run Prettier formatting check", "pnpm exec prettier --check .", pnpm_setup),
        ("audit-repo-files-existence", "Verify existence of core repository files", "[ -f LICENSE ] && [ -f README.md ] && [ -f SECURITY.md ] && [ -f CONTRIBUTING.md ] && [ -f ACKNOWLEDGMENTS.md ]")
    ]

    for filename, description, command, *extra in workflows:
        uses = extra[0] if extra else None
        workflow_content = get_template(filename.replace("-", " ").title(), description, command, uses)
        with open(os.path.join(workflow_dir, f"{filename}.yml"), "w") as f:
            f.write(workflow_content)

    print(f"Generated {len(workflows)} high-quality workflows.")

if __name__ == "__main__":
    generate_workflows()
