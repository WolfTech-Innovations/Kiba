#!/bin/bash
# KibaOS ISO build script
# Fixed: chotkeys onReleased patch now runs BEFORE cmake (was after ninja — too late),
#        header patch added alongside .cpp patch, SLiM autologin, Cutefish build patches,
#        Calamares sequence/modules, unpackfs path, package names, mkinitcpio hooks,
#        liveuser setup, kiba-apply runtime dir, shellprocess users.json path, and more.
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
  qt5-xmlpatterns kparts5 \
  \
  slim \
  \
  xorg-xrandr xorg-xdpyinfo xorg-xwd xorg-xwud \
  imagemagick \
  dconf python-dbus python-gobject

# ── Setup ─────────────────────────────────────────────────────────────────
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
airootfs_image_tool_options=('-comp' 'xz' '-Xbcj' 'x86' '-b' '1048576' '-Xdict-size' '100%' '-always-use-fragments' '-noappend')
file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/etc/gshadow"]="0:0:400"
  ["/usr/local/bin/kiba-welcome"]="0:0:755"
  ["/usr/local/bin/kiba-session"]="0:0:755"
  ["/usr/local/bin/kiba-apply"]="0:0:755"
  ["/usr/local/bin/kiba-set"]="0:0:755"
  ["/usr/local/bin/kiba-access"]="0:0:755"
  ["/usr/local/bin/kiba-freeze"]="0:0:755"
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

# ── Compile Cutefish DE ───────────────────────────────────────────────────
echo "=== Compiling Cutefish DE ==="

build_cutefish_repo() {
  local REPO=$1
  local GITHUB_NAME=${2:-$REPO}
  cd "${SRCDIR}"
  git clone --depth 1 "https://github.com/cutefishos/${GITHUB_NAME}.git" "${REPO}"
  cd "${SRCDIR}/${REPO}"

  # ── Strip optional/broken submodules ──────────────────────────────────
  # Do this before cmake so find_package failures don't abort the build.
  sed -i '/add_subdirectory(bluetooth)/d'         CMakeLists.txt 2>/dev/null || true
  sed -i '/add_subdirectory(bluez)/d'             CMakeLists.txt 2>/dev/null || true
  sed -i '/add_subdirectory(networkmanagement)/d' CMakeLists.txt 2>/dev/null || true
  sed -i '/add_subdirectory(screen)/d'            CMakeLists.txt 2>/dev/null || true
  sed -i '/find_package(KF5BluezQt/d'             CMakeLists.txt 2>/dev/null || true
  sed -i '/find_package(KF5NetworkManagerQt/d'    CMakeLists.txt 2>/dev/null || true
  sed -i '/find_package(KF5ModemManagerQt/d'      CMakeLists.txt 2>/dev/null || true
  sed -i '/find_package(KF5Screen/d'              CMakeLists.txt 2>/dev/null || true
  sed -i '/KF5::BluezQt/d'                        CMakeLists.txt 2>/dev/null || true
  sed -i '/KF5::NetworkManagerQt/d'               CMakeLists.txt 2>/dev/null || true
  sed -i '/KF5::ModemManagerQt/d'                 CMakeLists.txt 2>/dev/null || true
  sed -i '/KF5::Screen/d'                         CMakeLists.txt 2>/dev/null || true
  # VPN modules drag in NetworkManager headers we don't have
  sed -i '/src\/vpn\//d'                          CMakeLists.txt 2>/dev/null || true

  # ── Fix qt5_create_translation calls ──────────────────────────────────
  # If .ts files exist use qt5_add_translation; otherwise strip entirely.
  while IFS= read -r f; do
    DIR=$(dirname "$f")
    TS_COUNT=$(find "$DIR" -maxdepth 2 -name "*.ts" 2>/dev/null | wc -l)
    if grep -q 'qt5_create_translation' "$f" 2>/dev/null; then
      if [ "$TS_COUNT" -gt 0 ]; then
        sed -i 's/qt5_create_translation(\(QM_FILES\)[^)]*\(\${[A-Z_]*TS_FILES}\))/qt5_add_translation(\1 \2)/g' "$f"
        sed -i 's/qt5_create_translation(/qt5_add_translation(/g' "$f"
        sed -i 's/qt5_add_translation(\(QM_FILES\) \${CMAKE_CURRENT_SOURCE_DIR}[^ )]*  */qt5_add_translation(\1 /g' "$f"
      else
        sed -i '/qt5_create_translation/d' "$f"
        sed -i '/qt5_add_translation/d'    "$f"
        sed -i '/QM_FILES/d'               "$f"
        sed -i '/install.*\.qm/d'          "$f"
      fi
    fi
  done < <(find . -name "CMakeLists.txt")

  # ── Patch chotkeys onReleased — MUST happen BEFORE cmake ──────────────
  # The MOC reads application.h to generate qt_static_metacall, which emits
  # a call to Application::onReleased(QKeySequence). If the slot is declared
  # in the header but never defined in application.cpp, the linker fails.
  # We patch both the header (declaration) and the .cpp (definition) here,
  # before cmake configures the project and before ninja compiles anything.
  if [ -f chotkeys/application.h ]; then
    if ! grep -q 'onReleased' chotkeys/application.h; then
      # Insert the slot declaration under the first "public slots:" section
      sed -i '/public slots:/a\    void onReleased(QKeySequence keySeq);' \
        chotkeys/application.h
    fi
  fi
  if [ -f chotkeys/application.cpp ]; then
    if ! grep -q 'onReleased' chotkeys/application.cpp; then
      cat >> chotkeys/application.cpp << 'CHOTKEYS_PATCH'

void Application::onReleased(QKeySequence keySeq)
{
    Q_UNUSED(keySeq)
}
CHOTKEYS_PATCH
    fi
  fi

  # ── Configure and build ────────────────────────────────────────────────
  mkdir -p build && cd build
  cmake -DCMAKE_INSTALL_PREFIX=/usr \
        -DCMAKE_PREFIX_PATH="${STAGING}/usr" \
        -DCMAKE_BUILD_TYPE=Release \
        -GNinja ..
  ninja
  DESTDIR="${STAGING}"  ninja install
  DESTDIR="${AIROOTFS}" ninja install
  cd "${WORKDIR}"
}

