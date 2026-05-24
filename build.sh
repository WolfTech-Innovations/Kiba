#!/bin/bash
set -ex
set -o pipefail

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
  python python-yaml python-jsonschema jq \
  qt5-xmlpatterns kparts5 \
  \
  greetd greetd-regreet cage \
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
airootfs_image_tool_options=('-comp' 'xz' '-Xbcj' 'x86' '-b' '1M' '-Xdict-size' '1M')
file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/etc/gshadow"]="0:0:400"
  ["/usr/local/bin/kiba-welcome"]="0:0:755"
  ["/usr/local/bin/kiba-launch-session"]="0:0:755"
  ["/usr/local/bin/kiba-apply"]="0:0:755"
  ["/usr/local/bin/kiba-set"]="0:0:755"
  ["/usr/local/bin/kiba-access"]="0:0:755"
  ["/root"]="0:0:750"
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

  sed -i '/add_subdirectory(bluetooth)/d'         CMakeLists.txt
  sed -i '/add_subdirectory(bluez)/d'             CMakeLists.txt
  sed -i '/add_subdirectory(networkmanagement)/d' CMakeLists.txt
  sed -i '/add_subdirectory(screen)/d'            CMakeLists.txt
  sed -i '/find_package(KF5BluezQt/d'             CMakeLists.txt
  sed -i '/find_package(KF5NetworkManagerQt/d'    CMakeLists.txt
  sed -i '/find_package(KF5ModemManagerQt/d'      CMakeLists.txt
  sed -i '/find_package(KF5Screen/d'              CMakeLists.txt
  sed -i '/KF5::BluezQt/d'                        CMakeLists.txt
  sed -i '/KF5::NetworkManagerQt/d'               CMakeLists.txt
  sed -i '/KF5::ModemManagerQt/d'                 CMakeLists.txt
  sed -i '/KF5::Screen/d'                         CMakeLists.txt
  sed -i '/src\/vpn\/vpn\.cpp/d'                  CMakeLists.txt
  sed -i '/src\/vpn\/nm-.*\.h/d'                  CMakeLists.txt

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

# ── Package list ───────────────────────────────────────────────────────────
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
greetd
greetd-regreet
cage
xorg-server
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
PACKAGES

# ── initramfs ──────────────────────────────────────────────────────────────
mkdir -p "${AIROOTFS}/etc/mkinitcpio.conf.d"
cat > "${AIROOTFS}/etc/mkinitcpio.conf.d/archiso.conf" << 'INITRAMFS'
HOOKS=(base udev memdisk archiso block filesystems)
INITRAMFS

mkdir -p "${AIROOTFS}/etc/mkinitcpio.d"
cat > "${AIROOTFS}/etc/mkinitcpio.d/linux.preset" << 'PRESET'
PRESETS=('archiso')
ALL_kver='/boot/vmlinuz-linux'
archiso_config='/etc/mkinitcpio.conf.d/archiso.conf'
archiso_image='/boot/initramfs-linux.img'
PRESET

# ── Boot menu ──────────────────────────────────────────────────────────────
cat > "${PROFILE}/efiboot/loader/loader.conf" << 'LOADER'
default kibaos.conf
timeout 5
console-mode max
editor no
LOADER

mkdir -p "${PROFILE}/efiboot/loader/entries"
cat > "${PROFILE}/efiboot/loader/entries/kibaos.conf" << 'ENTRY'
title   KibaOS
linux   /arch/boot/x86_64/vmlinuz-linux
initrd  /arch/boot/x86_64/initramfs-linux.img
options archisobasedir=arch archisolabel=KIBAOS cow_spacesize=1G
ENTRY

SYSLINUX_CFG="${PROFILE}/syslinux/syslinux.cfg"
if [ -f "${SYSLINUX_CFG}" ]; then
  sed -i 's/Arch Linux/KibaOS/g'   "${SYSLINUX_CFG}"
  sed -i 's/ARCH_[0-9]*/KIBAOS/g' "${SYSLINUX_CFG}"
fi

# ── greetd + ReGreet config ───────────────────────────────────────────────
# ReGreet is a GTK4 greetd greeter. It runs under cage (minimal Wayland
# compositor). It reads session entries from /usr/share/xsessions/ but
# launches them via x11_prefix so the Exec= line is run as a direct binary,
# not through an Xsession wrapper script.
mkdir -p "${AIROOTFS}/etc/greetd"

# greetd config: run cage which hosts regreet on vt1
cat > "${AIROOTFS}/etc/greetd/config.toml" << 'GREETDCONF'
[terminal]
vt = 1

