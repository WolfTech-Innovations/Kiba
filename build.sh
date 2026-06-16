#!/bin/bash
set -ex

# ── Performance: Enable parallel downloads for host pacman ─────────────────
sed -i 's/^#ParallelDownloads = 5/ParallelDownloads = 10/' /etc/pacman.conf

# ── Pre-create alpm user in airootfs so pacman works inside chroot ─────────
grep -q '^alpm:' "${AIROOTFS}/etc/passwd" 2>/dev/null || \
  echo 'alpm:x:951:951::/var/cache/pacman/pkg:/usr/bin/nologin' >> "${AIROOTFS}/etc/passwd"
grep -q '^alpm:' "${AIROOTFS}/etc/group" 2>/dev/null || \
  echo 'alpm:x:951:' >> "${AIROOTFS}/etc/group"
grep -q '^alpm:' "${AIROOTFS}/etc/shadow" 2>/dev/null || \
  echo 'alpm:!*:19000::::::' >> "${AIROOTFS}/etc/shadow"
mkdir -p "${AIROOTFS}/var/cache/pacman/pkg"
chmod 755 "${AIROOTFS}/var/cache/pacman" "${AIROOTFS}/var/cache/pacman/pkg"

# ── Container deps ────────────────────────────────────────────────────────
pacman-key --init
pacman-key --populate archlinux
pacman -Syy --noconfirm
pacman -Su  --noconfirm
pacman -S --noconfirm --needed \
  archiso base-devel git squashfs-tools libisoburn mtools dosfstools \
  cmake ninja meson \
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
sed -i 's/^#ParallelDownloads = 5/ParallelDownloads = 10/' "${PROFILE}/pacman.conf"
sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' "${PROFILE}/pacman.conf"

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
earlyoom
fakeroot
grub
efibootmgr
bluez
sudo
bash
irqbalance
zram-generator
nano
curl
wget
git
mesa
networkmanager
power-profiles-daemon
xdg-user-dirs
noto-fonts
noto-fonts-emoji
noto-fonts-cjk
bluez-utils
gnome-weather
gnome-clocks
gnome-calculator
sof-firmware
thermald
network-manager-applet
xorg-xwayland
layer-shell-qt
budgie-session
gcc
debugedit
base-devel
wine
wine-mono
lib32-mesa
lib32-vulkan-icd-loader
pkg-config
labwc
sddm
budgie
budgie-desktop-view
budgie-desktop-services
budgie-control-center
swaybg
grim
slurp
swayidle
gtklock
wlopm
wdisplays
nemo
ufw
nemo-fileroller
gnome-terminal
gnome-system-monitor
gnome-disk-utility
gnome-backgrounds
gnome-keyring
gnome-settings-daemon
gvfs
gvfs-mtp
gvfs-smb
file-roller
gedit
eog
evince
papirus-icon-theme
accountsservice
firefox
sassc
network-manager-applet
pipewire
pipewire-pulse
pipewire-alsa
wireplumber
pavucontrol
gparted
ntfs-3g
exfatprogs
polkit
polkit-kde-agent
udisks2
upower
scrot
fastfetch
plymouth
flatpak
xdg-desktop-portal
gnome-software
xdg-desktop-portal-gtk
xdg-desktop-portal-wlr
imagemagick
eglinfo
gnupg
xdotool
v4l2loopback-dkms
PACKAGES

# ══════════════════════════════════════════════════════════════════════════
# mkinitcpio
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
timeout 0
console-mode max
editor no
LOADER

cat > "${PROFILE}/efiboot/loader/entries/kibaos.conf" << 'ENTRY'
title   KibaOS
linux   /arch/boot/x86_64/vmlinuz-linux
initrd  /arch/boot/x86_64/initramfs-linux.img
options archisobasedir=arch archisolabel=KIBAOS cow_spacesize=1G quiet splash nomodeset plymouth.enable=1 rd.plymouth=1
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
  sidebarBackground:    "#f5f8fa"
  sidebarText:          "#1a1a2e"
  sidebarTextSelect:    "#0099cc"
  sidebarTextHighlight: "#0099cc"
windowExpanding:  fullscreen
windowSize:       "1024px,768px"
windowPlacement:  center
sidebar:    none
navigation: none
BRANDING

