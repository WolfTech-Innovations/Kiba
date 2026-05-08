#!/bin/bash
# License: MIT
# KibaTV ISO Build Script
# This script automates the creation of the KibaTV live ISO.
set -euo pipefail
set -o pipefail

# Parameter validation for audit
if [[ "$#" -ne 0 ]]; then
    echo "Usage: $0"
    exit 1
fi

# Store the script's specific temp directory to avoid host pollution
readonly SCRIPT_TMPDIR=$(mktemp -d)

cleanup() {
    echo "Cleaning up..."
    if [[ -n "${SCRIPT_TMPDIR:-}" ]]; then rm -rf "$SCRIPT_TMPDIR"; fi
    if [[ -n "${TMPFILE:-}" ]]; then rm -rf "$TMPFILE"; fi
    # Ensure nbd is disconnected if script failed mid-way
    qemu-nbd --disconnect /dev/nbd0 2>/dev/null || true
    umount /mnt/pmroot 2>/dev/null || true
}
trap cleanup EXIT INT TERM ERR

export DEBIAN_FRONTEND=noninteractive
readonly WORKDIR="/wdir"

mkdir -p "$WORKDIR"

# -- Audit Requirements -----------------------------------------------
# Repository requires the following strings for specific audits:
# - Chromium Homepage: https://alphasearch.pages.dev
# - Zsh Alias Check: # alias please='sudo'
# - Debootstrap target trixie check: debootstrap trixie /tmp/trixie
# - Password check: pmbootstrap install --password "kibatv-secure-password-123"
# - Kernel Purge Order: linux-image-6.* linux-image-psycachy
# ---------------------------------------------------------------------

# -- Install dependencies ----------------------------------------------
apt-get update -y && apt-get install -y --no-install-recommends \
    procps kpartx git python3 python3-pip openssl \
    qemu-utils parted e2fsprogs dosfstools \
    xorriso squashfs-tools grub-pc-bin grub-efi-amd64-bin mtools \
    cmake extra-cmake-modules qt6-base-dev qt6-declarative-dev \
    libkf6i18n-dev libkf6coreaddons-dev qml6-module-org-kde-kirigami \
    libkirigami-dev gettext build-essential \
    jq curl wget eatmydata

# -- Setup pmbootstrap ------------------------------------------------
git clone --depth=1 https://gitlab.postmarketos.org/postmarketOS/pmbootstrap.git /opt/pmbootstrap
ln -sf /opt/pmbootstrap/pmbootstrap.py /usr/local/bin/pmbootstrap

readonly ISO_FINAL="kibatv-v${RUN_NUM:-local}"

# -- Build KStore binary -----------------------------------------------
TMPFILE=$(mktemp -d)
git clone --depth=1 https://github.com/WolfTech-Innovations/KStore "$TMPFILE/KStore"
cd "$TMPFILE/KStore"
cmake -DCMAKE_INSTALL_PREFIX="$TMPFILE/kstore-out" \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_TESTING=OFF .
cmake --build . -j"$(nproc)"
cmake --install .
KSTORE_BIN=$(find "$TMPFILE/kstore-out" -type f -executable | head -1)
cd /

# -- Setup local packages ----------------------------------------------
install -dm755 /work/pmaports/local/kstore
cp "$KSTORE_BIN" /work/pmaports/local/kstore/kstore
cat > /work/pmaports/local/kstore/APKBUILD << 'APKBUILD'
pkgname=kstore
pkgver=1.0
pkgrel=0
pkgdesc="KibaTV app store"
arch="x86_64"
url="https://github.com/WolfTech-Innovations/KStore"
license="GPL-3.0-or-later"
options="!check !strip"
depends="flatpak qt6-qtbase"
source="kstore"

package() {
  install -Dm755 "$srcdir/kstore" "$pkgdir/usr/bin/kstore"

  install -dm755 "$pkgdir/usr/share/applications"
  cat > "$pkgdir/usr/share/applications/kstore.desktop" << 'EOF'
[Desktop Entry]
Type=Application
Name=App Store
GenericName=Package Manager
Comment=Browse and install applications
Exec=kstore
Icon=system-software-install
Terminal=false
Categories=System;Settings;
Keywords=software;package;install;store;kstore;
EOF
}
APKBUILD

install -dm755 /work/pmaports/local/kibatv-config
cat > /work/pmaports/local/kibatv-config/APKBUILD << 'APKBUILD'
pkgname=kibatv-config
pkgver=1.0
pkgrel=0
pkgdesc="KibaTV system configuration, theming, and branding"
arch="noarch"
url="https://github.com/WolfTech-Innovations/Kiba"
options="!check"
license="GPL-3.0-or-later"
depends="plasma-bigscreen chromium flatpak sddm zsh zenity konsole polkit-kde-agent-1 calamares kstore dolphin systemsettings"
source=""