for REPO in libcutefish fishui core dock launcher statusbar \
            terminal filemanager calculator screenshot \
            wallpapers icons; do
  build_cutefish_repo "${REPO}" "${REPO}"
done

# ── Compile Calamares ──────────────────────────────────────────────────────
echo "=== Compiling Calamares ==="
cd "${SRCDIR}"
git clone --depth 1 https://codeberg.org/Calamares/calamares.git calamares
cd "${SRCDIR}/calamares"
mkdir -p build && cd build
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
xdg-desktop-portal-kde
xdg-desktop-portal-gtk
firefox
gparted
ntfs-3g
exfatprogs
cryptsetup
slim
zenity
xorg-server
xorg-xinit
xorg-xrandr
xorg-xdpyinfo
xorg-xwd
xorg-xwud
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
squashfs-tools
imagemagick
dconf
python-dbus
python-gobject
python
python-yaml
python-jsonschema
PACKAGES

# ── initramfs ──────────────────────────────────────────────────────────────
# archiso hooks: memdisk loads the squashfs into RAM; archiso mounts it.
# 'keyboard' and 'keymap' must come before 'archiso' so the console works
# if something goes wrong. 'filesystems' last for fallback mount support.
mkdir -p "${AIROOTFS}/etc/mkinitcpio.conf.d"
cat > "${AIROOTFS}/etc/mkinitcpio.conf.d/archiso.conf" << 'INITRAMFS'
HOOKS=(base udev keyboard keymap modconf memdisk archiso block filesystems)
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
options archisobasedir=arch archisolabel=KIBAOS cow_spacesize=1G quiet splash
ENTRY

# Syslinux (BIOS boot)
SYSLINUX_CFG="${PROFILE}/syslinux/syslinux.cfg"
if [ -f "${SYSLINUX_CFG}" ]; then
  sed -i 's/Arch Linux/KibaOS/g'   "${SYSLINUX_CFG}"
  sed -i 's/ARCH_[0-9]*/KIBAOS/g' "${SYSLINUX_CFG}"
fi

# ── SLiM display manager config ────────────────────────────────────────────
# SLiM opens a real PAM session, assigns a logind seat, and sets
# XDG_RUNTIME_DIR before exec-ing login_cmd. auto_login + default_user gives
# true no-password autologin with zero PAM gymnastics.
mkdir -p "${AIROOTFS}/etc"
cat > "${AIROOTFS}/etc/slim.conf" << 'SLIMCONF'
default_path        /usr/local/bin:/usr/bin:/bin
default_xserver     /usr/bin/X
xserver_arguments   -nolisten tcp vt7
login_cmd           exec /bin/bash -login /usr/local/bin/kiba-session
halt_cmd            /sbin/halt
reboot_cmd          /sbin/reboot
console_cmd         /usr/bin/xterm -C -fg white -bg black +sb -T "Console login" -e /bin/sh -c "/bin/cat /etc/issue; exec /bin/login"
screenshot_cmd      import -window root /slim.png
welcome_msg         Welcome to KibaOS
session_msg         KibaOS
default_user        liveuser
auto_login          yes
current_theme       default
lockfile            /var/run/slim.lock
logfile             /var/log/slim.log
SLIMCONF

