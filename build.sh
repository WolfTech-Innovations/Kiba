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
wayfire
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
nemo
nemo-fileroller
gnome-terminal
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
ntfs-3g
exfatprogs
polkit
polkit-kde-agent
udisks2
upower
scrot
fastfetch
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
xdg-utils
gawk
gnome-online-accounts
gnome-online-accounts-gtk
gvfs-goa
gnome-calendar
gnome-notes
geary
gnome-music
gnome-todo
plymouth
archinstall
PACKAGES

# ══════════════════════════════════════════════════════════════════════════
# mkinitcpio
# ══════════════════════════════════════════════════════════════════════════
# archiso.conf — used only by the LIVE environment (memdisk/archiso hooks)
mkdir -p "${AIROOTFS}/etc/mkinitcpio.conf.d"
cat > "${AIROOTFS}/etc/mkinitcpio.conf.d/archiso.conf" << 'INITRAMFS'
HOOKS=(base udev keyboard keymap modconf memdisk archiso block filesystems)
INITRAMFS

# installed.conf — used by the INSTALLED system after the OOBE installer runs initcpio.
# Must NOT include memdisk/archiso hooks (those are live-only).
cat > "${AIROOTFS}/etc/mkinitcpio.conf.d/installed.conf" << 'INSTALLED_HOOKS'
HOOKS=(base udev plymouth autodetect modconf kms block keyboard keymap filesystems fsck)
INSTALLED_HOOKS

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
# NOTE on boot logo: a `splash /path/to/image.bmp` line is intentionally
# NOT added here. Confirmed via systemd upstream issue #33728: systemd-boot's
# native splash image only renders when timeout >= 1 or the menu is shown
# manually — it is silently skipped whenever timeout is 0, which is exactly
# our zero-menu setup. This is an open upstream bug, not a config mistake on
# our end. Revisit if/when that's fixed; until then, no systemd-boot splash
# is shown, and the firmware's own BGRT logo (unrelated, OEM-controlled,
# not replaceable without a HackBGRT-style standalone EFI app) is what
# stays on screen through this phase of boot, exactly as before.

cat > "${PROFILE}/efiboot/loader/entries/kibaos.conf" << 'ENTRY'
title   KibaOS
linux   /arch/boot/x86_64/vmlinuz-linux
initrd  /arch/boot/x86_64/initramfs-linux.img
options archisobasedir=arch archisolabel=KIBAOS cow_spacesize=1G quiet loglevel=3 rd.udev.log_level=3 vt.global_cursor_default=0
ENTRY

cat > "${PROFILE}/efiboot/loader/entries/kibaos-safe.conf" << 'ENTRY_SAFE'
title   KibaOS (safe mode)
linux   /arch/boot/x86_64/vmlinuz-linux
initrd  /arch/boot/x86_64/initramfs-linux.img
options archisobasedir=arch archisolabel=KIBAOS cow_spacesize=1G nomodeset systemd.unit=multi-user.target systemd.log_level=info
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
  APPEND archisobasedir=arch archisolabel=KIBAOS cow_spacesize=1G nomodeset systemd.unit=multi-user.target systemd.log_level=info
SYSLINUX_SAFE
fi

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
WALLPAPER_URL="https://github.com/WolfTech-Innovations/Kiba/blob/main/branding/file_000000004b64720cabf43ce95dda0a0d.png?raw=true"
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
for pkg in libinput-gestures; do
  echo "=== Building ${pkg} from AUR ==="
  git clone --depth=1 "https://aur.archlinux.org/${pkg}.git" "${AUR_BUILD}/${pkg}"
  chown -R builduser:builduser "${AUR_BUILD}/${pkg}"
  cd "${AUR_BUILD}/${pkg}"
  # Bolt: Optimize AUR builds by using all cores and skipping compression
  # NOTE: runuser, not sudo -u — sudo is a setuid binary and setuid binaries
  # are unreliable/broken on nosuid-mounted chroot filesystems (confirmed:
  # this is exactly the "strange sudo error" multiple Arch forum threads
  # report when running sudo inside arch-chroot/Docker-based archiso
  # builds). runuser does the same "run this as another user" job but is
  # meant to be invoked by a process that's already root, which is exactly
  # our situation inside customize_airootfs.sh — no setuid escalation
  # needed at all since we start as root already.
  runuser -u builduser -- env MAKEFLAGS="-j$(nproc)" PKGEXT='.pkg.tar' makepkg -si --noconfirm --skippgpcheck
  cd /
done

# ── ChromeOS-theme: manual install to avoid gnome-shell dependency ─────────
echo "=== Installing ChromeOS-theme ==="
git clone --depth=1 "https://github.com/vinceliuice/ChromeOS-theme.git" "${AUR_BUILD}/ChromeOS-theme"
cd "${AUR_BUILD}/ChromeOS-theme"
# Install only the GTK theme files directly, bypassing the installer's
# gnome-shell dependency check
mkdir -p /usr/share/themes
for variant in ChromeOS ChromeOS-Dark; do
  [ -d "themes/${variant}" ] && \
    cp -r "themes/${variant}" /usr/share/themes/ || true
done
# Fallback: run installer with --dest if theme dirs not pre-built
if [ ! -d /usr/share/themes/ChromeOS-Dark ]; then
  bash install.sh --dest /usr/share/themes --color dark 2>/dev/null || true
  bash install.sh --dest /usr/share/themes --color light 2>/dev/null || true
fi
cd /

cd /; rm -rf "${AUR_BUILD}"
userdel -r builduser 2>/dev/null || true
rm -f /etc/sudoers.d/builduser
pacman -Rns --noconfirm gcc base-devel debugedit make patch autoconf automake 2>/dev/null || true
pacman -Qtdq | pacman -Rns --noconfirm - 2>/dev/null || true
echo "=== AUR packages installed ==="

# ══════════════════════════════════════════════════════════════════════════
# KIBAOS OOBE INSTALLER — fullscreen, one-step-per-screen Vala/GTK4 app.
#
# Earlier attempts ported elementary/installer + distinst to Arch/pacman.
# That path is abandoned: distinst's apt/dpkg assumptions required a Rust
# source patch (done), which then required building GNU parted from source
# to get complete libparted headers for bindgen (done), which then hit an
# unrelated upstream parted CLI compile bug. Rather than keep patching a
# dependency chain built for Ubuntu/apt, this section replaces it entirely
# with a small from-scratch Vala/GTK4/libadwaita app:
#   - UI: a NavigationView stack, one page per step (welcome, locale, disk,
#     account, confirm, installing, done) — no sidebar, no visible step
#     list, matching the Windows-OOBE single-question-per-screen pattern
#     the person actually asked for, themed in KibaOS's own navy/glass
#     palette (matching gtk-3.0/gtk.css's colors elsewhere in this script).
#   - Backend: a single root bash script (kibaos-oobe-backend.sh), called
#     via pkexec. ALL partitioning/mkfs/chroot work lives there in plain
#     bash — auditable, no FFI, no Rust, reuses this script's own existing
#     conventions (systemd-boot/bootctl, mkinitcpio installed.conf hooks,
#     pacman group names) rather than introducing new ones.
# ══════════════════════════════════════════════════════════════════════════

mkdir -p /usr/share/kibaos-oobe/src
echo "=== Installing GTK4/libadwaita OOBE build dependencies ==="
pacman -S --noconfirm --needed gtk4 libadwaita libgee vala meson ninja rsync polkit gptfdisk arch-install-scripts dosfstools

# ── main.vala ────────────────────────────────────────────────────────────
cat > /usr/share/kibaos-oobe/src/main.vala << 'OOBEVALA'
/* KibaOS OOBE — GTK4 + libadwaita, white-card design language.
 * Backend: /usr/local/bin/kibaos-oobe-backend (Python/archinstall). */

using Gtk;
using Adw;
using Gee;

public struct OobeSummaryItem {
    public string icon;
    public string key;
    public string val;
}

public class KibaOOBE : Adw.Application {
    private Adw.ApplicationWindow window;
    private Adw.NavigationView    nav_view;
    private string selected_disk   = "";
    private string selected_locale = "en_US.UTF-8";
    private string selected_keymap = "us";
    private string hostname_value  = "kibaos";
    private string username_value  = "";
    private string password_value  = "";
    private bool   is_oem_mode     = false;
    private const string OEM_MARKER = "/etc/kibaos/oem-pending";

    // ── Helpers ────────────────────────────────────────────────────────
    private string strip_partition_suffix (string n) {
        string r = n;
        try {
            r = /[0-9]+$/.replace (r, -1, 0, "");
            if (r.has_prefix ("nvme")) r = /p$/.replace (r, -1, 0, "");
        } catch (GLib.RegexError e) {}
        return r;
    }

    private bool detect_already_on_computer () {
        if (GLib.FileUtils.test (OEM_MARKER, GLib.FileTest.EXISTS)) return true;
        string src = "";
        try { GLib.Process.spawn_command_line_sync (
                "findmnt -n -o SOURCE /run/archiso/bootmnt", out src); }
        catch (GLib.SpawnError e) { return false; }
        src = src.strip ();
        if (src == "") return false;
        string removable_path = "/sys/block/%s/removable".printf (
            strip_partition_suffix (GLib.Path.get_basename (src)));
        string removable_content = "";
        try { GLib.FileUtils.get_contents (removable_path, out removable_content); }
        catch (GLib.FileError e) { return false; }
        return removable_content.strip () == "0";
    }

    public KibaOOBE () {
        Object (application_id: "io.kibaos.oobe", flags: ApplicationFlags.FLAGS_NONE);
    }

    protected override void activate () {
        is_oem_mode = detect_already_on_computer ();
        window = new Adw.ApplicationWindow (this) {
            default_width  = 1280,
            default_height = 800,
            fullscreened   = true,
            title          = is_oem_mode ? "Finish Setting Up KibaOS" : "KibaOS Setup"
        };
        window.add_css_class ("kibaos-oobe-window");
        nav_view = new Adw.NavigationView ();
        window.set_content (nav_view);
        load_css ();
        nav_view.push (is_oem_mode ? build_locale_page () : build_welcome_page ());
        window.present ();
    }

    private void load_css () {
        var p = new Gtk.CssProvider ();
        p.load_from_path ("/usr/share/kibaos-oobe/oobe.css");
        Gtk.StyleContext.add_provider_for_display (
            Gdk.Display.get_default (), p, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
    }

    private delegate void NextAction ();

    // ── Page chrome ────────────────────────────────────────────────────
    // step_index / step_total drive the dot-indicator at the top of each card.
    private Adw.NavigationPage make_page (
            string title, Gtk.Widget content,
            string? next_label, NextAction? on_next,
            bool hide_back   = false,
            int  step_index  = 0,
            int  step_total  = 0) {

        // Outer overlay = full-screen canvas
        var root = new Gtk.Overlay ();
        root.add_css_class ("oobe-background");

        // Frosted card
        var card = new Gtk.Box (Gtk.Orientation.VERTICAL, 0) {
            halign = Gtk.Align.CENTER,
            valign = Gtk.Align.CENTER,
            width_request = 600
        };
        card.add_css_class ("oobe-card");

        // ── Step-dots (shown when step_total > 1) ──────────────────────
        if (step_total > 1) {
            var dots_row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6) {
                halign = Gtk.Align.CENTER,
                margin_bottom = 20
            };
            for (int i = 0; i < step_total; i++) {
                var dot = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0) {};
                dot.add_css_class ("oobe-step-dot");
                if (i == step_index) dot.add_css_class ("oobe-step-dot-active");
                dots_row.append (dot);
            }
            card.append (dots_row);
        }

        // Content + nav row wrapped in a box with padding
        var inner = new Gtk.Box (Gtk.Orientation.VERTICAL, 24);
        inner.add_css_class ("oobe-inner");
        inner.append (content);

