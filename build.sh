#!/bin/bash
set -ex

# ── Container deps ────────────────────────────────────────────────────────
pacman-key --init
pacman-key --populate archlinux
useradd -r -s /usr/bin/nologin -U alpm 2>/dev/null || true

mkdir -p /var/cache/pacman/pkg
chmod 755 /etc
chmod 755 /var/cache/pacman
chmod 755 /var/cache/pacman/pkg
chown -R alpm:alpm /var/cache/pacman
pacman -Syy --noconfirm
pacman -Su  --noconfirm
pacman -S --noconfirm --needed \
  archiso base-devel git squashfs-tools libisoburn mtools dosfstools \
  cmake ninja meson \
  xorg-server xorg-xinit xorg-xrandr xorg-xsetroot \
  libx11 libxext libxrender libxcomposite libxfixes \
  openssl curl imagemagick

# ── Paths ─────────────────────────────────────────────────────────────────
WORKDIR="/w"
ISO="kibaos-v${RUN_NUM}"
PROFILE="${WORKDIR}/kiba-profile"
AIROOTFS="${PROFILE}/airootfs"

cd "${WORKDIR}"
cp -r /usr/share/archiso/configs/releng/ "${PROFILE}"
mkdir -p "${AIROOTFS}"
sed -i 's/^CheckSpace/#CheckSpace/' "${PROFILE}/pacman.conf"

# ══════════════════════════════════════════════════════════════════════════
# profiledef.sh
# ══════════════════════════════════════════════════════════════════════════
cat > "${PROFILE}/profiledef.sh" << 'PROFILEDEF'
#!/usr/bin/env bash
iso_name="kibaos"
iso_label="KIBAOS"
iso_publisher="WolfTech Innovations <https://github.com/WolfTech-Innovations>"
iso_application="KibaOS — A friendly Budgie desktop built on Arch Linux"
iso_version="$(date +%Y.%m)"
install_dir="arch"
buildmodes=('iso')
bootmodes=('bios.syslinux.mbr' 'bios.syslinux.eltorito' 'uefi-ia32.systemd-boot.esp' 'uefi-x64.systemd-boot.esp')
arch="x86_64"
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'xz' '-Xbcj' 'x86' '-b' '1048576' '-Xdict-size' '1048576' '-no-duplicates' '-noappend')
file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/etc/gshadow"]="0:0:400"
  ["/root"]="0:0:750"
  ["/home/liveuser"]="1000:1000:750"
)
PROFILEDEF
chmod +x "${PROFILE}/profiledef.sh"

# ══════════════════════════════════════════════════════════════════════════
# /etc/os-release
# ══════════════════════════════════════════════════════════════════════════
mkdir -p "${AIROOTFS}/etc"
cat > "${AIROOTFS}/etc/os-release" << 'OSRELEASE'
NAME="KibaOS"
PRETTY_NAME="KibaOS Rolling"
ID=kibaos
ID_LIKE=arch
BUILD_ID=rolling
VERSION_CODENAME="wolftech"
ANSI_COLOR="1;36"
HOME_URL="https://github.com/WolfTech-Innovations/Kiba"
DOCUMENTATION_URL="https://github.com/WolfTech-Innovations/Kiba/blob/main/WIKI.md"
SUPPORT_URL="https://github.com/WolfTech-Innovations/Kiba/issues"
BUG_REPORT_URL="https://github.com/WolfTech-Innovations/Kiba/issues"
LOGO=kibaos
OSRELEASE

# ══════════════════════════════════════════════════════════════════════════
# Package list — Budgie edition
# ══════════════════════════════════════════════════════════════════════════
cat > "${PROFILE}/packages.x86_64" << 'PACKAGES'
archlinux-keyring
syslinux
base
linux
linux-firmware
mkinitcpio
mkinitcpio-archiso
grub
efibootmgr
networkmanager
sudo
bash
nano
curl
wget
git
mesa
xf86-video-vesa
xf86-video-fbdev
xorg-server
xorg-xinit
xorg-xrandr
xorg-xsetroot
xorg-xauth
fakeroot
debugedit
gcc
make
pkg-config
budgie
budgie-screensaver
nemo
nemo-fileroller
gnome-terminal
gnome-control-center
gnome-system-monitor
gnome-disk-utility
gnome-backgrounds
gnome-keyring
gnome-session
gnome-settings-daemon
gnome-shell
gvfs
gvfs-mtp
gvfs-smb
file-roller
gedit
eog
evince
lightdm
lightdm-gtk-greeter
lightdm-gtk-greeter-settings
papirus-icon-theme
accountsservice
firefox
sassc
network-manager-applet
pulseaudio
pulseaudio-alsa
pavucontrol
gparted
ntfs-3g
exfatprogs
polkit
polkit-gnome
udisks2
upower
scrot
fastfetch
plymouth
flatpak
xdg-desktop-portal
xdg-desktop-portal-gnome
feh
imagemagick
PACKAGES

# ══════════════════════════════════════════════════════════════════════════
# mkinitcpio — plymouth after udev
# ══════════════════════════════════════════════════════════════════════════
mkdir -p "${AIROOTFS}/etc/mkinitcpio.conf.d"
cat > "${AIROOTFS}/etc/mkinitcpio.conf.d/archiso.conf" << 'INITRAMFS'
HOOKS=(base udev plymouth keyboard keymap modconf memdisk archiso block filesystems)
INITRAMFS

mkdir -p "${AIROOTFS}/etc/mkinitcpio.d"
cat > "${AIROOTFS}/etc/mkinitcpio.d/linux.preset" << 'PRESET'
PRESETS=('archiso')
ALL_kver='/boot/vmlinuz-linux'
archiso_config='/etc/mkinitcpio.conf.d/archiso.conf'
archiso_image='/boot/initramfs-linux.img'
PRESET