[default_session]
# cage -s: don't allow VT switching away from the greeter
# regreet reads /etc/greetd/regreet.toml for its own config
command = "cage -s -- regreet"
user = "greeter"
GREETDCONF

# ReGreet config — dark mode, KibaOS branding, direct X11 binary launch
mkdir -p "${AIROOTFS}/etc/greetd"
cat > "${AIROOTFS}/etc/greetd/regreet.toml" << 'REGREETCONF'
[background]
path = "/usr/share/cutefish-wallpapers/default.jpg"
fit = "Cover"

[GTK]
application_prefer_dark_theme = true
cursor_theme_name = "Adwaita"
cursor_blink = false
font_name = "Inter 14"
icon_theme_name = "cutefish-icons"
theme_name = "Adwaita"

[commands]
reboot  = ["systemctl", "reboot"]
poweroff = ["systemctl", "poweroff"]

# x11_prefix wraps every X11 session's Exec= binary so regreet starts
# the X server itself and hands the binary directly to it — no Xsession
# wrapper script, no xinit shim, no shell indirection.
# "startx /usr/bin/env" prepends to whatever Exec= is in the .desktop file.
x11_prefix = ["startx", "/usr/bin/env"]

[appearance]
greeting_msg = "KibaOS"

[widget.clock]
format = "%a %b %d  %H:%M"
resolution = "1s"
label_width = 200
REGREETCONF

# kiba-session.desktop — the session entry ReGreet will show.
# Exec= is the direct binary (cutefish-session), NOT a wrapper script.
# ReGreet prepends x11_prefix so the actual invocation becomes:
#   startx /usr/bin/env kiba-launch-session -- :0 vt1
# where kiba-launch-session sets env then execs cutefish-session.
mkdir -p "${AIROOTFS}/usr/local/bin"
cat > "${AIROOTFS}/usr/local/bin/kiba-launch-session" << 'KIBASESSION'
#!/bin/bash
# kiba-launch-session — direct session binary called by startx via ReGreet.
# startx invokes this as the client program inside a fresh X server.
# No PAM, no Xsession wrapper, no display manager session script.

export XDG_CURRENT_DESKTOP=Cutefish
export DESKTOP_SESSION=cutefish
export XDG_SESSION_DESKTOP=cutefish
export XDG_SESSION_TYPE=x11
export KDE_FULL_SESSION=
export KDE_SESSION_VERSION=

# D-Bus session bus for this X session
eval "$(dbus-launch --sh-syntax --exit-with-session)"

# kwin_x11 must start before cutefish-session on Arch
kwin_x11 --replace &
sleep 0.6

# kiba-apply instant-settings daemon
/usr/local/bin/kiba-apply &

exec cutefish-session
KIBASESSION
chmod +x "${AIROOTFS}/usr/local/bin/kiba-launch-session"

# The xsession desktop entry — Exec= points at our direct launcher binary.
# ReGreet reads this, prepends x11_prefix = ["startx", "/usr/bin/env"],
# and spawns: startx /usr/bin/env /usr/local/bin/kiba-launch-session -- :0 vt1
mkdir -p "${AIROOTFS}/usr/share/xsessions"
cat > "${AIROOTFS}/usr/share/xsessions/kibaos.desktop" << 'SESSIONDESK'
[Desktop Entry]
Name=KibaOS
Comment=KibaOS Cutefish Desktop
Exec=/usr/local/bin/kiba-launch-session
TryExec=/usr/local/bin/kiba-launch-session
Type=XSession
DesktopNames=Cutefish
SESSIONDESK

# ReGreet needs a tmpfiles.d entry to create /var/cache/regreet at boot
mkdir -p "${AIROOTFS}/usr/lib/tmpfiles.d"
cat > "${AIROOTFS}/usr/lib/tmpfiles.d/regreet.conf" << 'TMPFILES'
d /var/cache/regreet 0755 greeter greeter -
TMPFILES

# ── Calamares config ───────────────────────────────────────────────────────
mkdir -p "${AIROOTFS}/etc/calamares/modules"

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

# unpackfs.conf — the live squashfs IS the system; unpacking it verbatim
# means every DE change the user made in the live session transfers over.
cat > "${AIROOTFS}/etc/calamares/modules/unpackfs.conf" << 'UNPACKFS'
---
unpack:
  - source: "/run/archiso/bootmnt/arch/x86_64/airootfs.sfs"
    sourcefs: "squashfs"
    destination: ""
  - source: "/run/archiso/bootmnt/arch/boot/x86_64/vmlinuz-linux"
    sourcefs: "file"
    destination: "/boot/vmlinuz-linux"
