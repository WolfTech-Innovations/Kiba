#!/bin/bash
# KibaOS ISO build script
# DE: LXQt + Openbox + Picom
# Greeter: SDDM with autologin for liveuser (Session=lxqt.desktop)
# Wallpaper: auto-set from WolfTech branding repo
set -ex

# ── Install ALL deps inside the container ────────────────────────────────
pacman-key --init
pacman-key --populate archlinux
pacman -Syy --noconfirm
pacman -Su  --noconfirm

pacman -S --noconfirm --needed \
  archiso base-devel git squashfs-tools libisoburn mtools dosfstools \
  \
  cmake extra-cmake-modules ninja \
  \
  kpmcore boost boost-libs yaml-cpp libpwquality \
  python python-yaml python-jsonschema \
  qt5-xmlpatterns kparts5 \
  \
  dbus pam polkit \
  networkmanager \
  fontconfig freetype2 \
  \
  openssl

# ── Setup ─────────────────────────────────────────────────────────────────
WORKDIR="/w"
ISO="kibaos-v${RUN_NUM}"
PROFILE="${WORKDIR}/kiba-profile"
AIROOTFS="${PROFILE}/airootfs"
SRCDIR="${WORKDIR}/src"

cd "${WORKDIR}"

echo "=== Configuring archiso profile ==="
cp -r /usr/share/archiso/configs/releng/ "${PROFILE}"
mkdir -p "${AIROOTFS}"
mkdir -p "${SRCDIR}"

# ── profiledef.sh ──────────────────────────────────────────────────────────
cat > "${PROFILE}/profiledef.sh" << 'PROFILEDEF'
#!/usr/bin/env bash
iso_name="kibaos"
iso_label="KIBAOS"
iso_publisher="WolfTech Innovations <https://github.com/WolfTech-Innovations>"
iso_application="KibaOS Live/Installation Medium"
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

# ── /etc/os-release ───────────────────────────────────────────────────────
mkdir -p "${AIROOTFS}/etc"
cat > "${AIROOTFS}/etc/os-release" << 'OSRELEASE'
NAME="KibaOS"
PRETTY_NAME="KibaOS"
ID=kibaos
ID_LIKE=arch
BUILD_ID=rolling
ANSI_COLOR="1;36"
HOME_URL="https://github.com/WolfTech-Innovations/Kiba"
DOCUMENTATION_URL="https://github.com/WolfTech-Innovations/Kiba/blob/main/WIKI.md"
SUPPORT_URL="https://github.com/WolfTech-Innovations/Kiba/issues"
LOGO=kibaos
OSRELEASE

# ── Package list ───────────────────────────────────────────────────────────
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
flatpak
xdg-desktop-portal-gtk
firefox
gparted
ntfs-3g
exfatprogs
cryptsetup
xorg-server
xorg-xinit
xorg-xrandr
xf86-video-vesa
lxqt
openbox
obconf-qt
picom
pcmanfm-qt
lxqt-archiver
qterminal
lximage-qt
pavucontrol-qt
breeze-icons
papirus-icon-theme
kvantum
qt5ct
sddm
qt5-declarative
qt5-quickcontrols2
openssl
plymouth
imagemagick
curl
PACKAGES

# ── initramfs ──────────────────────────────────────────────────────────────
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

# ── Boot menu ──────────────────────────────────────────────────────────────
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
title   KibaOS (safe mode — no Plymouth, verbose)
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
  MENU LABEL KibaOS (safe mode - no Plymouth, verbose)
  LINUX boot/x86_64/vmlinuz-linux
  INITRD boot/x86_64/initramfs-linux.img
  APPEND archisobasedir=arch archisolabel=KIBAOS cow_spacesize=1G plymouth.enable=0 nomodeset systemd.log_level=info
SYSLINUX_SAFE
fi

# ── SDDM autologin config ─────────────────────────────────────────────────
# CRITICAL: Session must be the .desktop filename without extension.
# LXQt installs /usr/share/xsessions/lxqt.desktop → Session=lxqt
mkdir -p "${AIROOTFS}/etc/sddm.conf.d"

cat > "${AIROOTFS}/etc/sddm.conf.d/kibaos.conf" << 'SDDMCONF'
[Autologin]
User=liveuser
Session=lxqt
Relogin=false

[Theme]
Current=kibaos

[General]
HaltCommand=/usr/bin/systemctl poweroff
RebootCommand=/usr/bin/systemctl reboot

[X11]
ServerArguments=-nolisten tcp
SDDMCONF

# ── SDDM KibaOS theme ─────────────────────────────────────────────────────
# Material You teal palette × macOS translucency vibes × ChromeOS simplicity
mkdir -p "${AIROOTFS}/usr/share/sddm/themes/kibaos"

cat > "${AIROOTFS}/usr/share/sddm/themes/kibaos/metadata.desktop" << 'SDDMMETA'
[SddmGreeterTheme]
Name=KibaOS
Description=KibaOS SDDM Theme
Author=WolfTech Innovations
License=MIT
Type=sddm-theme
Version=1.0
Website=https://github.com/WolfTech-Innovations/Kiba
SDDMMETA

cat > "${AIROOTFS}/usr/share/sddm/themes/kibaos/theme.conf" << 'SDDMTHEMECONF'
[General]
background=background.png
SDDMTHEMECONF

cat > "${AIROOTFS}/usr/share/sddm/themes/kibaos/Main.qml" << 'SDDMQML'
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import SddmComponents 2.0

