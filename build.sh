#!/bin/bash
# KibaOS ISO build script
# DE: Deepin Desktop Environment (deepin + deepin-kwin + deepin-extra)
# Greeter: SDDM with autologin for liveuser
# Auth: liveuser password "live", SDDM autologin config
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

echo "=== DDE will be installed from Arch repos via packages.x86_64 ==="

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
noto-fonts-emoji
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
deepin
deepin-kwin
deepin-extra
sddm
qt5-declarative
qt5-quickcontrols2
openssl
plymouth
imagemagick
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

# ── SDDM config: autologin + KibaOS theme ─────────────────────────────────
mkdir -p "${AIROOTFS}/etc/sddm.conf.d"

cat > "${AIROOTFS}/etc/sddm.conf.d/kibaos.conf" << 'SDDMCONF'
[Autologin]
User=liveuser
Session=deepin
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
    color: "#0d0d0d"

    Image {
        anchors.fill: parent
        source: "background.png"
        fillMode: Image.PreserveAspectCrop
        smooth: true
        opacity: 0.35
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 24

        Image {
            Layout.alignment: Qt.AlignHCenter
            source: "logo.png"
            width: 96; height: 96
            fillMode: Image.PreserveAspectFit
            smooth: true
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "KibaOS"
            color: "#ffffff"
            font.pixelSize: 32
            font.weight: Font.Light
            font.family: "Noto Sans"
        }

        Text {
            id: clock
            Layout.alignment: Qt.AlignHCenter
            color: "#aaaaaa"
            font.pixelSize: 14
            font.family: "Noto Sans"
            Timer {
                interval: 1000; running: true; repeat: true
                onTriggered: clock.text = Qt.formatDateTime(new Date(), "hh:mm  —  dddd, MMMM d")
            }
            Component.onCompleted: clock.text = Qt.formatDateTime(new Date(), "hh:mm  —  dddd, MMMM d")
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: "#333333"; opacity: 0.8 }

        TextField {
            id: userField
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 280
            placeholderText: "Username"
            text: sddm.lastUser
            color: "#ffffff"
            placeholderTextColor: "#888888"
            font.pixelSize: 13
            background: Rectangle {
                color: "#1e1e1e"; radius: 6
                border.color: userField.activeFocus ? "#1a7fd4" : "#333333"
                border.width: userField.activeFocus ? 2 : 1
            }
            padding: 10
            Keys.onReturnPressed: passwordField.forceActiveFocus()
        }

        TextField {
            id: passwordField
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 280
            placeholderText: "Password"
            echoMode: TextInput.Password
            color: "#ffffff"
            placeholderTextColor: "#888888"
            font.pixelSize: 13
            background: Rectangle {
                color: "#1e1e1e"; radius: 6
                border.color: passwordField.activeFocus ? "#1a7fd4" : "#333333"
                border.width: passwordField.activeFocus ? 2 : 1
            }
            padding: 10
            Keys.onReturnPressed: sddm.login(userField.text, passwordField.text, sessionModel.index(sessionBox.currentIndex, 0))
        }

        ComboBox {
            id: sessionBox
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 280
            model: sessionModel
            textRole: "name"
            currentIndex: sessionModel.lastIndex
            font.pixelSize: 12
            background: Rectangle { color: "#1e1e1e"; radius: 6; border.color: "#333333" }
            contentItem: Text {
                leftPadding: 10
                text: sessionBox.displayText
                color: "#aaaaaa"
                font: sessionBox.font
                verticalAlignment: Text.AlignVCenter
            }
        }

        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            width: 280; height: 40
            color: loginMouse.containsMouse ? "#166bbf" : "#1a7fd4"
            radius: 6
            Behavior on color { ColorAnimation { duration: 120 } }
            Text {
                anchors.centerIn: parent
                text: "Sign In"
                color: "#ffffff"
                font.pixelSize: 13
                font.weight: Font.Medium
            }
            MouseArea {
                id: loginMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: sddm.login(userField.text, passwordField.text, sessionModel.index(sessionBox.currentIndex, 0))
            }
        }

        Text {
            id: errorMsg
            Layout.alignment: Qt.AlignHCenter
            color: "#ff6b6b"
            font.pixelSize: 12
            visible: text !== ""
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 32
            Text {
                text: "⏻  Shut Down"
                color: "#666666"; font.pixelSize: 12
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: sddm.powerOff() }
            }
            Text {
                text: "↺  Restart"
                color: "#666666"; font.pixelSize: 12
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: sddm.reboot() }
            }
        }
    }

    Connections {
        target: sddm
        function onLoginFailed() { errorMsg.text = "Incorrect username or password."; passwordField.clear() }
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
  sidebarText:          "#1a1a1a"
  sidebarTextSelect:    "#1a7fd4"
  sidebarTextHighlight: "#1a7fd4"

windowExpanding:  fullscreen
windowSize:       "1024px,768px"
windowPlacement:  center

sidebar:    none
navigation: none
BRANDING

cat > "${AIROOTFS}/usr/share/calamares/branding/kibaos/stylesheet.qss" << 'QSS'
/* ── KibaOS Installer Theme ──────────────────────────────────────────────
   Clean, friendly, light UI. No external font dependencies — falls back
   gracefully to whatever sans-serif the system provides.               */

QWidget {
    background-color: #f5f5f5;
    color: #1c1c1c;
    font-family: "Noto Sans", "DejaVu Sans", sans-serif;
    font-size: 13px;
}

/* Main content area: white card feel */
QStackedWidget,
QFrame#mainContent {
    background-color: #ffffff;
    border-radius: 8px;
}

