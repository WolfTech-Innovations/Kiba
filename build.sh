#!/bin/bash
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
  qt5-base qt5-declarative qt5-svg qt5-quickcontrols2 \
  qt5-graphicaleffects qt5-x11extras qt5-tools \
  qt5-quickcontrols qt5-multimedia qt5-wayland \
  \
  kwindowsystem5 kidletime5 kcoreaddons5 kconfig5 \
  ki18n5 kiconthemes5 kdbusaddons5 kservice5 \
  kio5 solid5 \
  kwin \
  \
  libxcb xcb-util xcb-util-wm xcb-util-keysyms \
  xcb-util-image xcb-util-renderutil \
  libxkbcommon xorgproto libxcursor libxtst \
  libpulse \
  xorg-server-devel xf86-input-libinput xf86-input-synaptics \
  \
  dbus pam polkit polkit-qt5 \
  gsettings-desktop-schemas networkmanager \
  bluez \
  fontconfig freetype2 icu \
  \
  appmenu-gtk-module \
  \
  kpmcore boost boost-libs yaml-cpp libpwquality \
  python python-yaml python-jsonschema \
  qt5-xmlpatterns kparts5

# ── Setup ────────────────────────────────────────────────────────────────
WORKDIR="/w"
ISO="kibaos-v${RUN_NUM}"
STAGING="/tmp/cutefish-staging"
PROFILE="${WORKDIR}/kiba-profile"
AIROOTFS="${PROFILE}/airootfs"
SRCDIR="${WORKDIR}/src"

cd "${WORKDIR}"

echo "=== Configuring archiso profile ==="
cp -r /usr/share/archiso/configs/releng/ "${PROFILE}"
mkdir -p "${AIROOTFS}"
mkdir -p "${SRCDIR}"

# ── profiledef.sh — ISO branding & metadata ───────────────────────────────
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
airootfs_image_tool_options=('-comp' 'xz' '-Xbcj' 'x86' '-b' '1M' '-Xdict-size' '1M')
file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/etc/gshadow"]="0:0:400"
  ["/usr/local/bin/kiba-welcome"]="0:0:755"
  ["/usr/share/xsessions/cutefish-xsession.desktop"]="0:0:777"
  ["/root"]="0:0:750"
)
PROFILEDEF
chmod +x "${PROFILE}/profiledef.sh"

# ── /etc/os-release — distro identity ────────────────────────────────────
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

# ── Compile Cutefish DE ──────────────────────────────────────────────────
echo "=== Compiling Cutefish DE ==="