UNPACKFS

# shellprocess: copy liveuser settings into the installer-created user account
cat > "${AIROOTFS}/etc/calamares/modules/shellprocess@copy-user-settings.conf" << 'SHELLPROC'
---
dontChroot: false
timeout: 120
script:
  - "-": "echo '=== KibaOS: migrating live session settings to new user ==='"
  - "-": |
          NEW_USER=$(python3 -c "
          import json
          try:
              d = json.load(open('/etc/calamares/users.json'))
              print(d.get('username',''))
          except Exception:
              print('')
          ")
          [ -z "$NEW_USER" ] && { echo 'WARNING: no username found, skipping'; exit 0; }
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

cat > "${AIROOTFS}/etc/calamares/modules/displaymanager.conf" << 'DMCONF'
---
displaymanagers:
  - greetd
defaultDesktopEnvironment:
  executable: "cutefish-session"
  desktopFile: "kibaos"
basicSetup: false
DMCONF

# ── kiba-freeze: X11/WL-layer framebuffer freeze primitive ────────────────
#
# HOW THE FREEZE WORKS:
#   1. xwd -root -silent  → fast raw X11 framebuffer grab into a temp .xwd
#      xwd talks directly to the X server's backing store, bypassing the
#      compositor, so it's a true frame-perfect snapshot even on composited
#      desktops. No partial-frame artefacts unlike ImageMagick import.
#
#   2. The .xwd dump is converted to PNG with `convert` (ImageMagick) once,
#      then displayed fullscreen via `display -window root` which uses the
#      X11 Composite/Overlay layer — it paints over everything without
#      raising or moving any real windows.
#
#   3. kiba-apply applies the real change underneath while the frozen frame
#      is visible. When it finishes it kills the overlay process.
#      From the user's POV: zero flicker, zero repaint flash.
#
# This is called kiba-freeze and is a standalone script so it can also be
# invoked externally (e.g. from shell scripts that change the wallpaper).
mkdir -p "${AIROOTFS}/usr/local/bin"
cat > "${AIROOTFS}/usr/local/bin/kiba-freeze" << 'KIBAFREEZE'
#!/bin/bash
# kiba-freeze — freeze the X11 framebuffer and print the overlay PID to stdout
# Usage:
#   FREEZE_PID=$(kiba-freeze)   # start overlay, returns PID
#   kill "$FREEZE_PID"          # release overlay

DISPLAY="${DISPLAY:-:0}"
TMP=$(mktemp /tmp/kiba-freeze-XXXXXX)
TMP_PNG="${TMP}.png"

# xwd: raw X11 dump — bypasses compositor, frame-perfect
xwd -display "${DISPLAY}" -root -silent -out "${TMP}"

# Convert XWD → PNG (xwud can display XWD natively but ImageMagick gives us
# full-res RGBA which display -window root composites cleanly)
convert "${TMP}" "${TMP_PNG}" 2>/dev/null
rm -f "${TMP}"

# Overlay the frozen frame on the X11 root window (Composite/Overlay layer).
# -window root paints directly to the root drawable — sits on top of all
# client windows without the WM knowing about it.
display -display "${DISPLAY}" -window root "${TMP_PNG}" &
OVERLAY_PID=$!

# Small settle: give the X server one frame to composite the overlay
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

Freeze/unfreeze is delegated to kiba-freeze (bash) which uses:
  xwd -root -silent    → frame-perfect X11 raw dump (no compositor artefacts)
  convert XWD→PNG      → lossless intermediate
  display -window root → X11 Composite overlay, paints over all windows

Supported ops (send as JSON, one line):
  {"op":"theme",        "value":"dark"|"light"}
  {"op":"wallpaper",    "value":"/path/to/image"}
  {"op":"font_scale",   "value":1.0}
  {"op":"accessibility","key":"large_text"|"high_contrast"|"reduce_motion",
                        "value":true|false}
  {"op":"xrandr",       "args":["--output","HDMI-1","--brightness","0.8"]}
"""
import json, os, signal, socket, subprocess, sys, tempfile, threading, time

SOCK_DIR  = f"/run/user/{os.getuid()}"
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

# ── freeze / unfreeze via kiba-freeze ─────────────────────────────────────
def freeze_screen():
    """
    Calls kiba-freeze which:
      1. Grabs framebuffer with xwd -root -silent  (X11 native, no compositor lag)
      2. Converts to PNG
      3. Overlays with display -window root
    Returns (overlay_pid, tmp_png_path) for cleanup.
    """
    result = subprocess.run(
        ["kiba-freeze"],
        capture_output=True, text=True, env=ENV
    )
    token = result.stdout.strip()
    if ":" not in token:
        return None, None
    pid_str, png_path = token.split(":", 1)
    return int(pid_str), png_path

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
    dconf_write("/org/cutefish/theme/colorScheme",
                "'dark'" if dark else "'light'")
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
        if v:
            theme = "HighContrast"
            scheme = "'highcontrast'"
        else:
            theme = "Adwaita-dark" if dark else "Adwaita"
            scheme = "'dark'" if dark else "'light'"
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

        # Freeze → apply → unfreeze
        freeze_pid, freeze_png = freeze_screen()
        try:
            fn(msg)
        finally:
            time.sleep(0.06)   # let compositor settle the real change
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

SOCK = f"/run/user/{os.getuid()}/kiba-apply.sock"

def send(payload):
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.connect(SOCK)
    s.sendall(json.dumps(payload).encode())
    s.shutdown(socket.SHUT_WR)
    resp = b""
    while True:
        c = s.recv(4096); 
        if not c: break
        resp += c
    s.close()
    return json.loads(resp)

def main():
    args = sys.argv[1:]
    if not args: print(__doc__); sys.exit(1)
    op = args[0]
    if op == "theme":
        payload = {"op": op, "value": args[1]}
    elif op == "wallpaper":
        payload = {"op": op, "value": args[1]}
    elif op == "font_scale":
        payload = {"op": op, "value": float(args[1])}
    elif op == "accessibility":
        payload = {"op": op, "key": args[1],
                   "value": args[2].lower() in ("true","1","yes")}
    elif op == "xrandr":
        payload = {"op": op, "args": args[1:]}
    else:
        print(f"Unknown op: {op}"); sys.exit(1)
    print(json.dumps(send(payload)))

if __name__ == "__main__":
    main()
KIBASET
chmod +x "${AIROOTFS}/usr/local/bin/kiba-set"

# ── kiba-access: accessibility panel (statusbar button target) ────────────
cat > "${AIROOTFS}/usr/local/bin/kiba-access" << 'KIBAACCESS'
#!/usr/bin/env python3
"""
kiba-access — KibaOS accessibility quick panel
Launched from the statusbar accessibility icon.
"""
import json, os, subprocess, sys

def dconf_read(k):
    r = subprocess.run(["dconf","read",k], capture_output=True, text=True)
    return r.stdout.strip()

large   = "1.5" in dconf_read("/org/gnome/desktop/interface/text-scaling-factor")
hc      = "highcontrast" in dconf_read("/org/cutefish/theme/colorScheme")
reduced = dconf_read("/org/gnome/desktop/interface/enable-animations") == "false"

rows = []
for tag, label, state in [
    ("large_text",    "Large Text (150%)",          large),
    ("high_contrast", "High Contrast",              hc),
    ("reduce_motion", "Reduce Motion / Animations", reduced),
]:
    rows += [("TRUE" if state else "FALSE"), tag, label]

result = subprocess.run(
    ["zenity","--list","--checklist",
     "--title=KibaOS Accessibility",
     "--text=Toggle accessibility features:",
     "--column=","--column=Key","--column=Feature",
     "--hide-column=2","--print-column=2",
     "--separator=,",
     "--width=450","--height=500",
     "--ok-label=Apply","--cancel-label=Cancel",
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
        subprocess.run(["kiba-set","accessibility",tag,str(now).lower()])
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
    --window-icon="/usr/share/kibaos/logo.png" \
    --text="Welcome to KibaOS. What would you like to do?" \
    --column="Tag" --column="Action" --column="Description" \
    "install"       "Install KibaOS"        "Install the system permanently to your disk" \
    "browser"       "Web Browser"           "Browse the internet" \
    "store"         "Software Center"       "Discover and install new applications" \
    "newelle"       "Newelle AI Assistant"  "AI assistant with terminal and file access" \
    "terminal"      "Open Terminal"         "Use Meta+T to launch" \
    "files"         "File Manager"          "Use Meta+E to browse" \
    "screenshot"    "Screen Capture"        "Use Print to capture" \
    "accessibility" "Accessibility"         "Font size, contrast, motion settings" \
    "info"          "System Information"    "View technical system details" \
    "shortcuts"     "Keyboard Shortcuts"    "View useful desktop shortcuts" \
    "wiki"          "Online Wiki"           "Read the technical documentation" \
    --hide-column=1 --print-column=1 \
    --width=450 --height=500 --ok-label="Launch" --cancel-label="Close" 2>/dev/null)

  [ -z "$CHOICE" ] && break

  case "$CHOICE" in
    install)        sudo calamares & break ;;
    browser)        chromium & break ;;
    store)          flatpak run org.kde.discover & break ;;
    newelle)        flatpak run io.github.qwersyk.Newelle & break ;;
    terminal)       cutefish-terminal & break ;;
    files)          cutefish-filemanager & break ;;
    screenshot)     cutefish-screenshot & break ;;
    accessibility)  kiba-access & ;;
    info)           (fastfetch --logo none --pipe true --no-color-blocks | zenity --text-info \
                      --title="KibaOS System Information" --width=450 --height=500) & ;;
    shortcuts)
      zenity --list --title="KibaOS Shortcuts" \
        --column="Action" --column="Shortcut" \
        "Application Menu"  "Meta" \
        "Terminal"          "Meta + T" \
        "Search"            "Meta + Space" \
        "File Manager"      "Meta + E" \
        "Accessibility"     "Statusbar icon or kiba-access" \
        "Apply theme"       "kiba-set theme dark|light" \
        --width=450 --height=500 \
        --ok-label="Close" --cancel-label="Close" 2>/dev/null &
      ;;
    wiki)
      chromium "https://github.com/WolfTech-Innovations/Kiba/blob/main/WIKI.md" & break
      ;;
  esac
done
WELCOME
chmod +x "${AIROOTFS}/usr/local/bin/kiba-welcome"

# ── liveuser account ───────────────────────────────────────────────────────
mkdir -p "${AIROOTFS}/etc"

grep -q '^liveuser:'  "${AIROOTFS}/etc/passwd" 2>/dev/null || \
  echo 'liveuser:x:1000:1000:KibaOS Live User:/home/liveuser:/usr/bin/zsh' \
  >> "${AIROOTFS}/etc/passwd"
grep -q '^liveuser:'  "${AIROOTFS}/etc/group"  2>/dev/null || \
  echo 'liveuser:x:1000:liveuser' >> "${AIROOTFS}/etc/group"
grep -q '^liveuser:'  "${AIROOTFS}/etc/shadow" 2>/dev/null || \
  echo 'liveuser::19000:0:99999:7:::' >> "${AIROOTFS}/etc/shadow"

mkdir -p "${AIROOTFS}/home/liveuser"
mkdir -p "${AIROOTFS}/etc/sudoers.d"
echo 'liveuser ALL=(ALL) NOPASSWD: ALL' > "${AIROOTFS}/etc/sudoers.d/liveuser"

# ── systemd system service symlinks ────────────────────────────────────────
WANTS="${AIROOTFS}/etc/systemd/system"
mkdir -p "${WANTS}/default.target.wants" "${WANTS}/multi-user.target.wants"

ln -sf /usr/lib/systemd/system/graphical.target "${WANTS}/default.target"
ln -sf /usr/lib/systemd/system/greetd.service  "${WANTS}/display-manager.service"
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

sed -i 's/#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
locale-gen
echo 'LANG=en_US.UTF-8' > /etc/locale.conf

echo 'kibaos' > /etc/hostname
cat > /etc/hosts << 'HOSTS'
127.0.0.1   localhost
::1         localhost
127.0.1.1   kibaos.localdomain kibaos
HOSTS

# ── greetd user (required by greetd service) ─────────────────────────────
groupadd -r greeter 2>/dev/null || true
useradd  -r -g greeter -d /var/lib/greeter -s /usr/bin/nologin \
         -c "greetd greeter user" greeter 2>/dev/null || true
mkdir -p /var/lib/greeter
chown greeter:greeter /var/lib/greeter
chmod 711 /var/lib/greeter

for g in users wheel audio video input network; do
  groupadd -r "$g" 2>/dev/null || true
done

sed -i 's/#Storage=auto/Storage=volatile/'                    /etc/systemd/journald.conf
sed -i 's/#HandleLidSwitch=suspend/HandleLidSwitch=ignore/'   /etc/systemd/logind.conf
sed -i 's/#HandleSuspendKey=suspend/HandleSuspendKey=ignore/' /etc/systemd/logind.conf

chsh -s /usr/bin/zsh root

cp -aT /etc/skel/ /home/liveuser/ 2>/dev/null || true
chown -R 1000:1000 /home/liveuser
chmod 700 /home/liveuser

# ── dconf system-db: dark mode defaults ───────────────────────────────────
mkdir -p /etc/dconf/profile
cat > /etc/dconf/profile/user << 'DCONFPROFILE'
user-db:user
system-db:kibaos-defaults
DCONFPROFILE

mkdir -p /etc/dconf/db/kibaos-defaults.d
cat > /etc/dconf/db/kibaos-defaults.d/01-darkmode << 'DCONFKEYS'
[org/cutefish/theme]
colorScheme='dark'

[org/gnome/desktop/interface]
color-scheme='prefer-dark'
gtk-theme='Adwaita-dark'
enable-animations=true

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

# Statusbar: register the accessibility launcher button
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

# ── Install Newelle from Flathub ──────────────────────────────────────────
# Add Flathub remote system-wide so it's ready for both live and installed system.
# The actual flatpak install is deferred to first login to avoid bloating the
# squashfs; we drop a post-login autostart that installs-then-launches on
# first run, then removes itself.
flatpak remote-add --system --if-not-exists flathub \
  https://dl.flathub.org/repo/flathub.flatpakrepo || true

# First-run installer script
cat > /usr/local/bin/kiba-newelle-setup << 'NEWELLESETUP'
#!/bin/bash
# Runs once after first login; installs Newelle then launches it.
flatpak install -y --system flathub io.github.qwersyk.Newelle && \
  flatpak run --talk-name=org.freedesktop.Flatpak \
              --filesystem=home \
              io.github.qwersyk.Newelle
# Remove self from autostart after successful install
rm -f ~/.config/autostart/kiba-newelle-setup.desktop
NEWELLESETUP
chmod +x /usr/local/bin/kiba-newelle-setup

# ── Autostart entries for liveuser ────────────────────────────────────────
mkdir -p /home/liveuser/.config/autostart

cat > /home/liveuser/.config/autostart/kiba-welcome.desktop << 'DESK'
[Desktop Entry]
Type=Application
Name=KibaOS Welcome
Exec=/usr/local/bin/kiba-welcome
X-GNOME-Autostart-enabled=true
DESK

cat > /home/liveuser/.config/autostart/kiba-newelle-setup.desktop << 'NEWELLEDESK'
[Desktop Entry]
Type=Application
Name=Newelle First-Run Setup
Exec=/usr/local/bin/kiba-newelle-setup
X-GNOME-Autostart-enabled=true
NEWELLEDESK

# ── Nuke any KDE/Plasma session files that sneak in as transitive deps ───
# kwin is needed by Cutefish but its presence drags in some KDE autostart
# .desktop files. Remove them all — cutefish-session is the only session.
rm -f /usr/share/xsessions/plasma.desktop
rm -f /usr/share/xsessions/plasmawayland.desktop
rm -f /usr/share/xsessions/kde-plasma.desktop
rm -f /usr/share/wayland-sessions/plasma.desktop
rm -f /usr/share/wayland-sessions/plasmawayland.desktop
# Kill any KDE autostart entries that polkit-kde or kwin packages install
find /etc/xdg/autostart -name 'plasma*' -delete 2>/dev/null || true
find /etc/xdg/autostart -name 'kde*'    -delete 2>/dev/null || true
find /usr/share/autostart -name 'plasma*' -delete 2>/dev/null || true

chown -R 1000:1000 /home/liveuser/.config

# ── xsession desktop file (referenced by Calamares displaymanager module) ─
mkdir -p /usr/share/xsessions
cat > /usr/share/xsessions/cutefish-xsession.desktop << 'SESSION'
[Desktop Entry]
Name=KibaOS (Cutefish)
Comment=KibaOS Desktop Environment
Exec=cutefish-session
TryExec=cutefish-session
Type=XSession
DesktopNames=Cutefish
SESSION
chmod 644 /usr/share/xsessions/cutefish-xsession.desktop
CUSTOMIZE
chmod +x "${AIROOTFS}/root/customize_airootfs.sh"

# ── Build the ISO ──────────────────────────────────────────────────────────
cd "${WORKDIR}"
mkarchiso -v -w work -o out "${PROFILE}/"

if ls out/*.iso 1>/dev/null 2>&1; then
  mv out/*.iso "${ISO}.iso"
  sha256sum "${ISO}.iso" > "${ISO}.iso.sha256"
else
  echo "ERROR: ISO file not found!"
  exit 1
fi