/* Page title — large, welcoming, not corporate */
QLabel#labelTitle,
QLabel[objectName="labelTitle"] {
    font-size: 26px;
    font-weight: 400;
    color: #1c1c1c;
    padding-top: 28px;
    padding-bottom: 6px;
}

/* Subtitle / body labels */
QLabel {
    color: #3a3a3a;
    font-size: 13px;
    line-height: 1.5;
}

/* ── Buttons ─────────────────────────────────────────────────────────── */

/* Primary action (Next / Install) */
QPushButton#nextButton,
QPushButton[objectName="nextButton"] {
    background-color: #1a7fd4;
    color: #ffffff;
    border: none;
    border-radius: 6px;
    padding: 10px 36px;
    font-size: 13px;
    font-weight: 600;
    min-width: 120px;
}
QPushButton#nextButton:hover   { background-color: #166bbf; }
QPushButton#nextButton:pressed { background-color: #1259a0; }
QPushButton#nextButton:disabled {
    background-color: #c8dff5;
    color: #ffffff;
}

/* Secondary buttons (Back, Cancel, etc.) */
QPushButton {
    background-color: #ffffff;
    color: #1a7fd4;
    border: 1px solid #c8c8c8;
    border-radius: 6px;
    padding: 9px 24px;
    font-size: 13px;
    min-width: 90px;
}
QPushButton:hover {
    background-color: #eaf3fc;
    border-color: #1a7fd4;
    color: #1259a0;
}
QPushButton:pressed {
    background-color: #d6eaf8;
}
QPushButton:disabled {
    color: #b0b0b0;
    border-color: #e0e0e0;
    background-color: #f5f5f5;
}

/* ── Inputs ──────────────────────────────────────────────────────────── */
QLineEdit,
QComboBox {
    background-color: #ffffff;
    border: 1.5px solid #c8c8c8;
    border-radius: 6px;
    padding: 8px 12px;
    color: #1c1c1c;
    selection-background-color: #1a7fd4;
    selection-color: #ffffff;
    font-size: 13px;
}
QLineEdit:focus,
QComboBox:focus {
    border: 2px solid #1a7fd4;
    background-color: #fafcff;
}
QLineEdit:hover,
QComboBox:hover {
    border-color: #999999;
}

QComboBox::drop-down {
    border: none;
    width: 24px;
}
QComboBox::down-arrow {
    width: 10px;
    height: 10px;
}
QComboBox QAbstractItemView {
    background-color: #ffffff;
    border: 1px solid #d0d0d0;
    border-radius: 4px;
    selection-background-color: #eaf3fc;
    selection-color: #1c1c1c;
    padding: 4px;
}

/* ── Progress bar ────────────────────────────────────────────────────── */
QProgressBar {
    background-color: #e4e4e4;
    border: none;
    border-radius: 3px;
    height: 5px;
    color: transparent;
    text-align: center;
}
QProgressBar::chunk {
    background-color: #1a7fd4;
    border-radius: 3px;
}