build_cutefish_repo() {
  local REPO=$1
  local GITHUB_NAME=${2:-$REPO}

  # Always operate relative to SRCDIR so cd chains can't escape
  cd "${SRCDIR}"

  git clone --depth 1 "https://github.com/cutefishos/${GITHUB_NAME}.git" "${REPO}"
  cd "${SRCDIR}/${REPO}"

  # Drop KF5 subdirs and find_package calls for libraries that no longer
  # exist on Arch (dropped as Qt5/Plasma5 support wound down)
  sed -i '/add_subdirectory(bluetooth)/d'         CMakeLists.txt
  sed -i '/add_subdirectory(bluez)/d'             CMakeLists.txt
  sed -i '/add_subdirectory(networkmanagement)/d' CMakeLists.txt
  sed -i '/add_subdirectory(screen)/d'            CMakeLists.txt

  sed -i '/find_package(KF5BluezQt/d'          CMakeLists.txt
  sed -i '/find_package(KF5NetworkManagerQt/d' CMakeLists.txt
  sed -i '/find_package(KF5ModemManagerQt/d'   CMakeLists.txt
  sed -i '/find_package(KF5Screen/d'           CMakeLists.txt

  sed -i '/KF5::BluezQt/d'          CMakeLists.txt
  sed -i '/KF5::NetworkManagerQt/d' CMakeLists.txt
  sed -i '/KF5::ModemManagerQt/d'   CMakeLists.txt
  sed -i '/KF5::Screen/d'           CMakeLists.txt

  sed -i '/src\/vpn\/vpn\.cpp/d' CMakeLists.txt
  sed -i '/src\/vpn\/nm-.*\.h/d' CMakeLists.txt

  # ── Fix MOC/translation dependency cycle ──────────────────────────────
  # qt5_create_translation runs lupdate (scans C++ sources = needs MOC'd
  # files) AND lrelease, creating a circular dep:
  #   mocs_compilation → translations → lupdate stamp → mocs_compilation
  #
  # Fix strategy per CMakeLists.txt:
  #   • If .ts files exist → swap to qt5_add_translation (lrelease-only)
  #   • If no .ts files   → drop the translation target entirely
  while IFS= read -r f; do
    DIR=$(dirname "$f")
    TS_COUNT=$(find "$DIR" -maxdepth 2 -name "*.ts" 2>/dev/null | wc -l)

    if grep -q 'qt5_create_translation' "$f" 2>/dev/null; then
      if [ "$TS_COUNT" -gt 0 ]; then
        sed -i \
          's/qt5_create_translation(\(QM_FILES\)[^)]*\(\${[A-Z_]*TS_FILES}\))/qt5_add_translation(\1 \2)/g' \
          "$f"
        sed -i 's/qt5_create_translation(/qt5_add_translation(/g' "$f"
        sed -i \
          's/qt5_add_translation(\(QM_FILES\) \${CMAKE_CURRENT_SOURCE_DIR}[^ )]*  */qt5_add_translation(\1 /g' \
          "$f"
      else
        sed -i '/qt5_create_translation/d' "$f"
        sed -i '/qt5_add_translation/d'    "$f"
        sed -i '/QM_FILES/d'               "$f"
        sed -i '/install.*\.qm/d'          "$f"
      fi
    fi
  done < <(find . -name "CMakeLists.txt")
  # ── End translation cycle fix ──────────────────────────────────────────

  if [ -f chotkeys/application.cpp ]; then
    cat >> chotkeys/application.cpp << 'CHOTKEYS_PATCH'

void Application::onReleased(QKeySequence keySeq)
{
    Q_UNUSED(keySeq)
}
CHOTKEYS_PATCH
  fi

  mkdir build && cd build
  cmake -DCMAKE_INSTALL_PREFIX=/usr \
        -DCMAKE_PREFIX_PATH="${STAGING}/usr" \
        -GNinja ..
  ninja
  DESTDIR="${STAGING}"  ninja install
  DESTDIR="${AIROOTFS}" ninja install
  # Return to a known location — never rely on relative cd chains
  cd "${WORKDIR}"
}

# 1. libcutefish
build_cutefish_repo libcutefish libcutefish

# 2. fishui
build_cutefish_repo fishui fishui

# 3. Core components
for REPO in core dock launcher statusbar; do
  build_cutefish_repo "${REPO}" "${REPO}"
done

# 4. Apps
for REPO in terminal filemanager calculator screenshot; do
  build_cutefish_repo "${REPO}" "${REPO}"
done

# 5. Wallpapers & icons
for REPO in wallpapers icons; do
  build_cutefish_repo "${REPO}" "${REPO}"
done

# ── Back to workdir (should already be here, but be explicit) ─────────────
cd "${WORKDIR}"


# ── Compile Calamares (not in Arch repos, must build from source) ─────────
echo "=== Compiling Calamares ==="
cd "${SRCDIR}"
git clone --depth 1 https://codeberg.org/Calamares/calamares.git calamares
cd "${SRCDIR}/calamares"
mkdir build && cd build
cmake -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_INSTALL_PREFIX=/usr \
      -DWITH_PYTHONQT=OFF \
      -DWITH_PYTHON=ON \
      -DWITH_KF5DBus=ON \
      -DSKIP_MODULES="webview interactiveterminal initramfs \
                      initramfscfg dracut dracutlukscfg \
                      dummyprocess dummypython dummycpp \
                      dummypythonqt services-openrc" \
      -GNinja ..
ninja
DESTDIR="${AIROOTFS}" ninja install
cd "${WORKDIR}"

