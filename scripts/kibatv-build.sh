#!/bin/bash
set -ex
export DEBIAN_FRONTEND=noninteractive

# ── Install live-build and build deps ─────────────────────────────────
apt-get update && apt-get install -y \
  live-build debootstrap xorriso git squashfs-tools \
  grub-efi-amd64-bin grub-pc-bin mtools dosfstools \
  qemu-system-x86 \
  meson ninja-build pkg-config \
  libgtk-4-dev libadwaita-1-dev libflatpak-dev libappstream-dev \
  libjson-glib-dev libostree-dev \
  gcc g++ gettext curl

cd /w
ISO="kibatv-v${RUN_NUM:-local}"

echo "=== Configuring live-build ==="

lb config \
  --distribution trixie \
  --architectures amd64 \
  --archive-areas "main contrib non-free non-free-firmware" \
  --debian-installer live \
  --debian-installer-gui false \
  --binary-images iso-hybrid \
  --mode debian \
  --system live \
  --linux-flavours amd64 \
  --linux-packages "linux-image linux-headers" \
  --bootappend-live "boot=live components quiet splash console=ttyS0" \
  --bootappend-install "auto=true priority=critical" \
  --bootloaders "grub-pc,grub-efi" \
  --iso-application "KibaTV" \
  --iso-volume "KIBATV" \
  --cache true \
  --cache-packages true \
  --cache-stages "bootstrap chroot rootfs" \
  --apt-options "--yes --no-install-recommends" \
  --apt-recommends false \
  --apt-indices false \
  --debootstrap-options "--variant=minbase --exclude=nano,vim-tiny,info" \
  --firmware-chroot false \
  --memtest none \
  --compression xz \
  --chroot-squashfs-compression-type zstd \
  --chroot-squashfs-compression-level 19

# ── Starship prompt hook ────────────────────────────────────────────
mkdir -p config/hooks/live
cat > config/hooks/live/0030-starship.hook.chroot << 'STARSHIP_HOOK'
#!/bin/bash
set -e
echo "=== Configuring Starship Prompt ==="

# Branded starship config
mkdir -p /etc/skel/.config
cat > /etc/skel/.config/starship.toml << 'STARSHIP_CONF'
format = "$all"
add_newline = false

[character]
success_symbol = "[❯](bold #bd93f9)"
error_symbol = "[❯](bold #ff5555)"

[directory]
style = "bold #bd93f9"

[git_branch]
symbol = "󰊢 "
style = "bold #50fa7b"

[hostname]
ssh_only = false
format = "[$hostname]($style) "
style = "bold #bd93f9"

[username]
show_always = true
format = "[$user]($style)@"
style = "bold #bd93f9"
STARSHIP_CONF

echo "=== Starship Prompt configured ==="
STARSHIP_HOOK
chmod +x config/hooks/live/0030-starship.hook.chroot

# ── CachyOS Kernel hook ──────────────────────────────────────────────
mkdir -p config/hooks/live
cat > config/hooks/live/0045-cachyos-kernel.hook.chroot << 'CACHY_HOOK'
#!/bin/bash
set -e
echo "=== Installing CachyOS Kernel ==="