        // Nav row
        var nav_row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 10) {
            halign = Gtk.Align.FILL,
            margin_top = 8
        };
        nav_row.add_css_class ("oobe-nav-row");

        // Spacer
        var spacer = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0) { hexpand = true };
        nav_row.append (spacer);

        if (!hide_back && nav_view.get_navigation_stack ().get_n_items () > 1) {
            var back_btn = new Gtk.Button.with_label ("Back");
            back_btn.add_css_class ("oobe-secondary-button");
            back_btn.clicked.connect (() => nav_view.pop ());
            nav_row.append (back_btn);
        }
        if (next_label != null) {
            var next_btn = new Gtk.Button.with_label (next_label);
            next_btn.add_css_class ("oobe-primary-button");
            if (on_next != null) {
                NextAction action = on_next;
                next_btn.clicked.connect (() => { action (); });
            }
            nav_row.append (next_btn);
        }
        inner.append (nav_row);
        card.append (inner);
        root.add_overlay (card);

        // KibaOS wordmark top-left
        var brand = new Gtk.Label ("KibaOS") {
            halign = Gtk.Align.START,
            valign = Gtk.Align.START,
            margin_start = 36,
            margin_top   = 32
        };
        brand.add_css_class ("oobe-brand");
        root.add_overlay (brand);

        return new Adw.NavigationPage (root, title);
    }

    // ── Heading ─────────────────────────────────────────────────────────
    private Gtk.Widget oobe_heading (string text, string? subtitle = null) {
        var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
        var label = new Gtk.Label (text);
        label.add_css_class ("oobe-title");
        label.halign = Gtk.Align.START;
        label.wrap   = true;
        box.append (label);
        if (subtitle != null) {
            var sub = new Gtk.Label (subtitle);
            sub.add_css_class ("oobe-subtitle");
            sub.halign = Gtk.Align.START;
            sub.wrap   = true;
            box.append (sub);
        }
        return box;
    }

    // ══════════════════════════════════════════════════════════════════
    // Page 1: Welcome
    // ══════════════════════════════════════════════════════════════════
    private Adw.NavigationPage build_welcome_page () {
        var content = new Gtk.Box (Gtk.Orientation.VERTICAL, 32);

        // Logo
        var logo = new Gtk.Image.from_file ("/usr/share/kibaos/logo-256.png") {
            pixel_size = 80,
            halign     = Gtk.Align.START
        };
        content.append (logo);

        content.append (oobe_heading ("Welcome to KibaOS",
            "Let's get your system set up. This should only take a few minutes."));

        return make_page ("Welcome", content, "Get Started", () => {
            nav_view.push (build_wifi_page ());
        }, true, 0, 0);
    }

    // ══════════════════════════════════════════════════════════════════
    // Page 2: Wi-Fi  (animated icon, network list)
    // ══════════════════════════════════════════════════════════════════
    private Adw.NavigationPage build_wifi_page () {
        var content = new Gtk.Box (Gtk.Orientation.VERTICAL, 24);

        // Animated Wi-Fi icon drawn on a DrawingArea
        var canvas = new Gtk.DrawingArea () {
            width_request  = 120,
            height_request = 120,
            halign         = Gtk.Align.CENTER
        };
        canvas.add_css_class ("oobe-wifi-canvas");

        // Animation tick state (boxed in an array so closures can capture it)
        double[] tick   = { 0.0 };   // 0..1 repeating
        double[] wiggle = { 0.0 };   // small side-sway for the playful bounce
        uint[]   src_id = { 0 };

        canvas.set_draw_func ((da, cr, w, h) => {
            double t      = tick[0];
            double cx     = w / 2.0;
            double cy     = h / 2.0 + 8;
            double r1     = 14.0, r2 = 26.0, r3 = 38.0;  // arc radii
            double sw     = 4.5;                           // stroke width

            // Arc opacity: arcs fade in from outer to inner as t grows
            double a3 = double.max (0, double.min (1, t * 3));
            double a2 = double.max (0, double.min (1, t * 3 - 0.6));
            double a1 = double.max (0, double.min (1, t * 3 - 1.2));

            // ── Outer arc ───────────────────────────────────────────────
            cr.set_line_width (sw);
            cr.set_line_cap (Cairo.LineCap.ROUND);
            cr.set_source_rgba (0.0, 0.60, 0.80, a3 * 0.85);
            double start_angle = Math.PI * (1.0 + 0.18);
            double end_angle   = Math.PI * (2.0 - 0.18);
            cr.arc (cx, cy, r3, start_angle, end_angle);
            cr.stroke ();

            // ── Middle arc ──────────────────────────────────────────────
            cr.set_source_rgba (0.0, 0.60, 0.80, a2 * 0.90);
            cr.arc (cx, cy, r2, start_angle, end_angle);
            cr.stroke ();

            // ── Inner arc ───────────────────────────────────────────────
            cr.set_source_rgba (0.0, 0.60, 0.80, a1 * 0.95);
            cr.arc (cx, cy, r1, start_angle, end_angle);
            cr.stroke ();

            // ── Dot + ripple ─────────────────────────────────────────────
            // dot phase: pulses from 0→1→0 at 1.2× speed
            double dp = (t * 1.4) % 1.0;
            // ripple ring expands outward and fades
            double rip_r = 6.0 + dp * 18.0;
            double rip_a = (1.0 - dp) * 0.55;

            // ripple circle
            cr.set_source_rgba (0.0, 0.60, 0.80, rip_a);
            cr.set_line_width (2.0);
            cr.arc (cx, cy + r3 - 2.0 + wiggle[0] * 3.0, rip_r, 0, 2 * Math.PI);
            cr.stroke ();

            // solid dot
            cr.set_source_rgba (0.0, 0.60, 0.80, 1.0);
            cr.arc (cx, cy + r3 - 2.0 + wiggle[0] * 3.0, 5.5, 0, 2 * Math.PI);
            cr.fill ();
        });

        // Tick function driving the animation (60 fps)
        src_id[0] = GLib.Timeout.add (16, () => {
            tick[0]   = (tick[0] + 0.012) % 1.0;
            wiggle[0] = Math.sin (tick[0] * Math.PI * 6.0) * 0.4;
            canvas.queue_draw ();
            return GLib.Source.CONTINUE;
        });

        // Stop animation when widget is destroyed
        canvas.destroy.connect (() => {
            if (src_id[0] != 0) { GLib.Source.remove (src_id[0]); src_id[0] = 0; }
        });

        content.append (canvas);
        content.append (oobe_heading ("Connect to Wi-Fi",
            "Choose a network to continue. You can also skip this step."));

        // Network list — populated via nmcli
        var list_box = new Gtk.ListBox ();
        list_box.add_css_class ("oobe-list");
        list_box.selection_mode = Gtk.SelectionMode.SINGLE;

        // Scan for networks (best-effort; if nmcli is absent, show a note)
        string raw_nets = "";
        try {
            GLib.Process.spawn_command_line_sync (
                "nmcli -t -f SSID,SIGNAL,SECURITY dev wifi list", out raw_nets);
        } catch (GLib.SpawnError e) {}

        var seen = new Gee.HashSet<string> ();
        bool any = false;
        foreach (var line in raw_nets.split ("\n")) {
            var parts = line.strip ().split (":", 3);
            if (parts.length < 2) continue;
            string ssid = parts[0].strip ();
            if (ssid == "" || ssid == "--" || seen.contains (ssid)) continue;
            seen.add (ssid);
            string signal   = parts.length > 1 ? parts[1] : "";
            bool   secured  = parts.length > 2 && parts[2] != "" && parts[2] != "--";
            string icon_name = secured ? "network-wireless-signal-good-symbolic"
                                       : "network-wireless-signal-good-symbolic";
            var row = new Adw.ActionRow () {
                title    = ssid,
                subtitle = "%s%%".printf (signal)
            };
            row.add_prefix (new Gtk.Image.from_icon_name (icon_name));
            if (secured) row.add_suffix (new Gtk.Image.from_icon_name ("system-lock-screen-symbolic"));
            list_box.append (row);
            any = true;
        }
        if (!any) {
            var row = new Adw.ActionRow () { title = "No networks found nearby" };
            row.add_prefix (new Gtk.Image.from_icon_name ("network-offline-symbolic"));
            list_box.append (row);
        }
        content.append (list_box);

        return make_page ("Wi-Fi", content, "Next", () => {
            nav_view.push (build_locale_page ());
        }, false, 1, 6);
    }

    // ══════════════════════════════════════════════════════════════════
    // Page 3: Locale + Keyboard
    // ══════════════════════════════════════════════════════════════════
    private Adw.NavigationPage build_locale_page () {
        var content = new Gtk.Box (Gtk.Orientation.VERTICAL, 20);
        content.append (oobe_heading ("Language & Keyboard",
            "Choose how KibaOS should communicate with you."));

        var locale_row = new Adw.ComboRow () { title = "Language" };
        var locale_model = new Gtk.StringList (null);
        string[] locales = {
            "en_US.UTF-8", "en_GB.UTF-8", "de_DE.UTF-8",
            "fr_FR.UTF-8", "es_ES.UTF-8", "ja_JP.UTF-8", "zh_CN.UTF-8"
        };
        foreach (var l in locales) locale_model.append (l);
        locale_row.set_model (locale_model);
        locale_row.notify["selected"].connect (() => {
            selected_locale = locales[locale_row.get_selected ()];
        });
        content.append (locale_row);

        var keymap_row = new Adw.ComboRow () { title = "Keyboard layout" };
        var keymap_model = new Gtk.StringList (null);
        string[] keymaps = { "us", "uk", "de", "fr", "es", "jp", "dvorak" };
        foreach (var k in keymaps) keymap_model.append (k);
        keymap_row.set_model (keymap_model);
        keymap_row.notify["selected"].connect (() => {
            selected_keymap = keymaps[keymap_row.get_selected ()];
        });
        content.append (keymap_row);

        return make_page ("Language", content, "Next", () => {
            if (is_oem_mode) nav_view.push (build_account_page ());
            else advance_past_storage_step ();
        }, false, 2, 6);
    }

    // ══════════════════════════════════════════════════════════════════
    // Storage detection helpers
    // ══════════════════════════════════════════════════════════════════
    private string boot_device_basename () {
        string s = "";
        try { GLib.Process.spawn_command_line_sync (
                "findmnt -n -o SOURCE /run/archiso/bootmnt", out s); }
        catch (GLib.SpawnError e) {}
        return strip_partition_suffix (GLib.Path.get_basename (s.strip ()));
    }

    private class StorageOption {
        public string devpath;
        public string label;
    }

    private Gee.ArrayList<StorageOption> list_storage_options () {
        var options  = new Gee.ArrayList<StorageOption> ();
        string boot_dev = boot_device_basename ();
        string raw = "";
        try { GLib.Process.spawn_command_line_sync (
                "lsblk -dpno NAME,SIZE,MODEL,RM -e7,11", out raw); }
        catch (GLib.SpawnError e) { return options; }

        foreach (var line in raw.split ("\n")) {
            var trimmed = line.strip ();
            if (trimmed == "") continue;
            var parts   = trimmed.split (" ", 2);
            string devpath = parts[0];
            string rest    = parts.length > 1 ? parts[1].strip () : "";
            if (rest.has_suffix (" 1") || rest == "1") continue;
            if (GLib.Path.get_basename (devpath) == boot_dev) continue;
            string label = rest;
            try { label = /\s+[01]$/.replace (label, -1, 0, ""); }
            catch (GLib.RegexError e) {}
            var opt  = new StorageOption ();
            opt.devpath = devpath;
            opt.label   = "Your computer's storage (%s)".printf (
                label == "" ? "internal drive" : label);
            options.add (opt);
        }
        return options;
    }

    private void advance_past_storage_step () {
        var options = list_storage_options ();
        if (options.size <= 1) {
            selected_disk = options.size == 1 ? options[0].devpath : "";
            nav_view.push (build_account_page ());
        } else {
            nav_view.push (build_storage_picker_page (options));
        }
    }

    // ══════════════════════════════════════════════════════════════════
    // Page 4: Storage picker (only shown with 2+ drives)
    // ══════════════════════════════════════════════════════════════════
    private Adw.NavigationPage build_storage_picker_page (Gee.ArrayList<StorageOption> options) {
        var content = new Gtk.Box (Gtk.Orientation.VERTICAL, 20);
        content.append (oobe_heading ("Where should KibaOS go?",
            "Your computer has more than one drive. Pick the one to set up."));

        var picker = new Gtk.ListBox ();
        picker.add_css_class ("oobe-list");
        picker.selection_mode = Gtk.SelectionMode.SINGLE;

        foreach (var opt in options) {
            var row = new Adw.ActionRow () { title = opt.label };
            row.add_prefix (new Gtk.Image.from_icon_name ("drive-harddisk-symbolic"));
            row.set_data ("devpath", opt.devpath);
            picker.append (row);
        }
        picker.row_selected.connect ((row) => {
            if (row != null) selected_disk = row.get_data<string> ("devpath");
        });
        if (options.size > 0) {
            selected_disk = options[0].devpath;
            picker.select_row (picker.get_row_at_index (0));
        }
        content.append (picker);

        return make_page ("Storage", content, "Next", () => {
            nav_view.push (build_account_page ());
        }, false, 3, 6);
    }

    // ══════════════════════════════════════════════════════════════════
    // Page 5: Account creation
    // ══════════════════════════════════════════════════════════════════
    private Adw.NavigationPage build_account_page () {
        var content = new Gtk.Box (Gtk.Orientation.VERTICAL, 16);
        content.append (oobe_heading ("Create Your Account",
            "This is the account you'll use every day."));

        var group = new Adw.PreferencesGroup ();
        group.add_css_class ("oobe-prefs-group");

        var hostname_entry = new Adw.EntryRow () { title = "Computer name" };
        hostname_entry.text = "kibaos";
        hostname_entry.changed.connect (() => { hostname_value = hostname_entry.text; });
        group.add (hostname_entry);

        var user_entry = new Adw.EntryRow () { title = "Username" };
        user_entry.changed.connect (() => { username_value = user_entry.text; });
        group.add (user_entry);

        var pass_entry = new Adw.PasswordEntryRow () { title = "Password" };
        pass_entry.changed.connect (() => { password_value = pass_entry.text; });
        group.add (pass_entry);

        content.append (group);

        return make_page ("Account", content,
            is_oem_mode ? "Finish Setup" : "Next", () => {
                if (is_oem_mode) {
                    nav_view.push (build_installing_page ());
                    start_oem_finish ();
                } else {
                    nav_view.push (build_confirm_page ());
                }
            }, false, 4, 6);
    }

    // ══════════════════════════════════════════════════════════════════
    // Page 6: Confirm
    // ══════════════════════════════════════════════════════════════════
    private Adw.NavigationPage build_confirm_page () {
        var content = new Gtk.Box (Gtk.Orientation.VERTICAL, 20);
        content.append (oobe_heading ("Ready to Set Up KibaOS",
            "Everything on your computer will be replaced. " +
            "Make sure anything important is backed up first."));

        // Summary card
        var summary = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        summary.add_css_class ("oobe-summary-box");

        OobeSummaryItem[] items = {
            { "drive-harddisk-symbolic",   "Storage",  selected_disk == "" ? "Auto-detected" : selected_disk },
            { "preferences-desktop-locale-symbolic", "Language", selected_locale },
            { "input-keyboard-symbolic",   "Keyboard", selected_keymap },
            { "system-users-symbolic",     "Account",  username_value == "" ? "(not set)" : username_value }
        };
        bool first = true;
        foreach (var item in items) {
            if (!first) {
                var sep = new Gtk.Separator (Gtk.Orientation.HORIZONTAL);
                sep.add_css_class ("oobe-summary-sep");
                summary.append (sep);
            }
            first = false;
            var row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12);
            row.add_css_class ("oobe-summary-row");
            row.append (new Gtk.Image.from_icon_name (item.icon));
            var lbl = new Gtk.Label (item.key);
            lbl.add_css_class ("oobe-summary-key");
            row.append (lbl);
            var spacer = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0) { hexpand = true };
            row.append (spacer);
            var val = new Gtk.Label (item.val);
            val.add_css_class ("oobe-summary-val");
            row.append (val);
            summary.append (row);
        }
        content.append (summary);

        return make_page ("Confirm", content, "Install KibaOS", () => {
            nav_view.push (build_installing_page ());
            start_install ();
        }, false, 5, 6);
    }

    // ══════════════════════════════════════════════════════════════════
    // Page 7: Installing
    // ══════════════════════════════════════════════════════════════════
    private Gtk.Label      progress_label;
    private Gtk.ProgressBar progress_bar;

    private Adw.NavigationPage build_installing_page () {
        var content = new Gtk.Box (Gtk.Orientation.VERTICAL, 20);
        content.append (oobe_heading ("Installing KibaOS",
            "Sit tight — this won't take long."));

        progress_bar = new Gtk.ProgressBar () { show_text = false };
        progress_bar.add_css_class ("oobe-progress");
        content.append (progress_bar);

        progress_label = new Gtk.Label ("Preparing…");
        progress_label.add_css_class ("oobe-subtitle");
        content.append (progress_label);

        return make_page ("Installing", content, null, null, true);
    }

    // ══════════════════════════════════════════════════════════════════
    // Page 8: Done
    // ══════════════════════════════════════════════════════════════════
    private Adw.NavigationPage build_done_page () {
        var content = new Gtk.Box (Gtk.Orientation.VERTICAL, 20);

        var check = new Gtk.Image.from_icon_name ("emblem-ok-symbolic") {
            pixel_size = 56,
            halign     = Gtk.Align.START
        };
        check.add_css_class ("oobe-done-check");
        content.append (check);

        content.append (oobe_heading ("You're all set.",
            "KibaOS is installed and ready. Restart your computer to get started."));

        return make_page ("Done", content, "Restart Now", () => {
            try { GLib.Process.spawn_command_line_async ("systemctl reboot"); }
            catch (GLib.SpawnError e) { warning ("Reboot failed: %s", e.message); }
        }, true);
    }

    // ══════════════════════════════════════════════════════════════════
    // Backend plumbing
    // ══════════════════════════════════════════════════════════════════
    private void start_oem_finish () {
        string cmd = "pkexec /usr/local/bin/kibaos-oem-finish.sh '%s' '%s' '%s' '%s' '%s'".printf (
            selected_locale, selected_keymap, hostname_value,
            username_value, password_value);
        launch_backend (cmd);
    }

    private void start_install () {
        string cmd = "pkexec /usr/local/bin/kibaos-oobe-backend '%s' '%s' '%s' '%s' '%s' '%s'".printf (
            selected_disk, selected_locale, selected_keymap,
            hostname_value, username_value, password_value);
        launch_backend (cmd);
    }

    private void launch_backend (string cmd) {
        try {
            string[] argv;
            GLib.Shell.parse_argv (cmd, out argv);
            var launcher = new GLib.SubprocessLauncher (GLib.SubprocessFlags.STDOUT_PIPE);
            var proc     = launcher.spawnv (argv);
            read_backend_output.begin (
                new GLib.DataInputStream (proc.get_stdout_pipe ()), proc);
        } catch (GLib.Error e) {
            progress_label.label = "Failed to start: %s".printf (e.message);
        }
    }

    private async void read_backend_output (GLib.DataInputStream stream, GLib.Subprocess proc) {
        try {
            while (true) {
                string? line = yield stream.read_line_async ();
                if (line == null) break;
                if (line.has_prefix ("PROGRESS ")) {
                    var parts = line.substring (9).split (" ", 2);
                    int    pct = int.parse (parts[0]);
                    string msg = parts.length > 1 ? parts[1] : "";
                    progress_bar.fraction = pct / 100.0;
                    progress_label.label  = msg;
                }
            }
            yield proc.wait_async ();
            if (proc.get_exit_status () == 0) {
                nav_view.push (build_done_page ());
            } else {
                progress_label.label =
                    "Something went wrong. Check /var/log/kibaos-oobe.log for details.";
            }
        } catch (GLib.Error e) {
            progress_label.label = "Lost connection to installer: %s".printf (e.message);
        }
    }

    public static int main (string[] args) {
        return new KibaOOBE ().run (args);
    }
}

