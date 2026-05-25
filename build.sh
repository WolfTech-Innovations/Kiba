#!/bin/bash
set -ex

# ── Container deps ────────────────────────────────────────────────────────
pacman-key --init
pacman-key --populate archlinux
pacman -Syy --noconfirm
pacman -Su  --noconfirm

pacman -S --noconfirm --needed \
  archiso base-devel git squashfs-tools libisoburn mtools dosfstools \
  cmake extra-cmake-modules ninja meson \
  wayland wayland-protocols wlroots libdrm libinput \
  qt6-base qt6-wayland qt6-declarative qt6-tools qt6-svg qt6-uitools qt6-5compat \
  qt6ct kvantum-qt6 \
  glm cairo pango freetype2 libpng libjpeg pixman libxml2 \
  boost boost-libs yaml-cpp \
  kpmcore python python-yaml python-jsonschema \
  dbus pam polkit networkmanager fontconfig openssl curl imagemagick

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
iso_application="KibaOS — A modern Wayland desktop built on Arch"
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
# /etc/os-release — full KibaOS branding
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
# NOTE: PaperDE + cubocore stack built from source in customize_airootfs.sh
# NOTE: Octopi built from AUR in customize_airootfs.sh (AUR-only package)
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
zsh
zsh-autosuggestions
zsh-syntax-highlighting
fastfetch
nano
ttf-dejavu
noto-fonts
noto-fonts-emoji
ttf-liberation
noto-fonts-cjk

# Wayland stack
wayland
wayland-protocols
wlroots
libdrm
libinput
libxkbcommon
xorg-xwayland
seatd

# Qt6 runtime
qt6-base
qt6-wayland
qt6-declarative
qt6-tools
qt6-svg
qt6-uitools
qt6-5compat
qt6ct
kvantum-qt6

# PaperDE build deps (also runtime)
glm
cairo
pango
freetype2
libpng
libjpeg-turbo
pixman
libxml2
cmake
ninja
git
base-devel

# Theming
papirus-icon-theme
breeze-icons

# Display manager
sddm

# Apps — all generic, all Qt6 where possible
falkon                   # browser (Qt6 WebEngine)
dolphin                  # file manager (KDE/Qt6)
konsole                  # terminal (KDE/Qt6)
elisa                    # music player (KDE/Qt6)
gwenview                 # image viewer (KDE/Qt6)
ark                      # archive manager (KDE/Qt6)
kate                     # text editor (KDE/Qt6)
spectacle                # screenshot tool (KDE/Qt6)
kcalc                    # calculator (KDE/Qt6)
# Octopi (Qt app store/package manager) — AUR, built in customize_airootfs.sh

# System utilities
gparted
ntfs-3g
exfatprogs
cryptsetup
polkit-kde-agent
networkmanager-qt
pipewire
pipewire-pulse
pipewire-alsa
wireplumber
pavucontrol-qt

# Flatpak / portals
flatpak
xdg-desktop-portal
xdg-desktop-portal-gtk
xdg-desktop-portal-wlr

# Plymouth
plymouth
imagemagick
curl
openssl
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
# Boot menu (systemd-boot + syslinux)
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
# SDDM — KibaOS theme (Qt6 QML)
# ══════════════════════════════════════════════════════════════════════════
mkdir -p "${AIROOTFS}/etc/sddm.conf.d"
cat > "${AIROOTFS}/etc/sddm.conf.d/kibaos.conf" << 'SDDMCONF'
[Autologin]
User=liveuser
Session=paperde
Relogin=false

[Theme]
Current=kibaos

[General]
HaltCommand=/usr/bin/systemctl poweroff
RebootCommand=/usr/bin/systemctl reboot
DisplayServer=wayland
GreeterEnvironment=QT_WAYLAND_SHELL_INTEGRATION=layer-shell

[Wayland]
CompositorCommand=kwin_wayland --drm --no-lockscreen --no-global-shortcuts --locale1
SDDMCONF

mkdir -p "${AIROOTFS}/usr/share/sddm/themes/kibaos"

cat > "${AIROOTFS}/usr/share/sddm/themes/kibaos/metadata.desktop" << 'SDDMMETA'
[SddmGreeterTheme]
Name=KibaOS
Description=KibaOS SDDM Theme — Material You Teal
Author=WolfTech Innovations
License=MIT
Type=sddm-theme
Version=2.0
Website=https://github.com/WolfTech-Innovations/Kiba
SDDMMETA

cat > "${AIROOTFS}/usr/share/sddm/themes/kibaos/theme.conf" << 'SDDMTHEMECONF'
[General]
background=background.png
SDDMTHEMECONF

cat > "${AIROOTFS}/usr/share/sddm/themes/kibaos/Main.qml" << 'SDDMQML'
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import SddmComponents

