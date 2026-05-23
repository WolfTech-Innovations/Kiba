#!/bin/bash
set -ex

# Force C++17 globally — ICU 78 headers require it, cutefish CMakeLists hardcodes gnu++11
export CXXFLAGS="-std=gnu++17"

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
cd /w
ISO="kibaos-v${RUN_NUM}"
STAGING="/tmp/cutefish-staging"
AIROOTFS="/w/kiba-profile/airootfs"

echo "=== Configuring archiso profile ==="
cp -r /usr/share/archiso/configs/releng/ kiba-profile
mkdir -p "${AIROOTFS}"

# ── Compile Cutefish DE ──────────────────────────────────────────────────
echo "=== Compiling Cutefish DE ==="
mkdir -p src && cd src

build_cutefish_repo() {
  local REPO=$1
  local GITHUB_NAME=${2:-$REPO}
  git clone --depth 1 "https://github.com/cutefishos/${GITHUB_NAME}.git" "${REPO}"
  cd "${REPO}"

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

  # Force C++17 in every CMakeLists.txt — cutefish repos hardcode CXX_STANDARD 11
  # which overrides -DCMAKE_CXX_STANDARD at the cmake invocation level.
  # Patch all three forms: set_property CXX_STANDARD, set(CMAKE_CXX_STANDARD), target_compile_features
  find . -name "CMakeLists.txt" | xargs -r sed -i \
    -e 's/CXX_STANDARD 11/CXX_STANDARD 17/g' \
    -e 's/CXX_STANDARD 14/CXX_STANDARD 17/g' \
    -e 's/set(CMAKE_CXX_STANDARD 11)/set(CMAKE_CXX_STANDARD 17)/g' \
    -e 's/set(CMAKE_CXX_STANDARD 14)/set(CMAKE_CXX_STANDARD 17)/g' \
    -e 's/cxx_std_11/cxx_std_17/g' \
    -e 's/cxx_std_14/cxx_std_17/g'

  # Inject icuuc icui18n into every existing target_link_libraries call that doesn't
  # already have it. Appending a new call would mix keyword/plain signatures and break
  # cmake. Instead we sed icuuc onto the end of the closing paren of each existing call.
  # Fixes cutefish-settings language.cpp -> libicuuc DSO missing error.
  if grep -q 'target_link_libraries' CMakeLists.txt && ! grep -q 'icuuc' CMakeLists.txt; then
    sed -i '/target_link_libraries/{/icuuc/!s/)$/ icuuc icui18n)/}' CMakeLists.txt
  fi

  find . -name "CMakeLists.txt" | while read f; do
    if grep -q 'qt5_create_translation(QM_FILES \${TS_FILES})' "$f" 2>/dev/null; then
      if grep -q 'src/.*\.cpp' "$f" 2>/dev/null; then
        sed -i 's|qt5_create_translation(QM_FILES \${TS_FILES})|qt5_create_translation(QM_FILES ${CMAKE_CURRENT_SOURCE_DIR}/src ${TS_FILES})|g' "$f"
      else
        sed -i 's|qt5_create_translation(QM_FILES \${TS_FILES})|qt5_create_translation(QM_FILES ${CMAKE_CURRENT_SOURCE_DIR} ${TS_FILES})|g' "$f"
      fi
    fi
  done

  if [ -f chotkeys/application.cpp ]; then
    cat >> chotkeys/application.cpp << 'CHOTKEYS_PATCH'

void Application::onReleased(QKeySequence keySeq)
{
    Q_UNUSED(keySeq)
}
CHOTKEYS_PATCH
  fi

  mkdir build && cd build
  CXXFLAGS="-std=gnu++17" \
  cmake -DCMAKE_INSTALL_PREFIX=/usr \
        -DCMAKE_PREFIX_PATH="${STAGING}/usr" \
        -DCMAKE_CXX_STANDARD=17 \
        -DCMAKE_CXX_STANDARD_REQUIRED=ON \
        -DCMAKE_CXX_FLAGS="-std=gnu++17" \
        -GNinja ..
  ninja
  DESTDIR="${STAGING}" ninja install
  DESTDIR="${AIROOTFS}" ninja install
  cd ../../..
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

cd ..  # back to /w

# ── Package list ─────────────────────────────────────────────────────────
cat > kiba-profile/packages.x86_64 << 'PACKAGES'
archlinux-keyring
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
    settings)   cutefish-settings & break ;;
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
cd /w
mkarchiso -v -w work -o out kiba-profile/

if ls out/*.iso 1>/dev/null 2>&1; then
  mv out/*.iso "${ISO}.iso"
  sha256sum "${ISO}.iso" > "${ISO}.iso.sha256"
else
  echo "ERROR: ISO file not found!"
  exit 1
fi