OOBEVALA

# ── meson build files ─────────────────────────────────────────────────────
cat > /usr/share/kibaos-oobe/src/meson.build << 'OOBEMESON'
project('kibaos-oobe', 'vala', 'c', version: '1.0')

gtk4_dep = dependency('gtk4')
adwaita_dep = dependency('libadwaita-1')
gee_dep = dependency('gee-0.8')

executable(
  'io.kibaos.oobe',
  'main.vala',
  dependencies: [gtk4_dep, adwaita_dep, gee_dep],
  install: true
)
OOBEMESON

# ── CSS theme ──────────────────────────────────────────────────────────────
cat > /usr/share/kibaos-oobe/oobe.css << 'OOBECSS'
/* ═══════════════════════════════════════════════════════════════════════
 * KibaOS OOBE — white-card design language, image 2 inspiration.
 * Timing functions:
 *   settle  cubic-bezier(0.22, 1, 0.36, 1)   easeOutQuint, enter
 *   fade    cubic-bezier(0.5,  0, 0.75, 0)   easeInQuart,  leave
 *   spring  cubic-bezier(0.34, 1.56, 0.64, 1) gentle overshoot
 * ═══════════════════════════════════════════════════════════════════════ */

/* ── Window / background ───────────────────────────────────────────────── */
window.kibaos-oobe-window { background: transparent; }

.oobe-background {
    background: linear-gradient(160deg,
        rgba(180,210,240,0.55) 0%,
        rgba(220,235,250,0.40) 50%,
        rgba(200,220,245,0.55) 100%);
    /* Blurred wallpaper shows through — the card pops as the focal point */
}

/* ── Brand wordmark ────────────────────────────────────────────────────── */
.oobe-brand {
    font-size: 15px;
    font-weight: 700;
    letter-spacing: 0.5px;
    color: rgba(255,255,255,0.85);
    text-shadow: 0 1px 3px rgba(0,0,0,0.25);
}

/* ── Card ──────────────────────────────────────────────────────────────── */
.oobe-card {
    background:    rgba(255,255,255,0.88);
    border:        1px solid rgba(255,255,255,0.70);
    border-radius: 28px;
    box-shadow:
        0 2px 4px  rgba(0,0,0,0.04),
        0 8px 24px rgba(0,0,0,0.10),
        0 32px 64px rgba(0,0,0,0.12);
    backdrop-filter: blur(40px) saturate(1.8);
    -webkit-backdrop-filter: blur(40px) saturate(1.8);
    animation: card-in 460ms cubic-bezier(0.22, 1, 0.36, 1) both;
}

@keyframes card-in {
    from { opacity: 0; transform: translateY(22px) scale(0.97); }
    to   { opacity: 1; transform: translateY(0)    scale(1);    }
}

/* Inner padding */
.oobe-inner {
    padding: 40px 44px 36px;
}

/* ── Step dots ─────────────────────────────────────────────────────────── */
.oobe-step-dot {
    min-width:     7px;
    min-height:    7px;
    border-radius: 999px;
    background:    rgba(0,0,0,0.15);
    transition: all 300ms cubic-bezier(0.22, 1, 0.36, 1);
}
.oobe-step-dot-active {
    min-width:  22px;
    background: #0099cc;
}

/* ── Nav row ───────────────────────────────────────────────────────────── */
.oobe-nav-row { margin-top: 4px; }

/* ── Typography ────────────────────────────────────────────────────────── */
.oobe-title {
    font-size:      26px;
    font-weight:    650;
    color:          #0f172a;
    letter-spacing: -0.4px;
    margin-bottom:  2px;
    animation: fade-up 380ms cubic-bezier(0.22, 1, 0.36, 1) 60ms both;
}
.oobe-subtitle {
    font-size:   14px;
    color:       #64748b;
    line-height: 1.55;
    animation:   fade-up 380ms cubic-bezier(0.22, 1, 0.36, 1) 100ms both;
}
@keyframes fade-up {
    from { opacity: 0; transform: translateY(7px); }
    to   { opacity: 1; transform: translateY(0);   }
}

/* ── Wi-Fi canvas ──────────────────────────────────────────────────────── */
.oobe-wifi-canvas {
    animation: scale-in 500ms cubic-bezier(0.34, 1.56, 0.64, 1) 80ms both;
}
@keyframes scale-in {
    from { opacity: 0; transform: scale(0.6); }
    to   { opacity: 1; transform: scale(1);   }
}

/* ── List / pickers ────────────────────────────────────────────────────── */
.oobe-list { background: transparent; }