# ══════════════════════════════════════════════════════════════════════════
# Boot menu
# ══════════════════════════════════════════════════════════════════════════
mkdir -p "${PROFILE}/efiboot/loader/entries"
cat > "${PROFILE}/efiboot/loader/loader.conf" << 'LOADER'
default kibaos.conf
timeout 5
console-mode max
editor no
LOADER

cat > "${PROFILE}/efiboot/loader/entries/kibaos.conf" << 'ENTRY'
title   KibaOS
linux   /arch/boot/x86_64/vmlinuz-linux
initrd  /arch/boot/x86_64/initramfs-linux.img
options archisobasedir=arch archisolabel=KIBAOS cow_spacesize=1G quiet splash plymouth.enable=1 rd.plymouth=1
ENTRY

cat > "${PROFILE}/efiboot/loader/entries/kibaos-safe.conf" << 'ENTRY_SAFE'
title   KibaOS (safe mode)
linux   /arch/boot/x86_64/vmlinuz-linux
initrd  /arch/boot/x86_64/initramfs-linux.img
options archisobasedir=arch archisolabel=KIBAOS cow_spacesize=1G plymouth.enable=0 nomodeset systemd.log_level=info
ENTRY_SAFE

SYSLINUX_CFG="${PROFILE}/syslinux/syslinux.cfg"
if [ -f "${SYSLINUX_CFG}" ]; then
  sed -i 's/Arch Linux/KibaOS/g'   "${SYSLINUX_CFG}"
  sed -i 's/ARCH_[0-9]*/KIBAOS/g' "${SYSLINUX_CFG}"
  cat >> "${SYSLINUX_CFG}" << 'SYSLINUX_SAFE'

LABEL kibaos-safe
  MENU LABEL KibaOS (safe mode)
  LINUX boot/x86_64/vmlinuz-linux
  INITRD boot/x86_64/initramfs-linux.img
  APPEND archisobasedir=arch archisolabel=KIBAOS cow_spacesize=1G plymouth.enable=0 nomodeset systemd.log_level=info
SYSLINUX_SAFE
fi

# ══════════════════════════════════════════════════════════════════════════
# Calamares installer config
# ══════════════════════════════════════════════════════════════════════════
mkdir -p "${AIROOTFS}/etc/calamares/modules"
mkdir -p "${AIROOTFS}/usr/share/calamares/branding/kibaos"

cat > "${AIROOTFS}/usr/share/calamares/branding/kibaos/branding.desc" << 'BRANDING'
---
componentName: kibaos
welcomeStyleCalamares: false
welcomeExpandingLogo: false
strings:
  productName:         KibaOS
  shortProductName:    KibaOS
  version:             Rolling
  shortVersion:        Rolling
  versionedName:       KibaOS Rolling
  shortVersionedName:  KibaOS
  bootloaderEntryName: KibaOS
  productUrl:          https://github.com/WolfTech-Innovations/Kiba
  supportUrl:          https://github.com/WolfTech-Innovations/Kiba/issues
  knownIssuesUrl:      https://github.com/WolfTech-Innovations/Kiba/issues
  releaseNotesUrl:     https://github.com/WolfTech-Innovations/Kiba
images:
  productLogo:    "logo.png"
  productIcon:    "logo.png"
  productWelcome: "logo.png"
slideshow:    "show.qml"
slideshowAPI: 2
style:
  sidebarBackground:    "#f3f3f3"
  sidebarText:          "#1a1a2e"
  sidebarTextSelect:    "#006874"
  sidebarTextHighlight: "#006874"
windowExpanding:  fullscreen
windowSize:       "1024px,768px"
windowPlacement:  center
sidebar:    none
navigation: none
BRANDING

