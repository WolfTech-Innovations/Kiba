import os

WORKFLOW_DIR = ".github/workflows"
os.makedirs(WORKFLOW_DIR, exist_ok=True)

TEMPLATE = """name: "{name}"
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  workflow_dispatch:

permissions:
  contents: read

jobs:
  audit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
{setup}
      - name: "{name}"
        run: |
          {command}
"""

workflows = [
    ("Audit: Sudo No Passwd", "", "grep -r \"NOPASSWD\" . --exclude-dir=.git --exclude-dir=.github && { echo 'Error: NOPASSWD found in sudoers configuration'; exit 1; } || exit 0"),
    ("Audit: Pacman GPG SigLevel", "", "if [ -f \"pacman.conf\" ]; then grep \"SigLevel\" pacman.conf | grep -qv \"Required\" && { echo 'Error: Pacman SigLevel must be Required'; exit 1; }; fi"),
    ("Audit: Unmasked Services", "", "grep -r \"systemctl unmask\" . --exclude-dir=.git --exclude-dir=.github && { echo 'Error: Explicit unmasking of services found'; exit 1; } || exit 0"),
    ("Audit: Pacman NoExtract", "", "if [ -f \"pacman.conf\" ]; then grep -q \"NoExtract\" pacman.conf || { echo 'Error: NoExtract policy missing in pacman.conf'; exit 1; }; fi"),
    ("Audit: Hardcoded URLs", "", "grep -rE \"http://[a-zA-Z0-9.-]+\" build.sh && { echo 'Error: Unencrypted HTTP URLs found in build.sh'; exit 1; } || exit 0"),
    ("Audit: Shadow File Check", "", "! find . -name \"shadow\" -path \"*/etc/*\" | grep ."),
    ("Audit: Large Binaries", "", "! find . -type f -size +10M -not -path \"*/.git/*\" | grep ."),
    ("Audit: License Headers", "", "MISSING=$(grep -L \"License\" *.sh ota/*.sh scripts/*.sh || true); if [ -n \"$MISSING\" ]; then echo \"Missing license in: $MISSING\"; exit 1; fi"),
    ("Audit: Curl Pipe Bash", "", "grep -r \"curl.*|.*bash\" . --exclude-dir=.git --exclude-dir=.github && { echo 'Error: Dangerous curl | bash pattern found'; exit 1; } || exit 0"),
    ("Audit: Systemd Syntax", "      - name: Install systemd\n        run: sudo apt-get update && sudo apt-get install -y systemd", "find . -name \"*.service\" -exec systemd-analyze verify {} +"),
    ("Audit: Chmod 777", "", "grep -r \"chmod 777\" . --exclude-dir=.git --exclude-dir=.github --exclude=\"repo_audit.sh\" --exclude=\"generate_45_workflows.py\" && { echo 'Error: chmod 777 is forbidden'; exit 1; } || exit 0"),
    ("Audit: Calamares QSS", "", "find . -name \"*.qss\" -exec grep -q \"background\" {} + || { echo 'Error: Calamares QSS files must define background properties'; exit 1; }"),
    ("Audit: HTML Security", "", "grep -r \"target=\\\"_blank\\\"\" . --include=\"*.html\" | grep -v \"rel=\\\"noopener\\\"\" && { echo 'Error: External links missing rel=\"noopener\"'; exit 1; } || exit 0"),
    ("Audit: Pacman Cache Cleanup", "", "grep -q \"pacman -Scc\" build.sh || { echo 'Error: build.sh must include pacman -Scc for image size optimization'; exit 1; }"),
    ("Audit: Dev Packages", "", "grep -E \"-devel|-git\" build.sh && { echo 'Error: Development packages found in production build list'; exit 1; } || exit 0"),
    ("Audit: GRUB Config", "", "grep -r \"GRUB_TIMEOUT\" . || { echo 'Error: GRUB_TIMEOUT configuration missing'; exit 1; }"),
    ("Audit: Bashisms", "      - name: Install devscripts\n        run: sudo apt-get update && sudo apt-get install -y devscripts", "checkbashisms scripts/*.sh ota/*.sh"),
    ("Audit: Branding Assets", "", "test -f branding/logo.png && test -f branding/wallpaper.jpg"),
    ("Audit: Duplicate Packages", "", "DUPS=$(grep \"pacman -S\" build.sh | sort | uniq -d); if [ -n \"$DUPS\" ]; then echo \"Duplicate packages found: $DUPS\"; exit 1; fi"),
    ("Audit: Hostname Hardcoded", "", "! grep -r \"hostname\" airootfs/etc/hostname 2>/dev/null"),
    ("Audit: SSH Keys", "", "! find . -name \"id_rsa*\" -o -name \"id_ed25519*\" | grep ."),
    ("Audit: Shell Completions", "", "grep -q \"bash-completion\" build.sh || { echo 'Error: bash-completion package missing'; exit 1; }"),
    ("Audit: X11 Leftovers", "", "! find . -name \"xorg.conf*\" | grep ."),
    ("Audit: Fstab Logic", "", "grep -q \"genfstab\" build.sh || { echo 'Error: genfstab usage missing in build process'; exit 1; }"),
    ("Audit: Tmp Files", "", "! find . -name \"*.tmp\" -o -name \"*.swp\" | grep ."),
    ("Audit: Locale Settings", "", "grep -q \"LOCALE\" build.sh || { echo 'Error: LOCALE configuration missing in build.sh'; exit 1; }"),
    ("Audit: Root Password", "", "grep \"root:\" build.sh | grep -q \"password\" && { echo 'Error: Root password should not be set in build.sh'; exit 1; } || exit 0"),
    ("Audit: DM Config", "", "find . -name \"lightdm.conf\" -o -name \"gdm.conf\" | grep . || { echo 'Error: Display Manager configuration missing'; exit 1; }"),
    ("Audit: Wayland Sessions", "", "find . -path \"*/usr/share/wayland-sessions/*.desktop\" | grep . || { echo 'Error: No Wayland session files found'; exit 1; }"),
    ("Audit: Budgie Schemas", "", "find . -name \"*.gschema.override\" | grep -q \"budgie\" || { echo 'Error: Budgie gschema overrides missing'; exit 1; }"),
    ("Audit: Deprecated Arch Packages", "", "grep -E \"net-tools|wireless_tools\" build.sh && { echo 'Error: Deprecated Arch packages (net-tools/wireless_tools) found'; exit 1; } || exit 0"),
    ("Audit: AUR Helper", "", "grep -E \"yay|paru\" build.sh || { echo 'Error: No AUR helper (yay/paru) detected in build.sh'; exit 1; }"),
    ("Audit: Pip Usage", "", "grep -r \"pip install\" . --exclude-dir=.git --exclude-dir=.github && { echo 'Error: Use pacman instead of pip for system-wide packages'; exit 1; } || exit 0"),
    ("Audit: Node Cleanup", "", "! find . -name \"node_modules\" -type d -not -path \"./node_modules\" | grep ."),
    ("Audit: Broken Symlinks", "", "! find . -xtype l | grep ."),
    ("Audit: Fonts Standard", "", "grep -E \"ttf-inter|ttf-jetbrains-mono\" build.sh || { echo 'Error: Standard KibaOS fonts missing in build.sh'; exit 1; }"),
    ("Audit: Icons Standard", "", "grep -q \"kora-icon-theme\" build.sh || { echo 'Error: Kora icon theme missing in build.sh'; exit 1; }"),
    ("Audit: Cursor Standard", "", "grep -q \"vimix-cursor-theme\" build.sh || { echo 'Error: Vimix cursor theme missing in build.sh'; exit 1; }"),
    ("Audit: Desktop Files", "      - name: Install desktop-file-utils\n        run: sudo apt-get update && sudo apt-get install -y desktop-file-utils", "find . -name \"*.desktop\" -exec desktop-file-validate {} +"),
    ("Audit: Polkit Syntax", "", "find . -name \"*.rules\" -path \"*/polkit-1/*\" | grep . || { echo 'Error: Polkit rules missing'; exit 1; }"),
    ("Audit: CUPS Defaults", "", "grep -q \"cups\" build.sh || { echo 'Error: CUPS printing support missing in build.sh'; exit 1; }"),
    ("Audit: NM Config", "", "find . -name \"NetworkManager.conf\" | grep . || { echo 'Error: NetworkManager configuration missing'; exit 1; }"),
    ("Audit: Audio Stack", "", "grep -q \"pipewire\" build.sh || { echo 'Error: Pipewire audio stack missing in build.sh'; exit 1; }"),
    ("Audit: Initcpio Hooks", "", "find . -name \"mkinitcpio.conf\" | grep . || { echo 'Error: mkinitcpio configuration missing'; exit 1; }"),
    ("Audit: Mirrorlist Optimization", "", "grep -q \"reflector\" build.sh || { echo 'Error: Reflector missing for mirrorlist optimization'; exit 1; }"),
]

for name, setup, command in workflows:
    filename = name.lower().replace(": ", "-").replace(" ", "-") + ".yml"
    filepath = os.path.join(WORKFLOW_DIR, filename)
    content = TEMPLATE.format(name=name, setup=setup, command=command)
    with open(filepath, "w") as f:
        f.write(content)
    print(f"Generated {filepath}")