# ── kiba-session — the X session script, exec'd by SLiM ───────────────────
# SLiM has already:
#   - opened a PAM session for liveuser
#   - set XDG_RUNTIME_DIR=/run/user/1000
#   - assigned the logind seat
# We just need to start dbus, kwin, and cutefish.
mkdir -p "${AIROOTFS}/usr/local/bin"
cat > "${AIROOTFS}/usr/local/bin/kiba-session" << 'KIBASESSION'
#!/bin/bash
# kiba-session — KibaOS X session, launched by SLiM after PAM login.

export XDG_CURRENT_DESKTOP=Cutefish
export DESKTOP_SESSION=cutefish
export XDG_SESSION_DESKTOP=cutefish
export XDG_SESSION_TYPE=x11

# Unset KDE session vars — kwin is present as a dep but we don't want
# anything assuming this is a Plasma session.
unset KDE_FULL_SESSION
unset KDE_SESSION_VERSION

# Source user profile (PATH, locale, etc.)
[ -f /etc/profile ]       && source /etc/profile
[ -f "${HOME}/.profile" ] && source "${HOME}/.profile" 2>/dev/null || true

# D-Bus session bus — SLiM doesn't start one for us.
# --exit-with-session ensures the bus dies when the session ends.
if [ -z "${DBUS_SESSION_BUS_ADDRESS}" ]; then
  eval "$(dbus-launch --sh-syntax --exit-with-session)"
fi

# kwin compositor — must start before cutefish-session or the desktop
# renders with a black/broken compositor. Give it a moment to settle.
kwin_x11 --replace &
sleep 0.8

# kiba-apply settings daemon (unix socket at /run/user/<uid>/kiba-apply.sock)
/usr/local/bin/kiba-apply &

# Hand off to cutefish. When this process exits SLiM sees the session end.
exec cutefish-session
KIBASESSION
chmod +x "${AIROOTFS}/usr/local/bin/kiba-session"

# ── Calamares config ───────────────────────────────────────────────────────
mkdir -p "${AIROOTFS}/etc/calamares/modules"

# settings.conf — module sequence.
# Notes:
#   - 'localecfg' writes /etc/locale.conf; 'locale' in exec sets the timezone.
#   - 'networkcfg' copies the live NetworkManager state to the installed system.
#   - 'shellprocess@copy-user-settings' migrates liveuser dotfiles.
#   - 'bootloader' must come after 'fstab' and after 'mount'.
#   - 'umount' must be last in exec.
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

# unpackfs.conf
# The squashfs path in archiso releng lives under:
# /run/archiso/bootmnt/arch/x86_64/airootfs.sfs
cat > "${AIROOTFS}/etc/calamares/modules/unpackfs.conf" << 'UNPACKFS'
---
unpack:
  - source: "/run/archiso/bootmnt/arch/x86_64/airootfs.sfs"
    sourcefs: "squashfs"
    destination: ""
UNPACKFS