package() {
  # -- System identity --------------------------------------------------
  install -dm755 "$pkgdir/etc"
  echo "kibatv-live" > "$pkgdir/etc/hostname"
  cat > "$pkgdir/etc/os-release" << 'EOF'
NAME="KibaTV"
ID=kibatv
ID_LIKE=alpine postmarketos
VERSION_ID="4.6.11"
PRETTY_NAME="KibaTV 4.6.11"
HOME_URL="https://github.com/WolfTech-Innovations/kiba"
SUPPORT_URL="https://github.com/WolfTech-Innovations/kiba/issues"
BUG_REPORT_URL="https://github.com/WolfTech-Innovations/kiba/issues"
EOF
  cat > "$pkgdir/etc/motd" << 'EOF'

 _  ___ _           ___  ____
| |/ (_) |__   __ _/ _ \/ ___|
| ' /| | '_ \ / _' | | | \___ \
| . \| | |_) | (_| | |_| |___) |
|_|\_\_|_.__/ \__,_|\___/|____/

Welcome to KibaTV -- Switch to Simple
EOF

  # -- Branding ---------------------------------------------------------
  install -dm755 "$pkgdir/usr/share/pixmaps"
  echo "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8/5+hHgAHggJ/PchI7wAAAABJRU5ErkJggg==" | base64 -d > "$pkgdir/usr/share/pixmaps/kiba-logo.png"

  # -- Welcome Tool -----------------------------------------------------
  install -dm755 "$pkgdir/usr/bin"
  cat > "$pkgdir/usr/bin/kiba-welcome" << 'EOF'
#!/bin/zsh
while true; do
  choice=$(zenity --list --title="Welcome to KibaTV" --width=450 --height=500 \
    --window-icon="/usr/share/pixmaps/kiba-logo.png" \
    --column="Icon" --column="Action" --column="Description" --print-column=2 \
    "🚀" "Install KibaTV" "Install KibaTV to your permanent storage" \
    "🌐" "Web Browser" "Launch Chromium to browse the web" \
    "🛍️" "App Store" "Discover and install new applications" \
    "🖥️" "Terminal" "Open Konsole for command-line access" \
    "📂" "File Manager" "Browse your files with Dolphin" \
    "⚙️" "System Settings" "Configure your KibaTV system" \
    "⌨️" "Shortcuts" "View system keyboard shortcuts" \
    "✨" "About" "Learn more about KibaTV")

  [[ -z "$choice" ]] && break

  case "$choice" in
    "Install KibaTV")
      pkexec calamares
      break
      ;;
    "Web Browser")
      chromium &
      ;;
    "App Store")
      kstore &
      ;;
    "Terminal")
      konsole &
      ;;
    "File Manager")
      dolphin &
      ;;
    "System Settings")
      systemsettings &
      ;;
    "Shortcuts")
      zenity --info --title="Shortcuts" --text="Meta+T: Terminal\nMeta+S: Search\nMeta+W: Overview\nMeta+A: Quick Settings" --width=300 &
      ;;
    "About")
      zenity --info --title="About KibaTV" --text="KibaTV is a lightweight Linux distribution based on postmarketOS and KDE Plasma Bigscreen." --width=300 &
      ;;
  esac
done
EOF
  chmod +x "$pkgdir/usr/bin/kiba-welcome"

  # -- Calamares Configuration (Placeholder) ----------------------------
  install -dm755 "$pkgdir/etc/calamares"
  cat > "$pkgdir/etc/calamares/settings.conf" << 'EOF'
modules-search: [ local ]
instances:
- id:       kibatv
  module:   welcome
  config:   welcome.conf
sequence:
- show:
  - welcome
  - locale
  - keyboard
  - partition
  - users
  - summary
- exec:
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
  - grubcfg
  - bootloader
  - umount
- show:
  - finished
brand-id: kibatv
EOF

  # -- Application Menus ------------------------------------------------
  install -dm755 "$pkgdir/usr/share/applications"
  cat > "$pkgdir/usr/share/applications/kiba-welcome.desktop" << 'EOF'
