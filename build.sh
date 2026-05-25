#!/bin/bash
# KibaOS ISO build script
# DE: Deepin Desktop Environment (deepin + deepin-kwin + deepin-extra)
# Greeter: ReGreet (greetd + greetd-regreet + cage)
# Auth: liveuser password "live", nopasswdlogin PAM group for autologin
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
  greetd greetd-regreet cage gtk4 \
  \
  imagemagick \
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

# ── Wallpaper: fetch + upscale to 4K ──────────────────────────────────────
# Source is a 1920×1080 copyright-free purple aesthetic image.
# We upscale to 3840×2160 with Lanczos so it looks sharp on HiDPI displays,
# then embed it at /usr/share/wallpapers/kibaos/wallpaper.jpg in the airootfs.
WALLPAPER_URL="https://wallpapers.com/images/hd/non-copyrighted-purple-aesthetic-view-6ad1lsfony65z6q5.jpg"
WALLPAPER_SRC="${WORKDIR}/wallpaper_src.jpg"
WALLPAPER_4K="${WORKDIR}/wallpaper_4k.jpg"

echo "=== Fetching wallpaper ==="
curl -fL --retry 3 --retry-delay 2 -o "${WALLPAPER_SRC}" "${WALLPAPER_URL}"

echo "=== Upscaling wallpaper to 3840×2160 (Lanczos) ==="
magick "${WALLPAPER_SRC}" \
  -filter Lanczos \
  -resize 3840x2160\! \
  -unsharp 0x0.75+0.75+0.008 \
  -quality 92 \
  "${WALLPAPER_4K}"

# Stage into airootfs — both paths covered:
#   /usr/share/wallpapers/kibaos/wallpaper.jpg  (regreet + deepin dconf key)
#   /usr/share/wallpapers/deepin/desktop.jpg    (deepin fallback default)
mkdir -p "${AIROOTFS}/usr/share/wallpapers/kibaos"
mkdir -p "${AIROOTFS}/usr/share/wallpapers/deepin"
cp "${WALLPAPER_4K}" "${AIROOTFS}/usr/share/wallpapers/kibaos/wallpaper.jpg"
cp "${WALLPAPER_4K}" "${AIROOTFS}/usr/share/wallpapers/deepin/desktop.jpg"

echo "=== Wallpaper staged ==="

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

# ── No source compilation needed — DDE ships as pacman packages ──────────
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
lightdm
lightdm-deepin-greeter
greetd
greetd-regreet
cage
gtk4
openssl
PACKAGES

# ── initramfs ──────────────────────────────────────────────────────────────
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

SYSLINUX_CFG="${PROFILE}/syslinux/syslinux.cfg"
if [ -f "${SYSLINUX_CFG}" ]; then
  sed -i 's/Arch Linux/KibaOS/g'   "${SYSLINUX_CFG}"
  sed -i 's/ARCH_[0-9]*/KIBAOS/g' "${SYSLINUX_CFG}"
fi

# ── greetd + ReGreet config ────────────────────────────────────────────────
# ReGreet runs under Cage (minimal Wayland compositor) as the greeter user.
# It reads xsessions from /usr/share/xsessions and launches them via
# startx /usr/bin/env <session-exec> (X11_CMD_PREFIX default).
mkdir -p "${AIROOTFS}/etc/greetd"

cat > "${AIROOTFS}/etc/greetd/config.toml" << 'GREETDCONF'
[terminal]
vt = 1

[default_session]
command = "env GTK_USE_PORTAL=0 GDK_DEBUG=no-portals cage -s -mlast -- regreet"
user = "greeter"
GREETDCONF

# wallpaper path now points to our embedded KibaOS wallpaper
cat > "${AIROOTFS}/etc/greetd/regreet.toml" << 'REGREETCONF'
[background]
path = "/usr/share/wallpapers/kibaos/wallpaper.jpg"
fit = "Cover"

[GTK]
application_prefer_dark_theme = true

[clock]
format = "%H:%M — %A, %B %d"