Rectangle {
    id: root
    color: "transparent"

    Image {
        anchors.fill: parent
        source: "background.png"
        fillMode: Image.PreserveAspectCrop
        smooth: true
    }

    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: 0.40
    }

    // ── KibaOS watermark (bottom-right corner) ───────────────────────────
    Row {
        anchors { bottom: parent.bottom; right: parent.right; margins: 24 }
        spacing: 8
        Image {
            source: "logo.png"
            width: 22; height: 22
            fillMode: Image.PreserveAspectFit
            smooth: true
            opacity: 0.6
        }
        Text {
            text: "KibaOS"
            color: "#ffffff"
            opacity: 0.5
            font.pixelSize: 12
            font.family: "Noto Sans"
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    // ── Centered login card ───────────────────────────────────────────────
    Rectangle {
        id: card
        anchors.centerIn: parent
        width: 340
        height: cardCol.implicitHeight + 56
        radius: 20
        color: "#ccffffff"

        Rectangle {
            anchors.fill: parent; radius: parent.radius
            color: "transparent"; border.color: "#44ffffff"; border.width: 1
        }

        ColumnLayout {
            id: cardCol
            anchors { top: parent.top; left: parent.left; right: parent.right; margins: 28 }
            spacing: 14

            Image {
                Layout.alignment: Qt.AlignHCenter
                source: "logo.png"
                width: 72; height: 72
                fillMode: Image.PreserveAspectFit
                smooth: true
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "KibaOS"
                color: "#1a1a2e"
                font.pixelSize: 24; font.weight: Font.Medium; font.family: "Noto Sans"
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "by WolfTech Innovations"
                color: "#557788"; font.pixelSize: 11; font.family: "Noto Sans"
            }

            Text {
                id: clock
                Layout.alignment: Qt.AlignHCenter
                color: "#444466"; font.pixelSize: 13; font.family: "Noto Sans"
                Timer {
                    interval: 1000; running: true; repeat: true
                    onTriggered: clock.text = Qt.formatDateTime(new Date(), "hh:mm  ·  dddd, MMMM d")
                }
                Component.onCompleted: clock.text = Qt.formatDateTime(new Date(), "hh:mm  ·  dddd, MMMM d")
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: "#22000000" }

            TextField {
                id: userField
                Layout.fillWidth: true
                placeholderText: "Username"
                text: sddm.lastUser
                color: "#1a1a2e"; placeholderTextColor: "#88667788"; font.pixelSize: 14
                background: Rectangle {
                    color: "#eef5ff"; radius: 10
                    border.color: userField.activeFocus ? "#006874" : "#ccd0da"
                    border.width: userField.activeFocus ? 2 : 1
                }
                leftPadding: 14; rightPadding: 14; topPadding: 12; bottomPadding: 12
                Keys.onReturnPressed: passwordField.forceActiveFocus()
            }

            TextField {
                id: passwordField
                Layout.fillWidth: true
                placeholderText: "Password"
                echoMode: TextInput.Password
                color: "#1a1a2e"; placeholderTextColor: "#88667788"; font.pixelSize: 14
                background: Rectangle {
                    color: "#eef5ff"; radius: 10
                    border.color: passwordField.activeFocus ? "#006874" : "#ccd0da"
                    border.width: passwordField.activeFocus ? 2 : 1
                }
                leftPadding: 14; rightPadding: 14; topPadding: 12; bottomPadding: 12
                Keys.onReturnPressed: sddm.login(userField.text, passwordField.text,
                    sessionModel.index(sessionBox.currentIndex, 0))
            }

            ComboBox {
                id: sessionBox
                Layout.fillWidth: true
                model: sessionModel; textRole: "name"
                currentIndex: sessionModel.lastIndex; font.pixelSize: 12
                background: Rectangle { color: "#e8f0fe"; radius: 10; border.color: "#ccd0da"; border.width: 1 }
                contentItem: Text {
                    leftPadding: 14; text: sessionBox.displayText
                    color: "#444466"; font: sessionBox.font; verticalAlignment: Text.AlignVCenter
                }
            }

            Rectangle {
                Layout.fillWidth: true; height: 44; radius: 12
                color: loginMouse.containsMouse ? "#004f57" : "#006874"
                Behavior on color { ColorAnimation { duration: 120 } }
                Text {
                    anchors.centerIn: parent; text: "Sign In"; color: "#ffffff"
                    font.pixelSize: 14; font.weight: Font.Medium; font.family: "Noto Sans"
                }
                MouseArea {
                    id: loginMouse; anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: sddm.login(userField.text, passwordField.text,
                        sessionModel.index(sessionBox.currentIndex, 0))
                }
            }

            Text {
                id: errorMsg; Layout.alignment: Qt.AlignHCenter
                color: "#b3261e"; font.pixelSize: 12; visible: text !== ""
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter; spacing: 28
                Text {
                    text: "⏻  Shut Down"; color: "#667788"; font.pixelSize: 12
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: sddm.powerOff() }
                }
                Text {
                    text: "↺  Restart"; color: "#667788"; font.pixelSize: 12
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: sddm.reboot() }
                }
            }
        }
    }

    Connections {
        target: sddm
        function onLoginFailed()    { errorMsg.text = "Incorrect username or password."; passwordField.clear() }
        function onLoginSucceeded() { errorMsg.text = "" }
    }

    Component.onCompleted: {
        if (userField.text === "") userField.forceActiveFocus()
        else passwordField.forceActiveFocus()
    }
}
SDDMQML

# ══════════════════════════════════════════════════════════════════════════
# PaperDE Wayland session file
# ══════════════════════════════════════════════════════════════════════════
mkdir -p "${AIROOTFS}/usr/share/wayland-sessions"
cat > "${AIROOTFS}/usr/share/wayland-sessions/paperde.desktop" << 'PAPERDESKTOP'
[Desktop Entry]
Name=PaperDE
Comment=KibaOS Desktop (PaperDE on Wayfire)
Exec=/usr/bin/papersessionmanager
TryExec=/usr/bin/papersessionmanager
Type=Application
DesktopNames=PaperDE;KibaOS
PAPERDESKTOP