# ── Package list ─────────────────────────────────────────────────────────
cat > "${PROFILE}/packages.x86_64" << 'PACKAGES'
archlinux-keyring
syslinux
base
linux
linux-headers
linux-firmware
mkinitcpio
mkinitcpio-archiso
grub
efibootmgr
networkmanager
git
wget
curl
sudo
zsh
zsh-autosuggestions
zsh-syntax-highlighting
starship
fastfetch
eza
bat
btop
ripgrep
fd
tealdeer
duf
ncdu
micro
nano
fzf
yt-dlp

inter-font
ttf-jetbrains-mono
noto-fonts-emoji
flatpak
xdg-desktop-portal-kde
xdg-desktop-portal-gtk
chromium
vlc
gparted
spectacle
ark
ntfs-3g
exfatprogs
cryptsetup
nextcloud-client
sddm
xorg-server
xorg-xinit
xf86-video-vesa
kwin
qt5-base
qt5-declarative
qt5-svg
qt5-quickcontrols2
qt5-graphicaleffects
qt5-x11extras
qt5-quickcontrols
qt5-multimedia
kwindowsystem5
kidletime5
polkit-qt5
libxcursor
libxtst
libxcb
xcb-util
xcb-util-cursor
xcb-util-image
xcb-util-keysyms
xcb-util-renderutil
xcb-util-wm
xcb-util-xrm
libxkbcommon-x11
libpulse
bluez
appmenu-gtk-module
systemsettings
PACKAGES


# ── Fix initramfs hooks (archiso live boot requires archiso hook, no autodetect) ──
mkdir -p "${AIROOTFS}/etc/mkinitcpio.conf.d"
cat > "${AIROOTFS}/etc/mkinitcpio.conf.d/archiso.conf" << 'INITRAMFS'
HOOKS=(base udev memdisk archiso block filesystems)
INITRAMFS

# Correct preset so mkinitcpio builds the archiso image, not a standard one
mkdir -p "${AIROOTFS}/etc/mkinitcpio.d"
cat > "${AIROOTFS}/etc/mkinitcpio.d/linux.preset" << 'PRESET'
PRESETS=('archiso')
ALL_kver='/boot/vmlinuz-linux'
archiso_config='/etc/mkinitcpio.conf.d/archiso.conf'
archiso_image='/boot/initramfs-linux.img'
PRESET

# ── Rebrand boot menu (systemd-boot) ─────────────────────────────────────
# Loader config
mkdir -p "${AIROOTFS}/loader"
cat > "${PROFILE}/efiboot/loader/loader.conf" << 'LOADER'
default kibaos.conf
timeout 5
console-mode max
editor no
LOADER

# Boot entry — reuse archiso's kernel/initramfs paths, just rename the title
mkdir -p "${PROFILE}/efiboot/loader/entries"
cat > "${PROFILE}/efiboot/loader/entries/kibaos.conf" << 'ENTRY'
title   KibaOS
linux   /arch/boot/x86_64/vmlinuz-linux
initrd  /arch/boot/x86_64/initramfs-linux.img
options archisobasedir=arch archisolabel=KIBAOS cow_spacesize=1G
ENTRY

# Also patch syslinux label for BIOS boot
SYSLINUX_CFG="${PROFILE}/syslinux/syslinux.cfg"
if [ -f "${SYSLINUX_CFG}" ]; then
  sed -i 's/Arch Linux/KibaOS/g'   "${SYSLINUX_CFG}"
  sed -i 's/ARCH_[0-9]*/KIBAOS/g' "${SYSLINUX_CFG}"
fi

# ── SDDM autologin for live session ──────────────────────────────────────
mkdir -p "${AIROOTFS}/etc/sddm.conf.d"
cat > "${AIROOTFS}/etc/sddm.conf.d/autologin.conf" << 'SDDM'
[Autologin]
User=liveuser
Session=cutefish-xsession
SDDM

# ── Calamares OOBE config ─────────────────────────────────────────────────
mkdir -p "${AIROOTFS}/etc/calamares/modules"
cat > "${AIROOTFS}/etc/calamares/settings.conf" << 'CALA_SETTINGS'
---
modules-search: [ local ]
instances:
- id: fullscreen
  module: welcome
  config: welcome_fullscreen.conf
sequence:
- show:
  - welcome@fullscreen
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