[commands]
reboot = ["loginctl", "reboot"]
poweroff = ["loginctl", "poweroff"]
REGREETCONF

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
  - greetd
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
# Password is "live" — SHA-512 hash generated at build time via openssl.
# The nopasswdlogin group + xdm-autologin PAM service means XDM never prompts,
# but the password works at TTY and as a sudo fallback.
mkdir -p "${AIROOTFS}/etc"

LIVE_HASH=$(openssl passwd -6 "live")

grep -q '^liveuser:' "${AIROOTFS}/etc/passwd" 2>/dev/null || \
  echo 'liveuser:x:1000:1000:KibaOS Live User:/home/liveuser:/usr/bin/zsh' \
  >> "${AIROOTFS}/etc/passwd"

grep -q '^liveuser:' "${AIROOTFS}/etc/group" 2>/dev/null || \
  echo 'liveuser:x:1000:liveuser' >> "${AIROOTFS}/etc/group"

# Real password hash — NOT locked with "!"
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
ln -sf /usr/lib/systemd/system/xdm.service      "${WANTS}/display-manager.service"
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

# nopasswdlogin: members bypass XDM PAM password auth via pam_succeed_if.
# This is the Arch-standard mechanism for display manager autologin.
groupadd -r nopasswdlogin 2>/dev/null || true

# ── liveuser group membership ─────────────────────────────────────────────
for g in users wheel audio video input network storage nopasswdlogin; do
  usermod -aG "$g" liveuser 2>/dev/null || true
done

# ── Set liveuser password to "live" ──────────────────────────────────────
# Belt-and-suspenders: shadow hash was written at build time, chpasswd
# re-hashes inside the chroot so the final shadow is definitely correct.
echo "liveuser:live" | chpasswd

# ── systemd tunables ──────────────────────────────────────────────────────
sed -i 's/#Storage=auto/Storage=volatile/'                    /etc/systemd/journald.conf
sed -i 's/#HandleLidSwitch=suspend/HandleLidSwitch=ignore/'   /etc/systemd/logind.conf
sed -i 's/#HandleSuspendKey=suspend/HandleSuspendKey=ignore/' /etc/systemd/logind.conf

# ── Root shell ────────────────────────────────────────────────────────────
chsh -s /usr/bin/zsh root

# ── liveuser home ─────────────────────────────────────────────────────────
cp -aT /etc/skel/ /home/liveuser/ 2>/dev/null || true

# ~/.xsession: XDM's actual session entry point.
cat > /home/liveuser/.xsession << 'DOTXSESSION'
#!/bin/bash
exec /usr/local/bin/kiba-session
DOTXSESSION
chmod +x /home/liveuser/.xsession

chown -R 1000:1000 /home/liveuser
chmod 750 /home/liveuser

# ── dconf system-db: dark mode + wallpaper defaults ───────────────────────
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
wallpaper='/usr/share/wallpapers/kibaos/wallpaper.jpg'

[com/deepin/dde/filemanager/wallpaper]
wallpaper-uri='file:///usr/share/wallpapers/kibaos/wallpaper.jpg'
DCONFKEYS
dconf update

# ── Cutefish native configs ────────────────────────────────────────────────
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

# ── Deepin wallpaper config file (DDE native, pre-seeds the gsetting key) ─
# DDE reads ~/.config/deepin/deepin-wallpaper.ini as a per-user override
# before the dconf key takes effect. Belt-and-suspenders for live session.
mkdir -p /home/liveuser/.config/deepin
cat > /home/liveuser/.config/deepin/deepin-wallpaper.ini << 'WALLINI'
[Wallpaper]
Wallpaper=/usr/share/wallpapers/kibaos/wallpaper.jpg
WALLINI

# Also write the org.deepin.dde.appearance gsettings XML override so the
# setting survives even if dconf-deepin integration isn't active at first boot.
mkdir -p /usr/share/glib-2.0/schemas
cat > /usr/share/glib-2.0/schemas/99-kibaos-wallpaper.gschema.override << 'GSCHEMA'
[com.deepin.dde.appearance]
wallpaper='/usr/share/wallpapers/kibaos/wallpaper.jpg'
GSCHEMA
glib-compile-schemas /usr/share/glib-2.0/schemas/ 2>/dev/null || true

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