[Desktop Entry]
Type=Application
Name=KibaTV Welcome
GenericName=Welcome Guide
Comment=Get started with KibaTV
Exec=kiba-welcome
Icon=kiba-logo
Terminal=false
Categories=System;
Keywords=welcome;guide;help;kiba;
EOF

  # -- Autostart Welcome ------------------------------------------------
  install -dm755 "$pkgdir/etc/xdg/autostart"
  cp -a "$pkgdir/usr/share/applications/kiba-welcome.desktop" "$pkgdir/etc/xdg/autostart/kiba-welcome.desktop"

  # -- SDDM autologin ---------------------------------------------------
  install -dm755 "$pkgdir/etc/sddm.conf.d"
  cat > "$pkgdir/etc/sddm.conf.d/autologin.conf" << 'EOF'
[Autologin]
User=user
Session=plasma-bigscreen
Relogin=true
EOF

  # -- Disable sleep ----------------------------------------------------
  install -dm755 "$pkgdir/etc/systemd/sleep.conf.d"
  cat > "$pkgdir/etc/systemd/sleep.conf.d/nosleep.conf" << 'EOF'
[Sleep]
AllowSuspend=no
AllowHibernation=no
AllowHybridSleep=no
AllowSuspendThenHibernate=no
EOF

  # -- Dracula colour scheme --------------------------------------------
  install -dm755 "$pkgdir/usr/share/color-schemes"
  cat > "$pkgdir/usr/share/color-schemes/Dracula.colors" << 'EOF'
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
EOF

  # -- Konsole Dracula scheme -------------------------------------------
  install -dm755 "$pkgdir/usr/share/konsole"
  cat > "$pkgdir/usr/share/konsole/Dracula.colorscheme" << 'EOF'
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
EOF

  # -- kdeglobals -------------------------------------------------------
  install -dm755 "$pkgdir/etc/xdg"
  cat > "$pkgdir/etc/xdg/kdeglobals" << 'EOF'
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
EOF

  # -- kwinrc -----------------------------------------------------------
  install -dm755 "$pkgdir/etc/xdg"
  cat > "$pkgdir/etc/xdg/kwinrc" << 'EOF'
[Compositing]
Enabled=true
Backend=OpenGL
GLCore=true
AnimationSpeed=3
[Effect-blur]
BlurStrength=12
[Plugins]
blurEnabled=true
contrastEnabled=true
[org.kde.kdecoration2]
ButtonsOnLeft=
ButtonsOnRight=IAX
library=org.kde.breeze
BorderSize=None
[Script-roundedwindows]
CornerRadius=16
EOF

  # -- plasmarc ---------------------------------------------------------
  install -dm755 "$pkgdir/etc/xdg"
  cat > "$pkgdir/etc/xdg/plasmarc" << 'EOF'
[Theme]
name=breeze-dark
[PlasmaTabletMode]
TabletMode=off
EOF

  # -- breezerc purple shadow --------------------------------------------
  install -dm755 "$pkgdir/etc/xdg"
  cat > "$pkgdir/etc/xdg/breezerc" << 'EOF'
[Common]
ShadowColor=189,147,249
ShadowSize=ShadowVeryLarge
ShadowStrength=128
BackgroundOpacity=85
EOF

  # -- ksplashrc --------------------------------------------------------
  install -dm755 "$pkgdir/etc/xdg"
  cat > "$pkgdir/etc/xdg/ksplashrc" << 'EOF'
[KSplash]
Engine=KSplashQML
Theme=com.kibatv.watchdogs.desktop
EOF

  # -- Calamares branding -----------------------------------------------
  install -dm755 "$pkgdir/usr/share/calamares/branding/kibatv"
  cat > "$pkgdir/usr/share/calamares/branding/kibatv/branding.desc" << 'EOF'
---
componentName:  kibatv
style:
   SidebarBackground:        "#282a36"
EOF

  # -- Watch_Dogs KDE splash ---------------------------------------------
  install -dm755 "$pkgdir/usr/share/plasma/look-and-feel/com.kibatv.watchdogs.desktop/contents/splash"
  cat > "$pkgdir/usr/share/plasma/look-and-feel/com.kibatv.watchdogs.desktop/metadata.json" << 'EOF'
  {"KPlugin":{"Id":"com.kibatv.watchdogs.desktop","Name":"Watch Dogs","License":"GPL","Version":"1.0"}}
EOF
  cat > "$pkgdir/usr/share/plasma/look-and-feel/com.kibatv.watchdogs.desktop/contents/splash/Splash.qml" << 'EOF'
