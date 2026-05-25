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

# ══════════════════════════════════════════════════════════════════════════
# profiledef.sh
# ══════════════════════════════════════════════════════════════════════════
cat > "${PROFILE}/profiledef.sh" << 'PROFILEDEF'
#!/usr/bin/env bash
iso_name="kibaos"
iso_label="KIBAOS"
iso_publisher="WolfTech Innovations <https://github.com/WolfTech-Innovations>"
iso_application="KibaOS — A friendly desktop built on Arch Linux"
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
# Package list
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
ttf-dejavu
noto-fonts
noto-fonts-emoji
ttf-liberation
noto-fonts-cjk
xorg-server
xorg-xinit
xorg-xrandr
xorg-xsetroot
xorg-xinput
xorg-xdpyinfo
xf86-input-libinput
xf86-video-vesa
mesa
gpicview
lxappearance
lxappearance-obconf
lxde-common
lxde-icon-theme
lxdm
lxhotkey
lxinput
lxlauncher
lxmusic
lxpanel
lxrandr
lxsession
lxtask
lxterminal
openbox
pcmanfm
picom
papirus-icon-theme
gnome-themes-extra
accountsservice
firefox
mousepad
ristretto
file-roller
galculator
xfburn
system-config-printer
network-manager-applet
parole
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
fastfetch
plymouth
flatpak
xdg-desktop-portal
xdg-desktop-portal-gtk
feh
imagemagick
PACKAGES

# ══════════════════════════════════════════════════════════════════════════
# mkinitcpio
# ══════════════════════════════════════════════════════════════════════════
mkdir -p "${AIROOTFS}/etc/mkinitcpio.conf.d"
cat > "${AIROOTFS}/etc/mkinitcpio.conf.d/archiso.conf" << 'INITRAMFS'
HOOKS=(base udev keyboard keymap modconf memdisk archiso block plymouth filesystems)
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
# LXDM config
# ══════════════════════════════════════════════════════════════════════════
mkdir -p "${AIROOTFS}/etc/lxdm"
cat > "${AIROOTFS}/etc/lxdm/lxdm.conf" << 'LXDMCONF'
[base]
greeter=/usr/lib/lxdm/lxdm-greeter-gtk
autologin=liveuser
session=/usr/bin/startlxde
lang=1
numlock=0
bg=/usr/share/kibaos/wallpaper.png

[server]
arg=/usr/bin/X -background vt1

[display]
gtk_theme=Arc-Dark
icon_theme=Papirus-Dark
font=Noto Sans 11
language=

[input]

[userlist]
disable=0
white=
black=
LXDMCONF

