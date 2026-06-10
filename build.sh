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
# Start dbus session for the whole script
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
mkdir -p /etc/xdg/crystal-dock
cat > /etc/xdg/crystal-dock/General.conf << 'CDCONF'
[General]
autoHide=false
showTaskManager=true
showClock=true
showDesktop=true
position=Bottom
screenEdgeMargin=8
iconSize=52
minIconSize=32
maxIconSize=72
backgroundAlpha=180
tooltipDelay=300
CDCONF

# ── Silent Wine wrapper ────────────────────────────────────────────────────
cat > /usr/local/bin/wine-silent << 'WINEWRAPPER'
#!/usr/bin/env bash
# Transparent .exe launcher — zero fingerprint, no console noise
export WINEDEBUG=-all
export WINEPREFIX="${HOME}/.wine"
export WINEARCH=win64
export QT_QPA_PLATFORM=wayland
export GDK_BACKEND=wayland
# Init prefix silently on first run
if [ ! -d "${WINEPREFIX}" ]; then
  wineboot --init 2>/dev/null
fi

exec wine "$@" 2>/dev/null
WINEWRAPPER
chmod +x /usr/local/bin/wine-silent
systemctl enable earlyoom
cat > /etc/sysctl.d/99-kibaos.conf << 'SYSCTL'
# Prefer keeping apps in RAM over disk cache — desktop feel
vm.swappiness=10
vm.vfs_cache_pressure=50
# Reduce dirty page writeback latency — snappier file saves
vm.dirty_ratio=10
vm.dirty_background_ratio=5
# More inotify watches — needed for IDEs, file managers, large projects
fs.inotify.max_user_watches=524288
# Faster network
net.core.netdev_max_backlog=16384
SYSCTL
# ── binfmt_misc: .exe files run transparently via wine-silent ──────────────
mkdir -p /etc/binfmt.d
cat > /etc/binfmt.d/wine.conf << 'BINFMT'
:DOSWin:M::MZ::/usr/local/bin/wine-silent:
BINFMT

# ── Nemo file association: double-click .exe → wine-silent ─────────────────
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

# Register MIME type
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

echo "=== Downloading KibaOS wallpaper ==="
curl -fL --retry 5 --retry-delay 3 -o "${WALLPAPER_DEST}" "${WALLPAPER_URL}" || \
  magick -size 1920x1080 gradient:"#003f5c-#0099cc" "${WALLPAPER_DEST}"

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
# AUR PACKAGES: calamares + arc-gtk-theme
# ══════════════════════════════════════════════════════════════════════════
useradd -m -s /bin/bash builduser 2>/dev/null || true
echo 'builduser ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/builduser
sed -i 's/^CheckSpace/#CheckSpace/' /etc/pacman.conf
# Before building calamares in customize_airootfs.sh, ensure deps:
pacman -S --noconfirm --needed \
  kpmcore \
  python \
  python-yaml \
  python-jsonschema \
  qt5-wayland \
  qt5-xmlpatterns \
  solid \
  kcoreaddons \
  ki18n \
  kio \
  kservice \
  kpackage \
  kdeclarative \
  kiconthemes \
  kwidgetsaddons \
  kpmcore
AUR_BUILD="/tmp/aur-build"
mkdir -p "${AUR_BUILD}"
for pkg in calamares arc-gtk-theme crystal-dock-git libinput-gestures; do
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
pacman -Rns --noconfirm \
    gcc \
    base-devel \
    debugedit \
    make \
    patch \
    autoconf \
    automake
pacman -Qtdq | pacman -Rns --noconfirm -
echo "=== AUR packages installed ==="

echo "=== Darling userspace installed, DKMS module staged for first boot ==="
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

magick -size 1920x1080 \
  gradient:"#003f5c-#0d1b2a" \
  "${PLYMOUTH_THEME}/background-tile.png"

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

# ══════════════════════════════════════════════════════════════════════════
# GTK4 CSS OVERRIDE
# ══════════════════════════════════════════════════════════════════════════
mkdir -p /etc/gtk-4.0
cat > /etc/gtk-4.0/gtk.css << 'GTK4CSS'
/* KibaOS unified GTK4 override — DDE+Paper+Cutefish fusion */

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
/* === KibaOS: Floating pill panel === */

/* The outer container — give it breathing room from screen edges */
.budgie-panel {
    margin: 6px 12px;              /* lifts it off the bottom edge */
    border-radius: 999px;          /* full pill shape */
    background-image: none;
    background-color: rgba(15, 22, 38, 0.72);  /* semi-transparent navy */
    border: 1px solid rgba(0, 153, 204, 0.18); /* subtle cyan rim */
    box-shadow:
        0 4px 32px rgba(0, 0, 0, 0.45),
        inset 0 1px 0 rgba(255,255,255,0.06);  /* inner highlight = glass depth */
    padding: 0 8px;
}

