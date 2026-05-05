#!/bin/bash
set -e
set -u
set -o pipefail
export DEBIAN_FRONTEND=noninteractive

# ── Environment Setup ──────────────────────────────────────────────────
WORKDIR="/wdir"
CHROOT="$WORKDIR/chroot"
ISO_DIR="$WORKDIR/isobuild"
OUTPUT_DIR="/w"
ISO_FILENAME="kibatv-v${RUN_NUM:-local}.iso"

/usr/bin/mkdir -p "$WORKDIR" "$CHROOT" "$ISO_DIR/live" "$OUTPUT_DIR"

# ── Install Host Dependencies ──────────────────────────────────────────
/usr/bin/apt-get update
/usr/bin/apt-get install -y eatmydata
/usr/bin/eatmydata /usr/bin/apt-get install -y \
    debootstrap \
    qemu-utils parted e2fsprogs dosfstools \
    xorriso squashfs-tools grub-pc-bin grub-efi-amd64-bin mtools \
    cmake extra-cmake-modules qt6-base-dev qt6-declarative-dev \
    libkf6i18n-dev libkf6coreaddons-dev qml6-module-org-kde-kirigami \
    libkirigami-dev gettext build-essential \
    jq curl wget git base64 systemd-container

# ── CachyOS Kernel Discovery ──────────────────────────────────────────
CURL_SECURE="/usr/bin/curl --proto =https --tlsv1.2 -Sf"
echo "🔍 Checking for latest CachyOS Kernel..."
API_URL="https://api.github.com/repos/psygreg/linux-psycachy/releases/latest"
IMG_URL=$($CURL_SECURE "$API_URL" | /usr/bin/jq -r ".assets[] | select(.name | contains(\"linux-image-psycachy\")) | .browser_download_url" | /usr/bin/head -1)
HDR_URL=$($CURL_SECURE "$API_URL" | /usr/bin/jq -r ".assets[] | select(.name | contains(\"linux-headers-psycachy\")) | .browser_download_url" | /usr/bin/head -1)

echo "🚀 Selected Kernel: $IMG_URL"
$CURL_SECURE -L -o /tmp/kernel.deb "$IMG_URL"
$CURL_SECURE -L -o /tmp/headers.deb "$HDR_URL"

# ── Build KStore binary ───────────────────────────────────────────────
/usr/bin/git clone --depth=1 https://github.com/WolfTech-Innovations/KStore /tmp/KStore
cd /tmp/KStore
/usr/bin/cmake -DCMAKE_INSTALL_PREFIX=/tmp/kstore-out -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF .
/usr/bin/cmake --build . -j"$(/usr/bin/nproc)"
/usr/bin/cmake --install .
KSTORE_BIN=$(/usr/bin/find /tmp/kstore-out -type f -executable | /usr/bin/head -1)
cd /

# ── Create Debian Rootfs ──────────────────────────────────────────────
/usr/bin/eatmydata /usr/sbin/debootstrap --arch=amd64 trixie "$CHROOT" http://deb.debian.org/debian/

# ── Configure System ──────────────────────────────────────────────────
/usr/bin/cat > "$CHROOT/etc/apt/sources.list" <<EOF
deb http://deb.debian.org/debian trixie main contrib non-free non-free-firmware
deb http://deb.debian.org/debian trixie-updates main contrib non-free non-free-firmware
deb http://security.debian.org/debian-security trixie-security main contrib non-free non-free-firmware
EOF

/usr/bin/cp /tmp/kernel.deb /tmp/headers.deb "$CHROOT/tmp/"
/usr/bin/cp "$KSTORE_BIN" "$CHROOT/usr/local/bin/kstore"

/usr/bin/cat > "$CHROOT/setup.sh" <<'EOF'
#!/bin/bash
set -e
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y eatmydata
eatmydata apt-get install -y \
    live-boot live-config live-config-systemd \
    plasma-bigscreen sddm chromium flatpak \
    zsh zsh-autosuggestions zsh-syntax-highlighting \
    nano git curl wget jq btop fastfetch fzf yt-dlp \
    calamares calamares-settings-debian \
    xdg-desktop-portal-kde network-manager plymouth \
    ntfs-3g cryptsetup locales sudo base64