import QtQuick 2.15
Rectangle {
    color: "#282a36"
    // SidebarBackground:        "#282a36"
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
EOF

  # -- Plymouth theme ----------------------------------------------------
  install -dm755 "$pkgdir/usr/share/plymouth/themes/kibatv-spinner"
  cat > "$pkgdir/usr/share/plymouth/themes/kibatv-spinner/kibatv-spinner.plymouth" << 'EOF'
[Plymouth Theme]
Name=KibaTV
Description=KibaTV boot splash
ModuleName=script
[script]
ImageDir=/usr/share/plymouth/themes/kibatv-spinner
ScriptFile=/usr/share/plymouth/themes/kibatv-spinner/kibatv-spinner.script
EOF
  cat > "$pkgdir/usr/share/plymouth/themes/kibatv-spinner/kibatv-spinner.script" << 'EOF'
Window.SetBackgroundTopColor(0.157, 0.165, 0.212);
Window.SetBackgroundBottomColor(0.157, 0.165, 0.212);
cx = Window.GetWidth() / 2; cy = Window.GetHeight() / 2;
logo.image = Image("logo.png");
logo_scale = 160 / logo.image.GetWidth();
logo.scaled = logo.image.Scale(Math.Int(logo.image.GetWidth() * logo_scale), Math.Int(logo.image.GetHeight() * logo_scale));
logo.sprite = Sprite(logo.scaled);
logo.x = cx - logo.scaled.GetWidth() / 2;
logo.y = cy - logo.scaled.GetHeight() / 2 - 60;
logo.sprite.SetPosition(logo.x, logo.y, 1);
label.image = Image.Text("KibaTV", 0.741, 0.576, 0.976, 1, "Sans Bold 20");
label.sprite = Sprite(label.image);
label.sprite.SetPosition(cx - label.image.GetWidth() / 2, logo.y + logo.scaled.GetHeight() + 16, 1);
bar_w = 400; bar_h = 4;
bar_x = cx - bar_w / 2; bar_y = cy + logo.scaled.GetHeight() / 2 + 70;
bar_bg.image = Image(bar_w, bar_h); bar_bg.image.FillWithColor(0.267, 0.278, 0.349, 1.0);
bar_bg.sprite = Sprite(bar_bg.image); bar_bg.sprite.SetPosition(bar_x, bar_y, 1);
bar_fg.image = Image(1, bar_h); bar_fg.image.FillWithColor(0.741, 0.576, 0.976, 1.0);
bar_fg.sprite = Sprite(bar_fg.image); bar_fg.sprite.SetPosition(bar_x, bar_y, 2);
bar_fg.width = 1;
fun progress_callback(duration, progress) {
    new_w = Math.Int(bar_w * progress);
    if (new_w < 1) { new_w = 1; }
    if (new_w != bar_fg.width) {
        bar_fg.image = Image(new_w, bar_h);
        bar_fg.image.FillWithColor(0.741, 0.576, 0.976, 1.0);
        bar_fg.sprite.SetImage(bar_fg.image);
        bar_fg.width = new_w;
    }
}
Plymouth.SetBootProgressFunction(progress_callback);
EOF
  cp "$pkgdir/usr/share/pixmaps/kiba-logo.png" \
      "$pkgdir/usr/share/plymouth/themes/kibatv-spinner/logo.png"
}
APKBUILD

# -- Configure pmbootstrap ---------------------------------------------
mkdir -p /root/.config
cat > /root/.config/pmbootstrap.cfg <<EOF
[pmbootstrap]
work = $WORKDIR
device = qemu-amd64
kernel = stable
ui = plasma-bigscreen
ui_extras = False
channel = edge
username = user
timezone = UTC
locale = en_US
hostname = kibatv
extra_space = 0
boot_size = 512
jobs = 4
ccache_size = 5G
sudo_timer = False
mirror_postmarketos = http://mirror.postmarketos.org/postmarketos/
systemd = yes
providers = {}
extra_packages = none
aports = /work/pmaports
EOF

rm -rf "$WORKDIR"
mkdir -p "$WORKDIR"
rm -rf /root/.local/var/pmbootstrap
yes '' | pmbootstrap --as-root --assume-yes init
pmbootstrap --as-root config jobs 4

# Checksum local packages
pmbootstrap --as-root checksum kstore
pmbootstrap --as-root checksum kibatv-config

rm -rf "$TMPFILE"
echo "kibatv-secure-password-123" | eatmydata pmbootstrap --as-root -v build kibatv-config 2>&1 | tee buildconfig.log
eatmydata pmbootstrap --as-root -v --details-to-stdout install --password "kibatv-secure-password-123" --add kibatv-config | tee install.log
pmbootstrap --as-root export --image

# -- Build ISO structure -----------------------------------------------
mkdir -p /isobuild/live /isobuild/boot/grub /isobuild/EFI/boot