/* Applet buttons inside the panel */
.budgie-panel .budgie-applet-button,
.budgie-panel button.flat {
    border-radius: 999px;
    background: transparent;
    transition: background 0.15s ease;
}
.budgie-panel .budgie-applet-button:hover,
.budgie-panel button.flat:hover {
    background: rgba(0, 153, 204, 0.15);
}
.budgie-panel .budgie-applet-button:active,
.budgie-panel button.flat:active {
    background: rgba(0, 153, 204, 0.28);
}

/* Active window indicators (tasklist underlines) */
.budgie-panel .launcher:checked,
.budgie-panel .launcher.running {
    border-bottom: 2px solid #0099cc;
    border-radius: 0;
}
window, .window-frame          { border-radius: 16px; }
headerbar                      { border-radius: 16px 16px 0 0; }
.card, frame, .frame           { border-radius: 14px; }
button                         { border-radius: 10px; }
entry                          { border-radius: 10px; }
popover > contents             { border-radius: 14px; }
.sidebar-row                   { border-radius: 8px; }
listview                       { border-radius: 12px; }
notebook > header              { border-radius: 12px 12px 0 0; }

button {
    box-shadow: none;
    -gtk-icon-shadow: none;
}
.suggested-action {
    background: @accent_bg_color;
    color: @accent_fg_color;
    border: none;
}
.suggested-action:hover { background: shade(@accent_bg_color, 0.88); }

headerbar { padding: 8px 12px; min-height: 44px; }
row        { padding: 4px 8px; }
GTK4CSS

# ══════════════════════════════════════════════════════════════════════════
# SDDM CONFIGURATION
# FIX: [Wayland] CompositorCommand=labwc added — without this SDDM in
# Wayland mode produces a black screen with a blinking underscore cursor
# and never starts the greeter.
# FIX: /var/lib/sddm created and owned — required for greeter user.
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
# Uncomment for instant live-session boot:
User=liveuser
Session=budgie-desktop
SDDMCONF

mkdir -p /var/lib/sddm
chown sddm:sddm /var/lib/sddm 2>/dev/null || true
chmod 750 /var/lib/sddm

# ══════════════════════════════════════════════════════════════════════════
# LABWC CONFIG
# Placed in /etc/xdg/labwc/ as a system-wide default.
# Budgie's labwc-bridge overlays ~/.config/budgie-desktop/labwc/ on top,
# so Budgie keybinds still take precedence.
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
      <name>Noto Sans</name>
      <size>10</size>
      <weight>medium</weight>
      <slant>normal</slant>
    </font>
    <font place="InactiveWindow">
      <name>Noto Sans</name>
      <size>10</size>
      <weight>normal</weight>
      <slant>normal</slant>
    </font>
    <titlebar>
      <layout>:iconify,max,close</layout>
      <showTitle>yes</showTitle>
    </titlebar>
    <dropShadows>yes</dropShadows>
  </theme>

  <snapping>
    <range>8</range>
    <topMaximize>yes</topMaximize>
    <notifyClient>always</notifyClient>
    <overlay>
      <enabled>yes</enabled>
      <delay inner="500" outer="500"/>
    </overlay>
  </snapping>

  <focus>
    <followMouse>no</followMouse>
    <raiseOnFocus>no</raiseOnFocus>
  </focus>

  <workspaces>
    <popupTime>1000</popupTime>
    <names>
      <name>1</name>
      <name>2</name>
      <name>3</name>
      <name>4</name>
    </names>
  </workspaces>

  <windowRules>
    <windowRule identifier="*">
      <serverDecoration>yes</serverDecoration>
    </windowRule>
    <windowRule type="dock">
      <serverDecoration>no</serverDecoration>
      <shadow>no</shadow>
    </windowRule>
    <windowRule identifier="*notification*">
      <serverDecoration>no</serverDecoration>
      <shadow>no</shadow>
    </windowRule>
  </windowRules>

</openbox_config>
LABWCRC

mkdir -p /usr/share/themes/kibaos/openbox-3

cat > /usr/share/themes/kibaos/openbox-3/themerc << 'THEMERC'
# KibaOS labwc theme — DDE+Paper+Cutefish fusion

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
# SKELETON — every new account created by Calamares or adduser inherits
# the full KibaOS theme without a settings app.
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
# Sets gsettings on first login. Runs once via autostart, stamps ~/.config.
# ══════════════════════════════════════════════════════════════════════════
cat > /usr/local/bin/kibaos-first-login << 'FIRSTLOGIN'
#!/usr/bin/env bash
STAMP="${HOME}/.config/.kibaos-configured"
[ -f "${STAMP}" ] && exit 0