# shellprocess: migrate liveuser settings to the newly created account.
# Calamares runtime state is in global_storage.json (not users.json).
cat > "${AIROOTFS}/etc/calamares/modules/shellprocess@copy-user-settings.conf" << 'SHELLPROC'
---
dontChroot: false
timeout: 120
script:
  - "-": "echo '=== KibaOS: migrating live session settings to new user ==='"
  - "-": |
          NEW_USER=$(python3 -c "
          import json, sys
          # Calamares runtime state is in global_storage.json
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
          # Fallback: first non-system user in passwd
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

          # dconf binary database (theme, colour, accessibility state)
          mkdir -p "${NEW_HOME}/.config/dconf"
          cp -a "${LIVE_HOME}/.config/dconf/user" \
                "${NEW_HOME}/.config/dconf/user" 2>/dev/null || true

          # Cutefish native config files
          for f in cutefishtheme.conf cutefish-wallpaper.conf \
                   cutefish-appearance.conf cutefish-dock.conf \
                   cutefish-statusbar.conf; do
              src="${LIVE_HOME}/.config/${f}"
              [ -f "$src" ] && cp "$src" "${NEW_HOME}/.config/${f}"
          done

          # Qt / KDE globals
          [ -f "${LIVE_HOME}/.config/kdeglobals" ] && \
              cp "${LIVE_HOME}/.config/kdeglobals" "${NEW_HOME}/.config/kdeglobals"

          # GTK theming
          for d in .config/gtk-3.0 .config/gtk-4.0 .gtkrc-2.0; do
              src="${LIVE_HOME}/${d}"
              dst="${NEW_HOME}/${d}"
              [ -e "$src" ] || continue
              mkdir -p "$(dirname "$dst")"
              cp -a "$src" "$dst"
          done

          # Fontconfig / accessibility overrides
          [ -d "${LIVE_HOME}/.config/fontconfig" ] && \
              cp -a "${LIVE_HOME}/.config/fontconfig" \
                    "${NEW_HOME}/.config/fontconfig"

          chown -R "${NEW_USER}:${NEW_USER}" "${NEW_HOME}/.config" 2>/dev/null || true
          echo "=== Settings migrated to ${NEW_HOME} ==="
SHELLPROC

# displaymanager.conf — tell Calamares to configure SLiM on the installed system.
cat > "${AIROOTFS}/etc/calamares/modules/displaymanager.conf" << 'DMCONF'
---
displaymanagers:
  - slim
defaultDesktopEnvironment:
  executable: "cutefish-session"
  desktopFile: "cutefish-xsession"
basicSetup: false
DMCONF

# ── kiba-freeze: X11 framebuffer freeze primitive ─────────────────────────
cat > "${AIROOTFS}/usr/local/bin/kiba-freeze" << 'KIBAFREEZE'
#!/bin/bash
# kiba-freeze — freeze the X11 framebuffer, print "PID:PNG_PATH" to stdout.
# Usage:
#   TOKEN=$(kiba-freeze)
#   PID=${TOKEN%%:*}  PNG=${TOKEN#*:}
#   ... make changes ...
#   kill "$PID"; rm -f "$PNG"

DISPLAY="${DISPLAY:-:0}"
TMP=$(mktemp /tmp/kiba-freeze-XXXXXX)
TMP_PNG="${TMP}.png"

# xwd: raw X11 dump — frame-perfect, no compositor lag
xwd -display "${DISPLAY}" -root -silent -out "${TMP}"

# Convert XWD → PNG for display -window root
convert "${TMP}" "${TMP_PNG}" 2>/dev/null
rm -f "${TMP}"

# Overlay the frozen frame on the root window.
display -display "${DISPLAY}" -window root "${TMP_PNG}" &
OVERLAY_PID=$!

# One frame for the X server to composite the overlay
sleep 0.04

echo "${OVERLAY_PID}:${TMP_PNG}"
KIBAFREEZE
chmod +x "${AIROOTFS}/usr/local/bin/kiba-freeze"

# ── kiba-apply: instant-apply settings daemon ─────────────────────────────
cat > "${AIROOTFS}/usr/local/bin/kiba-apply" << 'KIBAAPPLY'
#!/usr/bin/env python3
"""
kiba-apply  — KibaOS instant-apply settings daemon
Unix socket: /run/user/<uid>/kiba-apply.sock

Supported ops (send as JSON, one line):
  {"op":"theme",        "value":"dark"|"light"}
  {"op":"wallpaper",    "value":"/path/to/image"}
  {"op":"font_scale",   "value":1.0}
  {"op":"accessibility","key":"large_text"|"high_contrast"|"reduce_motion",
                        "value":true|false}
  {"op":"xrandr",       "args":["--output","HDMI-1","--brightness","0.8"]}
"""
import json, os, signal, socket, subprocess, sys, threading, time

UID       = os.getuid()
SOCK_DIR  = os.environ.get("XDG_RUNTIME_DIR") or f"/tmp/kiba-{UID}"
SOCK_PATH = f"{SOCK_DIR}/kiba-apply.sock"
DISPLAY   = os.environ.get("DISPLAY", ":0")
ENV       = {**os.environ, "DISPLAY": DISPLAY}

os.makedirs(SOCK_DIR, exist_ok=True)

# ── helpers ───────────────────────────────────────────────────────────────
def gsettings(schema, key, value):
    subprocess.run(["gsettings", "set", schema, key, str(value)], env=ENV,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

def dconf_write(path, value):
    subprocess.run(["dconf", "write", path, value], env=ENV,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

def xrandr_run(*args):
    subprocess.run(["xrandr", "--display", DISPLAY] + list(args), env=ENV)

# ── freeze / unfreeze ─────────────────────────────────────────────────────
def freeze_screen():
    result = subprocess.run(["kiba-freeze"], capture_output=True, text=True, env=ENV)
    token = result.stdout.strip()
    if ":" not in token:
        return None, None
    pid_str, png_path = token.split(":", 1)
    try:
        return int(pid_str), png_path
    except ValueError:
        return None, None

def unfreeze(pid, png_path):
    if pid:
        try:
            os.kill(pid, signal.SIGTERM)
        except ProcessLookupError:
            pass
    if png_path:
        try:
            os.unlink(png_path)
        except FileNotFoundError:
            pass

# ── operation handlers ────────────────────────────────────────────────────
def _current_dark():
    r = subprocess.run(["dconf", "read", "/org/cutefish/theme/colorScheme"],
                       capture_output=True, text=True, env=ENV)
    return "dark" in r.stdout

def op_theme(value):
    dark = (value == "dark")
    dconf_write("/org/cutefish/theme/colorScheme", "'dark'" if dark else "'light'")
    gsettings("org.gnome.desktop.interface", "color-scheme",
              "prefer-dark" if dark else "default")
    gsettings("org.gnome.desktop.interface", "gtk-theme",
              "Adwaita-dark" if dark else "Adwaita")
    cfg = os.path.expanduser("~/.config/cutefishtheme.conf")
    with open(cfg, "w") as f:
        f.write(f"[Theme]\ncolorScheme={'dark' if dark else 'light'}\n")

def op_wallpaper(path):
    if not os.path.exists(path):
        return
    dconf_write("/org/cutefish/background/pictureUrl", f"'{path}'")
    cfg = os.path.expanduser("~/.config/cutefish-wallpaper.conf")
    with open(cfg, "w") as f:
        f.write(f"[Wallpaper]\npath={path}\n")

def op_font_scale(scale):
    scale = max(0.5, min(3.0, float(scale)))
    gsettings("org.gnome.desktop.interface", "text-scaling-factor", scale)
    dconf_write("/org/cutefish/theme/fontPointSize", str(int(10 * scale)))

def op_accessibility(key, value):
    v = bool(value)
    if key == "large_text":
        op_font_scale(1.5 if v else 1.0)
    elif key == "high_contrast":
        dark = _current_dark()
        theme  = "HighContrast"           if v else ("Adwaita-dark" if dark else "Adwaita")
        scheme = "'highcontrast'"         if v else ("'dark'"       if dark else "'light'")
        gsettings("org.gnome.desktop.interface", "gtk-theme", theme)
        dconf_write("/org/cutefish/theme/colorScheme", scheme)
    elif key == "reduce_motion":
        gsettings("org.gnome.desktop.interface", "enable-animations",
                  "false" if v else "true")

def op_xrandr(args):
    xrandr_run(*args)

HANDLERS = {
    "theme":         lambda d: op_theme(d["value"]),
    "wallpaper":     lambda d: op_wallpaper(d["value"]),
    "font_scale":    lambda d: op_font_scale(d["value"]),
    "accessibility": lambda d: op_accessibility(d["key"], d["value"]),
    "xrandr":        lambda d: op_xrandr(d["args"]),
}

# ── socket server ─────────────────────────────────────────────────────────
def handle_client(conn):
    try:
        data = b""
        while True:
            chunk = conn.recv(4096)
            if not chunk:
                break
            data += chunk
        msg = json.loads(data.decode())
        op  = msg.get("op")
        fn  = HANDLERS.get(op)
        if fn is None:
            conn.sendall(b'{"error":"unknown op"}\n')
            return

        freeze_pid, freeze_png = freeze_screen()
        try:
            fn(msg)
        finally:
            time.sleep(0.06)
            unfreeze(freeze_pid, freeze_png)

        conn.sendall(b'{"ok":true}\n')
    except Exception as e:
        try:
            conn.sendall(json.dumps({"error": str(e)}).encode() + b"\n")
        except Exception:
            pass
    finally:
        conn.close()

def main():
    if os.path.exists(SOCK_PATH):
        os.unlink(SOCK_PATH)
    srv = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    srv.bind(SOCK_PATH)
    os.chmod(SOCK_PATH, 0o600)
    srv.listen(8)

    def _shutdown(sig, _):
        srv.close()
        sys.exit(0)
    signal.signal(signal.SIGTERM, _shutdown)
    signal.signal(signal.SIGINT,  _shutdown)

    print(f"kiba-apply listening on {SOCK_PATH}", flush=True)
    while True:
        conn, _ = srv.accept()
        threading.Thread(target=handle_client, args=(conn,), daemon=True).start()

if __name__ == "__main__":
    main()
KIBAAPPLY
chmod +x "${AIROOTFS}/usr/local/bin/kiba-apply"

# ── kiba-set: thin CLI client ──────────────────────────────────────────────
cat > "${AIROOTFS}/usr/local/bin/kiba-set" << 'KIBASET'
#!/usr/bin/env python3
"""
kiba-set — send a settings instruction to kiba-apply
Examples:
  kiba-set theme dark
  kiba-set theme light
  kiba-set wallpaper /usr/share/cutefish-wallpapers/default.jpg
  kiba-set font_scale 1.25
  kiba-set accessibility large_text true
  kiba-set accessibility high_contrast false
  kiba-set accessibility reduce_motion true
  kiba-set xrandr --output HDMI-1 --brightness 0.8
"""
import json, os, socket, sys

UID  = os.getuid()
SOCK = f"{os.environ.get('XDG_RUNTIME_DIR', f'/tmp/kiba-{UID}')}/kiba-apply.sock"

def send(payload):
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.connect(SOCK)
    s.sendall(json.dumps(payload).encode())
    s.shutdown(socket.SHUT_WR)
    resp = b""
    while True:
        c = s.recv(4096)
        if not c:
            break
        resp += c
    s.close()
    return json.loads(resp)

def main():
    args = sys.argv[1:]
    if not args:
        print(__doc__)
        sys.exit(1)
    op = args[0]
    if op == "theme":
        payload = {"op": op, "value": args[1]}
    elif op == "wallpaper":
        payload = {"op": op, "value": args[1]}
    elif op == "font_scale":
        payload = {"op": op, "value": float(args[1])}
    elif op == "accessibility":
        payload = {"op": op, "key": args[1],
                   "value": args[2].lower() in ("true", "1", "yes")}
    elif op == "xrandr":
        payload = {"op": op, "args": args[1:]}
    else:
        print(f"Unknown op: {op}")
        sys.exit(1)
    print(json.dumps(send(payload)))

if __name__ == "__main__":
    main()
KIBASET
chmod +x "${AIROOTFS}/usr/local/bin/kiba-set"

# ── kiba-access: accessibility quick panel ────────────────────────────────
cat > "${AIROOTFS}/usr/local/bin/kiba-access" << 'KIBAACCESS'
#!/usr/bin/env python3
"""
kiba-access — KibaOS accessibility quick panel
Launched from the statusbar accessibility icon or kiba-welcome.
"""
import json, os, subprocess, sys

def dconf_read(k):
    r = subprocess.run(["dconf", "read", k], capture_output=True, text=True)
    return r.stdout.strip().strip("'\"")

def scale_value():
    try:
        return float(dconf_read("/org/gnome/desktop/interface/text-scaling-factor"))
    except Exception:
        return 1.0

large   = scale_value() >= 1.4
hc      = "highcontrast" in dconf_read("/org/cutefish/theme/colorScheme").lower()
reduced = dconf_read("/org/gnome/desktop/interface/enable-animations") == "false"

rows = []
for tag, label, state in [
    ("large_text",    "Large Text (150%)",           large),
    ("high_contrast", "High Contrast",               hc),
    ("reduce_motion", "Reduce Motion / Animations",  reduced),
]:
    rows += [("TRUE" if state else "FALSE"), tag, label]

result = subprocess.run(
    ["zenity", "--list", "--checklist",
     "--title=KibaOS Accessibility",
     "--text=Toggle accessibility features:",
     "--column=", "--column=Key", "--column=Feature",
     "--hide-column=2", "--print-column=2",
     "--separator=,",
     "--width=390", "--height=260",
     "--ok-label=Apply", "--cancel-label=Cancel",
     ] + rows,
    capture_output=True, text=True
)
if result.returncode != 0:
    sys.exit(0)

chosen = set(result.stdout.strip().split(",")) if result.stdout.strip() else set()

for tag, _, was in [
    ("large_text",    "", large),
    ("high_contrast", "", hc),
    ("reduce_motion", "", reduced),
]:
    now = tag in chosen
    if now != was:
        subprocess.run(["kiba-set", "accessibility", tag, str(now).lower()])
KIBAACCESS
chmod +x "${AIROOTFS}/usr/local/bin/kiba-access"

# ── systemd user unit: kiba-apply ─────────────────────────────────────────
mkdir -p "${AIROOTFS}/usr/lib/systemd/user"
cat > "${AIROOTFS}/usr/lib/systemd/user/kiba-apply.service" << 'KAUNIT'
[Unit]
Description=KibaOS instant-apply settings daemon
After=graphical-session.target
PartOf=graphical-session.target

[Service]
Type=simple
ExecStart=/usr/local/bin/kiba-apply
Restart=on-failure
RestartSec=2

[Install]
WantedBy=graphical-session.target
KAUNIT

mkdir -p "${AIROOTFS}/usr/lib/systemd/user/graphical-session.target.wants"
ln -sf /usr/lib/systemd/user/kiba-apply.service \
       "${AIROOTFS}/usr/lib/systemd/user/graphical-session.target.wants/kiba-apply.service"

# ── Welcome script ─────────────────────────────────────────────────────────
cat > "${AIROOTFS}/usr/local/bin/kiba-welcome" << 'WELCOME'
#!/bin/bash
while true; do
  CHOICE=$(zenity --list --title="Welcome to KibaOS" \
    --text="Welcome to KibaOS. What would you like to do?" \
    --column="Tag" --column="Action" --column="Description" \
    "install"       "Install KibaOS"        "Install the system permanently to your disk" \
    "browser"       "Web Browser"           "Browse the internet" \
    "terminal"      "Open Terminal"         "Use Meta+T to launch" \
    "files"         "File Manager"          "Use Meta+E to browse" \
    "screenshot"    "Screen Capture"        "Use Print to capture" \
    "accessibility" "Accessibility"         "Font size, contrast, motion settings" \
    "info"          "System Information"    "View technical system details" \
    "shortcuts"     "Keyboard Shortcuts"    "View useful desktop shortcuts" \
    "wiki"          "Online Wiki"           "Read the technical documentation" \
    --hide-column=1 --print-column=1 \
    --width=450 --height=520 --ok-label="Launch" --cancel-label="Close" 2>/dev/null)

  [ -z "$CHOICE" ] && break

  case "$CHOICE" in
    install)        sudo calamares & break ;;
    browser)        firefox & break ;;
    terminal)       cutefish-terminal & break ;;
    files)          cutefish-filemanager & break ;;
    screenshot)     cutefish-screenshot & break ;;
    accessibility)  kiba-access & ;;
    info)           (fastfetch | zenity --text-info \
                      --title="KibaOS System Information") & ;;
    shortcuts)
      zenity --list --title="KibaOS Shortcuts" \
        --column="Action" --column="Shortcut" \
        "Application Menu"   "Meta" \
        "Terminal"           "Meta + T" \
        "Search"             "Meta + Space" \
        "File Manager"       "Meta + E" \
        "Accessibility"      "Statusbar icon or kiba-access" \
        "Apply theme"        "kiba-set theme dark|light" \
        --ok-label="Close" --cancel-label="Close" 2>/dev/null &
      ;;
    wiki)
      firefox "https://github.com/WolfTech-Innovations/Kiba/blob/main/WIKI.md" & break
      ;;
  esac