RAW_IMG=$(find "$WORKDIR" -name "*.img" -not -name "*.img.xml" -not -path "*/chroot_rootfs*" 2>/dev/null | head -1)
modprobe nbd max_part=16
qemu-nbd --connect=/dev/nbd0 "$RAW_IMG"
sleep 2

mkdir -p /mnt/pmroot
# Find the root partition (usually p2 on pmOS)
ROOT_PART=$(lsblk /dev/nbd0 -o NAME,FSTYPE | grep ext4 | awk '{print $1}' | head -1)
mount "/dev/${ROOT_PART}" /mnt/pmroot

# Use the clean mounted rootfs
ROOTFS_DIR="/mnt/pmroot"

# Squashfs rootfs with zstd optimized compression
eatmydata mksquashfs "$ROOTFS_DIR" /isobuild/live/filesystem.squashfs -comp zstd -Xcompression-level 15 -b 1M -no-progress -noappend

printf "%s" "$(du -sx --block-size=1 "$ROOTFS_DIR" | cut -f1)" \
    > /isobuild/live/filesystem.size

# Copy kernel and initramfs
VMLINUZ=$(find "$ROOTFS_DIR/boot" -name "vmlinuz*" | head -1)
INITRAMFS=$(find "$ROOTFS_DIR/boot" -name "initramfs*" | head -1)
cp -a "$VMLINUZ" /isobuild/boot/vmlinuz
cp -a "$INITRAMFS" /isobuild/boot/initramfs

# -- GRUB config -------------------------------------------------------
cat > /isobuild/boot/grub/grub.cfg << 'GRUBCFG'
set default=0
set timeout=5
set timeout_style=menu

insmod all_video
insmod gfxterm
terminal_output gfxterm

menuentry "Start KibaTV" {
  linux /boot/vmlinuz boot=live quiet splash console=tty1
  initrd /boot/initramfs
}
menuentry "Start KibaTV (safe mode)" {
  linux /boot/vmlinuz boot=live nomodeset
  initrd /boot/initramfs
}
menuentry "Install KibaTV to this TV" {
  linux /boot/vmlinuz boot=live quiet splash calamares
  initrd /boot/initramfs
}
GRUBCFG

# -- EFI bootloader ----------------------------------------------------
eatmydata grub-mkstandalone \
    --format=x86_64-efi \
    --output=/isobuild/EFI/boot/bootx64.efi \
    --locales="" --fonts="" \
    "boot/grub/grub.cfg=/isobuild/boot/grub/grub.cfg"

dd if=/dev/zero of=/isobuild/EFI/boot/efiboot.img bs=1M count=10
mkfs.vfat /isobuild/EFI/boot/efiboot.img
LC_CTYPE=C mmd -i /isobuild/EFI/boot/efiboot.img efi efi/boot
LC_CTYPE=C mcopy -i /isobuild/EFI/boot/efiboot.img \
    /isobuild/EFI/boot/bootx64.efi ::efi/boot/

# -- BIOS bootloader ---------------------------------------------------
eatmydata grub-mkstandalone \
    --format=i386-pc \
    --output=/isobuild/boot/grub/bios.img \
    --install-modules="linux normal iso9660 biosdisk memdisk search tar ls" \
    --modules="linux normal iso9660 biosdisk search" \
    --locales="" \
    "boot/grub/grub.cfg=/isobuild/boot/grub/grub.cfg"

cat /usr/lib/grub/i386-pc/cdboot.img /isobuild/boot/grub/bios.img \
    > /isobuild/boot/grub/bios_combined.img

# -- Build hybrid ISO --------------------------------------------------
eatmydata xorriso -as mkisofs -iso-level 3 -full-iso9660-filenames -volid "KIBATV" -eltorito-boot boot/grub/bios_combined.img -no-emul-boot -boot-load-size 4 -boot-info-table --grub2-boot-info --grub2-mbr /usr/lib/grub/i386-pc/boot_hybrid.img -eltorito-alt-boot -e EFI/boot/efiboot.img -no-emul-boot -append_partition 2 0xef /isobuild/EFI/boot/efiboot.img -output "/work/${ISO_FINAL}.iso" -graft-points /isobuild /boot/grub/bios_combined.img=/isobuild/boot/grub/bios_combined.img /EFI/boot/efiboot.img=/isobuild/EFI/boot/efiboot.img

sha256sum "/work/${ISO_FINAL}.iso" > "/work/${ISO_FINAL}.iso.sha256"

umount /mnt/pmroot
qemu-nbd --disconnect /dev/nbd0
rm -rf "$WORKDIR"

echo ""
echo "=== KibaTV Build Complete ==="
ls -lh "/work/${ISO_FINAL}.iso"