# ── Appearance ─────────────────────────────────────────────────────────────
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

# ── Wallpaper ──────────────────────────────────────────────────────────────
gsettings set org.gnome.desktop.background picture-uri      'file:///usr/share/kibaos/wallpaper.png'
gsettings set org.gnome.desktop.background picture-uri-dark 'file:///usr/share/kibaos/wallpaper.png'
gsettings set org.gnome.desktop.background picture-options  'zoom'
gsettings set org.gnome.desktop.background primary-color    '#0d1b2a'

# ── Window manager — macOS feel ────────────────────────────────────────────
gsettings set org.gnome.desktop.wm.preferences button-layout               'close,minimize,maximize:'
gsettings set org.gnome.desktop.wm.preferences titlebar-font               'Noto Sans Medium 10'
gsettings set org.gnome.desktop.wm.preferences action-double-click-titlebar 'toggle-maximize'
gsettings set org.gnome.desktop.wm.preferences num-workspaces               4
gsettings set org.gnome.desktop.wm.preferences focus-mode                  'click'

# ── Input ──────────────────────────────────────────────────────────────────
gsettings set org.gnome.desktop.peripherals.touchpad tap-to-click   true
gsettings set org.gnome.desktop.peripherals.touchpad natural-scroll  true
gsettings set org.gnome.desktop.peripherals.touchpad two-finger-scrolling-enabled true
gsettings set org.gnome.desktop.peripherals.mouse    natural-scroll  false
gsettings set org.gnome.desktop.peripherals.mouse    accel-profile   'adaptive'

# ── Nemo ───────────────────────────────────────────────────────────────────
gsettings set org.nemo.desktop show-desktop-icons              true
gsettings set org.nemo.desktop ignored-desktop-handlers        "['budgie-helper']"
gsettings set org.nemo.preferences show-hidden-files           false
gsettings set org.nemo.preferences default-folder-viewer       'icon-view'
gsettings set org.nemo.icon-view default-zoom-level            'standard'
gsettings set org.nemo.preferences show-location-entry         false

# ── Budgie panel — bottom floating pill ───────────────────────────────────
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

# ── Crystal Dock config ────────────────────────────────────────────────────
mkdir -p "${HOME}/.crystal-dock-2"
cat > "${HOME}/.crystal-dock-2/general.conf" << 'CDCONF'
[General]
autoHide=false
showTaskManager=true
showClock=true
showDesktop=true
position=Bottom
screenEdgeMargin=8
iconSize=52
minIconSize=32
maxIconSize=72
backgroundAlpha=180
tooltipDelay=300
CDCONF

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
# ── .config/labwc/environment env vars ───────────────────
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
# ── .config/fontconfig — sharper font rendering ────────────────
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
  <!-- Prefer Noto, fall back gracefully -->
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

# ── .config/electron-flags.conf — Wayland-native Electron apps ───────────
cat > "${SKEL}/.config/electron-flags.conf" << 'ELECTRONFLAGS'
--enable-features=UseOzonePlatform
--ozone-platform=wayland
--enable-wayland-ime
ELECTRONFLAGS

# ── .config/chrome-flags.conf — same for Chromium ─────────────────────────
cat > "${SKEL}/.config/chrome-flags.conf" << 'CHROMEFLAGS'
--enable-features=UseOzonePlatform
--ozone-platform=wayland
CHROMEFLAGS
cat > "${SKEL}/.config/autostart/crystal-dock.desktop" << 'CRYSTALDOCK'
[Desktop Entry]
Type=Application
Name=Crystal Dock
Exec=crystal-dock
Hidden=false
NoDisplay=true
X-GNOME-Autostart-enabled=true
CRYSTALDOCK
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
# Keep $HOME clean
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