done
WELCOME
chmod +x "${AIROOTFS}/usr/local/bin/kiba-welcome"

# ── pacman.conf: NoExtract to skip man/doc/locale at install time ─────────
PACMAN_CONF="${PROFILE}/pacman.conf"
if [ -f "${PACMAN_CONF}" ]; then
  grep -q 'NoExtract' "${PACMAN_CONF}" || \
    sed -i '/^\[options\]/a NoExtract  = usr/share/man/* usr/share/info/* usr/share/doc/*\nNoExtract  = usr/share/locale/* !usr/share/locale/en_US/* !usr/share/locale/en_GB/* !usr/share/locale/locale.alias' \
    "${PACMAN_CONF}"
fi

# ── liveuser account ───────────────────────────────────────────────────────
mkdir -p "${AIROOTFS}/etc"

grep -q '^liveuser:' "${AIROOTFS}/etc/passwd"  2>/dev/null || \
  echo 'liveuser:x:1000:1000:KibaOS Live User:/home/liveuser:/usr/bin/zsh' \
  >> "${AIROOTFS}/etc/passwd"
grep -q '^liveuser:' "${AIROOTFS}/etc/group"   2>/dev/null || \
  echo 'liveuser:x:1000:liveuser'              >> "${AIROOTFS}/etc/group"