.oobe-list row,
listview > row {
    background:    rgba(248,250,252,0.9);
    border:        1px solid rgba(0,0,0,0.07);
    border-radius: 14px;
    margin:        3px 0;
    padding:       10px 14px;
    color:         #1e293b;
    transition:
        background-color 180ms cubic-bezier(0.22, 1, 0.36, 1),
        border-color     180ms cubic-bezier(0.22, 1, 0.36, 1),
        box-shadow       180ms cubic-bezier(0.22, 1, 0.36, 1),
        transform        180ms cubic-bezier(0.22, 1, 0.36, 1);
}
.oobe-list row:hover { background: #f0f9ff; border-color: rgba(0,153,204,0.28); }
.oobe-list row:selected {
    background: rgba(0,153,204,0.10);
    border-color: rgba(0,153,204,0.55);
    box-shadow: 0 0 0 3px rgba(0,153,204,0.14);
}

/* ── Preferences group (account page) ─────────────────────────────────── */
.oobe-prefs-group {
    border-radius: 16px;
    overflow: hidden;
}

/* ── Summary box (confirm page) ────────────────────────────────────────── */
.oobe-summary-box {
    background:    rgba(248,250,252,0.9);
    border:        1px solid rgba(0,0,0,0.07);
    border-radius: 16px;
    overflow:      hidden;
    margin-top:    8px;
}
.oobe-summary-row {
    padding: 13px 18px;
}
.oobe-summary-sep {
    margin: 0 18px;
    opacity: 0.5;
}
.oobe-summary-key {
    font-size:   13px;
    font-weight: 600;
    color:       #475569;
}
.oobe-summary-val {
    font-size: 13px;
    color:     #0f172a;
}

/* ── Done check icon ───────────────────────────────────────────────────── */
.oobe-done-check {
    color: #0099cc;
    animation: pop-in 500ms cubic-bezier(0.34, 1.56, 0.64, 1) both;
}
@keyframes pop-in {
    from { opacity: 0; transform: scale(0.4); }
    to   { opacity: 1; transform: scale(1);   }
}

/* ── Buttons ───────────────────────────────────────────────────────────── */
.oobe-primary-button {
    background:    #0099cc;
    color:         #ffffff;
    border:        none;
    border-radius: 999px;
    padding:       11px 28px;
    font-weight:   650;
    font-size:     14px;
    box-shadow:    0 1px 3px rgba(0,153,204,0.35);
    transition:
        background-color 140ms cubic-bezier(0.22, 1, 0.36, 1),
        box-shadow       140ms cubic-bezier(0.22, 1, 0.36, 1),
        transform        120ms cubic-bezier(0.22, 1, 0.36, 1);
}
.oobe-primary-button:hover {
    background: #00aee3;
    box-shadow: 0 4px 14px rgba(0,153,204,0.40);
    transform:  translateY(-1px);
}
.oobe-primary-button:active {
    background:        #0088b8;
    transform:         translateY(0);
    box-shadow:        0 1px 3px rgba(0,153,204,0.20);
    transition-duration: 70ms;
}

.oobe-secondary-button {
    background:    transparent;
    color:         #475569;
    border:        1px solid rgba(0,0,0,0.14);
    border-radius: 999px;
    padding:       11px 24px;
    font-size:     14px;
    transition:
        background-color 140ms cubic-bezier(0.22, 1, 0.36, 1),
        border-color     140ms cubic-bezier(0.22, 1, 0.36, 1);
}
.oobe-secondary-button:hover  { background: #f1f5f9; border-color: rgba(0,0,0,0.22); }
.oobe-secondary-button:active { background: #e2e8f0; transition-duration: 70ms; }

/* ── Progress bar ──────────────────────────────────────────────────────── */
.oobe-progress { min-height: 6px; border-radius: 999px; }
.oobe-progress trough {
    background:    #e2e8f0;
    border-radius: 999px;
    min-height:    6px;
}
.oobe-progress progress {
    background:  linear-gradient(90deg, #0099cc, #00c4f0);
    border-radius: 999px;
    transition:  all 450ms cubic-bezier(0.22, 1, 0.36, 1);
}

/* ── Form entries ──────────────────────────────────────────────────────── */
entry, row.entry, .oobe-prefs-group entry {
    background:  rgba(248,250,252,0.9);
    border:      1px solid rgba(0,0,0,0.10);
    border-radius: 10px;
    color:       #0f172a;
    transition:
        border-color     160ms cubic-bezier(0.22, 1, 0.36, 1),
        background-color 160ms cubic-bezier(0.22, 1, 0.36, 1),
        box-shadow       160ms cubic-bezier(0.22, 1, 0.36, 1);
}
entry:focus-within, row.entry:focus-within {
    border-color: #0099cc;
    background:   #ffffff;
    box-shadow:   0 0 0 3px rgba(0,153,204,0.18);
}

/* ── ComboRow / ActionRow (Adwaita overrides) ──────────────────────────── */
row.combo, row.action {
    border-radius: 12px;
    background:    rgba(248,250,252,0.9);
}

OOBECSS

# ── Watermark icon: reuse the existing KibaOS logo as the symbolic
# watermark rather than generating a separate asset — same K-mark already
# used for the panel/branding elsewhere in this build. ────────────────────
mkdir -p /usr/share/icons/hicolor/scalable/actions
cp /usr/share/kibaos/logo-256.png /usr/share/icons/hicolor/scalable/actions/kibaos-watermark-symbolic.png 2>/dev/null || true
gtk-update-icon-cache /usr/share/icons/hicolor/ 2>/dev/null || true

# ── Build the OOBE app ─────────────────────────────────────────────────────
echo "=== Building KibaOS OOBE installer ==="
cd /usr/share/kibaos-oobe/src
meson setup build --prefix=/usr || { echo "FATAL: meson setup failed for kibaos-oobe — check vala/gtk4/libadwaita dev package availability." >&2; exit 1; }
ninja -C build || { echo "FATAL: ninja build failed for kibaos-oobe — check the Vala compile errors above." >&2; exit 1; }
ninja -C build install
cd /

# ── Privileged backend script ─────────────────────────────────────────────
cat > /usr/local/bin/kibaos-oobe-backend << 'OOBEBACKEND'
#!/usr/bin/env python3
# KibaOS OOBE backend
# Strategy:
#   1. archinstall for partition layout + formatting + bootloader
#   2. rsync the live squashfs onto the new root (preserves ALL KibaOS customisations)
#   3. chroot to configure locale/keymap/hostname/user
#   4. Remove live-only artefacts (installer, liveuser, autologin, squashfs tools)
#   5. Enable services, rebuild initramfs
#
# Emits "PROGRESS <0-100> <message>" to stdout; everything else -> log file.
import sys, subprocess as sp, pathlib, traceback, shutil, os, tempfile

LOG = pathlib.Path("/var/log/kibaos-oobe.log")
LOG.parent.mkdir(parents=True, exist_ok=True)
log_fh = open(LOG, "a")

def tee(msg):
    print(msg, flush=True)
    print(msg, file=log_fh, flush=True)

def progress(pct, msg):
    tee(f"PROGRESS {pct} {msg}")

def fail(msg):
    progress(100, f"Install failed: {msg}")
    tee(f"FATAL: {msg}")
    sys.exit(1)

def run(cmd, **kw):
    """Run a command, log it, raise on non-zero exit."""
    tee(f"  $ {' '.join(cmd) if isinstance(cmd, list) else cmd}")
    r = sp.run(cmd, capture_output=True, text=True, **kw)
    if r.stdout: tee(r.stdout.rstrip())
    if r.stderr: tee(r.stderr.rstrip())
    if r.returncode != 0:
        raise RuntimeError(f"Command failed (exit {r.returncode}): {cmd}")
    return r

def chroot(cmd_list):
    """arch-chroot into MNT and run a command."""
    run(["arch-chroot", str(MNT)] + cmd_list)

sys.stderr = log_fh

if len(sys.argv) < 7:
    fail("Usage: backend <disk> <locale> <keymap> <hostname> <username> <password>")

DISK     = sys.argv[1]
LOCALE   = sys.argv[2]   # e.g. en_US.UTF-8
KEYMAP   = sys.argv[3]   # e.g. us
HOSTNAME = sys.argv[4]
USERNAME = sys.argv[5]
PASSWORD = sys.argv[6]
MNT      = pathlib.Path("/mnt/kibaos-install")

if not DISK:
    fail("no disk selected")
if not pathlib.Path(DISK).is_block_device():
    fail(f"{DISK} is not a block device")

# ── 1. Import archinstall ────────────────────────────────────────────────
progress(2, "Loading installer library…")
try:
    from archinstall.lib.disk.device_handler import device_handler
    from archinstall.lib.disk.filesystem import FilesystemHandler
    from archinstall.lib.models.device import (
        DeviceModification, DiskLayoutConfiguration, DiskLayoutType,
        FilesystemType, ModificationStatus, PartitionFlag,
        PartitionModification, PartitionType, Size, Unit,
    )
except ImportError as e:
    fail(f"archinstall not available: {e}")

# ── 2. Clear stale mounts ────────────────────────────────────────────────
progress(5, "Clearing previous mounts…")
try:
    parts = sp.check_output(
        ["lsblk", "-rpno", "NAME", DISK], text=True
    ).strip().splitlines()[1:]
    for p in reversed(parts):
        sp.run(["umount", "-f", p], capture_output=True)
        sp.run(["swapoff", p],       capture_output=True)
    sp.run(["umount", "-R", str(MNT)], capture_output=True)
except Exception:
    pass

# ── 3. Partition + format via archinstall ────────────────────────────────
progress(8, "Setting up partitions…")
try:
    device = device_handler.get_device(pathlib.Path(DISK))
    if not device:
        fail(f"archinstall could not open {DISK}")

    sector = device.device_info.sector_size
    dev_mod = DeviceModification(device, wipe=True)

    boot_part = PartitionModification(
        status     = ModificationStatus.Create,
        type       = PartitionType.Primary,
        start      = Size(1,   Unit.MiB, sector),
        length     = Size(512, Unit.MiB, sector),
        mountpoint = pathlib.Path("/boot"),
        fs_type    = FilesystemType.Fat32,
        flags      = [PartitionFlag.BOOT],
    )
    dev_mod.add_partition(boot_part)

    root_part = PartitionModification(
        status     = ModificationStatus.Create,
        type       = PartitionType.Primary,
        start      = Size(513, Unit.MiB, sector),
        length     = device.device_info.total_size - Size(513, Unit.MiB, sector),
        mountpoint = pathlib.Path("/"),
        fs_type    = FilesystemType("ext4"),
    )
    dev_mod.add_partition(root_part)

    disk_config = DiskLayoutConfiguration(
        config_type          = DiskLayoutType.Default,
        device_modifications = [dev_mod],
    )
    FilesystemHandler(disk_config).perform_filesystem_operations()
except Exception as e:
    fail(f"Partition/format failed: {e}\n{traceback.format_exc()}")

# ── 4. Mount the new root ────────────────────────────────────────────────
progress(14, "Mounting target filesystem…")
try:
    # Determine partition device paths (nvme uses p1/p2, sata uses 1/2)
    if "nvme" in DISK or "mmcblk" in DISK:
        ESP_PART  = DISK + "p1"
        ROOT_PART = DISK + "p2"
    else:
        ESP_PART  = DISK + "1"
        ROOT_PART = DISK + "2"

    MNT.mkdir(parents=True, exist_ok=True)
    run(["mount", ROOT_PART, str(MNT)])
    (MNT / "boot").mkdir(parents=True, exist_ok=True)
    run(["mount", ESP_PART, str(MNT / "boot")])
except Exception as e:
    fail(f"Mount failed: {e}\n{traceback.format_exc()}")

# ── 5. Find the live squashfs ────────────────────────────────────────────
progress(18, "Locating KibaOS system image…")
SQUASHFS_CANDIDATES = [
    "/run/archiso/bootmnt/arch/x86_64/airootfs.sfs",
    "/run/archiso/bootmnt/arch/x86_64/airootfs.erofs",
    "/run/mnt/arch/x86_64/airootfs.sfs",
]
SQUASHFS_SRC = None
for c in SQUASHFS_CANDIDATES:
    if pathlib.Path(c).exists():
        SQUASHFS_SRC = c
        break
if not SQUASHFS_SRC:
    # Last resort: find it
    r = sp.run(["find", "/run", "-name", "airootfs.sfs", "-o", "-name", "airootfs.erofs"],
               capture_output=True, text=True)
    for line in r.stdout.strip().splitlines():
        if line:
            SQUASHFS_SRC = line.strip()
            break
if not SQUASHFS_SRC:
    fail("Could not locate the KibaOS system image (airootfs.sfs). "
         "Make sure you're booted from the KibaOS live USB.")

tee(f"  squashfs: {SQUASHFS_SRC}")

# ── 6. Mount squashfs and rsync to new root ──────────────────────────────
progress(22, "Copying KibaOS to your computer (this takes a few minutes)…")
SQMNT = pathlib.Path(tempfile.mkdtemp(prefix="kibaos-sq-"))
try:
    fs_type = "squashfs" if SQUASHFS_SRC.endswith(".sfs") else "erofs"
    run(["mount", "-t", fs_type, "-o", "loop,ro", SQUASHFS_SRC, str(SQMNT)])
except Exception as e:
    fail(f"Could not mount system image: {e}")

try:
    # rsync with progress — parse % for the UI
    proc = sp.Popen(
        [
            "rsync", "-aHAX",
            "--info=progress2",
            "--exclude=/run/*",
            "--exclude=/proc/*",
            "--exclude=/sys/*",
            "--exclude=/dev/*",
            "--exclude=/tmp/*",
            "--exclude=/home/liveuser",           # live session home
            "--exclude=/root/.bash_history",
            str(SQMNT) + "/",
            str(MNT) + "/",
        ],
        stdout=sp.PIPE, stderr=log_fh, text=True
    )
    for line in proc.stdout:
        line = line.rstrip()
        if not line:
            continue
        tee(line)
        # parse "  1,234,567  42%  12.34MB/s    0:00:05"
        import re
        m = re.search(r'(\d+)%', line)
        if m:
            pct = int(m.group(1))
            progress(22 + pct * 48 // 100, f"Copying files… {pct}%")
    proc.wait()
    if proc.returncode not in (0, 23, 24):   # 23/24 = partial/vanished (ok)
        fail(f"rsync exited with code {proc.returncode}")
except Exception as e:
    fail(f"File copy failed: {e}\n{traceback.format_exc()}")
finally:
    sp.run(["umount", str(SQMNT)], capture_output=True)
    SQMNT.rmdir()

progress(72, "Finalising system…")

# ── 7. Bind-mount kernel filesystems for chroot ──────────────────────────
for fs in ["proc", "sys", "dev"]:
    sp.run(["mount", "--rbind", f"/{fs}", str(MNT / fs)], capture_output=True)
    sp.run(["mount", "--make-rslave", str(MNT / fs)], capture_output=True)

try:
    # ── 8. fstab ────────────────────────────────────────────────────────
    progress(74, "Writing filesystem table…")
    root_uuid = sp.check_output(["blkid", "-s", "UUID", "-o", "value", ROOT_PART], text=True).strip()
    esp_uuid  = sp.check_output(["blkid", "-s", "UUID", "-o", "value", ESP_PART],  text=True).strip()
    (MNT / "etc/fstab").write_text(
        f"# KibaOS fstab — generated by installer\n"
        f"UUID={root_uuid}  /      ext4  defaults,noatime  0 1\n"
        f"UUID={esp_uuid}   /boot  vfat  umask=0077        0 2\n"
    )

    # ── 9. Hostname / hosts ──────────────────────────────────────────────
    (MNT / "etc/hostname").write_text(HOSTNAME + "\n")
    (MNT / "etc/hosts").write_text(
        f"127.0.0.1   localhost\n"
        f"::1         localhost\n"
        f"127.0.1.1   {HOSTNAME}.localdomain {HOSTNAME}\n"
    )

    # ── 10. Locale + keyboard ────────────────────────────────────────────
    progress(76, "Setting locale and keyboard…")
    locale_gen = MNT / "etc/locale.gen"
    if locale_gen.exists():
        text = locale_gen.read_text()
        text = text.replace(f"#{LOCALE}", LOCALE)
        locale_gen.write_text(text)
    (MNT / "etc/locale.conf").write_text(f"LANG={LOCALE}\n")
    (MNT / "etc/vconsole.conf").write_text(f"KEYMAP={KEYMAP}\n")
    chroot(["locale-gen"])

    # ── 11. Create user account ──────────────────────────────────────────
    progress(78, "Creating your account…")
    # Remove live autologin first
    for f in [
        MNT / "etc/sddm.conf.d/kibaos-live.conf",
        MNT / "etc/sddm.conf.d/autologin.conf",
    ]:
        f.unlink(missing_ok=True)

    chroot(["userdel", "-r", "liveuser"])   # best-effort; ignore if absent
    try:
        chroot([
            "useradd", "-m",
            "-G", "wheel,audio,video,input,network,storage,power",
            "-s", "/bin/bash",
            USERNAME,
        ])
    except RuntimeError:
        pass  # user may already exist from squashfs if somehow present

    # Set password via chpasswd
    proc = sp.run(
        ["arch-chroot", str(MNT), "chpasswd"],
        input=f"{USERNAME}:{PASSWORD}\n",
        capture_output=True, text=True
    )
    if proc.returncode != 0:
        fail(f"chpasswd failed: {proc.stderr}")

    # ── 12. Remove live-only and installer packages/files ────────────────
    progress(80, "Removing live-only tools…")
    # Files to remove from installed system
    live_only_paths = [
        # The installer itself
        MNT / "usr/share/applications/kibaos-install.desktop",
        MNT / "usr/bin/io.kibaos.oobe",
        MNT / "usr/share/kibaos-oobe",
        MNT / "usr/local/bin/kibaos-oobe-backend",
        MNT / "usr/local/bin/kibaos-oem-finish.sh",
        # archiso live-session leftovers
        MNT / "etc/systemd/system/getty@tty1.service.d",
        MNT / "etc/systemd/system/choose-mirror.service",
        MNT / "usr/share/libalpm/hooks/Installation_guide.hook",
        MNT / "root/customize_airootfs.sh",
        MNT / "root/install.txt",
        MNT / "etc/motd",                      # live MOTD
        MNT / "etc/issue",                     # live issue
    ]
    for p in live_only_paths:
        if p.is_dir():
            shutil.rmtree(p, ignore_errors=True)
        elif p.exists():
            p.unlink(missing_ok=True)

    # Remove archiso-specific packages if installed (squashfs-tools, mkinitcpio-archiso)
    chroot(["pacman", "-Rns", "--noconfirm",
            "archiso", "mkinitcpio-archiso", "squashfs-tools"])

    # Remove "Install KibaOS" from SDDM / app menu on the installed system
    sp.run(["arch-chroot", str(MNT),
            "update-desktop-database", "/usr/share/applications"],
           capture_output=True)

    # ── 13. Bootloader ───────────────────────────────────────────────────
    progress(84, "Installing bootloader…")
    chroot(["bootctl", "--esp-path=/boot", "install"])
    # Remove the Arch splash BMP that systemd-boot installs — it appears as
    # the bootloader logo and overrides our silent boot. Also remove systemd-boot's
    # own shipped loader.conf which sets "default arch" and can override ours.
    for f in [
        MNT / "boot/EFI/systemd/splash-arch.bmp",
        MNT / "usr/share/systemd/bootctl/splash-arch.bmp",
    ]:
        f.unlink(missing_ok=True)
    # Ensure our loader.conf wins — rewrite it after bootctl install
    (MNT / "boot/loader/loader.conf").write_text(
        "default kibaos.conf\n"
        "timeout 0\n"
        "console-mode max\n"
        "editor no\n"
        "auto-entries no\n"
    )

    # Patch the loader entry with the real PARTUUID
    root_partuuid = sp.check_output(
        ["blkid", "-s", "PARTUUID", "-o", "value", ROOT_PART], text=True
    ).strip()
    entry_path = MNT / "boot/loader/entries/kibaos.conf"
    if entry_path.exists():
        txt = entry_path.read_text()
        txt = txt.replace("PARTUUID=PLACEHOLDER", f"PARTUUID={root_partuuid}")
        entry_path.write_text(txt)
    else:
        # Write a sane fallback entry
        entry_path.parent.mkdir(parents=True, exist_ok=True)
        entry_path.write_text(
            "title   KibaOS\n"
            "linux   /vmlinuz-linux\n"
            "initrd  /initramfs-linux.img\n"
            f"options root=PARTUUID={root_partuuid} rw quiet splash loglevel=3 "
            "rd.udev.log_level=3 vt.global_cursor_default=0 "
            "clocksource=tsc tsc=reliable plymouth.use-simpledrm=1\n"
        )

    # Clear any stale EFI timeout/default variables
    sp.run(["arch-chroot", "-S", str(MNT), "bootctl", "set-timeout", ""], capture_output=True)
    sp.run(["arch-chroot", "-S", str(MNT), "bootctl", "set-default", ""], capture_output=True)

    # ── 14. Services ─────────────────────────────────────────────────────
    progress(88, "Enabling services…")
    for svc in [
        "NetworkManager", "sddm", "bluetooth",
        "systemd-timesyncd", "systemd-time-wait-sync",
    ]:
        sp.run(["arch-chroot", str(MNT), "systemctl", "enable", svc],
               capture_output=True)

    # ── 15. Plymouth theme ────────────────────────────────────────────────
    progress(91, "Applying boot theme…")
    ply_conf_dir = MNT / "etc/plymouth"
    ply_conf_dir.mkdir(parents=True, exist_ok=True)
    (ply_conf_dir / "plymouthd.conf").write_text(
        "[Daemon]\nTheme=kibaos\nShowDelay=0\nDeviceTimeout=8\n"
    )
    sp.run(["arch-chroot", str(MNT),
            "plymouth-set-default-theme", "kibaos"],
           capture_output=True)

    # ── 16. initramfs ────────────────────────────────────────────────────
    progress(94, "Rebuilding initramfs…")
    chroot([
        "mkinitcpio",
        "-c", "/etc/mkinitcpio.conf.d/installed.conf",
        "-g", "/boot/initramfs-linux.img",
    ])

    # ── 17. Wheel sudoers ────────────────────────────────────────────────
    sudoers = MNT / "etc/sudoers.d/wheel"
    sudoers.parent.mkdir(parents=True, exist_ok=True)
    sudoers.write_text("%wheel ALL=(ALL:ALL) ALL\n")
    sudoers.chmod(0o440)

except Exception as e:
    fail(f"Post-install configuration failed: {e}\n{traceback.format_exc()}")

finally:
    # ── 18. Unmount everything ───────────────────────────────────────────
    progress(98, "Cleaning up…")
    for fs in ["dev", "sys", "proc"]:
        sp.run(["umount", "-R", str(MNT / fs)], capture_output=True)
    sp.run(["umount", str(MNT / "boot")], capture_output=True)
    sp.run(["umount", str(MNT)],           capture_output=True)

progress(100, "Done")
sys.exit(0)
OOBEBACKEND
chmod +x /usr/local/bin/kibaos-oobe-backend
# Point polkit rule + Vala cmd at new backend (no .sh extension)
sed -i 's|/usr/local/bin/kibaos-oobe-backend\.sh|/usr/local/bin/kibaos-oobe-backend|g' \
    /usr/share/kibaos-oobe/src/main.vala 2>/dev/null || true


# ── kibaos-oem-finish.sh — lightweight OEM-mode completion backend.
# Runs on an ALREADY-INSTALLED system (imaged by an OEM before shipping —
# see kibaos-oem-prepare below for how that state is set), so there is no
# partitioning, no squashfs extraction, no bootloader install here at all.
# Just locale/keyboard, the real customer account, and removing the OEM
# marker + temporary OEM account. Mirrors the standard OEM-imaging pattern
# (locale/keyboard/account-only finish step, no disk work) used by
# installers like this one.
cat > /usr/local/bin/kibaos-oem-finish.sh << 'OEMFINISH'
#!/usr/bin/env bash
# Args: $1=locale $2=keymap $3=hostname $4=username $5=password
set -euo pipefail

LOCALE="$1"; KEYMAP="$2"; HOSTNAME_VAL="$3"; USERNAME_VAL="$4"; PASSWORD_VAL="$5"
LOG=/var/log/kibaos-oobe.log
exec > >(tee -a "${LOG}") 2>&1

progress() { echo "PROGRESS $1 $2"; }
fail() { progress 100 "Setup failed: $1"; echo "FATAL: $1" >&2; exit 1; }

[ -n "${USERNAME_VAL}" ] || fail "no username given"

progress 15 "Setting locale and keyboard..."
sed -i "s/#${LOCALE}/${LOCALE}/" /etc/locale.gen 2>/dev/null || true
echo "LANG=${LOCALE}" > /etc/locale.conf
echo "KEYMAP=${KEYMAP}" > /etc/vconsole.conf
locale-gen || fail "locale-gen failed"

progress 45 "Setting computer name..."
echo "${HOSTNAME_VAL}" > /etc/hostname
sed -i "s/127.0.1.1.*/127.0.1.1\t${HOSTNAME_VAL}.localdomain ${HOSTNAME_VAL}/" /etc/hosts 2>/dev/null || true

progress 65 "Creating your account..."
useradd -m -G wheel,audio,video,input,network,storage,power -s /bin/bash "${USERNAME_VAL}" \
  || fail "useradd failed"
echo "${USERNAME_VAL}:${PASSWORD_VAL}" | chpasswd || fail "chpasswd failed"

progress 85 "Cleaning up OEM account..."
# Remove the temporary OEM account created by kibaos-oem-prepare, if present.
userdel -r oem 2>/dev/null || true
rm -f /etc/sddm.conf.d/kibaos-oem-autologin.conf 2>/dev/null || true

progress 95 "Finishing up..."
rm -f /etc/kibaos/oem-pending

progress 100 "Done"
exit 0
OEMFINISH
chmod +x /usr/local/bin/kibaos-oem-finish.sh

# ── kibaos-oem-prepare — run by WHOEVER images a device for OEM delivery
# (not run on a normal end-user install). Creates a temporary autologin
# "oem" account so the imaged device boots straight to a usable desktop
# for OEM-side burn-in/testing, and drops the marker file that makes
# io.kibaos.oobe launch in OEM-finish mode on first real customer boot.
# This mirrors the standard dont-chroot-style OEM-mode pattern from
# Calamares-based distros, just implemented as a small script
# instead of an installer config file, consistent with the rest of this
# from-scratch installer. ─────────────────────────────────────────────────
cat > /usr/local/bin/kibaos-oem-prepare << 'OEMPREPARE'
#!/usr/bin/env bash
set -e
mkdir -p /etc/kibaos
touch /etc/kibaos/oem-pending

id oem &>/dev/null || useradd -m -G wheel,audio,video,input,network,storage,power -s /bin/bash oem
passwd -d oem 2>/dev/null || true

mkdir -p /etc/sddm.conf.d
cat > /etc/sddm.conf.d/kibaos-oem-autologin.conf << 'OEMAUTOLOGIN'
[Autologin]
User=oem
Session=budgie-desktop
OEMAUTOLOGIN

# OOBE app autostarts for the oem user too, in OEM-finish mode (the
# /etc/kibaos/oem-pending marker is what triggers that mode, not the
# username — the OOBE app itself doesn't know or care who's logged in).
echo "OEM mode prepared. This device will boot to a temporary 'oem' account"
echo "and prompt the customer to finish setup on next boot. Do not run this"
echo "on a normal end-user installation."
OEMPREPARE
chmod +x /usr/local/bin/kibaos-oem-prepare

# ── polkit rule: allow both backends to run via pkexec without a password
# prompt loop mid-install (the user already authenticates once via the
# account-creation step in the UI; this just lets pkexec itself proceed
# without re-prompting for the *root* password, which liveuser doesn't
# have set anyway — sudoers NOPASSWD already covers liveuser elsewhere
# in this build script). ───────────────────────────────────────────────────
mkdir -p /etc/polkit-1/rules.d
cat > /etc/polkit-1/rules.d/49-kibaos-oobe.rules << 'POLKITRULE'
polkit.addRule(function(action, subject) {
    if (action.id == "org.freedesktop.policykit.exec" &&
        (action.lookup("program") == "/usr/local/bin/kibaos-oobe-backend" ||
         action.lookup("program") == "/usr/local/bin/kibaos-oem-finish.sh") &&
        subject.isInGroup("wheel")) {
        return polkit.Result.YES;
    }
});
POLKITRULE

if [ -x /usr/bin/io.kibaos.oobe ]; then
  echo "=== KibaOS OOBE installer is the active install path ==="
else
  echo "=== WARNING: KibaOS OOBE installer binary not found post-build ===" >&2
  exit 1
fi

cd /; rm -rf "${AUR_BUILD}"
userdel -r builduser 2>/dev/null || true
rm -f /etc/sudoers.d/builduser
# ══════════════════════════════════════════════════════════════════════════
# BOOT SPLASH — Plymouth "kibaos" theme with baked-in logo
# ══════════════════════════════════════════════════════════════════════════
THEME_DIR="/usr/share/plymouth/themes/kibaos"
mkdir -p "${THEME_DIR}"

# Decode the baked-in logo PNG
echo "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/eP2afPx84EH0Hn7/AXrt98Phvf39/vbj89p4f52//F23G62B7o6yuX7GH28tX4f9x8vL7dvL69vb2+//37//u0PY/Tf33683F7abYz2fn9/fz0+sfTxaetqEnDPPSpE7oFKOSRoaF5GfAAd3SkGRv9pz2DwENhjWvBdAngCdF8P04SDzRjj42Xvr6+vbz9+tNa+f3sdY/z48f7t27fX1++99/e30Vt7e3v77bdvf/zjH//hT/847v32+tJHe7u/31p/+fat9358qNQYDzzce3t9eX39fnt97S+vx0+ovn379u1jBvj++RfA4osPyP7jz29vb29//v3397f2fr/39tI+/rG51trxy0IHwDtC8UiLx18dvM0x4P39vd367YiA8YHMxxi3l/7+/n5/e2uPH6aN+/328vIXv/3h9z//9/F+P/5xsNbaS2sv317fxn185NdncB2eHp8/Y5qf4uqg/+jcP+rP4zjIBo3TIdJCgkL8nHm1nMiR5fZ58xJEPDm+Pf1TEtl+rV0ADYfGmznESdgSDGMWutU4e2s3soX+22nvQzB/yo9I8CTQ3Mpv3l93MNZGKk4z9DKUtGTzQT4B6Aobs4/+O/yJ4fJ4uum60tSxgJLV227uMl17rFfd2s1UT9dsa5J1Jh8eB1xTv5QcGeYSaBiKSJBHrsU2yFfK/67Bx7cHvFCveu+93dsD998leBzvt9vt5dZaa/f3dh/39oFR3u/39u3by48f77dbu4/27aW9v7fX197a7Xa7vb+Nl5eX1m795TbGuLf3TzPG53QxE39i69vt9TDy3vqttfuD7QNUDXHVePt499jJBwzpvR+/Vz3a++vtZfrnsai3W2/tdh/j/e331t/6GGO026231u8/Wn/59uPt/XZ7eb//aL239n576bf2cvzYQYaTWzSUw9VZdDOGyedu0YhOExX6rluN+dfQPkWFQsyOgARpv10Fchw4UH7t/qaHZDAm+ejf6ab9+Pa19ePX5Uf/iKIDk7+Oez/+ja2Xl5cx3tv97WOgbbdp5P1+b7fPP00Z55J47+0Isc8Y7v0D69+PuD1+Y79//JZPu7fj/z8G1d56O/7lgNb6geb74w8AHlpUvz5+p+h+u70ePyI7nt9ePnz1/v7+/fv3Y0gY995v48fv74en7vd7b/eX1m+3Q3J7fX15G/e393H8sW//OJHxcClC/485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" | base64 -d > "${THEME_DIR}/logo.png"

# Plymouth theme descriptor
cat > "${THEME_DIR}/kibaos.plymouth" << 'PLYMOUTHCONF'
[Plymouth Theme]
Name=KibaOS
Description=KibaOS boot splash — liquid glass K on black
ModuleName=script

[script]
ImageDir=/usr/share/plymouth/themes/kibaos
ScriptFile=/usr/share/plymouth/themes/kibaos/kibaos.script
PLYMOUTHCONF

# Plymouth script — centres the logo and pulses it gently
cat > "${THEME_DIR}/kibaos.script" << 'PLYSCRIPT'
logo_image = Image("logo.png");
logo_width  = logo_image.GetWidth();
logo_height = logo_image.GetHeight();

screen_width  = Window.GetWidth();
screen_height = Window.GetHeight();

scale = Math.Min((screen_width  * 0.35) / logo_width,
                 (screen_height * 0.35) / logo_height);

logo_scaled = logo_image.Scale(logo_width * scale, logo_height * scale);

logo_sprite = Sprite(logo_scaled);
logo_sprite.SetX((screen_width  - logo_width  * scale) / 2);
logo_sprite.SetY((screen_height - logo_height * scale) / 2);
logo_sprite.SetOpacity(1);

counter = 0;

fun refresh_callback() {
    counter += 1;
    t = counter / 60.0;
    opacity = 0.75 + 0.25 * Math.Sin(t * 3.14159 * 0.8);
    logo_sprite.SetOpacity(opacity);
}

Plymouth.SetRefreshFunction(refresh_callback);
PLYSCRIPT

# Plymouth daemon config — must be written before mkinitcpio bakes it in
mkdir -p /etc/plymouth
cat > /etc/plymouth/plymouthd.conf << 'PLYMOUTHD'
[Daemon]
Theme=kibaos
ShowDelay=0
DeviceTimeout=8
PLYMOUTHD

# Set theme THEN rebuild initramfs so the hook embeds the correct theme
plymouth-set-default-theme kibaos 2>/dev/null || true
mkinitcpio -c /etc/mkinitcpio.conf.d/installed.conf \
           -g /boot/initramfs-linux.img 2>/dev/null || true
echo "=== Boot splash: Plymouth kibaos theme installed ==="

# ══════════════════════════════════════════════════════════════════════════
# GTK THEME — system-wide ChromeOS-Dark + KibaOS pill panel override
# ══════════════════════════════════════════════════════════════════════════
mkdir -p /usr/share/gtk-2.0
cat > /usr/share/gtk-2.0/gtkrc << 'GTK2RC'
gtk-theme-name = "ChromeOS-Dark"
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
gtk-theme-name=ChromeOS-Dark
gtk-icon-theme-name=Papirus-Dark
gtk-font-name=Noto Sans 11
gtk-cursor-theme-size=24
gtk-xft-antialias=1
gtk-xft-hinting=1
gtk-xft-hintstyle=hintslight
gtk-xft-rgba=rgb
GTK3RC

# ── GTK3 pill panel CSS — appended on top of ChromeOS-Dark ───────────────
# ChromeOS-theme provides the base window/widget styling.
# This overrides just the Budgie panel to be a floating liquid glass pill.
cat > /etc/gtk-3.0/gtk.css << 'GTK3PANEL'
/* ════════════════════════════════════════════════════════════════════════
 * KibaOS Organic Motion Language
 * Nothing alive moves with symmetric, linear timing — things settle into
 * rest faster than they drift away from it. These three curves (named for
 * documentation; GTK CSS has no custom-property/var() support, so the
 * literal cubic-bezier values are repeated at each use site below) encode
 * that asymmetry instead of using GTK's default flat "ease":
 *
 *   settle  cubic-bezier(0.22, 1, 0.36, 1)     — easeOutQuint. Entering a
 *           state (hover, focus, opening). Quick, confident, no bounce.
 *   fade    cubic-bezier(0.5, 0, 0.75, 0)       — easeInQuart. Leaving a
 *           state. Slightly slower than settle — things drift off, they
 *           don't snap off.
 *   spring  cubic-bezier(0.34, 1.56, 0.64, 1)   — easeOutBack. Reserved
 *           for ONE thing only: the physical switch knob, where a small
 *           positional overshoot reads as a twig springing back rather
 *           than a robotic snap. Used nowhere else — overusing overshoot
 *           reads as cartoonish rather than organic.
 *
 * Caveat: this governs GTK widget-state transitions only — separate from
 * Wayfire's wobbly plugin, which now provides real compositor-level window
 * drag physics (see wayfire.ini). Raven/the Budgie Menu's open/close slide
 * is still Budgie's own compiled animation code, not GTK CSS — the opacity
 * transitions below are best-effort and may be superseded by that native
 * motion. Verify visually.
 * ════════════════════════════════════════════════════════════════════════ */

/* === KibaOS: Floating liquid glass pill panel (override on ChromeOS-Dark) === */
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
    transition: background-color 220ms cubic-bezier(0.5, 0, 0.75, 0); /* fade out */
}
.budgie-panel .budgie-applet-button:hover,
.budgie-panel button.flat:hover {
    background-color: rgba(255, 255, 255, 0.10);
    transition: background-color 150ms cubic-bezier(0.22, 1, 0.36, 1); /* settle in */
}
.budgie-panel .budgie-applet-button:active,
.budgie-panel button.flat:active {
    background-color: rgba(0, 153, 204, 0.25);
    transition: background-color 90ms cubic-bezier(0.22, 1, 0.36, 1);
}
.budgie-panel .launcher:checked,
.budgie-panel .launcher.running {
    border-bottom: 2px solid #0099cc;
    border-radius: 0;
    transition: border-color 200ms cubic-bezier(0.22, 1, 0.36, 1);
}

/* === KibaOS: Raven (notification + quick-settings sidebar) as a floating glass card === */
frame.raven-frame,
.raven-background {
    margin: 8px 8px 8px 0;
    border-radius: 22px;
    background-color: rgba(16, 24, 40, 0.72);
    border: 1px solid rgba(255, 255, 255, 0.14);
    box-shadow:
        0 12px 48px rgba(0, 0, 0, 0.50),
        inset 0 1px 0 rgba(255, 255, 255, 0.10);
    opacity: 1;
    transition: opacity 280ms cubic-bezier(0.22, 1, 0.36, 1); /* best-effort, see note above */
}
frame.raven-frame > border { border-style: none; box-shadow: none; }
.raven-header,
.raven-section-header {
    color: #e8eef5;
    font-weight: 600;
    padding: 14px 18px 6px 18px;
}
/* notification + applet rows rendered as individual cards */
.raven-background row,
.raven-background list row {
    margin: 5px 12px;
    padding: 10px 12px;
    border-radius: 14px;
    background-color: rgba(255, 255, 255, 0.05);
    border: 1px solid rgba(255, 255, 255, 0.06);
    transition: background-color 240ms cubic-bezier(0.5, 0, 0.75, 0);
}
.raven-background row:hover {
    background-color: rgba(255, 255, 255, 0.10);
    transition: background-color 140ms cubic-bezier(0.22, 1, 0.36, 1);
}
/* quick-toggle pills: wifi / bluetooth / focus / airplane mode, etc. */
.raven-background button.toggle,
.raven-background .quick-toggle {
    border-radius: 16px;
    background-color: rgba(255, 255, 255, 0.06);
    border: 1px solid rgba(255, 255, 255, 0.08);
    padding: 10px;
    transition: background-color 220ms cubic-bezier(0.5, 0, 0.75, 0),
                border-color    220ms cubic-bezier(0.5, 0, 0.75, 0);
}
.raven-background button.toggle:checked,
.raven-background .quick-toggle:checked {
    background-color: rgba(0, 153, 204, 0.35);
    border-color: rgba(0, 153, 204, 0.6);
    transition: background-color 160ms cubic-bezier(0.22, 1, 0.36, 1),
                border-color    160ms cubic-bezier(0.22, 1, 0.36, 1);
}
/* volume / brightness sliders as rounded pill tracks */
.raven-background scale trough {
    border-radius: 999px;
    background-color: rgba(255, 255, 255, 0.10);
    min-height: 6px;
}
.raven-background scale highlight {
    border-radius: 999px;
    background-color: #0099cc;
    transition: background-color 200ms cubic-bezier(0.22, 1, 0.36, 1);
}
.raven-background scale slider {
    background-color: #ffffff;
    border-radius: 999px;
    min-width: 14px;
    min-height: 14px;
}

/* === KibaOS: Budgie Menu (app launcher popover) as a floating glass card === */
popover.budgie-menu,
.budgie-menu-window {
    border-radius: 22px;
    background-color: rgba(16, 24, 40, 0.80);
    border: 1px solid rgba(255, 255, 255, 0.14);
    box-shadow: 0 12px 48px rgba(0, 0, 0, 0.50);
    transition: opacity 260ms cubic-bezier(0.22, 1, 0.36, 1); /* best-effort, see note above */
}
.budgie-menu-window entry,
popover.budgie-menu entry {
    border-radius: 999px;
    background-color: rgba(255, 255, 255, 0.08);
    border: 1px solid rgba(255, 255, 255, 0.10);
    padding: 8px 16px;
    color: #e8eef5;
    transition: background-color 200ms cubic-bezier(0.5, 0, 0.75, 0),
                border-color    200ms cubic-bezier(0.5, 0, 0.75, 0);
}
.budgie-menu-window entry:focus,
popover.budgie-menu entry:focus {
    background-color: rgba(255, 255, 255, 0.12);
    border-color: rgba(0, 153, 204, 0.6);
    transition: background-color 140ms cubic-bezier(0.22, 1, 0.36, 1),
                border-color    140ms cubic-bezier(0.22, 1, 0.36, 1);
}
button.budgie-menu-launcher {
    border-radius: 14px;
    transition: background-color 220ms cubic-bezier(0.5, 0, 0.75, 0);
}
button.budgie-menu-launcher:hover {
    background-color: rgba(0, 153, 204, 0.20);
    transition: background-color 140ms cubic-bezier(0.22, 1, 0.36, 1);
}

/* === KibaOS: GTK places sidebar (Nemo + GTK open/save dialogs) glass card === */
placessidebar {
    background-color: transparent;
    border-radius: 18px;
}
placessidebar row {
    border-radius: 12px;
    margin: 2px 6px;
    transition: background-color 220ms cubic-bezier(0.5, 0, 0.75, 0);
}
placessidebar row:selected {
    background-color: rgba(0, 153, 204, 0.25);
    transition: background-color 150ms cubic-bezier(0.22, 1, 0.36, 1);
}

/* === KibaOS: switches everywhere (budgie-control-center, GTK apps) ========
 * The one and only spot using the "spring" overshoot curve — the knob
 * physically travels, so a little organic overshoot is visible motion,
 * not just a colour flicker. */
switch slider {
    transition: margin 260ms cubic-bezier(0.34, 1.56, 0.64, 1);
}
switch:checked {
    background-color: rgba(0, 153, 204, 0.85);
    transition: background-color 220ms cubic-bezier(0.22, 1, 0.36, 1);
}
switch {
    transition: background-color 240ms cubic-bezier(0.5, 0, 0.75, 0);
}
GTK3PANEL

# Append pill CSS into ChromeOS-Dark's gtk.css so it takes effect even
# when GTK loads the theme directory directly instead of /etc/gtk-3.0/gtk.css
CHROMEOS_GTK3="/usr/share/themes/ChromeOS-Dark/gtk-3.0/gtk.css"
if [ -f "${CHROMEOS_GTK3}" ]; then
  cat >> "${CHROMEOS_GTK3}" << 'CHROMEOS_PILL_APPEND'

/* === KibaOS pill panel override (organic motion language — see primary
 * gtk-3.0/gtk.css above for the full settle/fade/spring documentation) === */
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
    transition: background-color 220ms cubic-bezier(0.5, 0, 0.75, 0);
}
.budgie-panel .budgie-applet-button:hover,
.budgie-panel button.flat:hover {
    background-color: rgba(255, 255, 255, 0.10);
    transition: background-color 150ms cubic-bezier(0.22, 1, 0.36, 1);
}
.budgie-panel .budgie-applet-button:active,
.budgie-panel button.flat:active {
    background-color: rgba(0, 153, 204, 0.25);
    transition: background-color 90ms cubic-bezier(0.22, 1, 0.36, 1);
}
.budgie-panel .launcher:checked,
.budgie-panel .launcher.running {
    border-bottom: 2px solid #0099cc;
    border-radius: 0;
    transition: border-color 200ms cubic-bezier(0.22, 1, 0.36, 1);
}

/* === KibaOS: Raven (notification + quick-settings sidebar) as a floating glass card === */
frame.raven-frame,
.raven-background {
    margin: 8px 8px 8px 0;
    border-radius: 22px;
    background-color: rgba(16, 24, 40, 0.72);
    border: 1px solid rgba(255, 255, 255, 0.14);
    box-shadow:
        0 12px 48px rgba(0, 0, 0, 0.50),
        inset 0 1px 0 rgba(255, 255, 255, 0.10);
    opacity: 1;
    transition: opacity 280ms cubic-bezier(0.22, 1, 0.36, 1);
}
frame.raven-frame > border { border-style: none; box-shadow: none; }
.raven-header,
.raven-section-header {
    color: #e8eef5;
    font-weight: 600;
    padding: 14px 18px 6px 18px;
}
.raven-background row,
.raven-background list row {
    margin: 5px 12px;
    padding: 10px 12px;
    border-radius: 14px;
    background-color: rgba(255, 255, 255, 0.05);
    border: 1px solid rgba(255, 255, 255, 0.06);
    transition: background-color 240ms cubic-bezier(0.5, 0, 0.75, 0);
}
.raven-background row:hover {
    background-color: rgba(255, 255, 255, 0.10);
    transition: background-color 140ms cubic-bezier(0.22, 1, 0.36, 1);
}
.raven-background button.toggle,
.raven-background .quick-toggle {
    border-radius: 16px;
    background-color: rgba(255, 255, 255, 0.06);
    border: 1px solid rgba(255, 255, 255, 0.08);
    padding: 10px;
    transition: background-color 220ms cubic-bezier(0.5, 0, 0.75, 0),
                border-color    220ms cubic-bezier(0.5, 0, 0.75, 0);
}
.raven-background button.toggle:checked,
.raven-background .quick-toggle:checked {
    background-color: rgba(0, 153, 204, 0.35);
    border-color: rgba(0, 153, 204, 0.6);
    transition: background-color 160ms cubic-bezier(0.22, 1, 0.36, 1),
                border-color    160ms cubic-bezier(0.22, 1, 0.36, 1);
}
.raven-background scale trough {
    border-radius: 999px;
    background-color: rgba(255, 255, 255, 0.10);
    min-height: 6px;
}
.raven-background scale highlight {
    border-radius: 999px;
    background-color: #0099cc;
    transition: background-color 200ms cubic-bezier(0.22, 1, 0.36, 1);
}
.raven-background scale slider {
    background-color: #ffffff;
    border-radius: 999px;
    min-width: 14px;
    min-height: 14px;
}

/* === KibaOS: Budgie Menu (app launcher popover) as a floating glass card === */
popover.budgie-menu,
.budgie-menu-window {
    border-radius: 22px;
    background-color: rgba(16, 24, 40, 0.80);
    border: 1px solid rgba(255, 255, 255, 0.14);
    box-shadow: 0 12px 48px rgba(0, 0, 0, 0.50);
    transition: opacity 260ms cubic-bezier(0.22, 1, 0.36, 1);
}
.budgie-menu-window entry,
popover.budgie-menu entry {
    border-radius: 999px;
    background-color: rgba(255, 255, 255, 0.08);
    border: 1px solid rgba(255, 255, 255, 0.10);
    padding: 8px 16px;
    color: #e8eef5;
    transition: background-color 200ms cubic-bezier(0.5, 0, 0.75, 0),
                border-color    200ms cubic-bezier(0.5, 0, 0.75, 0);
}
.budgie-menu-window entry:focus,
popover.budgie-menu entry:focus {
    background-color: rgba(255, 255, 255, 0.12);
    border-color: rgba(0, 153, 204, 0.6);
    transition: background-color 140ms cubic-bezier(0.22, 1, 0.36, 1),
                border-color    140ms cubic-bezier(0.22, 1, 0.36, 1);
}
button.budgie-menu-launcher {
    border-radius: 14px;
    transition: background-color 220ms cubic-bezier(0.5, 0, 0.75, 0);
}
button.budgie-menu-launcher:hover {
    background-color: rgba(0, 153, 204, 0.20);
    transition: background-color 140ms cubic-bezier(0.22, 1, 0.36, 1);
}

/* === KibaOS: GTK places sidebar (Nemo + GTK open/save dialogs) glass card === */
placessidebar {
    background-color: transparent;
    border-radius: 18px;
}
placessidebar row {
    border-radius: 12px;
    margin: 2px 6px;
    transition: background-color 220ms cubic-bezier(0.5, 0, 0.75, 0);
}
placessidebar row:selected {
    background-color: rgba(0, 153, 204, 0.25);
    transition: background-color 150ms cubic-bezier(0.22, 1, 0.36, 1);
}

/* === KibaOS: switches everywhere — the one spot using the "spring"
 * overshoot curve, since the knob's positional travel actually shows it === */
switch slider {
    transition: margin 260ms cubic-bezier(0.34, 1.56, 0.64, 1);
}
switch:checked {
    background-color: rgba(0, 153, 204, 0.85);
    transition: background-color 220ms cubic-bezier(0.22, 1, 0.36, 1);
}
switch {
    transition: background-color 240ms cubic-bezier(0.5, 0, 0.75, 0);
}
CHROMEOS_PILL_APPEND
fi

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

/* KibaOS organic motion — same settle/fade pair as GTK3 (see gtk-3.0/gtk.css
 * for the full naming/rationale); GTK4 apps get the same asymmetric feel. */
button, row, .sidebar-row, switch slider {
    transition: background-color 220ms cubic-bezier(0.5, 0, 0.75, 0),
                border-color    220ms cubic-bezier(0.5, 0, 0.75, 0);
}
button:hover, row:hover, .sidebar-row:hover {
    transition: background-color 140ms cubic-bezier(0.22, 1, 0.36, 1),
                border-color    140ms cubic-bezier(0.22, 1, 0.36, 1);
}
switch slider { transition: margin 260ms cubic-bezier(0.34, 1.56, 0.64, 1); }
GTK4CSS

# ── Disable Budgie's "built-in theme" so the KibaOS GTK CSS above actually ──
# ── renders on the panel / Raven / menu instead of being overridden by it ──
# Schema id corrected to the verified-real "com.solus-project.budgie-panel"
# (hyphenated — see the panel config block below for the source citation).
# The key itself ("enable-built-in-theme") is NOT in the confirmed manager.vala
# const dump, so it may live on a different schema (e.g. ThemeManager) or
# under a different name — unknown gschema-override keys are silently
# ignored rather than harmful, so this is left in as a no-risk best effort.
mkdir -p /usr/share/glib-2.0/schemas
cat > /usr/share/glib-2.0/schemas/zz-kibaos-budgie.gschema.override << 'BUDGIEOVERRIDE'
[com.solus-project.budgie-panel]
enable-built-in-theme=false
BUDGIEOVERRIDE
glib-compile-schemas /usr/share/glib-2.0/schemas/ 2>/dev/null || true

# ══════════════════════════════════════════════════════════════════════════
# SDDM — custom KibaOS frosted-glass greeter theme
# ══════════════════════════════════════════════════════════════════════════
SDDM_THEME_DIR="/usr/share/sddm/themes/kibaos"
mkdir -p "${SDDM_THEME_DIR}"
cp /usr/share/kibaos/wallpaper.png  "${SDDM_THEME_DIR}/background.png"  2>/dev/null || true
cp /usr/share/kibaos/logo-256.png   "${SDDM_THEME_DIR}/logo.png"        2>/dev/null || true

cat > "${SDDM_THEME_DIR}/metadata.desktop" << 'SDDMMETA'
[SddmGreeterTheme]
Name=KibaOS
Description=KibaOS frosted-glass greeter
Author=WolfTech Innovations
Copyright=2026, WolfTech Innovations
License=GPLv3
Type=sddm-theme
Version=1.0
Website=https://github.com/WolfTech-Innovations/Kiba
MainScript=Main.qml
Font=Noto Sans
QuickVersion=6
SDDMMETA

cat > "${SDDM_THEME_DIR}/Main.qml" << 'SDDMQML'
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    width: Screen.width  > 0 ? Screen.width  : 1920
    height: Screen.height > 0 ? Screen.height : 1080
    color: "#0d1b2a"
    focus: true

    property int sessionIndex: sessionModel.lastIndex >= 0 ? sessionModel.lastIndex : 0

    // ── Background wallpaper, darkened so the glass card pops ──────────────
    Image {
        anchors.fill: parent
        source: "background.png"
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
    }
    Rectangle {
        anchors.fill: parent
        color: "#0d1b2a"
        opacity: 0.42
    }

    // ── Clock, top-right, matches KibaOS panel pill style ───────────────────
    Rectangle {
        anchors { top: parent.top; right: parent.right; margins: 28 }
        width: clockCol.implicitWidth + 28; height: 56
        radius: 18
        color: "#1c2433"
        opacity: 0.78
        Column {
            id: clockCol
            anchors.centerIn: parent
            spacing: 0
            Text {
                text: Qt.formatTime(new Date(), "h:mm AP")
                color: "#ffffff"; font.pixelSize: 18; font.weight: Font.Medium
                anchors.horizontalCenter: parent.horizontalCenter
            }
            Text {
                text: Qt.formatDate(new Date(), "ddd, MMM d")
                color: "#aebccd"; font.pixelSize: 11
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
        Timer { interval: 1000; running: true; repeat: true; onTriggered: clockCol.children[0].text = Qt.formatTime(new Date(), "h:mm AP") }
    }

    // ── Central frosted-glass login card ────────────────────────────────────
    Rectangle {
        id: card
        anchors.centerIn: parent
        width: 360
        height: cardCol.implicitHeight + 56
        radius: 26
        color: "#101828"
        opacity: 0.001
        Rectangle {
            anchors.fill: parent
            radius: 26
            color: "#101828"
            opacity: 0.001
        }
        // emulated glass: solid translucent fill. Wayfire has a real blur
        // plugin now, but it's known not to apply behind semi-transparent
        // layer-shell surfaces (panels) — see wayfire.ini notes.
        Rectangle {
            anchors.fill: parent
            radius: 26
            color: Qt.rgba(0.063, 0.094, 0.157, 0.72)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.14)
        }

        ColumnLayout {
            id: cardCol
            anchors { top: parent.top; left: parent.left; right: parent.right; margins: 28 }
            spacing: 14

            Image {
                Layout.alignment: Qt.AlignHCenter
                source: "logo.png"
                width: 64; height: 64
                fillMode: Image.PreserveAspectFit
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: userModel.count > 0 ? userModel.data(userModel.index(userList.currentIndex, 0), 257) : "User"
                color: "#e8eef5"; font.pixelSize: 17; font.weight: Font.Medium
            }

            ListView {
                id: userList
                Layout.fillWidth: true
                height: 0; visible: false  // names shown via combo below instead
                model: userModel
                currentIndex: userModel.lastIndex >= 0 ? userModel.lastIndex : 0
            }

            ComboBox {
                id: userBox
                Layout.fillWidth: true
                model: userModel
                textRole: "name"
                currentIndex: userModel.lastIndex >= 0 ? userModel.lastIndex : 0
                background: Rectangle { radius: 14; color: Qt.rgba(1,1,1,0.07); border.width: 1; border.color: Qt.rgba(1,1,1,0.10) }
                contentItem: Text { text: userBox.displayText; color: "#e8eef5"; padding: 10; verticalAlignment: Text.AlignVCenter }
            }

            TextField {
                id: passwordField
                Layout.fillWidth: true
                placeholderText: "Password"
                echoMode: TextInput.Password
                color: "#e8eef5"
                placeholderTextColor: "#8a99ad"
                background: Rectangle { radius: 14; color: Qt.rgba(1,1,1,0.07); border.width: 1; border.color: Qt.rgba(1,1,1,0.10) }
                onAccepted: sddm.login(userBox.currentText, passwordField.text, root.sessionIndex)
                Keys.onReturnPressed: sddm.login(userBox.currentText, passwordField.text, root.sessionIndex)
            }

            Button {
                id: loginButton
                Layout.fillWidth: true
                text: "Sign In"
                onClicked: sddm.login(userBox.currentText, passwordField.text, root.sessionIndex)
                background: Rectangle { radius: 14; color: "#0099cc" }
                contentItem: Text { text: loginButton.text; color: "#ffffff"; font.weight: Font.DemiBold; horizontalAlignment: Text.AlignHCenter }
            }

            ComboBox {
                Layout.fillWidth: true
                model: sessionModel
                textRole: "name"
                currentIndex: root.sessionIndex
                onActivated: root.sessionIndex = currentIndex
                background: Rectangle { radius: 14; color: "transparent" }
                contentItem: Text { text: parent.displayText; color: "#aebccd"; font.pixelSize: 11; padding: 6; horizontalAlignment: Text.AlignHCenter }
            }
        }
    }

    // ── Power row, bottom-right pill buttons ────────────────────────────────
    Row {
        anchors { bottom: parent.bottom; right: parent.right; margins: 28 }
        spacing: 10
        Repeater {
            model: [
                { label: "⏻", visible: sddm.canPowerOff, action: function(){ sddm.powerOff() } },
                { label: "⟲", visible: sddm.canReboot,   action: function(){ sddm.reboot()   } }
            ]
            delegate: Rectangle {
                visible: modelData.visible
                width: 44; height: 44; radius: 14
                color: "#1c2433"; opacity: 0.78
                Text { anchors.centerIn: parent; text: modelData.label; color: "#e8eef5"; font.pixelSize: 18 }
                MouseArea { anchors.fill: parent; onClicked: modelData.action() }
            }
        }
    }

    Connections {
        target: sddm
        function onLoginFailed() { passwordField.text = ""; passwordField.placeholderText = "Incorrect password"; }
    }

    Component.onCompleted: passwordField.forceActiveFocus()
}
SDDMQML

mkdir -p /etc/sddm.conf.d
cat > /etc/sddm.conf.d/kibaos.conf << 'SDDMCONF'
[General]
DisplayServer=wayland

[Wayland]
CompositorCommand=wayfire

[Theme]
Current=kibaos

[Autologin]
User=liveuser
Session=budgie-desktop
SDDMCONF

mkdir -p /var/lib/sddm
chown sddm:sddm /var/lib/sddm 2>/dev/null || true
chmod 750 /var/lib/sddm

# ══════════════════════════════════════════════════════════════════════════
# WAYFIRE CONFIG
# ══════════════════════════════════════════════════════════════════════════
# Switched from labwc to Wayfire for real compositor-level wobbly/jelly
# window physics (labwc's philosophy explicitly excludes any animation).
# Trade-off, stated plainly: Budgie 10.10 only ships an automatic
# integration "bridge" (keybindings/theme sync) for labwc. No such bridge
# exists for Wayfire — Budgie talks to it purely through standard wlroots
# protocols (layer-shell, foreign-toplevel, etc.), which Wayfire does
# implement, but this exact combination is genuinely less-tested than
# Budgie+labwc. The single most important consequence: without an
# explicit [autostart] entry below, nothing tells Wayfire to launch
# budgie-desktop at all, so that line is load-bearing, not optional.
#
# Wayfire has no system-wide /etc/xdg config fallback the way labwc does —
# it only reads $XDG_CONFIG_HOME/wayfire.ini (effectively ~/.config/wayfire.ini).
# So the default lives in /etc/skel and gets copied into every new user's
# home directory (liveuser, and any user the OOBE installer creates) instead.
mkdir -p "${SKEL}/.config"
cat > "${SKEL}/.config/wayfire.ini" << 'WAYFIREINI'
[core]
vwidth = 4
vheight = 1
plugins = \
    autostart \
    decoration \
    move \
    resize \
    wobbly \
    grid \
    place \
    expo \
    vswitch \
    switcher \
    fast-switcher \
    foreign-toplevel \
    gtk-shell \
    idle \
    wm-actions \
    command \
    session-lock \
    shortcuts-inhibit \
    blur

# No labwc-style bridge exists for Wayfire — this is what actually starts
# the Budgie shell. Without it, Wayfire boots to an empty compositor.
[autostart]
autostart_budgie = budgie-desktop

# RGBA as four floats from 0.0-1.0 — Wayfire's decoration plugin does NOT
# accept hex colors. #1a2030 -> 0.102 0.125 0.188 ; #232b3a -> 0.137 0.169 0.227
[decoration]
active_color   = 0.102 0.125 0.188 1.0
inactive_color = 0.137 0.169 0.227 1.0
border_size = 1

# Tuned softer than Compiz's nostalgia-mode defaults (friction 3.0) so it
# reads as an organic settle rather than cartoon jelly, matching the
# settle/fade motion language already in the GTK theme. Key names confirmed
# against Wayfire's own docs; exact feel is unverified until it boots —
# tune by hand from there.
[wobbly]
friction = 4.5
spring_k = 8.0
grid_resolution = 6

# Blur is a real Wayfire plugin (unlike labwc, which has none at all), but
# a known upstream limitation (WayfireWM/wayfire#1399) means it historically
# does NOT apply behind semi-transparent layer-shell surfaces like Budgie's
# panel/Raven — so this will likely blur behind floating app windows
# (e.g. a translucent terminal) but NOT produce real frosted-glass behind
# the panel itself. The panel still relies on the alpha-transparency
# illusion already built into the GTK theme. Verify visually either way.
[blur]
method = kawase
mode = normal
kawase_offset = 2
kawase_degrade = 3
kawase_iterations = 2
WAYFIREINI
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
    usr/bin/wayfire*)
      # Note: wayfire.ini now lives per-user (Wayfire has no system-wide
      # /etc/xdg fallback), seeded from /etc/skel at account creation. An
      # OTA patch to the skel copy only affects NEWLY created users from
      # that point on — it can't retroactively update already-installed
      # users' own ~/.config/wayfire.ini. Only the binary itself triggers
      # a restart here.
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

  # Take screenshot as liveuser. (This script runs at real boot time on the
  # installed system, not inside the nosuid build chroot, so sudo would
  # actually work here — using runuser anyway for consistency, since this
  # script is also always invoked as root and runuser is the more direct
  # tool for "run as a different user" with no escalation step needed.)
  runuser -u liveuser -- env \
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

# ── Restart compositor: full session bounce, not in-place reconfigure ─────
# Wayfire has documented crash-on-config-reload reports (no general
# "reconfigure" signal equivalent to labwc's, and what reload support
# exists is plugin-specific, not whole-compositor). Rather than gamble on
# an in-place reload inside an unattended OTA patcher, this restarts the
# whole greeter/session — slower, but it's not going to leave the user
# stuck on a half-reloaded compositor.
restart_compositor() {
  log "Restarting session (wayfire via sddm)..."
  systemctl restart sddm 2>/dev/null || \
  pkill -TERM wayfire 2>/dev/null || true
  sleep 1
  log "Session restarted."
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
gtk-theme-name=ChromeOS-Dark
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
gtk-theme-name="ChromeOS-Dark"
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

dconf write /com/solus-project/budgie-panel/panels "@as []"
cat > /usr/share/glib-2.0/schemas/99-kibaos-budgie.gschema.override << 'EOF'
[com.solus-project.budgie-panel]
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

gsettings set org.gnome.desktop.interface gtk-theme               'ChromeOS-Dark'
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

# ── Panel config, using the schema verified directly from upstream source ─
# (src/panel/manager.vala, BuddiesOfBudgie/budgie-desktop main branch):
#   ROOT_SCHEMA      = com.solus-project.budgie-panel          (hyphenated!)
#   TOPLEVEL_PREFIX  = /com/solus-project/budgie-panel/panels
#   PANEL_KEY_POSITION    = "location"       (not "position")
#   PANEL_KEY_SHADOW      = "enable-shadow"  (not "shadow")
#   PANEL_KEY_APPLETS     = "applets"        (flat ordered UUID list)
# The previous version of this block used "com.solus-project.budgie.panel"
# (dotted) with keys "position"/"shadow" — neither the schema nor those key
# names exist upstream, so those dconf writes were very likely a silent
# no-op the whole time, not actually configuring anything.
PANEL_UUID=$(gsettings get com.solus-project.budgie-panel panels 2>/dev/null | \
  tr -d "[]' " | cut -d',' -f1)
if [ -z "${PANEL_UUID}" ]; then
  PANEL_UUID=$(uuidgen)
  dconf write /com/solus-project/budgie-panel/panels "['${PANEL_UUID}']"
fi
PANEL_PATH="/com/solus-project/budgie-panel/panels/${PANEL_UUID}/"
dconf write "${PANEL_PATH}location"      "'BOTTOM'"
dconf write "${PANEL_PATH}size"          "42"
dconf write "${PANEL_PATH}transparency"  "'DYNAMIC'"
dconf write "${PANEL_PATH}enable-shadow" "true"

# ── Centered dock: applets + pinned launchers, matching the mockup's order ─
# Budgie's icon-tasklist applet PERMANENTLY crashes the session on every
# future login if pinned-launchers references a .desktop file that doesn't
# exist (solus-project/budgie-desktop#1480 — confirmed, not theoretical).
# So: probe the real filesystem for whichever desktop-id variant actually
# shipped, rather than hardcoding a guess and hoping it's right.
find_desktop_id() {
  for candidate in "$@"; do
    [ -f "/usr/share/applications/${candidate}" ] && { echo "${candidate}"; return 0; }
  done
  return 1
}
DOCK_LAUNCHERS=()
for ids in \
  "nemo.desktop" \
  "org.gnome.Calendar.desktop gnome-calendar.desktop" \
  "org.gnome.Notes.desktop bijiben.desktop gnome-notes.desktop" \
  "org.gnome.eog.desktop eog.desktop" \
  "org.gnome.Geary.desktop geary.desktop" \
  "org.gnome.Music.desktop gnome-music.desktop" \
  "org.gnome.Todo.desktop gnome-todo.desktop"
do
  FOUND=$(find_desktop_id ${ids}) && DOCK_LAUNCHERS+=("${FOUND}")
done

# Each applet UUID needs two things written: (1) a generic "which plugin is
# this UUID" lookup entry, and (2) that plugin's OWN settings at ITS OWN
# settings-prefix. (1) is extrapolated by direct structural analogy to the
# now-confirmed TOPLEVEL_SCHEMA/TOPLEVEL_PREFIX pattern above — I have not
# directly observed this exact const in source the way I have for the panel
# schema, so flag it as the one remaining inferential step if applets don't
# show up. (2) for icon-tasklist specifically IS directly confirmed: Budgie's
# own docs give the Budgie Menu applet's settings-prefix as
# /com/solus-project/budgie-panel/instance/budgie-menu/{uuid} — same pattern
# applies to icon-tasklist's instance path below.
add_applet() {
  local plugin_name="$1"
  local uuid
  uuid=$(uuidgen)
  dconf write "/com/solus-project/budgie-panel/applets/${uuid}/name" "'${plugin_name}'"
  echo "${uuid}"
}

MENU_UUID=$(add_applet "budgie-menu")
TASKLIST_UUID=$(add_applet "icon-tasklist")
CLOCK_UUID=$(add_applet "clock")

ALL_APPLETS="['${MENU_UUID}', '${TASKLIST_UUID}', '${CLOCK_UUID}']"
dconf write "${PANEL_PATH}applets" "${ALL_APPLETS}"

if [ "${#DOCK_LAUNCHERS[@]}" -gt 0 ]; then
  LAUNCHERS_GVARIANT=$(printf "'%s', " "${DOCK_LAUNCHERS[@]}")
  dconf write \
    "/com/solus-project/budgie-panel/instance/icon-tasklist/${TASKLIST_UUID}/pinned-launchers" \
    "[${LAUNCHERS_GVARIANT%, }]"
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

# ── OEM-mode autostart: launches io.kibaos.oobe (which self-detects
# OEM-finish mode via /etc/kibaos/oem-pending, see main.vala) on login to
# the temporary 'oem' autologin account set up by kibaos-oem-prepare. A
# plain Exec= can't conditionally skip launching, so the condition is
# wrapped in a one-line shell test instead — on a normal (non-OEM) install
# this marker never exists, so the test fails and nothing launches. ───────
cat > "${SKEL}/.config/autostart/kibaos-oem-finish.desktop" << 'OEMAUTOCFG'
[Desktop Entry]
Type=Application
Name=Finish Setting Up KibaOS
Exec=sh -c 'test -f /etc/kibaos/oem-pending && exec /usr/bin/io.kibaos.oobe'
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
OEMAUTOCFG

mkdir -p /etc/systemd/zram-generator.conf.d
cat > /etc/systemd/zram-generator.conf << 'ZRAM'
[zram0]
zram-size = ram / 2
compression-algorithm = zstd
ZRAM

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

cat > "${SKEL}/.bashrc" << 'BASHRC'
[[ $- != *i* ]] && return
PS1='\[\e[1;36m\][KibaOS]\[\e[0m\] \[\e[32m\]\u@\h\[\e[0m\]:\[\e[34m\]\w\[\e[0m\]\$ '
alias ls='ls --color=auto'
alias ll='ls -lah --color=auto'
alias grep='grep --color=auto'
alias install='sudo pkexec /usr/bin/io.kibaos.oobe'
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

# ── No firewall package on KibaOS ──────────────────────────────────────────
# ufw was previously included, but its packaging hooks misbehave inside
# this chroot build container even beyond just the `ufw enable` CLI
# command (confirmed: removing that one call wasn't sufficient — something
# in ufw's own systemd-enable-time hooks still tries a /proc-dependent
# SSH-detection check and fails the same way, since there's no real /proc
# in this build environment). Rather than keep fighting a third-party
# tool's chroot incompatibility for a build-time-only customization step
# that was never going to filter live traffic anyway, ufw is dropped
# entirely. KibaOS currently ships with no firewall configured by default —
# worth revisiting later (e.g. via nftables directly, or a different
# firewall frontend) if network-facing security hardening becomes a
# priority, but it's not a build-blocking concern for a desktop live/
# install image the way it might be for a server image.

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
Exec=/usr/bin/io.kibaos.oobe
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
GTK_THEME=ChromeOS-Dark
QT_STYLE_OVERRIDE=kvantum
XCURSOR_THEME=Adwaita
XCURSOR_SIZE=24
MOZ_ENABLE_WAYLAND=1
WINEDEBUG=-all
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
  Install: click the desktop icon or run  install

ISSUE

cat > /etc/motd << 'MOTD'
Welcome to KibaOS
MOTD

# ── Time sync ──────────────────────────────────────────────────────────────
# Configure timesyncd with fast NTP pools so the RTC gets corrected
# immediately on first boot rather than slewing for minutes/hours.
mkdir -p /etc/systemd/
cat > /etc/systemd/timesyncd.conf << 'TIMESYNCD'
[Time]
NTP=0.arch.pool.ntp.org 1.arch.pool.ntp.org 2.arch.pool.ntp.org 3.arch.pool.ntp.org
FallbackNTP=0.pool.ntp.org 1.pool.ntp.org time.cloudflare.com time.google.com
RootDistanceMaxSec=5
PollIntervalMinSec=32
PollIntervalMaxSec=1024
TIMESYNCD

# Force RTC to UTC (matches hwclock.conf) and enable sync
timedatectl set-local-rtc 0 2>/dev/null || true
systemctl enable systemd-timesyncd
systemctl enable systemd-time-wait-sync

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

install -d -m 755 -o 1000 -g 1000 /home/liveuser/.config/dconf
runuser -u liveuser -- dbus-run-session -- bash -c '
  dconf write /com/solus-project/budgie-panel/panels "@as []"
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