# Purge stock kernels BEFORE installing custom one to avoid name conflicts
eatmydata apt-get purge -y 'linux-image-6.*' 'linux-headers-6.*' linux-image-amd64 linux-headers-amd64 || true

# Install CachyOS Kernel
eatmydata apt-get install -y /tmp/kernel.deb /tmp/headers.deb
rm /tmp/kernel.deb /tmp/headers.deb
apt-get autoremove -y

# ── User Configuration ──────────────────────────────────────────────
useradd -m -s /bin/zsh user
echo "user:kiba" | chpasswd
echo "user ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/user

# ── System Identity ──────────────────────────────────────────────────
echo "kibatv-live" > /etc/hostname
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

cat > /etc/motd << 'MOTD'

 _  ___ _           ___  ____
| |/ (_) |__   __ _/ _ \/ ___|
| ' /| | '_ \ / _` | | | \___ \
| . \| | |_) | (_| | |_| |___) |
|_|\_\_|_.__/ \__,_|\___/|____/

Welcome to 🚀 KibaTV | Switch to Simple ✨
MOTD

# ── SDDM & Plasma Configuration ──────────────────────────────────────
mkdir -p /etc/sddm.conf.d
cat > /etc/sddm.conf.d/autologin.conf << 'SDDM'
[Autologin]
User=user
Session=plasma-bigscreen
Relogin=true
SDDM

mkdir -p /etc/xdg
cat > /etc/xdg/ksplashrc << 'KSPLASH'
[KSplash]
Engine=KSplashQML
Theme=com.kibatv.watchdogs.desktop
KSPLASH

# ── Theme & UX ────────────────────────────────────────────────────────
mkdir -p /usr/share/applications
cat > /usr/share/applications/calamares.desktop << 'CALA'
[Desktop Entry]
Type=Application
Name=Install KibaTV
GenericName=System Installer
Keywords=Install;KibaTV;Setup;
Comment=Install KibaTV on your TV
Exec=calamares
Icon=calamares
Terminal=false
Categories=System;
CALA

# ── Dracula colour scheme ────────────────────────────────────────────
mkdir -p /usr/share/color-schemes
cat > /usr/share/color-schemes/Dracula.colors << 'DRACULA'
[Colors:Button]
BackgroundAlternate=68,71,90
BackgroundNormal=68,71,90
DecorationFocus=189,147,249
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
[Colors:Tooltip]
BackgroundNormal=40,42,54
ForegroundNormal=248,248,242
[General]
ColorScheme=Dracula
Name=Dracula
shadeSortColumn=true
[KDE]
contrast=4
DRACULA

# ── Konsole Dracula scheme ───────────────────────────────────────────
mkdir -p /usr/share/konsole
cat > /usr/share/konsole/Dracula.colorscheme << 'KONSOLE'
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
KONSOLE

# ── kdeglobals ───────────────────────────────────────────────────────
cat > /etc/xdg/kdeglobals << 'KDEGLO'
[KDE]
LookAndFeelPackage=org.kde.breezedark.desktop
SingleClick=true
contrast=4
[Icons]
Theme=breeze-dark
[General]
ColorScheme=Dracula
widgetStyle=Breeze
font=Sans,11,-1,5,50,0,0,0,0,0
fixed=Monospace,11,-1,5,50,0,0,0,0,0
[WM]
activeBackground=40,42,54
activeBlend=189,147,249
activeForeground=248,248,242
inactiveBackground=40,42,54
inactiveForeground=98,114,164
KDEGLO

# ── Watch_Dogs KDE splash ─────────────────────────────────────────────
mkdir -p /usr/share/plasma/look-and-feel/com.kibatv.watchdogs.desktop/contents/splash
cat > /usr/share/plasma/look-and-feel/com.kibatv.watchdogs.desktop/metadata.json << 'META'
{"KPlugin":{"Id":"com.kibatv.watchdogs.desktop","Name":"Watch Dogs","License":"GPL","Version":"1.0"}}
META
cat > /usr/share/plasma/look-and-feel/com.kibatv.watchdogs.desktop/contents/splash/Splash.qml << 'SPLASH'
import QtQuick 2.15
Rectangle {
    color: "#282a36"
    anchors.fill: parent
    Text {
        id: welcomeText
        anchors.centerIn: parent
        text: "KibaTV | Switch to simple"
        font.pixelSize: 48; font.bold: true; color: "#bd93f9"
        opacity: 0
        OpacityAnimator { target: welcomeText; from: 0; to: 1; duration: 1000; running: true }
    }
}
SPLASH

# ── Zshrc ────────────────────────────────────────────────────────────
cat > /etc/zsh/zshrc << 'ZSHRC'
export LANG=en_US.UTF-8
export EDITOR=nano
HISTSIZE=10000; SAVEHIST=10000; HISTFILE=~/.zsh_history
setopt SHARE_HISTORY HIST_IGNORE_DUPS INC_APPEND_HISTORY
setopt extendedglob
if [[ -n ~/.zcompdump(#qN.m-24) ]]; then
  autoload -Uz compinit && compinit -C -u
else
  autoload -Uz compinit && compinit -u
fi
zstyle ':completion:*' menu select
[ -f /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ] && \
  source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
[ -f /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ] && \
  source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
command -v fastfetch >/dev/null 2>&1 && fastfetch
'alias' ls='ls --color=auto'
'alias' ll='ls -lah'
'alias' update='sudo apt update && sudo apt upgrade' # 🚀 System Update
'alias' install='sudo apt install' # 📦 Install App
ZSHRC

# ── Logo & Plymouth ──────────────────────────────────────────────────
mkdir -p /usr/share/kibatv
# Logo placeholder - in real build it would be full base64
echo "iVBORw0KGgoAAAANSUhEUgAAAKAAAACgCAYAAACLz2ctAAAABGdBTUEAALGPC/xhBQAAACBjSFJNAAB6JgAAgIQAAPoAAACA6AAAdTAAAOpgAAA6mAAAF3CculE8AAAACXBIWXMAAAsTAAALEwEAmpwYAAABWWlUWHRYTUw6Y29tLmFkb2JlLnhtcAAAAAAAPD94cGFja2V0IGJlZ2luPSfvu78nIGlkPSdXNU0wTXBDZWhpSHpyZVN6TlRjemtjOWQnPz4KPHg6eG1wbWV0YSB4bWxuczp4PSdhZG9iZTpuczptZXRhLycgeDp4bXB0az0nWE1QIENvcmUgNS40LjAnPgogIDxyZGY6UkRGIHhtbG5zOnJkZj0naHR0cDovL3d3dy53My5vcmcvMTk5OS8wMi8yMi1yZGYtc3ludGF4LW5zIyc+CiAgICA8cmRmOkRlc2NyaXB0aW9uIHJkZjphYm91dD0nJwogICAgICB4bWxuczp4bXBNTT0naHR0cDovL25zLmFkb2JlLmNvbS94YXAvMS4wL21tLycKICAgICAgeG1sbnM6c3RSZWY9J2h0dHA6Ly9ucy5hZG9iZS5jb20veGFwLzEuMC9zVHlwZS9SZXNvdXJjZVJlZiMnCiAgICAgIHhtbG5zOnhtcD0naHR0cDovL25zLmFkb2JlLmNvbS94YXAvMS4wLycKICAgICAgeG1wTU06RG9jdW1lbnRJRD0neG1wLmRpZDo4ODNENkFGRTM0OUUxMUVFODlGQjhFRDIzOTNEMzNGRCcKICAgICAgeG1wTU06SW5zdGFuY2VJRD0neG1wLmlpZDo4ODNENkFGRDI0OUUxMUVFODlGQjhFRDIzOTNEMzNGRCcKICAgICAgeG1wOkNyZWF0b3JUb29sPSdBZG9iZSBQaG90b3Nob3AgQ0MgMjAxNCAoV2luZG93cyknPgogICAgICA8eG1wTU06RGVyaXZlZEZyb20gcmRmOnBhcnNlVHlwZT0nUmVzb3VyY2VSZWYnIHN0UmVmOmluc3RhbmNlSUQ9J3htcC5paWQ6ODgzRDZBRkEyNDlFMTFFRTg5RkI4RUQyMzkzRDMzRkQnIHN0UmVmOmRvY3VtZW50SUQ9J3htcC5kaWQ6ODgzRDZBRkIzNDlFMTFFRTg5RkI4RUQyMzkzRDMzRkQnLz4KICAgIDwvcmRmOkRlc2NyaXB0aW9uPgogIDwvcmRmOlJERj4KPC94OnhtcG1ldGE+Cjw/eHBhY2tldCBlbmQ9J3cnPz4=" | base64 -d > /usr/share/kibatv/logo.png

mkdir -p /usr/share/plymouth/themes/kibatv-spinner
cp /usr/share/kibatv/logo.png /usr/share/plymouth/themes/kibatv-spinner/logo.png
cat > /usr/share/plymouth/themes/kibatv-spinner/kibatv-spinner.plymouth << 'PLY'
[Plymouth Theme]
Name=KibaTV
Description=KibaTV boot splash
ModuleName=script
[script]
ImageDir=/usr/share/plymouth/themes/kibatv-spinner
ScriptFile=/usr/share/plymouth/themes/kibatv-spinner/kibatv-spinner.script
PLY

# ── Calamares Full Configuration ─────────────────────────────────────
mkdir -p /etc/calamares/branding/kibatv
cp /usr/share/kibatv/logo.png /etc/calamares/branding/kibatv/logo.png

cat > /etc/calamares/settings.conf << 'CALASET'
---
modules-search: [ local, /usr/lib/calamares/modules ]
sequence:
  - show: [ welcome, locale, keyboard, partition, users, summary ]
  - exec: [ partition, mount, unpackfs, machineid, fstab, locale, keyboard, localecfg, users, displaymanager, networkcfg, hwclock, services-systemd, initramfs, umount ]
  - show: [ finished ]
branding: kibatv
prompt-install: false
dont-chroot: false
CALASET

cat > /etc/calamares/branding/kibatv/branding.desc << 'CALADESC'
---
componentName: kibatv
welcomeStyleCalamares: true
welcomeExpandingLogo: true
slideshowAPI: 2
strings:
  productName: "KibaTV"
  shortProductName: "KibaTV"
  version: "1.0"
  bootloaderEntryName: "KibaTV"
images:
  productLogo: "logo.png"
  productIcon: "logo.png"
  productWelcome: "logo.png"
style:
  SidebarBackground:        "#282a36"
  SidebarText:              "#f8f8f2"
  SidebarTextCurrent:       "#282a36"
  SidebarBackgroundCurrent: "#bd93f9"
slideshow: "show.qml"
CALADESC

cat > /etc/calamares/branding/kibatv/show.qml << 'SHOW'
import calamares.slideshow 1.0;
Presentation {
    id: presentation
    Timer { interval: 5000; running: presentation.activatedInCalamares; repeat: true; onTriggered: presentation.goToNextSlide() }
    Slide { centeredText: "🚀 Welcome to KibaTV!\n\nYour TV is getting set up.\nThis usually takes about 10 minutes." }
    Slide { centeredText: "📺 KibaTV is built to stay out of your way.\n\nEverything you need is already here." }
    Slide { centeredText: "🛍️ Your files, your apps, your way.\n\nHead to KStore after setup to install anything you like." }
    Slide { centeredText: "✨ Almost there!\n\nWe're just finishing up.\nYour TV will restart when ready." }
    function onActivate() { presentation.currentSlide = 0; }
}
SHOW

# Clean up
apt-get clean
rm /setup.sh
EOF

/usr/bin/chmod +x "$CHROOT/setup.sh"
/usr/bin/eatmydata /usr/bin/systemd-nspawn -D "$CHROOT" /bin/bash /setup.sh

# ── Prepare ISO structure ─────────────────────────────────────────────
VMLINUZ=$(/usr/bin/find "$CHROOT/boot" -name "vmlinuz*" | /usr/bin/head -1)
INITRD=$(/usr/bin/find "$CHROOT/boot" -name "initrd.img*" | /usr/bin/head -1)
/usr/bin/cp "$VMLINUZ" "$ISO_DIR/live/vmlinuz"
/usr/bin/cp "$INITRD" "$ISO_DIR/live/initrd"

/usr/bin/eatmydata /usr/bin/mksquashfs "$CHROOT" "$ISO_DIR/live/filesystem.squashfs" \
    -comp zstd -Xcompression-level 15 -b 1M -no-progress -noappend

# ── GRUB Configuration ────────────────────────────────────────────────
/usr/bin/mkdir -p "$ISO_DIR/boot/grub"
/usr/bin/cat > "$ISO_DIR/boot/grub/grub.cfg" << 'GRUBCFG'
set default=0
set timeout=5
set timeout_style=menu
insmod all_video
insmod gfxterm
terminal_output gfxterm
menuentry "🚀 Start KibaTV" {
    linux /live/vmlinuz boot=live quiet splash console=tty1
    initrd /live/initrd
}
GRUBCFG

# ── Build ISO ────────────────────────────────────────────────────────
/usr/bin/eatmydata /usr/bin/grub-mkstandalone --format=x86_64-efi --output="$ISO_DIR/EFI/boot/bootx64.efi" --locales="" --fonts="" "boot/grub/grub.cfg=$ISO_DIR/boot/grub/grub.cfg"
/usr/bin/dd if=/dev/zero of="$ISO_DIR/EFI/boot/efiboot.img" bs=1M count=10
/usr/sbin/mkfs.vfat "$ISO_DIR/EFI/boot/efiboot.img"
LC_CTYPE=C /usr/bin/mmd -i "$ISO_DIR/EFI/boot/efiboot.img" efi efi/boot
LC_CTYPE=C /usr/bin/mcopy -i "$ISO_DIR/EFI/boot/efiboot.img" "$ISO_DIR/EFI/boot/bootx64.efi" ::efi/boot/
/usr/bin/eatmydata /usr/bin/grub-mkstandalone --format=i386-pc --output="$ISO_DIR/boot/grub/bios.img" --install-modules="linux normal iso9660 biosdisk memdisk search tar ls" --modules="linux normal iso9660 biosdisk search" --locales="" "boot/grub/grub.cfg=$ISO_DIR/boot/grub/grub.cfg"
/usr/bin/cat /usr/lib/grub/i386-pc/cdboot.img "$ISO_DIR/boot/grub/bios.img" > "$ISO_DIR/boot/grub/bios_combined.img"
/usr/bin/eatmydata /usr/bin/xorriso -as mkisofs -iso-level 3 -full-iso9660-filenames -volid "KIBATV" -eltorito-boot boot/grub/bios_combined.img -no-emul-boot -boot-load-size 4 -boot-info-table --grub2-boot-info --grub2-mbr /usr/lib/grub/i386-pc/boot_hybrid.img -eltorito-alt-boot -e EFI/boot/efiboot.img -no-emul-boot -append_partition 2 0xef "$ISO_DIR/EFI/boot/efiboot.img" -output "$OUTPUT_DIR/$ISO_FILENAME" -graft-points "$ISO_DIR" /boot/grub/bios_combined.img="$ISO_DIR/boot/grub/bios_combined.img" /EFI/boot/efiboot.img="$ISO_DIR/EFI/boot/efiboot.img"
/usr/bin/sha256sum "$OUTPUT_DIR/$ISO_FILENAME" > "$OUTPUT_DIR/$ISO_FILENAME.sha256"
echo "✨ === KibaTV Build Complete === ✨"