cat > "${AIROOTFS}/usr/share/calamares/branding/kibaos/stylesheet.qss" << 'QSS'
QWidget {
    background-color: #f0f6fa;
    color: #1a2030;
    font-family: "Noto Sans", "DejaVu Sans", sans-serif;
    font-size: 13px;
}
QStackedWidget, QFrame#mainContent {
    background-color: #ffffff;
    border-radius: 16px;
    border: 1px solid rgba(0,0,0,0.06);
}
QLabel#labelTitle {
    font-size: 24px;
    font-weight: 400;
    color: #0d1b2a;
    padding-top: 24px;
    letter-spacing: 0.5px;
}
QLabel {
    color: #3a4660;
    font-size: 13px;
}
QPushButton#nextButton {
    background-color: #0099cc;
    color: #ffffff;
    border: none;
    border-radius: 12px;
    padding: 10px 36px;
    font-size: 13px;
    font-weight: 600;
    min-width: 120px;
}
QPushButton#nextButton:hover    { background-color: #007aaa; }
QPushButton#nextButton:pressed  { background-color: #005f88; }
QPushButton#nextButton:disabled { background-color: #a8d8ea; }
QPushButton {
    background-color: #eaf4f8;
    color: #0099cc;
    border: 1.5px solid #c5dde8;
    border-radius: 12px;
    padding: 9px 24px;
    font-size: 13px;
    min-width: 90px;
}
QPushButton:hover   { background-color: #d0ecf5; border-color: #0099cc; }
QPushButton:pressed { background-color: #b8e2f0; }
QPushButton:disabled { color: #aabbc8; border-color: #dde8ef; }
QLineEdit, QComboBox {
    background-color: #eaf4f8;
    border: 1.5px solid #c5dde8;
    border-radius: 12px;
    padding: 9px 14px;
    color: #1a2030;
    selection-background-color: #0099cc;
    selection-color: #ffffff;
    font-size: 13px;
}
QLineEdit:focus, QComboBox:focus {
    border: 2px solid #0099cc;
    background-color: #f4fbff;
}
QProgressBar {
    background-color: #d0ecf5;
    border: none;
    border-radius: 5px;
    height: 7px;
}
QProgressBar::chunk {
    background-color: qlineargradient(x1:0, y1:0, x2:1, y2:0,
        stop:0 #0099cc, stop:1 #00bfff);
    border-radius: 5px;
}
QListView, QTreeView {
    background-color: #ffffff;
    border: 1.5px solid #d8e8ef;
    border-radius: 12px;
    alternate-background-color: #f4fafd;
    outline: none;
}
QListView::item:hover, QTreeView::item:hover { background-color: #d8f0fa; }
QListView::item:selected, QTreeView::item:selected {
    background-color: #b0e0f5;
    color: #0d1b2a;
}
QScrollBar:vertical { background: transparent; width: 7px; }
QScrollBar::handle:vertical {
    background: #bbd8e8;
    border-radius: 3px;
    min-height: 28px;
}
QScrollBar::add-line:vertical, QScrollBar::sub-line:vertical { height: 0; }
QToolTip {
    background-color: #0d1b2a;
    color: #e8f4fa;
    border: none;
    border-radius: 8px;
    padding: 5px 10px;
    font-size: 12px;
}
QSS

cat > "${AIROOTFS}/usr/share/calamares/branding/kibaos/show.qml" << 'SHOWQML'
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root; anchors.fill: parent
    property bool activatedInCalamares: false
    property var slides: [
        { heading: "Welcome to KibaOS",       body: "We're setting everything up for you. This usually takes 5 to 10 minutes." },
        { heading: "Built on Arch Linux",     body: "Rolling release. Always the latest software, straight from upstream." },
        { heading: "Budgie 10.10 Wayland",    body: "Fully Wayland-native. Fast, modern, and compositor-agnostic." },
        { heading: "Designed with care",      body: "KibaOS blends the best of DDE, Paper, and Cutefish into one cohesive look." },
        { heading: "Your system, your rules", body: "Full disk encryption, pacman, and the entire AUR at your fingertips." },
        { heading: "KibaOS by WolfTech",      body: "github.com/WolfTech-Innovations/Kiba — guides, wiki, and issue reporting." }
    ]
    property int currentSlide: 0

    Timer {
        interval: 6000; running: root.activatedInCalamares; repeat: true
        onTriggered: root.currentSlide = (root.currentSlide + 1) % root.slides.length
    }

    Rectangle {
        anchors.fill: parent; color: "#f0f6fa"

        Rectangle {
            id: topStrip
            anchors { top: parent.top; left: parent.left; right: parent.right }
            height: parent.height * 0.36
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "#005f88" }
                GradientStop { position: 1.0; color: "#0099cc" }
            }
            Image {
                anchors.centerIn: parent; source: "logo.png"
                width: 88; height: 88
                fillMode: Image.PreserveAspectFit; smooth: true
            }
        }

        Rectangle {
            anchors {
                top: topStrip.bottom; topMargin: -22
                horizontalCenter: parent.horizontalCenter
            }
            width: Math.min(parent.width - 56, 500)
            height: contentCol.implicitHeight + 52
            radius: 20
            color: "#ffffff"

            ColumnLayout {
                id: contentCol
                anchors { top: parent.top; left: parent.left; right: parent.right; margins: 32 }
                spacing: 14

                Text {
                    Layout.alignment: Qt.AlignHCenter; Layout.fillWidth: true
                    text: root.slides[root.currentSlide].heading
                    font.pixelSize: 19; font.weight: Font.Medium
                    color: "#0d1b2a"
                    horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter; Layout.fillWidth: true
                    text: root.slides[root.currentSlide].body
                    font.pixelSize: 13; color: "#4a5a70"
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap; lineHeight: 1.55
                }
                Row {
                    Layout.alignment: Qt.AlignHCenter; spacing: 7
                    Repeater {
                        model: root.slides.length
                        delegate: Rectangle {
                            width: index === root.currentSlide ? 20 : 7
                            height: 7; radius: 3.5
                            color: index === root.currentSlide ? "#0099cc" : "#c5dde8"
                            Behavior on width { NumberAnimation { duration: 200 } }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: root.currentSlide = index
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            id: progressTrack
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: 5; color: "#cde8f5"
            Rectangle {
                anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                width: 0
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "#0099cc" }
                    GradientStop { position: 1.0; color: "#00bfff" }
                }
                radius: 2.5
                SequentialAnimation on width {
                    running: root.activatedInCalamares; loops: Animation.Infinite
                    NumberAnimation { from: 0; to: progressTrack.width * 0.85; duration: 2800; easing.type: Easing.InOutCubic }
                    PauseAnimation  { duration: 500 }
                    NumberAnimation { to: progressTrack.width; duration: 600 }
                    PauseAnimation  { duration: 300 }
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
  - bootloader
  - umount
- show:
  - finished
branding: kibaos
prompt-install: false
dont-chroot: false
CALA_SETTINGS

cat > "${AIROOTFS}/etc/calamares/modules/welcome.conf" << 'WELCOMECONF'
---
showSupportUrl:       true
showKnownIssuesUrl:   true
showReleaseNotesUrl:  false
requirements:
  requiredStorage: 10.0
  requiredRam:     1.0
  internetCheckUrl: http://example.com
  check:
    - storage
    - ram
    - root
  required:
    - storage
    - ram
    - root
geoip:
  style:    "none"
  url:      ""
  selector: ""
WELCOMECONF

cat > "${AIROOTFS}/etc/calamares/modules/unpackfs.conf" << 'UNPACKFS'
---
unpack:
  - source: "/run/archiso/bootmnt/arch/x86_64/airootfs.sfs"
    sourcefs: "squashfs"
    destination: ""
UNPACKFS

cat > "${AIROOTFS}/etc/calamares/modules/displaymanager.conf" << 'DMCONF'
---
displaymanagers:
  - sddm
defaultDesktopEnvironment:
  executable: "budgie-session"
  desktopFile: "budgie-desktop"
basicSetup: false
DMCONF

# ══════════════════════════════════════════════════════════════════════════
# pacman.conf tweaks
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
ln -sf /usr/lib/systemd/system/sddm.service           "${WANTS}/display-manager.service"
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

dbus-uuidgen > /etc/machine-id
eval $(dbus-launch --sh-syntax)
export DBUS_SESSION_BUS_ADDRESS

# ── alpm user ──────────────────────────────────────────────────────────────
useradd -r -s /usr/bin/nologin -U alpm 2>/dev/null || true
mkdir -p /var/cache/pacman/pkg
chmod 755 /var/cache/pacman /var/cache/pacman/pkg
chown -R alpm:alpm /var/cache/pacman
sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' /etc/pacman.conf
pacman -Syy --noconfirm

mkdir -p /etc/calamares/modules/
cat > /etc/calamares/modules/users.conf << 'USERSCONF'
---
defaultGroups:
  - users
  - wheel
  - audio
  - video
  - input
  - network
  - storage
  - power
autologinGroup: autologin
sudoersGroup: wheel
setRootPassword: false
USERSCONF

# ── Silent Wine wrapper ────────────────────────────────────────────────────
cat > /usr/local/bin/wine-silent << 'WINEWRAPPER'
#!/usr/bin/env bash
export WINEDEBUG=-all
export WINEPREFIX="${HOME}/.wine"
export WINEARCH=win64
export QT_QPA_PLATFORM=wayland
export GDK_BACKEND=wayland
if [ ! -d "${WINEPREFIX}" ]; then
  wineboot --init 2>/dev/null
fi
exec wine "$@" 2>/dev/null
WINEWRAPPER
chmod +x /usr/local/bin/wine-silent

systemctl enable earlyoom

cat > /etc/sysctl.d/99-kibaos.conf << 'SYSCTL'
vm.swappiness=10
vm.vfs_cache_pressure=50
vm.dirty_ratio=10
vm.dirty_background_ratio=5
fs.inotify.max_user_watches=524288
net.core.netdev_max_backlog=16384
SYSCTL

mkdir -p /etc/binfmt.d
cat > /etc/binfmt.d/wine.conf << 'BINFMT'
:DOSWin:M::MZ::/usr/local/bin/wine-silent:
BINFMT

mkdir -p /usr/share/applications
cat > /usr/share/applications/wine-exe.desktop << 'WINEDESKTOP'
[Desktop Entry]
Name=Windows Program
Exec=/usr/local/bin/wine-silent %f
MimeType=application/x-ms-dos-executable;application/x-msdos-program;application/x-msdownload;
Type=Application
NoDisplay=true
StartupNotify=false
WINEDESKTOP

mkdir -p /usr/share/mime/packages
cat > /usr/share/mime/packages/wine.xml << 'WINEXML'
<?xml version="1.0" encoding="UTF-8"?>
<mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">
  <mime-type type="application/x-ms-dos-executable">
    <comment>Windows Executable</comment>
    <glob pattern="*.exe"/>
    <glob pattern="*.EXE"/>
    <glob pattern="*.msi"/>
    <glob pattern="*.MSI"/>
  </mime-type>
</mime-info>
WINEXML
update-mime-database /usr/share/mime 2>/dev/null || true

pacman-key --init
pacman-key --populate archlinux
pacman -Syy --noconfirm

sed -i 's/#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
locale-gen
echo 'LANG=en_US.UTF-8' > /etc/locale.conf
echo 'kibaos' > /etc/hostname
cat > /etc/hosts << 'HOSTS'
127.0.0.1   localhost
::1         localhost
127.0.1.1   kibaos.localdomain kibaos
HOSTS

for g in users wheel audio video input network storage power; do
  groupadd -r "$g" 2>/dev/null || true
  usermod -aG "$g" liveuser 2>/dev/null || true
done
echo "liveuser:live" | chpasswd
grep -qx '/bin/bash' /etc/shells || echo '/bin/bash' >> /etc/shells
cp -aT /etc/skel/ /home/liveuser/ 2>/dev/null || true
chown -R 1000:1000 /home/liveuser
chmod 750 /home/liveuser

sed -i 's/#Storage=auto/Storage=volatile/'                    /etc/systemd/journald.conf
sed -i 's/#HandleLidSwitch=suspend/HandleLidSwitch=ignore/'   /etc/systemd/logind.conf
sed -i 's/#HandleSuspendKey=suspend/HandleSuspendKey=ignore/' /etc/systemd/logind.conf

# ══════════════════════════════════════════════════════════════════════════
# BRANDING ASSETS
# ══════════════════════════════════════════════════════════════════════════
WALLPAPER_URL="https://github.com/WolfTech-Innovations/Kiba/blob/2b65c409ad91c34854f530a69ee1c29183689257/branding/forest-k.png?raw=true"
LOGO_URL="https://github.com/WolfTech-Innovations/Kiba/blob/main/branding/boot.png?raw=true"
WALLPAPER_DEST="/usr/share/kibaos/wallpaper.png"
LOGO_SRC="/usr/share/kibaos/logo-raw.png"
LOGO_256="/usr/share/kibaos/logo-256.png"
LOGO_96="/usr/share/kibaos/logo-96.png"
LOGO_48="/usr/share/kibaos/logo-48.png"
LOGO_32="/usr/share/kibaos/logo-32.png"

mkdir -p /usr/share/kibaos /usr/share/pixmaps

curl -fL --retry 5 --retry-delay 3 -o "${WALLPAPER_DEST}" "${WALLPAPER_URL}" || \
  magick -size 1920x1080 gradient:"#003f5c-#0099cc" "${WALLPAPER_DEST}"

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
      -fill '#0099cc' -draw "circle $((sz/2)),$((sz/2)) $((sz/2)),1" \
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
# AUR PACKAGES
# ══════════════════════════════════════════════════════════════════════════
useradd -m -s /bin/bash builduser 2>/dev/null || true
echo 'builduser ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/builduser
sed -i 's/^CheckSpace/#CheckSpace/' /etc/pacman.conf
pacman -S --noconfirm --needed \
  kpmcore python python-yaml python-jsonschema \
  qt5-wayland qt5-xmlpatterns solid kcoreaddons \
  ki18n kio kservice kpackage kdeclarative \
  kiconthemes kwidgetsaddons

AUR_BUILD="/tmp/aur-build"
mkdir -p "${AUR_BUILD}"
for pkg in calamares arc-gtk-theme libinput-gestures; do
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
pacman -Rns --noconfirm gcc base-devel debugedit make patch autoconf automake 2>/dev/null || true
pacman -Qtdq | pacman -Rns --noconfirm - 2>/dev/null || true
echo "=== AUR packages installed ==="

# ══════════════════════════════════════════════════════════════════════════
# PLYMOUTH
# ══════════════════════════════════════════════════════════════════════════
PLYMOUTH_THEME="/usr/share/plymouth/themes/kibaos"
mkdir -p "${PLYMOUTH_THEME}"
SPINNER_SRC="/usr/share/plymouth/themes/spinner"
[ -d "${SPINNER_SRC}" ] && cp -a "${SPINNER_SRC}/." "${PLYMOUTH_THEME}/" && \
  rm -f "${PLYMOUTH_THEME}/spinner.plymouth"

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

magick -size 1920x1080 gradient:"#003f5c-#0d1b2a" "${PLYMOUTH_THEME}/background-tile.png"
cp "${LOGO_256}" "${PLYMOUTH_THEME}/watermark.png"
plymouth-set-default-theme kibaos 2>/dev/null || \
  plymouth-set-default-theme spinner 2>/dev/null || true
mkinitcpio -p linux 2>/dev/null || true
systemctl enable plymouth-start.service      2>/dev/null || true
systemctl enable plymouth-read-write.service 2>/dev/null || true
systemctl enable plymouth-quit-wait.service  2>/dev/null || true
echo "=== Plymouth configured ==="

# ══════════════════════════════════════════════════════════════════════════
# GTK THEME — system-wide Arc-Dark
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

# ── GTK3 pill panel CSS — Budgie panel is GTK3 ────────────────────────────
cat > /etc/gtk-3.0/gtk.css << 'GTK3PANEL'
/* === KibaOS: Floating liquid glass pill panel === */
.budgie-panel {
    margin: 0 120px 8px 120px;
    border-radius: 999px;
    background-image: none;
    background-color: rgba(12, 20, 35, 0.55);
    border-top: 1px solid rgba(255, 255, 255, 0.18);
    border-left: 1px solid rgba(255, 255, 255, 0.10);
    border-right: 1px solid rgba(255, 255, 255, 0.06);
    border-bottom: 1px solid rgba(0, 0, 0, 0.35);
    box-shadow:
        0 8px 40px rgba(0, 0, 0, 0.55),
        0 2px 8px  rgba(0, 0, 0, 0.30),
        inset 0 1px 0 rgba(255, 255, 255, 0.14),
        inset 0 -1px 0 rgba(0, 0, 0, 0.20);
    padding: 0 10px;
}
.budgie-panel .budgie-applet-button,
.budgie-panel button.flat {
    border-radius: 999px;
    background: transparent;
    transition: background 150ms ease;
}
.budgie-panel .budgie-applet-button:hover,
.budgie-panel button.flat:hover {
    background-color: rgba(255, 255, 255, 0.10);
}
.budgie-panel .budgie-applet-button:active,
.budgie-panel button.flat:active {
    background-color: rgba(0, 153, 204, 0.25);
}
.budgie-panel .launcher:checked,
.budgie-panel .launcher.running {
    border-bottom: 2px solid #0099cc;
    border-radius: 0;
}
GTK3PANEL

# ── GTK4 CSS OVERRIDE ─────────────────────────────────────────────────────
mkdir -p /etc/gtk-4.0
cat > /etc/gtk-4.0/gtk.css << 'GTK4CSS'
/* KibaOS unified GTK4 override */
@define-color accent_color #0099cc;
@define-color accent_bg_color #0099cc;
@define-color accent_fg_color #ffffff;
@define-color window_bg_color #1e2430;
@define-color window_fg_color #e8eef5;
@define-color view_bg_color #252c3a;
@define-color view_fg_color #dde5ef;
@define-color card_bg_color #2a3242;
@define-color popover_bg_color #2a3242;
@define-color sidebar_bg_color #1a2030;
@define-color headerbar_bg_color #1a2030;
@define-color headerbar_fg_color #dde5ef;

window, .window-frame          { border-radius: 16px; }
headerbar                      { border-radius: 16px 16px 0 0; }
.card, frame, .frame           { border-radius: 14px; }
button                         { border-radius: 10px; }
entry                          { border-radius: 10px; }
popover > contents             { border-radius: 14px; }
.sidebar-row                   { border-radius: 8px; }
listview                       { border-radius: 12px; }
notebook > header              { border-radius: 12px 12px 0 0; }
button { box-shadow: none; -gtk-icon-shadow: none; }
.suggested-action { background: @accent_bg_color; color: @accent_fg_color; border: none; }
.suggested-action:hover { background: shade(@accent_bg_color, 0.88); }
headerbar { padding: 8px 12px; min-height: 44px; }
row        { padding: 4px 8px; }
GTK4CSS

# ══════════════════════════════════════════════════════════════════════════
# SDDM
# ══════════════════════════════════════════════════════════════════════════
mkdir -p /etc/sddm.conf.d
cat > /etc/sddm.conf.d/kibaos.conf << 'SDDMCONF'
[General]
DisplayServer=wayland

[Wayland]
CompositorCommand=labwc

[Theme]
Current=

[Autologin]
User=liveuser
Session=budgie-desktop
SDDMCONF

mkdir -p /var/lib/sddm
chown sddm:sddm /var/lib/sddm 2>/dev/null || true
chmod 750 /var/lib/sddm

# ══════════════════════════════════════════════════════════════════════════
# LABWC CONFIG
# ══════════════════════════════════════════════════════════════════════════
mkdir -p /etc/xdg/labwc
cat > /etc/xdg/labwc/rc.xml << 'LABWCRC'
<?xml version="1.0"?>
<openbox_config xmlns="http://openbox.org/3.4/rc">
  <core>
    <decoration>server</decoration>
    <gap>6</gap>
    <adaptiveSync>yes</adaptiveSync>
    <allowTearing>no</allowTearing>
    <reuseOutputMode>no</reuseOutputMode>
  </core>
  <theme>
    <name>kibaos</name>
    <cornerRadius>14</cornerRadius>
    <font place="ActiveWindow">
      <name>Noto Sans</name><size>10</size>
      <weight>medium</weight><slant>normal</slant>
    </font>
    <font place="InactiveWindow">
      <name>Noto Sans</name><size>10</size>
      <weight>normal</weight><slant>normal</slant>
    </font>
    <titlebar>
      <layout>:iconify,max,close</layout>
      <showTitle>yes</showTitle>
    </titlebar>
    <dropShadows>yes</dropShadows>
  </theme>
  <snapping>
    <range>8</range><topMaximize>yes</topMaximize>
    <notifyClient>always</notifyClient>
    <overlay><enabled>yes</enabled><delay inner="500" outer="500"/></overlay>
  </snapping>
  <focus><followMouse>no</followMouse><raiseOnFocus>no</raiseOnFocus></focus>
  <workspaces>
    <popupTime>1000</popupTime>
    <names><name>1</name><name>2</name><name>3</name><name>4</name></names>
  </workspaces>
  <windowRules>
    <windowRule identifier="*"><serverDecoration>yes</serverDecoration></windowRule>
    <windowRule type="dock"><serverDecoration>no</serverDecoration><shadow>no</shadow></windowRule>
    <windowRule identifier="*notification*"><serverDecoration>no</serverDecoration><shadow>no</shadow></windowRule>
  </windowRules>
</openbox_config>
LABWCRC

mkdir -p /usr/share/themes/kibaos/openbox-3
cat > /usr/share/themes/kibaos/openbox-3/themerc << 'THEMERC'
border.width: 1
window.client.padding.width: 0
window.client.padding.height: 0
window.active.title.bg:                  Flat solid
window.active.title.bg.color:           #1a2030
window.active.label.text.color:         #e8eef5
window.active.label.text.font:          shadow=no
window.inactive.title.bg:               Flat solid
window.inactive.title.bg.color:        #232b3a
window.inactive.label.text.color:      #6a7a90
window.active.border.color:            #0099cc
window.inactive.border.color:          #3a4455
window.button.width:                     18
window.button.height:                    18
window.button.hover.bg.corner-radius:     9
window.active.button.unpressed.bg:       Flat solid
window.active.button.unpressed.bg.color: #1a2030
window.active.button.unpressed.image.color: #8aacbe
window.active.button.hover.bg:           Flat solid
window.active.button.hover.bg.color:     #0099cc40
window.active.button.hover.image.color:  #e8eef5
window.active.button.pressed.bg:         Flat solid
window.active.button.pressed.bg.color:   #00699990
window.active.button.pressed.image.color: #ffffff
window.inactive.button.unpressed.bg:     Flat solid
window.inactive.button.unpressed.bg.color: #232b3a
window.inactive.button.unpressed.image.color: #4a5a70
shadow.size:          30
shadow.inactive.size: 20
shadow.color:          #00000070
shadow.inactive.color: #00000040
menu.border.width:  1
menu.border.color:  #0099cc30
menu.items.bg.color: #1e2430
menu.items.text.color: #ccdae5
menu.items.active.bg.color: #0099cc
menu.items.active.text.color: #ffffff
menu.separator.color: #2e3a4a
menu.separator.width: 1
menu.separator.padding.width:  4
menu.separator.padding.height: 3
osd.bg:                 Flat solid
osd.bg.color:           #1a2030ee
osd.border.color:       #0099cc60
osd.border.width:       1
osd.label.text.color:   #e8eef5
osd.hilight.bg:         Flat solid
osd.hilight.bg.color:   #0099cc
osd.unhilight.bg:       Flat solid
osd.unhilight.bg.color: #2e3a4a
THEMERC

# ══════════════════════════════════════════════════════════════════════════
# OTA UPDATE SYSTEM
# ══════════════════════════════════════════════════════════════════════════
OTA_PUBKEY_URL="https://raw.githubusercontent.com/WolfTech-Innovations/Kiba/main/ota/ota-public.asc"
OTA_BASE="https://sourceforge.net/projects/kibaos/files/ota"
OTA_KEYRING="/etc/kibaos/ota-keyring.gpg"
mkdir -p /etc/kibaos /var/lib/kibaos-ota /var/log/kibaos

# ── Import OTA public key into dedicated keyring ───────────────────────────
curl -fsSL --retry 3 "${OTA_PUBKEY_URL}" -o /tmp/ota-public.asc 2>/dev/null && \
  gpg --no-default-keyring --keyring "${OTA_KEYRING}" \
      --import /tmp/ota-public.asc 2>/dev/null || true
rm -f /tmp/ota-public.asc

# ── Patch-level tracking ───────────────────────────────────────────────────
echo "0" > /etc/kibaos/patch-level

# ══════════════════════════════════════════════════════════════════════════
# /usr/local/bin/kibaos-ota — the live patching engine
# ══════════════════════════════════════════════════════════════════════════
cat > /usr/local/bin/kibaos-ota << 'OTASCRIPT'
#!/usr/bin/env bash
# KibaOS OTA Live Patch Engine
# Silently downloads, verifies, and applies file-level patches.
# Handles display manager restarts with a framebuffer freeze trick.
# Runs as root via systemd timer — never visible to the user.

set -euo pipefail

OTA_BASE="https://sourceforge.net/projects/kibaos/files/ota"
OTA_KEYRING="/etc/kibaos/ota-keyring.gpg"
PATCH_LEVEL_FILE="/etc/kibaos/patch-level"
OTA_WORKDIR="/var/lib/kibaos-ota"
OTA_LOG="/var/log/kibaos/ota.log"
FREEZE_PID_FILE="/tmp/kibaos-fb-freeze.pid"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "${OTA_LOG}"; }

# ── Check current patch level ──────────────────────────────────────────────
CURRENT=$(cat "${PATCH_LEVEL_FILE}" 2>/dev/null || echo 0)
log "Current patch level: ${CURRENT}"

# ── Fetch latest available patch level ────────────────────────────────────
LATEST=$(curl -fsSL --retry 3 --max-time 10 \
  "${OTA_BASE}/latest-patch-level" 2>/dev/null | tr -d '[:space:]') || {
  log "Could not reach OTA server. Skipping."
  exit 0
}

if ! [[ "${LATEST}" =~ ^[0-9]+$ ]]; then
  log "Invalid patch level received: '${LATEST}'. Skipping."
  exit 0
fi

if [ "${LATEST}" -le "${CURRENT}" ]; then
  log "Already up to date (patch level ${CURRENT})."
  exit 0
fi

log "New patch available: ${CURRENT} → ${LATEST}"

# ── Download patch bundle + signature ─────────────────────────────────────
PATCH_TAR="${OTA_WORKDIR}/kibaos-ota-${LATEST}.tar.gz"
PATCH_SIG="${PATCH_TAR}.asc"
MANIFEST="${OTA_WORKDIR}/manifest-${LATEST}.txt"

mkdir -p "${OTA_WORKDIR}"

log "Downloading patch ${LATEST}..."
curl -fsSL --retry 3 --max-time 120 \
  "${OTA_BASE}/kibaos-ota-${LATEST}.tar.gz" -o "${PATCH_TAR}" || {
  log "Download failed. Skipping."
  exit 0
}
curl -fsSL --retry 3 --max-time 30 \
  "${OTA_BASE}/kibaos-ota-${LATEST}.tar.gz.asc" -o "${PATCH_SIG}" || {
  log "Signature download failed. Aborting for safety."
  rm -f "${PATCH_TAR}"
  exit 1
}
curl -fsSL --retry 3 --max-time 30 \
  "${OTA_BASE}/kibaos-ota-${LATEST}-manifest.txt" -o "${MANIFEST}" || {
  log "Manifest download failed. Aborting."
  rm -f "${PATCH_TAR}" "${PATCH_SIG}"
  exit 1
}

# ── Verify GPG signature ───────────────────────────────────────────────────
log "Verifying signature..."
if ! gpg --no-default-keyring --keyring "${OTA_KEYRING}" \
         --verify "${PATCH_SIG}" "${PATCH_TAR}" 2>/dev/null; then
  log "SIGNATURE VERIFICATION FAILED. Patch rejected. Possible tampering."
  rm -f "${PATCH_TAR}" "${PATCH_SIG}" "${MANIFEST}"
  exit 1
fi
log "Signature verified."

# ── Verify SHA256 checksums from manifest ─────────────────────────────────
log "Verifying checksums..."
EXTRACT_DIR="${OTA_WORKDIR}/patch-${LATEST}"
rm -rf "${EXTRACT_DIR}"
mkdir -p "${EXTRACT_DIR}"
tar xzf "${PATCH_TAR}" -C "${EXTRACT_DIR}"

# manifest format: SHA256  ./path/to/file
while IFS= read -r line; do
  EXPECTED_HASH=$(echo "${line}" | awk '{print $1}')
  FILEPATH=$(echo "${line}" | awk '{print $2}' | sed 's|^\./||')
  ACTUAL_HASH=$(sha256sum "${EXTRACT_DIR}/${FILEPATH}" 2>/dev/null | awk '{print $1}')
  if [ "${EXPECTED_HASH}" != "${ACTUAL_HASH}" ]; then
    log "CHECKSUM MISMATCH for ${FILEPATH}. Aborting."
    rm -rf "${EXTRACT_DIR}" "${PATCH_TAR}" "${PATCH_SIG}" "${MANIFEST}"
    exit 1
  fi
done < "${MANIFEST}"
log "All checksums verified."

# ── Detect whether patch touches display-critical files ───────────────────
NEEDS_DISPLAY_RESTART=false
NEEDS_COMPOSITOR_RESTART=false
while IFS= read -r line; do
  FILEPATH=$(echo "${line}" | awk '{print $2}' | sed 's|^\./||')
  case "${FILEPATH}" in
    etc/sddm*|usr/lib/sddm*|usr/bin/sddm*)
      NEEDS_DISPLAY_RESTART=true ;;
    etc/xdg/labwc*|usr/bin/labwc*)
      NEEDS_COMPOSITOR_RESTART=true ;;
  esac
done < "${MANIFEST}"

# ══════════════════════════════════════════════════════════════════════════
# FRAMEBUFFER FREEZE — makes display restarts invisible to the user
# ══════════════════════════════════════════════════════════════════════════
fb_freeze() {
  log "Freezing display with framebuffer snapshot..."
  # Capture current screen with grim (Wayland screenshot)
  SNAP="/tmp/kibaos-ota-snap.png"
  SNAP_RAW="/tmp/kibaos-ota-snap.raw"
  WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}"
  XDG_RUNTIME_DIR="/run/user/1000"

  # Take screenshot as liveuser
  sudo -u liveuser \
    WAYLAND_DISPLAY="${WAYLAND_DISPLAY}" \
    XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR}" \
    grim "${SNAP}" 2>/dev/null || true

  if [ -f "${SNAP}" ]; then
    # Convert to raw framebuffer format and write to /dev/fb0
    FB_WIDTH=$(cat /sys/class/graphics/fb0/virtual_size 2>/dev/null | cut -d',' -f1 || echo 1920)
    FB_HEIGHT=$(cat /sys/class/graphics/fb0/virtual_size 2>/dev/null | cut -d',' -f2 || echo 1080)
    magick "${SNAP}" -resize "${FB_WIDTH}x${FB_HEIGHT}!" \
      -depth 8 bgr:"${SNAP_RAW}" 2>/dev/null || true
    if [ -f "${SNAP_RAW}" ] && [ -w /dev/fb0 ]; then
      cat "${SNAP_RAW}" > /dev/fb0 2>/dev/null || true
    fi
  fi

  # Emulate mouse movement via uinput to keep cursor alive
  python3 - << 'UINPUT_WIGGLE'
import struct, time, os, fcntl

EV_REL, REL_X, REL_Y = 0x02, 0x00, 0x01
EV_SYN, SYN_REPORT    = 0x00, 0x00

def emit(fd, typ, code, val):
    fd.write(struct.pack('llHHi', 0, 0, typ, code, val))

try:
    UI_SET_EVBIT  = 0x40045564
    UI_SET_RELBIT = 0x40045566
    UINPUT_DEV_SZ = 1452 + 4 * (64 + 64 + 48 + 48)
    UI_DEV_CREATE = 0x5501
    UI_DEV_DESTROY= 0x5502

    fd = open('/dev/uinput', 'wb', buffering=0)
    fcntl.ioctl(fd, UI_SET_EVBIT,  EV_REL)
    fcntl.ioctl(fd, UI_SET_RELBIT, REL_X)
    fcntl.ioctl(fd, UI_SET_RELBIT, REL_Y)
    dev = struct.pack('80sHHIII', b'kibaos-cursor', 0, 0, 0, 0, 0)
    dev = dev.ljust(UINPUT_DEV_SZ, b'\x00')
    fd.write(dev)
    fcntl.ioctl(fd, UI_DEV_CREATE)
    # Wiggle cursor gently every 500ms for up to 30s
    for _ in range(60):
        emit(fd, EV_REL, REL_X,  1)
        emit(fd, EV_SYN, SYN_REPORT, 0)
        time.sleep(0.25)
        emit(fd, EV_REL, REL_X, -1)
        emit(fd, EV_SYN, SYN_REPORT, 0)
        time.sleep(0.25)
    fcntl.ioctl(fd, UI_DEV_DESTROY)
    fd.close()
except Exception:
    pass
UINPUT_WIGGLE
  &
  echo $! > "${FREEZE_PID_FILE}"
  log "Framebuffer freeze active (PID $(cat ${FREEZE_PID_FILE}))."
}

fb_unfreeze() {
  if [ -f "${FREEZE_PID_FILE}" ]; then
    kill "$(cat ${FREEZE_PID_FILE})" 2>/dev/null || true
    rm -f "${FREEZE_PID_FILE}"
  fi
  rm -f /tmp/kibaos-ota-snap.png /tmp/kibaos-ota-snap.raw
  log "Framebuffer freeze released."
}

# ══════════════════════════════════════════════════════════════════════════
# APPLY PATCH — atomic file-by-file replacement
# ══════════════════════════════════════════════════════════════════════════
apply_patch() {
  log "Applying patch ${LATEST}..."
  ROLLBACK_DIR="${OTA_WORKDIR}/rollback-${CURRENT}"
  mkdir -p "${ROLLBACK_DIR}"

  while IFS= read -r line; do
    FILEPATH=$(echo "${line}" | awk '{print $2}' | sed 's|^\./||')
    SRC="${EXTRACT_DIR}/${FILEPATH}"
    DST="/${FILEPATH}"

    [ -f "${SRC}" ] || continue

    # Back up existing file for rollback
    if [ -f "${DST}" ]; then
      BACKUP_PATH="${ROLLBACK_DIR}/${FILEPATH}"
      mkdir -p "$(dirname ${BACKUP_PATH})"
      cp -a "${DST}" "${BACKUP_PATH}"
    fi

    # Atomic replace: write to .ota-tmp then move
    mkdir -p "$(dirname ${DST})"
    cp -a "${SRC}" "${DST}.ota-tmp"
    mv "${DST}.ota-tmp" "${DST}"
    log "  Patched: ${DST}"
  done < "${MANIFEST}"

  log "Patch applied."
}

rollback_patch() {
  ROLLBACK_DIR="${OTA_WORKDIR}/rollback-${CURRENT}"
  log "ROLLING BACK to patch level ${CURRENT}..."
  if [ -d "${ROLLBACK_DIR}" ]; then
    find "${ROLLBACK_DIR}" -type f | while read -r BACKUP; do
      FILEPATH="${BACKUP#${ROLLBACK_DIR}/}"
      DST="/${FILEPATH}"
      mkdir -p "$(dirname ${DST})"
      cp -a "${BACKUP}" "${DST}"
    done
    log "Rollback complete."
  else
    log "No rollback data found. Cannot roll back."
  fi
}

# ── Restart compositor silently if needed ─────────────────────────────────
restart_compositor() {
  log "Restarting compositor (labwc)..."
  LIVE_UID=1000
  sudo -u liveuser \
    WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}" \
    XDG_RUNTIME_DIR="/run/user/${LIVE_UID}" \
    labwc --reconfigure 2>/dev/null || \
  pkill -HUP labwc 2>/dev/null || true
  sleep 1
  log "Compositor restarted."
}

# ── Restart display manager silently if needed ────────────────────────────
restart_display_manager() {
  log "Restarting SDDM..."
  systemctl restart sddm
  # Wait for Wayland socket to come back
  for i in $(seq 1 20); do
    [ -S "/run/user/1000/${WAYLAND_DISPLAY:-wayland-0}" ] && break
    sleep 0.5
  done
  log "SDDM restarted."
}

# ── Post-patch hooks ───────────────────────────────────────────────────────
run_post_hooks() {
  log "Running post-patch hooks..."
  # Re-apply GTK icon cache if icons changed
  grep -q 'usr/share/icons' "${MANIFEST}" && \
    gtk-update-icon-cache /usr/share/icons/hicolor/ 2>/dev/null || true
  # Recompile GLib schemas if any changed
  grep -q 'usr/share/glib-2.0/schemas' "${MANIFEST}" && \
    glib-compile-schemas /usr/share/glib-2.0/schemas/ 2>/dev/null || true
  # Update MIME database if mime packages changed
  grep -q 'usr/share/mime' "${MANIFEST}" && \
    update-mime-database /usr/share/mime 2>/dev/null || true
  # Reload systemd units if any changed
  grep -q 'usr/lib/systemd' "${MANIFEST}" && \
    systemctl daemon-reload 2>/dev/null || true
  log "Post-patch hooks complete."
}

# ══════════════════════════════════════════════════════════════════════════
# MAIN EXECUTION
# ══════════════════════════════════════════════════════════════════════════

# Freeze display if we're going to restart anything visible
if ${NEEDS_DISPLAY_RESTART} || ${NEEDS_COMPOSITOR_RESTART}; then
  fb_freeze
fi

# Apply patch with rollback on failure
if ! apply_patch; then
  log "Patch application failed. Initiating rollback."
  rollback_patch
  fb_unfreeze
  exit 1
fi

# Run post-patch hooks
if ! run_post_hooks; then
  log "Post-patch hooks failed. Initiating rollback."
  rollback_patch
  fb_unfreeze
  exit 1
fi

# Restart services as needed
if ${NEEDS_COMPOSITOR_RESTART}; then
  restart_compositor
fi
if ${NEEDS_DISPLAY_RESTART}; then
  restart_display_manager
fi

# Unfreeze display
if ${NEEDS_DISPLAY_RESTART} || ${NEEDS_COMPOSITOR_RESTART}; then
  fb_unfreeze
fi

# Commit new patch level
echo "${LATEST}" > "${PATCH_LEVEL_FILE}"
log "Successfully updated to patch level ${LATEST}."

# Cleanup
rm -rf "${EXTRACT_DIR}" "${PATCH_TAR}" "${PATCH_SIG}" "${MANIFEST}"
log "Done."
OTASCRIPT
chmod +x /usr/local/bin/kibaos-ota

# ── systemd service + timer for OTA ───────────────────────────────────────
cat > /etc/systemd/system/kibaos-ota.service << 'OTASVC'
[Unit]
Description=KibaOS OTA Live Patch Engine
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/kibaos-ota
StandardOutput=append:/var/log/kibaos/ota.log
StandardError=append:/var/log/kibaos/ota.log
OTASVC

cat > /etc/systemd/system/kibaos-ota.timer << 'OTATIMER'
[Unit]
Description=KibaOS OTA patch check every 30 minutes

[Timer]
OnBootSec=5min
OnUnitActiveSec=30min
RandomizedDelaySec=3min
Persistent=true

[Install]
WantedBy=timers.target
OTATIMER

systemctl enable kibaos-ota.timer

# ══════════════════════════════════════════════════════════════════════════
# SKELETON
# ══════════════════════════════════════════════════════════════════════════
SKEL="/etc/skel"
mkdir -p \
  "${SKEL}/.config/gtk-3.0" \
  "${SKEL}/.config/gtk-4.0" \
  "${SKEL}/.config/autostart" \
  "${SKEL}/.config/fastfetch"

cat > "${SKEL}/.config/autostart/nemo-desktop.desktop" << 'NEMODESKTOP'
[Desktop Entry]
Type=Application
Name=Nemo Desktop
Exec=nemo-desktop
Hidden=false
NoDisplay=true
X-GNOME-Autostart-enabled=true
NEMODESKTOP

cat > "${SKEL}/.config/gtk-3.0/settings.ini" << 'GTK3SKEL'
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
GTK3SKEL

cp /etc/gtk-3.0/gtk.css "${SKEL}/.config/gtk-3.0/gtk.css"
cp /etc/gtk-4.0/gtk.css "${SKEL}/.config/gtk-4.0/gtk.css"

cat > "${SKEL}/.gtkrc-2.0" << 'GTK2SKEL'
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
GTK2SKEL

dconf write /com/solus-project/budgie/panel/panels "@as []"
cat > /usr/share/glib-2.0/schemas/99-kibaos-budgie.gschema.override << 'EOF'
[com.solus-project.budgie.panel]
panels=@as []
EOF
glib-compile-schemas /usr/share/glib-2.0/schemas/

# ══════════════════════════════════════════════════════════════════════════
# FIRST-LOGIN SCRIPT
# ══════════════════════════════════════════════════════════════════════════
cat > /usr/local/bin/kibaos-first-login << 'FIRSTLOGIN'
#!/usr/bin/env bash
STAMP="${HOME}/.config/.kibaos-configured"
[ -f "${STAMP}" ] && exit 0

gsettings set org.gnome.desktop.interface gtk-theme               'Arc-Dark'
gsettings set org.gnome.desktop.interface icon-theme              'Papirus-Dark'
gsettings set org.gnome.desktop.interface cursor-theme            'Adwaita'
gsettings set org.gnome.desktop.interface cursor-size             24
gsettings set org.gnome.desktop.interface font-name               'Noto Sans 11'
gsettings set org.gnome.desktop.interface document-font-name      'Noto Sans 11'
gsettings set org.gnome.desktop.interface monospace-font-name     'Noto Sans Mono 11'
gsettings set org.gnome.desktop.interface color-scheme            'prefer-dark'
gsettings set org.gnome.desktop.interface enable-animations       true
gsettings set org.gnome.desktop.interface text-scaling-factor     1.0

gsettings set org.gnome.desktop.background picture-uri      'file:///usr/share/kibaos/wallpaper.png'
gsettings set org.gnome.desktop.background picture-uri-dark 'file:///usr/share/kibaos/wallpaper.png'
gsettings set org.gnome.desktop.background picture-options  'zoom'
gsettings set org.gnome.desktop.background primary-color    '#0d1b2a'

gsettings set org.gnome.desktop.wm.preferences button-layout               'close,minimize,maximize:'
gsettings set org.gnome.desktop.wm.preferences titlebar-font               'Noto Sans Medium 10'
gsettings set org.gnome.desktop.wm.preferences action-double-click-titlebar 'toggle-maximize'
gsettings set org.gnome.desktop.wm.preferences num-workspaces               4
gsettings set org.gnome.desktop.wm.preferences focus-mode                  'click'

gsettings set org.gnome.desktop.peripherals.touchpad tap-to-click                true
gsettings set org.gnome.desktop.peripherals.touchpad natural-scroll               true
gsettings set org.gnome.desktop.peripherals.touchpad two-finger-scrolling-enabled true
gsettings set org.gnome.desktop.peripherals.mouse    natural-scroll               false
gsettings set org.gnome.desktop.peripherals.mouse    accel-profile                'adaptive'

gsettings set org.nemo.desktop show-desktop-icons              true
gsettings set org.nemo.desktop ignored-desktop-handlers        "['budgie-helper']"
gsettings set org.nemo.preferences show-hidden-files           false
gsettings set org.nemo.preferences default-folder-viewer       'icon-view'
gsettings set org.nemo.icon-view default-zoom-level            'standard'
gsettings set org.nemo.preferences show-location-entry         false

PANEL_UUID=$(gsettings get com.solus-project.budgie.panel panels 2>/dev/null | \
  tr -d "[]' " | cut -d',' -f1)
if [ -n "${PANEL_UUID}" ]; then
  PANEL_PATH="/com/solus-project/budgie/panel/panels/${PANEL_UUID}/"
  dconf write "${PANEL_PATH}position"              "'BOTTOM'"
  dconf write "${PANEL_PATH}size"                  "42"
  dconf write "${PANEL_PATH}transparency"          "'DYNAMIC'"
  dconf write "${PANEL_PATH}shadow"                "true"
  dconf write "${PANEL_PATH}enable-built-in-theme" "false"
fi

touch "${STAMP}"
FIRSTLOGIN
chmod +x /usr/local/bin/kibaos-first-login

cat > "${SKEL}/.config/autostart/kibaos-configure.desktop" << 'AUTOCFG'
[Desktop Entry]
Type=Application
Name=KibaOS First Login Setup
Exec=/usr/local/bin/kibaos-first-login
Hidden=false
NoDisplay=true
X-GNOME-Autostart-enabled=true
AUTOCFG

mkdir -p /etc/systemd/zram-generator.conf.d
cat > /etc/systemd/zram-generator.conf << 'ZRAM'
[zram0]
zram-size = ram / 2
compression-algorithm = zstd
ZRAM

mkdir -p "${SKEL}/.config/labwc"
cat > "${SKEL}/.config/labwc/environment" << 'LABWCENV'
GTK_THEME=Arc-Dark
QT_STYLE_OVERRIDE=kvantum
XCURSOR_THEME=Adwaita
XCURSOR_SIZE=24
QT_AUTO_SCREEN_SCALE_FACTOR=1
MOZ_ENABLE_WAYLAND=1
WINEDEBUG=-all
LABWCENV

mkdir -p "${SKEL}/.config"
cat > "${SKEL}/.config/libinput-gestures.conf" << 'GESTURES'
gesture swipe left  3  dbus-send --session --type=method_call \
  --dest=org.gnome.Shell /org/gnome/Shell \
  org.gnome.Shell.Eval string:'Main.wm.actionMoveWorkspaceRight()'
gesture swipe right 3  dbus-send --session --type=method_call \
  --dest=org.gnome.Shell /org/gnome/Shell \
  org.gnome.Shell.Eval string:'Main.wm.actionMoveWorkspaceLeft()'
gesture swipe up    4  /usr/local/bin/kibaos-expose
gesture pinch in    2  xdotool key super+d
GESTURES

mkdir -p "${SKEL}/.config/fontconfig"
cat > "${SKEL}/.config/fontconfig/fonts.conf" << 'FONTCONF'
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
  <match target="font">
    <edit name="antialias" mode="assign"><bool>true</bool></edit>
    <edit name="hinting" mode="assign"><bool>true</bool></edit>
    <edit name="hintstyle" mode="assign"><const>hintslight</const></edit>
    <edit name="rgba" mode="assign"><const>rgb</const></edit>
    <edit name="lcdfilter" mode="assign"><const>lcddefault</const></edit>
    <edit name="embeddedbitmap" mode="assign"><bool>false</bool></edit>
  </match>
  <alias>
    <family>sans-serif</family>
    <prefer><family>Noto Sans</family></prefer>
  </alias>
  <alias>
    <family>monospace</family>
    <prefer><family>Noto Sans Mono</family></prefer>
  </alias>
</fontconfig>
FONTCONF

cat > "${SKEL}/.config/electron-flags.conf" << 'ELECTRONFLAGS'
--enable-features=UseOzonePlatform
--ozone-platform=wayland
--enable-wayland-ime
ELECTRONFLAGS

cat > "${SKEL}/.config/chrome-flags.conf" << 'CHROMEFLAGS'
--enable-features=UseOzonePlatform
--ozone-platform=wayland
CHROMEFLAGS

cat > "${SKEL}/.config/autostart/polkit-agent.desktop" << 'POLKIT'
[Desktop Entry]
Type=Application
Name=Polkit Authentication Agent
Exec=/usr/lib/polkit-kde-authentication-agent-1
Hidden=false
NoDisplay=true
X-GNOME-Autostart-enabled=true
POLKIT

cat > "${SKEL}/.config/autostart/libinput-gestures.desktop" << 'GESTURESAUTO'
[Desktop Entry]
Type=Application
Name=Libinput Gestures
Exec=libinput-gestures-setup start
Hidden=false
NoDisplay=true
X-GNOME-Autostart-enabled=true
GESTURESAUTO

cat > "${SKEL}/.config/autostart/kiba-welcome.desktop" << 'WELCOME_AUTO'
[Desktop Entry]
Type=Application
Name=KibaOS Welcome
Exec=/usr/local/bin/kiba-welcome
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
WELCOME_AUTO

cat > "${SKEL}/.bashrc" << 'BASHRC'
[[ $- != *i* ]] && return
PS1='\[\e[1;36m\][KibaOS]\[\e[0m\] \[\e[32m\]\u@\h\[\e[0m\]:\[\e[34m\]\w\[\e[0m\]\$ '
alias ls='ls --color=auto'
alias ll='ls -lah --color=auto'
alias grep='grep --color=auto'
alias install='sudo calamares'
alias update='sudo pacman -Syu'
fastfetch 2>/dev/null || true
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_STATE_HOME="$HOME/.local/state"
export WINEPREFIX="$XDG_DATA_HOME/wine"
export HISTFILE="$XDG_STATE_HOME/bash/history"
BASHRC

mkdir -p "${SKEL}/.config/fastfetch"
cat > "${SKEL}/.config/fastfetch/config.jsonc" << 'FFCONF'
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

cp -aT "${SKEL}/" /home/liveuser/
chown -R 1000:1000 /home/liveuser
chmod 750 /home/liveuser

ufw default deny incoming
ufw default allow outgoing
ufw enable
systemctl enable ufw

# ══════════════════════════════════════════════════════════════════════════
# DESKTOP SHORTCUTS
# ══════════════════════════════════════════════════════════════════════════
mkdir -p /usr/share/applications /etc/skel/Desktop
cat > /etc/skel/.config/user-dirs.dirs << 'USERDIRS'
XDG_DESKTOP_DIR="$HOME/Desktop"
XDG_DOWNLOAD_DIR="$HOME/Downloads"
XDG_DOCUMENTS_DIR="$HOME/Documents"
XDG_PICTURES_DIR="$HOME/Pictures"
USERDIRS

cat > /usr/share/applications/kibaos-install.desktop << 'INSTDESK'
[Desktop Entry]
Name=Install KibaOS
Comment=Install KibaOS to your hard drive
Exec=/usr/local/bin/calamares-launch
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

mkdir -p /home/liveuser/Desktop
for src_desktop in kibaos-install kibaos-about; do
  cp "/usr/share/applications/${src_desktop}.desktop" \
     "/home/liveuser/Desktop/${src_desktop}.desktop" 2>/dev/null || true
  chmod +x "/home/liveuser/Desktop/${src_desktop}.desktop" 2>/dev/null || true
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
  :root {
    --accent: #0099cc; --accent-dark: #0077aa; --bg: #f0f6fa;
    --surface: #fff; --surface-2: #f7fbfd; --text: #0d1b2a;
    --sub: #4a5a70; --border: #d4e8f2;
    --shadow: 0 4px 24px rgba(0,100,160,0.10);
  }
  * { margin:0; padding:0; box-sizing:border-box; }
  body { font-family:'Noto Sans',system-ui,sans-serif; background:var(--bg); color:var(--text); }
  header {
    background: linear-gradient(135deg, #003f5c 0%, #0077aa 60%, #0099cc 100%);
    color:#fff; padding:52px 32px 72px; text-align:center;
  }
  header h1 { font-size:2.2rem; font-weight:300; letter-spacing:1px; }
  header p  { font-size:1rem; opacity:.72; margin-top:8px; }
  .card-row { display:flex; gap:18px; flex-wrap:wrap; padding:28px 32px; max-width:920px; margin:-32px auto 0; }
  .card {
    background:var(--surface); border-radius:18px; padding:24px 22px;
    flex:1; min-width:200px; box-shadow:var(--shadow); border:1px solid var(--border);
    transition: transform .15s, box-shadow .15s; cursor: pointer;
  }
  .card:hover, .card:focus-visible { transform:translateY(-3px); box-shadow:0 8px 32px rgba(0,100,160,0.14); }
  .card:focus-visible { outline: 2px solid var(--accent); outline-offset: 2px; }
  .card:active { transform: scale(0.98); transition: transform 0s; }
  .card h2 { font-size:1rem; font-weight:600; margin-bottom:6px; color:var(--text); }
  .card p  { font-size:.88rem; color:var(--sub); line-height:1.55; }
  section { max-width:920px; margin:0 auto; padding:4px 32px 40px; }
  section h2 { font-size:1.2rem; font-weight:600; margin:28px 0 12px; color:var(--accent); }
  .tip { background:#e6f6fc; border-left:3px solid var(--accent); border-radius:0 10px 10px 0; padding:14px 18px; margin-top:10px; font-size:.9rem; }
  .tip code { background:#cde8f5; padding:2px 7px; border-radius:5px; font-family:'Noto Sans Mono',monospace; font-size:.88em; }
  .btn { display:inline-block; background:var(--accent); color:#fff; border-radius:10px; padding:9px 20px; text-decoration:none; font-size:.88rem; font-weight:600; margin:6px 6px 0 0; transition: background .12s, transform .1s; }
  .btn:hover { background:var(--accent-dark); }
  .btn:focus-visible { outline: 2px solid var(--accent); outline-offset: 2px; }
  .btn:active { transform: scale(0.96); transition: transform 0s; }
  .btn.secondary { background:var(--surface); color:var(--accent); border:1.5px solid var(--border); }
  .btn.secondary:hover { background:#e6f6fc; }
  .design-pills { display:flex; gap:10px; flex-wrap:wrap; margin-top:10px; }
  .pill { background:var(--surface-2); border:1px solid var(--border); border-radius:100px; padding:5px 14px; font-size:.82rem; color:var(--sub); }
  footer { text-align:center; padding:24px; color:var(--sub); font-size:.8rem; border-top:1px solid var(--border); margin-top:16px; }
</style>
</head>
<body>
<header>
  <h1>Welcome to KibaOS</h1>
  <p>A fast, polished Budgie desktop built on Arch Linux — by WolfTech Innovations</p>
</header>
<div class="card-row">
  <div class="card" tabindex="0" aria-label="Feature: Budgie 10.10 Wayland - Fully Wayland-native window management"><h2>Budgie 10.10 Wayland</h2><p>Fully Wayland-native. Powered by labwc for smooth, compositor-agnostic window management.</p></div>
  <div class="card" tabindex="0" aria-label="Feature: Built on Arch Linux - Rolling release with full AUR access"><h2>Built on Arch Linux</h2><p>Rolling release. Always the latest software, straight from upstream with full AUR access.</p></div>
  <div class="card" tabindex="0" aria-label="Feature: Unified Design - Inspired by DDE, Paper DE, and Cutefish aesthetics"><h2>Unified Design</h2><p>Inspired by DDE's curves, Paper's flat surfaces, and Cutefish's airy, floating aesthetic.</p></div>
  <div class="card" tabindex="0" aria-label="Feature: Private by Default - No telemetry and full disk encryption support"><h2>Private by Default</h2><p>Full disk encryption support. No telemetry. Your data stays yours.</p></div>
</div>
<section>
  <h2>Ready to Install?</h2>
  <p>Click <strong>Install KibaOS</strong> on the desktop, or run:</p>
  <div class="tip"><code>sudo calamares</code></div>
  <br>
  <a class="btn" href="https://github.com/WolfTech-Innovations/Kiba/blob/main/WIKI.md" target="_blank" rel="noopener noreferrer" aria-label="Visit the KibaOS Wiki (opens in a new tab)">Wiki</a>
  <a class="btn secondary" href="https://github.com/WolfTech-Innovations/Kiba/issues" target="_blank" rel="noopener noreferrer" aria-label="Report an issue on GitHub (opens in a new tab)">Report Issue</a>
  <a class="btn secondary" href="https://github.com/WolfTech-Innovations/Kiba" target="_blank" rel="noopener noreferrer" aria-label="View the KibaOS source code on GitHub (opens in a new tab)">GitHub</a>
  <h2>Design Language</h2>
  <p>KibaOS's visual identity draws from three reference desktops:</p>
  <div class="design-pills">
    <span class="pill">DDE — smooth rounded corners, cohesive icon language, dark navy base</span>
    <span class="pill">Paper DE — flat material surfaces, colored accents, minimal depth shadows</span>
    <span class="pill">Cutefish — floating dock, translucent panels, generous whitespace, airy cards</span>
  </div>
</section>
<footer>KibaOS Rolling — WolfTech Innovations — github.com/WolfTech-Innovations/Kiba</footer>
</body>
</html>
WELCOMEHTML

# ══════════════════════════════════════════════════════════════════════════
# SYSTEM ENVIRONMENT
# ══════════════════════════════════════════════════════════════════════════
cat > /etc/environment << 'ENV'
DESKTOP_SESSION=budgie-desktop
XDG_CURRENT_DESKTOP=Budgie:GNOME
XDG_SESSION_DESKTOP=budgie-desktop
XDG_SESSION_TYPE=wayland
QT_AUTO_SCREEN_SCALE_FACTOR=1
QT_QPA_PLATFORM=wayland
QT_WAYLAND_SHELL_INTEGRATION=layer-shell
GTK_THEME=Arc-Dark
MOZ_ENABLE_WAYLAND=1
ELECTRON_OZONE_PLATFORM_HINT=wayland
CLUTTER_BACKEND=wayland
SDL_VIDEODRIVER=wayland
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

  KibaOS Rolling — Budgie 10.10 Wayland Edition — WolfTech Innovations
  Live session: user=liveuser  password=live
  Install: click the desktop icon or run  sudo calamares

ISSUE

cat > /etc/motd << 'MOTD'
Welcome to KibaOS — Budgie 10.10 Wayland desktop on Arch Linux.
Built by WolfTech Innovations.  https://github.com/WolfTech-Innovations/Kiba
MOTD

cat > /usr/local/bin/calamares-launch << 'EOF'
#!/usr/bin/env bash
LIVE_UID=1000
LIVE_RUNTIME="/run/user/${LIVE_UID}"
exec sudo -E \
  WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}" \
  XDG_RUNTIME_DIR="${LIVE_RUNTIME}" \
  QT_QPA_PLATFORM=wayland \
  QT_WAYLAND_SHELL_INTEGRATION=layer-shell \
  /usr/bin/calamares
EOF
chmod +x /usr/local/bin/calamares-launch

systemctl enable sddm
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
systemctl enable NetworkManager

install -d -m 755 -o 1000 -g 1000 /home/liveuser/.config/dconf
sudo -u liveuser dbus-run-session -- bash -c '
  dconf write /com/solus-project/budgie/panel/panels "@as []"
  dconf write /com/solus-project/budgie/panel/panels-changed "$(date +%s)"
'
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