/* ── Lists and trees (partition view, locale picker, etc.) ───────────── */
QListView,
QTreeView {
    background-color: #ffffff;
    border: 1.5px solid #e0e0e0;
    border-radius: 6px;
    alternate-background-color: #f8f8f8;
    outline: none;
    font-size: 13px;
}
QListView::item,
QTreeView::item {
    padding: 5px 8px;
    border-radius: 4px;
}
QListView::item:hover,
QTreeView::item:hover {
    background-color: #eaf3fc;
}
QListView::item:selected,
QTreeView::item:selected {
    background-color: #cce1f7;
    color: #1c1c1c;
}

/* ── Checkboxes and radio buttons ────────────────────────────────────── */
QCheckBox,
QRadioButton {
    spacing: 8px;
    font-size: 13px;
    color: #1c1c1c;
}
QCheckBox::indicator,
QRadioButton::indicator {
    width: 18px;
    height: 18px;
    border-radius: 4px;
    border: 1.5px solid #b0b0b0;
    background-color: #ffffff;
}
QCheckBox::indicator:hover,
QRadioButton::indicator:hover {
    border-color: #1a7fd4;
}
QCheckBox::indicator:checked {
    background-color: #1a7fd4;
    border-color: #1a7fd4;
    border-radius: 4px;
}
QRadioButton::indicator {
    border-radius: 9px;
}
QRadioButton::indicator:checked {
    background-color: #1a7fd4;
    border-color: #1a7fd4;
}

/* ── Group boxes (used on users, keyboard pages) ─────────────────────── */
QGroupBox {
    border: 1.5px solid #e0e0e0;
    border-radius: 8px;
    margin-top: 18px;
    padding: 14px 12px 10px 12px;
    font-weight: 600;
    color: #1c1c1c;
}
QGroupBox::title {
    subcontrol-origin: margin;
    subcontrol-position: top left;
    left: 12px;
    padding: 0 6px;
    color: #555555;
    font-size: 11px;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.5px;
}