# ── Welcome script ────────────────────────────────────────────────────────
mkdir -p "${AIROOTFS}/usr/local/bin"
cat > "${AIROOTFS}/usr/local/bin/kiba-welcome" << 'WELCOME'
#!/bin/bash
while true; do
  CHOICE=$(zenity --list --title="Welcome to KibaOS" \
    --window-icon="/usr/share/kibaos/logo.png" \
    --text="Welcome to KibaOS. What would you like to do?" \
    --column="Tag" --column="Action" --column="Description" \
    "install"    "Install KibaOS"      "Install the system permanently to your disk" \
    "browser"    "Web Browser"          "Browse the internet" \
    "store"      "Software Center"      "Discover and install new applications" \
    "terminal"   "Open Terminal"        "Use Meta+T to launch" \
    "files"      "File Manager"         "Use Meta+E to browse" \
    "screenshot" "Screen Capture"       "Use Print to capture" \
    "info"       "System Information"   "View technical system details" \
    "shortcuts"  "Keyboard Shortcuts"   "View useful desktop shortcuts" \
    "wiki"       "Online Wiki"          "Read the technical documentation" \
    --hide-column=1 --print-column=1 \
    --width=450 --height=500 --ok-label="Launch" --cancel-label="Close" 2>/dev/null)

  [ -z "$CHOICE" ] && break

  case "$CHOICE" in
    install)    sudo calamares & break ;;
    browser)    chromium & break ;;
    store)      flatpak run org.kde.discover & break ;;
    terminal)   cutefish-terminal & break ;;
    files)      cutefish-filemanager & break ;;
    screenshot) cutefish-screenshot & break ;;
    info)
      (fastfetch | zenity --text-info --title="KibaOS System Information") &
      ;;
    shortcuts)
      (zenity --list --title="KibaOS Shortcuts" \
        --column="Action" --column="Shortcut" \
        "Application Menu" "Meta" \
        "Terminal"         "Meta + T" \
        "Search"           "Meta + Space" \
        "File Manager"     "Meta + E" \
        --ok-label="Close" --cancel-label="Close" 2>/dev/null) &
      ;;
    wiki)
      chromium "https://github.com/WolfTech-Innovations/Kiba/blob/main/WIKI.md" & break
      ;;
  esac
done
WELCOME
chmod +x "${AIROOTFS}/usr/local/bin/kiba-welcome"

# ── liveuser account ─────────────────────────────────────────────────────
# passwd / shadow / group entries for the passwordless live user
mkdir -p "${AIROOTFS}/etc"

# Append liveuser to passwd (uid 1000, home /home/liveuser, shell zsh)
grep -q '^liveuser:' "${AIROOTFS}/etc/passwd" 2>/dev/null || \
  echo 'liveuser:x:1000:1000:KibaOS Live User:/home/liveuser:/usr/bin/zsh' \
  >> "${AIROOTFS}/etc/passwd"

grep -q '^liveuser:' "${AIROOTFS}/etc/group" 2>/dev/null || \
  echo 'liveuser:x:1000:liveuser' >> "${AIROOTFS}/etc/group"

# Empty password hash = no password required for live session
grep -q '^liveuser:' "${AIROOTFS}/etc/shadow" 2>/dev/null || \
  echo 'liveuser::19000:0:99999:7:::' >> "${AIROOTFS}/etc/shadow"

mkdir -p "${AIROOTFS}/home/liveuser"

# sudo without password for live session
mkdir -p "${AIROOTFS}/etc/sudoers.d"
echo 'liveuser ALL=(ALL) NOPASSWD: ALL' > "${AIROOTFS}/etc/sudoers.d/liveuser"

# ── systemd service symlinks (equivalent of systemctl enable) ─────────────
WANTS="${AIROOTFS}/etc/systemd/system"

# graphical.target as default
mkdir -p "${WANTS}/default.target.wants"
mkdir -p "${WANTS}"
ln -sf /usr/lib/systemd/system/graphical.target \
       "${WANTS}/default.target"

# SDDM display manager
ln -sf /usr/lib/systemd/system/sddm.service \
       "${WANTS}/display-manager.service"

# NetworkManager
mkdir -p "${WANTS}/multi-user.target.wants"
ln -sf /usr/lib/systemd/system/NetworkManager.service \
       "${WANTS}/multi-user.target.wants/NetworkManager.service"