# '!' locks the password — SLiM auto_login bypasses PAM auth so this is fine.
grep -q '^liveuser:' "${AIROOTFS}/etc/shadow"  2>/dev/null || \
  echo 'liveuser:!:19000:0:99999:7:::'         >> "${AIROOTFS}/etc/shadow"

mkdir -p "${AIROOTFS}/home/liveuser"
mkdir -p "${AIROOTFS}/etc/sudoers.d"
echo 'liveuser ALL=(ALL) NOPASSWD: ALL' > "${AIROOTFS}/etc/sudoers.d/liveuser"
chmod 0440 "${AIROOTFS}/etc/sudoers.d/liveuser"

# ── systemd system service symlinks ────────────────────────────────────────
WANTS="${AIROOTFS}/etc/systemd/system"
mkdir -p "${WANTS}/default.target.wants" "${WANTS}/multi-user.target.wants"

ln -sf /usr/lib/systemd/system/graphical.target "${WANTS}/default.target"
ln -sf /usr/lib/systemd/system/slim.service     "${WANTS}/display-manager.service"
ln -sf /usr/lib/systemd/system/NetworkManager.service \
       "${WANTS}/multi-user.target.wants/NetworkManager.service"
ln -sf /usr/lib/systemd/system/NetworkManager-dispatcher.service \
       "${WANTS}/dbus-org.freedesktop.nm-dispatcher.service"