cat > "${AIROOTFS}/usr/share/calamares/branding/kibaos/stylesheet.qss" << 'QSS'
QWidget {
    background-color: #f2f7f9; color: #1a1a2e;
    font-family: "Noto Sans", "DejaVu Sans", sans-serif; font-size: 13px;
}
QStackedWidget, QFrame#mainContent { background-color: #ffffff; border-radius: 12px; }
QLabel#labelTitle { font-size: 26px; font-weight: 400; color: #1a1a2e; padding-top: 28px; }
QLabel { color: #3a4050; font-size: 13px; }
QPushButton#nextButton {
    background-color: #006874; color: #ffffff; border: none;
    border-radius: 10px; padding: 10px 36px; font-size: 13px; font-weight: 600; min-width: 120px;
}
QPushButton#nextButton:hover { background-color: #004f57; }
QPushButton#nextButton:pressed { background-color: #003640; }
QPushButton#nextButton:disabled { background-color: #a0c8ce; }
QPushButton {
    background-color: #eef5f6; color: #006874; border: 1px solid #cdd7d9;
    border-radius: 10px; padding: 9px 24px; font-size: 13px; min-width: 90px;
}
QPushButton:hover { background-color: #d8edef; border-color: #006874; }
QPushButton:pressed { background-color: #c0e4e8; }
QPushButton:disabled { color: #aabbbb; border-color: #dde8e9; }
QLineEdit, QComboBox {
    background-color: #eef5f6; border: 1.5px solid #cdd7d9; border-radius: 10px;
    padding: 8px 12px; color: #1a1a2e; selection-background-color: #006874;
    selection-color: #ffffff; font-size: 13px;
}
QLineEdit:focus, QComboBox:focus { border: 2px solid #006874; background-color: #f0fafb; }
QProgressBar { background-color: #d8edef; border: none; border-radius: 4px; height: 6px; }
QProgressBar::chunk { background-color: #006874; border-radius: 4px; }
QListView, QTreeView {
    background-color: #ffffff; border: 1.5px solid #d8e0e2; border-radius: 10px;
    alternate-background-color: #f5fafb; outline: none;
}
QListView::item:hover, QTreeView::item:hover { background-color: #d8edef; }
QListView::item:selected, QTreeView::item:selected { background-color: #b0d8dc; color: #1a1a2e; }
QScrollBar:vertical { background: transparent; width: 7px; }
QScrollBar::handle:vertical { background: #c0d4d8; border-radius: 3px; min-height: 28px; }
QScrollBar::add-line:vertical, QScrollBar::sub-line:vertical { height: 0; }
QToolTip { background-color: #1a1a2e; color: #e8f0f2; border: none; border-radius: 6px; padding: 5px 8px; }
QSS

cat > "${AIROOTFS}/usr/share/calamares/branding/kibaos/show.qml" << 'SHOWQML'
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root; anchors.fill: parent
    property bool activatedInCalamares: false
    property var slides: [
        { icon: "", heading: "Welcome to KibaOS", body: "We're setting everything up for you. This usually takes 5-10 minutes." },
        { icon: "", heading: "Built on Arch Linux", body: "Rolling release means you always get the latest software, straight from upstream." },
        { icon: "", heading: "Budgie Desktop", body: "Fast, familiar, and easy to use. Works great on any hardware, old or new." },
        { icon: "", heading: "Your system, your rules", body: "Full disk encryption, pacman, and the entire AUR at your fingertips." },
        { icon: "", heading: "KibaOS by WolfTech", body: "github.com/WolfTech-Innovations/Kiba - guides, wiki, and issue reporting." }
    ]
    property int currentSlide: 0

    Timer { interval: 6000; running: root.activatedInCalamares; repeat: true
        onTriggered: root.currentSlide = (root.currentSlide + 1) % root.slides.length }

    Rectangle {
        anchors.fill: parent; color: "#f2f7f9"
        Rectangle {
            id: topStrip
            anchors { top: parent.top; left: parent.left; right: parent.right }
            height: parent.height * 0.38; color: "#006874"
            Image {
                anchors.centerIn: parent; source: "logo.png"; width: 96; height: 96
                fillMode: Image.PreserveAspectFit; smooth: true
            }
        }
        Rectangle {
            anchors { top: topStrip.bottom; topMargin: -20; horizontalCenter: parent.horizontalCenter }
            width: Math.min(parent.width - 64, 520); height: contentCol.implicitHeight + 48
            radius: 16; color: "#ffffff"
            ColumnLayout {
                id: contentCol
                anchors { top: parent.top; left: parent.left; right: parent.right; margins: 32 }
                spacing: 12
                Text { Layout.alignment: Qt.AlignHCenter; text: root.slides[root.currentSlide].icon; font.pixelSize: 36 }
                Text {
                    Layout.alignment: Qt.AlignHCenter; Layout.fillWidth: true
                    text: root.slides[root.currentSlide].heading
                    font.pixelSize: 20; font.weight: Font.Medium; color: "#1a1a2e"
                    horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter; Layout.fillWidth: true
                    text: root.slides[root.currentSlide].body
                    font.pixelSize: 13; color: "#556677"; horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap; lineHeight: 1.5
                }
                Row {
                    Layout.alignment: Qt.AlignHCenter; spacing: 8
                    Repeater {
                        model: root.slides.length
                        delegate: Rectangle {
                            width: index === root.currentSlide ? 18 : 7; height: 7; radius: 3.5
                            color: index === root.currentSlide ? "#006874" : "#cce0e4"
                            Behavior on width { NumberAnimation { duration: 200 } }
                            MouseArea { anchors.fill: parent; onClicked: root.currentSlide = index }
                        }
                    }
                }
            }
        }
        Rectangle {
            id: progressTrack
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: 5; color: "#d0eaee"
            Rectangle {
                anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                width: 0; color: "#006874"; radius: 2.5
                SequentialAnimation on width {
                    running: root.activatedInCalamares; loops: Animation.Infinite
                    NumberAnimation { from: 0; to: progressTrack.width * 0.85; duration: 2800; easing.type: Easing.InOutCubic }
                    PauseAnimation { duration: 500 }
                    NumberAnimation { to: progressTrack.width; duration: 600 }
                    PauseAnimation { duration: 300 }
                    NumberAnimation { to: 0; duration: 500 }
                }
            }
        }
    }
}
SHOWQML

cat > "${AIROOTFS}/etc/calamares/settings.conf" << 'CALA_SETTINGS'
---
modules-search: [ local, /usr/lib/calamares/modules ]
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
  - shellprocess@copy-user-settings
  - bootloader
  - umount
- show:
  - finished
branding: kibaos
prompt-install: false
dont-chroot: false
CALA_SETTINGS

cat > "${AIROOTFS}/etc/calamares/modules/unpackfs.conf" << 'UNPACKFS'
---
unpack:
  - source: "/run/archiso/bootmnt/arch/x86_64/airootfs.sfs"
    sourcefs: "squashfs"
    destination: ""
UNPACKFS

cat > "${AIROOTFS}/etc/calamares/modules/shellprocess@copy-user-settings.conf" << 'SHELLPROC'
---
dontChroot: false
timeout: 120
script:
SHELLPROC

# Calamares displaymanager — Budgie via LightDM
cat > "${AIROOTFS}/etc/calamares/modules/displaymanager.conf" << 'DMCONF'
---
displaymanagers:
  - lightdm
defaultDesktopEnvironment:
  executable: "budgie-desktop"
  desktopFile: "budgie-desktop"
basicSetup: false
DMCONF

# ══════════════════════════════════════════════════════════════════════════
# pacman.conf — locale pruning
# ══════════════════════════════════════════════════════════════════════════
PACMAN_CONF="${PROFILE}/pacman.conf"
if [ -f "${PACMAN_CONF}" ]; then
  grep -q 'NoExtract' "${PACMAN_CONF}" || \
    sed -i '/^\[options\]/a NoExtract  = usr/share/man/* usr/share/info/* usr/share/doc/*\nNoExtract  = usr/share/locale/* !usr/share/locale/en_US/* !usr/share/locale/en_GB/* !usr/share/locale/locale.alias' \
    "${PACMAN_CONF}"
fi

# ══════════════════════════════════════════════════════════════════════════
# liveuser account
# ══════════════════════════════════════════════════════════════════════════
LIVE_HASH=$(openssl passwd -6 "live")
grep -q '^liveuser:' "${AIROOTFS}/etc/passwd"  2>/dev/null || \
  echo 'liveuser:x:1000:1000:KibaOS Live User:/home/liveuser:/bin/bash' >> "${AIROOTFS}/etc/passwd"
grep -q '^liveuser:' "${AIROOTFS}/etc/group"   2>/dev/null || \
  echo 'liveuser:x:1000:liveuser' >> "${AIROOTFS}/etc/group"
grep -q '^liveuser:' "${AIROOTFS}/etc/shadow"  2>/dev/null || \
  echo "liveuser:${LIVE_HASH}:19000:0:99999:7:::" >> "${AIROOTFS}/etc/shadow"
mkdir -p "${AIROOTFS}/home/liveuser"
mkdir -p "${AIROOTFS}/etc/sudoers.d"
echo 'liveuser ALL=(ALL) NOPASSWD: ALL' > "${AIROOTFS}/etc/sudoers.d/liveuser"
chmod 0440 "${AIROOTFS}/etc/sudoers.d/liveuser"

# ══════════════════════════════════════════════════════════════════════════
# systemd symlinks
# ══════════════════════════════════════════════════════════════════════════
WANTS="${AIROOTFS}/etc/systemd/system"
mkdir -p "${WANTS}/default.target.wants" "${WANTS}/multi-user.target.wants"
ln -sf /usr/lib/systemd/system/graphical.target       "${WANTS}/default.target"
ln -sf /usr/lib/systemd/system/lightdm.service        "${WANTS}/display-manager.service"
ln -sf /usr/lib/systemd/system/NetworkManager.service "${WANTS}/multi-user.target.wants/NetworkManager.service"
ln -sf /usr/lib/systemd/system/NetworkManager-dispatcher.service \
       "${WANTS}/dbus-org.freedesktop.nm-dispatcher.service"
ln -sf /usr/lib/systemd/system/pacman-init.service    "${WANTS}/multi-user.target.wants/pacman-init.service"
ln -sf /usr/lib/systemd/system/bluetooth.service      "${WANTS}/multi-user.target.wants/bluetooth.service"

# ══════════════════════════════════════════════════════════════════════════
# customize_airootfs.sh — runs inside chroot at build time
# ══════════════════════════════════════════════════════════════════════════
mkdir -p "${AIROOTFS}/root"
cat > "${AIROOTFS}/root/customize_airootfs.sh" << 'CUSTOMIZE'
#!/usr/bin/env bash
set -e

# ── alpm user — must exist before any pacman call ─────────────────────────
useradd -r -s /usr/bin/nologin -U alpm 2>/dev/null || true
mkdir -p /var/cache/pacman/pkg
chmod 755 /var/cache/pacman /var/cache/pacman/pkg
chown -R alpm:alpm /var/cache/pacman

# ── Keyring + package DB ───────────────────────────────────────────────────
pacman-key --init
pacman-key --populate archlinux
pacman -Syy --noconfirm

# ── Locale + hostname ──────────────────────────────────────────────────────
sed -i 's/#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
locale-gen
echo 'LANG=en_US.UTF-8' > /etc/locale.conf
echo 'kibaos' > /etc/hostname
cat > /etc/hosts << 'HOSTS'
127.0.0.1   localhost
::1         localhost
127.0.1.1   kibaos.localdomain kibaos
HOSTS

# ── Groups + liveuser ─────────────────────────────────────────────────────
for g in users wheel audio video input network storage power; do
  groupadd -r "$g" 2>/dev/null || true
  usermod -aG "$g" liveuser 2>/dev/null || true
done
echo "liveuser:live" | chpasswd
grep -qx '/bin/bash' /etc/shells || echo '/bin/bash' >> /etc/shells

cp -aT /etc/skel/ /home/liveuser/ 2>/dev/null || true
chown -R 1000:1000 /home/liveuser
chmod 750 /home/liveuser

# ── systemd tunables ───────────────────────────────────────────────────────
sed -i 's/#Storage=auto/Storage=volatile/'                    /etc/systemd/journald.conf
sed -i 's/#HandleLidSwitch=suspend/HandleLidSwitch=ignore/'   /etc/systemd/logind.conf
sed -i 's/#HandleSuspendKey=suspend/HandleSuspendKey=ignore/' /etc/systemd/logind.conf

# ══════════════════════════════════════════════════════════════════════════
# DOWNLOAD BRANDING ASSETS
# ══════════════════════════════════════════════════════════════════════════
WALLPAPER_URL="https://github.com/WolfTech-Innovations/Kiba/blob/78699a64fff1f243162f50ffba206a2de0d3272e/branding/wallpaper.png?raw=true"
LOGO_URL="https://github.com/WolfTech-Innovations/Kiba/blob/main/branding/boot.png?raw=true"
WALLPAPER_DEST="/usr/share/kibaos/wallpaper.png"
LOGO_SRC="/usr/share/kibaos/logo-raw.png"
LOGO_256="/usr/share/kibaos/logo-256.png"
LOGO_96="/usr/share/kibaos/logo-96.png"
LOGO_48="/usr/share/kibaos/logo-48.png"
LOGO_32="/usr/share/kibaos/logo-32.png"

mkdir -p /usr/share/kibaos /usr/share/pixmaps

echo "=== Downloading KibaOS wallpaper ==="
curl -fL --retry 5 --retry-delay 3 -o "${WALLPAPER_DEST}" "${WALLPAPER_URL}" || \
  magick -size 1920x1080 gradient:"#004f57-#0d1b2a" "${WALLPAPER_DEST}"

echo "=== Downloading KibaOS logo ==="
curl -fL --retry 5 --retry-delay 3 -o "${LOGO_SRC}" "${LOGO_URL}" || true

if [ -f "${LOGO_SRC}" ] && file "${LOGO_SRC}" | grep -qi 'image'; then
  magick "${LOGO_SRC}" -filter Lanczos -resize 256x256 "${LOGO_256}"
  magick "${LOGO_SRC}" -filter Lanczos -resize 96x96  "${LOGO_96}"
  magick "${LOGO_SRC}" -filter Lanczos -resize 48x48  "${LOGO_48}"
  magick "${LOGO_SRC}" -filter Lanczos -resize 32x32  "${LOGO_32}"
  rm -f "${LOGO_SRC}"
else
  for sz in 256 96 48 32; do
    magick -size ${sz}x${sz} xc:none \
      -fill '#006874' -draw "circle $((sz/2)),$((sz/2)) $((sz/2)),1" \
      -fill white -pointsize $((sz/2)) -gravity Center -annotate 0 'K' \
      "/usr/share/kibaos/logo-${sz}.png"
  done
fi

cp "${LOGO_256}" /usr/share/pixmaps/kibaos.png
ln -sf /usr/share/pixmaps/kibaos.png /usr/share/pixmaps/kibaos-logo.png

mkdir -p /usr/share/icons/hicolor/256x256/apps \
         /usr/share/icons/hicolor/48x48/apps   \
         /usr/share/icons/hicolor/32x32/apps
cp "${LOGO_256}" /usr/share/icons/hicolor/256x256/apps/kibaos.png
cp "${LOGO_48}"  /usr/share/icons/hicolor/48x48/apps/kibaos.png
cp "${LOGO_32}"  /usr/share/icons/hicolor/32x32/apps/kibaos.png
gtk-update-icon-cache /usr/share/icons/hicolor/ 2>/dev/null || true

cp "${LOGO_256}" /usr/share/calamares/branding/kibaos/logo.png

# ══════════════════════════════════════════════════════════════════════════
# ══════════════════════════════════════════════════════════════════════════
# BUILD calamares + arc-gtk-theme FROM AUR
# ══════════════════════════════════════════════════════════════════════════
useradd -m -s /bin/bash builduser 2>/dev/null || true
echo 'builduser ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/builduser
sed -i 's/^CheckSpace/#CheckSpace/' /etc/pacman.conf

AUR_BUILD="/tmp/aur-build"
mkdir -p "${AUR_BUILD}"
for pkg in calamares arc-gtk-theme; do
  echo "=== Building ${pkg} from AUR ==="
  git clone --depth=1 "https://aur.archlinux.org/${pkg}.git" "${AUR_BUILD}/${pkg}"
  chown -R builduser:builduser "${AUR_BUILD}/${pkg}"
  cd "${AUR_BUILD}/${pkg}"
  sudo -u builduser makepkg -si --noconfirm --skippgpcheck
  cd /
done

cd /; rm -rf "${AUR_BUILD}"
userdel -r builduser 2>/dev/null || true
rm -f /etc/sudoers.d/builduser
echo "=== AUR packages installed ==="

# ══════════════════════════════════════════════════════════════════════════
# PLYMOUTH — KibaOS boot splash
# ══════════════════════════════════════════════════════════════════════════
PLYMOUTH_THEME="/usr/share/plymouth/themes/kibaos"
mkdir -p "${PLYMOUTH_THEME}"

SPINNER_SRC="/usr/share/plymouth/themes/spinner"
if [ -d "${SPINNER_SRC}" ]; then
  cp -a "${SPINNER_SRC}/." "${PLYMOUTH_THEME}/"
  rm -f "${PLYMOUTH_THEME}/spinner.plymouth"
fi

cat > "${PLYMOUTH_THEME}/kibaos.plymouth" << 'PLYM'
[Plymouth Theme]
Name=KibaOS
Description=KibaOS boot splash
ModuleName=spinner

[spinner]
Title=KibaOS
HideDelay=5
TransitionDuration=3
PLYM

magick -size 1920x1080 \
  \( xc:'#0d1b2a' \) \
  \( xc:'#004f57' -resize 1920x1080! \) \
  -compose Multiply -composite \
  "${PLYMOUTH_THEME}/background-tile.png"

cp "${LOGO_256}" "${PLYMOUTH_THEME}/watermark.png"

# Set theme WITHOUT -R to avoid chroot mkinitcpio hang
plymouth-set-default-theme kibaos 2>/dev/null || \
  plymouth-set-default-theme spinner 2>/dev/null || true

# Regenerate initramfs explicitly after theme is set
mkinitcpio -p linux 2>/dev/null || true

systemctl enable plymouth-start.service      2>/dev/null || true
systemctl enable plymouth-read-write.service 2>/dev/null || true
systemctl enable plymouth-quit-wait.service  2>/dev/null || true

echo "=== Plymouth configured ==="

# ══════════════════════════════════════════════════════════════════════════
# GTK THEME — system-wide
# ══════════════════════════════════════════════════════════════════════════
mkdir -p /usr/share/gtk-2.0
cat > /usr/share/gtk-2.0/gtkrc << 'GTK2RC'
gtk-theme-name = "Arc-Dark"
gtk-icon-theme-name = "Papirus-Dark"
gtk-font-name = "Noto Sans 11"
gtk-cursor-theme-size = 24
gtk-toolbar-style = GTK_TOOLBAR_ICONS
gtk-button-images = 1
gtk-menu-images = 1
gtk-xft-antialias = 1
gtk-xft-hinting = 1
gtk-xft-hintstyle = "hintslight"
gtk-xft-rgba = "rgb"
GTK2RC

mkdir -p /etc/gtk-3.0
cat > /etc/gtk-3.0/settings.ini << 'GTK3RC'
[Settings]
gtk-theme-name=Arc-Dark
gtk-icon-theme-name=Papirus-Dark
gtk-font-name=Noto Sans 11
gtk-cursor-theme-size=24
gtk-xft-antialias=1
gtk-xft-hinting=1
gtk-xft-hintstyle=hintslight
gtk-xft-rgba=rgb
GTK3RC

# ══════════════════════════════════════════════════════════════════════════
# BUDGIE USER CONFIGURATION
# ══════════════════════════════════════════════════════════════════════════
BHOME="/home/liveuser"
mkdir -p \
  "${BHOME}/.config/gtk-3.0" \
  "${BHOME}/.config/gtk-2.0" \
  "${BHOME}/.config/dconf" \
  "${BHOME}/.config/autostart" \
  "${BHOME}/.local/share/applications" \
  "${BHOME}/Desktop"

# GTK theme for liveuser
cat > "${BHOME}/.config/gtk-3.0/settings.ini" << 'GTK3USER'
[Settings]
gtk-theme-name=Arc-Dark
gtk-icon-theme-name=Papirus-Dark
gtk-font-name=Noto Sans 11
gtk-cursor-theme-size=24
gtk-xft-antialias=1
gtk-xft-hinting=1
gtk-xft-hintstyle=hintslight
gtk-xft-rgba=rgb
gtk-button-images=1
gtk-menu-images=1
gtk-enable-animations=1
GTK3USER

cat > "${BHOME}/.gtkrc-2.0" << 'GTK2USER'
gtk-theme-name="Arc-Dark"
gtk-icon-theme-name="Papirus-Dark"
gtk-font-name="Noto Sans 11"
gtk-cursor-theme-size=24
gtk-toolbar-style=GTK_TOOLBAR_ICONS
gtk-button-images=1
gtk-menu-images=1
gtk-xft-antialias=1
gtk-xft-hinting=1
gtk-xft-hintstyle="hintslight"
gtk-xft-rgba="rgb"
GTK2USER

# dconf settings — Budgie theme, wallpaper, panel
# Written as a dconf keyfile, imported on first login via autostart
mkdir -p "${BHOME}/.config/dconf"
cat > /usr/local/bin/kibaos-first-login << 'FIRSTLOGIN'
#!/usr/bin/env bash
# Runs once on first login to apply dconf settings
STAMP="${HOME}/.config/.kibaos-configured"
[ -f "${STAMP}" ] && exit 0

dbus-launch dconf write /org/gnome/desktop/interface/gtk-theme "'Arc-Dark'"
dbus-launch dconf write /org/gnome/desktop/interface/icon-theme "'Papirus-Dark'"
dbus-launch dconf write /org/gnome/desktop/interface/font-name "'Noto Sans 11'"
dbus-launch dconf write /org/gnome/desktop/interface/document-font-name "'Noto Sans 11'"
dbus-launch dconf write /org/gnome/desktop/interface/monospace-font-name "'Noto Sans Mono 11'"
dbus-launch dconf write /org/gnome/desktop/background/picture-uri "'file:///usr/share/kibaos/wallpaper.png'"
dbus-launch dconf write /org/gnome/desktop/background/picture-uri-dark "'file:///usr/share/kibaos/wallpaper.png'"
dbus-launch dconf write /org/gnome/desktop/background/picture-options "'zoom'"
dbus-launch dconf write /org/gnome/desktop/background/primary-color "'#0d1b2a'"
dbus-launch dconf write /com/solus-project/budgie-panel/layout "'default'"

touch "${STAMP}"
FIRSTLOGIN
chmod +x /usr/local/bin/kibaos-first-login

# Autostart entry for first-login config
cat > "${BHOME}/.config/autostart/kibaos-configure.desktop" << 'AUTOCFG'
[Desktop Entry]
Type=Application
Name=KibaOS First Login Setup
Exec=/usr/local/bin/kibaos-first-login
Hidden=false
NoDisplay=true
X-GNOME-Autostart-enabled=true
AUTOCFG

# Polkit agent — correct Arch path
cat > "${BHOME}/.config/autostart/polkit-gnome.desktop" << 'POLKIT'
[Desktop Entry]
Type=Application
Name=Polkit Authentication Agent
Exec=/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1
Hidden=false
NoDisplay=true
X-GNOME-Autostart-enabled=true
POLKIT

# Welcome page autostart
cat > "${BHOME}/.config/autostart/kiba-welcome.desktop" << 'WELCOME_AUTO'
[Desktop Entry]
Type=Application
Name=KibaOS Welcome
Exec=/usr/local/bin/kiba-welcome
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
WELCOME_AUTO

# bashrc
cat > "${BHOME}/.bashrc" << 'BASHRC'
[[ $- != *i* ]] && return
PS1='\[\e[1;36m\][KibaOS]\[\e[0m\] \[\e[32m\]\u@\h\[\e[0m\]:\[\e[34m\]\w\[\e[0m\]\$ '
alias ls='ls --color=auto'
alias ll='ls -lah --color=auto'
alias grep='grep --color=auto'
alias install='sudo calamares'
alias update='sudo pacman -Syu'
fastfetch 2>/dev/null || true
BASHRC

# fastfetch config
mkdir -p "${BHOME}/.config/fastfetch"
cat > "${BHOME}/.config/fastfetch/config.jsonc" << 'FFCONF'
{
  "$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",
  "logo": {
    "source": "kibaos",
    "color": { "1": "cyan", "2": "white" },
    "padding": { "top": 1 }
  },
  "display": { "separator": "  ", "color": { "keys": "cyan" } },
  "modules": [
    { "type": "title",  "format": "{user-name-colored}@{host-name-colored}" },
    "separator",
    { "type": "os",     "key": "OS" },
    { "type": "kernel", "key": "Kernel" },
    { "type": "de",     "key": "Desktop" },
    { "type": "wm",     "key": "WM" },
    { "type": "shell",  "key": "Shell" },
    { "type": "cpu",    "key": "CPU" },
    { "type": "gpu",    "key": "GPU" },
    { "type": "memory", "key": "Memory" },
    { "type": "disk",   "key": "Disk" },
    "break",
    { "type": "colors", "paddingLeft": 0 }
  ]
}
FFCONF

# ══════════════════════════════════════════════════════════════════════════
# DESKTOP SHORTCUTS
# ══════════════════════════════════════════════════════════════════════════
mkdir -p /usr/share/applications

cat > /usr/share/applications/kibaos-install.desktop << 'INSTDESK'
[Desktop Entry]
Name=Install KibaOS
Comment=Install KibaOS to your hard drive
Exec=sudo calamares
Icon=kibaos
Terminal=false
Type=Application
Categories=System;
Keywords=install;setup;kibaos;
INSTDESK

cat > /usr/share/applications/kibaos-about.desktop << 'ABOUTDESK'
[Desktop Entry]
Name=About KibaOS
Comment=Learn more about KibaOS
Exec=xdg-open https://github.com/WolfTech-Innovations/Kiba
Icon=kibaos
Terminal=false
Type=Application
Categories=System;
ABOUTDESK

DESKTOP="${BHOME}/Desktop"
for src_desktop in kibaos-install kibaos-about; do
  [ -f "/usr/share/applications/${src_desktop}.desktop" ] && \
    cp "/usr/share/applications/${src_desktop}.desktop" "${DESKTOP}/${src_desktop}.desktop" && \
    chmod +x "${DESKTOP}/${src_desktop}.desktop" || true
done

# ══════════════════════════════════════════════════════════════════════════
# WELCOME PAGE
# ══════════════════════════════════════════════════════════════════════════
cat > /usr/local/bin/kiba-welcome << 'WELCOMESCRIPT'
#!/usr/bin/env bash
WELCOME_HTML="/usr/share/kibaos/welcome.html"
if command -v firefox &>/dev/null; then
  firefox --no-remote "${WELCOME_HTML}" &
elif command -v xdg-open &>/dev/null; then
  xdg-open "${WELCOME_HTML}" &
fi
WELCOMESCRIPT
chmod +x /usr/local/bin/kiba-welcome

cat > /usr/share/kibaos/welcome.html << 'WELCOMEHTML'
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Welcome to KibaOS</title>
<style>
  :root{--teal:#006874;--teal-dark:#004f57;--bg:#f2f7f9;--surface:#fff;--text:#1a1a2e;--sub:#556677}
  *{margin:0;padding:0;box-sizing:border-box}
  body{font-family:'Noto Sans',sans-serif;background:var(--bg);color:var(--text)}
  header{background:var(--teal);color:#fff;padding:48px 32px 64px;text-align:center}
  header h1{font-size:2.4rem;font-weight:300}
  header p{font-size:1rem;opacity:.75;margin-top:6px}
  .card-row{display:flex;gap:20px;flex-wrap:wrap;padding:28px 32px;max-width:900px;margin:-28px auto 0}
  .card{background:var(--surface);border-radius:16px;padding:24px;flex:1;min-width:220px;box-shadow:0 2px 12px rgba(0,0,0,.08);transition:transform 0.2s ease,box-shadow 0.2s ease}
  .card:hover{transform:translateY(-4px);box-shadow:0 4px 20px rgba(0,0,0,.12)}
  .card h2{font-size:1.1rem;font-weight:600;margin-bottom:6px}
  .card p{font-size:.9rem;color:var(--sub);line-height:1.5}
  section{max-width:900px;margin:0 auto;padding:0 32px 40px}
  section h2{font-size:1.3rem;font-weight:600;margin:28px 0 14px;color:var(--teal)}
  .tip{background:#e8f6f8;border-left:4px solid var(--teal);border-radius:8px;padding:14px 18px;margin-top:12px;font-size:.9rem}
  kbd{background:#fff;border:1px solid #cdd7d9;border-radius:4px;box-shadow:0 1px 0 rgba(0,0,0,.2),inset 0 0 0 2px #fff;color:var(--text);display:inline-block;font-family:monospace;font-size:.85rem;line-height:1.4;margin:0 .1rem;padding:.1rem .4rem;white-space:nowrap}
  .btn{display:inline-block;background:var(--teal);color:#fff;border-radius:10px;padding:10px 22px;text-decoration:none;font-size:.9rem;font-weight:600;margin-right:8px;margin-top:8px;transition:background 0.2s ease,transform 0.1s ease}
  .btn:hover{background:var(--teal-dark)}
  .btn:active{transform:scale(0.98)}
  footer{text-align:center;padding:24px;color:var(--sub);font-size:.82rem;border-top:1px solid #d8e0e2;margin-top:16px}
</style>
</head>
<body>
<header><h1>Welcome to KibaOS</h1><p>A fast, friendly Budgie desktop built on Arch Linux — by WolfTech Innovations</p></header>
<main>
<div class="card-row" role="list" aria-label="Key features">
  <div class="card" role="listitem"><h2>Budgie Desktop</h2><p>Modern, clean, and intuitive. Great on any hardware.</p></div>
  <div class="card" role="listitem"><h2>Rolling Release</h2><p>Always up to date. Powered by Arch Linux and the AUR.</p></div>
  <div class="card" role="listitem"><h2>Your System</h2><p>Full encryption support. No telemetry. Your data stays yours.</p></div>
</div>
<section aria-labelledby="install-heading">
  <h2 id="install-heading">Ready to Install?</h2>
  <p>Click <strong>Install KibaOS</strong> on the desktop, or open a terminal and run:</p>
  <div class="tip"><kbd>sudo calamares</kbd></div><br>
  <a class="btn" href="https://github.com/WolfTech-Innovations/Kiba/blob/main/WIKI.md" aria-label="Visit the KibaOS Wiki for detailed documentation">Wiki</a>
  <a class="btn" href="https://github.com/WolfTech-Innovations/Kiba/issues" aria-label="Report an issue or bug on GitHub">Report Issue</a>
  <a class="btn" href="https://github.com/WolfTech-Innovations/Kiba" aria-label="View the KibaOS source code on GitHub">GitHub</a>
</section>
</main>
<footer>KibaOS Rolling — WolfTech Innovations — github.com/WolfTech-Innovations/Kiba</footer>
</body>
</html>
WELCOMEHTML

# ══════════════════════════════════════════════════════════════════════════
# SYSTEM BRANDING
# ══════════════════════════════════════════════════════════════════════════
cat > /etc/environment << 'ENV'
DESKTOP_SESSION=budgie-desktop
XDG_CURRENT_DESKTOP=Budgie:GNOME
XDG_SESSION_DESKTOP=budgie-desktop
XDG_SESSION_TYPE=x11
QT_AUTO_SCREEN_SCALE_FACTOR=1
GTK_THEME=Arc-Dark
KIBAOS_VERSION=rolling
KIBAOS_VENDOR="WolfTech Innovations"
ENV

cat > /etc/issue << 'ISSUE'

  ██╗  ██╗██╗██████╗  █████╗  ██████╗ ███████╗
  ██║ ██╔╝██║██╔══██╗██╔══██╗██╔═══██╗██╔════╝
  █████╔╝ ██║██████╔╝███████║██║   ██║███████╗
  ██╔═██╗ ██║██╔══██╗██╔══██║██║   ██║╚════██║
  ██║  ██╗██║██████╔╝██║  ██║╚██████╔╝███████║
  ╚═╝  ╚═╝╚═╝╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝

  KibaOS Rolling — Budgie Edition — WolfTech Innovations
  Live session: user=liveuser  password=live
  Install: click the desktop icon or run  sudo calamares

ISSUE

cat > /etc/motd << 'MOTD'
Welcome to KibaOS — Budgie desktop on Arch Linux.
Built with love by WolfTech Innovations.  https://github.com/WolfTech-Innovations/Kiba
MOTD

# ── Services ───────────────────────────────────────────────────────────────
systemctl enable lightdm
systemctl enable NetworkManager.service

# ── Fix ownership ──────────────────────────────────────────────────────────
chown -R 1000:1000 /home/liveuser
chmod 750 /home/liveuser

# ── Size reduction ─────────────────────────────────────────────────────────
rm -rf /var/cache/pacman/pkg/*
rm -rf /usr/share/man/* /usr/share/info/* /usr/share/doc/*
find /usr/share/locale -mindepth 1 -maxdepth 1 \
  ! -name 'en_US' ! -name 'en_GB' ! -name 'locale.alias' \
  -exec rm -rf {} + 2>/dev/null || true
find /usr/lib/firmware -mindepth 1 -maxdepth 1 \
  ! -name 'i915'    ! -name 'amdgpu'   ! -name 'radeon'  \
  ! -name 'nouveau' ! -name 'iwlwifi*' ! -name 'ath*'    \
  ! -name 'ath10k'  ! -name 'ath11k'   ! -name 'rtl_nic' \
  ! -name 'rtlwifi' ! -name 'rtw88'    ! -name 'rtw89'   \
  ! -name 'sof'     ! -name 'sof-tplg' ! -name 'intel'   \
  -exec rm -rf {} + 2>/dev/null || true
find /usr -type d -name '__pycache__' -exec rm -rf {} + 2>/dev/null || true
find /usr -name '*.pyc' -delete 2>/dev/null || true
find /usr/lib -name '*.a' -delete 2>/dev/null || true
rm -rf /usr/include/* 2>/dev/null || true
find /usr/share/icons -name 'icon-theme.cache' -delete 2>/dev/null || true
rm -rf /var/lib/pacman/sync/* /tmp/* /var/tmp/* 2>/dev/null || true

chown -R 1000:1000 /home/liveuser
echo "=== customize_airootfs.sh complete ==="
CUSTOMIZE
chmod +x "${AIROOTFS}/root/customize_airootfs.sh"

# ══════════════════════════════════════════════════════════════════════════
# BUILD ISO
# ══════════════════════════════════════════════════════════════════════════
cd "${WORKDIR}"
rm -rf "${WORKDIR}/work"
mkarchiso -v -w work -o out "${PROFILE}/"

if ls out/*.iso 1>/dev/null 2>&1; then
  mv out/*.iso "${ISO}.iso"
  sha256sum "${ISO}.iso" > "${ISO}.iso.sha256"
  echo "╔══════════════════════════════════════╗"
  echo "║  KibaOS Budgie build complete!       ║"
  echo "║  ${ISO}.iso            ║"
  echo "╚══════════════════════════════════════╝"
else
  echo "ERROR: ISO file not found after mkarchiso!"
  exit 1
fi