mkdir -p "${AIROOTFS}/usr/share/lxdm/themes/KibaOS"
cat > "${AIROOTFS}/usr/share/lxdm/themes/KibaOS/theme.conf" << 'LXDMTHEME'
[theme]
greeter_label_bg=#006874
greeter_label_fg=#ffffff
bg=/usr/share/kibaos/wallpaper.png
LXDMTHEME

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
        { icon: "", heading: "LXDE Desktop", body: "Fast, familiar, and easy to use. Works great on any hardware, old or new." },
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
  - "-": "echo '=== KibaOS: migrating live session settings ==='"
  - "-": |
          NEW_USER=$(python3 -c "
          import json, sys
          for path in ['/etc/calamares/global_storage.json', '/tmp/calamares-global-storage.json']:
              try:
                  d = json.load(open(path))
                  u = d.get('username') or d.get('loginName') or ''
                  if u: print(u); sys.exit(0)
              except: pass
          import pwd
          for p in pwd.getpwall():
              if p.pw_uid >= 1000 and p.pw_name != 'liveuser': print(p.pw_name); sys.exit(0)
          print('')
          ")
          [ -z "$NEW_USER" ] && { echo 'WARNING: no username found'; exit 0; }
          NEW_HOME="/home/${NEW_USER}"
          LIVE_HOME="/home/liveuser"
          for d in openbox lxpanel lxsession lxde lxappearance gtk-3.0 gtk-4.0 gtk-2.0; do
              src="${LIVE_HOME}/.config/${d}"
              dst="${NEW_HOME}/.config/${d}"
              [ -d "$src" ] || continue
              mkdir -p "$(dirname "$dst")"
              cp -a "$src" "$dst"
          done
          chown -R "${NEW_USER}:${NEW_USER}" "${NEW_HOME}/.config" 2>/dev/null || true
          echo "=== Settings migrated to ${NEW_HOME} ==="
SHELLPROC

cat > "${AIROOTFS}/etc/calamares/modules/displaymanager.conf" << 'DMCONF'
---
displaymanagers:
  - lxdm
defaultDesktopEnvironment:
  executable: "startlxde"
  desktopFile: "LXDE"
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
ln -sf /usr/lib/systemd/system/graphical.target        "${WANTS}/default.target"
ln -sf /usr/lib/systemd/system/lxdm.service            "${WANTS}/display-manager.service"
ln -sf /usr/lib/systemd/system/NetworkManager.service  "${WANTS}/multi-user.target.wants/NetworkManager.service"
ln -sf /usr/lib/systemd/system/NetworkManager-dispatcher.service \
       "${WANTS}/dbus-org.freedesktop.nm-dispatcher.service"
ln -sf /usr/lib/systemd/system/pacman-init.service     "${WANTS}/multi-user.target.wants/pacman-init.service"
ln -sf /usr/lib/systemd/system/bluetooth.service       "${WANTS}/multi-user.target.wants/bluetooth.service"

# ══════════════════════════════════════════════════════════════════════════
# customize_airootfs.sh — runs inside the chroot at build time
# THE FIX: create alpm user at the very top, before any pacman call
# ══════════════════════════════════════════════════════════════════════════
mkdir -p "${AIROOTFS}/root"
cat > "${AIROOTFS}/root/customize_airootfs.sh" << 'CUSTOMIZE'
#!/usr/bin/env bash
set -e

# ── alpm user — MUST exist before any pacman invocation ───────────────────
# pacman 6.1+ uses DownloadUser=alpm in pacman.conf. The chroot starts from
# a clean airootfs install; the host's /etc/passwd is not inherited, so we
# must create the system user here before pacman-key / pacman -Sy.
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
# BUILD arc-gtk-theme FROM AUR
# ══════════════════════════════════════════════════════════════════════════
useradd -m -s /bin/bash builduser 2>/dev/null || true
echo 'builduser ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/builduser

AUR_BUILD="/tmp/aur-build"
mkdir -p "${AUR_BUILD}"

for pkg in arc-gtk-theme; do
  echo "=== Building ${pkg} from AUR ==="
  git clone --depth=1 "https://aur.archlinux.org/${pkg}.git" "${AUR_BUILD}/${pkg}"
  chown -R builduser:builduser "${AUR_BUILD}/${pkg}"
  cd "${AUR_BUILD}/${pkg}"
  sudo -u builduser makepkg -si --noconfirm
  cd /
done

cd /; rm -rf "${AUR_BUILD}"
userdel -r builduser 2>/dev/null || true
rm -f /etc/sudoers.d/builduser
echo "=== arc-gtk-theme installed ==="

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

for f in background-tile.png watermark.png kibaos.plymouth; do
  [ -L "${PLYMOUTH_THEME}/${f}" ] && cp --remove-destination \
    "$(readlink -f "${PLYMOUTH_THEME}/${f}")" "${PLYMOUTH_THEME}/${f}" || true
done

plymouth-set-default-theme -R kibaos

systemctl enable plymouth-start.service      2>/dev/null || true
systemctl enable plymouth-read-write.service 2>/dev/null || true
systemctl enable plymouth-quit-wait.service  2>/dev/null || true

echo "=== Plymouth configured ==="

# ══════════════════════════════════════════════════════════════════════════
# GTK THEME CONFIGURATION
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
# LXDE DESKTOP CONFIGURATION
# ══════════════════════════════════════════════════════════════════════════
LXHOME="/home/liveuser"
mkdir -p \
  "${LXHOME}/.config/openbox" \
  "${LXHOME}/.config/lxsession/LXDE" \
  "${LXHOME}/.config/lxpanel/LXDE/panels" \
  "${LXHOME}/.config/pcmanfm/LXDE" \
  "${LXHOME}/.config/gtk-3.0" \
  "${LXHOME}/.config/gtk-2.0" \
  "${LXHOME}/.config/picom" \
  "${LXHOME}/.local/share/applications"

cat > "${LXHOME}/.config/lxsession/LXDE/desktop.conf" << 'LXSESS'
[Session]
window_manager=openbox-lxde

[GTK]
sNet/ThemeName=Arc-Dark
sNet/IconThemeName=Papirus-Dark
sGtk/FontName=Noto Sans 11
sGtk/CursorThemeName=Adwaita
iGtk/CursorThemeSize=24
iXft/Antialias=1
iXft/Hinting=1
sXft/HintStyle=hintslight
sXft/RGBA=rgb

[Dbus]
autostart=true

[Autostart]
disable_autostart=no
LXSESS

cat > "${LXHOME}/.config/openbox/lxde-rc.xml" << 'OBCONF'
<?xml version="1.0" encoding="UTF-8"?>
<openbox_config xmlns="http://openbox.org/3.4/rc"
                xmlns:xi="http://www.w3.org/2001/XInclude">
  <resistance><strength>10</strength><screen_edge_strength>20</screen_edge_strength></resistance>
  <focus><focusNew>yes</focusNew><followMouse>no</followMouse><focusLast>yes</focusLast><underMouse>no</underMouse><focusDelay>200</focusDelay><raiseOnFocus>no</raiseOnFocus></focus>
  <placement><policy>Smart</policy><center>yes</center><monitor>Primary</monitor></placement>
  <theme>
    <name>Arc-Dark</name>
    <titleLayout>NLIMC</titleLayout>
    <keepBorder>yes</keepBorder>
    <animateIconify>yes</animateIconify>
    <font place="ActiveWindow"><name>Noto Sans</name><size>10</size><weight>Normal</weight><slant>Normal</slant></font>
    <font place="InactiveWindow"><name>Noto Sans</name><size>10</size><weight>Normal</weight><slant>Normal</slant></font>
    <font place="MenuHeader"><name>Noto Sans</name><size>10</size><weight>Bold</weight><slant>Normal</slant></font>
    <font place="MenuItem"><name>Noto Sans</name><size>10</size><weight>Normal</weight><slant>Normal</slant></font>
    <font place="OnScreenDisplay"><name>Noto Sans</name><size>10</size><weight>Bold</weight><slant>Normal</slant></font>
  </theme>
  <desktops><number>1</number><firstdesk>1</firstdesk><names><name>KibaOS</name></names><popupTime>875</popupTime></desktops>
  <resize><drawContents>yes</drawContents><popupShow>Nonpixel</popupShow></resize>
  <margins><top>0</top><bottom>48</bottom><left>0</left><right>0</right></margins>
  <dock><position>Bottom</position><floatingY>450</floatingY><stacking>Above</stacking><direction>Horizontal</direction><autoHide>no</autoHide><hideDelay>300</hideDelay><showDelay>300</showDelay><moveButton>Middle</moveButton></dock>
  <keyboard>
    <chainQuitKey>C-g</chainQuitKey>
    <keybind key="W-e"><action name="Execute"><command>pcmanfm</command></action></keybind>
    <keybind key="W-t"><action name="Execute"><command>lxterminal</command></action></keybind>
    <keybind key="W-b"><action name="Execute"><command>firefox</command></action></keybind>
    <keybind key="W-d"><action name="ToggleShowDesktop"/></keybind>
    <keybind key="A-F4"><action name="Close"/></keybind>
    <keybind key="A-Tab"><action name="NextWindow"><finalactions><action name="Focus"/><action name="Raise"/><action name="Unshade"/></finalactions></action></keybind>
    <keybind key="Print"><action name="Execute"><command>scrot ~/Pictures/screenshot-%Y%m%d-%H%M%S.png</command></action></keybind>
    <keybind key="C-A-t"><action name="Execute"><command>lxterminal</command></action></keybind>
    <keybind key="C-A-Delete"><action name="Execute"><command>lxtask</command></action></keybind>
    <keybind key="XF86AudioRaiseVolume"><action name="Execute"><command>amixer -q set Master 5%+ unmute</command></action></keybind>
    <keybind key="XF86AudioLowerVolume"><action name="Execute"><command>amixer -q set Master 5%- unmute</command></action></keybind>
    <keybind key="XF86AudioMute"><action name="Execute"><command>amixer -q set Master toggle</command></action></keybind>
  </keyboard>
  <mouse>
    <dragThreshold>8</dragThreshold><doubleClickTime>500</doubleClickTime>
    <screenEdgeWarpTime>400</screenEdgeWarpTime><screenEdgeWarpMouse>false</screenEdgeWarpMouse>
    <context name="Frame">
      <mousebind button="A-Left" action="Press"><action name="Focus"/><action name="Raise"/></mousebind>
      <mousebind button="A-Left" action="Drag"><action name="Move"/></mousebind>
      <mousebind button="A-Right" action="Drag"><action name="Resize"/></mousebind>
      <mousebind button="A-Middle" action="Press"><action name="Lower"/></mousebind>
    </context>
    <context name="Titlebar">
      <mousebind button="Left" action="Drag"><action name="Move"/></mousebind>
      <mousebind button="Left" action="DoubleClick"><action name="ToggleMaximize"/></mousebind>
      <mousebind button="Right" action="Press"><action name="Focus"/><action name="Raise"/><action name="ShowMenu"><menu>client-menu</menu></action></mousebind>
    </context>
    <context name="Desktop">
      <mousebind button="Right" action="Press"><action name="ShowMenu"><menu>root-menu</menu></action></mousebind>
      <mousebind button="Middle" action="Press"><action name="ShowMenu"><menu>client-list-combined-menu</menu></action></mousebind>
    </context>
    <context name="Client">
      <mousebind button="Left" action="Press"><action name="Focus"/><action name="Raise"/></mousebind>
      <mousebind button="Middle" action="Press"><action name="Focus"/><action name="Raise"/></mousebind>
      <mousebind button="Right" action="Press"><action name="Focus"/><action name="Raise"/></mousebind>
    </context>
  </mouse>
  <menu>
    <file>menu.xml</file><hideDelay>200</hideDelay><middle>no</middle>
    <submenuShowDelay>100</submenuShowDelay><submenuHideDelay>400</submenuHideDelay>
    <applicationIcons>yes</applicationIcons><manageDesktops>no</manageDesktops>
  </menu>
  <applications>
    <application name="pcmanfm"><focus>yes</focus></application>
    <application name="lxpanel"><layer>above</layer></application>
    <application name="firefox"><maximized>yes</maximized></application>
  </applications>
</openbox_config>
OBCONF

cat > "${LXHOME}/.config/openbox/menu.xml" << 'OBMENU'
<?xml version="1.0" encoding="UTF-8"?>
<openbox_menu xmlns="http://openbox.org/3.4/menu">
<menu id="root-menu" label="KibaOS">
  <item label="Files"><action name="Execute"><execute>pcmanfm</execute></action></item>
  <item label="Terminal"><action name="Execute"><execute>lxterminal</execute></action></item>
  <item label="Browser"><action name="Execute"><execute>firefox</execute></action></item>
  <item label="Text Editor"><action name="Execute"><execute>mousepad</execute></action></item>
  <separator/>
  <menu id="system-menu" label="System">
    <item label="Task Manager"><action name="Execute"><execute>lxtask</execute></action></item>
    <item label="Disk Manager"><action name="Execute"><execute>gparted</execute></action></item>
    <item label="Display Settings"><action name="Execute"><execute>lxrandr</execute></action></item>
    <item label="Appearance"><action name="Execute"><execute>lxappearance</execute></action></item>
    <item label="Install KibaOS"><action name="Execute"><execute>sudo calamares</execute></action></item>
  </menu>
  <separator/>
  <item label="Refresh Desktop"><action name="Execute"><execute>lxde-settings-daemon</execute></action></item>
  <separator/>
  <item label="Log Out"><action name="Execute"><execute>lxsession-logout</execute></action></item>
</menu>
</openbox_menu>
OBMENU

cat > "${LXHOME}/.config/lxpanel/LXDE/panels/panel" << 'PANEL'
Global {
  edge=bottom
  allign=left
  margin=0
  widthtype=percent
  width=100
  height=40
  transparent=0
  tintcolor=#1e2a2e
  alpha=255
  setdocktype=1
  setpartialstrut=1
  autohide=0
  heightwhenhidden=2
  usefontcolor=1
  fontcolor=#e8f0f2
  fontsize=11
  background=1
  backgroundcolor=#1e2a2e
  loglevel=4
  monitor=0
}
Plugin {
  type=menu
  Config {
    image=/usr/share/kibaos/logo-32.png
    system {
    }
    separator {
    }
    item {
      name=Install KibaOS
      image=system-software-install
      action=sudo calamares
    }
  }
}
Plugin {
  type=launchbar
  Config {
    Button { id=pcmanfm.desktop }
    Button { id=firefox.desktop }
    Button { id=lxterminal.desktop }
    Button { id=mousepad.desktop }
  }
}
Plugin { type=space
  Config { Size=4 }
}
Plugin {
  type=taskbar
  expand=1
  Config {
    tooltips=1
    IconsOnly=0
    ShowAllDesks=1
    UseMouseWheel=1
    UseUrgencyHint=1
    FlatButton=0
    MaxTaskWidth=200
    spacing=1
    GroupedTasks=0
  }
}
Plugin { type=space
  Config { Size=4 }
}
Plugin { type=tray }
Plugin { type=volume }
Plugin {
  type=netstatus
  Config {
    iface=
    configtool=nm-connection-editor
  }
}
Plugin {
  type=dclock
  Config {
    ClockFmt=%H:%M
    TooltipFmt=%A, %B %d %Y
    BoldFont=1
    IconOnly=0
    CenterText=1
  }
}
Plugin {
  type=launchbar
  Config {
    Button { id=system-shutdown.desktop }
  }
}
PANEL

cat > "${LXHOME}/.config/pcmanfm/LXDE/pcmanfm.conf" << 'PCMANFM'
[config]
show_thumbnail=1
thumbnail_max_size=8192
show_hidden=0
sort_by=name
sort_type=ascending
view_mode=icon_view

[volume]
mount_on_startup=1
mount_removable=1
autorun=0

[ui]
always_show_tabs=0
max_tab_chars=32
win_width=760
win_height=480
splitter_pos=150
side_pane_mode=dir_tree
toolbar_buttons=back;forward;up;home;

[desktop]
wallpaper_mode=stretch
wallpaper=/usr/share/kibaos/wallpaper.png
desktop_bg=#0d1b2a
desktop_fg=#e8f0f2
desktop_shadow=#000000
desktop_font=Noto Sans 11
show_wm_menu=0
show_documents=1
show_trash=1
show_mounts=1
PCMANFM

cat > "${LXHOME}/.config/gtk-3.0/settings.ini" << 'GTK3USER'
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

cat > "${LXHOME}/.gtkrc-2.0" << 'GTK2USER'
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

cat > "${LXHOME}/.config/picom/picom.conf" << 'PICOMCONF'
backend = "glx";
vsync = true;
shadow = true;
shadow-radius = 12;
shadow-offset-x = -5;
shadow-offset-y = -5;
shadow-opacity = 0.4;
shadow-exclude = [
  "name = 'Notification'",
  "class_g = 'lxpanel'",
  "_GTK_FRAME_EXTENTS@:c"
];
fading = true;
fade-in-step = 0.05;
fade-out-step = 0.05;
fade-delta = 8;
inactive-opacity = 0.95;
active-opacity = 1.0;
frame-opacity = 0.85;
inactive-opacity-override = false;
opacity-rule = [
  "100:class_g = 'firefox'",
  "100:class_g = 'lxterminal'",
  "100:class_g = 'Pcmanfm'"
];
glx-no-stencil = true;
glx-no-rebind-pixmap = true;
use-damage = true;
PICOMCONF

cat > "${LXHOME}/.config/lxsession/LXDE/autostart" << 'LXAUTOSTART'
@/usr/lib/policykit-1-gnome/polkit-gnome-authentication-agent-1
@picom --config /home/liveuser/.config/picom/picom.conf
@nm-applet
@nitrogen --restore
@/usr/local/bin/kiba-welcome
LXAUTOSTART

mkdir -p "${LXHOME}/.config/nitrogen"
cat > "${LXHOME}/.config/nitrogen/bg-saved.cfg" << 'NITROCFG'
[xin_-1]
file=/usr/share/kibaos/wallpaper.png
mode=4
bgcolor=#0d1b2a
NITROCFG

cat > "${LXHOME}/.config/nitrogen/nitrogen.cfg" << 'NITROCFG2'
[geometry]
posx=0
posy=0
sizex=560
sizey=400

[nitrogen]
view=icon
recurse=true
sort=alpha
icon_caps=false
dirs=/usr/share/kibaos;/usr/share/wallpapers;
NITROCFG2

mkdir -p "${LXHOME}/.config/lxterminal"
cat > "${LXHOME}/.config/lxterminal/lxterminal.conf" << 'LXTERM'
[general]
fontname=Noto Sans Mono 11
selchars=-A-Za-z0-9,./?%&#:_
scrollback=5000
bgcolor=#1e2a2e
fgcolor=#d8e6ea
color_preset=Custom
color0=#1e2a2e
color1=#e06c75
color2=#00b892
color3=#e5c07b
color4=#61afef
color5=#c678dd
color6=#56b6c2
color7=#abb2bf
color8=#3e4a50
color9=#e06c75
color10=#00c9a0
color11=#e5c07b
color12=#61afef
color13=#c678dd
color14=#56b6c2
color15=#ffffff
tabpos=top
hidescrollbar=0
hidemenubar=0
hideclosebutton=0
disablef10=0
disablealt=0
LXTERM

cat > "${LXHOME}/.bashrc" << 'BASHRC'
[[ $- != *i* ]] && return
PS1='\[\e[1;36m\][KibaOS]\[\e[0m\] \[\e[32m\]\u@\h\[\e[0m\]:\[\e[34m\]\w\[\e[0m\]\$ '
alias ls='ls --color=auto'
alias ll='ls -lah --color=auto'
alias grep='grep --color=auto'
alias install='sudo calamares'
alias update='sudo pacman -Syu'
fastfetch 2>/dev/null || true
BASHRC

mkdir -p "${LXHOME}/.config/fastfetch"
cat > "${LXHOME}/.config/fastfetch/config.jsonc" << 'FFCONF'
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
# DESKTOP SHORTCUT FILES
# ══════════════════════════════════════════════════════════════════════════
mkdir -p /usr/share/applications /usr/share/kibaos

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

[ -f /usr/share/applications/firefox.desktop ] && {
  cp /usr/share/applications/firefox.desktop /usr/share/applications/kibaos-browser.desktop
  sed -i -e 's/^Name=.*/Name=KibaOS Browser/' \
         -e 's/^GenericName=.*/GenericName=Web Browser/' \
         -e 's/^Comment=.*/Comment=Browse the web/' \
    /usr/share/applications/kibaos-browser.desktop; }

[ -f /usr/share/applications/pcmanfm.desktop ] && {
  cp /usr/share/applications/pcmanfm.desktop /usr/share/applications/kibaos-files.desktop
  sed -i -e 's/^Name=.*/Name=KibaOS Files/' \
         -e 's/^GenericName=.*/GenericName=File Manager/' \
    /usr/share/applications/kibaos-files.desktop; }

[ -f /usr/share/applications/lxterminal.desktop ] && {
  cp /usr/share/applications/lxterminal.desktop /usr/share/applications/kibaos-terminal.desktop
  sed -i -e 's/^Name=.*/Name=KibaOS Terminal/' \
    /usr/share/applications/kibaos-terminal.desktop; }

for src in /usr/share/applications/mousepad.desktop /usr/share/applications/org.xfce.mousepad.desktop; do
  [ -f "$src" ] && { cp "$src" /usr/share/applications/kibaos-editor.desktop
    sed -i -e 's/^Name=.*/Name=KibaOS Editor/' /usr/share/applications/kibaos-editor.desktop; break; }
done

for src in /usr/share/applications/ristretto.desktop /usr/share/applications/org.xfce.ristretto.desktop; do
  [ -f "$src" ] && { cp "$src" /usr/share/applications/kibaos-photos.desktop
    sed -i -e 's/^Name=.*/Name=KibaOS Photos/' /usr/share/applications/kibaos-photos.desktop; break; }
done

[ -f /usr/share/applications/gparted.desktop ] && {
  cp /usr/share/applications/gparted.desktop /usr/share/applications/kibaos-disks.desktop
  sed -i -e 's/^Name=.*/Name=KibaOS Disks/' /usr/share/applications/kibaos-disks.desktop; }

DESKTOP="${LXHOME}/Desktop"
mkdir -p "${DESKTOP}"
for src_desktop in kibaos-install kibaos-browser kibaos-files kibaos-terminal kibaos-editor kibaos-photos kibaos-disks; do
  [ -f "/usr/share/applications/${src_desktop}.desktop" ] && \
    cp "/usr/share/applications/${src_desktop}.desktop" "${DESKTOP}/${src_desktop}.desktop" && \
    chmod +x "${DESKTOP}/${src_desktop}.desktop" || true
done

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
  .card{background:var(--surface);border-radius:16px;padding:24px;flex:1;min-width:220px;box-shadow:0 2px 12px rgba(0,0,0,.08)}
  .card h2{font-size:1.1rem;font-weight:600;margin-bottom:6px}
  .card p{font-size:.9rem;color:var(--sub);line-height:1.5}
  section{max-width:900px;margin:0 auto;padding:0 32px 40px}
  section h2{font-size:1.3rem;font-weight:600;margin:28px 0 14px;color:var(--teal)}
  .tip{background:#e8f6f8;border-left:4px solid var(--teal);border-radius:8px;padding:14px 18px;margin-top:12px;font-size:.9rem}
  .tip code{background:#d0eaee;padding:2px 6px;border-radius:4px;font-family:monospace}
  .btn{display:inline-block;background:var(--teal);color:#fff;border-radius:10px;padding:10px 22px;text-decoration:none;font-size:.9rem;font-weight:600;margin-right:8px;margin-top:8px}
  .btn:hover{background:var(--teal-dark)}
  footer{text-align:center;padding:24px;color:var(--sub);font-size:.82rem;border-top:1px solid #d8e0e2;margin-top:16px}
</style>
</head>
<body>
<header><h1>Welcome to KibaOS</h1><p>A fast, friendly desktop built on Arch Linux - by WolfTech Innovations</p></header>
<div class="card-row">
  <div class="card"><h2>Fast &amp; Lightweight</h2><p>LXDE uses very little RAM and runs great on older and newer hardware alike.</p></div>
  <div class="card"><h2>Rolling Release</h2><p>Always up to date. Powered by Arch Linux and the AUR.</p></div>
  <div class="card"><h2>Your System</h2><p>Full encryption support. No telemetry. Your data stays yours.</p></div>
</div>
<section>
  <h2>Keyboard Shortcuts</h2>
  <div class="tip">
    <b>Super+E</b> Files | <b>Super+T</b> Terminal | <b>Super+B</b> Browser | <b>Super+D</b> Show Desktop<br><br>
    <b>Ctrl+Alt+T</b> Terminal | <b>Print</b> Screenshot | <b>Alt+F4</b> Close window
  </div>
  <h2>Ready to Install?</h2>
  <p>Click <strong>Install KibaOS</strong> on the desktop, or open a terminal and run:</p>
  <div class="tip"><code>sudo calamares</code></div><br>
  <a class="btn" href="https://github.com/WolfTech-Innovations/Kiba/blob/main/WIKI.md">Wiki</a>
  <a class="btn" href="https://github.com/WolfTech-Innovations/Kiba/issues">Report Issue</a>
  <a class="btn" href="https://github.com/WolfTech-Innovations/Kiba">GitHub</a>
</section>
<footer>KibaOS Rolling - WolfTech Innovations - github.com/WolfTech-Innovations/Kiba</footer>
</body>
</html>
WELCOMEHTML

# ══════════════════════════════════════════════════════════════════════════
# SYSTEM BRANDING
# ══════════════════════════════════════════════════════════════════════════
cat > /etc/issue << 'ISSUE'

  ██╗  ██╗██╗██████╗  █████╗  ██████╗ ███████╗
  ██║ ██╔╝██║██╔══██╗██╔══██╗██╔═══██╗██╔════╝
  █████╔╝ ██║██████╔╝███████║██║   ██║███████╗
  ██╔═██╗ ██║██╔══██╗██╔══██║██║   ██║╚════██║
  ██║  ██╗██║██████╔╝██║  ██║╚██████╔╝███████║
  ╚═╝  ╚═╝╚═╝╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝

  KibaOS Rolling - WolfTech Innovations
  Live session: user=liveuser  password=live
  Install: click the desktop icon or run  sudo calamares

ISSUE

cat > /etc/motd << 'MOTD'
Welcome to KibaOS - Fast LXDE desktop on Arch Linux.
Built with love by WolfTech Innovations.  https://github.com/WolfTech-Innovations/Kiba
MOTD

cat > /etc/environment << 'ENV'
DESKTOP_SESSION=LXDE
XDG_CURRENT_DESKTOP=LXDE
XDG_SESSION_DESKTOP=LXDE
XDG_SESSION_TYPE=x11
QT_AUTO_SCREEN_SCALE_FACTOR=1
GTK_THEME=Arc-Dark
KIBAOS_VERSION=rolling
KIBAOS_VENDOR="WolfTech Innovations"
ENV

systemctl enable lxdm.service
systemctl enable NetworkManager.service

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
  echo "╔══════════════════════════════════╗"
  echo "║  KibaOS LXDE build complete!     ║"
  echo "║  ${ISO}.iso          ║"
  echo "╚══════════════════════════════════╝"
else
  echo "ERROR: ISO file not found after mkarchiso!"
  exit 1
fi