Rectangle {
    id: root
    color: "transparent"

    // Blurred wallpaper background
    Image {
        anchors.fill: parent
        source: "background.png"
        fillMode: Image.PreserveAspectCrop
        smooth: true
        layer.enabled: true
        layer.effect: null
        opacity: 1.0
    }

    // Scrim overlay for readability
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: 0.38
    }

    // ── Centered login card (macOS-style frosted glass card) ────────────
    Rectangle {
        id: card
        anchors.centerIn: parent
        width: 340
        height: cardCol.implicitHeight + 56
        radius: 20
        color: "#ccffffff"   // semi-opaque white → frosted feel
        layer.enabled: true
        layer.effect: null   // no QtGraphicalEffects dep

        // Subtle border
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"
            border.color: "#33ffffff"
            border.width: 1
        }

        ColumnLayout {
            id: cardCol
            anchors {
                top: parent.top; left: parent.left; right: parent.right
                margins: 28
            }
            spacing: 14

            // Logo
            Image {
                Layout.alignment: Qt.AlignHCenter
                source: "logo.png"
                width: 72; height: 72
                fillMode: Image.PreserveAspectFit
                smooth: true
            }

            // Distro name
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "KibaOS"
                color: "#1a1a2e"
                font.pixelSize: 24
                font.weight: Font.Medium
                font.family: "Noto Sans"
            }

            // Clock
            Text {
                id: clock
                Layout.alignment: Qt.AlignHCenter
                color: "#444466"
                font.pixelSize: 13
                font.family: "Noto Sans"
                Timer {
                    interval: 1000; running: true; repeat: true
                    onTriggered: clock.text = Qt.formatDateTime(new Date(), "hh:mm  ·  dddd, MMMM d")
                }
                Component.onCompleted: clock.text = Qt.formatDateTime(new Date(), "hh:mm  ·  dddd, MMMM d")
            }

            // Divider
            Rectangle { Layout.fillWidth: true; height: 1; color: "#22000000"; opacity: 0.6 }

            // Username field
            TextField {
                id: userField
                Layout.fillWidth: true
                placeholderText: "Username"
                text: sddm.lastUser
                color: "#1a1a2e"
                placeholderTextColor: "#88667788"
                font.pixelSize: 14
                background: Rectangle {
                    color: "#eef5ff"
                    radius: 10
                    border.color: userField.activeFocus ? "#006874" : "#ccd0da"
                    border.width: userField.activeFocus ? 2 : 1
                }
                leftPadding: 14; rightPadding: 14
                topPadding: 12; bottomPadding: 12
                Keys.onReturnPressed: passwordField.forceActiveFocus()
            }

            // Password field
            TextField {
                id: passwordField
                Layout.fillWidth: true
                placeholderText: "Password"
                echoMode: TextInput.Password
                color: "#1a1a2e"
                placeholderTextColor: "#88667788"
                font.pixelSize: 14
                background: Rectangle {
                    color: "#eef5ff"
                    radius: 10
                    border.color: passwordField.activeFocus ? "#006874" : "#ccd0da"
                    border.width: passwordField.activeFocus ? 2 : 1
                }
                leftPadding: 14; rightPadding: 14
                topPadding: 12; bottomPadding: 12
                Keys.onReturnPressed: sddm.login(userField.text, passwordField.text, sessionModel.index(sessionBox.currentIndex, 0))
            }

            // Session selector (ChromeOS-style pill)
            ComboBox {
                id: sessionBox
                Layout.fillWidth: true
                model: sessionModel
                textRole: "name"
                currentIndex: sessionModel.lastIndex
                font.pixelSize: 12
                background: Rectangle {
                    color: "#e8f0fe"; radius: 10
                    border.color: "#ccd0da"; border.width: 1
                }
                contentItem: Text {
                    leftPadding: 14
                    text: sessionBox.displayText
                    color: "#444466"
                    font: sessionBox.font
                    verticalAlignment: Text.AlignVCenter
                }
            }

            // Sign-in button (Material You teal filled)
            Rectangle {
                Layout.fillWidth: true
                height: 44
                radius: 12
                color: loginMouse.containsMouse ? "#004f57" : "#006874"
                Behavior on color { ColorAnimation { duration: 120 } }

                Text {
                    anchors.centerIn: parent
                    text: "Sign In"
                    color: "#ffffff"
                    font.pixelSize: 14
                    font.weight: Font.Medium
                    font.family: "Noto Sans"
                }
                MouseArea {
                    id: loginMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: sddm.login(userField.text, passwordField.text, sessionModel.index(sessionBox.currentIndex, 0))
                }
            }

            // Error message
            Text {
                id: errorMsg
                Layout.alignment: Qt.AlignHCenter
                color: "#b3261e"
                font.pixelSize: 12
                visible: text !== ""
            }

            // Power row
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 28
                Text {
                    text: "⏻  Shut Down"
                    color: "#667788"; font.pixelSize: 12
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: sddm.powerOff() }
                }
                Text {
                    text: "↺  Restart"
                    color: "#667788"; font.pixelSize: 12
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

# ── Calamares config ───────────────────────────────────────────────────────
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
/* ── KibaOS Installer Theme — Material You × macOS × ChromeOS ──────────
   Teal primary (#006874), M3 surface tones, rounded corners, clean type. */

QWidget {
    background-color: #f2f7f9;
    color: #1a1a2e;
    font-family: "Noto Sans", "DejaVu Sans", sans-serif;
    font-size: 13px;
}

QStackedWidget, QFrame#mainContent {
    background-color: #ffffff;
    border-radius: 12px;
}

QLabel#labelTitle, QLabel[objectName="labelTitle"] {
    font-size: 26px;
    font-weight: 400;
    color: #1a1a2e;
    padding-top: 28px;
    padding-bottom: 6px;
}

QLabel {
    color: #3a4050;
    font-size: 13px;
    line-height: 1.5;
}

/* Primary button */
QPushButton#nextButton, QPushButton[objectName="nextButton"] {
    background-color: #006874;
    color: #ffffff;
    border: none;
    border-radius: 10px;
    padding: 10px 36px;
    font-size: 13px;
    font-weight: 600;
    min-width: 120px;
}
QPushButton#nextButton:hover   { background-color: #004f57; }
QPushButton#nextButton:pressed { background-color: #003640; }
QPushButton#nextButton:disabled { background-color: #a0c8ce; color: #ffffff; }