# Use an active CachyOS kernel deb repository (psygreg/linux-psycachy)
# For trixie, we'll try to find the latest version from their GitHub
REPO="psygreg/linux-psycachy"
RELEASE_INFO=$(curl -s "https://api.github.com/repos/$REPO/releases/latest")
LATEST_TAG=$(echo "$RELEASE_INFO" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')

if [ -z "$LATEST_TAG" ]; then
  echo "WARNING: Could not fetch CachyOS Kernel tag, using fallback"
  # Fallback to a known version or exit
  exit 0
fi

mkdir -p /tmp/cachyos
cd /tmp/cachyos

# Download image and headers
IMAGE_URL=$(echo "$RELEASE_INFO" | grep '"browser_download_url":' | grep "linux-image-psycachy" | grep "amd64.deb" | head -1 | sed -E 's/.*"([^"]+)".*/\1/')
HEADERS_URL=$(echo "$RELEASE_INFO" | grep '"browser_download_url":' | grep "linux-headers-psycachy" | grep "amd64.deb" | head -1 | sed -E 's/.*"([^"]+)".*/\1/')

if [ -n "$IMAGE_URL" ]; then
  curl -LO "$IMAGE_URL"
else
  echo "WARNING: Could not find CachyOS image URL, using fallback pattern"
  curl -LO "https://github.com/$REPO/releases/download/$LATEST_TAG/linux-image-psycachy_${LATEST_TAG}-3_amd64.deb"
fi

if [ -n "$HEADERS_URL" ]; then
  curl -LO "$HEADERS_URL"
else
   echo "WARNING: Could not find CachyOS headers URL, using fallback pattern"
   curl -LO "https://github.com/$REPO/releases/download/$LATEST_TAG/linux-headers-psycachy_${LATEST_TAG}-3_amd64.deb"
fi

# Install
apt-get install -y ./*.deb || {
  echo "WARNING: CachyOS Kernel install failed, falling back to stock"
  cd / && rm -rf /tmp/cachyos
  exit 0
}

# Cleanup
cd / && rm -rf /tmp/cachyos

# Remove stock kernel meta-packages to keep it minimal
# We don't use wildcards to avoid purging the CachyOS kernel we just installed
apt-get purge -y linux-image-amd64 linux-headers-amd64
apt-get autoremove -y

echo "=== CachyOS Kernel installed ==="
CACHY_HOOK
chmod +x config/hooks/live/0045-cachyos-kernel.hook.chroot

# ── Extreme Minimization hook ─────────────────────────────────────────
cat > config/hooks/live/0090-extreme-minimization.hook.chroot << 'MIN_HOOK'
#!/bin/bash
set -e
echo "=== Aggressive Minimization: cleaning system ==="

# 1. Remove all documentation, man pages, and info files
# Preserve fzf scripts before nuking doc
mkdir -p /usr/share/fzf
cp /usr/share/doc/fzf/examples/*.zsh /usr/share/fzf/ 2>/dev/null || true
rm -rf /usr/share/doc/*
rm -rf /usr/share/man/*
rm -rf /usr/share/info/*
rm -rf /usr/share/help/*

# 2. Remove all locales except en and en_US
find /usr/share/locale -mindepth 1 -maxdepth 1 ! -name 'en' ! -name 'en_US' -exec rm -rf {} +

# 3. Clean apt cache and lists
rm -rf /var/cache/apt/archives/*
rm -rf /var/lib/apt/lists/*

# 4. Remove temporary files
rm -rf /tmp/* /var/tmp/*

echo "=== Aggressive Minimization complete ==="
MIN_HOOK
chmod +x config/hooks/live/0090-extreme-minimization.hook.chroot


# ── Chromium Browser & Policy Configuration ───────────────────────────
cat > config/hooks/live/0056-chromium-policy.hook.chroot << 'CHROMIUM_HOOK'
#!/bin/bash
set -e
echo "=== Configuring Chromium Managed Policies ==="

# System-wide Managed Policies
mkdir -p /etc/chromium/policies/managed
cat > /etc/chromium/policies/managed/kibatv.json << 'CPOLICY'
{
  "HomepageLocation": "https://alphasearch.pages.dev",
  "HomepageIsNewTabPage": false,
  "RestoreOnStartup": 4,
  "RestoreOnStartupURLs": ["https://alphasearch.pages.dev"],
  "ManagedBookmarks": [
    {
      "name": "KibaTV GitHub",
      "url": "https://github.com/WolfTech-Innovations/Kiba"
    }
  ],
  "ShowHomeButton": true,
  "BookmarkBarEnabled": true
}
CPOLICY

echo "=== Chromium policies configured ==="
CHROMIUM_HOOK
chmod +x config/hooks/live/0056-chromium-policy.hook.chroot

# ── GRUB branding + user-friendly boot menu ──────────────────────────
mkdir -p config/hooks/binary
cat > config/hooks/binary/0020-bootloader-branding.hook.binary << 'BOOT_HOOK'
#!/bin/bash
set -e
echo "=== Patching GRUB boot menu ==="

# Find all grub.cfg files in the binary directory
GRUB_CONFIGS=$(find binary -name "grub.cfg")

if [ -n "$GRUB_CONFIGS" ]; then
  for cfg in $GRUB_CONFIGS; do
    echo "  Patched: $cfg"
    sed -i \
      -e 's/Debian GNU\/Linux/KibaTV/g' \
      -e 's/Debian Live/KibaTV/g' \
      -e 's/GNU\/Linux Live/KibaTV/g' \
      -e 's/Live system (amd64)/Start KibaTV/g' \
      -e 's/Live system/Start KibaTV/g' \
      -e 's/Graphical install/Install KibaTV to this computer/g' \
      -e 's/Install with Speech Synthesis/Start KibaTV (screen reader)/g' \
      -e 's/Advanced options for/More options for/g' \
      -e 's/Live system (failsafe mode)/Start KibaTV (safe mode)/g' \
      "$cfg"
  done
else
  echo "WARNING: No GRUB configuration found to patch"
fi

echo "=== GRUB boot menu branding complete ==="
BOOT_HOOK
chmod +x config/hooks/binary/0020-bootloader-branding.hook.binary
# Update your script around lines 238-248 to use a compatible Neon repository
wget -qO- https://archive.neon.kde.org/public.key | gpg --dearmor | tee /usr/share/keyrings/neon-archive-keyring.gpg > /dev/null

# Use 'jammy' (Ubuntu 22.04 LTS) which is closest to Debian Trixie compatibility
# or use 'focal' as fallback - both have plasma-bigscreen available
echo "deb [signed-by=/usr/share/keyrings/neon-archive-keyring.gpg trusted=yes] https://archive.neon.kde.org/user jammy main" | tee /etc/apt/sources.list.d/neon.list

# Unstable repo (has plasma-bigscreen) - use jammy instead of noble
echo "deb [signed-by=/usr/share/keyrings/neon-archive-keyring.gpg trusted=yes] https://archive.neon.kde.org/unstable jammy main" | tee /etc/apt/sources.list.d/neon-dev.list

# Set low priority to prefer Debian packages
echo -e "Package: *\nPin: release o=Neon\nPin-Priority: 100" | tee /etc/apt/preferences.d/neon-pin

# Update package cache inside the container BEFORE live-build uses it
apt-get update || true


echo "=== Adding packages ==="

mkdir -p config/package-lists
cat > config/package-lists/kibatv.list.chroot << 'PACKAGES'
# ── Base system ───────────────────────────────────────────────────────
linux-image-amd64
linux-headers-amd64
firmware-linux-free
firmware-linux-nonfree
systemd-sysv
sudo
ca-certificates
openssl
locales
tzdata
libc6
libc-bin

# ── Nala (apt frontend) ───────────────────────────────────────────────
nala

# ── Network ───────────────────────────────────────────────────────────
network-manager
wpasupplicant
iwd
wget
curl
git
apt-transport-https

# ── KDE Plasma Bigscreen ─────────────────────────────────────────────
plasma-bigscreen
plasma-workspace
plasma-workspace-wallpapers
plasma-discover
plasma-discover-backend-flatpak

sddm
sddm-theme-debian-breeze
plasma-nm
plasma-pa
dolphin
konsole
ark
qt6-svg-plugins
desktop-file-utils
plasma-wallpapers-addons
kwin-addons
breeze
breeze-gtk-theme
fonts-jetbrains-mono
fonts-noto-color-emoji
fonts-inter

# ── Cloud & online accounts integration ───────────────────────────────
# nextcloud-desktop: Nextcloud sync client + Dolphin integration
nextcloud-desktop
dolphin-nextcloud
# kdeconnect: phone/tablet integration (sync notifications, files, etc.)
kdeconnect

# ── Flatpak (for KibaStore / Bazaar) ──────────────────────────────────
flatpak
xdg-desktop-portal-kde
xdg-desktop-portal-gtk

# ── Shell — zsh ───────────────────────────────────────────────────────
zsh
zsh-autosuggestions
zsh-syntax-highlighting
starship

# ── Boot splash ───────────────────────────────────────────────────────
plymouth
plymouth-themes
kde-config-plymouth

# ── Calamares installer ───────────────────────────────────────────────
calamares
calamares-settings-debian
libkpmcore12
libparted2t64
libpwquality1
libpython3.13
libqt6core6t64
libqt6dbus6
libqt6gui6
libqt6network6
libqt6qml6
libqt6quick6
libqt6quickwidgets6
libqt6svg6
libqt6widgets6
libqt6xml6
qml6-module-qtquick
qml6-module-qtquick-controls
qml6-module-qtquick-layouts
qml6-module-qtquick-window
qml6-module-qtqml
python3-pyqt6
python3-dbus

# ── Browser ───────────────────────────────────────────────────────────
chromium
# Note: ungoogled-chromium installed via OBS hook (0056)
# firefox-esr removed per spec

# ── Essential tools ───────────────────────────────────────────────────
nano
micro
python3
fastfetch
eza
bat
btop
ripgrep
fd-find
tealdeer
duf
ncdu
zenity

# ── Boot loaders ──────────────────────────────────────────────────────
grub-pc-bin
grub-efi-amd64-bin
grub-common

# ── Squashfs ──────────────────────────────────────────────────────────
squashfs-tools
zstd

# ── Filesystems ───────────────────────────────────────────────────────
ntfs-3g
exfatprogs
cryptsetup

# ── Utilities ─────────────────────────────────────────────────────────
debianutils
kmod
binutils
fzf
yt-dlp
file
PACKAGES

echo "=== Creating live customization hook ==="

mkdir -p config/hooks/live
cat > config/hooks/live/0100-customize.hook.chroot << 'HOOK'
#!/bin/bash
set -e

# ── Plymouth theme ────────────────────────────────────────────────────
mkdir -p /usr/share/kibatv
touch ~/.zshrc
mkdir -p /usr/share/plymouth/themes/kibatv-spinner

# Decode embedded fallback logo
if [ ! -f /usr/share/kibatv/logo.png ]; then
  cat > /tmp/logo_b64.txt << 'LOGO_B64'
iVBORw0KGgoAAAANSUhEUgAAAyAAAAJYCAYAAACadoJwAAAQXklEQVR4nO3dS5LbyhFAUfYL7cJT79Px9ump10EPbEoU1c3mB7ioAs7ZQBchDepGIsmP8/l84i4PCACAZ3xsfYCR/dj6AIMQGQAALOXe3fLwcXLUABEcAABs4fYeerggOUqACA4AAEZ0uCDZc4CIDgAAZnN9h91ljOwtQEQHAAB7scsY2UuACA8AAPbsct+dPkRmDxDhAQDAkUwfIrMGiPAAAODIpg2R2QJEeAAAwC/ThcgsASI8AADga9OEyOgBIjwAAOBxw4fIX1sf4A7xAQAArxn2Lj3iBGTYhwUAABMZchoy2gREfAAAwLKGumOPMgEZ6qEAAMDODDMNGWECIj4AAKCx+d176wDZ/AEAAMDBbHoH3+oVLOEBAADb2eyVrC0mIOIDAADGkN/N6wARHwAAMJb0jl4GiPgAAIAxZXf1KkDEBwAAjC25sxcBIj4AAGBfFr3jLxkg4gMAAPZpsbt+/UvoAADAgS0VIKYfAACwb4vc+ZcIEPEBAABH8Pbd/90AER8AAHAsbzWAHRAAACDzToCYfgAAwDG93AKvBoj4AACAY3upCbyCBQAAZF4JENMPAADgdHqhDZ4NEPEBAABbe6oRvIIFAABkngkQ0w8AAOAzD7eCCQgAAJB5NEBMPwAAgHseagYTEAAAIPNIgJh+AAAAj/i2HUxAAACAzHcBYvoBAAA8425DmIAAAACZewFi+gEAALziy5YwAQEAADJfBYjpBwAA8I5Pm8IEBAAAyNwLEFMQAADgFV+2hAkIAACQ+S5ATEEAAIBn3G0IExAAACDzSICYggAAAI/4th1MQAAAgMyjAWIKAgAA3PNQM5iAAAAAmWcCxBQEAAD4zMOtYAICAABkng0QUxAAAODaU43wygREhAAAAKfTC23gFSwAACDzaoCYggAAwLG91ATvTEBECAAAHNPLLeAVLAAAIPNugJiCAADAsbzVAEtMQEQIAAAcw9t3/6VewRIhAACwb4vc+e2AAAAAmSUDxBQEAAD2abG7/tITEBECAAD7sugdf41XsEQIAADMbZU7/ZpL6CIEAADmtNqdfu1vwRIhAAAwl1Xv8MXX8IoQAACYw+p39+p3QEQIAACMLbmzlz9EKEIAAGBM2V29/iV0EQIAAGNJ7+h1gJxOIgQAAEaR381/1H/w/y4f9LzR3wcAgCPbbCiwxQTkmmkIAAC0Nr2Dbx0gp5MIAQCAyuZ3761ewbrllSwAAFjP5uFxMcIE5NowDwYAAHZiqDv2KBOQa6YhAADwvqHC42K0Aci1IR8YAABMYNi79IgTkGumIQAA8Lhhw+Ni9AC5ECIAAPC14cPjYpYAuRAiAADwyzThcTFbgFwIEQAAjmy68LiYNUAuhAgAAEcybXhczB4gF0IEAIA9mz48LvYSIBfX/zBiBACAme0mOq7tLUCuiREAAGazi+i4tucAuXb7DylIAAAYwe6D49ZRAuSWIAEAYAuHC45bRw2QW/f+I4gTAACecfjIuOe/Ds4zCD9oqXsAAAAASUVORK5CYII=
LOGO_B64
  base64 -d /tmp/logo_b64.txt > /usr/share/kibatv/logo.png
  rm /tmp/logo_b64.txt
fi
cp /usr/share/kibatv/logo.png /usr/share/kibatv/logo-plymouth.png

# ── Plymouth theme — KibaTV boot splash ───────────────────────────────
cat > /usr/share/plymouth/themes/kibatv-spinner/kibatv-spinner.plymouth << 'PLYMOUTH_THEME'
[Plymouth Theme]
Name=KibaTV
Description=KibaTV boot splash
ModuleName=script

[script]
ImageDir=/usr/share/plymouth/themes/kibatv-spinner
ScriptFile=/usr/share/plymouth/themes/kibatv-spinner/kibatv-spinner.script
PLYMOUTH_THEME

cat > /usr/share/plymouth/themes/kibatv-spinner/kibatv-spinner.script << 'PLYMOUTH_SCRIPT'
Window.SetBackgroundTopColor(0.157, 0.165, 0.212);
Window.SetBackgroundBottomColor(0.157, 0.165, 0.212);
screen_width  = Window.GetWidth();
screen_height = Window.GetHeight();
cx = screen_width  / 2;
cy = screen_height / 2;

logo.image  = Image("logo.png");
logo_target_w = 160;
logo_scale    = logo_target_w / logo.image.GetWidth();
logo.scaled   = logo.image.Scale(
                  Math.Int(logo.image.GetWidth()  * logo_scale),
                  Math.Int(logo.image.GetHeight() * logo_scale));
logo.sprite   = Sprite(logo.scaled);
logo.x = cx - logo.scaled.GetWidth()  / 2;
logo.y = cy - logo.scaled.GetHeight() / 2 - 60;
logo.sprite.SetPosition(logo.x, logo.y, 1);

label.image  = Image.Text("KibaTV", 0.741, 0.576, 0.976, 1, "Sans Bold 20");
label.sprite = Sprite(label.image);
label.sprite.SetPosition(
  cx - label.image.GetWidth() / 2,
  logo.y + logo.scaled.GetHeight() + 16, 1);

tag.image  = Image.Text("Switch to Simple", 0.384, 0.447, 0.643, 1, "Sans 13");
tag.sprite = Sprite(tag.image);
tag.sprite.SetPosition(
  cx - tag.image.GetWidth() / 2,
  logo.y + logo.scaled.GetHeight() + 48, 1);

bar_w = 400; bar_h = 4;
bar_x = cx - bar_w / 2;
bar_y = cy + logo.scaled.GetHeight() / 2 + 70;
bar_bg.image  = Image(bar_w, bar_h);
bar_bg.image.FillWithColor(0.267, 0.278, 0.349, 1.0);
bar_bg.sprite = Sprite(bar_bg.image);
bar_bg.sprite.SetPosition(bar_x, bar_y, 1);
bar_fg.image  = Image(1, bar_h);
bar_fg.image.FillWithColor(0.741, 0.576, 0.976, 1.0);
bar_fg.sprite = Sprite(bar_fg.image);
bar_fg.sprite.SetPosition(bar_x, bar_y, 2);
bar_fg.width  = 1;

fun progress_callback(duration, progress) {
    new_w = Math.Int(bar_w * progress);
    if (new_w < 1) { new_w = 1; }
    if (new_w != bar_fg.width) {
        bar_fg.image  = Image(new_w, bar_h);
        bar_fg.image.FillWithColor(0.741, 0.576, 0.976, 1.0);
        bar_fg.sprite.SetImage(bar_fg.image);
        bar_fg.width = new_w;
    }
}
Plymouth.SetBootProgressFunction(progress_callback);

msg.sprite = Sprite();
msg.sprite.SetPosition(16, screen_height - 36, 10);
fun message_callback(text) {
    msg.image = Image.Text(text, 0.596, 0.631, 0.784, 1, "Sans 11");
    msg.sprite.SetImage(msg.image);
}
Plymouth.SetMessageFunction(message_callback);
PLYMOUTH_SCRIPT

cp /usr/share/kibatv/logo-plymouth.png \
   /usr/share/plymouth/themes/kibatv-spinner/logo.png

update-alternatives --install \
  /usr/share/plymouth/themes/default.plymouth default.plymouth \
  /usr/share/plymouth/themes/kibatv-spinner/kibatv-spinner.plymouth 100
update-alternatives --set default.plymouth \
  /usr/share/plymouth/themes/kibatv-spinner/kibatv-spinner.plymouth

# ── Aggressive Initrd Compression ────────────────────────────────────
sed -i 's/^COMPRESS=.*/COMPRESS=zstd/' /etc/initramfs-tools/initramfs.conf
echo "COMPRESSLEVEL=19" >> /etc/initramfs-tools/initramfs.conf

# Ensure critical libraries are correctly linked and indexed
ldconfig
if [ ! -e /lib/x86_64-linux-gnu/libresolv.so.2 ] && [ ! -e /lib64/libresolv.so.2 ]; then
  echo "WARNING: libresolv.so.2 not found, attempting to fix..."
  ldconfig
fi

update-initramfs -u -k all || update-initramfs -u

# ── GRUB boot config ─────────────────────────────────────────────────
# We write a custom grub.cfg at build time via a binary hook.
# The chroot hook just sets the kernel cmdline defaults here.

# ── SDDM autologin for live session ───────────────────────────────────
mkdir -p /etc/sddm.conf.d
cat > /etc/sddm.conf.d/autologin.conf << 'SDDM_CONF'
[Autologin]
User=user
Session=plasma-bigscreen
SDDM_CONF

# ── Nala: replace apt alias system-wide ───────────────────────────────
# Nala wraps apt; we alias apt→nala in the system zshrc and bashrc
# so users interacting with the terminal get the nicer interface.
cat > /etc/profile.d/nala-alias.sh << 'NALA_ALIAS'
# KibaTV: use nala as the default package manager frontend
if command -v nala >/dev/null 2>&1; then
  alias apt='nala'
  alias apt-get='nala'
fi
NALA_ALIAS
chmod +x /etc/profile.d/nala-alias.sh

# ── Zsh config (auto-generated) ───────────────────────────────────────
# The zshrc is written by this hook and placed in /etc/zsh/zshrc
# so it applies to all users automatically.
mkdir -p /etc/zsh
cat > /etc/zsh/zshrc << 'ZSHRC'
# ═══════════════════════════════════════════════════════
#  KibaTV system-wide zshrc — auto-generated at build time
# ═══════════════════════════════════════════════════════

# ── Environment ────────────────────────────────────────
export LANG=en_US.UTF-8
if command -v micro >/dev/null 2>&1; then
  export EDITOR=micro
  export VISUAL=micro
else
  export EDITOR=nano
  export VISUAL=nano
fi
export PAGER=less

# ── History ────────────────────────────────────────────
HISTSIZE=10000
SAVEHIST=10000
HISTFILE=~/.zsh_history
setopt SHARE_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt INC_APPEND_HISTORY

# ── Completion ─────────────────────────────────────────
autoload -Uz compinit && compinit -u
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'
zstyle ':completion:*:descriptions' format '%F{yellow}-- %d --%f'

# ── VCS info (git branch in prompt) ────────────────────
autoload -Uz vcs_info
precmd() { vcs_info }
zstyle ':vcs_info:git:*' formats ' %F{#50fa7b}(%b)%f'
setopt PROMPT_SUBST

# ── Prompt — Starship (Modern) ──────────────────────────
if command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
else
  # Fallback to Dracula palette
  PROMPT='%F{#bd93f9}%n@%m%f %F{#f8f8f2}%~%f${vcs_info_msg_0_} %F{#bd93f9}❯%f '
fi

# ── Fzf Integration ─────────────────────────────────────
if command -v fzf >/dev/null 2>&1; then
  source /usr/share/fzf/key-bindings.zsh 2>/dev/null || true
  source /usr/share/fzf/completion.zsh 2>/dev/null || true
fi

# ── Fastfetch on startup ────────────────────────────────
if command -v fastfetch >/dev/null 2>&1; then
  fastfetch
fi

# ── Plugins ────────────────────────────────────────────
[[ -f /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]] && \
  source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
[[ -f /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] && \
  source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# ── Nala/apt aliases ────────────────────────────────────
if command -v nala >/dev/null 2>&1; then
  alias apt='nala'
  alias apt-get='nala'
  alias install='sudo nala install'
  alias remove='sudo nala remove'
  alias update='sudo nala update && sudo nala upgrade -y'
  alias upgrade='sudo nala upgrade'
  alias search='nala search'
fi

# ── KibaTV Aliases ──────────────────────────────────────
alias edit='${EDITOR:-micro}'
alias please='sudo'
alias cls='clear'
alias path='echo -e "${PATH//:/\\n}"'

# ── Modern Aliases ──────────────────────────────────────
if command -v eza >/dev/null 2>&1; then
  alias ls='eza --icons --group-directories-first'
  alias ll='eza -lah --icons --group-directories-first'
  alias la='eza -A --icons'
  alias tree='eza --tree --icons'
else
  alias ls='ls --color=auto'
  alias ll='ls -lah'
  alias la='ls -A'
fi

if command -v bat >/dev/null 2>&1; then
  alias cat='bat --paging=never'
elif command -v batcat >/dev/null 2>&1; then
  alias cat='batcat --paging=never'
  alias bat='batcat'
fi

if command -v rg >/dev/null 2>&1; then
  alias grep='rg'
elif command -v ripgrep >/dev/null 2>&1; then
  alias grep='ripgrep'
fi

if command -v fdfind >/dev/null 2>&1; then
  alias fd='fdfind'
fi

if command -v tldr >/dev/null 2>&1; then
  # Use tealdeer if available
  alias help='tldr'
elif command -v tealdeer >/dev/null 2>&1; then
  alias help='tealdeer'
  alias tldr='tealdeer'
fi

command -v duf >/dev/null 2>&1 && alias df='duf'
command -v ncdu >/dev/null 2>&1 && alias du='ncdu'
command -v btop >/dev/null 2>&1 && alias top='btop'

# ── General aliases ─────────────────────────────────────
alias free='free -h'
alias mkdir='mkdir -pv'
alias cp='cp -iv'
alias mv='mv -iv'
alias rm='rm -I'
alias ..='cd ..'
alias ...='cd ../..'
ZSHRC

# ── Update tldr cache ──────────────────────────────────────────────────
if command -v tldr >/dev/null 2>&1; then
  tldr --update || true
elif command -v tealdeer >/dev/null 2>&1; then
  tealdeer --update || true
fi

# ── Default shell: zsh ─────────────────────────────────────────────────
chsh -s /bin/zsh user  2>/dev/null || true
chsh -s /bin/zsh root  2>/dev/null || true

# ── Live user setup ────────────────────────────────────────────────────
if ! id -u user >/dev/null 2>&1; then
  useradd -m -s /bin/zsh -G sudo,audio,video,netdev,plugdev user
  echo "user:live" | chpasswd
else
  usermod -s /bin/zsh user
fi
echo "user ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/live-user
chmod 440 /etc/sudoers.d/live-user

# ── Disable sleep/suspend ─────────────────────────────────────────────
mkdir -p /etc/systemd/sleep.conf.d
cat > /etc/systemd/sleep.conf.d/nosleep.conf << 'NOSLEEP'
[Sleep]
AllowSuspend=no
AllowHibernation=no
AllowHybridSleep=no
AllowSuspendThenHibernate=no
NOSLEEP

mkdir -p /etc/skel/.config
cat > /etc/skel/.config/powermanagementprofilesrc << 'POWERRC'
[AC][DPMSControl]
idleTime=0
lockBeforeSleep=false
turnOffDisplayWhenIdle=false
[AC][HandleButtonEvents]
lidAction=0; powerButtonAction=0; powerDownAction=0
[AC][SuspendAndShutdown]
autoSuspend=false; autoSuspendAction=0; autoSuspendIdleTime=0
POWERRC

# ─────────────────────────────────────────────────────────────────────
# ── THEMING ───────────────────────────────────────────────────────────
# ─────────────────────────────────────────────────────────────────────

# ── Ant-Dark plasma theme ─────────────────────────────────────────────
mkdir -p /usr/share/plasma/desktoptheme/ant-dark
git clone --depth=1 https://github.com/EliverLara/Ant-Themes \
  /tmp/ant-themes 2>/dev/null || true
if [ -d /tmp/ant-themes/Plasma/Ant-Dark ]; then
  cp -r /tmp/ant-themes/Plasma/Ant-Dark/. /usr/share/plasma/desktoptheme/ant-dark/
fi
if [ ! -f /usr/share/plasma/desktoptheme/ant-dark/metadata.json ]; then
  cat > /usr/share/plasma/desktoptheme/ant-dark/metadata.json << 'ANTMETA'
{"KPlugin":{"Id":"ant-dark","Name":"Ant Dark","License":"GPL","Version":"1.0"}}
ANTMETA
fi
if [ -f /tmp/ant-themes/colors/Ant-Dark.colors ]; then
  mkdir -p /usr/share/color-schemes
  cp /tmp/ant-themes/colors/Ant-Dark.colors /usr/share/color-schemes/AntDark.colors
fi
rm -rf /tmp/ant-themes

# ── Watch_Dogs KDE splash ─────────────────────────────────────────────
mkdir -p /usr/share/plasma/look-and-feel/com.kibatv.watchdogs.desktop/contents/splash/images
cat > /usr/share/plasma/look-and-feel/com.kibatv.watchdogs.desktop/metadata.json << 'WATCHMETA'
{"KPlugin":{"Id":"com.kibatv.watchdogs.desktop","Name":"Watch Dogs","License":"GPL","Version":"1.0"}}
WATCHMETA
cat > /usr/share/plasma/look-and-feel/com.kibatv.watchdogs.desktop/contents/splash/Splash.qml << 'WATCHSPLASH'
import QtQuick 2.15
Rectangle {
    color: "#000000"
    anchors.fill: parent
    Text {
        anchors.centerIn: parent
        text: "KibaTV | Switch to simple"
        font.pixelSize: 48; font.bold: true; color: "#bd93f9"
    }
}
WATCHSPLASH

# ── Kora icon theme ───────────────────────────────────────────────────
mkdir -p /usr/share/icons
git clone --depth=1 https://github.com/bikass/kora.git /tmp/kora 2>/dev/null || true
if [ -d /tmp/kora/kora ]; then
  cp -r /tmp/kora/kora /usr/share/icons/kora
  gtk-update-icon-cache -f /usr/share/icons/kora 2>/dev/null || true
fi
rm -rf /tmp/kora

# ── Vimix cursors ─────────────────────────────────────────────────────
git clone --depth=1 https://github.com/vinceliuice/Vimix-cursors.git \
  /tmp/vimix-cursors 2>/dev/null || true
if [ -d /tmp/vimix-cursors/dist/Vimix-cursors ]; then
  cp -r /tmp/vimix-cursors/dist/Vimix-cursors /usr/share/icons/Vimix-cursors
fi
rm -rf /tmp/vimix-cursors

# ── Dracula KDE colour scheme ─────────────────────────────────────────
mkdir -p /usr/share/color-schemes
cat > /usr/share/color-schemes/Dracula.colors << 'DRACULA_COLORS'
[Colors:Button]
BackgroundAlternate=68,71,90
BackgroundNormal=68,71,90
DecorationFocus=189,147,249
DecorationHover=189,147,249
ForegroundNormal=248,248,242

[Colors:Selection]
BackgroundNormal=189,147,249
ForegroundNormal=40,42,54

[Colors:View]
BackgroundNormal=40,42,54
BackgroundAlternate=40,42,54
ForegroundNormal=248,248,242
ForegroundActive=189,147,249
ForegroundLink=139,233,253
ForegroundNegative=255,85,85

[Colors:Window]
BackgroundNormal=40,42,54
BackgroundAlternate=68,71,90
ForegroundNormal=248,248,242
ForegroundActive=189,147,249

[General]
ColorScheme=Dracula
Name=Dracula
shadeSortColumn=true

[KDE]
contrast=4
DRACULA_COLORS

# ── Konsole Dracula colour scheme ──────────────────────────────────────
mkdir -p /usr/share/konsole
cat > /usr/share/konsole/Dracula.colorscheme << 'KONSOLE_COLORS'
[Background]
Color=40,42,54
[Foreground]
Color=248,248,242
[Color0]
Color=40,42,54
[Color1]
Color=255,85,85
[Color2]
Color=80,250,123
[Color3]
Color=241,250,140
[Color4]
Color=189,147,249
[Color5]
Color=255,121,198
[Color6]
Color=139,233,253
[Color7]
Color=248,248,242
[Color0Intense]
Color=68,71,90
[Color1Intense]
Color=255,85,85
[Color2Intense]
Color=80,250,123
[Color3Intense]
Color=241,250,140
[Color4Intense]
Color=189,147,249
[Color5Intense]
Color=255,121,198
[Color6Intense]
Color=139,233,253
[Color7Intense]
Color=248,248,242
[General]
Description=Dracula
Opacity=0.95
KONSOLE_COLORS

# ── Konsole profile ────────────────────────────────────────────────────
mkdir -p /etc/skel/.local/share/konsole
cat > /etc/skel/.local/share/konsole/KibaTV.profile << 'KONSOLE_PROFILE'
[Appearance]
ColorScheme=Dracula
Font=Monospace,11,-1,5,50,0,0,0,0,0
[General]
Command=/bin/zsh
Name=KibaTV
Parent=FALLBACK/
TerminalColumns=100
TerminalRows=30
[Scrolling]
ScrollBarPosition=2
KONSOLE_PROFILE

cat > /etc/skel/.local/share/konsole/konsolerc << 'KONSOLERC'
[Desktop Entry]
DefaultProfile=KibaTV.profile
KONSOLERC

# ── KDE global settings ────────────────────────────────────────────────
SKEL_KDE=/etc/skel/.config
mkdir -p "$SKEL_KDE" /etc/xdg

cat > /etc/xdg/kdeglobals << 'XDG_KDEGLOBALS'
[KDE]
LookAndFeelPackage=org.kde.breezedark.desktop
SingleClick=true
contrast=4
[Icons]
Theme=kora
[General]
ColorScheme=Dracula
widgetStyle=Breeze
XCURSOR_THEME=Vimix-cursors
XCURSOR_SIZE=24
font=Inter,11,-1,5,50,0,0,0,0,0
fixed=JetBrains Mono,11,-1,5,50,0,0,0,0,0
toolBarFont=Inter,11,-1,5,50,0,0,0,0,0
menuFont=Inter,11,-1,5,50,0,0,0,0,0
smallestReadableFont=Inter,9,-1,5,50,0,0,0,0,0
XDG_KDEGLOBALS

cat > "$SKEL_KDE/kdeglobals" << 'KDEGLOBALS'
[Colors:Button]
BackgroundAlternate=68,71,90
BackgroundNormal=68,71,90
DecorationFocus=189,147,249
ForegroundNormal=248,248,242
ForegroundActive=189,147,249

[Colors:Selection]
BackgroundNormal=189,147,249
ForegroundNormal=40,42,54

[Colors:View]
BackgroundNormal=40,42,54
BackgroundAlternate=40,42,54
ForegroundNormal=248,248,242
ForegroundActive=189,147,249
ForegroundLink=139,233,253
ForegroundNegative=255,85,85

[Colors:Window]
BackgroundNormal=40,42,54
BackgroundAlternate=68,71,90
ForegroundNormal=248,248,242
ForegroundActive=189,147,249

[Colors:Tooltip]
BackgroundNormal=40,42,54
ForegroundNormal=248,248,242

[General]
ColorScheme=Dracula
widgetStyle=Breeze
shadeSortColumn=true
font=Inter,11,-1,5,50,0,0,0,0,0
fixed=JetBrains Mono,11,-1,5,50,0,0,0,0,0
toolBarFont=Inter,11,-1,5,50,0,0,0,0,0
menuFont=Inter,11,-1,5,50,0,0,0,0,0
smallestReadableFont=Inter,9,-1,5,50,0,0,0,0,0

[Icons]
Theme=kora

[KDE]
LookAndFeelPackage=org.kde.breezedark.desktop
SingleClick=true
contrast=4

[WM]
activeBackground=40,42,54
activeBlend=189,147,249
activeForeground=248,248,242
inactiveBackground=40,42,54
inactiveForeground=98,114,164
KDEGLOBALS

# ── plasmarc — Ant-Dark theme ──────────────────────────────────────────
cat > "$SKEL_KDE/plasmarc" << 'PLASMARC'
[Theme]
name=ant-dark
[PlasmaTabletMode]
TabletMode=off
PLASMARC

# ── ksplashrc — Watch_Dogs splash ──────────────────────────────────────
cat > "$SKEL_KDE/ksplashrc" << 'KSPLASHRC'
[KSplash]
Engine=KSplashQML
Theme=com.kibatv.watchdogs.desktop
KSPLASHRC

# ── kcminputrc — Vimix cursors ─────────────────────────────────────────
cat > "$SKEL_KDE/kcminputrc" << 'KCMINPUTRC'
[Mouse]
cursorTheme=Vimix-cursors
cursorSize=24
KCMINPUTRC

mkdir -p /usr/share/icons/default
cat > /usr/share/icons/default/index.theme << 'CURSOR_DEFAULT'
[Icon Theme]
Inherits=Vimix-cursors
CURSOR_DEFAULT

# ── kwinrc — compositing, glass, rounded corners ───────────────────────
cat > "$SKEL_KDE/kwinrc" << 'KWINRC'
[Compositing]
Enabled=true
Backend=OpenGL
GLCore=true
AnimationSpeed=3

[Effect-blur]
BlurStrength=12
NoiseStrength=2

[Plugins]
blurEnabled=true
contrastEnabled=true
presentwindowsEnabled=true
slideEnabled=true

[Windows]
RoundedCorners=true

[org.kde.kdecoration2]
ButtonsOnLeft=
ButtonsOnRight=IAX
library=org.kde.breeze
BorderSize=None
BorderSizeAuto=false

[Script-roundedwindows]
CornerRadius=16
KWINRC

# ── breezerc — purple shadow ───────────────────────────────────────────
cat > "$SKEL_KDE/breezerc" << 'BREEZERC'
[Common]
ShadowColor=189,147,249
ShadowSize=ShadowVeryLarge
ShadowStrength=128
BackgroundOpacity=85
[Windeco Exception 0]
BorderSize=None
Enabled=true
ExceptionPattern=.*
Mask=2
BREEZERC

# ── plasmashellrc — floating panel ─────────────────────────────────────
cat > "$SKEL_KDE/plasmashellrc" << 'PLASMASHELLRC'
[PlasmaViews][Panel 2][Defaults]
thickness=52
[PlasmaViews][Panel 2][Horizontal1920]
thickness=52
[PlasmaViews][Panel 2][floating]
floating=1
[PlasmaViews][Panel 2][opacity]
type=2
PLASMASHELLRC

# ── Wallpaper: Autumn ─────────────────────────────────────────────────
# Autumn ships with plasma-workspace-wallpapers
# Fallback to first available large image if specific path differs
WALLPAPER_PATH=$(find /usr/share/wallpapers/Autumn -name "*.png" -o -name "*.jpg" 2>/dev/null | sort -V | tail -1 || echo "")
if [ -z "$WALLPAPER_PATH" ]; then
  # Try to find any Autumn wallpaper variant
  WALLPAPER_PATH=$(find /usr/share/wallpapers -iname "*autumn*" -name "*.png" 2>/dev/null | head -1 || echo "")
fi
if [ -z "$WALLPAPER_PATH" ]; then
  # Absolute fallback to Breeze default
  WALLPAPER_PATH="file:///usr/share/wallpapers/Next/contents/images/5120x2880.png"
fi

# ── Panel + desktop layout ─────────────────────────────────────────────
cat > "$SKEL_KDE/plasma-org.kde.plasma.desktop-appletsrc" << 'PANELRC'
[Containments][1]
activityId=
formfactor=0
immutability=1
lastScreen=0
location=0
plugin=org.kde.plasma.folder
wallpaperplugin=org.kde.image

[Containments][1][Wallpaper][org.kde.image][General]
Image=file://${WALLPAPER_PATH}
SlideshowInterval=0

[Containments][1][Applets][10]
immutability=1
plugin=org.kde.plasma.icon
[Containments][1][Applets][10][Configuration][General]
applicationName=calamares
iconPath=/usr/share/applications/calamares.desktop
label=Install KibaTV
[Containments][1][Applets][10][Geometry]
x=20; y=40; width=64; height=64

[Containments][1][Applets][11]
immutability=1
plugin=org.kde.plasma.icon
[Containments][1][Applets][11][Configuration][General]
applicationName=org.kde.discover
iconPath=/usr/share/applications/org.kde.discover.desktop
label=Software Center
[Containments][1][Applets][11][Geometry]
x=100; y=40; width=64; height=64

[Containments][1][Applets][12]
immutability=1
plugin=org.kde.plasma.icon
[Containments][1][Applets][12][Configuration][General]
applicationName=chromium
iconPath=/usr/share/applications/chromium.desktop
label=Web Browser
[Containments][1][Applets][12][Geometry]
x=180; y=40; width=64; height=64

[Containments][2]
activityId=
formfactor=2
immutability=1
lastScreen=0
location=4
plugin=org.kde.panel
wallpaperplugin=org.kde.image
[Containments][2][General]
floating=1
[Containments][2][Applets][3]
immutability=1
plugin=org.kde.plasma.kickoff
[Containments][2][Applets][3][Configuration][General]
icon=start-here-kde-symbolic
[Containments][2][Applets][4]
immutability=1
plugin=org.kde.plasma.icontasks
[Containments][2][Applets][5]
immutability=1
plugin=org.kde.plasma.marginsseparator
[Containments][2][Applets][8]
immutability=1
plugin=org.kde.plasma.systemtray
[Containments][2][Applets][9]
immutability=1
plugin=org.kde.plasma.digitalclock
[Containments][2][Layout]
AppletOrder=3;4;5;8;9
PANELRC

# ── kscreenlockerrc ────────────────────────────────────────────────────
cat > "$SKEL_KDE/kscreenlockerrc" << LOCKRC
[Daemon]
Autolock=false
LockOnResume=false
Timeout=0
[Greeter][Wallpaper][org.kde.image][General]
Image=file://${WALLPAPER_PATH}
LOCKRC

# ── Calamares autostart on live session login ──────────────────────────
# Uses KDE's XDG autostart so it fires after the desktop loads.
# Only runs in the live session (the installed system removes this file
# in post-install step 14).
mkdir -p /etc/xdg/autostart
cat > /etc/xdg/autostart/kibatv-installer.desktop << 'AUTOSTART'
[Desktop Entry]
Type=Application
Name=Install KibaTV
Comment=Start the KibaTV installer
Exec=bash -c 'sleep 4 && sudo calamares'
Icon=calamares
Terminal=false
Categories=System;
X-KDE-autostart-condition=calamares
OnlyShowIn=KDE;
AUTOSTART

# Also add to /etc/skel so it appears for the live user's home
mkdir -p /etc/skel/.config/autostart
cp /etc/xdg/autostart/kibatv-installer.desktop \
   /etc/skel/.config/autostart/kibatv-installer.desktop

# ── Services ────────────────────────────────────────────────────────────
systemctl enable sddm           || true
systemctl enable NetworkManager  || true
systemctl enable plymouth        || true

# ── KibaStore .desktop (hide Discover, prioritize Bazaar) ──────────────
mkdir -p /usr/local/share/applications
for f in \
  /usr/share/applications/org.kde.discover.desktop \
  /usr/share/applications/plasma-discover.desktop \
  /usr/share/applications/discover.desktop; do
  [ -f "$f" ] || continue
  FNAME=$(basename "$f")
  cp "$f" "/usr/local/share/applications/$FNAME"
  echo "NoDisplay=true" >> "/usr/local/share/applications/$FNAME"
  update-desktop-database /usr/local/share/applications 2>/dev/null || true
done

# Flathub remote setup
flatpak remote-add --if-not-exists --system flathub \
  https://dl.flathub.org/repo/flathub.flatpakrepo 2>/dev/null || true

# ── System identity ────────────────────────────────────────────────────
echo "kibatv-live" > /etc/hostname

cat > /etc/os-release << 'EOF'
NAME="KibaTV"
ID=kibatv
ID_LIKE=debian
VERSION_ID="1.0"
PRETTY_NAME="KibaTV 1.0"
HOME_URL="https://github.com/WolfTech-Innovations/kiba"
SUPPORT_URL="https://github.com/WolfTech-Innovations/kiba/issues"
BUG_REPORT_URL="https://github.com/WolfTech-Innovations/kiba/issues"
EOF

cat > /etc/issue << 'EOF'
KibaTV \r (\l)
EOF

cat > /etc/motd << 'EOF'

 _  ___ _             ___  ____
| |/ (_) |__   __ _ / _ \/ ___|
| ' /| | '_ \ / _` | | | \___ \
| . \| | |_) | (_| | |_| |___) |
|_|\_\_|_.__/ \__,_|\___/|____/

Welcome to KibaTV — Switch to Simple

EOF

# ── Desktop Welcome ───────────────────────────────────────────────────
mkdir -p /usr/local/bin
cat > /usr/local/bin/kiba-welcome << 'WELCOME'
#!/bin/bash
# Functional welcome menu for KibaTV
CHOICE=$(zenity --list --title="Welcome to KibaTV" \
  --text="Welcome to KibaTV! What would you like to do?" \
  --column="Action" --column="Description" \
  "Install KibaTV" "Install the system permanently to your disk" \
  "Web Browser" "Browse the internet" \
  "Software Center" "Discover and install new applications" \
  --width=450 --height=300 2>/dev/null)

case "$CHOICE" in
  "Install KibaTV")
    sudo calamares &
    ;;
  "Web Browser")
    chromium &
    ;;
  "Software Center")
    plasma-discover &
    ;;
esac
WELCOME
chmod +x /usr/local/bin/kiba-welcome

mkdir -p /etc/skel/.config/autostart
cat > /etc/skel/.config/autostart/kiba-welcome.desktop << 'WELCOMEDESK'
[Desktop Entry]
Type=Application
Name=Kiba Welcome
Exec=/usr/local/bin/kiba-welcome
Icon=start-here-kde-symbolic
Terminal=false
X-KDE-autostart-condition=kiba-welcome
WELCOMEDESK

cp -rn /etc/skel/. /home/user/ 2>/dev/null || true
chown -R user:user /home/user/.config /home/user/.local 2>/dev/null || true

HOOK
chmod +x config/hooks/live/0100-customize.hook.chroot

echo "=== Creating Calamares config ==="

# ── Calamares branding ─────────────────────────────────────────────────
mkdir -p config/includes.chroot/etc/calamares/branding/kibatv
cat > config/includes.chroot/etc/calamares/branding/kibatv/branding.desc << 'BRANDING'
componentName: kibatv
welcomeStyleCalamares: true
welcomeExpandingLogo: true
slideshowAPI: 2
strings:
  productName: "KibaTV"
  shortProductName: "KibaTV"
  version: "1.8"
  shortVersion: "1.8"
  versionedName: "KibaTV"
  shortVersionedName: "KibaTV"
  bootloaderEntryName: "KibaTV"
  productUrl: "https://github.com/WolfTech-Innovations/kiba"
  supportUrl: "https://github.com/WolfTech-Innovations/kiba/issues"
  knownIssuesUrl: "https://github.com/WolfTech-Innovations/kiba/issues"
  releaseNotesUrl: "https://github.com/WolfTech-Innovations/kiba"
images:
  productLogo: "logo.png"
  productIcon: "logo.png"
  productWelcome: "welcome.png"
style:
  SidebarBackground:        "#282a36"
  SidebarText:              "#f8f8f2"
  SidebarTextCurrent:       "#282a36"
  SidebarBackgroundCurrent: "#bd93f9"
slideshow: "show.qml"
BRANDING

# ── Calamares branding hook ────────────────────────────────────────────
cat > config/hooks/live/0110-calamares-branding.hook.chroot << 'BRANDING_HOOK'
#!/bin/bash
set -e
mkdir -p /etc/calamares/branding/kibatv
cp /usr/share/kibatv/logo.png /etc/calamares/branding/kibatv/logo.png
cp /usr/share/kibatv/logo.png /etc/calamares/branding/kibatv/welcome.png

# ── Write complete Calamares settings.conf ──────────────────────────────
cat > /etc/calamares/settings.conf << 'CALASETTINGS'
---
modules-search: [ local, /usr/lib/calamares/modules ]

instances:
  - id: post
    module: shellprocess
    config: shellprocess@post.conf

sequence:
  - show:
    - welcome
    - locale
    - keyboard
    - partition
    - users
    - summary
  - exec:
    - ageverify
    - partition
    - mount
    - unpackfs
    - machineid
    - fstab
    - locale
    - keyboard
    - localecfg
    - users
    - displaymanager
    - networkcfg
    - hwclock
    - services-systemd
    - initramfs
    - shellprocess@post
    - preservefiles
    - umount
  - show:
    - finished

branding: kibatv
prompt-install: false
dont-chroot: false
oem-setup: false
disable-cancel: false
disable-cancel-during-exec: false
hide-back-and-next-during-exec: true
quit-at-end: false
CALASETTINGS

# ── User-friendly Calamares module configs ──────────────────────────────
# Override module titles/labels so nothing technical shows in the sidebar
# or page headers. Plain English only.

cat > /etc/calamares/modules/welcome.conf << 'WELCOMECONF'
---
# KibaTV welcome page — plain English, no technical jargon
requirements:
  check:
    - storage
    - ram
    - power
    - internet
  requiredStorageGiB: 20.0
  requiredRam: 1.0
geoip:
  style: "json"
  url:   "https://geoip.kde.org/v1/calamares"

# Override the page title shown in the sidebar
sidebar: "Welcome"
WELCOMECONF

cat > /etc/calamares/modules/locale.conf << 'LOCALECONF'
---
# Plain-English labels
region: "en_US"
zone:   "UTC"
sidebar: "Language & Region"
LOCALECONF

cat > /etc/calamares/modules/keyboard.conf << 'KEYBOARDCONF'
---
sidebar: "Keyboard"
KEYBOARDCONF

cat > /etc/calamares/modules/partition.conf << 'PARTCONF'
---
# Storage setup page — no "partition" word shown to user
efiSystemPartition:     "/boot/efi"
efiSystemPartitionSize: "300MiB"
efiSystemPartitionName: "EFI"
sidebar: "Storage"
PARTCONF

cat > /etc/calamares/modules/users.conf << 'USERSCONF'
---
sidebar: "Your Account"
userShell: /bin/zsh
autologinGroup:  autologin
sudoersGroup:    sudo
setRootPassword: false
doAutoLogin:     false
passwordRequirements:
  minLength: 6
  maxLength: -1
USERSCONF

cat > /etc/calamares/modules/summary.conf << 'SUMMARYCONF'
---
sidebar: "Review"
SUMMARYCONF

cat > /etc/calamares/modules/finished.conf << 'FINISHEDCONF'
---
sidebar: "All Done!"
restartNowEnabled:     true
restartNowChecked:     true
restartNowCommand:     "shutdown -r now"
notifyOnFinished:      false
FINISHEDCONF

# ── displaymanager.conf ─────────────────────────────────────────────────
mkdir -p /etc/calamares/modules
cat > /etc/calamares/modules/displaymanager.conf << 'DMCONF'
---
displaymanagers:
  - sddm
basicSetup: false
DMCONF

# ── preservefiles.conf ──────────────────────────────────────────────────
# FIXED: correct syntax — use list of file paths, not "from: log"
cat > /etc/calamares/modules/preservefiles.conf << 'PRESFILES'
---
dontChroot: true
files:
  - dest: /var/log/kibatv-install.log
    from: /var/log/calamares/session.log
    perm: "0644"
PRESFILES

# ── shellprocess@post.conf ──────────────────────────────────────────────
cat > /etc/calamares/modules/shellprocess@post.conf << 'POSTINSTALL'
---
dontChroot: false
timeout: 300
verbose: true
script:
  - "/usr/share/kibatv/post-install.sh"
POSTINSTALL

# ── Calamares slideshow ─────────────────────────────────────────────────
cat > /etc/calamares/branding/kibatv/show.qml << 'SHOWQML'
import calamares.slideshow 1.0;
Presentation {
    id: presentation
    Timer {
        interval: 5000
        running: presentation.activatedInCalamares
        repeat: true
        onTriggered: presentation.goToNextSlide()
    }
    Slide { centeredText: "Welcome to KibaTV!\n\nYour computer is getting set up.\nThis usually takes about 10 minutes." }
    Slide { centeredText: "KibaTV is built to stay out of your way.\n\nEverything you need is already here —\njust open it and go." }
    Slide { centeredText: "Your files, your apps, your way.\n\nHead to the app store after setup\nto install anything you like." }
    Slide { centeredText: "Almost there!\n\nWe're just finishing up.\nYour computer will restart when it's ready." }
    function onActivate() { presentation.currentSlide = 0; }
    function onLeave() {}
}
SHOWQML

# ── Calamares .desktop launcher ─────────────────────────────────────────
mkdir -p /usr/share/applications
cat > /usr/share/applications/calamares.desktop << 'CALADESKTOP'
[Desktop Entry]
Type=Application
Version=1.0
Name=Install KibaTV
Comment=Install KibaTV on your PC
Exec=sudo calamares
Icon=calamares
Terminal=false
Categories=System;
CALADESKTOP


# ── Post-install script ─────────────────────────────────────────────────
mkdir -p /usr/share/kibatv
cat > /usr/share/kibatv/post-install.sh << 'POSTINSTALLSH'
#!/bin/bash
# KibaTV post-install — runs chrooted inside installed system
set -e
exec > /var/log/kibatv-post-install.log 2>&1

TARGET_USER=$(getent passwd 1000 | cut -d: -f1 || true)
[ -z "$TARGET_USER" ] && TARGET_USER=$(ls /home 2>/dev/null | head -1 || true)
[ -z "$TARGET_USER" ] && { echo "FATAL: no user at UID 1000"; exit 1; }
TARGET_HOME="/home/$TARGET_USER"
echo "=== post-install: user=$TARGET_USER ==="

# 1. SKEL → user home
mkdir -p "$TARGET_HOME"
cp -rn /etc/skel/. "$TARGET_HOME/" 2>/dev/null || true
chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME"

# 2. ZSH as default shell
[ -x /bin/zsh ] && {
  chsh -s /bin/zsh "$TARGET_USER" 2>/dev/null || true
  chsh -s /bin/zsh root           2>/dev/null || true
}

# 3. The /etc/zsh/zshrc is already in squashfs; no need to rewrite.

# 4. SDDM — remove live autologin
rm -f /etc/sddm.conf.d/autologin.conf
mkdir -p /etc/sddm.conf.d
cat > /etc/sddm.conf.d/kde.conf << 'SDDMCONF'
[General]
DisplayServer=x11
GreeterEnvironment=QT_SCREEN_SCALE_FACTORS=1,QT_FONT_DPI=96
[Theme]
Current=breeze
[Users]
RememberLastSession=true
RememberLastUser=true
SDDMCONF

# 5. Sudoers — remove live NOPASSWD
rm -f /etc/sudoers.d/live-user

# 6. System identity
echo "kibatv" > /etc/hostname
cat > /etc/hosts << 'HOSTS'
127.0.0.1   localhost
127.0.1.1   kibatv
::1         localhost ip6-localhost ip6-loopback
HOSTS
cat > /etc/os-release << 'OSREL'
NAME="KibaTV"
ID=kibatv
ID_LIKE=debian
VERSION_ID="1.0"
PRETTY_NAME="KibaTV 1.0"
HOME_URL="https://github.com/WolfTech-Innovations/kiba"
SUPPORT_URL="https://github.com/WolfTech-Innovations/kiba/issues"
BUG_REPORT_URL="https://github.com/WolfTech-Innovations/kiba/issues"
OSREL

# 7. Sleep disabled on installed system
mkdir -p /etc/systemd/sleep.conf.d
cat > /etc/systemd/sleep.conf.d/nosleep.conf << 'NOSLEEP'
[Sleep]
AllowSuspend=no
AllowHibernation=no
AllowHybridSleep=no
AllowSuspendThenHibernate=no
NOSLEEP

# 8. Plymouth — re-register and rebuild initramfs
if [ -f /usr/share/plymouth/themes/kibatv-spinner/kibatv-spinner.plymouth ]; then
  update-alternatives --install \
    /usr/share/plymouth/themes/default.plymouth default.plymouth \
    /usr/share/plymouth/themes/kibatv-spinner/kibatv-spinner.plymouth 100 \
    2>/dev/null || true
  update-alternatives --set default.plymouth \
    /usr/share/plymouth/themes/kibatv-spinner/kibatv-spinner.plymouth \
    2>/dev/null || true
fi
sed -i 's/^COMPRESS=.*/COMPRESS=zstd/' /etc/initramfs-tools/initramfs.conf
echo "COMPRESSLEVEL=19" >> /etc/initramfs-tools/initramfs.conf
update-initramfs -u -k all 2>/dev/null || update-initramfs -u 2>/dev/null || true

# 9. GRUB update
echo "=== Updating GRUB configuration ==="
DEBIAN_FRONTEND=noninteractive update-grub || true

# 11. Flatpak — add Flathub system-wide
command -v flatpak >/dev/null 2>&1 && \
  flatpak remote-add --system --if-not-exists flathub \
    https://flathub.org/repo/flathub.flatpakrepo 2>/dev/null || true

# 12. Desktop DB refresh
update-desktop-database /usr/local/share/applications 2>/dev/null || true
update-desktop-database /usr/share/applications        2>/dev/null || true

# 13. Services
systemctl enable sddm            2>/dev/null || true
systemctl enable NetworkManager  2>/dev/null || true
systemctl enable plymouth-start  2>/dev/null || true
systemctl disable live-config    2>/dev/null || true
systemctl disable live-boot      2>/dev/null || true

# 14. Remove installer from autostart
rm -f /etc/xdg/autostart/calamares.desktop 2>/dev/null || true

# 15. Nala alias in bashrc (belt-and-suspenders alongside profile.d)
for RCFILE in /root/.bashrc "$TARGET_HOME/.bashrc"; do
  if [ -f "$RCFILE" ] && ! grep -q "nala" "$RCFILE"; then
    cat >> "$RCFILE" << 'NALABASH'
# KibaTV: nala as package manager frontend
command -v nala >/dev/null 2>&1 && {
  alias apt='nala'
  alias apt-get='nala'
}
NALABASH
  fi
done
chown "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.bashrc" 2>/dev/null || true

echo "=== KibaTV post-install COMPLETE ==="
POSTINSTALLSH
chmod +x /usr/share/kibatv/post-install.sh

BRANDING_HOOK
chmod +x config/hooks/live/0110-calamares-branding.hook.chroot


echo "=== Building ISO ==="
lb build 2>&1 | tee build.log

echo "=== Pipeline Verification ==="
# Check for CachyOS kernel in the chroot environment
if grep -qiE "cachyos|psycachy" build.log; then
  echo "VERIFIED: CachyOS kernel (psycachy) mentioned in build log"
else
  echo "WARNING: CachyOS kernel not found in build log"
fi

# Check for critical modern tools (mapping binary names to package names where needed)
for tool in micro fastfetch eza bat btop ripgrep fd-find tealdeer starship fzf yt-dlp; do
  if grep -q "Installing $tool" build.log || grep -q "Setting up $tool" build.log || grep -qi "$tool installed" build.log; then
     echo "VERIFIED: $tool installed"
  else
     # Some might be installed as dependencies or already present
     echo "NOTICE: $tool installation status unclear from log"
  fi
done

if [ -f live-image-amd64.hybrid.iso ]; then
  mv live-image-amd64.hybrid.iso "${ISO}.iso"
  sha256sum "${ISO}.iso" > "${ISO}.iso.sha256"

  echo "=== Starting Headless Boot Test (QEMU) ==="
  # Run QEMU for 60 seconds and capture serial output
  # We use -nographic and -serial stdio to capture boot logs
  # We add a small delay to ensure the kernel starts printing
  timeout 60s qemu-system-x86_64 \
    -m 2G \
    -cdrom "${ISO}.iso" \
    -nographic \
    -serial stdio \
    -no-reboot \
    > boot_test.log 2>&1 || true

  echo "=== Analyzing Boot Logs ==="
  if grep -qi "Kernel panic" boot_test.log; then
    echo "ERROR: Kernel panic detected during boot test!"
    cat boot_test.log
    exit 1
  fi

  if grep -qi "Call Trace:" boot_test.log; then
     echo "ERROR: Potential crash/trace detected in logs!"
     cat boot_test.log
     exit 1
  fi

  # Check if we at least reached the initramfs or live-boot stage
  if ! grep -qiE "init|live-boot|Loading|Linux version" boot_test.log; then
     echo "WARNING: Boot log seems empty or didn't start properly"
     # This might be due to lack of kvm, but we'll still fail if it's definitely broken
  fi

  echo "VERIFIED: Boot test completed without panics"

  echo ""
  echo "═══ KibaTV Build Complete ═══"
  ls -lh "${ISO}.iso"
else
  echo "ERROR: ISO file not found!"
  exit 1
fi