ln -sf /usr/lib/systemd/system/NetworkManager-dispatcher.service \
       "${WANTS}/dbus-org.freedesktop.nm-dispatcher.service"

# Bluetooth
ln -sf /usr/lib/systemd/system/bluetooth.service \
       "${WANTS}/multi-user.target.wants/bluetooth.service"

# pacman keyring init (needed on live ISO)
ln -sf /usr/lib/systemd/system/pacman-init.service \
       "${WANTS}/multi-user.target.wants/pacman-init.service"

# ── customize_airootfs.sh — runs inside chroot at build time ─────────────
mkdir -p "${AIROOTFS}/root"
cat > "${AIROOTFS}/root/customize_airootfs.sh" << 'CUSTOMIZE'
#!/usr/bin/env bash
set -e

# Locale
sed -i 's/#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
locale-gen
echo 'LANG=en_US.UTF-8' > /etc/locale.conf

# Hostname
echo 'kibaos' > /etc/hostname
cat > /etc/hosts << 'HOSTS'
127.0.0.1   localhost
::1         localhost
127.0.1.1   kibaos.localdomain kibaos
HOSTS

# SDDM system user
groupadd -r sddm || true
useradd -r -g sddm -d /var/lib/sddm -s /usr/bin/nologin -c "SDDM Greeter" sddm || true
mkdir -p /var/lib/sddm
chown sddm:sddm /var/lib/sddm
chmod 700 /var/lib/sddm

# Create utmp (systemd 256+ no longer creates this, but SDDM still wants it)
touch /run/utmp
mkdir -p /var/log
touch /var/log/btmp
touch /var/log/wtmp

# Ensure basic groups exist
groupadd -r users 2>/dev/null || true
groupadd -r wheel 2>/dev/null || true
groupadd -r audio 2>/dev/null || true
groupadd -r video 2>/dev/null || true
groupadd -r input 2>/dev/null || true
groupadd -r network 2>/dev/null || true

# Volatile journal (saves RAM on live ISO)
sed -i 's/#Storage=auto/Storage=volatile/' /etc/systemd/journald.conf

# Don't suspend on lid close in live session
sed -i 's/#HandleLidSwitch=suspend/HandleLidSwitch=ignore/' /etc/systemd/logind.conf
sed -i 's/#HandleSuspendKey=suspend/HandleSuspendKey=ignore/' /etc/systemd/logind.conf

# zsh for root in live session
chsh -s /usr/bin/zsh root

# liveuser home skeleton
cp -aT /etc/skel/ /home/liveuser/ 2>/dev/null || true
chown -R 1000:1000 /home/liveuser
chmod 700 /home/liveuser

# Autostart kiba-welcome for liveuser on login
mkdir -p /home/liveuser/.config/autostart
cat > /home/liveuser/.config/autostart/kiba-welcome.desktop << 'DESK'
[Desktop Entry]
Type=Application
Name=KibaOS Welcome
Exec=/usr/local/bin/kiba-welcome
X-GNOME-Autostart-enabled=true
DESK
chown 1000:1000 /home/liveuser/.config/autostart/kiba-welcome.desktop

# Trust cutefish DE session
mkdir -p /usr/share/wayland-sessions
mkdir -p /usr/share/xsessions
cat > /usr/share/xsessions/cutefish-xsession.desktop << 'SESSION'
[Desktop Entry]
Name=Cutefish
Comment=KibaOS Desktop
Exec=cutefish-session
TryExec=cutefish-session
Type=Application
SESSION
chmod 777 /usr/share/xsessions/cutefish-xsession.desktop
CUSTOMIZE
chmod +x "${AIROOTFS}/root/customize_airootfs.sh"

# ── Build the ISO ─────────────────────────────────────────────────────────
cd "${WORKDIR}"
mkarchiso -v -w work -o out "${PROFILE}/"

if ls out/*.iso 1>/dev/null 2>&1; then
  mv out/*.iso "${ISO}.iso"
  sha256sum "${ISO}.iso" > "${ISO}.iso.sha256"
else
  echo "ERROR: ISO file not found!"
  exit 1
fi