/* Secondary buttons */
QPushButton {
    background-color: #eef5f6;
    color: #006874;
    border: 1px solid #cdd7d9;
    border-radius: 10px;
    padding: 9px 24px;
    font-size: 13px;
    min-width: 90px;
}
QPushButton:hover   { background-color: #d8edef; border-color: #006874; }
QPushButton:pressed { background-color: #c0e4e8; }
QPushButton:disabled { color: #aabbbb; border-color: #dde8e9; background-color: #f2f7f9; }

/* Inputs */
QLineEdit, QComboBox {
    background-color: #eef5f6;
    border: 1.5px solid #cdd7d9;
    border-radius: 10px;
    padding: 8px 12px;
    color: #1a1a2e;
    selection-background-color: #006874;
    selection-color: #ffffff;
    font-size: 13px;
}
QLineEdit:focus, QComboBox:focus { border: 2px solid #006874; background-color: #f0fafb; }
QLineEdit:hover, QComboBox:hover { border-color: #778899; }

QComboBox::drop-down { border: none; width: 24px; }
QComboBox::down-arrow { width: 10px; height: 10px; }
QComboBox QAbstractItemView {
    background-color: #ffffff;
    border: 1px solid #cdd7d9;
    border-radius: 6px;
    selection-background-color: #d8edef;
    selection-color: #1a1a2e;
    padding: 4px;
}

/* Progress bar */
QProgressBar {
    background-color: #d8edef;
    border: none;
    border-radius: 4px;
    height: 6px;
    color: transparent;
}
QProgressBar::chunk { background-color: #006874; border-radius: 4px; }

/* Lists / trees */
QListView, QTreeView {
    background-color: #ffffff;
    border: 1.5px solid #d8e0e2;
    border-radius: 10px;
    alternate-background-color: #f5fafb;
    outline: none;
    font-size: 13px;
}
QListView::item, QTreeView::item { padding: 5px 8px; border-radius: 6px; }
QListView::item:hover, QTreeView::item:hover { background-color: #d8edef; }
QListView::item:selected, QTreeView::item:selected { background-color: #b0d8dc; color: #1a1a2e; }

/* Checkboxes / radios */
QCheckBox, QRadioButton { spacing: 8px; font-size: 13px; color: #1a1a2e; }
QCheckBox::indicator, QRadioButton::indicator {
    width: 18px; height: 18px;
    border-radius: 4px;
    border: 1.5px solid #99aaaa;
    background-color: #ffffff;
}
QCheckBox::indicator:hover, QRadioButton::indicator:hover { border-color: #006874; }
QCheckBox::indicator:checked { background-color: #006874; border-color: #006874; border-radius: 4px; }
QRadioButton::indicator { border-radius: 9px; }
QRadioButton::indicator:checked { background-color: #006874; border-color: #006874; }

/* Group boxes */
QGroupBox {
    border: 1.5px solid #d8e0e2;
    border-radius: 12px;
    margin-top: 18px;
    padding: 14px 12px 10px 12px;
    font-weight: 600;
    color: #1a1a2e;
}
QGroupBox::title {
    subcontrol-origin: margin;
    subcontrol-position: top left;
    left: 12px; padding: 0 6px;
    color: #556677;
    font-size: 11px; font-weight: 600;
    text-transform: uppercase; letter-spacing: 0.5px;
}

/* Scrollbars */
QScrollBar:vertical   { background: transparent; width: 7px; margin: 0; }
QScrollBar::handle:vertical { background: #c0d4d8; border-radius: 3px; min-height: 28px; }
QScrollBar::handle:vertical:hover { background: #90b0b8; }
QScrollBar::add-line:vertical, QScrollBar::sub-line:vertical { height: 0; }
QScrollBar:horizontal { background: transparent; height: 7px; }
QScrollBar::handle:horizontal { background: #c0d4d8; border-radius: 3px; min-width: 28px; }
QScrollBar::handle:horizontal:hover { background: #90b0b8; }
QScrollBar::add-line:horizontal, QScrollBar::sub-line:horizontal { width: 0; }

/* Tooltip */
QToolTip {
    background-color: #1a1a2e;
    color: #e8f0f2;
    border: none; border-radius: 6px;
    padding: 5px 8px; font-size: 12px;
}
QSS

cat > "${AIROOTFS}/usr/share/calamares/branding/kibaos/show.qml" << 'SHOWQML'
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: root
    anchors.fill: parent
    property bool activatedInCalamares: false

    property var slides: [
        { icon: "🐺", heading: "Welcome to KibaOS", body: "We're setting everything up for you. This usually takes around 5–10 minutes depending on your hardware." },
        { icon: "⚡", heading: "Fast by default",    body: "KibaOS is built on Arch Linux, so you always get the latest software — fresh from upstream." },
        { icon: "🎨", heading: "Beautiful by design", body: "The desktop blends ChromeOS simplicity, macOS elegance, and Material You color science." },
        { icon: "🔒", heading: "Your system, your rules", body: "Full disk encryption, a powerful package manager, and the entire AUR are at your fingertips." },
        { icon: "💡", heading: "Need help?",         body: "Visit github.com/WolfTech-Innovations/Kiba for guides, the wiki, and to report issues." }
    ]
    property int currentSlide: 0

    Timer {
        interval: 6000; running: root.activatedInCalamares; repeat: true
        onTriggered: root.currentSlide = (root.currentSlide + 1) % root.slides.length
    }

    Rectangle {
        anchors.fill: parent
        color: "#f2f7f9"

        // Teal top strip
        Rectangle {
            id: topStrip
            anchors { top: parent.top; left: parent.left; right: parent.right }
            height: parent.height * 0.38
            color: "#006874"

            Rectangle {
                anchors.centerIn: parent; width: 180; height: 180; radius: 90
                color: "#ffffff"; opacity: 0.08
            }
            Image {
                anchors.centerIn: parent; source: "logo.png"
                width: 96; height: 96; fillMode: Image.PreserveAspectFit; smooth: true
                NumberAnimation on scale { from: 0.8; to: 1.0; duration: 600; easing.type: Easing.OutBack; running: true }
            }
        }

        // Slide card
        Rectangle {
            id: card
            anchors { top: topStrip.bottom; topMargin: -20; horizontalCenter: parent.horizontalCenter }
            width: Math.min(parent.width - 64, 520)
            height: contentCol.implicitHeight + 48
            radius: 16
            color: "#ffffff"

            ColumnLayout {
                id: contentCol
                anchors { top: parent.top; left: parent.left; right: parent.right; margins: 32 }
                spacing: 12

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.slides[root.currentSlide].icon
                    font.pixelSize: 36
                }
                Text {
                    id: slideHeading
                    Layout.alignment: Qt.AlignHCenter; Layout.fillWidth: true
                    text: root.slides[root.currentSlide].heading
                    font.pixelSize: 20; font.weight: Font.Medium
                    color: "#1a1a2e"; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap
                    Behavior on text {
                        SequentialAnimation {
                            NumberAnimation { target: slideHeading; property: "opacity"; to: 0; duration: 180 }
                            PropertyAction { }
                            NumberAnimation { target: slideHeading; property: "opacity"; to: 1; duration: 220 }
                        }
                    }
                }
                Text {
                    id: slideBody
                    Layout.alignment: Qt.AlignHCenter; Layout.fillWidth: true
                    text: root.slides[root.currentSlide].body
                    font.pixelSize: 13; color: "#556677"
                    horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap; lineHeight: 1.5
                    Behavior on text {
                        SequentialAnimation {
                            NumberAnimation { target: slideBody; property: "opacity"; to: 0; duration: 180 }
                            PropertyAction { }
                            NumberAnimation { target: slideBody; property: "opacity"; to: 1; duration: 220 }
                        }
                    }
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
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.currentSlide = index }
                        }
                    }
                }
            }
        }

        Text {
            id: statusLabel
            anchors { horizontalCenter: parent.horizontalCenter; bottom: progressTrack.top; bottomMargin: 10 }
            text: "Installing KibaOS…"; font.pixelSize: 12; color: "#889aaa"
        }

        Rectangle {
            id: progressTrack
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: 5; color: "#d0eaee"
            Rectangle {
                id: progressFill
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
  - "-": "echo '=== KibaOS: migrating live session settings to new user ==='"
  - "-": |
          NEW_USER=$(python3 -c "
          import json, sys
          for path in [
              '/etc/calamares/global_storage.json',
              '/tmp/calamares-global-storage.json',
          ]:
              try:
                  d = json.load(open(path))
                  u = d.get('username') or d.get('loginName') or ''
                  if u:
                      print(u)
                      sys.exit(0)
              except Exception:
                  pass
          import pwd
          for p in pwd.getpwall():
              if p.pw_uid >= 1000 and p.pw_name != 'liveuser':
                  print(p.pw_name)
                  sys.exit(0)
          print('')
          ")
          [ -z "$NEW_USER" ] && { echo 'WARNING: no username found, skipping migration'; exit 0; }
          NEW_HOME="/home/${NEW_USER}"
          LIVE_HOME="/home/liveuser"

          # LXQt config
          for d in lxqt openbox pcmanfm-qt qt5ct; do
              src="${LIVE_HOME}/.config/${d}"
              dst="${NEW_HOME}/.config/${d}"
              [ -d "$src" ] || continue
              mkdir -p "$(dirname "$dst")"
              cp -a "$src" "$dst"
          done

          # GTK
          for d in .config/gtk-3.0 .config/gtk-4.0 .gtkrc-2.0; do
              src="${LIVE_HOME}/${d}"
              dst="${NEW_HOME}/${d}"
              [ -e "$src" ] || continue
              mkdir -p "$(dirname "$dst")"
              cp -a "$src" "$dst"
          done

          # Wallpaper / icons
          [ -f "${LIVE_HOME}/.config/lxqt/lxqt.conf" ] && \
              cp "${LIVE_HOME}/.config/lxqt/lxqt.conf" "${NEW_HOME}/.config/lxqt/lxqt.conf"

          chown -R "${NEW_USER}:${NEW_USER}" "${NEW_HOME}/.config" 2>/dev/null || true
          echo "=== Settings migrated to ${NEW_HOME} ==="
SHELLPROC

cat > "${AIROOTFS}/etc/calamares/modules/displaymanager.conf" << 'DMCONF'
---
displaymanagers:
  - sddm
defaultDesktopEnvironment:
  executable: "startlxqt"
  desktopFile: "lxqt"
basicSetup: false
DMCONF

# ── pacman.conf ───────────────────────────────────────────────────────────
PACMAN_CONF="${PROFILE}/pacman.conf"
if [ -f "${PACMAN_CONF}" ]; then
  grep -q 'NoExtract' "${PACMAN_CONF}" || \
    sed -i '/^\[options\]/a NoExtract  = usr/share/man/* usr/share/info/* usr/share/doc/*\nNoExtract  = usr/share/locale/* !usr/share/locale/en_US/* !usr/share/locale/en_GB/* !usr/share/locale/locale.alias' \
    "${PACMAN_CONF}"
fi

# ── liveuser account ───────────────────────────────────────────────────────
mkdir -p "${AIROOTFS}/etc"
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

# ── systemd service symlinks ────────────────────────────────────────────────
WANTS="${AIROOTFS}/etc/systemd/system"
mkdir -p "${WANTS}/default.target.wants" "${WANTS}/multi-user.target.wants"

ln -sf /usr/lib/systemd/system/graphical.target        "${WANTS}/default.target"
ln -sf /usr/lib/systemd/system/sddm.service            "${WANTS}/display-manager.service"
ln -sf /usr/lib/systemd/system/NetworkManager.service  "${WANTS}/multi-user.target.wants/NetworkManager.service"
ln -sf /usr/lib/systemd/system/NetworkManager-dispatcher.service \
       "${WANTS}/dbus-org.freedesktop.nm-dispatcher.service"
ln -sf /usr/lib/systemd/system/bluetooth.service       "${WANTS}/multi-user.target.wants/bluetooth.service"
ln -sf /usr/lib/systemd/system/pacman-init.service     "${WANTS}/multi-user.target.wants/pacman-init.service"

# ── customize_airootfs.sh ─────────────────────────────────────────────────
mkdir -p "${AIROOTFS}/root"
cat > "${AIROOTFS}/root/customize_airootfs.sh" << 'CUSTOMIZE'
#!/usr/bin/env bash
set -e

# ── Locale ─────────────────────────────────────────────────────────────────
sed -i 's/#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
locale-gen
echo 'LANG=en_US.UTF-8' > /etc/locale.conf

# ── Hostname ───────────────────────────────────────────────────────────────
echo 'kibaos' > /etc/hostname
cat > /etc/hosts << 'HOSTS'
127.0.0.1   localhost
::1         localhost
127.0.1.1   kibaos.localdomain kibaos
HOSTS

# ── Groups ─────────────────────────────────────────────────────────────────
for g in users wheel audio video input network storage; do
  groupadd -r "$g" 2>/dev/null || true
done
for g in users wheel audio video input network storage; do
  usermod -aG "$g" liveuser 2>/dev/null || true
done
echo "liveuser:live" | chpasswd

# ── systemd tunables ───────────────────────────────────────────────────────
sed -i 's/#Storage=auto/Storage=volatile/'                    /etc/systemd/journald.conf
sed -i 's/#HandleLidSwitch=suspend/HandleLidSwitch=ignore/'   /etc/systemd/logind.conf
sed -i 's/#HandleSuspendKey=suspend/HandleSuspendKey=ignore/' /etc/systemd/logind.conf

# ── Root shell ─────────────────────────────────────────────────────────────
grep -qx '/usr/bin/zsh' /etc/shells || echo '/usr/bin/zsh' >> /etc/shells
chsh -s /usr/bin/zsh root

# ── liveuser home skeleton ─────────────────────────────────────────────────
cp -aT /etc/skel/ /home/liveuser/ 2>/dev/null || true
chown -R 1000:1000 /home/liveuser
chmod 750 /home/liveuser

# ── Download branding assets ───────────────────────────────────────────────
WALLPAPER_URL="https://github.com/WolfTech-Innovations/Kiba/blob/78699a64fff1f243162f50ffba206a2de0d3272e/branding/wallpaper.png?raw=true"
LOGO_URL="https://github.com/WolfTech-Innovations/Kiba/blob/main/branding/boot.png?raw=true"
WALLPAPER_DEST="/usr/share/kibaos/wallpaper.png"
LOGO_RAW="/tmp/kibaos_boot_raw.png"

mkdir -p /usr/share/kibaos
curl -fL --retry 3 --retry-delay 2 -o "${WALLPAPER_DEST}" "${WALLPAPER_URL}" || true
curl -fL --retry 3 --retry-delay 2 -o "${LOGO_RAW}"       "${LOGO_URL}"      || true

# Calamares / SDDM logos
if [ -f "${LOGO_RAW}" ]; then
  magick "${LOGO_RAW}" -filter Lanczos -resize 256x256 \
    /usr/share/calamares/branding/kibaos/logo.png
  magick "${LOGO_RAW}" -filter Lanczos -resize 96x96  \
    /usr/share/sddm/themes/kibaos/logo.png
  rm -f "${LOGO_RAW}"
fi

# SDDM background: use actual wallpaper if downloaded, else generate gradient
if [ -f "${WALLPAPER_DEST}" ]; then
  magick "${WALLPAPER_DEST}" -filter Lanczos -resize 1920x1080^ \
    -gravity Center -extent 1920x1080 \
    /usr/share/sddm/themes/kibaos/background.png
else
  magick -size 1920x1080 gradient:"#004f57-#0d1b2a" \
    /usr/share/sddm/themes/kibaos/background.png
fi

# ── LXQt config: ChromeOS × macOS × Material You ─────────────────────────
# All configs land in liveuser's home; Calamares shellprocess migrates them.

LXQT_CFG="/home/liveuser/.config/lxqt"
mkdir -p "${LXQT_CFG}"

# ── lxqt.conf: icon theme, font, Qt style ─────────────────────────────────
cat > "${LXQT_CFG}/lxqt.conf" << 'LXQTCONF'
[General]
icon_theme=Papirus
singleclick_activate=false
theme=kibaos

[Qt]
font="Noto Sans,11,-1,5,50,0,0,0,0,0"
style=kvantum
LXQTCONF

# ── Session: Openbox WM + Picom compositor ─────────────────────────────────
cat > "${LXQT_CFG}/session.conf" << 'SESSIONCONF'
[General]
__userfile__=true
window_manager=openbox
desktop_manager=pcmanfm-qt

[Environment]
QT_QPA_PLATFORMTHEME=qt5ct
QT_AUTO_SCREEN_SCALE_FACTOR=1
SESSIONCONF

# ── lxqt-panel: ChromeOS-style bottom shelf ───────────────────────────────
# Single panel, bottom, full-width, 48px tall.
# Plugins: app-menu (launcher) | taskbar (open windows, centered) | spacer | systray | clock
cat > "${LXQT_CFG}/panel.conf" << 'PANELCONF'
[General]
panels=panel1

[panel1]
alignment=0
iconSize=24
lineCount=1
panelSize=48
position=Bottom
show=true
hidable=false
visibleMargin=true

plugins=mainmenu, quicklaunch, taskbar, spacer, statusnotifier, volume, clock, showdesktop

[mainmenu]
plugin=mainmenu
alignment=left
buttonIcon=kibaos
buttonText=

[quicklaunch]
plugin=quicklaunch
alignment=left
apps\1\desktop=/usr/share/applications/firefox.desktop
apps\2\desktop=/usr/share/applications/qterminal.desktop
apps\3\desktop=/usr/share/applications/pcmanfm-qt.desktop
apps\4\desktop=/usr/share/applications/lximage-qt.desktop
apps\size=4

[taskbar]
plugin=taskbar
alignment=center
buttonStyle=IconAndText
closeOnMiddleClick=true
cycleOnWheelScroll=true
showOnlyCurrentScreen=false
showOnlyCurrentDesktop=false
buttonWidth=200

[spacer]
plugin=spacer
type=expanding

[statusnotifier]
plugin=statusnotifier

[volume]
plugin=volume

[clock]
plugin=clock
alignment=right
dateFormat=ddd d MMM
timeFormat=hh:mm
PANELCONF

# ── Picom config: macOS-style shadows + subtle translucency ───────────────
mkdir -p /home/liveuser/.config/picom
cat > /home/liveuser/.config/picom/picom.conf << 'PICOMCONF'
# KibaOS Picom — macOS-inspired compositing
backend = "glx";
glx-copy-from-front = false;
vsync = true;

# Shadows (macOS-style soft drop shadows)
shadow = true;
shadow-radius = 18;
shadow-offset-x = -8;
shadow-offset-y = -8;
shadow-opacity = 0.32;
shadow-exclude = [
  "name = 'Notification'",
  "class_g = 'Conky'",
  "class_g ?= 'Notify-osd'",
  "_GTK_FRAME_EXTENTS@:c",
  "window_type = 'dock'",
  "window_type = 'desktop'"
];

# Fading — snappy, not sluggish
fading = true;
fade-in-step = 0.06;
fade-out-step = 0.06;
fade-delta = 4;

# Transparency — panels and inactive windows get a subtle tint
inactive-opacity = 0.94;
active-opacity = 1.0;
frame-opacity = 1.0;
inactive-opacity-override = false;

opacity-rule = [
  "95:class_g = 'lxqt-panel'",
  "100:name = 'KibaOS'",
  "92:class_g = 'QTerminal'",
  "100:class_g = 'Firefox'"
];

# Rounded corners
corner-radius = 10;
rounded-corners-exclude = [
  "window_type = 'dock'",
  "window_type = 'desktop'"
];

# Blur (frosted glass on panels/menus)
blur-method = "dual_kawase";
blur-strength = 4;
blur-background = true;
blur-background-exclude = [
  "window_type = 'dock'",
  "window_type = 'desktop'",
  "class_g = 'slop'"
];
PICOMCONF

# ── Openbox config: macOS × Material You window decorations ───────────────
mkdir -p /home/liveuser/.config/openbox
cat > /home/liveuser/.config/openbox/rc.xml << 'OBRCXML'
<?xml version="1.0" encoding="UTF-8"?>
<openbox_config xmlns="http://openbox.org/3.4/rc"
                xmlns:xi="http://www.w3.org/2001/XInclude">

  <theme>
    <!-- We ship a custom OB theme below -->
    <name>KibaOS</name>
    <titleLayout>NLIMC</titleLayout>
    <keepBorder>no</keepBorder>
    <animateIconify>yes</animateIconify>
    <font place="ActiveWindow">
      <name>Noto Sans</name>
      <size>10</size>
      <weight>Bold</weight>
      <slant>Normal</slant>
    </font>
    <font place="InactiveWindow">
      <name>Noto Sans</name>
      <size>10</size>
      <weight>Normal</weight>
      <slant>Normal</slant>
    </font>
  </theme>

  <desktops>
    <number>4</number>
    <firstdesk>1</firstdesk>
    <names>
      <name>Home</name>
      <name>Work</name>
      <name>Media</name>
      <name>Other</name>
    </names>
    <popupTime>875</popupTime>
  </desktops>

  <resize>
    <drawContents>yes</drawContents>
    <popupShow>Nonpixel</popupShow>
    <popupPosition>Center</popupPosition>
  </resize>

  <mouse>
    <dragThreshold>8</dragThreshold>
    <doubleClickTime>200</doubleClickTime>
    <screenEdgeWarpTime>400</screenEdgeWarpTime>
    <screenEdgeWarpMouse>false</screenEdgeWarpMouse>
  </mouse>

  <keyboard>
    <!-- macOS-style: Super+Q closes, Super+M minimises, Super+F fullscreen -->
    <keybind key="Super-q">
      <action name="Close"/>
    </keybind>
    <keybind key="Super-m">
      <action name="Iconify"/>
    </keybind>
    <keybind key="Super-f">
      <action name="ToggleMaximize"/>
    </keybind>
    <!-- ChromeOS-style: alt+tab, ctrl+alt+t terminal -->
    <keybind key="A-Tab">
      <action name="NextWindow">
        <finalactions>
          <action name="Focus"/>
          <action name="Raise"/>
          <action name="Unshade"/>
        </finalactions>
      </action>
    </keybind>
    <keybind key="C-A-t">
      <action name="Execute">
        <command>qterminal</command>
      </action>
    </keybind>
    <!-- Screenshot -->
    <keybind key="Print">
      <action name="Execute">
        <command>scrot '%Y-%m-%d_%H-%M-%S.png' -e 'mv $f ~/Pictures/'</command>
      </action>
    </keybind>
  </keyboard>

  <applications>
    <!-- macOS-feel: windows open in center -->
    <application class="*">
      <placement>
        <policy>UnderMouse</policy>
        <monitor>Primary</monitor>
        <primarymonitor>1</primarymonitor>
        <center>yes</center>
      </placement>
    </application>
  </applications>

</openbox_config>
OBRCXML

# ── Openbox theme: clean light with teal accents ──────────────────────────
OB_THEME_DIR="/usr/share/themes/KibaOS/openbox-3"
mkdir -p "${OB_THEME_DIR}"
cat > "${OB_THEME_DIR}/themerc" << 'THEMERC'
# KibaOS Openbox Theme
# Inspired by macOS Sonoma light + Material You teal

# ── Window border/geometry ──────────────────────────────────────────────
border.width: 1
padding.width: 6
padding.height: 4
window.client.padding.width: 0
window.client.padding.height: 0

# ── Title bar ───────────────────────────────────────────────────────────
titlebar.height: 30

window.active.title.bg: flat solid
window.active.title.bg.color: #f2f7f9
window.active.title.separator.color: #c8d8da

window.inactive.title.bg: flat solid
window.inactive.title.bg.color: #e8eef0
window.inactive.title.separator.color: #d8e0e2

# ── Title text ──────────────────────────────────────────────────────────
window.active.label.text.color: #1a1a2e
window.inactive.label.text.color: #889aaa
window.active.label.bg: parentrelative
window.inactive.label.bg: parentrelative

# ── Border colors ───────────────────────────────────────────────────────
window.active.border.color: #006874
window.inactive.border.color: #cdd7d9

# ── Buttons (macOS style: circle close/min/max on left) ─────────────────
# Close
window.active.button.close.bg: flat solid
window.active.button.close.bg.color: #ff5f57
window.active.button.close.image.color: #1a1a2e
window.active.button.close.pressed.bg: flat solid
window.active.button.close.pressed.bg.color: #d44040

# Iconify (minimize)
window.active.button.iconify.bg: flat solid
window.active.button.iconify.bg.color: #febc2e
window.active.button.iconify.image.color: #1a1a2e

# Maximize
window.active.button.max.bg: flat solid
window.active.button.max.bg.color: #28c840
window.active.button.max.image.color: #1a1a2e

# Inactive buttons
window.inactive.button.close.bg: flat solid
window.inactive.button.close.bg.color: #d0d8da
window.inactive.button.close.image.color: #889aaa
window.inactive.button.iconify.bg: flat solid
window.inactive.button.iconify.bg.color: #d0d8da
window.inactive.button.iconify.image.color: #889aaa
window.inactive.button.max.bg: flat solid
window.inactive.button.max.bg.color: #d0d8da
window.inactive.button.max.image.color: #889aaa

# ── Menu ────────────────────────────────────────────────────────────────
menu.border.color: #cdd7d9
menu.border.width: 1
menu.items.bg: flat solid
menu.items.bg.color: #ffffff
menu.items.text.color: #1a1a2e
menu.items.active.bg: flat solid
menu.items.active.bg.color: #d8edef
menu.items.active.text.color: #006874
menu.title.bg: flat solid
menu.title.bg.color: #f2f7f9
menu.title.text.color: #1a1a2e
menu.separator.color: #e0e8ea
menu.separator.width: 1
menu.separator.padding.width: 6
menu.separator.padding.height: 3

# ── Handles / grips ─────────────────────────────────────────────────────
window.active.handle.bg: flat solid
window.active.handle.bg.color: #e0eef0
window.inactive.handle.bg: flat solid
window.inactive.handle.bg.color: #e8eef0
window.handle.width: 4

window.active.grip.bg: flat solid
window.active.grip.bg.color: #c0d8dc
window.inactive.grip.bg: flat solid
window.inactive.grip.bg.color: #d0dfe2
THEMERC

# ── LXQt custom QSS theme: Material You teal ──────────────────────────────
LXQT_THEME_DIR="/usr/share/lxqt/themes/kibaos"
mkdir -p "${LXQT_THEME_DIR}"

cat > "${LXQT_THEME_DIR}/lxqt-panel.qss" << 'PANELQSS'
/* KibaOS Panel Theme — ChromeOS shelf × macOS dock × Material You teal */

/* ── Panel background: frosted glass via Picom blur layer ─────────────── */
LXQtPanel, LXQtPanel #BackgroundWidget {
    background-color: rgba(242, 247, 249, 0.82);
    border-top: 1px solid rgba(0, 104, 116, 0.18);
    color: #1a1a2e;
}

/* ── Panel buttons / taskbar items ───────────────────────────────────── */
LXQtPanel #BackgroundWidget QToolButton,
LXQtPanel #BackgroundWidget QAbstractButton {
    background-color: transparent;
    border: none;
    border-radius: 8px;
    padding: 4px 8px;
    color: #1a1a2e;
    font-family: "Noto Sans";
    font-size: 12px;
    min-width: 0;
}

LXQtPanel #BackgroundWidget QToolButton:hover,
LXQtPanel #BackgroundWidget QAbstractButton:hover {
    background-color: rgba(0, 104, 116, 0.12);
}

LXQtPanel #BackgroundWidget QToolButton:pressed,
LXQtPanel #BackgroundWidget QAbstractButton:pressed {
    background-color: rgba(0, 104, 116, 0.22);
}

/* Active / focused task in taskbar gets a teal underline pill */
LXQtPanel #BackgroundWidget QToolButton:checked {
    background-color: rgba(0, 104, 116, 0.14);
    border-bottom: 3px solid #006874;
    border-radius: 8px;
    color: #006874;
    font-weight: bold;
}

/* ── Clock ────────────────────────────────────────────────────────────── */
Plugin > QLabel,
LXQtClock QLabel {
    color: #1a1a2e;
    font-family: "Noto Sans";
    font-size: 12px;
    padding: 0 8px;
}

/* ── System tray ─────────────────────────────────────────────────────── */
StatusNotifierButton {
    background-color: transparent;
    border-radius: 6px;
    padding: 4px;
    qproperty-iconSize: 20;
}
StatusNotifierButton:hover {
    background-color: rgba(0, 104, 116, 0.12);
}

/* ── Volume plugin ───────────────────────────────────────────────────── */
LXQtVolume {
    qproperty-iconSize: 20;
}

/* ── App menu launcher button ────────────────────────────────────────── */
MainMenu {
    background-color: transparent;
    border: none;
    border-radius: 8px;
    padding: 4px 10px;
    font-size: 13px;
    font-weight: 600;
    color: #006874;
    qproperty-iconSize: 24;
}
MainMenu:hover { background-color: rgba(0, 104, 116, 0.14); }
MainMenu:pressed { background-color: rgba(0, 104, 116, 0.24); }

/* ── App menu popup (ChromeOS launcher feel) ─────────────────────────── */
QMenu {
    background-color: #f2f7f9;
    border: 1px solid #cde4e7;
    border-radius: 12px;
    padding: 6px;
    color: #1a1a2e;
    font-size: 13px;
}
QMenu::item {
    padding: 7px 16px;
    border-radius: 8px;
}
QMenu::item:selected {
    background-color: rgba(0, 104, 116, 0.15);
    color: #006874;
}
QMenu::separator {
    height: 1px;
    background-color: #cde4e7;
    margin: 4px 8px;
}
PANELQSS

cat > "${LXQT_THEME_DIR}/stylesheet.qss" << 'THEMEQSS'
/* KibaOS Global QSS — shared across all LXQt widgets */

QWidget {
    font-family: "Noto Sans", "DejaVu Sans", sans-serif;
    font-size: 12px;
    color: #1a1a2e;
    background-color: #f2f7f9;
}

/* Application windows get a clean white surface */
QMainWindow, QDialog {
    background-color: #f2f7f9;
}

/* ── Buttons ─────────────────────────────────────────────────────────── */
QPushButton {
    background-color: #006874;
    color: #ffffff;
    border: none;
    border-radius: 8px;
    padding: 7px 20px;
    font-weight: 600;
}
QPushButton:hover   { background-color: #004f57; }
QPushButton:pressed { background-color: #003640; }
QPushButton:flat {
    background-color: transparent;
    color: #006874;
}
QPushButton:flat:hover { background-color: rgba(0,104,116,0.1); }

/* ── Inputs ──────────────────────────────────────────────────────────── */
QLineEdit, QTextEdit, QPlainTextEdit {
    background-color: #eef5f6;
    border: 1.5px solid #cdd7d9;
    border-radius: 8px;
    padding: 6px 10px;
    color: #1a1a2e;
    selection-background-color: #006874;
    selection-color: #ffffff;
}
QLineEdit:focus, QTextEdit:focus, QPlainTextEdit:focus {
    border: 2px solid #006874;
    background-color: #f0fafb;
}

/* ── Scrollbars ───────────────────────────────────────────────────────── */
QScrollBar:vertical   { background: transparent; width: 7px; }
QScrollBar::handle:vertical { background: #b0c8cc; border-radius: 3px; min-height: 24px; }
QScrollBar::handle:vertical:hover { background: #80aab0; }
QScrollBar::add-line:vertical, QScrollBar::sub-line:vertical { height: 0; }
QScrollBar:horizontal { background: transparent; height: 7px; }
QScrollBar::handle:horizontal { background: #b0c8cc; border-radius: 3px; min-width: 24px; }
QScrollBar::handle:horizontal:hover { background: #80aab0; }
QScrollBar::add-line:horizontal, QScrollBar::sub-line:horizontal { width: 0; }

/* ── Tabs ─────────────────────────────────────────────────────────────── */
QTabBar::tab {
    background-color: transparent;
    border: none;
    padding: 8px 16px;
    color: #556677;
    border-bottom: 2px solid transparent;
}
QTabBar::tab:selected {
    color: #006874;
    border-bottom: 2px solid #006874;
    font-weight: 600;
}
QTabBar::tab:hover:!selected {
    color: #1a1a2e;
    background-color: rgba(0,104,116,0.08);
    border-radius: 6px 6px 0 0;
}

/* ── Lists / trees ───────────────────────────────────────────────────── */
QListView, QTreeView, QTableView {
    background-color: #ffffff;
    border: 1px solid #d8e0e2;
    border-radius: 8px;
    alternate-background-color: #f5fafb;
    outline: none;
}
QListView::item:hover, QTreeView::item:hover { background-color: #d8edef; border-radius: 4px; }
QListView::item:selected, QTreeView::item:selected { background-color: #b0d8dc; color: #1a1a2e; }

/* ── Tooltip ─────────────────────────────────────────────────────────── */
QToolTip {
    background-color: #1a1a2e;
    color: #e8f0f2;
    border: none; border-radius: 6px;
    padding: 4px 8px; font-size: 11px;
}
THEMEQSS

# ── qt5ct config (Qt style bridge for non-LXQt apps) ──────────────────────
mkdir -p /home/liveuser/.config/qt5ct
cat > /home/liveuser/.config/qt5ct/qt5ct.conf << 'QT5CTCONF'
[Appearance]
color_scheme_path=/home/liveuser/.config/qt5ct/colors/kibaos.conf
custom_palette=true
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
gui_effects=@Invalid()
keyboard_scheme=2
menus_have_icons=true
show_shortcuts_in_context_menus=true
stylesheets=@Invalid()
toolbutton_style=4
underline_shortcut=1
wheel_scroll_lines=3
QT5CTCONF

# ── Kvantum theme (Material You teal) ─────────────────────────────────────
mkdir -p /home/liveuser/.config/Kvantum/KibaOS
cat > /home/liveuser/.config/Kvantum/KibaOS/KibaOS.kvconfig << 'KVCONFIG'
[%General]
author=WolfTech Innovations
comment=KibaOS Material You teal theme
x11drag=all
alt_mnemonic=true
left_tabs=false
joined_inactive_tabs=true
attach_inactive_tabs=false
mirror_doc_tabs=true
scroll_width=8
scroll_arrows=false
scroll_min_extent=36
transient_scrollbar=true
tooltip_delay=-1
tooltip_shadow=true
composite=true
menu_shadow_depth=6
submenu_overlap=0
spread_progressbar=false
progressbar_animation=true
progressbar_animation_frames=72
menubar_mouse_tracking=true
toolbutton_alignment=middle
double_click=false
translucent_windows=false
blurring=true
popup_blurring=true
opaque=kaffeine,kmplayer
reduce_window_opacity=0
reduce_menu_opacity=0
groupbox_top_label=false
fill_rubberband=false
small_icon_size=16
large_icon_size=32
button_icon_size=16
toolbar_icon_size=16
combo_as_lineedit=false
square_combo_button=false
groupbox_no_border=false
layout_spacing=4
layout_margin=6
no_inactiveness=false
no_window_pattern=false
KVCONFIG

cat > /home/liveuser/.config/Kvantum/KibaOS/KibaOS.svgz << 'KVSVGZ_SKIP'
KVSVGZ_SKIP
# Note: Kvantum SVG is complex; we rely on the kvconfig for color hints
# and fall back to the Fusion style palette. Real Kvantum SVG theming
# requires a pre-built .svgz — ship via AUR package in production.

# ── PCManFM-Qt desktop config: set wallpaper ──────────────────────────────
mkdir -p /home/liveuser/.config/pcmanfm-qt/lxqt
cat > /home/liveuser/.config/pcmanfm-qt/lxqt/settings.conf << 'PCMANFM_SETTINGS'
[Behavior]
NoUsbTrash=false
SingleWindowMode=false

[System]
FallbackIconThemeName=Papirus

[Thumbnail]
MaxThumbnailFileSize=10485760
ShowThumbnails=true

[Volume]
AutoRun=false
CloseOnUnmount=true
MountOnStartup=false
MountRemovable=false
PCMANFM_SETTINGS

# wallpaper-0.conf keys depend on screen; create a sensible default
# lxqt-config-appearance also sets this via pcmanfm-qt --set-wallpaper
mkdir -p /home/liveuser/.config/pcmanfm-qt/lxqt
cat > /home/liveuser/.config/pcmanfm-qt/lxqt/desktop-items-0.conf << 'DESKTOPWP'
[Desktop]
BgColor=#006874
BgImageFile=/usr/share/kibaos/wallpaper.png
BgImageStyle=zoom
BgMode=wallpaper
ShowHidden=false
SortColumn=name
SortOrder=ascending
TextShadowColor=#00000000
Wallpaper=/usr/share/kibaos/wallpaper.png
WallpaperMode=zoom
DESKTOPWP

# ── Autostart: picom compositor ────────────────────────────────────────────
mkdir -p /home/liveuser/.config/autostart
cat > /home/liveuser/.config/autostart/picom.desktop << 'PICOMDESK'
[Desktop Entry]
Type=Application
Name=Picom Compositor
Exec=picom --config /home/liveuser/.config/picom/picom.conf -b
X-GNOME-Autostart-enabled=true
Hidden=false
NoDisplay=false
Comment=GPU-accelerated compositor with blur and shadows
PICOMDESK

# ── Autostart: pcmanfm-qt desktop (LXQt Module — auto-restarted on crash) ─
cat > /home/liveuser/.config/autostart/pcmanfm-qt-desktop.desktop << 'PCMANFMDESK'
[Desktop Entry]
Type=Application
Name=Desktop
Exec=pcmanfm-qt --desktop --profile lxqt
OnlyShowIn=LXQt;
X-LXQt-Module=true
PCMANFMDESK

# ── Autostart: KibaOS welcome ─────────────────────────────────────────────
cat > /home/liveuser/.config/autostart/kiba-welcome.desktop << 'WDESK'
[Desktop Entry]
Type=Application
Name=KibaOS Welcome
Exec=/usr/local/bin/kiba-welcome
X-GNOME-Autostart-enabled=true
WDESK

# ── Fix ownership ──────────────────────────────────────────────────────────
chown -R 1000:1000 /home/liveuser

# ── SDDM user + service ────────────────────────────────────────────────────
systemctl enable sddm.service
useradd -r -s /usr/bin/nologin -d /var/lib/sddm -M sddm 2>/dev/null || true
mkdir -p /var/lib/sddm
chown sddm:sddm /var/lib/sddm

# ── Plymouth: KibaOS branded spinner ──────────────────────────────────────
THEME_SRC="/usr/share/plymouth/themes/spinner"
THEME_DST="/usr/share/plymouth/themes/kibaos"
mkdir -p "${THEME_DST}"
cp -a "${THEME_SRC}/." "${THEME_DST}/"
mv "${THEME_DST}/spinner.plymouth" "${THEME_DST}/kibaos.plymouth" 2>/dev/null || true
sed -i \
  -e 's/^Name=.*/Name=kibaos/' \
  -e 's/^Description=.*/Description=KibaOS Boot Splash/' \
  -e 's/spinner\.plymouth/kibaos.plymouth/g' \
  -e 's/^ModuleName=.*/ModuleName=spinner/' \
  "${THEME_DST}/kibaos.plymouth"

# Solid dark background — clean boot screen, no wallpaper bleed
magick -size 1920x1080 xc:"#0d1b2a" "${THEME_DST}/background-tile.png"

# Logo as watermark (centered by spinner plugin)
if [ -f "${LOGO_RAW}" ]; then
  magick "${LOGO_RAW}" -filter Lanczos -resize 200x200 \
    "${THEME_DST}/watermark.png"
fi

plymouth-set-default-theme -R kibaos 2>/dev/null || \
  plymouth-set-default-theme kibaos 2>/dev/null || true

systemctl enable plymouth-start.service      2>/dev/null || true
systemctl enable plymouth-read-write.service 2>/dev/null || true
systemctl enable plymouth-quit-wait.service  2>/dev/null || true

# ── Strip kernel module debug info only ───────────────────────────────────
find /usr/lib/modules -type f -name '*.ko' \
  -exec strip --strip-debug {} \; 2>/dev/null || true

# ── Aggressive size reduction ─────────────────────────────────────────────
rm -rf /var/cache/pacman/pkg/*
rm -rf /usr/share/man/* /usr/share/info/* /usr/share/doc/*

find /usr/share/locale -mindepth 1 -maxdepth 1 \
  ! -name 'en_US' ! -name 'en_GB' ! -name 'locale.alias' \
  -exec rm -rf {} + 2>/dev/null || true
find /usr/share/i18n/locales -mindepth 1 -maxdepth 1 \
  ! -name 'en_US' ! -name 'en_GB' ! -name 'POSIX' \
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

# ── Final ownership pass ──────────────────────────────────────────────────
chown -R 1000:1000 /home/liveuser
CUSTOMIZE
chmod +x "${AIROOTFS}/root/customize_airootfs.sh"

# ── Build the ISO ──────────────────────────────────────────────────────────
cd "${WORKDIR}"
rm -rf "${WORKDIR}/work"
mkarchiso -v -w work -o out "${PROFILE}/"

if ls out/*.iso 1>/dev/null 2>&1; then
  mv out/*.iso "${ISO}.iso"
  sha256sum "${ISO}.iso" > "${ISO}.iso.sha256"
  echo "=== Build complete: ${ISO}.iso ==="
else
  echo "ERROR: ISO file not found after mkarchiso!"
  exit 1
fi