# ── Apply skeleton to liveuser ─────────────────────────────────────────────
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
mkdir -p /usr/share/applications
mkdir -p /etc/skel/Desktop
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
    --bg: #282a36;
    --surface: #44475a;
    --surface-2: #383a59;
    --text: #f8f8f2;
    --accent: #bd93f9;
    --accent-dark: #a37cf2;
    --sub: #6272a4;
    --border: #44475a;
    --shadow: 0 4px 24px rgba(0,0,0,0.4);
  }
  * { margin:0; padding:0; box-sizing:border-box; }
  body { font-family:'Noto Sans',system-ui,sans-serif; background:var(--bg); color:var(--text); }

  header {
    background: linear-gradient(135deg, #282a36 0%, #44475a 100%);
    color: var(--text); padding: 52px 32px 72px; text-align: center;
    border-bottom: 1px solid var(--border);
  }
  header h1 { font-size:2.2rem; font-weight:300; letter-spacing:1px; }
  header p  { font-size:1rem; opacity:.72; margin-top:8px; }

  .card-row {
    display:flex; gap:18px; flex-wrap:wrap;
    padding:28px 32px; max-width:920px; margin:-32px auto 0;
  }
  .card {
    background:var(--surface); border-radius:18px; padding:24px 22px;
    flex:1; min-width:200px; box-shadow:var(--shadow);
    border:1px solid var(--border);
    transition: transform .15s, box-shadow .15s;
  }
  .card:hover { transform:translateY(-3px); box-shadow:0 8px 32px rgba(0,0,0,0.6); }
  .card h2 { font-size:1rem; font-weight:600; margin-bottom:6px; color:var(--text); }
  .card p  { font-size:.88rem; color:var(--sub); line-height:1.55; }

  section { max-width:920px; margin:0 auto; padding:4px 32px 40px; }
  section h2 {
    font-size:1.2rem; font-weight:600; margin:28px 0 12px;
    color:var(--accent);
  }
  .tip {
    background: var(--surface); border-left: 3px solid var(--accent);
    border-radius: 0 10px 10px 0; padding: 14px 18px; margin-top: 10px;
    font-size: .9rem; color: var(--text);
  }
  .tip code {
    background: var(--bg); padding: 2px 7px; border-radius: 5px;
    font-family: 'Noto Sans Mono', monospace; font-size: .88em;
  }

  .btn {
    display:inline-block; background:var(--accent); color:#282a36;
    border-radius:10px; padding:9px 20px; text-decoration:none;
    font-size:.88rem; font-weight:600; margin:6px 6px 0 0;
    transition: background .12s;
  }
  .btn:hover { background:var(--accent-dark); }
  .btn:focus-visible { outline: 2px solid var(--text); outline-offset: 2px; }
  .btn.secondary {
    background:var(--surface); color:var(--text);
    border:1.5px solid var(--border);
  }
  .btn.secondary:hover { background:var(--surface-2); }

  .design-pills { display:flex; gap:10px; flex-wrap:wrap; margin-top:10px; }
  .pill {
    background:var(--surface-2); border:1px solid var(--border);
    border-radius:100px; padding:5px 14px; font-size:.82rem;
    color:var(--sub);
  }

  footer {
    text-align:center; padding:24px; color:var(--sub); font-size:.8rem;
    border-top:1px solid var(--border); margin-top:16px;
  }
</style>
</head>
<body>
<header>
  <h1>Welcome to KibaOS</h1>
  <p>A fast, polished Budgie desktop built on Arch Linux — by WolfTech Innovations</p>
</header>

<div class="card-row">
  <div class="card">
    <h2>Budgie 10.10 Wayland</h2>
    <p>Fully Wayland-native. Powered by labwc for smooth, compositor-agnostic window management.</p>
  </div>
  <div class="card">
    <h2>Built on Arch Linux</h2>
    <p>Rolling release. Always the latest software, straight from upstream with full AUR access.</p>
  </div>
  <div class="card">
    <h2>Unified Design</h2>
    <p>Inspired by DDE's curves, Paper's flat surfaces, and Cutefish's airy, floating aesthetic.</p>
  </div>
  <div class="card">
    <h2>Private by Default</h2>
    <p>Full disk encryption support. No telemetry. Your data stays yours.</p>
  </div>
</div>

<section>
  <h2>Ready to Install?</h2>
  <p>Click <strong>Install KibaOS</strong> on the desktop, or run:</p>
  <div class="tip"><code>sudo calamares</code></div>
  <br>
  <a class="btn" href="https://github.com/WolfTech-Innovations/Kiba/blob/main/WIKI.md">📖 Wiki</a>
  <a class="btn secondary" href="https://github.com/WolfTech-Innovations/Kiba/issues">🐞 Report Issue</a>
  <a class="btn secondary" href="https://github.com/WolfTech-Innovations/Kiba">🐙 GitHub</a>

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
# Pass the live user's Wayland socket to root's calamares process.
# We need the *user's* XDG_RUNTIME_DIR, not root's /tmp/runtime-root.
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
# ── Services ───────────────────────────────────────────────────────────────
systemctl enable sddm
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
sudo systemctl enable NetworkManager
# After liveuser's home exists, at the end of customize_airootfs.sh:
install -d -m 755 -o 1000 -g 1000 /home/liveuser/.config/dconf
sudo -u liveuser dbus-run-session -- bash -c '
  dconf write /com/solus-project/budgie/panel/panels "@as []"
  dconf write /com/solus-project/budgie/panel/panels-changed "$(date +%s)"
  dconf write /com/solus-project/budgie/panel/applets/.../key-combination "'Super_L'"
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
