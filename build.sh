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
  appmenu-gtk-module

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
for REPO in core dock launcher statusbar settings; do
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

# ── Package list ─────────────────────────────────────────────────────────
cat > "${PROFILE}/packages.x86_64" << 'PACKAGES'
archlinux-keyring
syslinux
base
linux
linux-headers
linux-firmware
mkinitcpio
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
calamares
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
plymouth
ntfs-3g
exfatprogs
cryptsetup
nextcloud-client
erofs-utils
sddm
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
libpulse
bluez
appmenu-gtk-module
systemsettings
PACKAGES

# ── Immutable root (erofs + tmpfs overlays) ───────────────────────────────
mkdir -p "${AIROOTFS}/etc"
cat > "${AIROOTFS}/etc/fstab" << 'FSTAB'
LABEL=KIBAOS_ROOT / erofs defaults,ro 0 0
tmpfs /etc tmpfs defaults,noatime,mode=755 0 0
tmpfs /var tmpfs defaults,noatime,mode=755 0 0
FSTAB

# ── SDDM autologin for live session ──────────────────────────────────────
mkdir -p "${AIROOTFS}/etc/sddm.conf.d"
cat > "${AIROOTFS}/etc/sddm.conf.d/autologin.conf" << 'SDDM'
[Autologin]
User=liveuser
Session=cutefish
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
    "settings"   "System Settings"      "Configure your desktop and hardware" \
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
    settings)   systemsettings5 & break ;;
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