/* ── Scrollbars — thin and unobtrusive ───────────────────────────────── */
QScrollBar:vertical {
    background: transparent;
    width: 7px;
    margin: 0;
}
QScrollBar::handle:vertical {
    background: #d0d0d0;
    border-radius: 3px;
    min-height: 28px;
}
QScrollBar::handle:vertical:hover { background: #aaaaaa; }
QScrollBar::add-line:vertical,
QScrollBar::sub-line:vertical { height: 0; }

QScrollBar:horizontal {
    background: transparent;
    height: 7px;
}
QScrollBar::handle:horizontal {
    background: #d0d0d0;
    border-radius: 3px;
    min-width: 28px;
}
QScrollBar::handle:horizontal:hover { background: #aaaaaa; }
QScrollBar::add-line:horizontal,
QScrollBar::sub-line:horizontal { width: 0; }

/* ── Tooltip ─────────────────────────────────────────────────────────── */
QToolTip {
    background-color: #1c1c1c;
    color: #f5f5f5;
    border: none;
    border-radius: 4px;
    padding: 5px 8px;
    font-size: 12px;
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

    // ── Slide data ─────────────────────────────────────────────────────
    property var slides: [
        {
            icon:    "🐺",
            heading: "Welcome to KibaOS",
            body:    "We're setting everything up for you. This usually takes around 5–10 minutes depending on your hardware."
        },
        {
            icon:    "⚡",
            heading: "Fast by default",
            body:    "KibaOS is built on Arch Linux, so you always get the latest software — fresh from upstream."
        },
        {
            icon:    "🎨",
            heading: "Made to look great",
            body:    "The Deepin desktop is polished, smooth, and easy to navigate right out of the box."
        },
        {
            icon:    "🔒",
            heading: "Your system, your rules",
            body:    "Full disk encryption, a powerful package manager, and the entire AUR are at your fingertips."
        },
        {
            icon:    "💡",
            heading: "Need help?",
            body:    "Visit github.com/WolfTech-Innovations/Kiba for guides, the wiki, and to report issues."
        }
    ]

    property int currentSlide: 0

    // Auto-advance slides every 6 seconds once the installer is active
    Timer {
        interval: 6000
        running: root.activatedInCalamares
        repeat: true
        onTriggered: root.currentSlide = (root.currentSlide + 1) % root.slides.length
    }

    // ── Background ─────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: "#f5f5f5"

        // ── Top logo strip ─────────────────────────────────────────────
        Rectangle {
            id: topStrip
            anchors { top: parent.top; left: parent.left; right: parent.right }
            height: parent.height * 0.38
            color: "#1a7fd4"

            // Subtle radial glow behind the logo
            Rectangle {
                anchors.centerIn: parent
                width: 180; height: 180
                radius: 90
                color: "#ffffff"
                opacity: 0.08
            }

            Image {
                id: logo
                anchors.centerIn: parent
                source: "logo.png"
                width: 96; height: 96
                fillMode: Image.PreserveAspectFit
                smooth: true

                // Gentle entrance scale on first load
                NumberAnimation on scale {
                    from: 0.8; to: 1.0; duration: 600
                    easing.type: Easing.OutBack
                    running: true
                }
            }
        }

        // ── Slide content card ─────────────────────────────────────────
        Rectangle {
            id: card
            anchors {
                top: topStrip.bottom
                topMargin: -16        // overlap the strip for a layered look
                horizontalCenter: parent.horizontalCenter
            }
            width: Math.min(parent.width - 64, 520)
            height: contentCol.implicitHeight + 48
            radius: 12
            color: "#ffffff"
            layer.enabled: true
            layer.effect: null       // no QtGraphicalEffects dependency

            ColumnLayout {
                id: contentCol
                anchors { top: parent.top; left: parent.left; right: parent.right; margins: 32 }
                spacing: 12

                // Emoji icon
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.slides[root.currentSlide].icon
                    font.pixelSize: 36
                    Behavior on text { }
                }

                // Slide heading
                Text {
                    id: slideHeading
                    Layout.alignment: Qt.AlignHCenter
                    Layout.fillWidth: true
                    text: root.slides[root.currentSlide].heading
                    font.pixelSize: 20
                    font.weight: Font.Medium
                    color: "#1c1c1c"
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap

                    Behavior on text {
                        SequentialAnimation {
                            NumberAnimation { target: slideHeading; property: "opacity"; to: 0; duration: 180 }
                            PropertyAction  { }
                            NumberAnimation { target: slideHeading; property: "opacity"; to: 1; duration: 220 }
                        }
                    }
                }

                // Slide body
                Text {
                    id: slideBody
                    Layout.alignment: Qt.AlignHCenter
                    Layout.fillWidth: true
                    text: root.slides[root.currentSlide].body
                    font.pixelSize: 13
                    color: "#555555"
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    lineHeight: 1.5

                    Behavior on text {
                        SequentialAnimation {
                            NumberAnimation { target: slideBody; property: "opacity"; to: 0; duration: 180 }
                            PropertyAction  { }
                            NumberAnimation { target: slideBody; property: "opacity"; to: 1; duration: 220 }
                        }
                    }
                }

                // Dot pagination
                Row {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 8
                    Repeater {
                        model: root.slides.length
                        delegate: Rectangle {
                            width:  index === root.currentSlide ? 18 : 7
                            height: 7
                            radius: 3.5
                            color:  index === root.currentSlide ? "#1a7fd4" : "#d0d0d0"
                            Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }
                            Behavior on color { ColorAnimation { duration: 200 } }

                            // Tap to jump to slide
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.currentSlide = index
                            }
                        }
                    }
                }
            }
        }

        // ── Status label (mirrors Calamares job name if available) ─────
        Text {
            id: statusLabel
            anchors {
                horizontalCenter: parent.horizontalCenter
                bottom: progressTrack.top
                bottomMargin: 10
            }
            text: "Installing KibaOS…"
            font.pixelSize: 12
            color: "#888888"
        }

        // ── Animated progress bar ──────────────────────────────────────
        Rectangle {
            id: progressTrack
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: 5
            color: "#e0e0e0"

            Rectangle {
                id: progressFill
                anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                width: 0
                color: "#1a7fd4"
                radius: 2.5

                SequentialAnimation on width {
                    running: root.activatedInCalamares
                    loops: Animation.Infinite
                    NumberAnimation {
                        from: 0; to: progressTrack.width * 0.85
                        duration: 2800; easing.type: Easing.InOutCubic
                    }
                    PauseAnimation { duration: 500 }
                    NumberAnimation {
                        to: progressTrack.width
                        duration: 600; easing.type: Easing.OutCubic
                    }
                    PauseAnimation { duration: 300 }
                    NumberAnimation {
                        to: 0; duration: 500; easing.type: Easing.InCubic
                    }
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

          mkdir -p "${NEW_HOME}/.config/dconf"
          cp -a "${LIVE_HOME}/.config/dconf/user" \
                "${NEW_HOME}/.config/dconf/user" 2>/dev/null || true

          for f in org.deepin.dde.appearance org.deepin.dde.wallpaper \
                   deepin-metacity deepin-wm-switcher; do
              src="${LIVE_HOME}/.config/${f}"
              [ -f "$src" ] && cp "$src" "${NEW_HOME}/.config/${f}"
          done

          [ -f "${LIVE_HOME}/.config/kdeglobals" ] && \
              cp "${LIVE_HOME}/.config/kdeglobals" "${NEW_HOME}/.config/kdeglobals"

          for d in .config/gtk-3.0 .config/gtk-4.0 .gtkrc-2.0; do
              src="${LIVE_HOME}/${d}"
              dst="${NEW_HOME}/${d}"
              [ -e "$src" ] || continue
              mkdir -p "$(dirname "$dst")"
              cp -a "$src" "$dst"
          done

          [ -d "${LIVE_HOME}/.config/fontconfig" ] && \
              cp -a "${LIVE_HOME}/.config/fontconfig" \
                    "${NEW_HOME}/.config/fontconfig"

          chown -R "${NEW_USER}:${NEW_USER}" "${NEW_HOME}/.config" 2>/dev/null || true
          echo "=== Settings migrated to ${NEW_HOME} ==="
SHELLPROC

cat > "${AIROOTFS}/etc/calamares/modules/displaymanager.conf" << 'DMCONF'
---
displaymanagers:
  - sddm
defaultDesktopEnvironment:
  executable: "startdde"
  desktopFile: "deepin"
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

grep -q '^liveuser:' "${AIROOTFS}/etc/passwd" 2>/dev/null || \
  echo 'liveuser:x:1000:1000:KibaOS Live User:/home/liveuser:/usr/bin/zsh' \
  >> "${AIROOTFS}/etc/passwd"

grep -q '^liveuser:' "${AIROOTFS}/etc/group" 2>/dev/null || \
  echo 'liveuser:x:1000:liveuser' >> "${AIROOTFS}/etc/group"

grep -q '^liveuser:' "${AIROOTFS}/etc/shadow" 2>/dev/null || \
  echo "liveuser:${LIVE_HASH}:19000:0:99999:7:::" >> "${AIROOTFS}/etc/shadow"

mkdir -p "${AIROOTFS}/home/liveuser"
mkdir -p "${AIROOTFS}/etc/sudoers.d"
echo 'liveuser ALL=(ALL) NOPASSWD: ALL' > "${AIROOTFS}/etc/sudoers.d/liveuser"
chmod 0440 "${AIROOTFS}/etc/sudoers.d/liveuser"

# ── systemd system service symlinks ────────────────────────────────────────
WANTS="${AIROOTFS}/etc/systemd/system"
mkdir -p "${WANTS}/default.target.wants" "${WANTS}/multi-user.target.wants"

ln -sf /usr/lib/systemd/system/graphical.target "${WANTS}/default.target"
ln -sf /usr/lib/systemd/system/sddm.service     "${WANTS}/display-manager.service"
ln -sf /usr/lib/systemd/system/NetworkManager.service \
       "${WANTS}/multi-user.target.wants/NetworkManager.service"
ln -sf /usr/lib/systemd/system/NetworkManager-dispatcher.service \
       "${WANTS}/dbus-org.freedesktop.nm-dispatcher.service"
ln -sf /usr/lib/systemd/system/bluetooth.service \
       "${WANTS}/multi-user.target.wants/bluetooth.service"
ln -sf /usr/lib/systemd/system/pacman-init.service \
       "${WANTS}/multi-user.target.wants/pacman-init.service"

# ── customize_airootfs.sh ─────────────────────────────────────────────────
mkdir -p "${AIROOTFS}/root"
cat > "${AIROOTFS}/root/customize_airootfs.sh" << 'CUSTOMIZE'
#!/usr/bin/env bash
set -e

# ── Locale ────────────────────────────────────────────────────────────────
sed -i 's/#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
locale-gen
echo 'LANG=en_US.UTF-8' > /etc/locale.conf

# ── Hostname ──────────────────────────────────────────────────────────────
echo 'kibaos' > /etc/hostname
cat > /etc/hosts << 'HOSTS'
127.0.0.1   localhost
::1         localhost
127.0.1.1   kibaos.localdomain kibaos
HOSTS

# ── Required groups ───────────────────────────────────────────────────────
for g in users wheel audio video input network storage; do
  groupadd -r "$g" 2>/dev/null || true
done

# ── liveuser group membership ─────────────────────────────────────────────
for g in users wheel audio video input network storage; do
  usermod -aG "$g" liveuser 2>/dev/null || true
done

# ── Set liveuser password to "live" ──────────────────────────────────────
echo "liveuser:live" | chpasswd

# ── systemd tunables ──────────────────────────────────────────────────────
sed -i 's/#Storage=auto/Storage=volatile/'                    /etc/systemd/journald.conf
sed -i 's/#HandleLidSwitch=suspend/HandleLidSwitch=ignore/'   /etc/systemd/logind.conf
sed -i 's/#HandleSuspendKey=suspend/HandleSuspendKey=ignore/' /etc/systemd/logind.conf

# ── Root shell ────────────────────────────────────────────────────────────
# zsh must be in /etc/shells before chsh will accept it
grep -qx '/usr/bin/zsh' /etc/shells || echo '/usr/bin/zsh' >> /etc/shells
chsh -s /usr/bin/zsh root

# ── liveuser home ─────────────────────────────────────────────────────────
cp -aT /etc/skel/ /home/liveuser/ 2>/dev/null || true

cat > /home/liveuser/.xsession << 'DOTXSESSION'
#!/bin/bash
exec /usr/local/bin/kiba-session
DOTXSESSION
chmod +x /home/liveuser/.xsession

chown -R 1000:1000 /home/liveuser
chmod 750 /home/liveuser

mkdir -p /etc/dconf/profile
cat > /etc/dconf/profile/user << 'DCONFPROFILE'
user-db:user
system-db:kibaos-defaults
DCONFPROFILE

mkdir -p /etc/dconf/db/kibaos-defaults.d
cat > /etc/dconf/db/kibaos-defaults.d/01-kibaos << 'DCONFKEYS'
[org/cutefish/theme]
colorScheme='dark'

[org/gnome/desktop/interface]
color-scheme='prefer-dark'
gtk-theme='Adwaita-dark'
enable-animations=true
text-scaling-factor=1.0

[org/gnome/desktop/a11y/interface]
high-contrast=false

[com/deepin/dde/appearance]
DCONFKEYS
dconf update

mkdir -p /home/liveuser/.config

cat > /home/liveuser/.config/cutefishtheme.conf << 'CFTHEME'
[Theme]
colorScheme=dark
CFTHEME

cat > /home/liveuser/.config/cutefish-statusbar.conf << 'SBCONF'
[Plugins]
enabled=network,volume,battery,datetime,accessibility-kiba
[accessibility-kiba]
type=launcher
icon=preferences-desktop-accessibility
tooltip=Accessibility
command=kiba-access
SBCONF

# ── kiba-apply user service ───────────────────────────────────────────────
mkdir -p /home/liveuser/.config/systemd/user/graphical-session.target.wants
ln -sf /usr/lib/systemd/user/kiba-apply.service \
       /home/liveuser/.config/systemd/user/graphical-session.target.wants/kiba-apply.service

# ── Flathub remote ────────────────────────────────────────────────────────
flatpak remote-add --system --if-not-exists flathub \
  https://dl.flathub.org/repo/flathub.flatpakrepo 2>/dev/null || true

# ── Autostart entries ─────────────────────────────────────────────────────
mkdir -p /home/liveuser/.config/autostart
cat > /home/liveuser/.config/autostart/kiba-welcome.desktop << 'DESK'
[Desktop Entry]
Type=Application
Name=KibaOS Welcome
Exec=/usr/local/bin/kiba-welcome
X-GNOME-Autostart-enabled=true
DESK

# ── Strip stray KDE/Plasma session files ──────────────────────────────────
for f in \
  /usr/share/xsessions/plasma.desktop \
  /usr/share/xsessions/plasmawayland.desktop \
  /usr/share/xsessions/kde-plasma.desktop \
  /usr/share/wayland-sessions/plasma.desktop \
  /usr/share/wayland-sessions/plasmawayland.desktop; do
    rm -f "$f"
done
find /etc/xdg/autostart   -name 'plasma*' -o -name 'kde*' -delete 2>/dev/null || true
find /usr/share/autostart -name 'plasma*' -o -name 'kde*' -delete 2>/dev/null || true

# ── xsession desktop file ─────────────────────────────────────────────────
mkdir -p /usr/share/xsessions
cat > /usr/share/xsessions/cutefish-xsession.desktop << 'SESSION'
[Desktop Entry]
Name=KibaOS (Cutefish)
Comment=KibaOS Desktop Environment
Exec=/usr/local/bin/kiba-session
TryExec=/usr/local/bin/kiba-session
Type=XSession
DesktopNames=Cutefish
SESSION
chmod 644 /usr/share/xsessions/cutefish-xsession.desktop

# ── SDDM: ensure service is enabled and system user exists ────────────────
systemctl enable sddm.service
useradd -r -s /usr/bin/nologin -d /var/lib/sddm -M sddm 2>/dev/null || true
mkdir -p /var/lib/sddm
chown sddm:sddm /var/lib/sddm

# ── Plymouth: KibaOS branded spinner theme ───────────────────────────────
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

LOGO_URL="https://github.com/WolfTech-Innovations/Kiba/blob/main/branding/boot.png?raw=true"
LOGO_RAW="/tmp/kibaos_boot_raw.png"

curl -fL --retry 3 --retry-delay 2 -o "${LOGO_RAW}" "${LOGO_URL}"

# Calamares branding logo
magick "${LOGO_RAW}" -filter Lanczos -resize 256x256 \
  /usr/share/calamares/branding/kibaos/logo.png

# SDDM theme assets
magick "${LOGO_RAW}" -filter Lanczos -resize 96x96 \
  /usr/share/sddm/themes/kibaos/logo.png

# Dark gradient background for SDDM
magick -size 1920x1080 gradient:"#0d0d0d-#1a1a2e" \
  /usr/share/sddm/themes/kibaos/background.png

# Plymouth watermark + icon
magick "${LOGO_RAW}" -filter Lanczos -resize 400x \
  "${THEME_DST}/watermark.png"
magick "${LOGO_RAW}" -filter Lanczos -resize 64x64 \
  "${THEME_DST}/entry-icon.png"

rm -f "${LOGO_RAW}"

[ -f "${THEME_DST}/spinner.script" ] && \
  sed -i 's|watermark\.png|watermark.png|g' "${THEME_DST}/spinner.script"

plymouth-set-default-theme -R kibaos 2>/dev/null || \
  plymouth-set-default-theme kibaos 2>/dev/null || true

systemctl enable plymouth-start.service      2>/dev/null || true
systemctl enable plymouth-read-write.service 2>/dev/null || true
systemctl enable plymouth-quit-wait.service  2>/dev/null || true

# ── Strip debug from uncompressed kernel modules only ────────────────────
# Full ELF binary stripping (find /usr/bin /usr/lib ... strip --strip-unneeded)
# is intentionally omitted: running `file` + exec sh against live chroot
# binaries causes SIGSEGV/bus errors when strip or sh itself gets processed
# mid-execution (signal 11, exit 135). squashfs xz + bcj filter in
# profiledef.sh recovers equivalent space at pack time without the risk.
find /usr/lib/modules -type f -name '*.ko' \
  -exec strip --strip-debug {} \; 2>/dev/null || true
# .ko.zst recompression also omitted — same fragility concern in chroot.

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

# ── Fix ownership one final time ──────────────────────────────────────────
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