ln -sf /usr/lib/systemd/system/bluetooth.service \
       "${WANTS}/multi-user.target.wants/bluetooth.service"
ln -sf /usr/lib/systemd/system/pacman-init.service \
       "${WANTS}/multi-user.target.wants/pacman-init.service"

# ── customize_airootfs.sh (runs in chroot at build time) ──────────────────
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

# ── systemd tunables ──────────────────────────────────────────────────────
sed -i 's/#Storage=auto/Storage=volatile/'                    /etc/systemd/journald.conf
sed -i 's/#HandleLidSwitch=suspend/HandleLidSwitch=ignore/'   /etc/systemd/logind.conf
sed -i 's/#HandleSuspendKey=suspend/HandleSuspendKey=ignore/' /etc/systemd/logind.conf

# ── Root shell ────────────────────────────────────────────────────────────
chsh -s /usr/bin/zsh root

# ── liveuser home ─────────────────────────────────────────────────────────
cp -aT /etc/skel/ /home/liveuser/ 2>/dev/null || true
chown -R 1000:1000 /home/liveuser
chmod 750 /home/liveuser

# ── dconf system-db: dark mode defaults ───────────────────────────────────
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
DCONFKEYS
dconf update

# ── Cutefish native configs ────────────────────────────────────────────────
mkdir -p /home/liveuser/.config