# ══════════════════════════════════════════════════════════════════════════
# Calamares installer branding + config
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
/* KibaOS Installer Theme — Material You × macOS × ChromeOS */
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
        { icon: "🐺", heading: "Welcome to KibaOS", body: "We're setting everything up for you. This usually takes 5–10 minutes." },
        { icon: "⚡", heading: "Built on Arch Linux", body: "Rolling release means you always get the latest software, straight from upstream." },
        { icon: "🎨", heading: "PaperDE on Wayland", body: "A touch-friendly Qt6 desktop on Wayfire — fast, modern, and beautiful." },
        { icon: "🔒", heading: "Your system, your rules", body: "Full disk encryption, pacman, and the entire AUR at your fingertips." },
        { icon: "🐺", heading: "KibaOS by WolfTech", body: "github.com/WolfTech-Innovations/Kiba — guides, wiki, and issue reporting." }
    ]
    property int currentSlide: 0

    Timer { interval: 6000; running: root.activatedInCalamares; repeat: true
        onTriggered: root.currentSlide = (root.currentSlide + 1) % root.slides.length }

    Rectangle {
        anchors.fill: parent; color: "#f2f7f9"

        Rectangle {
            id: topStrip; anchors { top: parent.top; left: parent.left; right: parent.right }
            height: parent.height * 0.38; color: "#006874"
            Rectangle { anchors.centerIn: parent; width: 180; height: 180; radius: 90; color: "#ffffff"; opacity: 0.08 }
            Image {
                anchors.centerIn: parent; source: "logo.png"; width: 96; height: 96
                fillMode: Image.PreserveAspectFit; smooth: true
                NumberAnimation on scale { from: 0.8; to: 1.0; duration: 600; easing.type: Easing.OutBack; running: true }
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
                    id: slideHeading; Layout.alignment: Qt.AlignHCenter; Layout.fillWidth: true
                    text: root.slides[root.currentSlide].heading
                    font.pixelSize: 20; font.weight: Font.Medium; color: "#1a1a2e"
                    horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap
                    Behavior on text { SequentialAnimation {
                        NumberAnimation { target: slideHeading; property: "opacity"; to: 0; duration: 180 }
                        PropertyAction {}
                        NumberAnimation { target: slideHeading; property: "opacity"; to: 1; duration: 220 }
                    }}
                }
                Text {
                    id: slideBody; Layout.alignment: Qt.AlignHCenter; Layout.fillWidth: true
                    text: root.slides[root.currentSlide].body
                    font.pixelSize: 13; color: "#556677"; horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap; lineHeight: 1.5
                    Behavior on text { SequentialAnimation {
                        NumberAnimation { target: slideBody; property: "opacity"; to: 0; duration: 180 }
                        PropertyAction {}
                        NumberAnimation { target: slideBody; property: "opacity"; to: 1; duration: 220 }
                    }}
                }
                Row {
                    Layout.alignment: Qt.AlignHCenter; spacing: 8
                    Repeater {
                        model: root.slides.length
                        delegate: Rectangle {
                            width: index === root.currentSlide ? 18 : 7; height: 7; radius: 3.5
                            color: index === root.currentSlide ? "#006874" : "#cce0e4"
                            Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }
                            Behavior on color { ColorAnimation { duration: 200 } }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: root.currentSlide = index }
                        }
                    }
                }
            }
        }

        Text {
            anchors { horizontalCenter: parent.horizontalCenter; bottom: progressTrack.top; bottomMargin: 10 }
            text: "Installing KibaOS…"; font.pixelSize: 12; color: "#889aaa"
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
                    NumberAnimation { to: progressTrack.width; duration: 600; easing.type: Easing.OutCubic }
                    PauseAnimation { duration: 300 }
                    NumberAnimation { to: 0; duration: 500; easing.type: Easing.InCubic }
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
          for d in paperde wayfire qt6ct Kvantum gtk-3.0 gtk-4.0; do
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
  - sddm
defaultDesktopEnvironment:
  executable: "papersessionmanager"
  desktopFile: "paperde"
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
  echo 'liveuser:x:1000:1000:KibaOS Live User:/home/liveuser:/usr/bin/zsh' >> "${AIROOTFS}/etc/passwd"
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
ln -sf /usr/lib/systemd/system/seatd.service          "${WANTS}/multi-user.target.wants/seatd.service"
ln -sf /usr/lib/systemd/system/bluetooth.service      "${WANTS}/multi-user.target.wants/bluetooth.service"
ln -sf /usr/lib/systemd/system/pacman-init.service    "${WANTS}/multi-user.target.wants/pacman-init.service"

# ══════════════════════════════════════════════════════════════════════════
# customize_airootfs.sh  ←  runs inside the chroot at build time
# ══════════════════════════════════════════════════════════════════════════
mkdir -p "${AIROOTFS}/root"
cat > "${AIROOTFS}/root/customize_airootfs.sh" << 'CUSTOMIZE'
#!/usr/bin/env bash
set -e

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
for g in users wheel audio video input network storage seat; do
  groupadd -r "$g" 2>/dev/null || true
  usermod -aG "$g" liveuser 2>/dev/null || true
done
echo "liveuser:live" | chpasswd
grep -qx '/usr/bin/zsh' /etc/shells || echo '/usr/bin/zsh' >> /etc/shells
chsh -s /usr/bin/zsh root
cp -aT /etc/skel/ /home/liveuser/ 2>/dev/null || true
chown -R 1000:1000 /home/liveuser
chmod 750 /home/liveuser

# ── systemd tunables ───────────────────────────────────────────────────────
sed -i 's/#Storage=auto/Storage=volatile/'                    /etc/systemd/journald.conf
sed -i 's/#HandleLidSwitch=suspend/HandleLidSwitch=ignore/'   /etc/systemd/logind.conf
sed -i 's/#HandleSuspendKey=suspend/HandleSuspendKey=ignore/' /etc/systemd/logind.conf

# ══════════════════════════════════════════════════════════════════════════
# DOWNLOAD BRANDING ASSETS  (must happen before Plymouth + SDDM setup)
# ══════════════════════════════════════════════════════════════════════════
WALLPAPER_URL="https://github.com/WolfTech-Innovations/Kiba/blob/78699a64fff1f243162f50ffba206a2de0d3272e/branding/wallpaper.png?raw=true"
LOGO_URL="https://github.com/WolfTech-Innovations/Kiba/blob/main/branding/boot.png?raw=true"
WALLPAPER_DEST="/usr/share/kibaos/wallpaper.png"
LOGO_SRC="/usr/share/kibaos/logo-raw.png"
LOGO_256="/usr/share/kibaos/logo-256.png"   # canonical high-res copy
LOGO_96="/usr/share/kibaos/logo-96.png"
LOGO_72="/usr/share/kibaos/logo-72.png"
LOGO_48="/usr/share/kibaos/logo-48.png"
LOGO_32="/usr/share/kibaos/logo-32.png"

mkdir -p /usr/share/kibaos /usr/share/pixmaps

echo "=== Downloading KibaOS wallpaper ==="
curl -fL --retry 5 --retry-delay 3 -o "${WALLPAPER_DEST}" "${WALLPAPER_URL}" || \
  magick -size 1920x1080 gradient:"#004f57-#0d1b2a" "${WALLPAPER_DEST}"

echo "=== Downloading KibaOS logo ==="
curl -fL --retry 5 --retry-delay 3 -o "${LOGO_SRC}" "${LOGO_URL}" || true

# Generate all logo sizes from source; fall back to generated teal circle
if [ -f "${LOGO_SRC}" ] && file "${LOGO_SRC}" | grep -qi 'image'; then
  magick "${LOGO_SRC}" -filter Lanczos -resize 256x256 "${LOGO_256}"
  magick "${LOGO_SRC}" -filter Lanczos -resize 96x96  "${LOGO_96}"
  magick "${LOGO_SRC}" -filter Lanczos -resize 72x72  "${LOGO_72}"
  magick "${LOGO_SRC}" -filter Lanczos -resize 48x48  "${LOGO_48}"
  magick "${LOGO_SRC}" -filter Lanczos -resize 32x32  "${LOGO_32}"
  rm -f "${LOGO_SRC}"
else
  # Fallback: draw a teal circle with "K"
  for sz in 256 96 72 48 32; do
    magick -size ${sz}x${sz} xc:none \
      -fill '#006874' -draw "circle $((sz/2)),$((sz/2)) $((sz/2)),1" \
      -fill white -pointsize $((sz/2)) -gravity Center -annotate 0 'K' \
      "/usr/share/kibaos/logo-${sz}.png"
  done
fi

# ── Pixmap symlinks (used by system-wide logo lookups) ────────────────────
cp "${LOGO_256}" /usr/share/pixmaps/kibaos.png
ln -sf /usr/share/pixmaps/kibaos.png /usr/share/pixmaps/kibaos-logo.png

# ── XDG icon theme entry (so apps can find kibaos icon by name) ───────────
mkdir -p /usr/share/icons/hicolor/256x256/apps \
         /usr/share/icons/hicolor/48x48/apps \
         /usr/share/icons/hicolor/32x32/apps
cp "${LOGO_256}" /usr/share/icons/hicolor/256x256/apps/kibaos.png
cp "${LOGO_48}"  /usr/share/icons/hicolor/48x48/apps/kibaos.png
cp "${LOGO_32}"  /usr/share/icons/hicolor/32x32/apps/kibaos.png
gtk-update-icon-cache /usr/share/icons/hicolor/ 2>/dev/null || true

# ══════════════════════════════════════════════════════════════════════════
# SDDM theme assets  (placed AFTER assets are downloaded)
# ══════════════════════════════════════════════════════════════════════════
cp "${LOGO_96}" /usr/share/sddm/themes/kibaos/logo.png

# SDDM background: wallpaper cropped to 1920×1080
magick "${WALLPAPER_DEST}" -filter Lanczos -resize 1920x1080^ \
  -gravity Center -extent 1920x1080 \
  /usr/share/sddm/themes/kibaos/background.png

# ══════════════════════════════════════════════════════════════════════════
# Calamares branding assets
# ══════════════════════════════════════════════════════════════════════════
cp "${LOGO_256}" /usr/share/calamares/branding/kibaos/logo.png

# ══════════════════════════════════════════════════════════════════════════
# PLYMOUTH — custom KibaOS spinner theme
#
# Key lessons from upstream reports:
#  1. Logo file must be a real PNG file, NOT a symlink.
#  2. The spinner theme uses "watermark.png" for the center logo.
#  3. background-tile.png must be a real image file.
#  4. plymouth-set-default-theme -R must be called AFTER all files are placed.
#  5. The .plymouth descriptor must correctly reference ModuleName=spinner.
# ══════════════════════════════════════════════════════════════════════════
PLYMOUTH_THEME="/usr/share/plymouth/themes/kibaos"
mkdir -p "${PLYMOUTH_THEME}"

# Copy spinner base (gets us the .so and scripts)
SPINNER_SRC="/usr/share/plymouth/themes/spinner"
if [ -d "${SPINNER_SRC}" ]; then
  cp -a "${SPINNER_SRC}/." "${PLYMOUTH_THEME}/"
  # Remove any pre-existing .plymouth file from spinner so we replace it cleanly
  rm -f "${PLYMOUTH_THEME}/spinner.plymouth"
fi

# Write KibaOS Plymouth descriptor — must match the directory name exactly
cat > "${PLYMOUTH_THEME}/kibaos.plymouth" << 'PLYM'
[Plymouth Theme]
Name=KibaOS
Description=KibaOS boot splash — Material You teal spinner
ModuleName=spinner

[spinner]
Title=KibaOS
HideDelay=5
TransitionDuration=3
PLYM

# Background: solid dark (teal-black gradient)
magick -size 1920x1080 \
  \( xc:'#0d1b2a' \) \
  \( xc:'#004f57' -resize 1920x1080! \) \
  -compose Multiply -composite \
  "${PLYMOUTH_THEME}/background-tile.png"

# Watermark: KibaOS logo centered on boot screen
# spinner module places watermark.png in the center of the display
cp "${LOGO_256}" "${PLYMOUTH_THEME}/watermark.png"

# Verify files are real files (not symlinks) — Plymouth requires this
for f in background-tile.png watermark.png kibaos.plymouth; do
  [ -L "${PLYMOUTH_THEME}/${f}" ] && cp --remove-destination \
    "$(readlink -f "${PLYMOUTH_THEME}/${f}")" "${PLYMOUTH_THEME}/${f}" || true
done

# Register and rebuild initramfs — this is the critical step
# The -R flag calls mkinitcpio automatically after setting the theme
plymouth-set-default-theme -R kibaos

# Enable Plymouth services
systemctl enable plymouth-start.service      2>/dev/null || true
systemctl enable plymouth-read-write.service 2>/dev/null || true
systemctl enable plymouth-quit-wait.service  2>/dev/null || true

echo "=== Plymouth theme kibaos set and initramfs rebuilt ==="

# ══════════════════════════════════════════════════════════════════════════
# BUILD PAPERDE FROM SOURCE
# Build order: wayfire → cprime → csys → wayqt → df6 → paperde
# ══════════════════════════════════════════════════════════════════════════
BUILD_DIR="/tmp/paperde-build"
mkdir -p "${BUILD_DIR}"
cd "${BUILD_DIR}"

CUBO="https://gitlab.com/cubocore"
PAPER="https://gitlab.com/cubocore/paper"

build_cmake() {
  local name="$1" url="$2"
  echo "=== Building ${name} ==="
  git clone --depth=1 "${url}" "${name}"
  cmake -S "${name}" -B "${name}/build" \
    -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr -GNinja
  ninja -C "${name}/build"
  ninja -C "${name}/build" install
}

build_meson() {
  local name="$1" url="$2"; shift 2
  echo "=== Building ${name} (meson) ==="
  git clone --depth=1 "${url}" "${name}"
  meson setup "${name}/build" "${name}" --prefix=/usr --buildtype=release "$@"
  ninja -C "${name}/build"
  ninja -C "${name}/build" install
}

build_meson wayfire "https://gitlab.com/WayfireWM/wayfire" \
  -Duse_system_wfconfig=auto -Duse_system_wlroots=enabled -Dxwayland=enabled

build_cmake cprime "${CUBO}/coreapps/cprime"
build_cmake csys   "${CUBO}/coreapps/csys"
build_cmake wayqt  "${PAPER}/wayqt"
build_cmake df6    "${PAPER}/df6"

echo "=== Building paperde ==="
git clone --depth=1 "${PAPER}/paperde" paperde-src
cmake -S paperde-src -B paperde-src/build \
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr -GNinja
ninja -C paperde-src/build
ninja -C paperde-src/build install

ldconfig
cd /; rm -rf "${BUILD_DIR}"
echo "=== PaperDE build complete ==="

# ══════════════════════════════════════════════════════════════════════════
# BUILD OCTOPI FROM AUR (Qt-based pacman/AUR GUI — our "App Store")
# ══════════════════════════════════════════════════════════════════════════
OCTOPI_BUILD="/tmp/octopi-build"
mkdir -p "${OCTOPI_BUILD}"
cd "${OCTOPI_BUILD}"

# Build as a non-root user (makepkg requirement)
useradd -m -s /bin/bash builduser 2>/dev/null || true
echo 'builduser ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/builduser

git clone --depth=1 https://aur.archlinux.org/octopi.git
chown -R builduser:builduser octopi
cd octopi
sudo -u builduser makepkg -si --noconfirm

cd /; rm -rf "${OCTOPI_BUILD}"
userdel -r builduser 2>/dev/null || true
rm -f /etc/sudoers.d/builduser
echo "=== Octopi (App Store) installed ==="

# ══════════════════════════════════════════════════════════════════════════
# KibaOS SYSTEM BRANDING — branding appears EVERYWHERE
# ══════════════════════════════════════════════════════════════════════════

# ── /etc/issue (TTY login banner) ─────────────────────────────────────────
cat > /etc/issue << 'ISSUE'

  ██╗  ██╗██╗██████╗  █████╗  ██████╗ ███████╗
  ██║ ██╔╝██║██╔══██╗██╔══██╗██╔═══██╗██╔════╝
  █████╔╝ ██║██████╔╝███████║██║   ██║███████╗
  ██╔═██╗ ██║██╔══██╗██╔══██║██║   ██║╚════██║
  ██║  ██╗██║██████╔╝██║  ██║╚██████╔╝███████║
  ╚═╝  ╚═╝╚═╝╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝

  KibaOS Rolling — WolfTech Innovations
  github.com/WolfTech-Innovations/Kiba

  Live session: user=liveuser  password=live
  Install: run  kibaos-install  or open the installer from the desktop.

ISSUE

# ── /etc/motd (post-login message) ────────────────────────────────────────
cat > /etc/motd << 'MOTD'
Welcome to KibaOS — PaperDE on Wayland, powered by Arch Linux.
Built with ❤ by WolfTech Innovations.  https://github.com/WolfTech-Innovations/Kiba
MOTD

# ── neofetch / fastfetch branding ─────────────────────────────────────────
# KibaOS ASCII art config for fastfetch (shows on terminal open)
mkdir -p /etc/kibaos
cat > /etc/kibaos/fastfetch.jsonc << 'FFCONF'
{
  "$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",
  "logo": {
    "source": "kibaos",
    "color": { "1": "cyan", "2": "white" },
    "padding": { "top": 1 }
  },
  "display": {
    "separator": "  ",
    "color": { "keys": "cyan" }
  },
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

# Fastfetch config for liveuser
mkdir -p /home/liveuser/.config/fastfetch
cp /etc/kibaos/fastfetch.jsonc /home/liveuser/.config/fastfetch/config.jsonc

# ── zshrc with KibaOS branding greeting ───────────────────────────────────
cat > /home/liveuser/.zshrc << 'ZSHRC'
# KibaOS — zsh config
export ZDOTDIR="$HOME"
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh 2>/dev/null || true
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh 2>/dev/null || true

# Prompt: KibaOS teal
autoload -U colors && colors
PS1="%{$fg_bold[cyan]%}[KibaOS]%{$reset_color%} %{$fg[green]%}%n@%m%{$reset_color%}:%{$fg[blue]%}%~%{$reset_color%}$ "

# Run fastfetch on new terminal
fastfetch --config /home/liveuser/.config/fastfetch/config.jsonc 2>/dev/null || true

alias install='sudo calamares'
alias update='sudo pacman -Syu'
alias pkgmgr='octopi'
ZSHRC

# ── /etc/environment — KibaOS env vars ────────────────────────────────────
cat > /etc/environment << 'ENV'
DESKTOP_SESSION=paperde
XDG_CURRENT_DESKTOP=PaperDE
XDG_SESSION_DESKTOP=paperde
XDG_SESSION_TYPE=wayland
QT_QPA_PLATFORM=wayland
QT_WAYLAND_DISABLE_WINDOWDECORATION=0
QT_AUTO_SCREEN_SCALE_FACTOR=1
MOZ_ENABLE_WAYLAND=1
QT_QPA_PLATFORMTHEME=qt6ct
GDK_BACKEND=wayland
CLUTTER_BACKEND=wayland
SDL_VIDEODRIVER=wayland
KIBAOS_VERSION=rolling
KIBAOS_VENDOR="WolfTech Innovations"
ENV

# ── KibaOS desktop branding .desktop files ────────────────────────────────
mkdir -p /usr/share/applications

# Installer shortcut (branded)
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

# About KibaOS
cat > /usr/share/applications/kibaos-about.desktop << 'ABOUTDESK'
[Desktop Entry]
Name=About KibaOS
Comment=Learn more about KibaOS by WolfTech Innovations
Exec=xdg-open https://github.com/WolfTech-Innovations/Kiba
Icon=kibaos
Terminal=false
Type=Application
Categories=System;
Keywords=kibaos;about;wolftech;
ABOUTDESK

# App Store (Octopi) — branded as KibaOS Software
cat > /usr/share/applications/kibaos-software.desktop << 'SWDESK'
[Desktop Entry]
Name=KibaOS Software
GenericName=Software Manager
Comment=Install and manage software on KibaOS
Exec=octopi
Icon=kibaos
Terminal=false
Type=Application
Categories=System;PackageManager;
Keywords=software;apps;install;pacman;aur;kibaos;
SWDESK

# ── Rename / brand key app desktop entries ─────────────────────────────────
# Falkon → KibaOS Browser
if [ -f /usr/share/applications/org.kde.falkon.desktop ]; then
  cp /usr/share/applications/org.kde.falkon.desktop \
     /usr/share/applications/kibaos-browser.desktop
  sed -i \
    -e 's/^Name=.*/Name=KibaOS Browser/' \
    -e 's/^GenericName=.*/GenericName=Web Browser/' \
    -e 's/^Comment=.*/Comment=Browse the web on KibaOS/' \
    -e 's/^Icon=.*/Icon=kibaos/' \
    /usr/share/applications/kibaos-browser.desktop
fi

# Elisa → KibaOS Music
if [ -f /usr/share/applications/org.kde.elisa.desktop ]; then
  cp /usr/share/applications/org.kde.elisa.desktop \
     /usr/share/applications/kibaos-music.desktop
  sed -i \
    -e 's/^Name=.*/Name=KibaOS Music/' \
    -e 's/^GenericName=.*/GenericName=Music Player/' \
    -e 's/^Comment=.*/Comment=Play your music collection on KibaOS/' \
    -e 's/^Icon=.*/Icon=kibaos/' \
    /usr/share/applications/kibaos-music.desktop
fi

# Dolphin → KibaOS Files
if [ -f /usr/share/applications/org.kde.dolphin.desktop ]; then
  cp /usr/share/applications/org.kde.dolphin.desktop \
     /usr/share/applications/kibaos-files.desktop
  sed -i \
    -e 's/^Name=.*/Name=KibaOS Files/' \
    -e 's/^GenericName=.*/GenericName=File Manager/' \
    -e 's/^Comment=.*/Comment=Manage your files on KibaOS/' \
    -e 's/^Icon=.*/Icon=kibaos/' \
    /usr/share/applications/kibaos-files.desktop
fi

# Konsole → KibaOS Terminal
if [ -f /usr/share/applications/org.kde.konsole.desktop ]; then
  cp /usr/share/applications/org.kde.konsole.desktop \
     /usr/share/applications/kibaos-terminal.desktop
  sed -i \
    -e 's/^Name=.*/Name=KibaOS Terminal/' \
    -e 's/^GenericName=.*/GenericName=Terminal/' \
    -e 's/^Comment=.*/Comment=Command line on KibaOS/' \
    -e 's/^Icon=.*/Icon=kibaos/' \
    /usr/share/applications/kibaos-terminal.desktop
fi

# Gwenview → KibaOS Photos
if [ -f /usr/share/applications/org.kde.gwenview.desktop ]; then
  cp /usr/share/applications/org.kde.gwenview.desktop \
     /usr/share/applications/kibaos-photos.desktop
  sed -i \
    -e 's/^Name=.*/Name=KibaOS Photos/' \
    -e 's/^GenericName=.*/GenericName=Image Viewer/' \
    -e 's/^Comment=.*/Comment=View your photos on KibaOS/' \
    -e 's/^Icon=.*/Icon=kibaos/' \
    /usr/share/applications/kibaos-photos.desktop
fi

# Kate → KibaOS Editor
if [ -f /usr/share/applications/org.kde.kate.desktop ]; then
  cp /usr/share/applications/org.kde.kate.desktop \
     /usr/share/applications/kibaos-editor.desktop
  sed -i \
    -e 's/^Name=.*/Name=KibaOS Editor/' \
    -e 's/^GenericName=.*/GenericName=Text Editor/' \
    -e 's/^Comment=.*/Comment=Edit text and code on KibaOS/' \
    -e 's/^Icon=.*/Icon=kibaos/' \
    /usr/share/applications/kibaos-editor.desktop
fi

# Gparted → KibaOS Disk Manager
if [ -f /usr/share/applications/gparted.desktop ]; then
  cp /usr/share/applications/gparted.desktop \
     /usr/share/applications/kibaos-disks.desktop
  sed -i \
    -e 's/^Name=.*/Name=KibaOS Disks/' \
    -e 's/^Comment=.*/Comment=Manage disk partitions on KibaOS/' \
    -e 's/^Icon=.*/Icon=kibaos/' \
    /usr/share/applications/kibaos-disks.desktop
fi

# ── KibaOS welcome script ─────────────────────────────────────────────────
cat > /usr/local/bin/kiba-welcome << 'WELCOME_SCRIPT'
#!/usr/bin/env bash
# KibaOS Welcome — shown on first login, uses Falkon as viewer
WELCOME_HTML="/usr/share/kibaos/welcome.html"
if command -v falkon &>/dev/null; then
  falkon --no-remote "${WELCOME_HTML}" &
elif command -v xdg-open &>/dev/null; then
  xdg-open "${WELCOME_HTML}" &
fi
WELCOME_SCRIPT
chmod +x /usr/local/bin/kiba-welcome

# Welcome page HTML
mkdir -p /usr/share/kibaos
cat > /usr/share/kibaos/welcome.html << 'WELCOMEHTML'
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Welcome to KibaOS</title>
<style>
  :root { --teal: #006874; --teal-dark: #004f57; --bg: #f2f7f9; --surface: #fff; --text: #1a1a2e; --sub: #556677; }
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body { font-family: 'Noto Sans', sans-serif; background: var(--bg); color: var(--text); }
  header { background: var(--teal); color: #fff; padding: 48px 32px 64px; text-align: center; position: relative; overflow: hidden; }
  header::before { content: ''; position: absolute; inset: 0; background: radial-gradient(circle at 60% 40%, rgba(255,255,255,.08), transparent 60%); }
  header h1 { font-size: 2.8rem; font-weight: 300; letter-spacing: -.5px; position: relative; }
  header p  { font-size: 1rem; opacity: .75; margin-top: 6px; position: relative; }
  .card-row { display: flex; gap: 20px; flex-wrap: wrap; padding: 28px 32px; max-width: 900px; margin: -28px auto 0; }
  .card { background: var(--surface); border-radius: 16px; padding: 24px; flex: 1; min-width: 220px;
           box-shadow: 0 2px 12px rgba(0,0,0,.08); }
  .card .icon { font-size: 2rem; margin-bottom: 12px; }
  .card h2 { font-size: 1.1rem; font-weight: 600; margin-bottom: 6px; }
  .card p  { font-size: .9rem; color: var(--sub); line-height: 1.5; }
  section  { max-width: 900px; margin: 0 auto; padding: 0 32px 40px; }
  section h2 { font-size: 1.3rem; font-weight: 600; margin: 28px 0 14px; color: var(--teal); }
  .app-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(160px,1fr)); gap: 12px; }
  .app-item { background: var(--surface); border-radius: 12px; padding: 16px 12px; text-align: center; font-size: .85rem; }
  .app-item .icon { font-size: 1.6rem; display: block; margin-bottom: 6px; }
  .app-item strong { display: block; font-weight: 600; margin-bottom: 2px; }
  .app-item span   { color: var(--sub); }
  .btn { display: inline-block; background: var(--teal); color: #fff; border-radius: 10px;
         padding: 10px 22px; text-decoration: none; font-size: .9rem; font-weight: 600;
         margin-right: 8px; margin-top: 8px; }
  .btn:hover { background: var(--teal-dark); }
  footer { text-align: center; padding: 24px; color: var(--sub); font-size: .82rem;
           border-top: 1px solid #d8e0e2; margin-top: 16px; }
</style>
</head>
<body>
<header>
  <h1>🐺 Welcome to KibaOS</h1>
  <p>A modern Wayland desktop built on Arch Linux &mdash; by WolfTech Innovations</p>
</header>

<div class="card-row">
  <div class="card"><div class="icon">⚡</div><h2>Rolling Release</h2><p>Always up to date. Powered by Arch Linux and the AUR.</p></div>
  <div class="card"><div class="icon">🎨</div><h2>PaperDE</h2><p>Qt6 desktop on Wayland. Touch-friendly and fast.</p></div>
  <div class="card"><div class="icon">🔒</div><h2>Your System</h2><p>Full encryption support. No telemetry. Your data stays yours.</p></div>
</div>

<section>
  <h2>Included Apps</h2>
  <div class="app-grid">
    <div class="app-item"><span class="icon">🌐</span><strong>KibaOS Browser</strong><span>Falkon</span></div>
    <div class="app-item"><span class="icon">🎵</span><strong>KibaOS Music</strong><span>Elisa</span></div>
    <div class="app-item"><span class="icon">📁</span><strong>KibaOS Files</strong><span>Dolphin</span></div>
    <div class="app-item"><span class="icon">💻</span><strong>KibaOS Terminal</strong><span>Konsole</span></div>
    <div class="app-item"><span class="icon">🖼</span><strong>KibaOS Photos</strong><span>Gwenview</span></div>
    <div class="app-item"><span class="icon">📝</span><strong>KibaOS Editor</strong><span>Kate</span></div>
    <div class="app-item"><span class="icon">📦</span><strong>KibaOS Software</strong><span>Octopi</span></div>
    <div class="app-item"><span class="icon">💿</span><strong>KibaOS Disks</strong><span>GParted</span></div>
    <div class="app-item"><span class="icon">🔧</span><strong>Install KibaOS</strong><span>Calamares</span></div>
  </div>

  <h2>Get Started</h2>
  <a class="btn" href="https://github.com/WolfTech-Innovations/Kiba/blob/main/WIKI.md">📖 Read the Wiki</a>
  <a class="btn" href="https://github.com/WolfTech-Innovations/Kiba/issues">🐛 Report an Issue</a>
  <a class="btn" href="https://github.com/WolfTech-Innovations/Kiba">🐺 GitHub</a>

  <h2>Install KibaOS</h2>
  <p>Ready to make it permanent? Click <strong>Install KibaOS</strong> on the desktop, or open KibaOS Terminal and run <code>sudo calamares</code>.</p>
</section>

<footer>KibaOS Rolling &mdash; WolfTech Innovations &mdash; github.com/WolfTech-Innovations/Kiba</footer>
</body>
</html>
WELCOMEHTML

# ── Wayfire config ─────────────────────────────────────────────────────────
mkdir -p /home/liveuser/.config
cat > /home/liveuser/.config/wayfire.ini << 'WAYFIREINI'
[core]
plugins = required autostart animate scale expo vswitch move resize place grid command wm-actions oswitch

[output:default]
mode = auto
position = auto
transform = normal
scale = 1.000000

[animate]
open_animation = zoom
close_animation = zoom
duration = 200
startup_duration = 500

[place]
mode = center

[grid]
duration = 200
type = crossfade

[move]
enable_snap = true
snap_threshold = 10
WAYFIREINI

# ── PaperDE config ─────────────────────────────────────────────────────────
mkdir -p /home/liveuser/.config/paperde
cat > /home/liveuser/.config/paperde/paperde.conf << 'PAPERDECONF'
[Theme]
accent=#006874
background=#f2f7f9
surface=#ffffff
onSurface=#1a1a2e
secondaryText=#556677
border=#cdd7d9
radius=10
iconTheme=Papirus

[Dock]
position=bottom
size=52
iconSize=32
autohide=false
blur=true
opacity=0.88

[Wallpaper]
path=/usr/share/kibaos/wallpaper.png
mode=zoom

[Startup]
welcomeApp=/usr/local/bin/kiba-welcome
PAPERDECONF

# ── qt6ct ─────────────────────────────────────────────────────────────────
mkdir -p /home/liveuser/.config/qt6ct
cat > /home/liveuser/.config/qt6ct/qt6ct.conf << 'QT6CTCONF'
[Appearance]
icon_theme=Papirus
standard_dialogs=default
style=kvantum

[Fonts]
fixed="Noto Sans Mono,10,-1,5,50,0,0,0,0,0"
general="Noto Sans,11,-1,5,50,0,0,0,0,0"

[Interface]
buttonbox_layout=0
cursor_flash_time=1000
dialog_buttons_have_icons=1
double_click_interval=400
menus_have_icons=true
toolbutton_style=4
wheel_scroll_lines=3
QT6CTCONF

# ── Kvantum ────────────────────────────────────────────────────────────────
mkdir -p /home/liveuser/.config/Kvantum/KibaOS
cat > /home/liveuser/.config/Kvantum/KibaOS/KibaOS.kvconfig << 'KVCONFIG'
[%General]
author=WolfTech Innovations
comment=KibaOS Material You teal — Qt6
composite=true
blurring=true
popup_blurring=true
scroll_width=8
scroll_arrows=false
transient_scrollbar=true
progressbar_animation=true
progressbar_animation_frames=72
tooltip_shadow=true
KVCONFIG

cat > /home/liveuser/.config/Kvantum/kvantum.kvconfig << 'KVCFG'
[General]
theme=KibaOS
KVCFG

# ── GTK settings ───────────────────────────────────────────────────────────
mkdir -p /home/liveuser/.config/gtk-3.0
cat > /home/liveuser/.config/gtk-3.0/settings.ini << 'GTKSETTINGS'
[Settings]
gtk-theme-name=Adwaita
gtk-icon-theme-name=Papirus
gtk-font-name=Noto Sans 11
gtk-cursor-theme-size=24
gtk-xft-antialias=1
gtk-xft-hinting=1
gtk-xft-hintstyle=hintslight
gtk-xft-rgba=rgb
GTKSETTINGS

# ══════════════════════════════════════════════════════════════════════════
# WALLPAPER — set via multiple paths to ensure it actually applies
# ══════════════════════════════════════════════════════════════════════════
# 1. PaperDE reads paperde.conf [Wallpaper] section — already set above.
#
# 2. Wayfire/wf-background fallback: write the background plugin config
cat >> /home/liveuser/.config/wayfire.ini << 'WFBG'

[background-view]
# wf-background plugin — shows wallpaper behind all windows
app-id = kibaos-wallpaper
file = /usr/share/kibaos/wallpaper.png
WFBG

# 3. Write a small autostart script that sets wallpaper via swaybg as
#    belt-and-suspenders if PaperDE's own background handler isn't running.
#    swaybg is lightweight, has no GNOME/KDE deps.
pacman -S --noconfirm --needed swaybg 2>/dev/null || true

mkdir -p /home/liveuser/.config/autostart
cat > /home/liveuser/.config/autostart/kibaos-wallpaper.desktop << 'WPDESK'
[Desktop Entry]
Type=Application
Name=KibaOS Wallpaper
Exec=swaybg -m fill -i /usr/share/kibaos/wallpaper.png
X-GNOME-Autostart-enabled=true
Hidden=false
NoDisplay=false
WPDESK

# 4. Set gsettings for any GTK app that reads org.gnome.desktop.background
mkdir -p /home/liveuser/.config/dconf
cat > /home/liveuser/.config/dconf/user.ini << 'DCONF'
[org/gnome/desktop/background]
picture-uri='file:///usr/share/kibaos/wallpaper.png'
picture-uri-dark='file:///usr/share/kibaos/wallpaper.png'
picture-options='zoom'
DCONF

# ── Autostart: welcome + wallpaper ────────────────────────────────────────
cat > /home/liveuser/.config/autostart/kiba-welcome.desktop << 'WDESK'
[Desktop Entry]
Type=Application
Name=KibaOS Welcome
Exec=/usr/local/bin/kiba-welcome
X-GNOME-Autostart-enabled=true
WDESK

# ── SDDM user + service ────────────────────────────────────────────────────
systemctl enable sddm.service
useradd -r -s /usr/bin/nologin -d /var/lib/sddm -M sddm 2>/dev/null || true
mkdir -p /var/lib/sddm
chown sddm:sddm /var/lib/sddm
systemctl enable seatd.service 2>/dev/null || true

# ── Konsole profile — KibaOS branded ──────────────────────────────────────
KONSOLE_PROF_DIR="/home/liveuser/.local/share/konsole"
mkdir -p "${KONSOLE_PROF_DIR}"
cat > "${KONSOLE_PROF_DIR}/KibaOS.profile" << 'KONSOLEPROF'
[Appearance]
ColorScheme=Breeze
Font=Noto Sans Mono,11,-1,5,50,0,0,0,0,0

[General]
Name=KibaOS
Parent=FALLBACK/

[Scrolling]
HistorySize=10000
KONSOLEPROF

# ── Fix ownership ──────────────────────────────────────────────────────────
chown -R 1000:1000 /home/liveuser

# ── Size reduction ─────────────────────────────────────────────────────────
rm -rf /var/cache/pacman/pkg/*
rm -rf /usr/share/man/* /usr/share/info/* /usr/share/doc/*
find /usr/share/locale -mindepth 1 -maxdepth 1 \
  ! -name 'en_US' ! -name 'en_GB' ! -name 'locale.alias' \
  -exec rm -rf {} + 2>/dev/null || true
find /usr/lib/firmware -mindepth 1 -maxdepth 1 \
  ! -name 'i915'     ! -name 'amdgpu'   ! -name 'radeon'  \
  ! -name 'nouveau'  ! -name 'iwlwifi*' ! -name 'ath*'    \
  ! -name 'ath10k'   ! -name 'ath11k'   ! -name 'rtl_nic' \
  ! -name 'rtlwifi'  ! -name 'rtw88'    ! -name 'rtw89'   \
  ! -name 'mt7601u*' ! -name 'mediatek' ! -name 'sof'     \
  ! -name 'sof-tplg' ! -name 'intel'    ! -name 'qed'     \
  -exec rm -rf {} + 2>/dev/null || true
find /usr -type d -name '__pycache__' -exec rm -rf {} + 2>/dev/null || true
find /usr -name '*.pyc' -delete 2>/dev/null || true
find /usr/lib -name '*.a' -delete 2>/dev/null || true
rm -rf /usr/include/* 2>/dev/null || true
find /usr/share/icons -name 'icon-theme.cache' -delete 2>/dev/null || true
rm -rf /var/lib/pacman/sync/* /tmp/* /var/tmp/* 2>/dev/null || true

# Final ownership pass
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
  echo "║  KibaOS build complete!          ║"
  echo "║  ${ISO}.iso  ║"
  echo "╚══════════════════════════════════╝"
else
  echo "ERROR: ISO file not found after mkarchiso!"
  exit 1
fi