cat > /home/liveuser/.config/cutefishtheme.conf << 'CFTHEME'
[Theme]
colorScheme=dark
CFTHEME

# Statusbar: accessibility launcher button
cat > /home/liveuser/.config/cutefish-statusbar.conf << 'SBCONF'
[Plugins]
enabled=network,volume,battery,datetime,accessibility-kiba
[accessibility-kiba]
type=launcher
icon=preferences-desktop-accessibility
tooltip=Accessibility
command=kiba-access
SBCONF

# ── kiba-apply user service: enable for liveuser ──────────────────────────
mkdir -p /home/liveuser/.config/systemd/user/graphical-session.target.wants
ln -sf /usr/lib/systemd/user/kiba-apply.service \
       /home/liveuser/.config/systemd/user/graphical-session.target.wants/kiba-apply.service

# ── Flathub remote ────────────────────────────────────────────────────────
flatpak remote-add --system --if-not-exists flathub \
  https://dl.flathub.org/repo/flathub.flatpakrepo 2>/dev/null || true

# ── Autostart entries for liveuser ────────────────────────────────────────
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

# ── Aggressive size reduction ─────────────────────────────────────────────
rm -rf /var/cache/pacman/pkg/*
rm -rf /usr/share/man/*
rm -rf /usr/share/info/*
rm -rf /usr/share/doc/*

find /usr/share/locale -mindepth 1 -maxdepth 1 \
  ! -name 'en_US' ! -name 'en_GB' ! -name 'locale.alias' \
  -exec rm -rf {} + 2>/dev/null || true
find /usr/share/i18n/locales -mindepth 1 -maxdepth 1 \
  ! -name 'en_US' ! -name 'en_GB' ! -name 'POSIX' \
  -exec rm -rf {} + 2>/dev/null || true

find /usr/lib/firmware -mindepth 1 -maxdepth 1 \
  ! -name 'i915'     \
  ! -name 'amdgpu'   \
  ! -name 'radeon'   \
  ! -name 'iwlwifi*' \
  ! -name 'ath*'     \
  ! -name 'rtl_nic'  \
  ! -name 'rtlwifi'  \
  ! -name 'mt7601u*' \
  ! -name 'sof'      \
  ! -name 'sof-tplg' \
  ! -name 'intel'    \
  ! -name 'qed'      \
  -exec rm -rf {} + 2>/dev/null || true

find /usr -type d -name '__pycache__' -exec rm -rf {} + 2>/dev/null || true
find /usr -name '*.pyc' -delete 2>/dev/null || true
find /usr/lib -name '*.a' -delete 2>/dev/null || true
rm -rf /usr/include/* 2>/dev/null || true
find /usr/share/icons -name 'icon-theme.cache' -delete 2>/dev/null || true
rm -rf /var/lib/pacman/sync/*
rm -rf /tmp/* /var/tmp/* 2>/dev/null || true

# ── Fix ownership one final time ──────────────────────────────────────────
chown -R 1000:1000 /home/liveuser
CUSTOMIZE
chmod +x "${AIROOTFS}/root/customize_airootfs.sh"

# ── Build the ISO ──────────────────────────────────────────────────────────
cd "${WORKDIR}"
mkarchiso -v -w work -o out "${PROFILE}/"

if ls out/*.iso 1>/dev/null 2>&1; then
  mv out/*.iso "${ISO}.iso"
  sha256sum "${ISO}.iso" > "${ISO}.iso.sha256"
  echo "=== Build complete: ${ISO}.iso ==="
else
  echo "ERROR: ISO file not found after mkarchiso!"
  exit 1
fi
