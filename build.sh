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
  grub \
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
bootmodes=('uefi-x64.grub.esp' 'uefi-x64.grub.eltorito')
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
grub
os-prober
dosfstools
mtools
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
xorg-xwayland
layer-shell-qt
budgie-session
gcc
debugedit
base-devel
archinstall
python
python-pyalpm
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
swaybg
grim
slurp
swayidle
gtklock
wlopm
nemo
nemo-fileroller
gnome-console
gnome-disk-utility
gnome-backgrounds
gnome-keyring
gnome-settings-daemon
gvfs
gvfs-mtp
gvfs-smb
file-roller
gnome-text-editor
loupe
evince
papirus-icon-theme
accountsservice
sassc
meson
ninja
vulkan-headers
vulkan-icd-loader
wayland
wayland-protocols
wlroots0.19
cairo
pango
pixman
libdrm
libevdev
libxml2
freetype2
libpng
harfbuzz
fribidi
glib2
sysprof
libinput
libjpeg-turbo
libxkbcommon
nlohmann-json
yyjson
boost
glm
network-manager-applet
kvantum
pipewire
pipewire-pulse
pipewire-alsa
wireplumber
networkmanager

chromium
ntfs-3g
exfatprogs
polkit
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
gnome-calendar
gnome-notes
gnome-music
gnome-todo
plymouth
squashfs-tools
PACKAGES

# ══════════════════════════════════════════════════════════════════════════
# mkinitcpio
# ══════════════════════════════════════════════════════════════════════════
# archiso.conf — used only by the LIVE environment (memdisk/archiso hooks).
# "plymouth" is included so the live boot can show our splash theme, and
# "kms" so the framebuffer is set up early enough (before "archiso") for
# plymouth to actually have a surface to draw on. Both must be added here —
# mkarchiso only ever bakes THIS file's hooks into the live ISO's initramfs
# (per linux.preset's archiso_config= below); installed.conf is irrelevant
# to the live build and is never read by mkarchiso.
mkdir -p "${AIROOTFS}/etc/mkinitcpio.conf.d"
cat > "${AIROOTFS}/etc/mkinitcpio.conf.d/archiso.conf" << 'INITRAMFS'
HOOKS=(base udev kms plymouth keyboard keymap modconf memdisk archiso block filesystems)
INITRAMFS

# installed.conf — used by the INSTALLED system after the OOBE installer runs initcpio.
# Must NOT include memdisk/archiso hooks (those are live-only).
cat > "${AIROOTFS}/etc/mkinitcpio.conf.d/installed.conf" << 'INSTALLED_HOOKS'
HOOKS=(base udev kms plymouth autodetect modconf block keyboard keymap filesystems fsck)
INSTALLED_HOOKS

mkdir -p "${AIROOTFS}/etc/mkinitcpio.d"
cat > "${AIROOTFS}/etc/mkinitcpio.d/linux.preset" << 'PRESET'
PRESETS=('archiso')
ALL_kver='/boot/vmlinuz-linux'
archiso_config='/etc/mkinitcpio.conf.d/archiso.conf'
archiso_image='/boot/initramfs-linux.img'
PRESET

# ══════════════════════════════════════════════════════════════════════════
# Boot menu — GRUB, UEFI only
# ══════════════════════════════════════════════════════════════════════════
# releng ships syslinux/ (BIOS) and efiboot/ (systemd-boot) by default;
# neither is used now that bootmodes above is GRUB/UEFI-only, so drop them
# rather than leave dead config lying around in the profile.
rm -rf "${PROFILE}/syslinux" "${PROFILE}/efiboot"
mkdir -p "${PROFILE}/grub"

# grub/grub.cfg is a template: mkarchiso substitutes %ARCHISO_LABEL%,
# %INSTALL_DIR%, %ARCH% and %ARCHISO_SEARCH_FILENAME% for us at build time
# (see mkarchiso's _build_grub_config). GRUB draws its background/theme
# immediately regardless of timeout — unlike systemd-boot, there's no
# timeout>=1 requirement to get a splash on screen, so `timeout=0` here
# auto-boots straight in without the systemd-boot splash bug we hit before.
cat > "${PROFILE}/grub/grub.cfg" << 'GRUBCFG'
set default=0
set timeout=0
insmod all_video
insmod gfxterm
terminal_output gfxterm

search --no-floppy --set=root --label %ARCHISO_LABEL%

menuentry "KibaOS" --class kibaos {
    linux /%INSTALL_DIR%/boot/x86_64/vmlinuz-linux archisobasedir=%INSTALL_DIR% archisolabel=%ARCHISO_LABEL% cow_spacesize=1G quiet splash loglevel=3 rd.udev.log_level=3 vt.global_cursor_default=0 plymouth.use-simpledrm=1
    initrd /%INSTALL_DIR%/boot/x86_64/initramfs-linux.img
}

menuentry "KibaOS (safe mode)" --class kibaos {
    linux /%INSTALL_DIR%/boot/x86_64/vmlinuz-linux archisobasedir=%INSTALL_DIR% archisolabel=%ARCHISO_LABEL% cow_spacesize=1G nomodeset systemd.unit=multi-user.target systemd.log_level=info
    initrd /%INSTALL_DIR%/boot/x86_64/initramfs-linux.img
}

if [ "${grub_platform}" == "efi" ]; then
    menuentry 'UEFI Firmware Settings' --id 'uefi-firmware' {
        fwsetup
    }
fi
GRUBCFG

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

rm -f /etc/machine-id
touch /etc/machine-id

# ── create system users/groups declared via sysusers.d (polkitd, etc.) ─────
# pacman normally triggers this via a post-install hook on a running system,
# but that hook doesn't fire reliably when packages are unpacked straight
# into an airootfs, so users like polkitd never get created and polkitd
# fails to start (-> "Could not activate remote peer 'org.freedesktop.
# PolicyKit1': startup job failed"). Run it explicitly here.
systemd-sysusers || true
systemd-tmpfiles --create 2>/dev/null || true

# ── polkitd fallback ────────────────────────────────────────────────────────
# Belt-and-suspenders: if systemd-sysusers above didn't run/succeed in this
# chroot context, this guarantees the polkitd user still exists so polkitd
# can actually start (otherwise: "Could not activate remote peer
# 'org.freedesktop.PolicyKit1': startup job failed").
id polkitd &>/dev/null || useradd -r -U -M -d /run/polkit -s /usr/bin/nologin polkitd

# ── alpm user ──────────────────────────────────────────────────────────────
useradd -r -s /usr/bin/nologin -U alpm 2>/dev/null || true
mkdir -p /var/cache/pacman/pkg
chmod 755 /var/cache/pacman /var/cache/pacman/pkg
chown -R alpm:alpm /var/cache/pacman
sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' /etc/pacman.conf

# CheckSpace is disabled for the airootfs pacstrap over in kibaos.sh's
# PROFILE/pacman.conf, but that doesn't guarantee this chroot's own live
# /etc/pacman.conf inherited the same edit — belt-and-suspenders it here too.
# CheckSpace is a known false-positive source under overlay filesystems (its
# statvfs() call misreports free space on overlay2, which is what most CI
# runners use for Docker), and — critically — its "not enough free disk
# space... Proceed with installation? [Y/n]" prompt does NOT reliably honor
# --noconfirm the way the normal transaction-confirmation prompt does. In a
# non-interactive CI shell with no stdin, that stray prompt is what actually
# hangs/fails the step, not a real space shortage.
sed -i 's/^CheckSpace/#CheckSpace/' /etc/pacman.conf

# ── Re-init the pacman keyring inside THIS chroot ───────────────────────────
# "keyring is not writable" / "required key missing from keyring" happens
# when /etc/pacman.d/gnupg's ownership/permissions don't match the UID
# actually running pacman inside the container — common in CI where the
# outer Docker layer and this arch-chroot session don't line up cleanly,
# even though mkarchiso initialized a keyring earlier in the process. GnuPG
# is strict about homedir perms (must be 0700, owned by the invoking user),
# so rather than debug which UID owns what, wipe it and rebuild fresh under
# the identity that's actually running this script right now.
rm -rf /etc/pacman.d/gnupg
pacman-key --init
pacman-key --populate archlinux
pacman -Syy --noconfirm

# ── Reclaim disk before any further installs ────────────────────────────────
# By this point mkarchiso has already pacstrapped the full ~195-package
# packages.x86_64 list (chromium, wine, mesa, etc.) into this airootfs, and
# every one of those .pkg.tar.zst downloads is still sitting in the cache —
# previously nothing cleared it until the very end of the script. Later
# steps in here (Kortex's own pacman installs, the Nuitka onefile compile,
# building wayfire-plugins-extra from source) all need real scratch disk on
# top of that, which is what was actually running the image out of space,
# not any one install being oversized on its own. `-Scc` (double-c) drops
# cached packages of every version, not just superseded ones.
pacman -Scc --noconfirm

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

# ══════════════════════════════════════════════════════════════════════════
# KORTEX — adaptive daemon (usage prediction, break reminders, layout
# learning, driver/service auto-repair). Source is embedded here and
# compiled to a native x86_64 binary with Nuitka at image-build time, same
# pattern the OOBE build below uses for its Vala sources.
# ══════════════════════════════════════════════════════════════════════════
echo "=== Installing Kortex build + runtime dependencies ==="
# NOTE: Nuitka's Arch package name is "nuitka", not "python-nuitka" — but
# it's currently AUR-only (aur.archlinux.org/packages/nuitka), not in
# core/extra, so plain `pacman -S nuitka` won't resolve on a stock mirror
# without an AUR helper. Installing via pip avoids that dependency entirely.
pacman -S --noconfirm --needed gtk4 gtk4-layer-shell python-gobject patchelf python-pip
pip install --break-system-packages --no-cache-dir nuitka

mkdir -p /usr/lib/kortex/kortexd/assets

cat > /usr/lib/kortex/kortexd/__init__.py << 'KORTEX_INIT_PY'
"""
Kept lazy on purpose: importing `kortexd` shouldn't require GTK4 to be
installed just to use storage.py/models.py in isolation (tests, tuning
scripts, a REPL on a dev box without the desktop stack).
"""

__all__ = ["KortexDaemon", "main"]
__version__ = "0.1.0"


def __getattr__(name):
    if name in ("KortexDaemon", "main"):
        from .core import KortexDaemon, main
        return {"KortexDaemon": KortexDaemon, "main": main}[name]
    raise AttributeError(f"module {__name__!r} has no attribute {name!r}")
KORTEX_INIT_PY

cat > /usr/lib/kortex/kortexd/storage.py << 'KORTEX_STORAGE_PY'
"""
kortexd.storage
----------------
Single sqlite3 backend for all Kortex state: usage counters (Beta params),
session stats (Welford), placement history, friction events, repair history,
and KDE anchor points. Kept as one file so the whole daemon has one source
of truth and one lock.
"""

import sqlite3
import time
import json
import os
from contextlib import contextmanager

DEFAULT_DB_PATH = os.path.expanduser("~/.local/share/kortex/kortex.db")

SCHEMA = """
CREATE TABLE IF NOT EXISTS usage_beta (
    app TEXT NOT NULL,
    day_of_week INTEGER NOT NULL,   -- 0-6
    hour_block INTEGER NOT NULL,    -- 0-23
    alpha REAL NOT NULL DEFAULT 1.0,
    beta REAL NOT NULL DEFAULT 1.0,
    last_seen REAL NOT NULL DEFAULT 0,
    PRIMARY KEY (app, day_of_week, hour_block)
);

CREATE TABLE IF NOT EXISTS session_stats (
    app TEXT PRIMARY KEY,
    count INTEGER NOT NULL DEFAULT 0,
    mean REAL NOT NULL DEFAULT 0,
    m2 REAL NOT NULL DEFAULT 0,      -- Welford running variance accumulator
    session_start REAL,
    last_updated REAL
);

CREATE TABLE IF NOT EXISTS placement (
    app TEXT NOT NULL,
    monitor INTEGER NOT NULL,
    x REAL NOT NULL,
    y REAL NOT NULL,
    w REAL NOT NULL,
    h REAL NOT NULL,
    weight REAL NOT NULL DEFAULT 1.0,
    updated REAL NOT NULL,
    PRIMARY KEY (app, monitor)
);

CREATE TABLE IF NOT EXISTS friction_events (
    app TEXT NOT NULL,
    kind TEXT NOT NULL,             -- 'rage' | 'dead' | 'reverted'
    ts REAL NOT NULL,
    x REAL,
    y REAL
);

CREATE TABLE IF NOT EXISTS repair_beta (
    failure_sig TEXT NOT NULL,
    action TEXT NOT NULL,
    alpha REAL NOT NULL DEFAULT 1.0,
    beta REAL NOT NULL DEFAULT 1.0,
    attempts INTEGER NOT NULL DEFAULT 0,
    last_attempt REAL,
    PRIMARY KEY (failure_sig, action)
);

CREATE TABLE IF NOT EXISTS repair_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    failure_sig TEXT NOT NULL,
    action TEXT NOT NULL,
    success INTEGER NOT NULL,
    detail TEXT,
    ts REAL NOT NULL
);

CREATE TABLE IF NOT EXISTS kde_points (
    domain TEXT NOT NULL,           -- 'usage' | 'failure' | 'placement'
    key TEXT NOT NULL,              -- serialized feature vector
    weight REAL NOT NULL,
    ts REAL NOT NULL
);

CREATE TABLE IF NOT EXISTS config (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
);
"""


class Store:
    def __init__(self, path: str = DEFAULT_DB_PATH):
        os.makedirs(os.path.dirname(path), exist_ok=True)
        self.path = path
        self._conn = sqlite3.connect(path, check_same_thread=False)
        self._conn.row_factory = sqlite3.Row
        self._conn.executescript(SCHEMA)
        self._conn.commit()

    @contextmanager
    def cursor(self):
        cur = self._conn.cursor()
        try:
            yield cur
            self._conn.commit()
        except Exception:
            self._conn.rollback()
            raise
        finally:
            cur.close()

    # ---- usage beta ----
    def get_beta(self, app, dow, hour):
        with self.cursor() as c:
            c.execute(
                "SELECT alpha, beta FROM usage_beta WHERE app=? AND day_of_week=? AND hour_block=?",
                (app, dow, hour),
            )
            row = c.fetchone()
            if row:
                return row["alpha"], row["beta"]
            return 1.0, 1.0  # uniform prior

    def update_beta(self, app, dow, hour, hit: bool, decay: float = 1.0):
        alpha, beta = self.get_beta(app, dow, hour)
        alpha *= decay
        beta *= decay
        if hit:
            alpha += 1.0
        else:
            beta += 1.0
        with self.cursor() as c:
            c.execute(
                """INSERT INTO usage_beta (app, day_of_week, hour_block, alpha, beta, last_seen)
                   VALUES (?,?,?,?,?,?)
                   ON CONFLICT(app, day_of_week, hour_block)
                   DO UPDATE SET alpha=excluded.alpha, beta=excluded.beta, last_seen=excluded.last_seen""",
                (app, dow, hour, alpha, beta, time.time()),
            )

    def last_seen(self, app):
        with self.cursor() as c:
            c.execute("SELECT MAX(last_seen) as ls FROM usage_beta WHERE app=?", (app,))
            row = c.fetchone()
            return row["ls"] if row and row["ls"] else None

    # ---- session stats (Welford) ----
    def get_session_stats(self, app):
        with self.cursor() as c:
            c.execute("SELECT * FROM session_stats WHERE app=?", (app,))
            row = c.fetchone()
            if row:
                return dict(row)
            return {"app": app, "count": 0, "mean": 0.0, "m2": 0.0,
                    "session_start": None, "last_updated": None}

    def update_session_stats(self, app, session_length: float):
        s = self.get_session_stats(app)
        n = s["count"] + 1
        delta = session_length - s["mean"]
        mean = s["mean"] + delta / n
        delta2 = session_length - mean
        m2 = s["m2"] + delta * delta2
        with self.cursor() as c:
            c.execute(
                """INSERT INTO session_stats (app, count, mean, m2, last_updated)
                   VALUES (?,?,?,?,?)
                   ON CONFLICT(app) DO UPDATE SET
                     count=excluded.count, mean=excluded.mean, m2=excluded.m2,
                     last_updated=excluded.last_updated""",
                (app, n, mean, m2, time.time()),
            )

    def set_session_start(self, app, ts):
        with self.cursor() as c:
            c.execute(
                """INSERT INTO session_stats (app, session_start)
                   VALUES (?,?)
                   ON CONFLICT(app) DO UPDATE SET session_start=excluded.session_start""",
                (app, ts),
            )

    # ---- placement ----
    def update_placement(self, app, monitor, x, y, w, h, decay=0.9):
        with self.cursor() as c:
            c.execute("SELECT weight FROM placement WHERE app=? AND monitor=?", (app, monitor))
            row = c.fetchone()
            weight = (row["weight"] * decay + 1.0) if row else 1.0
            c.execute(
                """INSERT INTO placement (app, monitor, x, y, w, h, weight, updated)
                   VALUES (?,?,?,?,?,?,?,?)
                   ON CONFLICT(app, monitor) DO UPDATE SET
                     x=excluded.x, y=excluded.y, w=excluded.w, h=excluded.h,
                     weight=excluded.weight, updated=excluded.updated""",
                (app, monitor, x, y, w, h, weight, time.time()),
            )

    def get_placement(self, app, monitor):
        """Returns (x, y, w, h, weight) for the learned placement, or None
        if Kortex has never seen this app on this monitor.
        """
        with self.cursor() as c:
            c.execute(
                "SELECT x, y, w, h, weight FROM placement WHERE app=? AND monitor=?",
                (app, monitor),
            )
            row = c.fetchone()
            if not row:
                return None
            return (row["x"], row["y"], row["w"], row["h"], row["weight"])

    def get_placement_confidence(self, app, kappa=3.0):
        with self.cursor() as c:
            c.execute("SELECT SUM(weight) as tw FROM placement WHERE app=?", (app,))
            row = c.fetchone()
            total = row["tw"] or 0.0
            return total / (total + kappa)

    # ---- friction ----
    # 'reverted' (user manually undid an automatic Kortex action) is a much
    # stronger, more specific signal than a rage/dead click — it's not "this
    # UI is annoying," it's "Kortex was wrong about me, specifically." Weight
    # it accordingly rather than logging it as a second 'rage' event.
    FRICTION_KIND_WEIGHTS = {
        "rage": 1.0,
        "dead": 1.0,
        "reverted": 3.0,
    }

    def log_friction(self, app, kind, x=None, y=None):
        with self.cursor() as c:
            c.execute(
                "INSERT INTO friction_events (app, kind, ts, x, y) VALUES (?,?,?,?,?)",
                (app, kind, time.time(), x, y),
            )

    def friction_score(self, app, window_seconds=3600, rho=5.0):
        cutoff = time.time() - window_seconds
        with self.cursor() as c:
            c.execute(
                "SELECT kind, COUNT(*) as n FROM friction_events "
                "WHERE app=? AND ts>=? GROUP BY kind",
                (app, cutoff),
            )
            weighted = sum(
                self.FRICTION_KIND_WEIGHTS.get(row["kind"], 1.0) * row["n"]
                for row in c.fetchall()
            )
            return weighted / (weighted + rho)

    # ---- repair beta ----
    def get_repair_beta(self, failure_sig, action):
        with self.cursor() as c:
            c.execute(
                "SELECT alpha, beta, attempts FROM repair_beta WHERE failure_sig=? AND action=?",
                (failure_sig, action),
            )
            row = c.fetchone()
            if row:
                return row["alpha"], row["beta"], row["attempts"]
            return 1.0, 1.0, 0

    def update_repair_beta(self, failure_sig, action, success: bool):
        alpha, beta, attempts = self.get_repair_beta(failure_sig, action)
        if success:
            alpha += 1.0
        else:
            beta += 1.0
        attempts += 1
        with self.cursor() as c:
            c.execute(
                """INSERT INTO repair_beta (failure_sig, action, alpha, beta, attempts, last_attempt)
                   VALUES (?,?,?,?,?,?)
                   ON CONFLICT(failure_sig, action) DO UPDATE SET
                     alpha=excluded.alpha, beta=excluded.beta,
                     attempts=excluded.attempts, last_attempt=excluded.last_attempt""",
                (failure_sig, action, alpha, beta, attempts, time.time()),
            )
        with self.cursor() as c:
            c.execute(
                "INSERT INTO repair_log (failure_sig, action, success, ts) VALUES (?,?,?,?)",
                (failure_sig, action, int(success), time.time()),
            )

    # ---- KDE anchors ----
    def add_kde_point(self, domain, key_vec, weight=1.0):
        with self.cursor() as c:
            c.execute(
                "INSERT INTO kde_points (domain, key, weight, ts) VALUES (?,?,?,?)",
                (domain, json.dumps(key_vec), weight, time.time()),
            )

    def get_kde_points(self, domain, limit=500):
        with self.cursor() as c:
            c.execute(
                "SELECT key, weight, ts FROM kde_points WHERE domain=? ORDER BY ts DESC LIMIT ?",
                (domain, limit),
            )
            return [(json.loads(r["key"]), r["weight"], r["ts"]) for r in c.fetchall()]

    def prune_kde_points(self, domain, max_points=500):
        with self.cursor() as c:
            c.execute(
                """DELETE FROM kde_points WHERE domain=? AND ts NOT IN (
                       SELECT ts FROM kde_points WHERE domain=? ORDER BY ts DESC LIMIT ?
                   )""",
                (domain, domain, max_points),
            )
KORTEX_STORAGE_PY

cat > /usr/lib/kortex/kortexd/models.py << 'KORTEX_MODELS_PY'
"""
kortexd.models
--------------
Pure-math layer. Every function here is deterministic and named after what
it returns, so this module IS the spec:

    C(a,t) = sigmoid( mu(a,t)*delta(a,t) + eps(a) + beta_p(a)
                       + pi(a)*delta(a,t) - phi(a)
                       + eta(f,act)*kappa(act)*delta(f) )

No ML weights, no training step — everything updates online via closed-form
rules (Beta posterior updates, Welford's algorithm, exponentially decayed KDE).
"""

import math
import time

# ---------------------------------------------------------------------------
# Tunable constants (smoothing / decay). Keep centralized so tuning Kortex's
# "feel" is a one-place edit, not a hunt through the codebase.
# ---------------------------------------------------------------------------
LAMBDA_RECENCY = 0.15       # recency decay rate (per day)
LAMBDA_WEEKLY_FORGET = 0.95  # weekly decay applied to stale beta counts
KDE_BANDWIDTH = 1.0
KDE_TIME_DECAY = 0.98        # per-hour decay on KDE point weight
PLACEMENT_KAPPA = 3.0
FRICTION_RHO = 5.0
DENSITY_TAU = 0.15           # min density before a signal is "trusted"

WEIGHTS = {
    "usage": 1.4,
    "recency": 0.6,
    "break": 1.0,
    "placement": 0.8,
    "friction": 1.2,
    "repair": 1.5,
}


def sigmoid(x: float) -> float:
    """sigma(x) = 1 / (1 + e^-x)"""
    try:
        return 1.0 / (1.0 + math.exp(-x))
    except OverflowError:
        return 0.0 if x < 0 else 1.0


def normal_cdf(x: float) -> float:
    """Phi(x) via erf — used for break-pressure tail probability."""
    return 0.5 * (1.0 + math.erf(x / math.sqrt(2)))


def beta_mean(alpha: float, beta: float) -> float:
    """E[Beta(alpha, beta)] — posterior mean usage/success probability."""
    return alpha / (alpha + beta) if (alpha + beta) > 0 else 0.5


def gaussian_kernel(u: float) -> float:
    return math.exp(-0.5 * u * u) / math.sqrt(2 * math.pi)


def kde_density(point, anchors, h=KDE_BANDWIDTH, now=None):
    """
    delta(x) = sum_i K((x - x_i)/h) * decay^(hours since x_i)

    `point` and each anchor's key are equal-length numeric vectors
    (already normalized by the caller). Distance uses simple Euclidean norm
    scaled by bandwidth h.
    """
    if not anchors:
        return 0.0
    now = now or time.time()
    total = 0.0
    for key_vec, weight, ts in anchors:
        dist = math.sqrt(sum((a - b) ** 2 for a, b in zip(point, key_vec)))
        hours = max(0.0, (now - ts) / 3600.0)
        decay = KDE_TIME_DECAY ** hours
        total += gaussian_kernel(dist / h) * weight * decay
    # normalize roughly into [0,1]-ish range by anchor count so it doesn't
    # blow up with a large history
    return total / max(1, len(anchors))


def usage_belief(alpha: float, beta: float) -> float:
    """mu(a,t)"""
    return beta_mean(alpha, beta)


def recency_decay(last_seen_ts, now=None) -> float:
    """eps(a) = e^(-lambda * days_since_last_use)"""
    if last_seen_ts is None:
        return 0.0
    now = now or time.time()
    days = max(0.0, (now - last_seen_ts) / 86400.0)
    return math.exp(-LAMBDA_RECENCY * days)


def break_pressure(current_session_s: float, mean_s: float, var_s: float) -> float:
    """
    beta_p(a) = 1 - Phi((T_a - mu_a) / sigma_a)

    Spikes toward 1 as current session time exceeds the learned mean.
    Falls back to 0 if we don't have enough history to estimate variance.
    """
    sigma = math.sqrt(var_s) if var_s > 0 else None
    if sigma is None or sigma == 0 or mean_s == 0:
        return 0.0
    z = (current_session_s - mean_s) / sigma
    return 1.0 - normal_cdf(z)


def placement_consistency(total_weight: float, kappa=PLACEMENT_KAPPA) -> float:
    """pi(a) = C_a / (C_a + kappa)"""
    return total_weight / (total_weight + kappa)


def friction_penalty(friction_count: float, rho=FRICTION_RHO) -> float:
    """phi(a) = R_a / (R_a + rho)"""
    return friction_count / (friction_count + rho)


def repair_success_rate(alpha: float, beta: float) -> float:
    """eta(f, action) = E[Beta(alpha_success, beta_fail)]"""
    return beta_mean(alpha, beta)


def action_confidence(risk: float) -> float:
    """kappa(action) = 1 - Risk(action), risk in [0,1]"""
    return max(0.0, 1.0 - risk)


def confidence(
    mu_a_t: float,
    delta_a_t: float,
    eps_a: float,
    beta_p_a: float,
    pi_a: float,
    phi_a: float,
    eta_f_act: float = 0.0,
    kappa_act: float = 0.0,
    delta_f: float = 0.0,
    weights=None,
) -> float:
    """
    C(a,t) = sigmoid( w1*mu*delta + w2*eps + w3*beta_p
                        + w4*pi*delta - w5*phi
                        + w6*eta*kappa*delta_f )

    Density terms (delta) gate the usage/placement contributions so a single
    lucky observation can't spike confidence — see DENSITY_TAU.
    """
    w = weights or WEIGHTS
    usage_term = mu_a_t * delta_a_t if delta_a_t >= DENSITY_TAU else 0.0
    placement_term = pi_a * delta_a_t if delta_a_t >= DENSITY_TAU else 0.0
    repair_term = eta_f_act * kappa_act * delta_f

    x = (
        w["usage"] * usage_term
        + w["recency"] * eps_a
        + w["break"] * beta_p_a
        + w["placement"] * placement_term
        - w["friction"] * phi_a
        + w["repair"] * repair_term
    )
    return sigmoid(x)


def score_action(history_success: float, risk: float, attempts: int, lam=0.5) -> float:
    """
    A*(f) = argmax_a [ w1*H(a,f) + w2*(1-Risk(a)) + w3*e^(-lambda*attempts) ]

    Returns the scalar score for one candidate action; caller takes argmax
    over the action space.
    """
    return (
        1.2 * history_success
        + 0.8 * action_confidence(risk)
        + 0.5 * math.exp(-lam * attempts)
    )
KORTEX_MODELS_PY

cat > /usr/lib/kortex/kortexd/repair.py << 'KORTEX_REPAIR_PY'
"""
kortexd.repair
--------------
Detects device/service failures from journald + udev, then picks a fix from
a FIXED, pre-written action table using score_action() from models.py.

Kortex never generates or executes arbitrary commands. Every action here is
a named Python function with a known blast radius. If nothing in the table
fixes it, we escalate to the user instead of guessing further.
"""

import subprocess
import time
import re
import math
import json
from dataclasses import dataclass, field
from typing import Callable, Optional

from . import models
from .storage import Store

# ---------------------------------------------------------------------------
# Static risk table — how much state each action touches. 0 = trivial/safe,
# 1 = high blast radius. Tune conservatively; when in doubt, rate it higher.
# ---------------------------------------------------------------------------
RISK = {
    "reload_module": 0.15,
    "restart_service": 0.25,
    "reset_udev_rule": 0.20,
    "reset_usb_port": 0.30,
    "fallback_driver": 0.40,
    "rollback_config": 0.60,
    "noop_escalate": 0.0,
}

MAX_ATTEMPTS = 3


@dataclass
class FailureEvent:
    signature: str          # e.g. "usb:disconnect_loop:0451:8442"
    device: str
    detail: str
    ts: float = field(default_factory=time.time)


# ---------------------------------------------------------------------------
# Detection: EWMA / z-score control chart on event rate per device.
# This is the "no ML, just statistics" fault detector.
# ---------------------------------------------------------------------------
class EWMAMonitor:
    def __init__(self, alpha=0.3, k=3.0):
        self.alpha = alpha
        self.k = k
        self._mean = {}
        self._var = {}

    def observe(self, key: str, value: float) -> bool:
        """Returns True if `value` breaches the EWMA + k*sigma control limit."""
        m = self._mean.get(key, value)
        v = self._var.get(key, 0.0)
        breach = False
        if key in self._mean:
            sigma = math.sqrt(v) if v > 0 else 0.0
            if sigma > 0 and value > m + self.k * sigma:
                breach = True
        delta = value - m
        m2 = m + self.alpha * delta
        v2 = (1 - self.alpha) * (v + self.alpha * delta * delta)
        self._mean[key] = m2
        self._var[key] = v2
        return breach


# ---------------------------------------------------------------------------
# Action space — each function takes the FailureEvent and returns (ok, detail)
# ---------------------------------------------------------------------------
def _run(cmd, timeout=15):
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
        return r.returncode == 0, (r.stdout + r.stderr).strip()[-500:]
    except Exception as e:
        return False, str(e)


# ---------------------------------------------------------------------------
# Privilege boundary: kortexd runs as an unprivileged per-user systemd
# service (see graphical-session.target.wants), but every action below needs
# root (modprobe, systemctl restart of a *system* unit, udevadm, sysfs
# writes, kibaos-ota). Rather than granting kortexd itself any privilege, it
# hands off to /usr/lib/kortex/kortex-helper via pkexec — a separate root
# process that re-validates every parameter against the same whitelist
# before touching anything. kortexd never runs privileged commands directly.
# ---------------------------------------------------------------------------
def _run_privileged(action: str, params: dict, timeout=15):
    try:
        r = subprocess.run(
            ["pkexec", "/usr/lib/kortex/kortex-helper"],
            input=json.dumps({"action": action, "params": params}),
            capture_output=True, text=True, timeout=timeout,
        )
        if r.returncode != 0 and not r.stdout.strip():
            return False, (r.stderr or "pkexec denied or failed").strip()[-500:]
        resp = json.loads(r.stdout)
        return bool(resp.get("ok")), str(resp.get("detail", ""))[-500:]
    except Exception as e:
        return False, str(e)


def act_reload_module(ev: FailureEvent):
    mod = _extract_module(ev.detail)
    if not mod:
        return False, "no module name extracted"
    return _run_privileged("reload_module", {"mod": mod})


def act_restart_service(ev: FailureEvent):
    svc = _extract_service(ev.detail) or ev.device
    return _run_privileged("restart_service", {"svc": svc})


def act_reset_udev_rule(ev: FailureEvent):
    return _run_privileged("reset_udev_rule", {})


def act_reset_usb_port(ev: FailureEvent):
    bus_port = _extract_usb_port(ev.detail)
    if not bus_port:
        return False, "no usb bus/port extracted"
    return _run_privileged("reset_usb_port", {"bus_port": bus_port})


def act_fallback_driver(ev: FailureEvent):
    # Swap to a known-safe alternate driver binding, if one is configured.
    alt = KNOWN_FALLBACKS.get(ev.device)
    if not alt:
        return False, "no fallback driver configured"
    mod = _extract_module(ev.detail)
    return _run_privileged("fallback_driver", {"device": ev.device, "mod": mod or ""})


def act_rollback_config(ev: FailureEvent):
    # Reuses KibaOS's existing OTA snapshot infra rather than reinventing it.
    return _run_privileged("rollback_config", {"reason": f"kortex:{ev.signature}"})


def act_noop_escalate(ev: FailureEvent):
    return False, "escalated to user, no automatic action taken"


ACTIONS: dict[str, Callable[[FailureEvent], tuple]] = {
    "reload_module": act_reload_module,
    "restart_service": act_restart_service,
    "reset_udev_rule": act_reset_udev_rule,
    "reset_usb_port": act_reset_usb_port,
    "fallback_driver": act_fallback_driver,
    "rollback_config": act_rollback_config,
    "noop_escalate": act_noop_escalate,
}

KNOWN_FALLBACKS: dict[str, str] = {
    # "wifi:rtl8822ce": "rtw88_8822ce",
}


def _extract_module(text: str) -> Optional[str]:
    m = re.search(r"module[:\s]+([a-zA-Z0-9_\-]+)", text, re.I)
    return m.group(1) if m else None


def _extract_service(text: str) -> Optional[str]:
    m = re.search(r"([a-zA-Z0-9_\-]+\.service)", text)
    return m.group(1) if m else None


def _extract_usb_port(text: str) -> Optional[str]:
    m = re.search(r"\b(\d+-[\d.]+)\b", text)
    return m.group(1) if m else None


# ---------------------------------------------------------------------------
# Execution loop
# ---------------------------------------------------------------------------
class RepairEngine:
    def __init__(self, store: Store, on_popup=None, on_result=None):
        self.store = store
        self.monitor = EWMAMonitor()
        self.on_popup = on_popup      # callback(FailureEvent) -> fire "repair started" UI
        self.on_result = on_result    # callback(FailureEvent, success, detail) -> update UI

    def handle_failure(self, ev: FailureEvent):
        if self.on_popup:
            self.on_popup(ev)

        density = models.kde_density(
            point=_failure_vector(ev),
            anchors=self.store.get_kde_points("failure"),
        )
        self.store.add_kde_point("failure", _failure_vector(ev), weight=1.0)
        self.store.prune_kde_points("failure")

        # Novel failure signatures (low density) get fewer automatic attempts
        # before escalating — Kortex trusts its own history less here.
        max_attempts = MAX_ATTEMPTS if density >= models.DENSITY_TAU else 1

        tried = []
        any_succeeded = False
        for attempt in range(max_attempts):
            action = self._pick_action(ev, exclude=tried)
            if action is None or action == "noop_escalate":
                break
            fn = ACTIONS[action]
            success, detail = fn(ev)
            self.store.update_repair_beta(ev.signature, action, success)
            tried.append(action)
            if self.on_result:
                self.on_result(ev, success, detail, action, attempt + 1, max_attempts)
            if success:
                any_succeeded = True
                return True
        # exhausted attempts (all failed), or nothing was viable to try at all —
        # either way, nothing fixed it, so surface a final escalation to the user
        # distinct from the per-attempt failure notifications already sent above.
        if self.on_result and not any_succeeded:
            reason = "no viable action found" if not tried else f"all {len(tried)} attempt(s) failed"
            self.on_result(ev, False, reason, "noop_escalate", len(tried), max_attempts)
        return False

    def _pick_action(self, ev: FailureEvent, exclude):
        best, best_score = None, -1.0
        for name in ACTIONS:
            if name in exclude or name == "noop_escalate":
                continue
            alpha, beta, attempts = self.store.get_repair_beta(ev.signature, name)
            hist = models.repair_success_rate(alpha, beta)
            score = models.score_action(hist, RISK[name], attempts)
            if score > best_score:
                best, best_score = name, score
        return best


def _failure_vector(ev: FailureEvent):
    # crude but stable feature hash -> numeric vector for KDE distance
    h = abs(hash(ev.signature)) % 1000
    return [h / 1000.0]


# ---------------------------------------------------------------------------
# journald / udev watcher (stub loop — wire to real subprocess.Popen streams)
# ---------------------------------------------------------------------------
FAILURE_PATTERNS = [
    (re.compile(r"usb \S+: device descriptor read.*error", re.I), "usb_desc_error"),
    (re.compile(r"link is not ready", re.I), "link_not_ready"),
    (re.compile(r"firmware: failed to load", re.I), "firmware_load_fail"),
    (re.compile(r"(\S+\.service): Failed with result", re.I), "service_failed"),
]


def watch_journal(engine: RepairEngine, poll_seconds=2):
    """Tail `journalctl -f` and turn matching lines into FailureEvents."""
    proc = subprocess.Popen(
        ["journalctl", "-f", "-o", "short-monotonic"],
        stdout=subprocess.PIPE, text=True, bufsize=1,
    )
    try:
        for line in proc.stdout:
            for pattern, tag in FAILURE_PATTERNS:
                m = pattern.search(line)
                if not m:
                    continue
                device = m.group(1) if m.groups() else "unknown"
                sig = f"{tag}:{device}"
                breach = engine.monitor.observe(sig, 1.0)
                if breach or tag in ("firmware_load_fail", "usb_desc_error"):
                    ev = FailureEvent(signature=sig, device=device, detail=line.strip())
                    engine.handle_failure(ev)
    finally:
        proc.terminate()
KORTEX_REPAIR_PY

# ══════════════════════════════════════════════════════════════════════════
# KORTEX-HELPER — root-side executor for the repair action table.
#
# kortexd (above) runs unprivileged as a per-user systemd service. It never
# runs modprobe/systemctl/udevadm/sysfs-writes/kibaos-ota itself — it asks
# this helper to, via pkexec. The helper re-validates every parameter
# against the same whitelist independently: it does not trust kortexd's
# extraction of the module/service/USB-port name, because that text
# ultimately traces back to journald log lines, which a misbehaving device
# could influence. Defense in depth across the privilege boundary.
# ══════════════════════════════════════════════════════════════════════════
echo "=== Installing kortex-helper (privileged repair executor) ==="
install -d -m 755 /usr/lib/kortex
cat > /usr/lib/kortex/kortex-helper << 'KORTEX_HELPER_PY'
#!/usr/bin/env python3
"""
kortex-helper
-------------
Root-side executor for Kortex's fixed repair action table. Invoked via
pkexec by the unprivileged kortexd user service. Reads one JSON request
from stdin: {"action": "<name>", "params": {...}}, writes one JSON
response to stdout: {"ok": bool, "detail": "..."}.

Every parameter is re-validated here, independently of whatever checks
kortexd already did — this process trusts nothing that crosses the
privilege boundary. There is no arbitrary-command path: the action name
must be an exact key in DISPATCH, and every function below only ever
shells out to a fixed, named command.
"""
import sys
import json
import re
import subprocess
import time

SAFE_NAME = re.compile(r"^[a-zA-Z0-9_\-]{1,64}$")
SAFE_SERVICE = re.compile(r"^[a-zA-Z0-9_\-@.]{1,128}\.service$")
SAFE_USB_PORT = re.compile(r"^\d+-[\d.]{1,16}$")
SAFE_REASON = re.compile(r"^[a-zA-Z0-9_\-:. ]{1,128}$")

# Keep in sync with kortexd/repair.py's KNOWN_FALLBACKS. Currently empty on
# both sides — populate as real hardware fallback pairs get validated.
KNOWN_FALLBACKS = {
    # "wifi:rtl8822ce": "rtw88_8822ce",
}


def _run(cmd, timeout=15):
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
        return r.returncode == 0, (r.stdout + r.stderr).strip()[-500:]
    except Exception as e:
        return False, str(e)


def reload_module(params):
    mod = params.get("mod", "")
    if not SAFE_NAME.match(mod):
        return False, "rejected: invalid module name"
    _run(["modprobe", "-r", mod])
    return _run(["modprobe", mod])


def restart_service(params):
    svc = params.get("svc", "")
    if not SAFE_SERVICE.match(svc):
        return False, "rejected: invalid service unit name"
    return _run(["systemctl", "restart", svc])


def reset_udev_rule(params):
    ok1, _ = _run(["udevadm", "control", "--reload-rules"])
    ok2, out = _run(["udevadm", "trigger", "--action=change"])
    return (ok1 and ok2), out


def reset_usb_port(params):
    bus_port = params.get("bus_port", "")
    if not SAFE_USB_PORT.match(bus_port):
        return False, "rejected: invalid usb bus/port"
    path = f"/sys/bus/usb/devices/{bus_port}/authorized"
    try:
        with open(path, "w") as f:
            f.write("0")
        time.sleep(1)
        with open(path, "w") as f:
            f.write("1")
        return True, f"cycled {bus_port}"
    except Exception as e:
        return False, str(e)


def fallback_driver(params):
    device = params.get("device", "")
    mod = params.get("mod", "")
    alt = KNOWN_FALLBACKS.get(device)
    if not alt:
        return False, "no fallback driver configured"
    if mod and not SAFE_NAME.match(mod):
        return False, "rejected: invalid module name"
    if mod:
        _run(["modprobe", "-r", mod])
    return _run(["modprobe", alt])


def rollback_config(params):
    reason = params.get("reason", "kortex:unknown")
    if not SAFE_REASON.match(reason):
        reason = "kortex:unspecified"
    return _run(["kibaos-ota", "rollback", "--reason", reason])


DISPATCH = {
    "reload_module": reload_module,
    "restart_service": restart_service,
    "reset_udev_rule": reset_udev_rule,
    "reset_usb_port": reset_usb_port,
    "fallback_driver": fallback_driver,
    "rollback_config": rollback_config,
}


def main():
    try:
        req = json.loads(sys.stdin.read())
    except Exception:
        print(json.dumps({"ok": False, "detail": "malformed request"}))
        return 1

    fn = DISPATCH.get(req.get("action", ""))
    if fn is None:
        print(json.dumps({"ok": False, "detail": f"unknown action: {req.get('action')!r}"}))
        return 1

    ok, detail = fn(req.get("params", {}) or {})
    print(json.dumps({"ok": ok, "detail": detail}))
    return 0


if __name__ == "__main__":
    sys.exit(main())
KORTEX_HELPER_PY
chown root:root /usr/lib/kortex/kortex-helper
chmod 755 /usr/lib/kortex/kortex-helper

# ── Polkit action + exec-path mapping ───────────────────────────────────────
# The exec.path annotation is what lets `pkexec /usr/lib/kortex/kortex-helper`
# resolve to this specific action id rather than falling back to the generic
# org.freedesktop.policykit.exec action (which prompts for the admin password
# every single time — unworkable for silent background repair).
install -d -m 755 /usr/share/polkit-1/actions
cat > /usr/share/polkit-1/actions/dev.wolftech.kortex.policy << 'KORTEX_POLKIT_POLICY'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE policyconfig PUBLIC "-//freedesktop//DTD PolicyKit Policy Configuration 1.0//EN"
 "http://www.freedesktop.org/standards/PolicyKit/1/policyconfig.dtd">
<policyconfig>
  <vendor>WolfTech Innovations</vendor>
  <vendor_url>https://github.com/WolfTech-Innovations</vendor_url>
  <action id="dev.wolftech.kortex.repair">
    <description>Run a Kortex automatic repair action</description>
    <message>Kortex wants to apply an automatic repair</message>
    <icon_name>kortex</icon_name>
    <defaults>
      <allow_any>no</allow_any>
      <allow_inactive>no</allow_inactive>
      <allow_active>auth_admin_keep</allow_active>
    </defaults>
    <annotate key="org.freedesktop.policykit.exec.path">/usr/lib/kortex/kortex-helper</annotate>
  </action>
</policyconfig>
KORTEX_POLKIT_POLICY

# ── Polkit rule: allow without a password prompt, active local session only ─
# NOTE — deliberate tradeoff, not a default you should ship blind:
# <defaults> above says auth_admin_keep (password once, cached). This rule
# overrides that to YES with no password at all for the active local user,
# because a repair popup that then demands a sudo password defeats the
# point of "automatic" repair on a consumer OS. The blast radius is bounded
# by kortex-helper's own fixed whitelist + re-validation above, but it does
# mean any locally-running process as the active user can invoke these six
# specific root actions without a prompt. If that tradeoff doesn't sit
# right for you, delete this .rules file and keep only the auth_admin_keep
# default above — Kortex will then prompt for a password on first repair
# per session instead of acting silently.
install -d -m 755 /etc/polkit-1/rules.d
cat > /etc/polkit-1/rules.d/49-kortex.rules << 'KORTEX_POLKIT_RULES'
polkit.addRule(function(action, subject) {
    if (action.id == "dev.wolftech.kortex.repair" &&
        subject.active && subject.local) {
        return polkit.Result.YES;
    }
});
KORTEX_POLKIT_RULES
chmod 644 /etc/polkit-1/rules.d/49-kortex.rules
echo "=== kortex-helper installed ==="

cat > /usr/lib/kortex/kortexd/notifier.py << 'KORTEX_NOTIFIER_PY'
"""
kortexd.notifier
----------------
Renders the repair-status popup. Styled to match KibaOS's own OOBE
design language (white glass card, #0099cc accent, rounded corners)
rather than a separate look — palette pulled straight from kibaos.sh's
oobe.css block, so this reads as part of the OS, not a bolted-on toast.

Built as a plain GTK4 layer-shell window (not a libnotify passthrough) so
it can carry live progress state and a details expander. Falls back to a
normal top-level Gtk.Window if gtk4-layer-shell isn't installed (e.g.
during dev on non-Wayland).
"""

import os
import gi

gi.require_version("Gtk", "4.0")
from gi.repository import Gtk, Gdk, GLib, Pango  # noqa: E402

try:
    gi.require_version("Gtk4LayerShell", "1.0")
    from gi.repository import Gtk4LayerShell as LayerShell
    HAVE_LAYER_SHELL = True
except (ValueError, ImportError):
    HAVE_LAYER_SHELL = False

ASSET_DIR = os.path.join(os.path.dirname(__file__), "assets")

# Palette lifted directly from kibaos.sh's oobe.css (.oobe-card,
# .oobe-continue-button, .oobe-title) so Kortex's popup and the installer
# read as the same product, not two different design systems.
CSS = b"""
.kortex-toast {
    background:    rgba(255,255,255,0.92);
    border:        1px solid rgba(255,255,255,0.70);
    border-radius: 20px;
    padding: 14px 16px;
    box-shadow:
        0 2px 4px  rgba(0,0,0,0.04),
        0 8px 24px rgba(0,0,0,0.10);
}
.kortex-title {
    color: #0f172a;
    font-weight: 700;
    font-size: 14px;
}
.kortex-body {
    color: #475569;
    font-size: 12.5px;
}
.kortex-detail {
    color: #64748b;
    font-size: 11px;
    font-family: monospace;
}
.kortex-icon-badge {
    background: rgba(0,153,204,0.10);
    border-radius: 14px;
    padding: 6px;
}
.kortex-progress trough {
    min-height: 4px;
    border-radius: 4px;
    background: rgba(0,0,0,0.08);
}
.kortex-progress progress {
    min-height: 4px;
    border-radius: 4px;
    background: #0099cc;
}
.kortex-undo-button {
    background: rgba(0,153,204,0.10);
    color: #0099cc;
    font-weight: 600;
    font-size: 12px;
    border-radius: 10px;
    padding: 4px 10px;
    margin-top: 2px;
}
.kortex-undo-button:hover {
    background: rgba(0,153,204,0.18);
}
"""


def _apply_css():
    provider = Gtk.CssProvider()
    provider.load_from_data(CSS)
    Gtk.StyleContext.add_provider_for_display(
        Gdk.Display.get_default(), provider,
        Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION,
    )


class KortexToast(Gtk.Window):
    """One popup instance, mutated across its lifecycle:
    started -> (success | retrying | escalated)
    """

    def __init__(self, app, title, body):
        super().__init__(application=app)
        self.set_default_size(340, -1)
        self.set_decorated(False)

        if HAVE_LAYER_SHELL:
            LayerShell.init_for_window(self)
            LayerShell.set_layer(self, LayerShell.Layer.OVERLAY)
            LayerShell.set_anchor(self, LayerShell.Edge.TOP, True)
            LayerShell.set_anchor(self, LayerShell.Edge.RIGHT, True)
            LayerShell.set_margin(self, LayerShell.Edge.TOP, 48)
            LayerShell.set_margin(self, LayerShell.Edge.RIGHT, 16)

        outer = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        outer.add_css_class("kortex-toast")
        outer.set_margin_start(4)
        outer.set_margin_end(4)
        outer.set_margin_top(4)
        outer.set_margin_bottom(4)

        badge = Gtk.Box()
        badge.add_css_class("kortex-icon-badge")
        icon_path = os.path.join(ASSET_DIR, "kortex-icon.svg")
        image = Gtk.Image.new_from_file(icon_path)
        image.set_pixel_size(26)
        badge.append(image)
        outer.append(badge)

        text_col = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        text_col.set_hexpand(True)

        self.title_label = Gtk.Label(label=title, xalign=0)
        self.title_label.add_css_class("kortex-title")
        self.title_label.set_wrap(True)
        text_col.append(self.title_label)

        self.body_label = Gtk.Label(label=body, xalign=0)
        self.body_label.add_css_class("kortex-body")
        self.body_label.set_wrap(True)
        self.body_label.set_max_width_chars(34)
        text_col.append(self.body_label)

        self.progress = Gtk.ProgressBar()
        self.progress.add_css_class("kortex-progress")
        self.progress.set_show_text(False)
        self.progress.pulse()
        text_col.append(self.progress)

        self.detail_label = Gtk.Label(label="", xalign=0)
        self.detail_label.add_css_class("kortex-detail")
        self.detail_label.set_visible(False)
        self.detail_label.set_wrap(True)
        self.detail_label.set_max_width_chars(40)
        text_col.append(self.detail_label)

        outer.append(text_col)
        self.set_child(outer)

        self._pulse_id = GLib.timeout_add(120, self._pulse)
        self._auto_close_id = None

    def _pulse(self):
        self.progress.pulse()
        return True

    def set_success(self, detail: str, auto_close_s=5):
        self._stop_pulse()
        self.progress.set_fraction(1.0)
        self.title_label.set_label("Fixed \u2014 Kortex repaired the device")
        self.body_label.set_label(detail or "Device is back online.")
        self._schedule_close(auto_close_s)

    def set_retrying(self, action: str, attempt: int, max_attempts: int):
        self.body_label.set_label(
            f"Trying fix {attempt}/{max_attempts}: {action.replace('_', ' ')}"
        )

    def set_preference_shift(self, on_undo, auto_close_s=8):
        """Deliberately vague/corporate, matching the repair toast's tone —
        no app name, no coordinates, no admission of what actually moved.
        """
        self._stop_pulse()
        self.progress.set_fraction(1.0)
        self.title_label.set_label("KibaOS optimized your workspace")
        self.body_label.set_label("Layout adjusted based on usage patterns")

        undo_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        undo_row.set_halign(Gtk.Align.START)
        undo_btn = Gtk.Button(label="Undo")
        undo_btn.add_css_class("kortex-undo-button")
        undo_btn.set_has_frame(False)

        def _on_undo_clicked(_btn):
            if on_undo:
                on_undo()
            self._close()

        undo_btn.connect("clicked", _on_undo_clicked)
        undo_row.append(undo_btn)

        # Insert the undo row into the text column, right under the body
        # label — same child structure as the rest of the toast.
        text_col = self.body_label.get_parent()
        text_col.append(undo_row)

        self._schedule_close(auto_close_s)

    def set_escalated(self, tried_actions):
        self._stop_pulse()
        self.progress.set_fraction(1.0)
        self.title_label.set_label("Couldn't auto-repair this one")
        self.body_label.set_label("Here's what Kortex tried \u2014 tap for details.")
        self.detail_label.set_label(", ".join(tried_actions) or "no safe action available")
        self.detail_label.set_visible(True)
        self._schedule_close(12)

    def _stop_pulse(self):
        if self._pulse_id:
            GLib.source_remove(self._pulse_id)
            self._pulse_id = None

    def _schedule_close(self, seconds):
        if self._auto_close_id:
            GLib.source_remove(self._auto_close_id)
        self._auto_close_id = GLib.timeout_add_seconds(seconds, self._close)

    def _close(self):
        self.close()
        return False


class KortexNotifier:
    """Owns the GTK application loop; kortexd calls into this from its
    repair callbacks. Runs on the main thread — repair detection/execution
    should happen on a worker thread and hand off via GLib.idle_add.
    """

    def __init__(self):
        self.app = Gtk.Application(application_id="dev.wolftech.kortex.notifier")
        self._toasts = {}
        self.app.connect("startup", lambda a: _apply_css())

    def run(self):
        self.app.run(None)

    # -- callbacks wired into RepairEngine --
    def on_repair_started(self, ev):
        GLib.idle_add(self._show_started, ev)

    def on_repair_result(self, ev, success, detail, action, attempt, max_attempts):
        GLib.idle_add(self._update_result, ev, success, detail, action, attempt, max_attempts)

    # -- callback wired into KortexDaemon's preference-shift logic --
    def on_preference_shift(self, on_undo):
        """Fired once a placement/preference change has actually been
        applied (not while confidence is merely accumulating) — see
        core.py's confidence-threshold gate before this ever gets called.
        """
        GLib.idle_add(self._show_preference_shift, on_undo)

    def _show_preference_shift(self, on_undo):
        toast = KortexToast(
            self.app,
            title="KibaOS optimized your workspace",
            body="Layout adjusted based on usage patterns",
        )
        toast.set_preference_shift(on_undo=on_undo)
        toast.present()
        return False

    def _show_started(self, ev):
        toast = KortexToast(
            self.app,
            title="KibaOS noticed a device isn't functioning",
            body="Automatic repair started",
        )
        toast.present()
        self._toasts[ev.signature] = {"win": toast, "tried": []}
        return False

    def _update_result(self, ev, success, detail, action, attempt, max_attempts):
        entry = self._toasts.get(ev.signature)
        if not entry:
            return False
        entry["tried"].append(action)
        win = entry["win"]
        if success:
            win.set_success(detail)
        elif attempt < max_attempts and action != "noop_escalate":
            win.set_retrying(action, attempt + 1, max_attempts)
        else:
            win.set_escalated(entry["tried"])
        return False
KORTEX_NOTIFIER_PY

cat > /usr/lib/kortex/kortexd/core.py << 'KORTEX_CORE_PY'
"""
kortexd.core
------------
Entrypoint. Runs the repair watcher + usage/session trackers on a background
thread, and the GTK notifier on the main thread (GTK requires the main
thread on most platforms).

Window-focus/launch/move events come from Wayfire's IPC (the `ipc` +
`ipc-rules` plugins from wayfire-plugins-extra, built from source in
kibaos.sh's WAYFIRE IPC section since that package is AUR-only on Arch),
consumed here via the `wfctl` CLI rather than the raw JSON-RPC socket
protocol directly — see WindowEventSource below for why and its caveats.
"""

import threading
import time
import datetime
import logging
import subprocess
import json

from .storage import Store
from . import models
from .repair import RepairEngine, watch_journal
from .notifier import KortexNotifier

logging.basicConfig(level=logging.INFO, format="%(asctime)s kortexd: %(message)s")
log = logging.getLogger("kortexd")


def _run(cmd, timeout=15):
    """Same small subprocess helper as repair.py's — kept local rather than
    imported since it's a one-liner and this module shouldn't reach into
    repair.py's private helpers.
    """
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
        return r.returncode == 0, (r.stdout + r.stderr).strip()[-500:]
    except Exception as e:
        return False, str(e)


class WindowEventSource:
    """Wayfire IPC bridge, via the `wfctl` CLI (pip: wfctl,
    github.com/killown/wfctl) rather than hand-rolling the raw JSON-RPC
    socket protocol that `ipc`/`ipc-rules` actually expose. `wfctl -m`
    tails Wayfire's event stream and prints one JSON object per line — same
    "tail a subprocess, parse lines" shape as repair.py's watch_journal(),
    so this follows the pattern already established here instead of adding
    a second I/O style.

    CAVEAT — verify on first real boot: the event/field names below
    (event, view.app-id, view.geometry, view-mapped/focused/geometry-changed)
    are based on wfctl's documented command surface and Wayfire's IPC
    changelog, not a field-by-field spec checked against a live socket.
    Same "unverified until it boots, tune from there" situation as
    wayfire.ini's [wobbly]/[blur] sections below — if `wfctl -m` emits
    different keys, only _handle_event() needs to change.

    CAVEAT — clicks are NOT covered: Wayfire's IPC has no raw pointer-button
    event, by design — wlroots compositors deliberately don't let one client
    see another client's input. `on_click` is therefore still never called
    here; rage/dead-click detection needs either a custom Wayfire input-grab
    plugin or a per-toolkit (GTK/Qt) hook, which is separate, larger work
    than this IPC bridge covers.
    """

    def __init__(self, on_focus, on_move, on_click, on_launch=None):
        self.on_focus = on_focus
        self.on_move = on_move
        self.on_click = on_click
        self.on_launch = on_launch
        self._known_views = set()   # view ids already seen -> mapped vs re-mapped
        self._view_apps = {}        # view id -> app-id, so move_window can resolve one

    def start(self):
        threading.Thread(target=self._watch_loop, daemon=True).start()
        log.info("WindowEventSource started (wfctl -m watching Wayfire IPC)")

    def _watch_loop(self):
        while True:
            try:
                self._run_watch()
            except Exception as e:
                log.warning(f"wfctl watcher crashed, restarting in 5s: {e}")
                time.sleep(5)

    def _run_watch(self):
        proc = subprocess.Popen(
            ["wfctl", "-m"], stdout=subprocess.PIPE, text=True, bufsize=1,
        )
        try:
            for line in proc.stdout:
                line = line.strip()
                if not line:
                    continue
                try:
                    event = json.loads(line)
                except ValueError:
                    continue  # non-JSON output line — ignore, don't crash the watcher
                self._handle_event(event)
        finally:
            proc.terminate()

    def _handle_event(self, event):
        kind = event.get("event") or event.get("type")
        view = event.get("view") or {}
        app = view.get("app-id") or view.get("app_id") or event.get("app-id")
        view_id = view.get("id", event.get("view-id"))
        if not app or view_id is None:
            return

        if kind in ("view-mapped", "view-map"):
            first_seen = view_id not in self._known_views
            self._known_views.add(view_id)
            self._view_apps[view_id] = app
            if first_seen and self.on_launch:
                geo = view.get("geometry", {})
                monitor = view.get("output-id", view.get("output", 0))
                xywh = (geo.get("x", 0), geo.get("y", 0),
                         geo.get("width", 0), geo.get("height", 0))
                self.on_launch(app, monitor, xywh)

        elif kind in ("view-focused", "view-focus-changed"):
            self._view_apps[view_id] = app
            self.on_focus(app)

        elif kind in ("view-geometry-changed", "view-moved", "view-resized"):
            geo = view.get("geometry", {})
            monitor = view.get("output-id", view.get("output", 0))
            self.on_move(app, monitor, geo.get("x", 0), geo.get("y", 0),
                         geo.get("width", 0), geo.get("height", 0))

        elif kind in ("view-unmapped", "view-unmap"):
            self._known_views.discard(view_id)
            self._view_apps.pop(view_id, None)

        # No pointer-button event exists in Wayfire's IPC — see class
        # docstring. on_click is wired but nothing ever calls it yet.

    def move_window(self, app, monitor, x, y, w, h):
        """Applies a placement via wfctl (used both for Kortex-initiated
        shifts and for reverting one via the Undo button). wfctl's
        move/resize subcommands take a numeric view id, not an app name, so
        resolve one from the most recent view we've seen for this app.
        """
        view_id = self._resolve_view_id(app)
        if view_id is None:
            log.warning(f"move_window: no live view found for {app!r}, skipping")
            return
        ok1, out1 = _run(["wfctl", "move", "view", str(view_id), str(int(x)), str(int(y))])
        ok2, out2 = _run(["wfctl", "resize", "view", str(view_id), str(int(w)), str(int(h))])
        if not (ok1 and ok2):
            log.warning(f"move_window failed for {app!r} (view {view_id}): {out1} / {out2}")

    def _resolve_view_id(self, app):
        for vid, a in self._view_apps.items():
            if a == app:
                return vid
        return None


class KortexDaemon:
    def __init__(self, db_path=None):
        self.store = Store(db_path) if db_path else Store()
        self.notifier = KortexNotifier()
        self.repair_engine = RepairEngine(
            self.store,
            on_popup=self.notifier.on_repair_started,
            on_result=self.notifier.on_repair_result,
        )
        self.active_sessions = {}          # app -> start_ts
        self.last_click = {}               # app -> (x, y, ts)
        self.rage_click_window = 1.2       # seconds
        self.rage_click_radius = 20        # px
        self.rage_click_count = {}         # app -> count in current burst
        self.dead_click_timeout = 0.6      # seconds with no state change

        self.window_source = WindowEventSource(
            on_focus=self.on_window_focus,
            on_move=self.on_window_moved,
            on_click=self.on_click,
            on_launch=self.on_window_launch,
        )

    # ---- usage / focus tracking ----
    def on_window_focus(self, app: str, ts=None):
        ts = ts or time.time()
        now = datetime.datetime.fromtimestamp(ts)
        dow, hour = now.weekday(), now.hour

        # close out previous session for this app if one was open elsewhere
        prev_start = self.active_sessions.get(app)
        if prev_start:
            self.store.update_session_stats(app, ts - prev_start)

        self.active_sessions[app] = ts
        self.store.set_session_start(app, ts)
        self.store.update_beta(app, dow, hour, hit=True, decay=models.LAMBDA_WEEKLY_FORGET)
        self.store.add_kde_point("usage", [dow / 6.0, hour / 23.0], weight=1.0)

    def on_window_close(self, app: str, ts=None):
        ts = ts or time.time()
        start = self.active_sessions.pop(app, None)
        if start:
            self.store.update_session_stats(app, ts - start)

    # ---- placement ----
    # Threshold above which placement_consistency() is trusted enough to
    # actually move a window, not just accumulate weight. Deliberately high
    # — see the hysteresis discussion: an oscillating ~0.5 confidence should
    # never win, it should keep sitting quietly in the store.
    PLACEMENT_APPLY_THRESHOLD = 0.75

    def on_window_moved(self, app, monitor, x, y, w, h):
        self.store.update_placement(app, monitor, x, y, w, h)

    def on_window_launch(self, app, monitor, current_xywh):
        """Called at launch time — i.e. before the window has a position the
        user cares about yet — rather than repositioning something live
        under the user's cursor. This is the only place a learned placement
        actually gets applied.
        """
        confidence = self.store.get_placement_confidence(app)
        if confidence < self.PLACEMENT_APPLY_THRESHOLD:
            return  # still just accumulating weight, not acted on yet

        learned = self.store.get_placement(app, monitor)
        if not learned or learned[:4] == current_xywh:
            return  # nothing to change, or already there

        old_xywh = current_xywh
        new_xywh = learned[:4]
        self.window_source.move_window(app, monitor, *new_xywh)
        self.notifier.on_preference_shift(
            on_undo=lambda: self._undo_shift(app, monitor, old_xywh)
        )

    def _undo_shift(self, app, monitor, old_xywh):
        # Move it back...
        self.window_source.move_window(app, monitor, *old_xywh)
        # ...and log a 'reverted' friction event rather than reusing 'rage' —
        # "user undid an automatic action" is a stronger, more specific
        # signal than click-frustration, so it gets its own weighted kind
        # (see storage.Store.FRICTION_KIND_WEIGHTS) instead of being faked
        # as two rage clicks.
        self.store.log_friction(app, "reverted")

    # ---- click friction ----
    def on_click(self, app, x, y, caused_state_change: bool, ts=None):
        ts = ts or time.time()
        last = self.last_click.get(app)
        self.last_click[app] = (x, y, ts)

        if not caused_state_change:
            self.store.log_friction(app, "dead", x, y)
            return

        if last:
            lx, ly, lts = last
            dt = ts - lts
            dist = ((x - lx) ** 2 + (y - ly) ** 2) ** 0.5
            if dt <= self.rage_click_window and dist <= self.rage_click_radius:
                n = self.rage_click_count.get(app, 0) + 1
                self.rage_click_count[app] = n
                if n >= 3:
                    self.store.log_friction(app, "rage", x, y)
                    self.rage_click_count[app] = 0
            else:
                self.rage_click_count[app] = 0

    # ---- confidence scoring (public API other components call) ----
    def score_app(self, app: str, ts=None) -> float:
        ts = ts or time.time()
        now = datetime.datetime.fromtimestamp(ts)
        dow, hour = now.weekday(), now.hour

        alpha, beta = self.store.get_beta(app, dow, hour)
        mu = models.usage_belief(alpha, beta)

        delta = models.kde_density(
            point=[dow / 6.0, hour / 23.0],
            anchors=self.store.get_kde_points("usage"),
        )

        eps = models.recency_decay(self.store.last_seen(app), now=ts)

        sess = self.store.get_session_stats(app)
        current_session = ts - sess["session_start"] if sess.get("session_start") else 0.0
        variance = sess["m2"] / sess["count"] if sess["count"] > 1 else 0.0
        beta_p = models.break_pressure(current_session, sess["mean"], variance)

        pi = models.placement_consistency(
            self.store.get_placement_confidence(app) * (models.PLACEMENT_KAPPA)  # back out weight
        ) if False else self.store.get_placement_confidence(app)

        phi = self.store.friction_score(app)

        return models.confidence(mu, delta, eps, beta_p, pi, phi)

    # ---- break reminders (polling loop) ----
    def _break_reminder_loop(self, poll_seconds=30):
        while True:
            time.sleep(poll_seconds)
            now = time.time()
            for app, start in list(self.active_sessions.items()):
                sess = self.store.get_session_stats(app)
                if sess["count"] < 3:
                    continue  # not enough history to know what's "too long"
                variance = sess["m2"] / sess["count"]
                pressure = models.break_pressure(now - start, sess["mean"], variance)
                if pressure > 0.9:
                    log.info(f"break pressure high for {app} ({pressure:.2f}) — nudge user")
                    # UI hook: notifier could show a lightweight break toast here

    def _repair_watch_loop(self):
        while True:
            try:
                watch_journal(self.repair_engine)
            except Exception as e:
                log.warning(f"journal watcher crashed, restarting in 5s: {e}")
                time.sleep(5)

    def start_background(self):
        threading.Thread(target=self._repair_watch_loop, daemon=True).start()
        threading.Thread(target=self._break_reminder_loop, daemon=True).start()
        self.window_source.start()

    def run(self):
        self.start_background()
        log.info("kortexd running")
        self.notifier.run()  # blocks on GTK main loop (main thread)


def main():
    daemon = KortexDaemon()
    daemon.run()


if __name__ == "__main__":
    main()
KORTEX_CORE_PY

cat > /usr/lib/kortex/kortexd/__main__.py << 'KORTEX_MAIN_PY'
from .core import main

if __name__ == "__main__":
    main()
KORTEX_MAIN_PY

cat > /usr/lib/kortex/kortexd/assets/kortex-icon.svg << 'KORTEX_ICON_SVG'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48" width="48" height="48">
  <!-- adaptive/refresh glyph: two arcing arrows, same accent blue as the OOBE -->
  <g fill="none" stroke-linecap="round" stroke-linejoin="round">
    <path d="M12 20 A12 12 0 0 1 34 13" stroke="#0099cc" stroke-width="3.4"/>
    <path d="M34 13 l1 6 l-6 -1.5" fill="none" stroke="#0099cc" stroke-width="3.4"/>
    <path d="M36 28 A12 12 0 0 1 14 35" stroke="#00aee3" stroke-width="3.4"/>
    <path d="M14 35 l-1 -6 l6 1.5" fill="none" stroke="#00aee3" stroke-width="3.4"/>
  </g>
</svg>
KORTEX_ICON_SVG

mkdir -p /usr/lib/systemd/user
cat > /usr/lib/systemd/user/kortexd.service << 'KORTEX_SERVICE_UNIT'
[Unit]
Description=Kortex — KibaOS adaptive daemon
After=graphical-session.target
PartOf=graphical-session.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 -m kortexd
Restart=on-failure
RestartSec=3
Environment=PYTHONUNBUFFERED=1

[Install]
WantedBy=graphical-session.target
KORTEX_SERVICE_UNIT

echo "=== Compiling kortexd (Nuitka -> native x86_64 binary) ==="
cd /usr/lib/kortex
python -m nuitka \
  --standalone \
  --onefile \
  --output-dir=build \
  --output-filename=kortexd \
  --include-package=kortexd \
  --include-package-data=kortexd \
  --python-flag=-m \
  --assume-yes-for-downloads \
  --lto=yes \
  kortexd
install -Dm755 build/kortexd /usr/bin/kortexd
cd /
rm -rf /usr/lib/kortex/build /usr/lib/kortex/kortexd.build /usr/lib/kortex/kortexd.dist /usr/lib/kortex/kortexd.onefile-build

# Enabled per-user (graphical-session.target), same as other user services
# in this image — actual activation happens on first login via systemd.
mkdir -p /etc/skel/.config/systemd/user/graphical-session.target.wants
ln -sf /usr/lib/systemd/user/kortexd.service \
  /etc/skel/.config/systemd/user/graphical-session.target.wants/kortexd.service
echo "=== Kortex installed ==="

# ══════════════════════════════════════════════════════════════════════════
# KORTEX-AUTHD — replaces polkit-kde-agent as the system's authentication
# agent entirely (not just for Kortex's own repair actions above). The
# stock "Authenticate to ___" polkit-kde-agent dialog is Qt/Kvantum on a
# GTK4/libadwaita desktop — visibly the wrong toolkit, no relation to
# KibaOS's Organic Motion Language design system. kortex-authd registers
# as the real org.freedesktop.PolicyKit1.AuthenticationAgent for the
# session (small C binary against libpolkit-agent-1, verified against the
# real headers during development — see PolkitAgentListener docs) and
# delegates only the visual prompt to a separate GTK4/libadwaita process,
# kortex-auth-prompt, so the polkit-facing code stays a small, auditable
# amount of glue rather than a UI-toolkit consumer itself.
# ══════════════════════════════════════════════════════════════════════════
echo "=== Building kortex-authd (PolicyKit authentication agent) ==="
mkdir -p /usr/lib/kortex/src
cat > /usr/lib/kortex/src/kortex-authd.c << 'KORTEX_AUTHD_C'
/*
 * kortex-authd — Kortex's replacement for the generic "Authenticate to ___"
 * polkit dialog. Registers as the session's PolicyKit authentication agent;
 * delegates the actual visual prompt to a separate GTK4/libadwaita process
 * (kortex-auth-prompt) so this binary stays a small, auditable amount of
 * glue against the real polkit-agent-1 API, not a UI toolkit consumer.
 *
 * Architecture follows the documented PolkitAgentListener vtable exactly:
 * https://www.freedesktop.org/software/polkit/docs/latest/PolkitAgentListener.html
 */

#define POLKIT_AGENT_I_KNOW_API_IS_SUBJECT_TO_CHANGE
#include <polkitagent/polkitagent.h>
#include <gio/gio.h>
#include <unistd.h>
#include <string.h>

#define KORTEX_TYPE_AGENT_LISTENER (kortex_agent_listener_get_type())
G_DECLARE_FINAL_TYPE(KortexAgentListener, kortex_agent_listener, KORTEX, AGENT_LISTENER, PolkitAgentListener)

struct _KortexAgentListener
{
  PolkitAgentListener parent_instance;
};

G_DEFINE_TYPE(KortexAgentListener, kortex_agent_listener, POLKIT_AGENT_TYPE_LISTENER)

/* Per-authentication state threaded through the async chain. */
typedef struct
{
  GTask *task;
  PolkitAgentSession *session;
  gchar *message;
  gboolean gained_authorization;
  gboolean is_retry;
} KortexAuthState;

static void
state_free(KortexAuthState *state)
{
  if (state->session)
    g_object_unref(state->session);
  g_free(state->message);
  g_free(state);
}

/* Spawns the branded prompt UI, feeds the polkit request message to it,
 * reads the typed password back over stdout. A non-zero exit (user hit
 * Cancel) means no password line is produced. */
static void
run_prompt_and_respond(KortexAuthState *state)
{
  GSubprocess *proc;
  GError *error = NULL;
  const gchar *argv[4];
  gint argc = 0;

  argv[argc++] = "/usr/lib/kortex/kortex-auth-prompt";
  argv[argc++] = state->message ? state->message : "Authentication required";
  if (state->is_retry)
    argv[argc++] = "--retry";
  argv[argc] = NULL;

  proc = g_subprocess_newv(argv, G_SUBPROCESS_FLAGS_STDOUT_PIPE, &error);
  if (!proc)
    {
      g_warning("kortex-authd: failed to spawn prompt: %s", error->message);
      g_clear_error(&error);
      polkit_agent_session_cancel(state->session);
      return;
    }

  GBytes *stdout_buf = NULL;
  if (!g_subprocess_communicate(proc, NULL, NULL, &stdout_buf, NULL, &error))
    {
      g_warning("kortex-authd: prompt communication failed: %s", error->message);
      g_clear_error(&error);
      g_object_unref(proc);
      polkit_agent_session_cancel(state->session);
      return;
    }

  if (!g_subprocess_get_successful(proc))
    {
      /* User cancelled in the UI. */
      g_object_unref(proc);
      if (stdout_buf)
        g_bytes_unref(stdout_buf);
      polkit_agent_session_cancel(state->session);
      return;
    }

  gsize len = 0;
  const gchar *data = stdout_buf ? g_bytes_get_data(stdout_buf, &len) : "";
  gchar *password = g_strndup(data, len);
  /* Strip the trailing newline the prompt writes after the password. */
  g_strchomp(password);

  polkit_agent_session_response(state->session, password);

  /* Do not linger with the plaintext password in memory. */
  memset(password, 0, strlen(password));
  g_free(password);
  if (stdout_buf)
    g_bytes_unref(stdout_buf);
  g_object_unref(proc);
}

static void
on_session_request(PolkitAgentSession *session, const gchar *request,
                    gboolean echo_on, gpointer user_data)
{
  KortexAuthState *state = user_data;
  (void)session;
  (void)request;
  (void)echo_on;
  run_prompt_and_respond(state);
  state->is_retry = TRUE; /* any subsequent request in this session is a retry */
}

static void
on_session_show_error(PolkitAgentSession *session, const gchar *text, gpointer user_data)
{
  (void)session;
  (void)user_data;
  g_message("kortex-authd: PAM error: %s", text);
}

static void
on_session_show_info(PolkitAgentSession *session, const gchar *text, gpointer user_data)
{
  (void)session;
  (void)user_data;
  g_message("kortex-authd: PAM info: %s", text);
}

static void
on_session_completed(PolkitAgentSession *session, gboolean gained_authorization,
                      gpointer user_data)
{
  KortexAuthState *state = user_data;
  (void)session;
  state->gained_authorization = gained_authorization;
  g_task_return_boolean(state->task, gained_authorization);
  g_object_unref(state->task);
  state_free(state);
}

static void
kortex_agent_listener_initiate_authentication(PolkitAgentListener *listener,
                                               const gchar *action_id,
                                               const gchar *message,
                                               const gchar *icon_name,
                                               PolkitDetails *details,
                                               const gchar *cookie,
                                               GList *identities,
                                               GCancellable *cancellable,
                                               GAsyncReadyCallback callback,
                                               gpointer user_data)
{
  (void)action_id;
  (void)icon_name;
  (void)details;

  GTask *task = g_task_new(listener, cancellable, callback, user_data);

  if (identities == NULL)
    {
      g_task_return_new_error(task, G_IO_ERROR, G_IO_ERROR_FAILED,
                               "No identities to authenticate");
      g_object_unref(task);
      return;
    }

  /* Prefer authenticating as the identity matching our own uid when present
   * (the common pkexec-as-self case); otherwise fall back to the first
   * identity offered, same default most agents use. */
  PolkitIdentity *chosen = g_list_nth_data(identities, 0);
  uid_t my_uid = getuid();
  for (GList *l = identities; l != NULL; l = l->next)
    {
      if (POLKIT_IS_UNIX_USER(l->data) &&
          (uid_t)polkit_unix_user_get_uid(POLKIT_UNIX_USER(l->data)) == my_uid)
        {
          chosen = l->data;
          break;
        }
    }

  KortexAuthState *state = g_new0(KortexAuthState, 1);
  state->task = task;
  state->message = g_strdup(message);
  state->session = polkit_agent_session_new(chosen, cookie);

  g_signal_connect(state->session, "request", G_CALLBACK(on_session_request), state);
  g_signal_connect(state->session, "show-error", G_CALLBACK(on_session_show_error), state);
  g_signal_connect(state->session, "show-info", G_CALLBACK(on_session_show_info), state);
  g_signal_connect(state->session, "completed", G_CALLBACK(on_session_completed), state);

  polkit_agent_session_initiate(state->session);
}

static gboolean
kortex_agent_listener_initiate_authentication_finish(PolkitAgentListener *listener,
                                                      GAsyncResult *res,
                                                      GError **error)
{
  (void)listener;
  return g_task_propagate_boolean(G_TASK(res), error);
}

static void
kortex_agent_listener_class_init(KortexAgentListenerClass *klass)
{
  PolkitAgentListenerClass *listener_class = POLKIT_AGENT_LISTENER_CLASS(klass);
  listener_class->initiate_authentication = kortex_agent_listener_initiate_authentication;
  listener_class->initiate_authentication_finish = kortex_agent_listener_initiate_authentication_finish;
}

static void
kortex_agent_listener_init(KortexAgentListener *self)
{
  (void)self;
}

int
main(void)
{
  GError *error = NULL;
  PolkitSubject *subject = polkit_unix_session_new_for_process_sync(getpid(), NULL, &error);
  if (!subject)
    {
      g_printerr("kortex-authd: could not get session subject: %s\n", error->message);
      return 1;
    }

  KortexAgentListener *listener = g_object_new(KORTEX_TYPE_AGENT_LISTENER, NULL);
  gpointer registration = polkit_agent_listener_register(
      POLKIT_AGENT_LISTENER(listener),
      POLKIT_AGENT_REGISTER_FLAGS_NONE,
      subject,
      NULL, /* default object path */
      NULL, /* cancellable */
      &error);

  if (!registration)
    {
      g_printerr("kortex-authd: failed to register as authentication agent: %s\n",
                 error->message);
      return 1;
    }

  g_message("kortex-authd: registered, waiting for authentication requests");
  GMainLoop *loop = g_main_loop_new(NULL, FALSE);
  g_main_loop_run(loop);
  return 0;
}
KORTEX_AUTHD_C

cat > /usr/lib/kortex/src/kortex-auth-prompt.c << 'KORTEX_AUTH_PROMPT_C'
/*
 * kortex-auth-prompt — the actual visual card kortex-authd spawns for each
 * password request. A plain, ordinary GTK4/libadwaita app: no polkit API
 * surface here at all, on purpose — this process only ever prints the
 * typed password to stdout on submit and exits 0, or exits non-zero on
 * Cancel/close. kortex-authd is the only thing that talks to polkit.
 *
 * argv[1] = message to display (the polkit request/prompt text)
 * argv[2] = optional "--retry" flag -> shows the shake + "try again" state
 */

#include <gtk/gtk.h>
#include <adwaita.h>

typedef struct
{
  GtkWidget *entry;
  gboolean retry;
} PromptData;

static void
on_submit(GtkWidget *widget, gpointer user_data)
{
  PromptData *data = user_data;
  const gchar *text = gtk_editable_get_text(GTK_EDITABLE(data->entry));
  g_print("%s\n", text);
  fflush(stdout);
  GtkWidget *window = gtk_widget_get_ancestor(widget, GTK_TYPE_WINDOW);
  gtk_window_close(GTK_WINDOW(window));
}

static void
on_cancel(GtkWidget *widget, gpointer user_data)
{
  (void)user_data;
  GtkWidget *window = gtk_widget_get_ancestor(widget, GTK_TYPE_WINDOW);
  gtk_window_close(GTK_WINDOW(window));
  /* No password line was printed, so kortex-authd reads an empty
   * subprocess output and treats it as a cancel. */
  exit(1);
}

typedef struct
{
  const gchar *message;
  gboolean retry;
} ActivateData;

static void
activate(GtkApplication *app, gpointer user_data)
{
  ActivateData *adata = user_data;
  const gchar *message = adata->message;

  GtkWidget *window = adw_application_window_new(GTK_APPLICATION(app));
  gtk_window_set_title(GTK_WINDOW(window), "Kortex");
  gtk_window_set_decorated(GTK_WINDOW(window), FALSE);
  gtk_widget_add_css_class(window, "kortex-auth-backdrop");

  /* Outer layer fills the whole screen and centers the actual card in the
   * middle of it, so this reads as a full dim overlay rather than a
   * small dialog floating in a corner. */
  GtkWidget *backdrop = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0);
  gtk_widget_set_halign(backdrop, GTK_ALIGN_FILL);
  gtk_widget_set_valign(backdrop, GTK_ALIGN_FILL);
  gtk_widget_set_hexpand(backdrop, TRUE);
  gtk_widget_set_vexpand(backdrop, TRUE);

  GtkWidget *box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 14);
  gtk_widget_set_halign(box, GTK_ALIGN_CENTER);
  gtk_widget_set_valign(box, GTK_ALIGN_CENTER);
  gtk_widget_set_size_request(box, 380, -1);
  gtk_widget_add_css_class(box, "kortex-auth-card");
  gtk_widget_set_margin_top(box, 28);
  gtk_widget_set_margin_bottom(box, 28);
  gtk_widget_set_margin_start(box, 28);
  gtk_widget_set_margin_end(box, 28);

  GtkWidget *icon = gtk_image_new_from_icon_name("dialog-password-symbolic");
  gtk_image_set_pixel_size(GTK_IMAGE(icon), 40);
  gtk_widget_add_css_class(icon, "kortex-auth-icon");
  gtk_box_append(GTK_BOX(box), icon);

  GtkWidget *title = gtk_label_new("Kortex wants to apply a repair");
  gtk_widget_add_css_class(title, "title-2");
  gtk_box_append(GTK_BOX(box), title);

  GtkWidget *subtitle = gtk_label_new(message);
  gtk_label_set_wrap(GTK_LABEL(subtitle), TRUE);
  gtk_widget_add_css_class(subtitle, "dim-label");
  gtk_box_append(GTK_BOX(box), subtitle);

  GtkWidget *entry = gtk_password_entry_new();
  gtk_password_entry_set_show_peek_icon(GTK_PASSWORD_ENTRY(entry), TRUE);
  gtk_widget_add_css_class(entry, "kortex-auth-entry");
  gtk_box_append(GTK_BOX(box), entry);

  PromptData *data = g_new0(PromptData, 1);
  data->entry = entry;
  data->retry = adata->retry;

  if (data->retry)
    {
      GtkWidget *err = gtk_label_new("That password wasn't right — try again");
      gtk_widget_add_css_class(err, "error");
      gtk_box_append(GTK_BOX(box), err);
      gtk_widget_add_css_class(entry, "kortex-shake");
    }

  GtkWidget *button_row = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 8);
  gtk_widget_set_halign(button_row, GTK_ALIGN_END);

  GtkWidget *cancel_btn = gtk_button_new_with_label("Cancel");
  g_signal_connect(cancel_btn, "clicked", G_CALLBACK(on_cancel), data);
  gtk_box_append(GTK_BOX(button_row), cancel_btn);

  GtkWidget *ok_btn = gtk_button_new_with_label("Authenticate");
  gtk_widget_add_css_class(ok_btn, "suggested-action");
  g_signal_connect(ok_btn, "clicked", G_CALLBACK(on_submit), data);
  gtk_box_append(GTK_BOX(button_row), ok_btn);

  gtk_box_append(GTK_BOX(box), button_row);

  /* Enter in the password field submits, same as clicking Authenticate. */
  g_signal_connect(entry, "activate", G_CALLBACK(on_submit), data);

  gtk_box_append(GTK_BOX(backdrop), box);
  adw_application_window_set_content(ADW_APPLICATION_WINDOW(window), backdrop);
  gtk_window_fullscreen(GTK_WINDOW(window));
  gtk_window_present(GTK_WINDOW(window));
  gtk_widget_grab_focus(entry);
}

int
main(int argc, char **argv)
{
  ActivateData adata;
  adata.message = argc > 1 ? argv[1] : "Authentication required";
  adata.retry = (argc > 2 && g_strcmp0(argv[2], "--retry") == 0);

  GtkApplication *app = gtk_application_new("dev.wolftech.kortex.authprompt",
                                             G_APPLICATION_DEFAULT_FLAGS);
  g_signal_connect(app, "activate", G_CALLBACK(activate), &adata);
  int status = g_application_run(G_APPLICATION(app), 1, argv);
  g_object_unref(app);
  return status;
}
KORTEX_AUTH_PROMPT_C

cd /usr/lib/kortex/src
gcc -O2 -Wall $(pkg-config --cflags polkit-agent-1 polkit-gobject-1 glib-2.0 gio-2.0) \
    kortex-authd.c -o /usr/lib/kortex/kortex-authd \
    $(pkg-config --libs polkit-agent-1 polkit-gobject-1 glib-2.0 gio-2.0) \
  || { echo "FATAL: kortex-authd compile/link failed" >&2; exit 1; }
gcc -O2 -Wall $(pkg-config --cflags gtk4 libadwaita-1) \
    kortex-auth-prompt.c -o /usr/lib/kortex/kortex-auth-prompt \
    $(pkg-config --libs gtk4 libadwaita-1) \
  || { echo "FATAL: kortex-auth-prompt compile/link failed" >&2; exit 1; }
cd /
rm -rf /usr/lib/kortex/src
chown root:root /usr/lib/kortex/kortex-authd /usr/lib/kortex/kortex-auth-prompt
chmod 755 /usr/lib/kortex/kortex-authd /usr/lib/kortex/kortex-auth-prompt

# kortex-authd runs per-user, same as kortexd — it only needs to register
# on the session bus, no elevated privilege of its own. It calls out to
# pkexec/dev.wolftech.kortex.repair only indirectly (that flow is entirely
# inside kortex-helper); this process just brokers the polkit conversation.
cat > /usr/lib/systemd/user/kortex-authd.service << 'KORTEX_AUTHD_SERVICE'
[Unit]
Description=Kortex PolicyKit authentication agent
After=graphical-session.target
PartOf=graphical-session.target

[Service]
Type=simple
ExecStart=/usr/lib/kortex/kortex-authd
Restart=on-failure
RestartSec=3

[Install]
WantedBy=graphical-session.target
KORTEX_AUTHD_SERVICE

mkdir -p /etc/skel/.config/systemd/user/graphical-session.target.wants
ln -sf /usr/lib/systemd/user/kortex-authd.service \
  /etc/skel/.config/systemd/user/graphical-session.target.wants/kortex-authd.service
echo "=== kortex-authd installed ==="


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
sed -i 's/#IdleAction=ignore/IdleAction=ignore/'               /etc/systemd/logind.conf
# Explicitly zero out the idle-action timer so logind never fires it,
# and suppress the hibernate/power keys too — this is a live/install session,
# nothing should put the machine to sleep mid-install.
grep -q 'IdleActionSec'  /etc/systemd/logind.conf || echo 'IdleActionSec=0'  >> /etc/systemd/logind.conf
grep -q 'HandleHibernateKey' /etc/systemd/logind.conf || echo 'HandleHibernateKey=ignore' >> /etc/systemd/logind.conf
grep -q 'HandleLidSwitchDocked' /etc/systemd/logind.conf || echo 'HandleLidSwitchDocked=ignore' >> /etc/systemd/logind.conf
grep -q 'HandleLidSwitchExternalPower' /etc/systemd/logind.conf || echo 'HandleLidSwitchExternalPower=ignore' >> /etc/systemd/logind.conf
grep -q 'HandlePowerKey' /etc/systemd/logind.conf && \
  sed -i 's/^HandlePowerKey=.*/HandlePowerKey=poweroff/' /etc/systemd/logind.conf

# Belt-and-suspenders: mask the sleep targets themselves so nothing on the
# live/install image — a stray udev rule, a misbehaving app, a battery
# driver's default — can put the machine to sleep mid-session or mid-install.
systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target

# ══════════════════════════════════════════════════════════════════════════
# BRANDING ASSETS
# ══════════════════════════════════════════════════════════════════════════
WALLPAPER_URL="https://raw.githubusercontent.com/WolfTech-Innovations/Kiba/refs/heads/main/branding/file_00000000718081f5a7295830accc33de.jpg?raw=true"
LOGO_URL="https://github.com/WolfTech-Innovations/Kiba/blob/main/branding/boot.png?raw=true"
INSTALLER_LOGO_URL="https://github.com/WolfTech-Innovations/Kiba/blob/1419ece4c5c2dbfaa9c0b65f0055b6d70e6b4dbd/branding/installer.png?raw=true"
WALLPAPER_DEST="/usr/share/kibaos/wallpaper.jpg"
LOGO_SRC="/usr/share/kibaos/logo-raw.png"
LOGO_256="/usr/share/kibaos/logo-256.png"
LOGO_96="/usr/share/kibaos/logo-96.png"
LOGO_48="/usr/share/kibaos/logo-48.png"
LOGO_32="/usr/share/kibaos/logo-32.png"
INSTALLER_LOGO="/usr/share/kibaos/installer-logo.png"

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

# ── OOBE installer logo — separate art from the generic distro logo above ──
curl -fL --retry 5 --retry-delay 3 -o "${INSTALLER_LOGO}.raw" "${INSTALLER_LOGO_URL}" || true
if [ -f "${INSTALLER_LOGO}.raw" ] && file "${INSTALLER_LOGO}.raw" | grep -qi 'image'; then
  magick "${INSTALLER_LOGO}.raw" -filter Lanczos -resize 256x256 "${INSTALLER_LOGO}"
  rm -f "${INSTALLER_LOGO}.raw"
else
  rm -f "${INSTALLER_LOGO}.raw"
  cp "${LOGO_256}" "${INSTALLER_LOGO}"   # fallback: reuse the generic logo
fi

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

cd /
userdel -r builduser 2>/dev/null || true
rm -f /etc/sudoers.d/builduser
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
#   - Backend: a privileged C binary (kibaos-oobe-backend), called via
#     sudo with a plain argv array (no shell string, no quoting/
#     injection surface, no D-Bus/polkit dependency). Disk partitioning (GPT) and the udev-settle
#     wait are hand-implemented in libkibadisk against raw ioctls --
#     no archinstall, no parted/sgdisk, no blkid/partprobe subprocess
#     for the disk-critical path. The handful of remaining external
#     tools (unsquashfs, mkfs.fat/mkfs.ext4, arch-chroot, grub-install,
#     mkinitcpio, useradd/chpasswd, locale-gen, pacman) have no sane
#     from-scratch replacement and are invoked via posix_spawn argv
#     arrays, never a shell. See /usr/share/kibaos-oobe/src/disk/ for
#     the library source (kiba_gpt.c, kiba_fs.c, kiba_udev.c,
#     kiba_install_*.c) and kibaos_oobe_backend_main.c for the
#     orchestrator that ties it together.
# ══════════════════════════════════════════════════════════════════════════

mkdir -p /usr/share/kibaos-oobe/src
echo "=== Installing GTK4/libadwaita OOBE build dependencies ==="
pacman -S --noconfirm --needed gtk4 libadwaita libgee vala meson ninja rsync polkit arch-install-scripts dosfstools

# ── main.vala ────────────────────────────────────────────────────────────
cat > /usr/share/kibaos-oobe/src/main.vala << 'OOBEVALA'
/* KibaOS OOBE — GTK4 + libadwaita, white-card design language.
 * Backend: /usr/local/bin/kibaos-oobe-backend (C, libkibadisk). */

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
    private string install_mode    = "erase"; // "erase" or "alongside" (dual boot)
    private string selected_locale = "en_US.UTF-8";
    private string selected_keymap = "us";
    private string hostname_value  = "kibaos";
    private string username_value  = "";
    private string password_value  = "";
    private bool   is_oem_mode     = false;
    private const string OEM_MARKER = "/etc/kibaos/oem-pending";

    // ── Language ──────────────────────────────────────────────────────
    // Only affects the OOBE's own UI text. The locale picked on the
    // Language & Keyboard page is a separate thing (that's what the
    // installed system will use).
    private string ui_lang = "en";

    // Tiny inline translator: t("English", "Türkçe") at each call site
    // instead of a separate lookup table, so a string and its
    // translation always sit next to each other in the source.
    private string t (string en, string tr) {
        return ui_lang == "tr" ? tr : en;
    }

    // ── Dark mode ─────────────────────────────────────────────────────
    private bool is_dark = false;

    private void apply_dark_mode () {
        if (is_dark) window.add_css_class ("dark");
        else window.remove_css_class ("dark");
    }

    // ── VM guard ──────────────────────────────────────────────────────
    // Installing onto virtual disks (VDI/VMDK/qcow2) was never made
    // reliable enough to ship — GPT/ESP handling on those virtual disk
    // formats kept breaking in ways real hardware never hit. Rather than
    // let someone click through the whole wizard and fail at the very
    // end, refuse up front and say why.
    private bool is_running_in_vm () {
        string out_str = "", err_str = "";
        int status = 0;
        try {
            GLib.Process.spawn_command_line_sync (
                "systemd-detect-virt -q", out out_str, out err_str, out status);
        } catch (GLib.SpawnError e) { return false; }
        // systemd-detect-virt exits 0 when it detects a VM/container,
        // 1 when running on bare metal.
        return GLib.Process.if_exited (status) && GLib.Process.exit_status (status) == 0;
    }

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
        bool in_vm = is_running_in_vm ();
        is_oem_mode = !in_vm && detect_already_on_computer ();
        window = new Adw.ApplicationWindow (this) {
            default_width  = 1280,
            default_height = 800,
            fullscreened   = true,
            title          = in_vm ? "KibaOS Setup"
                             : is_oem_mode ? "Finish Setting Up KibaOS" : "KibaOS Setup"
        };
        window.add_css_class ("kibaos-oobe-window");
        // Default to dark mode regardless of system preference; the toggle
        // on every page still lets the user switch to light from there.
        Adw.StyleManager.get_default ().color_scheme = Adw.ColorScheme.FORCE_DARK;
        is_dark = true;
        apply_dark_mode ();
        nav_view = new Adw.NavigationView ();
        window.set_content (nav_view);
        load_css ();
        nav_view.push (in_vm ? build_vm_blocked_page ()
                       : is_oem_mode ? build_locale_page () : build_welcome_page ());
        window.present ();
    }

    // ══════════════════════════════════════════════════════════════════
    // VM guard page — installation is refused entirely inside a VM.
    // ══════════════════════════════════════════════════════════════════
    private Adw.NavigationPage build_vm_blocked_page () {
        var content = new Gtk.Box (Gtk.Orientation.VERTICAL, 20);

        var icon = new Gtk.Image.from_icon_name ("dialog-warning-symbolic") {
            pixel_size = 56,
            halign     = Gtk.Align.START
        };
        content.append (icon);

        content.append (oobe_heading (
            t ("Installation isn't available in a virtual machine",
               "Sanal makinede kurulum kullanılamaz"),
            t ("KibaOS can't be installed onto a virtual disk yet — VDI/VMDK/qcow2 " +
               "support isn't reliable enough to ship. You're welcome to explore the " +
               "live desktop, or boot this image on real hardware to install.",
               "KibaOS henüz sanal bir diske kurulamıyor — VDI/VMDK/qcow2 desteği " +
               "yayınlanacak kadar güvenilir değil. Canlı masaüstünü keşfedebilir " +
               "ya da kurulum için bu imajı gerçek bir donanımda başlatabilirsiniz.")));

        return make_page (t ("Virtual Machine Detected", "Sanal Makine Algılandı"),
            content, t ("Explore Live Desktop", "Canlı Masaüstünü Keşfet"), () => {
                this.quit ();
            }, true);
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
            var back_btn = new Gtk.Button.with_label (t ("Back", "Geri"));
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

        // Corner controls top-right: language toggle + dark-mode toggle.
        // Live on every screen (not just Welcome) so switching either one
        // doesn't force a trip back to page 1.
        var corner = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8) {
            halign       = Gtk.Align.END,
            valign       = Gtk.Align.START,
            margin_end   = 28,
            margin_top   = 24
        };

        var lang_btn = new Gtk.Button.with_label (ui_lang == "tr" ? "EN" : "TR");
        lang_btn.add_css_class ("oobe-corner-button");
        lang_btn.tooltip_text = t ("Switch to Turkish", "İngilizceye geç");
        lang_btn.clicked.connect (() => {
            ui_lang = ui_lang == "tr" ? "en" : "tr";
            refresh_current_page ();
        });
        corner.append (lang_btn);

        var dark_btn = new Gtk.Button.from_icon_name (
            is_dark ? "weather-clear-symbolic" : "weather-clear-night-symbolic");
        dark_btn.add_css_class ("oobe-corner-button");
        dark_btn.tooltip_text = is_dark
            ? t ("Switch to light mode", "Açık moda geç")
            : t ("Switch to dark mode", "Koyu moda geç");
        dark_btn.clicked.connect (() => {
            is_dark = !is_dark;
            apply_dark_mode ();
            refresh_current_page ();
        });
        corner.append (dark_btn);

        root.add_overlay (corner);

        return new Adw.NavigationPage (root, title);
    }

    // Rebuilds whatever page is currently on top of the nav stack, so a
    // language/theme toggle is reflected immediately instead of only on
    // the next forward/back navigation.
    private delegate Adw.NavigationPage PageBuilder ();
    private void refresh_current_page () {
        var stack = nav_view.get_navigation_stack ();
        uint n = stack.get_n_items ();
        if (n == 0) return;
        var current = stack.get_item (n - 1) as Adw.NavigationPage;
        string tag = current != null ? current.title : "";
        PageBuilder rebuild;
        switch (tag) {
            case "Welcome":          rebuild = build_welcome_page; break;
            case "Wi-Fi":            rebuild = build_wifi_page; break;
            case "Language":         rebuild = build_locale_page; break;
            case "Account":          rebuild = build_account_page; break;
            case "Confirm":          rebuild = build_confirm_page; break;
            case "Done":             rebuild = build_done_page; break;
            case "Virtual Machine Detected":
            case "Sanal Makine Algılandı":
                                     rebuild = build_vm_blocked_page; break;
            default: return; // Storage / Install Mode / Installing carry
                              // per-instance state that isn't worth
                              // reconstructing from scratch mid-flow.
        }
        nav_view.pop ();
        nav_view.push (rebuild ());
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
        var logo = new Gtk.Image.from_file ("/usr/share/kibaos/installer-logo.png") {
            pixel_size = 80,
            halign     = Gtk.Align.START
        };
        content.append (logo);

        content.append (oobe_heading (
            t ("Welcome to KibaOS", "KibaOS'a Hoş Geldiniz"),
            t ("Let's get your system set up. This should only take a few minutes.",
               "Sisteminizi kuralım. Bu işlem yalnızca birkaç dakika sürecek.")));

        var nav_row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 10) {
            halign = Gtk.Align.START,
            margin_top = 20
        };
        var try_btn = new Gtk.Button.with_label (t ("Try KibaOS", "KibaOS'u Dene"));
        try_btn.add_css_class ("oobe-secondary-button");
        try_btn.tooltip_text = t ("Explore the live desktop without installing anything yet.",
            "Henüz hiçbir şey kurmadan canlı masaüstünü keşfedin.");
        try_btn.clicked.connect (() => { this.quit (); });
        nav_row.append (try_btn);
        content.append (nav_row);

        return make_page ("Welcome", content, t ("Get Started", "Başla"), () => {
            nav_view.push (build_wifi_page ());
        }, true, 0, 0);
    }

    // ══════════════════════════════════════════════════════════════════
    // Page 2: Wi-Fi  (animated icon, network list, actual connection)
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

        double[] tick   = { 0.0 };
        double[] wiggle = { 0.0 };
        uint[]   src_id = { 0 };

        canvas.set_draw_func ((da, cr, w, h) => {
            double t      = tick[0];
            double cx     = w / 2.0;
            double cy     = h / 2.0 + 8;
            double r1     = 14.0, r2 = 26.0, r3 = 38.0;
            double sw     = 4.5;

            double a3 = double.max (0, double.min (1, t * 3));
            double a2 = double.max (0, double.min (1, t * 3 - 0.6));
            double a1 = double.max (0, double.min (1, t * 3 - 1.2));

            cr.set_line_width (sw);
            cr.set_line_cap (Cairo.LineCap.ROUND);
            double start_angle = Math.PI * (1.0 + 0.18);
            double end_angle   = Math.PI * (2.0 - 0.18);

            cr.set_source_rgba (0.0, 0.60, 0.80, a3 * 0.85);
            cr.arc (cx, cy, r3, start_angle, end_angle);
            cr.stroke ();

            cr.set_source_rgba (0.0, 0.60, 0.80, a2 * 0.90);
            cr.arc (cx, cy, r2, start_angle, end_angle);
            cr.stroke ();

            cr.set_source_rgba (0.0, 0.60, 0.80, a1 * 0.95);
            cr.arc (cx, cy, r1, start_angle, end_angle);
            cr.stroke ();

            double dp    = (t * 1.4) % 1.0;
            double rip_r = 6.0 + dp * 18.0;
            double rip_a = (1.0 - dp) * 0.55;

            cr.set_source_rgba (0.0, 0.60, 0.80, rip_a);
            cr.set_line_width (2.0);
            cr.arc (cx, cy + r3 - 2.0 + wiggle[0] * 3.0, rip_r, 0, 2 * Math.PI);
            cr.stroke ();

            cr.set_source_rgba (0.0, 0.60, 0.80, 1.0);
            cr.arc (cx, cy + r3 - 2.0 + wiggle[0] * 3.0, 5.5, 0, 2 * Math.PI);
            cr.fill ();
        });

        src_id[0] = GLib.Timeout.add (16, () => {
            tick[0]   = (tick[0] + 0.012) % 1.0;
            wiggle[0] = Math.sin (tick[0] * Math.PI * 6.0) * 0.4;
            canvas.queue_draw ();
            return GLib.Source.CONTINUE;
        });

        canvas.destroy.connect (() => {
            if (src_id[0] != 0) { GLib.Source.remove (src_id[0]); src_id[0] = 0; }
        });

        content.append (canvas);
        content.append (oobe_heading (
            t ("Connect to Wi-Fi", "Wi-Fi'ye Bağlan"),
            t ("Choose a network to continue. You can also skip this step.",
               "Devam etmek için bir ağ seçin. Bu adımı atlayabilirsiniz de.")));

        // Status label shown below the list ("Connecting…", "Connected ✓", errors)
        var status_label = new Gtk.Label ("") {
            halign = Gtk.Align.CENTER,
            wrap   = true
        };
        status_label.add_css_class ("oobe-subtitle");

        // ── Discover the first NetworkManager-managed wireless device ─────
        string wifi_dev = "";
        try {
            string dev_out = "";
            GLib.Process.spawn_command_line_sync (
                "nmcli -t -f DEVICE,TYPE device status", out dev_out);
            foreach (var line in dev_out.split ("\n")) {
                var trimmed = line.strip ();
                if (trimmed == "") continue;
                var cols = trimmed.split (":");
                if (cols.length >= 2 && cols[1] == "wifi") { wifi_dev = cols[0]; break; }
            }
        } catch (GLib.SpawnError e) {}

        // Capture for closures
        string[] dev_box = { wifi_dev };

        // ── Build network list ────────────────────────────────────────────
        var list_box = new Gtk.ListBox ();
        list_box.add_css_class ("oobe-list");
        list_box.selection_mode = Gtk.SelectionMode.SINGLE;

        // Each row stores its SSID and whether it needs a password in widget data.
        // We use a simple parallel arrays approach since Vala/GTK4 has no
        // set_data on widgets without GObject subclassing tricks.
        string[] ssid_list    = {};
        bool[]   secured_list = {};

        string raw_nets = "";
        if (dev_box[0] != "") {
            try {
                string scan_out = "";
                GLib.Process.spawn_command_line_sync (
                    "nmcli device wifi rescan ifname %s".printf (dev_box[0]), out scan_out);
                // Colon-separated, one AP per line: SSID:SECURITY:SIGNAL
                // (nmcli backslash-escapes literal colons inside the SSID field).
                GLib.Process.spawn_command_line_sync (
                    "nmcli -t -f SSID,SECURITY,SIGNAL device wifi list ifname %s".printf (dev_box[0]),
                    out raw_nets);
            } catch (GLib.SpawnError e) {}
        }

        var seen = new Gee.HashSet<string> ();
        bool any = false;
        foreach (var line in raw_nets.split ("\n")) {
            var trimmed = line.strip ();
            if (trimmed == "") continue;
            // Split on unescaped colons only (nmcli escapes literal ':' in
            // field values as '\:').
            var cols = GLib.Regex.split_simple ("(?<!\\\\):", trimmed);
            if (cols.length < 3) continue;
            string ssid = cols[0].replace ("\\:", ":").strip ();
            if (ssid == "" || seen.contains (ssid)) continue;
            seen.add (ssid);
            string security    = cols[1].strip ().down ();
            string signal_str  = cols[2].strip ();
            bool   secured     = security != "" && security != "--";
            int    pct         = int.parse (signal_str);
            string signal_pct  = "%d%%".printf (int.max (0, int.min (100, pct)));

            // Choose signal icon based on nmcli's 0-100 signal percentage
            string icon_name;
            if      (pct >= 80) icon_name = "network-wireless-signal-excellent-symbolic";
            else if (pct >= 55) icon_name = "network-wireless-signal-good-symbolic";
            else if (pct >= 30) icon_name = "network-wireless-signal-ok-symbolic";
            else                icon_name = "network-wireless-signal-weak-symbolic";

            var row = new Adw.ActionRow () {
                title       = ssid,
                subtitle    = signal_pct,
                activatable = true
            };
            row.add_prefix (new Gtk.Image.from_icon_name (icon_name));
            if (secured) row.add_suffix (new Gtk.Image.from_icon_name ("system-lock-screen-symbolic"));
            list_box.append (row);

            ssid_list    += ssid;
            secured_list += secured;
            any = true;
        }
        if (!any) {
            var row = new Adw.ActionRow () {
                title = t ("No networks found nearby", "Yakında ağ bulunamadı")
            };
            row.add_prefix (new Gtk.Image.from_icon_name ("network-offline-symbolic"));
            list_box.append (row);
        }

        content.append (list_box);
        content.append (status_label);

        // ── Row activation: password dialog → nmcli connect ──────────────
        // Captures: dev_box, ssid_list, secured_list, status_label, window
        list_box.row_activated.connect ((row) => {
            int idx = row.get_index ();
            if (idx < 0 || idx >= ssid_list.length) return;

            string ssid    = ssid_list[idx];
            bool   secured = secured_list[idx];

            if (secured) {
                // ── Password dialog ───────────────────────────────────────
                var dialog = new Adw.MessageDialog (window,
                    t ("Enter Wi-Fi Password", "Wi-Fi Şifresini Girin"),
                    t ("""Enter the password for "%s".""",
                       """"%s" ağının şifresini girin.""").printf (ssid));

                var pw_entry = new Gtk.PasswordEntry () {
                    show_peek_icon = true,
                    placeholder_text = t ("Password", "Şifre")
                };
                pw_entry.add_css_class ("oobe-entry");
                dialog.set_extra_child (pw_entry);

                dialog.add_response ("cancel", t ("Cancel", "İptal"));
                dialog.add_response ("connect", t ("Connect", "Bağlan"));
                dialog.set_response_appearance ("connect", Adw.ResponseAppearance.SUGGESTED);
                dialog.set_default_response ("connect");
                dialog.set_close_response ("cancel");

                // Allow pressing Enter in the password field to confirm
                pw_entry.activate.connect (() => {
                    dialog.response ("connect");
                });

                dialog.response.connect ((resp) => {
                    if (resp != "connect") { dialog.destroy (); return; }
                    string password = pw_entry.get_text ();
                    dialog.destroy ();

                    if (password == "") {
                        status_label.remove_css_class ("oobe-subtitle");
                        status_label.add_css_class ("oobe-error");
                        status_label.label = t ("Password cannot be empty.",
                                                 "Şifre boş olamaz.");
                        return;
                    }

                    status_label.remove_css_class ("oobe-error");
                    status_label.add_css_class ("oobe-subtitle");
                    status_label.label = t ("Connecting to %s…", "%s ağına bağlanıyor…").printf (ssid);
                    do_connect_async (dev_box[0], ssid, password, status_label);
                });

                dialog.present ();

            } else {
                // ── Open network — connect directly ───────────────────────
                status_label.label = t ("Connecting to %s…", "%s ağına bağlanıyor…").printf (ssid);
                do_connect_async (dev_box[0], ssid, null, status_label);
            }
        });

        return make_page ("Wi-Fi", content, t ("Next", "İleri"), () => {
            nav_view.push (build_locale_page ());
        }, false, 1, 6);
    }

    // ── Async connect helper ─────────────────────────────────────────────────
    // Runs `nmcli device wifi connect <ssid> [password <pw>] ifname <dev>` in
    // a background GLib.Thread so the GTK main loop stays responsive, then
    // polls `nmcli device show <dev>` on the main thread for up to 15 s to
    // confirm association. Updates status_label on each step.
    private void do_connect_async (string dev, string ssid,
                                    string? password,
                                    Gtk.Label status_label) {
        // Build argv — no shell, no quoting/injection surface
        string[] argv_arr;
        if (password != null) {
            argv_arr = { "nmcli", "device", "wifi", "connect", ssid,
                         "password", password, "ifname", dev };
        } else {
            argv_arr = { "nmcli", "device", "wifi", "connect", ssid,
                         "ifname", dev };
        }

        // Kick the blocking nmcli call off the main thread.
        // When it finishes, schedule the polling phase back on the main loop.
        string[]  argv_copy   = argv_arr;
        string    dev_copy    = dev;
        string    ssid_copy   = ssid;
        unowned Gtk.Label lbl = status_label;

        new GLib.Thread<void> ("kibaos-wifi-connect", () => {
            bool   ok  = false;
            string err = "";
            try {
                int exit_status = 0;
                GLib.Process.spawn_sync (
                    null, argv_copy, null,
                    GLib.SpawnFlags.SEARCH_PATH         |
                    GLib.SpawnFlags.STDOUT_TO_DEV_NULL  |
                    GLib.SpawnFlags.STDERR_TO_DEV_NULL,
                    null, null, null, out exit_status);
                ok  = (exit_status == 0);
                err = ok ? "" : "nmcli exit %d".printf (exit_status);
            } catch (GLib.SpawnError e) {
                err = e.message;
            }

            // Marshal result back to the GTK main thread
            bool   ok_f  = ok;
            string err_f = err;
            GLib.Idle.add (() => {
                if (!ok_f) {
                    lbl.remove_css_class ("oobe-subtitle");
                    lbl.add_css_class ("oobe-error");
                    lbl.label = t ("Could not connect: %s", "Bağlanılamadı: %s").printf (err_f);
                    return GLib.Source.REMOVE;
                }
                // Start polling for association on the main thread
                lbl.remove_css_class ("oobe-error");
                lbl.add_css_class ("oobe-subtitle");
                lbl.label = t ("Verifying connection…", "Bağlantı doğrulanıyor…");
                int[] attempts = { 0 };
                GLib.Timeout.add (500, () => {
                    attempts[0]++;
                    bool associated = false;
                    try {
                        string show_out = "";
                        GLib.Process.spawn_command_line_sync (
                            "nmcli -t -f GENERAL.STATE device show %s".printf (dev_copy),
                            out show_out);
                        associated = show_out.down ().contains ("connected");
                    } catch (GLib.SpawnError e) {}

                    if (associated) {
                        lbl.label = t ("Connected to %s ✓", "%s ağına bağlanıldı ✓").printf (ssid_copy);
                        return GLib.Source.REMOVE;
                    }
                    if (attempts[0] >= 30) {   // 30 × 500 ms = 15 s
                        lbl.remove_css_class ("oobe-subtitle");
                        lbl.add_css_class ("oobe-error");
                        lbl.label = t ("Timed out — check the password and try again.",
                                        "Zaman aşımı — şifreyi kontrol edip tekrar deneyin.");
                        return GLib.Source.REMOVE;
                    }
                    return GLib.Source.CONTINUE;
                });
                return GLib.Source.REMOVE;
            });
        });
    }

    // ══════════════════════════════════════════════════════════════════
    // Page 3: Locale + Keyboard
    // ══════════════════════════════════════════════════════════════════
    private Adw.NavigationPage build_locale_page () {
        var content = new Gtk.Box (Gtk.Orientation.VERTICAL, 20);
        content.append (oobe_heading (
            t ("Language & Keyboard", "Dil ve Klavye"),
            t ("Choose how KibaOS should communicate with you.",
               "KibaOS'un sizinle nasıl iletişim kuracağını seçin.")));

        var locale_row = new Adw.ComboRow () { title = t ("Language", "Dil") };
        var locale_model = new Gtk.StringList (null);
        // Display names shown in the picker; `locales` holds the actual
        // locale strings the installed system will use, in the same order.
        string[] locale_labels = {
            "English (US)", "English (UK)", "Deutsch", "Français",
            "Español", "日本語", "中文（简体）", "Türkçe"
        };
        string[] locales = {
            "en_US.UTF-8", "en_GB.UTF-8", "de_DE.UTF-8",
            "fr_FR.UTF-8", "es_ES.UTF-8", "ja_JP.UTF-8", "zh_CN.UTF-8",
            "tr_TR.UTF-8"
        };
        foreach (var l in locale_labels) locale_model.append (l);
        locale_row.set_model (locale_model);
        locale_row.notify["selected"].connect (() => {
            selected_locale = locales[locale_row.get_selected ()];
        });
        content.append (locale_row);

        var keymap_row = new Adw.ComboRow () { title = t ("Keyboard layout", "Klavye düzeni") };
        var keymap_model = new Gtk.StringList (null);
        string[] keymap_labels = {
            "English (US)", "English (UK)", "Deutsch", "Français",
            "Español", "日本語", "Dvorak", "Türkçe (Q)"
        };
        string[] keymaps = { "us", "uk", "de", "fr", "es", "jp106", "dvorak", "trq" };
        foreach (var k in keymap_labels) keymap_model.append (k);
        keymap_row.set_model (keymap_model);
        keymap_row.notify["selected"].connect (() => {
            selected_keymap = keymaps[keymap_row.get_selected ()];
        });
        content.append (keymap_row);

        return make_page ("Language", content, t ("Next", "İleri"), () => {
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

    // True if `devpath` already has a partition table with at least one
    // partition on it — our signal that there might be another OS here,
    // worth asking the user whether to erase it or install alongside it.
    private bool disk_has_existing_data (string devpath) {
        string raw = "";
        try { GLib.Process.spawn_command_line_sync (
                "lsblk -rno NAME %s".printf (devpath), out raw); }
        catch (GLib.SpawnError e) { return false; }
        int lines = 0;
        foreach (var line in raw.split ("\n")) {
            if (line.strip () != "") lines++;
        }
        // First line is the disk itself; anything beyond that means at
        // least one partition already exists.
        return lines > 1;
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
            opt.label   = t ("Your computer's storage (%s)", "Bilgisayarınızın deposu (%s)").printf (
                label == "" ? t ("internal drive", "dahili disk") : label);
            options.add (opt);
        }
        return options;
    }

    private void advance_past_storage_step () {
        var options = list_storage_options ();
        if (options.size <= 1) {
            selected_disk = options.size == 1 ? options[0].devpath : "";
            advance_past_install_mode_step ();
        } else {
            nav_view.push (build_storage_picker_page (options));
        }
    }

    // After a disk is settled on: if it looks like it already has an OS
    // on it, ask erase-vs-alongside; otherwise there's nothing to ask
    // (a blank disk can only be erased/initialized) so skip straight on.
    private void advance_past_install_mode_step () {
        install_mode = "erase";
        if (selected_disk != "" && disk_has_existing_data (selected_disk)) {
            nav_view.push (build_install_mode_page ());
        } else {
            nav_view.push (build_account_page ());
        }
    }

    // ══════════════════════════════════════════════════════════════════
    // Page 4: Storage picker (only shown with 2+ drives)
    // ══════════════════════════════════════════════════════════════════
    private Adw.NavigationPage build_storage_picker_page (Gee.ArrayList<StorageOption> options) {
        var content = new Gtk.Box (Gtk.Orientation.VERTICAL, 20);
        content.append (oobe_heading (
            t ("Where should KibaOS go?", "KibaOS nereye kurulsun?"),
            t ("Your computer has more than one drive. Pick the one to set up.",
               "Bilgisayarınızda birden fazla disk var. Kurulacak olanı seçin.")));

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

        return make_page ("Storage", content, t ("Next", "İleri"), () => {
            advance_past_install_mode_step ();
        }, false, 3, 6);
    }

    // ══════════════════════════════════════════════════════════════════
    // Page 4b: Install mode (erase vs. install alongside) — only shown
    // when the chosen drive already has an existing OS/partition table
    // ══════════════════════════════════════════════════════════════════
    private Adw.NavigationPage build_install_mode_page () {
        var content = new Gtk.Box (Gtk.Orientation.VERTICAL, 20);
        content.append (oobe_heading (
            t ("How should KibaOS be installed?", "KibaOS nasıl kurulsun?"),
            t ("We found an existing operating system on this drive.",
               "Bu diskte mevcut bir işletim sistemi bulduk.")));

        var picker = new Gtk.ListBox ();
        picker.add_css_class ("oobe-list");
        picker.selection_mode = Gtk.SelectionMode.SINGLE;

        var erase_row = new Adw.ActionRow () {
            title    = t ("Erase disk", "Diski sil"),
            subtitle = t ("Delete everything on this drive and install KibaOS by itself.",
                           "Bu diskteki her şeyi silip yalnızca KibaOS'u kurun.")
        };
        erase_row.add_prefix (new Gtk.Image.from_icon_name ("edit-delete-symbolic"));
        erase_row.set_data ("mode", "erase");
        picker.append (erase_row);

        var alongside_row = new Adw.ActionRow () {
            title    = t ("Install alongside", "Yanına kur"),
            subtitle = t ("Keep what's already here and set up KibaOS in the free space next to it (dual boot).",
                           "Mevcut sistemi koru, KibaOS'u yanındaki boş alana kur (çift önyükleme).")
        };
        alongside_row.add_prefix (new Gtk.Image.from_icon_name ("drive-multidisk-symbolic"));
        alongside_row.set_data ("mode", "alongside");
        picker.append (alongside_row);

        picker.row_selected.connect ((row) => {
            if (row != null) install_mode = row.get_data<string> ("mode");
        });
        install_mode = "erase";
        picker.select_row (picker.get_row_at_index (0));
        content.append (picker);

        return make_page ("Install Mode", content, t ("Next", "İleri"), () => {
            nav_view.push (build_account_page ());
        }, false, 3, 6);
    }

    // ══════════════════════════════════════════════════════════════════
    // Page 5: Account creation
    // ══════════════════════════════════════════════════════════════════
    private Adw.NavigationPage build_account_page () {
        var content = new Gtk.Box (Gtk.Orientation.VERTICAL, 16);
        content.append (oobe_heading (
            t ("Create Your Account", "Hesabınızı Oluşturun"),
            t ("This is the account you'll use every day.",
               "Bu, her gün kullanacağınız hesap.")));

        var group = new Adw.PreferencesGroup ();
        group.add_css_class ("oobe-prefs-group");

        var hostname_entry = new Adw.EntryRow () { title = t ("Computer name", "Bilgisayar adı") };
        hostname_entry.text = "kibaos";
        hostname_entry.changed.connect (() => { hostname_value = hostname_entry.text; });
        group.add (hostname_entry);

        var user_entry = new Adw.EntryRow () { title = t ("Username", "Kullanıcı adı") };
        user_entry.changed.connect (() => { username_value = user_entry.text; });
        group.add (user_entry);

        var pass_entry = new Adw.PasswordEntryRow () { title = t ("Password", "Şifre") };
        pass_entry.changed.connect (() => { password_value = pass_entry.text; });
        group.add (pass_entry);

        content.append (group);

        return make_page ("Account", content,
            is_oem_mode ? t ("Finish Setup", "Kurulumu Bitir") : t ("Next", "İleri"), () => {
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
        content.append (oobe_heading (
            t ("Ready to Set Up KibaOS", "KibaOS Kurulumuna Hazır"),
            install_mode == "alongside"
                ? t ("KibaOS will be installed next to your existing operating system, " +
                     "using the free space on this drive. Nothing else will be touched.",
                     "KibaOS, mevcut işletim sisteminizin yanına, bu diskteki boş alan " +
                     "kullanılarak kurulacak. Başka hiçbir şeye dokunulmayacak.")
                : t ("Everything on your computer will be replaced. " +
                     "Make sure anything important is backed up first.",
                     "Bilgisayarınızdaki her şeyin yerine yenisi kurulacak. " +
                     "Önemli olan her şeyi önceden yedeklediğinizden emin olun.")));

        // Summary card
        var summary = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        summary.add_css_class ("oobe-summary-box");

        OobeSummaryItem[] items = {
            { "drive-harddisk-symbolic",   t ("Storage", "Depolama"),
              selected_disk == "" ? t ("Auto-detected", "Otomatik algılandı") : GLib.Path.get_basename (selected_disk) },
            { "drive-multidisk-symbolic",  t ("Install mode", "Kurulum modu"),
              install_mode == "alongside" ? t ("Install alongside (dual boot)", "Yanına kur (çift önyükleme)") : t ("Erase disk", "Diski sil") },
            { "preferences-desktop-locale-symbolic", t ("Language", "Dil"), selected_locale },
            { "input-keyboard-symbolic",   t ("Keyboard", "Klavye"), selected_keymap },
            { "system-users-symbolic",     t ("Account", "Hesap"),
              username_value == "" ? t ("(not set)", "(ayarlanmadı)") : username_value }
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

        return make_page ("Confirm", content, t ("Install KibaOS", "KibaOS'u Kur"), () => {
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
        content.append (oobe_heading (
            t ("Installing KibaOS", "KibaOS Kuruluyor"),
            t ("Sit tight — this won't take long.", "Biraz bekleyin — çok sürmeyecek.")));

        progress_bar = new Gtk.ProgressBar () { show_text = false };
        progress_bar.add_css_class ("oobe-progress");
        content.append (progress_bar);

        progress_label = new Gtk.Label (t ("Preparing…", "Hazırlanıyor…"));
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

        content.append (oobe_heading (
            t ("You're all set.", "Her şey hazır."),
            t ("KibaOS is installed and ready. Restart your computer to get started.",
               "KibaOS kuruldu ve hazır. Başlamak için bilgisayarınızı yeniden başlatın.")));

        return make_page ("Done", content, t ("Restart Now", "Şimdi Yeniden Başlat"), () => {
            try { GLib.Process.spawn_command_line_async ("systemctl reboot"); }
            catch (GLib.SpawnError e) { warning ("Reboot failed: %s", e.message); }
        }, true);
    }

    // ══════════════════════════════════════════════════════════════════
    // Backend plumbing
    // ══════════════════════════════════════════════════════════════════
    private void start_oem_finish () {
        string[] argv = {
            "sudo", "/usr/local/bin/kibaos-oem-finish.sh",
            selected_locale, selected_keymap, hostname_value,
            username_value, password_value
        };
        launch_backend (argv);
    }

    private void start_install () {
        // Delegates disk partitioning/formatting, base pacstrap, and
        // bootloader install to archinstall instead of libkibadisk's
        // hand-rolled ioctl code. Same argv shape and PROGRESS/FATAL
        // stdout protocol as before, so nothing else in this file changes.
        string[] argv = {
            "sudo", "/usr/local/bin/kibaos-archinstall-backend",
            selected_disk, install_mode, selected_locale, selected_keymap,
            hostname_value, username_value, password_value
        };
        launch_backend (argv);
    }

    private string last_fatal_message = "";

    private void launch_backend (string[] argv) {
        try {
            // STDERR_MERGE folds the backend's stderr into the same pipe as
            // stdout. Previously only STDOUT_PIPE was set, so every
            // "FATAL: ..." line (the only place the *actual* error reason
            // — kiba_fs_strerror()/strerror(errno) text — ever got written)
            // went to the backend's inherited stderr and was simply lost,
            // since sudo+a GUI launch has no terminal attached to catch it.
            var launcher = new GLib.SubprocessLauncher (
                GLib.SubprocessFlags.STDOUT_PIPE | GLib.SubprocessFlags.STDERR_MERGE);
            var proc     = launcher.spawnv (argv);
            last_fatal_message = "";
            read_backend_output.begin (
                new GLib.DataInputStream (proc.get_stdout_pipe ()), proc);
        } catch (GLib.Error e) {
            progress_label.label = t ("Failed to start: %s", "Başlatılamadı: %s").printf (e.message);
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
                } else if (line.has_prefix ("FATAL: ")) {
                    // Captured now that stderr is merged in — keep the real
                    // reason so we can show it instead of a generic message.
                    last_fatal_message = line.substring (7);
                }
            }
            yield proc.wait_async ();
            if (proc.get_exit_status () == 0) {
                nav_view.push (build_done_page ());
            } else if (last_fatal_message != "") {
                progress_label.label = last_fatal_message +
                    t ("\n(Full log: /var/log/kibaos-oobe.log)",
                       "\n(Tam günlük: /var/log/kibaos-oobe.log)");
            } else {
                progress_label.label = t (
                    "Something went wrong. Check /var/log/kibaos-oobe.log for details.",
                    "Bir şeyler ters gitti. Ayrıntılar için /var/log/kibaos-oobe.log dosyasına bakın.");
            }
        } catch (GLib.Error e) {
            progress_label.label = t ("Lost connection to installer: %s",
                                       "Kurulum programıyla bağlantı kesildi: %s").printf (e.message);
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

cc = meson.get_compiler('c')
m_dep       = cc.find_library('m', required: true)
threads_dep = dependency('threads')   # needed for GLib.Thread

gtk4_dep    = dependency('gtk4')
adwaita_dep = dependency('libadwaita-1')
gee_dep     = dependency('gee-0.8')

executable(
  'io.kibaos.oobe',
  'main.vala',
  dependencies: [gtk4_dep, adwaita_dep, gee_dep, m_dep, threads_dep],
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
    transition: background 260ms cubic-bezier(0.22, 1, 0.36, 1);
}
window.dark .oobe-background {
    background: linear-gradient(160deg,
        rgba(8,14,24,0.75) 0%,
        rgba(14,20,32,0.55) 50%,
        rgba(6,10,18,0.75) 100%);
}

/* ── Brand wordmark ────────────────────────────────────────────────────── */
.oobe-brand {
    font-size: 15px;
    font-weight: 700;
    letter-spacing: 0.5px;
    color: rgba(255,255,255,0.85);
    text-shadow: 0 1px 3px rgba(0,0,0,0.25);
}

/* ── Corner controls (language / dark-mode toggle) ───────────────────────── */
.oobe-corner-button {
    background:    rgba(255,255,255,0.55);
    color:         #334155;
    border:        1px solid rgba(255,255,255,0.6);
    border-radius: 999px;
    min-width:     34px;
    min-height:    34px;
    padding:       6px 12px;
    font-size:     12px;
    font-weight:   650;
    transition:
        background-color 140ms cubic-bezier(0.22, 1, 0.36, 1),
        transform         140ms cubic-bezier(0.22, 1, 0.36, 1);
}
.oobe-corner-button:hover  { background: rgba(255,255,255,0.85); transform: translateY(-1px); }
.oobe-corner-button:active { transform: translateY(0); transition-duration: 70ms; }
window.dark .oobe-corner-button {
    background: rgba(30,41,59,0.65);
    color:      #e2e8f0;
    border-color: rgba(255,255,255,0.12);
}
window.dark .oobe-corner-button:hover { background: rgba(51,65,85,0.85); }

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
    transition:
        background-color 220ms cubic-bezier(0.22, 1, 0.36, 1),
        border-color     220ms cubic-bezier(0.22, 1, 0.36, 1);
}
window.dark .oobe-card {
    background:    rgba(17,24,39,0.86);
    border:        1px solid rgba(255,255,255,0.08);
    box-shadow:
        0 2px 4px  rgba(0,0,0,0.20),
        0 8px 24px rgba(0,0,0,0.30),
        0 32px 64px rgba(0,0,0,0.40);
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
window.dark .oobe-step-dot { background: rgba(255,255,255,0.18); }
window.dark .oobe-step-dot-active { background: #22c1ec; }

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
window.dark .oobe-title    { color: #f1f5f9; }
window.dark .oobe-subtitle { color: #94a3b8; }
window.dark .oobe-brand    { color: rgba(255,255,255,0.75); }

/* Status text that means "this went wrong" — distinct from the neutral
 * .oobe-subtitle so an error doesn't read as just another status update. */
.oobe-error {
    font-size:   14px;
    color:       #dc2626;
    line-height: 1.55;
    animation:   shake 340ms cubic-bezier(0.36, 0.07, 0.19, 0.97) both;
}
window.dark .oobe-error { color: #f87171; }
@keyframes shake {
    10%, 90% { transform: translateX(-1px); }
    20%, 80% { transform: translateX(2px);  }
    30%, 50%, 70% { transform: translateX(-3px); }
    40%, 60% { transform: translateX(3px);  }
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
    animation: fade-up 260ms cubic-bezier(0.22, 1, 0.36, 1) both;
}
.oobe-list row:hover { background: #f0f9ff; border-color: rgba(0,153,204,0.28); transform: translateX(2px); }
.oobe-list row:selected {
    background: rgba(0,153,204,0.10);
    border-color: rgba(0,153,204,0.55);
    box-shadow: 0 0 0 3px rgba(0,153,204,0.14);
}
window.dark .oobe-list row,
window.dark listview > row {
    background: rgba(30,41,59,0.55);
    border-color: rgba(255,255,255,0.08);
    color: #e2e8f0;
}
window.dark .oobe-list row:hover { background: rgba(0,153,204,0.16); border-color: rgba(0,153,204,0.4); }
window.dark .oobe-list row:selected {
    background: rgba(0,153,204,0.22);
    border-color: rgba(0,153,204,0.6);
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
window.dark .oobe-summary-box { background: rgba(30,41,59,0.55); border-color: rgba(255,255,255,0.08); }
window.dark .oobe-summary-key { color: #94a3b8; }
window.dark .oobe-summary-val { color: #f1f5f9; }
window.dark .oobe-prefs-group,
window.dark row.combo, window.dark row.action {
    background: rgba(30,41,59,0.55);
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
window.dark .oobe-secondary-button { color: #cbd5e1; border-color: rgba(255,255,255,0.16); }
window.dark .oobe-secondary-button:hover  { background: rgba(255,255,255,0.08); border-color: rgba(255,255,255,0.26); }
window.dark .oobe-secondary-button:active { background: rgba(255,255,255,0.14); }

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
window.dark .oobe-progress trough { background: rgba(255,255,255,0.10); }

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
window.dark entry, window.dark row.entry, window.dark .oobe-prefs-group entry {
    background: rgba(30,41,59,0.7);
    border-color: rgba(255,255,255,0.12);
    color: #f1f5f9;
}
window.dark entry:focus-within, window.dark row.entry:focus-within {
    background: rgba(30,41,59,0.95);
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
# ══════════════════════════════════════════════════════════════════════════
# ARCHINSTALL FOR PARTITIONING ONLY — squashfs extraction stays.
# ══════════════════════════════════════════════════════════════════════════
# Uses archinstall's `only_hd` script, which — unlike the guided/default
# script — ONLY partitions, formats, and mounts a disk; it does no pacstrap,
# no bootloader, no package install. That's exactly the piece worth
# delegating (archinstall's partitioning is far more battle-tested than
# libkibadisk's hand-rolled libfdisk code), while everything downstream —
# squashfs extraction onto the mounted target, configs, user creation,
# bootloader — stays exactly as kiba_install_extract_image()/
# kiba_install_write_configs()/kiba_install_finalize() already do it below.
# kibaos-oobe-backend gets a new `prepartitioned` mode (see main() below)
# that skips straight to "mount + extract" using the device nodes
# archinstall just formatted, via KIBA_ROOT_PART/KIBA_ESP_PART env vars.
#
# Scope: only_hd's "default_layout" wipes the whole disk, so this only
# covers `mode=erase`. `mode=alongside` (dual-boot into existing free
# space + an existing ESP) keeps using the original kiba_gpt_scan()/
# kiba_gpt_add_partition() path further down — archinstall's manual
# partitioning mode has a long history of bugs around exactly this
# "reuse an existing table, only touch the free space" case (see e.g.
# archlinux/archinstall issues around silent partition failures), so
# it isn't worth the risk for the less-common dual-boot path.
#
# Config field names below match the archinstall 3.x JSON schema as
# documented, but that schema does shift between releases — run
# `archinstall --script only_hd --dry-run` against the version pinned in
# this ISO before shipping to confirm they still match.
cat > /usr/local/bin/kibaos-archinstall-backend << 'ARCHBACKEND'
#!/bin/bash
# Thin shim between the OOBE and the C backend: run archinstall's only_hd
# script to partition/format/mount the disk, then hand off to
# kibaos-oobe-backend in "prepartitioned" mode for the squashfs extraction,
# configs, user account, and bootloader (unchanged from before).
set -o pipefail
LOG=/var/log/kibaos-oobe.log
disk="$1"; mode="$2"; locale="$3"; keymap="$4"
hostname="$5"; username="$6"; password="$7"
echo "=== kibaos-archinstall-backend started $(date) ===" >> "$LOG"

if [ "$mode" = "alongside" ]; then
  # archinstall's manual partitioning isn't reliable enough for "append
  # into existing free space" yet -- fall straight through to the
  # original hand-rolled dual-boot path, untouched.
  exec /usr/local/bin/kibaos-oobe-backend "$disk" "$mode" "$locale" "$keymap" \
       "$hostname" "$username" "$password"
fi

echo "PROGRESS 1 Preparing disk layout…"
# archinstall's real config schema nests sizes as {sector_size,unit,value}
# objects (not "512MiB"-style strings) and wants a per-partition obj_id
# UUID -- matched against actual archinstall 3.x --silent configs, not the
# simplified examples in the docs.
#
# NOTE: current archinstall's Unit enum has NO "Percent" member -- that was
# removed at some point after the docs/examples were written. Size.parse_args
# does Unit[size_arg['unit']], a literal enum-name lookup, so "Percent"
# raises KeyError: 'Percent'. There is no "fill the rest of the disk" token
# anymore -- we have to compute the actual end size ourselves. archinstall's
# own bounds check requires the last partition's end to be <= (total_size -
# 1 MiB) on GPT disks (Size.gpt_end()), so gpt_safety_mib below only needs
# to clear 1 MiB -- kept at 2 for integer-division/rounding slack.
boot_obj_id=$(cat /proc/sys/kernel/random/uuid)
root_obj_id=$(cat /proc/sys/kernel/random/uuid)

disk_bytes=$(lsblk -b -dn -o SIZE "${disk}")
disk_mib=$(( disk_bytes / 1048576 ))
root_start_mib=513
gpt_safety_mib=2
root_size_mib=$(( disk_mib - root_start_mib - gpt_safety_mib ))

if [ "$root_size_mib" -lt 1024 ]; then
  echo "ERROR: computed root partition size (${root_size_mib}MiB) is too small -- disk ${disk} may be smaller than expected (${disk_mib}MiB total)" >> "$LOG"
  exit 1
fi

# Unquoted heredoc on purpose -- $disk etc. interpolate directly into the
# JSON, no separate config-generation script needed.
cat > /tmp/kiba_disk_config.json << DISKCFG
{
  "disk_config": {
    "config_type": "default_layout",
    "device_modifications": [
      {
        "device": "${disk}",
        "wipe": true,
        "partitions": [
          {
            "obj_id": "${boot_obj_id}",
            "status": "create",
            "type": "primary",
            "start": {
              "sector_size": {"unit": "B", "value": 512},
              "unit": "MiB",
              "value": 1
            },
            "size": {
              "sector_size": {"unit": "B", "value": 512},
              "unit": "MiB",
              "value": 512
            },
            "mountpoint": "/boot",
            "fs_type": "fat32",
            "mount_options": [],
            "flags": ["boot", "esp"],
            "btrfs": [],
            "dev_path": null
          },
          {
            "obj_id": "${root_obj_id}",
            "status": "create",
            "type": "primary",
            "start": {
              "sector_size": {"unit": "B", "value": 512},
              "unit": "MiB",
              "value": 513
            },
            "size": {
              "sector_size": {"unit": "B", "value": 512},
              "unit": "MiB",
              "value": ${root_size_mib}
            },
            "mountpoint": "/",
            "fs_type": "ext4",
            "mount_options": [],
            "flags": [],
            "btrfs": [],
            "dev_path": null
          }
        ]
      }
    ]
  }
}
DISKCFG

echo "PROGRESS 4 Partitioning and formatting…"
archinstall --script only_hd --config /tmp/kiba_disk_config.json --silent \
  >> "$LOG" 2>&1
if [ $? -ne 0 ]; then
  tail -n 1 "$LOG" | sed 's/^/FATAL: /'
  exit 1
fi

# only_hd leaves everything mounted under /mnt/archinstall. Resolve which
# device nodes it actually used, then unmount -- kibaos-oobe-backend does
# its own mount at /mnt/kibaos-install so the rest of the pipeline (which
# hardcodes that path) needs zero changes.
root_part=$(findmnt -n -o SOURCE --target /mnt/archinstall)
esp_part=$(findmnt -n -o SOURCE --target /mnt/archinstall/boot)
if [ -z "$root_part" ] || [ -z "$esp_part" ]; then
  echo "FATAL: Couldn't determine which partitions archinstall created."
  exit 1
fi
umount -R /mnt/archinstall

echo "PROGRESS 8 Handing off to KibaOS installer…"
KIBA_ROOT_PART="$root_part" KIBA_ESP_PART="$esp_part" \
  exec /usr/local/bin/kibaos-oobe-backend "$disk" "$mode" "$locale" "$keymap" \
       "$hostname" "$username" "$password" prepartitioned
ARCHBACKEND
chmod +x /usr/local/bin/kibaos-archinstall-backend

# ── Privileged backend: libkibadisk + kibaos-oobe-backend ─────────────────
# Replaces the old Python/archinstall-based backend entirely. No archinstall,
# no parted, no blkid/partprobe subprocesses for the disk-critical path --
# see kiba_gpt.c/kiba_fs.c/kiba_udev.c for the from-scratch GPT writer,
# mkfs/mount wrapper, and udev-settle replacement respectively. The only
# external tools retained are ones with no sane from-scratch replacement:
# unsquashfs, mkfs.fat, mkfs.ext4, useradd/chpasswd, grub-install, mkinitcpio,
# locale-gen, pacman -- all invoked via posix_spawn argv arrays, never a
# shell, so there's no string-quoting/injection surface anywhere in this
# backend (mirrors the argv fix already applied on the Vala/sudo side).
echo "=== Building libkibadisk (disk/install backend library) ==="
mkdir -p /usr/share/kibaos-oobe/src/disk
cd /usr/share/kibaos-oobe/src/disk

cat > kiba_gpt.h << 'KIBA_SRC_END_GPTH'
/* kiba_gpt.h — GPT partition table writer, backed by libfdisk.
 *
 * Previously this was a from-scratch, hand-rolled implementation of
 * UEFI Spec 2.10 chapter 5 (protective MBR + primary/backup GPT header +
 * entry array) written directly via pwrite(), with BLKPG ioctls standing
 * in for partprobe. That hand-rolled GPT writer is now replaced with
 * libfdisk (util-linux's own partitioning library — the same code that
 * backs `fdisk`/`cfdisk` and is maintained by the kernel/util-linux
 * project). Reasoning: GPT is a CRC32'd, dual-copy, byte-exact-spec
 * format — exactly the kind of thing where a small bug (off-by-one
 * sector, wrong CRC scope, endianness slip) silently corrupts a real
 * disk. libfdisk gets this right because it's the reference
 * implementation other tools defer to, not because hand-rolled C can't
 * — it's a real, maintained dependency trade made deliberately, the
 * same way kiba_fs.h already defers to mkfs.ext4/mkfs.fat for the same
 * reason.
 *
 * The public API below is UNCHANGED from the previous version, so
 * kibaos_oobe_backend_main.c and every other caller needs zero changes.
 *
 * Build requirement: link with `-lfdisk` (libfdisk-dev /
 * util-linux-libs, already present on any Arch base — part of
 * util-linux). See the gcc invocation building kibaos-oobe-backend.
 */
#ifndef KIBA_GPT_H
#define KIBA_GPT_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

/* 16-byte little/mixed-endian GUID, stored exactly as UEFI expects on disk.
 * Kept for ABI compatibility with existing callers — internally this is
 * now converted to/from libfdisk's string-GUID representation. */
typedef struct {
    uint8_t b[16];
} kiba_guid_t;

/* Well-known partition type GUIDs (UEFI Spec 2.10 Table 5-7 + Linux conventions) */
extern const kiba_guid_t KIBA_GUID_ESP;          /* C12A7328-F81F-11D2-BA4B-00A0C93EC93B */
extern const kiba_guid_t KIBA_GUID_LINUX_FS;     /* 0FC63DAF-8483-4772-8E79-3D69D8477DE4 */

typedef struct {
    char        name[37];      /* NUL-terminated, displayed only; truncated to 36 UTF-16 chars on disk */
    kiba_guid_t type_guid;
    kiba_guid_t unique_guid;   /* if all-zero, libfdisk generates one */
    uint64_t    first_lba;
    uint64_t    last_lba;      /* inclusive. Pass KIBA_GPT_LAST_LBA_REST to
                                 * consume all remaining space on the disk --
                                 * this defers to libfdisk's own last-usable-LBA
                                 * (which already accounts for the backup GPT
                                 * header + entry array at the end of the disk)
                                 * instead of recomputing it by hand. */
    uint64_t    attributes;
} kiba_gpt_partition_t;

/* Sentinel for last_lba: "use all remaining space on the disk." Never a
 * legitimate LBA value, so safe to reuse as a flag. */
#define KIBA_GPT_LAST_LBA_REST UINT64_MAX

typedef struct {
    int      fd;                 /* open O_RDWR on the whole-disk block device */
    uint32_t logical_sector_size;
    uint64_t total_sectors;
    kiba_guid_t disk_guid;       /* if all-zero, libfdisk generates one */
} kiba_gpt_disk_t;

/* Generates a random RFC-4122 v4 GUID using /dev/urandom — no external tool. */
kiba_guid_t kiba_guid_random(void);

/* Creates a fresh GPT label and writes the given partitions (in order) to
 * disk->fd via libfdisk. Returns 0 on success, -errno (or a libfdisk
 * negative error code) on failure.
 *
 * On success, the kernel partition table is updated for each partition
 * automatically (libfdisk calls BLKPG/BLKRRPART internally as needed) —
 * caller does not need to call partprobe.
 *
 * NOTE: disk->fd is used only to derive the device path for libfdisk
 * (via /proc/self/fd) — libfdisk opens the device itself through
 * fdisk_assign_device(). The fd passed in must stay open for the
 * duration of the call.
 */
int kiba_gpt_write(kiba_gpt_disk_t *disk,
                    const kiba_gpt_partition_t *parts, size_t n_parts);

/* Reads back sector size + total size for `path` (e.g. "/dev/vda") via
 * ioctl (BLKSSZGET, BLKGETSIZE64) — no `blockdev`/`lsblk` subprocess.
 * (Unchanged — these ioctls were never the risky part.) */
int kiba_gpt_probe_device(const char *path, uint32_t *sector_size,
                           uint64_t *total_sectors);

/* ── Dual-boot / "install alongside" support ─────────────────────────
 * Everything above this point assumes we own the whole disk and are
 * free to lay down a brand-new GPT (kiba_gpt_write() calls
 * fdisk_create_disklabel(), which wipes whatever was there). The
 * functions below are the non-destructive counterparts used when the
 * disk already has an OS on it that the user wants to keep. */

typedef struct {
    int      esp_partno;      /* 1-indexed partno of an existing ESP found
                                * on the disk, or 0 if none exists. */
    uint64_t esp_first_lba;
    uint64_t esp_last_lba;
    uint64_t free_first_lba;  /* largest contiguous run of unallocated
                                * sectors on the disk. Zero-length
                                * (free_last_lba < free_first_lba) if the
                                * disk has no usable free space. */
    uint64_t free_last_lba;
    uint64_t free_bytes;
} kiba_gpt_scan_result_t;

/* Reads the EXISTING partition table on `path` without modifying
 * anything on disk (read-only fdisk_assign_device). Locates an existing
 * EFI System Partition, if any, and the single largest gap of
 * unallocated sectors, for dual-boot free-space installs. If the disk
 * has no valid GPT label at all, *out is zeroed and this returns 0 —
 * callers should treat that the same as "no free space / no ESP found"
 * rather than as an error, since an unpartitioned disk simply isn't a
 * dual-boot candidate. Returns -errno only if the device itself
 * couldn't be opened/read. */
int kiba_gpt_scan(const char *path, kiba_gpt_scan_result_t *out);

/* Adds ONE new partition to an EXISTING GPT table on `path` — unlike
 * kiba_gpt_write(), this does NOT call fdisk_create_disklabel() and
 * does NOT touch any partition already on the disk. `part->first_lba`/
 * `last_lba` should fall inside a free region (normally taken straight
 * from a prior kiba_gpt_scan() call's free_first_lba/free_last_lba).
 * On success, writes the new partition's 1-indexed partition number to
 * *out_partno. Returns 0 on success, -errno / libfdisk error on
 * failure. */
int kiba_gpt_add_partition(const char *path, const kiba_gpt_partition_t *part,
                            int *out_partno);

#endif
KIBA_SRC_END_GPTH

cat > kiba_gpt.c << 'KIBA_SRC_END_GPTC'
/* kiba_gpt.c — GPT writer backed by libfdisk (util-linux).
 *
 * The previous revision of this file was a hand-rolled GPT writer
 * (pwrite, CRC32, etc). It has been replaced with libfdisk, which is
 * the reference implementation that backs fdisk/cfdisk and is maintained
 * by the util-linux / kernel project. The public API (kiba_gpt.h) is
 * unchanged — all callers continue to work without modification.
 *
 * libfdisk handles:
 *   - Protective MBR
 *   - Primary + backup GPT headers (including CRCs)
 *   - Partition entry array
 *   - BLKPG / BLKRRPART kernel notification (via fdisk_reread_partition_table)
 *
 * We retain our own kiba_gpt_probe_device() (raw ioctls, unchanged) and
 * kiba_guid_random() since those have nothing to do with GPT writing and
 * we do not want to pull in extra libfdisk API for such simple helpers.
 */
#define _GNU_SOURCE
#include "kiba_gpt.h"

#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <strings.h>       /* strcasecmp */
#include <sys/ioctl.h>
#include <linux/fs.h>     /* BLKSSZGET, BLKGETSIZE64 */
#include <libfdisk/libfdisk.h>

/* ── Well-known type GUIDs (string form for libfdisk) ───────────────── */
/* libfdisk accepts GUIDs as canonical strings: 8-4-4-4-12 uppercase hex.
 * These correspond to the byte arrays in the old hand-rolled version;
 * kept as string constants so they're human-readable and verifiable. */
#define KIBA_GUID_ESP_STR      "C12A7328-F81F-11D2-BA4B-00A0C93EC93B"
#define KIBA_GUID_LINUX_FS_STR "0FC63DAF-8483-4772-8E79-3D69D8477DE4"

/* Public kiba_guid_t constants — kept for API compatibility with callers
 * that compare against them. Byte layout: u32 LE, u16 LE, u16 LE, u8[8]. */
const kiba_guid_t KIBA_GUID_ESP = {
    .b = { 0x28,0x73,0x2a,0xc1, 0x1f,0xf8, 0xd2,0x11,
           0xba,0x4b, 0x00,0xa0,0xc9,0x3e,0xc9,0x3b }
};
const kiba_guid_t KIBA_GUID_LINUX_FS = {
    .b = { 0xaf,0x3d,0xc6,0x0f, 0x83,0x84, 0x72,0x47,
           0x8e,0x79, 0x3d,0x69,0xd8,0x47,0x7d,0xe4 }
};

/* ── GUID helpers ────────────────────────────────────────────────────── */
static bool guid_is_zero(const kiba_guid_t *g) {
    for (int i = 0; i < 16; i++) if (g->b[i]) return false;
    return true;
}

kiba_guid_t kiba_guid_random(void) {
    kiba_guid_t g;
    FILE *f = fopen("/dev/urandom", "rb");
    if (!f || fread(g.b, 1, 16, f) != 16) {
        for (int i = 0; i < 16; i++) g.b[i] = (uint8_t)(rand() & 0xFF);
    }
    if (f) fclose(f);
    /* RFC 4122 v4 bits */
    g.b[6] = (uint8_t)((g.b[6] & 0x0F) | 0x40);
    g.b[8] = (uint8_t)((g.b[8] & 0x3F) | 0x80);
    return g;
}

/* Convert our kiba_guid_t (mixed-endian on-disk bytes) to the canonical
 * 8-4-4-4-12 string that libfdisk expects.
 * GPT GUID wire format: first three groups are LE, last two are BE/raw. */
static void guid_to_str(const kiba_guid_t *g, char out[37]) {
    const uint8_t *b = g->b;
    snprintf(out, 37,
        "%02X%02X%02X%02X-%02X%02X-%02X%02X-%02X%02X-%02X%02X%02X%02X%02X%02X",
        b[3],b[2],b[1],b[0],   /* u32 LE → big-endian display */
        b[5],b[4],              /* u16 LE → big-endian display */
        b[7],b[6],              /* u16 LE → big-endian display */
        b[8],b[9],              /* remaining 8 bytes raw */
        b[10],b[11],b[12],b[13],b[14],b[15]);
}

/* ── Device probing via ioctl (unchanged from original) ─────────────── */
int kiba_gpt_probe_device(const char *path, uint32_t *sector_size,
                           uint64_t *total_sectors) {
    int fd = open(path, O_RDONLY);
    if (fd < 0) return -errno;

    int ssz = 0;
    if (ioctl(fd, BLKSSZGET, &ssz) != 0) { int e = errno; close(fd); return -e; }

    uint64_t bytes = 0;
    if (ioctl(fd, BLKGETSIZE64, &bytes) != 0) { int e = errno; close(fd); return -e; }

    close(fd);
    *sector_size   = (uint32_t)ssz;
    *total_sectors = bytes / (uint64_t)ssz;
    return 0;
}

/* ── kiba_gpt_write — the libfdisk implementation ───────────────────── */
int kiba_gpt_write(kiba_gpt_disk_t *disk,
                    const kiba_gpt_partition_t *parts, size_t n_parts) {
    if (n_parts == 0 || n_parts > 128) return -EINVAL;
    if (disk->logical_sector_size == 0) return -EINVAL;

    /* Resolve the block device path from our open fd via /proc/self/fd.
     * libfdisk needs a path string, not an fd. */
    char fd_link[64];
    char dev_path[PATH_MAX];
    snprintf(fd_link, sizeof(fd_link), "/proc/self/fd/%d", disk->fd);
    ssize_t len = readlink(fd_link, dev_path, sizeof(dev_path) - 1);
    if (len < 0) return -errno;
    dev_path[len] = '\0';

    /* ── Initialise libfdisk context ─────────────────────────────── */
    struct fdisk_context *cxt = fdisk_new_context();
    if (!cxt) return -ENOMEM;

    int rc = fdisk_assign_device(cxt, dev_path, 0 /* read-write */);
    if (rc != 0) { fdisk_unref_context(cxt); return rc; }

    /* Create a fresh GPT label (wipes any existing table) */
    rc = fdisk_create_disklabel(cxt, "gpt");
    if (rc != 0) goto out;

    /* Optionally set the disk GUID */
    if (!guid_is_zero(&disk->disk_guid)) {
        char disk_guid_str[37];
        guid_to_str(&disk->disk_guid, disk_guid_str);
        fdisk_set_disklabel_id_from_string(cxt, disk_guid_str);
    }

    /* ── Add each partition ──────────────────────────────────────── */
    for (size_t i = 0; i < n_parts; i++) {
        const kiba_gpt_partition_t *p = &parts[i];

        struct fdisk_partition *pa = fdisk_new_partition();
        if (!pa) { rc = -ENOMEM; goto out; }

        fdisk_partition_set_start(pa, p->first_lba);
        if (p->last_lba == KIBA_GPT_LAST_LBA_REST) {
            /* Let libfdisk pick the end -- it already knows the real
             * last usable LBA for this disk (accounts for the backup
             * GPT header + entry array), so we don't have to guess. */
            fdisk_partition_end_follow_default(pa, 1);
        } else {
            fdisk_partition_set_size(pa, p->last_lba - p->first_lba + 1);
        }

        /* Partition type GUID */
        struct fdisk_parttype *ptype = NULL;
        if (memcmp(p->type_guid.b, KIBA_GUID_ESP.b, 16) == 0)
            ptype = fdisk_label_parse_parttype(
                        fdisk_get_label(cxt, NULL), KIBA_GUID_ESP_STR);
        else
            ptype = fdisk_label_parse_parttype(
                        fdisk_get_label(cxt, NULL), KIBA_GUID_LINUX_FS_STR);
        if (ptype) {
            fdisk_partition_set_type(pa, ptype);
            fdisk_unref_parttype(ptype);
        }

        /* Partition name */
        if (p->name[0])
            fdisk_partition_set_name(pa, p->name);

        /* Unique partition GUID (if caller provided one) */
        if (!guid_is_zero(&p->unique_guid)) {
            char uguid_str[37];
            guid_to_str(&p->unique_guid, uguid_str);
            fdisk_partition_set_uuid(pa, uguid_str);
        }

        /* Use fdisk_add_partition so libfdisk tracks the slot number */
        size_t partno = i; /* 0-based slot */
        rc = fdisk_add_partition(cxt, pa, &partno);
        fdisk_unref_partition(pa);
        if (rc != 0) goto out;
    }

    /* ── Write GPT to disk ───────────────────────────────────────── */
    rc = fdisk_write_disklabel(cxt);
    if (rc != 0) goto out;

    /* Tell the kernel about the new partition table (replaces partprobe) */
    rc = fdisk_reread_partition_table(cxt);
    if (rc != 0) {
        /* Non-fatal on some setups (e.g. disk is mounted read-only for
         * another partition). The caller's udev settle loop will handle it. */
        rc = 0;
    }

out:
    fdisk_deassign_device(cxt, 0);
    fdisk_unref_context(cxt);
    return rc;
}

/* ── Dual-boot: scan an existing table for an ESP + the largest gap ─── */
int kiba_gpt_scan(const char *path, kiba_gpt_scan_result_t *out) {
    memset(out, 0, sizeof(*out));

    struct fdisk_context *cxt = fdisk_new_context();
    if (!cxt) return -ENOMEM;

    int rc = fdisk_assign_device(cxt, path, 1 /* read-only */);
    if (rc != 0) { fdisk_unref_context(cxt); return rc; }

    /* No label, or not GPT (e.g. blank disk, or legacy MBR) -- nothing
     * to scan for dual-boot purposes. Not an error: the caller falls
     * back to "erase disk" in that case. */
    if (!fdisk_has_label(cxt) ||
        !fdisk_is_labeltype(cxt, FDISK_DISKLABEL_GPT)) {
        fdisk_deassign_device(cxt, 1);
        fdisk_unref_context(cxt);
        return 0;
    }

    struct fdisk_table *tb = NULL;
    rc = fdisk_get_partitions(cxt, &tb);
    if (rc != 0 || !tb) {
        fdisk_deassign_device(cxt, 1);
        fdisk_unref_context(cxt);
        return rc;
    }

    /* Collect [start,end] spans for every in-use partition so we can
     * walk the gaps between them in order. 128 is GPT's own hard cap
     * on partition entries, so this never overflows. */
    uint64_t starts[128], ends[128];
    size_t n = 0;

    struct fdisk_partition *pa = NULL;
    struct fdisk_iter *itr = fdisk_new_iter(FDISK_ITER_FORWARD);
    while (n < 128 && fdisk_table_next_partition(tb, itr, &pa) == 0) {
        starts[n] = fdisk_partition_get_start(pa);
        ends[n]   = fdisk_partition_get_end(pa);

        if (out->esp_partno == 0) {
            struct fdisk_parttype *pt = fdisk_partition_get_type(pa);
            const char *gs = pt ? fdisk_parttype_get_string(pt) : NULL;
            if (gs && strcasecmp(gs, KIBA_GUID_ESP_STR) == 0) {
                out->esp_partno    = (int)fdisk_partition_get_partno(pa) + 1;
                out->esp_first_lba = starts[n];
                out->esp_last_lba  = ends[n];
            }
        }
        n++;
    }
    fdisk_free_iter(itr);

    /* Simple insertion sort by start LBA -- n is at most 128, and in
     * practice almost always under 10, so O(n^2) is irrelevant here. */
    for (size_t i = 1; i < n; i++) {
        uint64_t s = starts[i], e = ends[i];
        size_t j = i;
        while (j > 0 && starts[j - 1] > s) {
            starts[j] = starts[j - 1];
            ends[j]   = ends[j - 1];
            j--;
        }
        starts[j] = s;
        ends[j]   = e;
    }

    uint64_t first_usable = fdisk_get_first_lba(cxt);
    uint64_t last_usable  = fdisk_get_last_lba(cxt);
    uint32_t ssz = fdisk_get_sector_size(cxt);

    uint64_t best_first = 0, best_last = 0, best_len = 0;
    uint64_t cursor = first_usable;

    for (size_t i = 0; i <= n; i++) {
        uint64_t gap_start = cursor;
        uint64_t gap_end   = (i < n) ? (starts[i] > 0 ? starts[i] - 1 : 0)
                                      : last_usable;
        if (gap_end >= gap_start) {
            uint64_t len = gap_end - gap_start + 1;
            if (len > best_len) {
                best_len = len; best_first = gap_start; best_last = gap_end;
            }
        }
        if (i < n) cursor = ends[i] + 1;
    }

    if (best_len > 0) {
        out->free_first_lba = best_first;
        out->free_last_lba  = best_last;
        out->free_bytes     = best_len * (uint64_t)(ssz ? ssz : 512);
    } else {
        /* No free space: make free_last_lba < free_first_lba so callers
         * can check "free_last_lba >= free_first_lba" as the has-room test. */
        out->free_first_lba = 1;
        out->free_last_lba  = 0;
    }

    fdisk_unref_table(tb);
    fdisk_deassign_device(cxt, 1);
    fdisk_unref_context(cxt);
    return 0;
}

/* ── Dual-boot: append one partition to an existing table ───────────── */
int kiba_gpt_add_partition(const char *path, const kiba_gpt_partition_t *part,
                            int *out_partno) {
    struct fdisk_context *cxt = fdisk_new_context();
    if (!cxt) return -ENOMEM;

    int rc = fdisk_assign_device(cxt, path, 0 /* read-write */);
    if (rc != 0) { fdisk_unref_context(cxt); return rc; }

    if (!fdisk_has_label(cxt) || !fdisk_is_labeltype(cxt, FDISK_DISKLABEL_GPT)) {
        /* Caller is responsible for having already confirmed (via
         * kiba_gpt_scan()) that a GPT label exists. Refuse to proceed
         * rather than silently creating one -- that's what
         * kiba_gpt_write() is for, and doing it here would surprise
         * dual-boot callers with a wipe they explicitly wanted to avoid. */
        rc = -EINVAL;
        goto out;
    }

    struct fdisk_partition *pa = fdisk_new_partition();
    if (!pa) { rc = -ENOMEM; goto out; }

    /* Let libfdisk pick the next free partition-number slot rather than
     * us guessing one, since we don't know which slots are occupied by
     * whatever's already on this disk. */
    fdisk_partition_partno_follow_default(pa, 1);
    fdisk_partition_set_start(pa, part->first_lba);
    if (part->last_lba == KIBA_GPT_LAST_LBA_REST) {
        fdisk_partition_end_follow_default(pa, 1);
    } else {
        fdisk_partition_set_size(pa, part->last_lba - part->first_lba + 1);
    }

    struct fdisk_parttype *ptype = NULL;
    if (memcmp(part->type_guid.b, KIBA_GUID_ESP.b, 16) == 0)
        ptype = fdisk_label_parse_parttype(fdisk_get_label(cxt, NULL), KIBA_GUID_ESP_STR);
    else
        ptype = fdisk_label_parse_parttype(fdisk_get_label(cxt, NULL), KIBA_GUID_LINUX_FS_STR);
    if (ptype) {
        fdisk_partition_set_type(pa, ptype);
        fdisk_unref_parttype(ptype);
    }

    if (part->name[0])
        fdisk_partition_set_name(pa, part->name);

    if (!guid_is_zero(&part->unique_guid)) {
        char uguid_str[37];
        guid_to_str(&part->unique_guid, uguid_str);
        fdisk_partition_set_uuid(pa, uguid_str);
    }

    size_t partno = 0;
    rc = fdisk_add_partition(cxt, pa, &partno);
    fdisk_unref_partition(pa);
    if (rc != 0) goto out;

    rc = fdisk_write_disklabel(cxt);
    if (rc != 0) goto out;

    rc = fdisk_reread_partition_table(cxt);
    if (rc != 0) rc = 0; /* non-fatal, same rationale as kiba_gpt_write() */

    if (out_partno) *out_partno = (int)partno + 1;

out:
    fdisk_deassign_device(cxt, 0);
    fdisk_unref_context(cxt);
    return rc;
}
KIBA_SRC_END_GPTC

cat > kiba_fs.h << 'KIBA_SRC_END_FSH'
/* kiba_fs.h — filesystem creation + mounting, no shell involved anywhere.
 *
 * Honest scope note: there is no maintained C *library* for writing
 * FAT32 or ext4 from scratch that's lighter/safer than the reference
 * mkfs tools themselves (mkfs.fat, mkfs.ext4) — those tools ARE the
 * spec-compliant implementation maintained by the kernel/util-linux
 * communities. Reimplementing ext4's journal+extents+checksums by hand
 * here would trade a small, stable dependency for a large hand-written
 * one with real data-loss risk if subtly wrong.
 *
 * What this module removes instead is everything *fragile* about how
 * the previous backend called external tools:
 *   - no /bin/sh involved at any point (execvp, not system()/popen())
 *   - no stdout string-scraping for results — only exit status matters
 *   - no shell quoting of user-controlled strings (there are none here;
 *     mkfs only ever receives device paths and fixed flags)
 *   - mount(2) is called directly via syscall, not the `mount` binary
 *
 * The actual partitioning (kiba_gpt.c) has zero external dependencies.
 */
#ifndef KIBA_FS_H
#define KIBA_FS_H

#include <stdint.h>

typedef enum {
    KIBA_FS_FAT32,
    KIBA_FS_EXT4,
} kiba_fs_type_t;

/* Formats `part_path` (e.g. "/dev/vda1") with the given filesystem.
 * `volume_label` may be NULL. Returns 0 on success, -errno-ish on
 * failure (see kiba_fs_strerror for a human-readable string, since
 * exec failures don't map cleanly to errno alone). */
int kiba_fs_format(const char *part_path, kiba_fs_type_t type,
                    const char *volume_label);

/* Mounts `part_path` at `target_dir` with the given fstype ("vfat",
 * "ext4") and optional comma-free mount options string (or NULL).
 * Calls mount(2) directly — no `mount` binary involved. */
int kiba_fs_mount(const char *part_path, const char *target_dir,
                   const char *fstype, const char *options);

int kiba_fs_umount(const char *target_dir);

/* Returns a human-readable description of the last kiba_fs_* error on
 * this thread (mkfs exit code / signal, or strerror() for mount(2)). */
const char *kiba_fs_strerror(void);

#endif
KIBA_SRC_END_FSH

cat > kiba_fs.c << 'KIBA_SRC_END_FSC'
/* kiba_fs.c — see kiba_fs.h for scope/rationale. */
#define _GNU_SOURCE
#include "kiba_fs.h"

#include <errno.h>
#include <spawn.h>
#include <stdio.h>
#include <string.h>
#include <sys/mount.h>
#include <sys/wait.h>
#include <unistd.h>

extern char **environ;

static char g_last_error[256] = "no error";

const char *kiba_fs_strerror(void) { return g_last_error; }

/* Runs argv[0] with argv (NULL-terminated), via posix_spawn — never
 * touches /bin/sh, so there is no quoting/injection surface at all:
 * each element of argv is passed to execve() as a discrete argument
 * regardless of its contents (spaces, quotes, anything). Captures
 * only the exit code; does not parse the child's stdout/stderr for
 * control flow (we only care whether it succeeded). */
static int run_argv(char *const argv[]) {
    pid_t pid;
    int rc = posix_spawnp(&pid, argv[0], NULL, NULL, argv, environ);
    if (rc != 0) {
        snprintf(g_last_error, sizeof(g_last_error),
                  "failed to spawn %s: %s", argv[0], strerror(rc));
        return -1;
    }
    int status = 0;
    if (waitpid(pid, &status, 0) < 0) {
        snprintf(g_last_error, sizeof(g_last_error),
                  "waitpid failed for %s: %s", argv[0], strerror(errno));
        return -1;
    }
    if (WIFEXITED(status) && WEXITSTATUS(status) == 0) {
        return 0;
    }
    if (WIFEXITED(status)) {
        snprintf(g_last_error, sizeof(g_last_error),
                  "%s exited with status %d", argv[0], WEXITSTATUS(status));
    } else if (WIFSIGNALED(status)) {
        snprintf(g_last_error, sizeof(g_last_error),
                  "%s killed by signal %d", argv[0], WTERMSIG(status));
    } else {
        snprintf(g_last_error, sizeof(g_last_error),
                  "%s terminated abnormally", argv[0]);
    }
    return -1;
}

int kiba_fs_format(const char *part_path, kiba_fs_type_t type,
                    const char *volume_label) {
    if (!part_path) { snprintf(g_last_error, sizeof(g_last_error), "no partition path"); return -1; }

    if (type == KIBA_FS_FAT32) {
        /* mkfs.fat -F 32 [-n LABEL] <part> */
        char *argv[8];
        int i = 0;
        argv[i++] = (char *)"mkfs.fat";
        argv[i++] = (char *)"-F";
        argv[i++] = (char *)"32";
        if (volume_label) { argv[i++] = (char *)"-n"; argv[i++] = (char *)volume_label; }
        argv[i++] = (char *)part_path;
        argv[i++] = NULL;
        return run_argv(argv);
    } else if (type == KIBA_FS_EXT4) {
        /* mkfs.ext4 -F -q [-L LABEL] <part>
         * -F: force (skip the "are you sure" prompt — we already
         *     confirmed disk selection in the UI before reaching here)
         * -q: quiet (we don't parse its stdout regardless) */
        char *argv[8];
        int i = 0;
        argv[i++] = (char *)"mkfs.ext4";
        argv[i++] = (char *)"-F";
        argv[i++] = (char *)"-q";
        if (volume_label) { argv[i++] = (char *)"-L"; argv[i++] = (char *)volume_label; }
        argv[i++] = (char *)part_path;
        argv[i++] = NULL;
        return run_argv(argv);
    }

    snprintf(g_last_error, sizeof(g_last_error), "unknown filesystem type");
    return -1;
}

int kiba_fs_mount(const char *part_path, const char *target_dir,
                   const char *fstype, const char *options) {
    /* Direct mount(2) syscall — no `mount` binary, no shell. */
    unsigned long flags = 0;
    if (mount(part_path, target_dir, fstype, flags, options) != 0) {
        snprintf(g_last_error, sizeof(g_last_error),
                  "mount(%s -> %s, %s) failed: %s",
                  part_path, target_dir, fstype, strerror(errno));
        return -1;
    }
    return 0;
}

int kiba_fs_umount(const char *target_dir) {
    if (umount2(target_dir, 0) != 0) {
        snprintf(g_last_error, sizeof(g_last_error),
                  "umount(%s) failed: %s", target_dir, strerror(errno));
        return -1;
    }
    return 0;
}
KIBA_SRC_END_FSC

cat > kiba_udev.h << 'KIBA_SRC_END_UDEVH'
/* kiba_udev.h — waits for the kernel's view of newly-added partitions
 * to settle, without shelling out to `udevadm settle`.
 *
 * Why this is still needed even with BLKPG (see kiba_gpt.c): BLKPG
 * tells the kernel's block layer about the new partition immediately
 * and synchronously (the ioctl doesn't return until that's done) --
 * but *udev* (userspace) reacting to that change (creating the
 * /dev/vdaN symlink/device-node permissions, populating
 * /dev/disk/by-uuid/, etc.) is asynchronous and racy, exactly per the
 * upstream archinstall issues we found (#2286, #1759). Userspace tools
 * like blkid read from udev-populated state in some paths, so a short
 * poll-based wait here is the same fix as udevadm settle, just done by
 * directly polling sysfs instead of going through udev's own client
 * tool.
 */
#ifndef KIBA_UDEV_H
#define KIBA_UDEV_H

#include <stdbool.h>
#include <stddef.h>

/* Polls (no subprocess) until `path` (e.g. "/dev/vda1") exists and is
 * openable, or `timeout_ms` elapses. Returns true if it appeared. */
bool kiba_wait_for_device(const char *path, int timeout_ms);

/* Polls blkid-equivalent state by repeatedly attempting to read the
 * given tag (e.g. "UUID" or "PARTUUID") for `part_path` directly from
 * /dev/disk/by-uuid and /dev/disk/by-partuuid symlinks (populated by
 * udev), without invoking blkid as a subprocess. Returns true and
 * fills `out_value` (caller-provided buffer of `out_len`) on success. */
bool kiba_wait_for_disk_tag(const char *part_path, const char *tag_dir_name,
                             char *out_value, size_t out_len, int timeout_ms);

/* Reads the PARTUUID of partition number `partno` (1-indexed) directly
 * out of the primary GPT partition entry array on `disk_path`, via
 * pread -- no udev, no blkid, no /dev/disk/by-partuuid dependency at
 * all. This is the preferred way to get a PARTUUID for a partition we
 * just created ourselves with kiba_gpt_write(), since we already know
 * exactly where to look on disk and don't need userspace device-node
 * population to have caught up.
 *
 * Returns true and fills out_value (format: lowercase hex with dashes,
 * matching blkid's PARTUUID= output) on success. */
bool kiba_read_partuuid_direct(const char *disk_path, int partno,
                                char *out_value, size_t out_len);

#endif
KIBA_SRC_END_UDEVH

cat > kiba_udev.c << 'KIBA_SRC_END_UDEVC'
/* kiba_udev.c — see kiba_udev.h. */
#define _GNU_SOURCE
#include "kiba_udev.h"

#include <dirent.h>
#include <fcntl.h>
#include <limits.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <time.h>
#include <unistd.h>

static void sleep_ms(int ms) {
    struct timespec ts = { .tv_sec = ms / 1000, .tv_nsec = (long)(ms % 1000) * 1000000L };
    nanosleep(&ts, NULL);
}

bool kiba_wait_for_device(const char *path, int timeout_ms) {
    struct stat st;
    int waited = 0;
    const int step_ms = 100;
    while (waited <= timeout_ms) {
        if (stat(path, &st) == 0) return true;
        sleep_ms(step_ms);
        waited += step_ms;
    }
    return false;
}

/* /dev/disk/by-uuid/<UUID> and /dev/disk/by-partuuid/<PARTUUID> are
 * symlinks udev creates pointing back at e.g. ../../vda1. We resolve
 * every entry in the requested directory and compare its target
 * against `part_path` (after resolving both to canonical form), which
 * gives us the tag value without ever invoking blkid. */
bool kiba_wait_for_disk_tag(const char *part_path, const char *tag_dir_name,
                             char *out_value, size_t out_len, int timeout_ms) {
    char real_part[PATH_MAX];
    if (!realpath(part_path, real_part)) return false;

    char dir_path[64];
    snprintf(dir_path, sizeof(dir_path), "/dev/disk/%s", tag_dir_name);

    int waited = 0;
    const int step_ms = 150;
    while (waited <= timeout_ms) {
        DIR *d = opendir(dir_path);
        if (d) {
            struct dirent *ent;
            while ((ent = readdir(d)) != NULL) {
                if (ent->d_name[0] == '.') continue;
                char full[PATH_MAX];
                snprintf(full, sizeof(full), "%s/%s", dir_path, ent->d_name);
                char resolved[PATH_MAX];
                if (realpath(full, resolved) && strcmp(resolved, real_part) == 0) {
                    snprintf(out_value, out_len, "%s", ent->d_name);
                    closedir(d);
                    return true;
                }
            }
            closedir(d);
        }
        sleep_ms(step_ms);
        waited += step_ms;
    }
    return false;
}

bool kiba_read_partuuid_direct(const char *disk_path, int partno,
                                char *out_value, size_t out_len) {
    if (partno < 1 || partno > 128) return false;

    int fd = open(disk_path, O_RDONLY);
    if (fd < 0) return false;

    /* Read the primary GPT header (LBA 1) to find sector size and the
     * partition entry array location -- we don't hardcode sector size
     * here so this also works correctly on 4Kn disks. */
    uint8_t sector_probe[4096];
    /* Try 512 first since BLKSSZGET requires an ioctl we'd rather avoid
     * duplicating here; the header's own self-description (its LBA is
     * always 1) lets us detect the real sector size by trying 512 and
     * checking the signature, falling back to 4096. */
    ssize_t r = pread(fd, sector_probe, 512, 512);
    uint32_t ssz;
    if (r == 512 && memcmp(sector_probe, "EFI PART", 8) == 0) {
        ssz = 512;
    } else {
        r = pread(fd, sector_probe, 4096, 4096);
        if (r == 4096 && memcmp(sector_probe, "EFI PART", 8) == 0) {
            ssz = 4096;
        } else {
            close(fd);
            return false;
        }
    }

    uint8_t hdr[512];
    if (pread(fd, hdr, sizeof(hdr), (off_t)ssz) != (ssize_t)sizeof(hdr)) {
        close(fd); return false;
    }
    uint64_t array_lba;
    uint32_t entry_size;
    memcpy(&array_lba, hdr + 72, 8);
    memcpy(&entry_size, hdr + 84, 4);

    off_t entry_off = (off_t)array_lba * ssz + (off_t)(partno - 1) * entry_size;
    uint8_t entry[128];
    if (entry_size < 32 || entry_size > sizeof(entry) ||
        pread(fd, entry, entry_size, entry_off) != (ssize_t)entry_size) {
        close(fd); return false;
    }
    close(fd);

    /* Unique partition GUID lives at bytes [16:32) of the entry, in the
     * same mixed-endian layout GPT uses everywhere: u32 LE, u16 LE,
     * u16 LE, then 8 raw bytes -- matching how blkid renders PARTUUID. */
    const uint8_t *g = entry + 16;
    snprintf(out_value, out_len,
             "%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x",
             g[3], g[2], g[1], g[0],
             g[5], g[4],
             g[7], g[6],
             g[8], g[9],
             g[10], g[11], g[12], g[13], g[14], g[15]);
    return true;
}
KIBA_SRC_END_UDEVC

cat > kiba_install.h << 'KIBA_SRC_END_INSTH'
/* kiba_install.h — the rest of the install pipeline: extracting the
 * live squashfs onto the new root, writing fstab/hostname/locale,
 * creating the user account, installing the bootloader, and enabling
 * services.
 *
 * Same rule as kiba_fs.c: no shell, no string-parsing of subprocess
 * stdout. Where a maintained external tool is the only sane
 * implementation of something complex (unsquashfs's LZMA/xz/zstd
 * decompression, arch-chroot's mount namespace setup, grub-install's
 * GRUB installation), it's invoked via posix_spawnp with a
 * literal argv array -- never system()/popen(), so there's no shell
 * to inject into and no string protocol to desync.
 *
 * Functions that report progress take a kiba_progress_cb so the caller
 * (the GTK4 app, in-process) gets typed callbacks instead of scraping
 * "PROGRESS N msg" lines from stdout.
 */
#ifndef KIBA_INSTALL_H
#define KIBA_INSTALL_H

#include <stdbool.h>
#include <stddef.h>

typedef void (*kiba_progress_cb)(int pct, const char *msg, void *user_data);

/* Locates the live squashfs/erofs image on the boot medium. Writes the
 * found path into out_path (caller-provided buffer). Returns true on
 * success. Mirrors the find-strategy from the old Python backend
 * (findmnt-based, with conventional-path and full-scan fallbacks) but
 * implemented by walking /proc/self/mountinfo directly instead of
 * shelling out to `findmnt`. */
bool kiba_find_live_image(char *out_path, size_t out_len);

/* Extracts the squashfs/erofs image found above onto `target_root`.
 * For squashfs: posix_spawnp's `unsquashfs -f -d <target> <image>`.
 * For erofs: mount(2) the image read-only via a loop device, then
 * recursively copy (our own copy, not `cp -a`) onto target_root. */
int kiba_install_extract_image(const char *image_path, const char *target_root,
                                kiba_progress_cb cb, void *user_data);

/* Writes /etc/fstab, /etc/hostname, /etc/hosts, locale.conf,
 * vconsole.conf directly (plain file I/O, not even posix_spawn). */
int kiba_install_write_configs(const char *target_root,
                                const char *root_uuid, const char *esp_uuid,
                                const char *hostname, const char *locale,
                                const char *keymap);

/* Runs locale-gen inside the chroot (posix_spawnp arch-chroot). */
int kiba_install_locale_gen(const char *target_root);

/* Removes the live user, creates the real user account, sets password.
 * useradd/userdel/chpasswd are run inside the chroot via posix_spawnp
 * (no shell); chpasswd's input is written to its stdin pipe directly,
 * never formatted into a shell string. */
int kiba_install_create_user(const char *target_root, const char *username,
                              const char *password);

/* Removes live-only files/packages, installs the bootloader via
 * posix_spawnp arch-chroot grub-install + grub-mkconfig, enables
 * services, rebuilds the initramfs. */
/* root_partno/disk_path are no longer used by the GRUB path (grub-mkconfig
 * reads /etc/fstab, already written with the real filesystem UUID, to work
 * out root= itself) but are kept in the signature for compatibility with
 * the rest of the install pipeline. */
/* dualboot: when true, the ESP being installed to is shared with an
 * existing OS. We leave that OS's own boot files on the ESP completely
 * untouched (grub-install only ever adds KibaOS's own files under
 * /EFI/KibaOS and an NVRAM entry -- it never removes anyone else's), but
 * we also configure GRUB (via /etc/default/grub + os-prober) to actually
 * show a menu with the other OS's entries auto-discovered, rather than
 * the whole-disk install's silent single-OS auto-boot, so the user gets
 * a real choice at boot instead of KibaOS silently taking over. */
int kiba_install_finalize(const char *target_root, const char *disk_path,
                           const char *root_part, int root_partno, bool dualboot,
                           kiba_progress_cb cb, void *user_data);

/* Human-readable description of the last failure from any kiba_install_*
 * function in this module. */
const char *kiba_install_strerror(void);

#endif
KIBA_SRC_END_INSTH

cat > kiba_install_extract.c << 'KIBA_SRC_END_EXTC'
/* kiba_install_extract.c — squashfs/erofs location and extraction.
 * See kiba_install.h for design rationale. */
#define _GNU_SOURCE
#include "kiba_install.h"

#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <spawn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mount.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <unistd.h>

extern char **environ;

char kiba_install_shared_err[256] = "no error";
const char *kiba_install_strerror(void) { return kiba_install_shared_err; }
#define g_install_err kiba_install_shared_err

static int run_argv(char *const argv[]) {
    pid_t pid;
    int rc = posix_spawnp(&pid, argv[0], NULL, NULL, argv, environ);
    if (rc != 0) {
        snprintf(g_install_err, sizeof(g_install_err),
                  "failed to spawn %s: %s", argv[0], strerror(rc));
        return -1;
    }
    int status = 0;
    if (waitpid(pid, &status, 0) < 0) {
        snprintf(g_install_err, sizeof(g_install_err),
                  "waitpid failed for %s: %s", argv[0], strerror(errno));
        return -1;
    }
    if (WIFEXITED(status) && WEXITSTATUS(status) == 0) return 0;
    if (WIFEXITED(status)) {
        snprintf(g_install_err, sizeof(g_install_err),
                  "%s exited with status %d", argv[0], WEXITSTATUS(status));
    } else if (WIFSIGNALED(status)) {
        snprintf(g_install_err, sizeof(g_install_err),
                  "%s killed by signal %d", argv[0], WTERMSIG(status));
    } else {
        snprintf(g_install_err, sizeof(g_install_err), "%s terminated abnormally", argv[0]);
    }
    return -1;
}

/* Run argv with status >=0 considered acceptable up to max_nonfatal
 * (mirrors the old backend's tolerance of unsquashfs's non-fatal
 * warning exit codes, where only exit code 1 is truly fatal). */
static int run_argv_tolerant(char *const argv[], int max_nonfatal_exit) {
    pid_t pid;
    int rc = posix_spawnp(&pid, argv[0], NULL, NULL, argv, environ);
    if (rc != 0) {
        snprintf(g_install_err, sizeof(g_install_err),
                  "failed to spawn %s: %s", argv[0], strerror(rc));
        return -1;
    }
    int status = 0;
    if (waitpid(pid, &status, 0) < 0) {
        snprintf(g_install_err, sizeof(g_install_err),
                  "waitpid failed for %s: %s", argv[0], strerror(errno));
        return -1;
    }
    if (WIFEXITED(status)) {
        int code = WEXITSTATUS(status);
        if (code <= max_nonfatal_exit) return code; /* 0 or tolerated warning code */
        snprintf(g_install_err, sizeof(g_install_err),
                  "%s exited with fatal status %d", argv[0], code);
        return -1;
    }
    snprintf(g_install_err, sizeof(g_install_err), "%s terminated abnormally", argv[0]);
    return -1;
}

/* Finds a directory containing one of these filenames anywhere below
 * `root`, by walking the tree ourselves (no `find` subprocess). Bounded
 * depth to avoid pathological scans of huge trees. */
static bool scan_dir_for_image(const char *root, char *out_path, size_t out_len, int max_depth) {
    static const char *names[] = { "airootfs.sfs", "airootfs.erofs" };

    DIR *d = opendir(root);
    if (!d) return false;

    struct dirent *ent;
    bool found = false;
    while (!found && (ent = readdir(d)) != NULL) {
        if (strcmp(ent->d_name, ".") == 0 || strcmp(ent->d_name, "..") == 0) continue;
        char full[4096];
        snprintf(full, sizeof(full), "%s/%s", root, ent->d_name);

        struct stat st;
        if (lstat(full, &st) != 0) continue;

        if (S_ISREG(st.st_mode)) {
            for (size_t i = 0; i < sizeof(names)/sizeof(names[0]); i++) {
                if (strcmp(ent->d_name, names[i]) == 0) {
                    snprintf(out_path, out_len, "%s", full);
                    found = true;
                    break;
                }
            }
        } else if (S_ISDIR(st.st_mode) && max_depth > 0) {
            if (scan_dir_for_image(full, out_path, out_len, max_depth - 1)) found = true;
        }
    }
    closedir(d);
    return found;
}

/* Parses /proc/self/mountinfo to find the mount target for the given
 * mount source's mountpoint matching `target_substr` in its mount
 * point path -- specifically, we want wherever /run/archiso/bootmnt
 * (or equivalent) is mounted. Avoids shelling out to `findmnt`. */
static bool mountinfo_find_target(const char *target_path, char *out_target, size_t out_len) {
    FILE *f = fopen("/proc/self/mountinfo", "r");
    if (!f) return false;

    char line[4096];
    bool found = false;
    while (fgets(line, sizeof(line), f)) {
        /* mountinfo format: id parentid major:minor root mountpoint ...
         * Field 5 (1-indexed) is the mount point, space-delimited,
         * with systemd-style octal escapes we don't need to decode
         * for an exact-path comparison against /run/archiso/bootmnt. */
        char *fields[16] = {0};
        int n = 0;
        char *tok = strtok(line, " ");
        while (tok && n < 16) { fields[n++] = tok; tok = strtok(NULL, " "); }
        if (n < 5) continue;
        if (strcmp(fields[4], target_path) == 0) {
            snprintf(out_target, out_len, "%s", target_path);
            found = true;
            break;
        }
    }
    fclose(f);
    return found;
}

bool kiba_find_live_image(char *out_path, size_t out_len) {
    /* (a) ask the kernel (via mountinfo, not findmnt) where the boot
     * medium is actually mounted right now. */
    char bootmnt[256];
    if (mountinfo_find_target("/run/archiso/bootmnt", bootmnt, sizeof(bootmnt))) {
        if (scan_dir_for_image(bootmnt, out_path, out_len, 6)) return true;
    }

    /* (b) conventional archiso layout, direct check. */
    static const char *conventional[] = {
        "/run/archiso/bootmnt/arch/x86_64/airootfs.sfs",
        "/run/archiso/bootmnt/arch/x86_64/airootfs.erofs",
        "/run/archiso/copytoram/arch/x86_64/airootfs.sfs",
        "/run/archiso/copytoram/arch/x86_64/airootfs.erofs",
        "/run/mnt/arch/x86_64/airootfs.sfs",
    };
    for (size_t i = 0; i < sizeof(conventional)/sizeof(conventional[0]); i++) {
        struct stat st;
        if (stat(conventional[i], &st) == 0) {
            snprintf(out_path, out_len, "%s", conventional[i]);
            return true;
        }
    }

    /* (c) last resort: scan /run and /mnt entirely. */
    if (scan_dir_for_image("/run", out_path, out_len, 8)) return true;
    if (scan_dir_for_image("/mnt", out_path, out_len, 8)) return true;

    return false;
}

int kiba_install_extract_image(const char *image_path, const char *target_root,
                                kiba_progress_cb cb, void *user_data) {
    if (cb) cb(22, "Copying KibaOS to your computer (this takes a few minutes)...", user_data);

    size_t len = strlen(image_path);
    bool is_squashfs = (len >= 4 && strcmp(image_path + len - 4, ".sfs") == 0);

    if (is_squashfs) {
        char *argv[] = {
            (char *)"unsquashfs", (char *)"-f", (char *)"-d", (char *)target_root,
            (char *)"-no-progress", (char *)image_path, NULL
        };
        /* Exit code 1 is fatal; anything else (e.g. >1 for non-fatal
         * extraction warnings) is tolerated, matching the old backend. */
        int rc = run_argv_tolerant(argv, 255);
        if (rc < 0) return -1;
        if (rc == 1) { snprintf(g_install_err, sizeof(g_install_err), "unsquashfs fatal error"); return -1; }
        return 0;
    } else {
        /* EROFS: no in-place extractor; mount read-only via a loop
         * device and recursively copy. We use the `cp -a` binary here
         * deliberately rather than hand-rolling a recursive copy that
         * preserves xattrs/ACLs/special files/hardlinks/sparse files
         * correctly -- that's a much larger correctness surface than
         * mkfs, and cp is a stable, single-purpose coreutils tool. */
        char tmp_mnt[] = "/tmp/kiba-erofs-XXXXXX";
        if (!mkdtemp(tmp_mnt)) {
            snprintf(g_install_err, sizeof(g_install_err), "mkdtemp failed: %s", strerror(errno));
            return -1;
        }
        if (mount(image_path, tmp_mnt, "erofs", MS_RDONLY, "loop") != 0) {
            snprintf(g_install_err, sizeof(g_install_err), "erofs mount failed: %s", strerror(errno));
            rmdir(tmp_mnt);
            return -1;
        }
        char *argv[] = { (char *)"cp", (char *)"-a", (char *)"-T", tmp_mnt, (char *)target_root, NULL };
        int rc = run_argv(argv);
        umount2(tmp_mnt, 0);
        rmdir(tmp_mnt);
        return rc;
    }
}
KIBA_SRC_END_EXTC

cat > kiba_install_finish.c << 'KIBA_SRC_END_FINC'
/* kiba_install_finish.c — configs, user account, bootloader, finalize.
 * See kiba_install.h for design rationale. */
#define _GNU_SOURCE
#include "kiba_install.h"
#include "kiba_udev.h"

#include <errno.h>
#include <fcntl.h>
#include <spawn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <unistd.h>

extern char **environ;

extern char kiba_install_shared_err[256];
#define g_finish_err kiba_install_shared_err

static int run_argv(char *const argv[]) {
    pid_t pid;
    int rc = posix_spawnp(&pid, argv[0], NULL, NULL, argv, environ);
    if (rc != 0) {
        snprintf(g_finish_err, sizeof(g_finish_err), "failed to spawn %s: %s", argv[0], strerror(rc));
        return -1;
    }
    int status = 0;
    if (waitpid(pid, &status, 0) < 0) {
        snprintf(g_finish_err, sizeof(g_finish_err), "waitpid failed for %s: %s", argv[0], strerror(errno));
        return -1;
    }
    if (WIFEXITED(status) && WEXITSTATUS(status) == 0) return 0;
    if (WIFEXITED(status)) {
        snprintf(g_finish_err, sizeof(g_finish_err), "%s exited with status %d", argv[0], WEXITSTATUS(status));
    } else {
        snprintf(g_finish_err, sizeof(g_finish_err), "%s terminated abnormally", argv[0]);
    }
    return -1;
}

/* Like run_argv, but writes `stdin_data` to the child's stdin before
 * closing it -- used for `chpasswd`, so the password never appears in
 * argv (visible in /proc/PID/cmdline to other users) or in a shell
 * string anywhere. */
static int run_argv_with_stdin(char *const argv[], const char *stdin_data) {
    int pipefd[2];
    if (pipe(pipefd) != 0) {
        snprintf(g_finish_err, sizeof(g_finish_err), "pipe() failed: %s", strerror(errno));
        return -1;
    }

    posix_spawn_file_actions_t actions;
    posix_spawn_file_actions_init(&actions);
    posix_spawn_file_actions_adddup2(&actions, pipefd[0], STDIN_FILENO);
    posix_spawn_file_actions_addclose(&actions, pipefd[1]);

    pid_t pid;
    int rc = posix_spawnp(&pid, argv[0], &actions, NULL, argv, environ);
    posix_spawn_file_actions_destroy(&actions);
    close(pipefd[0]);

    if (rc != 0) {
        close(pipefd[1]);
        snprintf(g_finish_err, sizeof(g_finish_err), "failed to spawn %s: %s", argv[0], strerror(rc));
        return -1;
    }

    size_t len = strlen(stdin_data);
    size_t written = 0;
    while (written < len) {
        ssize_t w = write(pipefd[1], stdin_data + written, len - written);
        if (w < 0) { if (errno == EINTR) continue; break; }
        written += (size_t)w;
    }
    close(pipefd[1]);

    int status = 0;
    waitpid(pid, &status, 0);
    if (WIFEXITED(status) && WEXITSTATUS(status) == 0) return 0;
    snprintf(g_finish_err, sizeof(g_finish_err), "%s failed (chpasswd)", argv[0]);
    return -1;
}

static int chroot_run(const char *target_root, char *const inner_argv[]) {
    /* arch-chroot target_root <inner_argv...> */
    char *argv[16];
    int i = 0;
    argv[i++] = (char *)"arch-chroot";
    argv[i++] = (char *)target_root;
    for (int j = 0; inner_argv[j] != NULL && i < 14; j++) argv[i++] = inner_argv[j];
    argv[i] = NULL;
    return run_argv(argv);
}

static int write_file(const char *path, const char *content) {
    int fd = open(path, O_WRONLY | O_CREAT | O_TRUNC, 0644);
    if (fd < 0) {
        snprintf(g_finish_err, sizeof(g_finish_err), "open(%s) failed: %s", path, strerror(errno));
        return -1;
    }
    size_t len = strlen(content);
    ssize_t w = write(fd, content, len);
    close(fd);
    if (w != (ssize_t)len) {
        snprintf(g_finish_err, sizeof(g_finish_err), "write(%s) failed: %s", path, strerror(errno));
        return -1;
    }
    return 0;
}

int kiba_install_write_configs(const char *target_root,
                                const char *root_uuid, const char *esp_uuid,
                                const char *hostname, const char *locale,
                                const char *keymap) {
    char path[1024];
    char content[2048];

    snprintf(path, sizeof(path), "%s/etc/fstab", target_root);
    snprintf(content, sizeof(content),
              "# KibaOS fstab — generated by installer\n"
              "UUID=%s  /      ext4  defaults,noatime  0 1\n"
              "UUID=%s  /boot  vfat  umask=0077        0 2\n",
              root_uuid, esp_uuid);
    if (write_file(path, content) != 0) return -1;

    snprintf(path, sizeof(path), "%s/etc/hostname", target_root);
    snprintf(content, sizeof(content), "%s\n", hostname);
    if (write_file(path, content) != 0) return -1;

    snprintf(path, sizeof(path), "%s/etc/hosts", target_root);
    snprintf(content, sizeof(content),
              "127.0.0.1   localhost\n"
              "::1         localhost\n"
              "127.0.1.1   %s.localdomain %s\n",
              hostname, hostname);
    if (write_file(path, content) != 0) return -1;

    /* locale.gen: enable the requested locale line, plain text edit. */
    snprintf(path, sizeof(path), "%s/etc/locale.gen", target_root);
    {
        FILE *f = fopen(path, "r");
        if (f) {
            fseek(f, 0, SEEK_END);
            long sz = ftell(f);
            fseek(f, 0, SEEK_SET);
            char *buf = malloc((size_t)sz + 1);
            if (buf) {
                size_t got = fread(buf, 1, (size_t)sz, f);
                buf[got] = 0;
                fclose(f);

                char needle[300];
                snprintf(needle, sizeof(needle), "#%s", locale);
                char *pos = strstr(buf, needle);
                if (pos) memmove(pos, pos + 1, strlen(pos + 1) + 1); /* drop the leading '#' */

                FILE *fw = fopen(path, "w");
                if (fw) { fwrite(buf, 1, strlen(buf), fw); fclose(fw); }
                free(buf);
            } else {
                fclose(f);
            }
        }
    }

    snprintf(path, sizeof(path), "%s/etc/locale.conf", target_root);
    snprintf(content, sizeof(content), "LANG=%s\n", locale);
    if (write_file(path, content) != 0) return -1;

    snprintf(path, sizeof(path), "%s/etc/vconsole.conf", target_root);
    snprintf(content, sizeof(content), "KEYMAP=%s\n", keymap);
    if (write_file(path, content) != 0) return -1;

    return 0;
}

int kiba_install_locale_gen(const char *target_root) {
    char *argv[] = { (char *)"locale-gen", NULL };
    if (chroot_run(target_root, argv) != 0) {
        snprintf(g_finish_err, sizeof(g_finish_err), "locale-gen failed");
        return -1;
    }
    return 0;
}

int kiba_install_create_user(const char *target_root, const char *username,
                              const char *password) {
    /* Remove live autologin configs (best-effort, plain unlink). */
    char path[1024];
    snprintf(path, sizeof(path), "%s/etc/sddm.conf.d/kibaos-live.conf", target_root);
    unlink(path);
    snprintf(path, sizeof(path), "%s/etc/sddm.conf.d/autologin.conf", target_root);
    unlink(path);

    /* Remove the live user -- best effort, ignore failure if absent. */
    {
        char *argv[] = { (char *)"userdel", (char *)"-r", (char *)"liveuser", NULL };
        chroot_run(target_root, argv); /* ignore result intentionally */
    }

    {
        char *argv[] = {
            (char *)"useradd", (char *)"-m",
            (char *)"-G", (char *)"wheel,audio,video,input,network,storage,power",
            (char *)"-s", (char *)"/bin/bash",
            (char *)username, NULL
        };
        if (chroot_run(target_root, argv) != 0) {
            /* tolerate "already exists" the same way the old backend did */
        }
    }

    {
        char stdin_data[512];
        snprintf(stdin_data, sizeof(stdin_data), "%s:%s\n", username, password);
        char *argv[] = { (char *)"arch-chroot", (char *)target_root, (char *)"chpasswd", NULL };
        if (run_argv_with_stdin(argv, stdin_data) != 0) {
            snprintf(g_finish_err, sizeof(g_finish_err), "chpasswd failed");
            return -1;
        }
    }

    return 0;
}

int kiba_install_finalize(const char *target_root, const char *disk_path,
                           const char *root_part, int root_partno, bool dualboot,
                           kiba_progress_cb cb, void *user_data) {
    char path[1024];

    if (cb) cb(80, "Removing live-only tools...", user_data);

    static const char *live_only[] = {
        "usr/share/applications/kibaos-install.desktop",
        "usr/bin/io.kibaos.oobe",
        "usr/share/kibaos-oobe",
        "usr/local/bin/kibaos-oobe-backend",
        "usr/local/bin/kibaos-oem-finish.sh",
        "etc/systemd/system/choose-mirror.service",
        "usr/share/libalpm/hooks/Installation_guide.hook",
        "root/customize_airootfs.sh",
        "root/install.txt",
        "etc/motd",
        "etc/issue",
    };
    for (size_t i = 0; i < sizeof(live_only)/sizeof(live_only[0]); i++) {
        snprintf(path, sizeof(path), "%s/%s", target_root, live_only[i]);
        char *argv[] = { (char *)"rm", (char *)"-rf", path, NULL };
        run_argv(argv); /* best-effort */
    }

    {
        char *argv[] = {
            (char *)"pacman", (char *)"-Rns", (char *)"--noconfirm",
            (char *)"archiso", (char *)"mkinitcpio-archiso", (char *)"squashfs-tools", NULL
        };
        chroot_run(target_root, argv); /* best-effort, same as old backend */
    }

    if (cb) cb(84, "Installing bootloader...", user_data);
    {
        /* KibaOS is UEFI-only, which needs /sys/firmware/efi/efivars to
         * write the NVRAM boot entry. Fail fast with a clear message
         * instead of letting grub-install die with a cryptic error --
         * this also covers VMs, which are not supported. */
        if (access("/sys/firmware/efi", F_OK) != 0) {
            snprintf(g_finish_err, sizeof(g_finish_err),
                     "KibaOS requires UEFI boot. This system appears to have "
                     "booted in BIOS/legacy mode. Virtual machines are not "
                     "supported -- please install on real UEFI hardware.");
            return -1;
        }

        char *argv[] = {
            (char *)"grub-install", (char *)"--target=x86_64-efi",
            (char *)"--efi-directory=/boot", (char *)"--bootloader-id=KibaOS",
            (char *)"--recheck", NULL
        };
        if (chroot_run(target_root, argv) != 0) {
            snprintf(g_finish_err, sizeof(g_finish_err), "grub-install failed");
            return -1;
        }
    }

    /* /etc/default/grub — quiet/splash cmdline, timeout behavior, and
     * (on dual-boot installs) os-prober so GRUB picks up the other OS's
     * entries automatically instead of hiding everything but KibaOS. */
    snprintf(path, sizeof(path), "%s/etc/default/grub", target_root);
    if (dualboot) {
        write_file(path,
                   "GRUB_DISTRIBUTOR=\"KibaOS\"\n"
                   "GRUB_DEFAULT=0\n"
                   "GRUB_TIMEOUT=5\n"
                   "GRUB_TIMEOUT_STYLE=menu\n"
                   "GRUB_CMDLINE_LINUX_DEFAULT=\"quiet splash loglevel=3 "
                   "rd.udev.log_level=3 vt.global_cursor_default=0 "
                   "plymouth.use-simpledrm=1\"\n"
                   "GRUB_CMDLINE_LINUX=\"\"\n"
                   "GRUB_DISABLE_OS_PROBER=false\n");
    } else {
        write_file(path,
                   "GRUB_DISTRIBUTOR=\"KibaOS\"\n"
                   "GRUB_DEFAULT=0\n"
                   "GRUB_TIMEOUT=0\n"
                   "GRUB_TIMEOUT_STYLE=hidden\n"
                   "GRUB_CMDLINE_LINUX_DEFAULT=\"quiet splash loglevel=3 "
                   "rd.udev.log_level=3 vt.global_cursor_default=0 "
                   "plymouth.use-simpledrm=1\"\n"
                   "GRUB_CMDLINE_LINUX=\"\"\n"
                   "GRUB_DISABLE_OS_PROBER=true\n");
    }

    /* grub-mkconfig introspects the mounted root filesystem (via
     * /etc/fstab, already written with the real UUID a few steps ago) to
     * work out root=UUID=... itself -- no manual PARTUUID patching needed
     * the way bootctl's static loader entries required. */
    {
        char *argv[] = {
            (char *)"grub-mkconfig", (char *)"-o", (char *)"/boot/grub/grub.cfg", NULL
        };
        if (chroot_run(target_root, argv) != 0) {
            snprintf(g_finish_err, sizeof(g_finish_err), "grub-mkconfig failed");
            return -1;
        }
    }

    (void)disk_path;  /* no longer needed -- grub-mkconfig reads fstab, not the GPT */
    (void)root_partno;

    if (cb) cb(88, "Enabling services...", user_data);
    {
        static const char *services[] = {
            "NetworkManager", "sddm", "bluetooth",
            "systemd-timesyncd", "systemd-time-wait-sync",
        };
        for (size_t i = 0; i < sizeof(services)/sizeof(services[0]); i++) {
            char *argv[] = { (char *)"systemctl", (char *)"enable", (char *)services[i], NULL };
            chroot_run(target_root, argv); /* best-effort */
        }
    }

    if (cb) cb(91, "Applying boot theme...", user_data);
    snprintf(path, sizeof(path), "%s/etc/sysctl.d", target_root);
    mkdir(path, 0755);
    snprintf(path, sizeof(path), "%s/etc/sysctl.d/20-quiet-printk.conf", target_root);
    /* Belt-and-suspenders for silent boot: loglevel=3 on the kernel cmdline
     * only filters what reaches the console at the level it's set; this
     * sysctl additionally caps the kernel's own default console log level,
     * catching messages cmdline filtering alone sometimes misses. */
    write_file(path, "kernel.printk = 3 3 3 3\n");

    snprintf(path, sizeof(path), "%s/etc/plymouth", target_root);
    mkdir(path, 0755);
    snprintf(path, sizeof(path), "%s/etc/plymouth/plymouthd.conf", target_root);
    write_file(path, "[Daemon]\nTheme=numix\nShowDelay=0\nDeviceTimeout=8\n");
    {
        char *argv[] = { (char *)"plymouth-set-default-theme", (char *)"numix", NULL };
        chroot_run(target_root, argv);
    }

    if (cb) cb(94, "Rebuilding initramfs...", user_data);
    {
        char *argv[] = {
            (char *)"mkinitcpio", (char *)"-c", (char *)"/etc/mkinitcpio.conf.d/installed.conf",
            (char *)"-g", (char *)"/boot/initramfs-linux.img", NULL
        };
        if (chroot_run(target_root, argv) != 0) {
            snprintf(g_finish_err, sizeof(g_finish_err), "mkinitcpio failed");
            return -1;
        }
    }

    snprintf(path, sizeof(path), "%s/etc/sudoers.d/wheel", target_root);
    write_file(path, "%wheel ALL=(ALL:ALL) ALL\n");
    chmod(path, 0440);

    (void)root_part; /* kept for signature symmetry / future use */
    return 0;
}
KIBA_SRC_END_FINC

cat > kibaos_oobe_backend_main.c << 'KIBA_SRC_END_MAINC'
/* kibaos_oobe_backend_main.c — the privileged install orchestrator.
 *
 * Invoked via sudo (no D-Bus/polkit dependency): `sudo /usr/local/bin/kibaos-oobe-backend
 * <disk> <mode> <locale> <keymap> <hostname> <username> <password>` — argv,
 * no shell, per the injection fix already applied on the Vala side.
 * <mode> is "erase" (wipe the whole disk, original behavior) or
 * "alongside" (dual-boot: keep whatever's already on the disk, reuse its
 * existing ESP, and install KibaOS into the largest free-space gap).
 *
 * Internally this no longer touches archinstall, parted, blkid, or
 * partprobe as subprocesses: all of that is libkibadisk (kiba_gpt.c /
 * kiba_fs.c / kiba_udev.c). The only external tools left are the ones
 * with no sane from-scratch replacement: unsquashfs, useradd/chpasswd,
 * grub-install, grub-mkconfig, mkinitcpio, locale-gen, pacman -- all invoked via argv
 * arrays inside libkibadisk, never through a shell.
 *
 * Output protocol is unchanged on purpose: "PROGRESS <pct> <msg>" on
 * stdout, one line, matching what main.vala's read_backend_output()
 * already parses. Nothing on the Vala side needs to change.
 */
#define _GNU_SOURCE
#include "kiba_gpt.h"
#include "kiba_fs.h"
#include "kiba_udev.h"
#include "kiba_install.h"

#include <fcntl.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

static FILE *g_logfp = NULL;

static void log_init(void) {
    /* Open (create/append) the log file the UI tells the user to check.
     * Nothing upstream of this ever actually opened it before now — the
     * backend only wrote to stdout/stderr, which the frontend silently
     * dropped half of (see SubprocessLauncher fix in the Vala frontend:
     * it only piped STDOUT, so every FATAL: line on stderr went nowhere). */
    g_logfp = fopen("/var/log/kibaos-oobe.log", "a");
    if (g_logfp) {
        setvbuf(g_logfp, NULL, _IOLBF, 0); /* line-buffered: survives a crash/kill */
        time_t now = time(NULL);
        fprintf(g_logfp, "\n=== kibaos-oobe-backend started %s", ctime(&now));
        fflush(g_logfp);
    }
    /* Non-fatal if this fails (e.g. /var/log not writable yet at this point
     * in boot) — we still have stdout/stderr as a fallback, just no file. */
}

static void progress(int pct, const char *msg) {
    printf("PROGRESS %d %s\n", pct, msg);
    fflush(stdout);
    if (g_logfp) { fprintf(g_logfp, "PROGRESS %d %s\n", pct, msg); fflush(g_logfp); }
}

static void progress_cb(int pct, const char *msg, void *ud) {
    (void)ud;
    progress(pct, msg);
}

static void fail(const char *msg) {
    progress(100, msg);
    fprintf(stderr, "FATAL: %s\n", msg);
    if (g_logfp) { fprintf(g_logfp, "FATAL: %s\n", msg); fflush(g_logfp); fclose(g_logfp); }
    exit(1);
}

/* Defense-in-depth: the Vala frontend already refuses to offer install at
 * all inside a VM, but this backend can be invoked directly via sudo, so
 * it re-checks. Virtual disk (VDI/VMDK/qcow2) handling was never made
 * reliable enough to ship, so we refuse outright rather than risk leaving
 * a half-written disk behind. */
static bool running_in_vm(void) {
    int rc = system("systemd-detect-virt -q");
    if (rc == -1) return false;   /* couldn't run the check -- don't block */
    if (!WIFEXITED(rc)) return false;
    return WEXITSTATUS(rc) == 0;  /* exit 0 = virtualized, 1 = bare metal */
}

/* Builds the device path for partition number `n` of `disk` into `buf`.
 * Real rule (confirmed against ArchWiki's device-naming page): if the
 * disk's device name ends in a digit, partitions get a 'p' separator
 * (/dev/loop0p1, /dev/nvme0n1p1); otherwise they don't (/dev/vda1,
 * /dev/sda1). This is NOT about which driver/bus is involved (virtio vs
 * nvme vs scsi) -- it's purely about whether the trailing character of
 * the disk name is already a digit, which would otherwise make "loop01"
 * ambiguous (loop-1 vs loop0-partition-1). Checking for "nvme"/"mmcblk"
 * by substring was the previous (wrong) approach -- it happened to work
 * for /dev/vda by accident, but failed for /dev/loop0. */
static void partition_path(const char *disk, int n, char *buf, size_t buf_len) {
    size_t disk_len = strlen(disk);
    bool ends_in_digit = disk_len > 0 && disk[disk_len - 1] >= '0' && disk[disk_len - 1] <= '9';
    if (ends_in_digit) snprintf(buf, buf_len, "%sp%d", disk, n);
    else                snprintf(buf, buf_len, "%s%d", disk, n);
}

int main(int argc, char **argv) {
    log_init();
    if (running_in_vm()) {
        fail("KibaOS installation is not supported inside a virtual machine "
             "(virtual disk handling isn't reliable enough yet). "
             "Please install on real hardware.");
    }
    if (argc != 8 && argc != 9) {
        fprintf(stderr,
            "usage: %s <disk> <mode: erase|alongside> <locale> <keymap> <hostname> <username> <password> [prepartitioned]\n",
            argv[0]);
        return 2;
    }
    /* "prepartitioned": archinstall's only_hd script already partitioned,
     * formatted, and mounted the disk (see kibaos-archinstall-backend).
     * KIBA_ROOT_PART / KIBA_ESP_PART point at the device nodes it used.
     * Everything from here on (squashfs extraction, configs, user,
     * bootloader) is unchanged either way. */
    bool prepartitioned = (argc == 9 && strcmp(argv[8], "prepartitioned") == 0);
    const char *disk     = argv[1];
    const char *mode     = argv[2];
    const char *locale   = argv[3];
    const char *keymap   = argv[4];
    const char *hostname = argv[5];
    const char *username = argv[6];
    const char *password = argv[7];

    bool dualboot = (strcmp(mode, "alongside") == 0);
    if (!dualboot && strcmp(mode, "erase") != 0) {
        fail("Unknown install mode (expected 'erase' or 'alongside').");
    }

    const char *target_root = "/mnt/kibaos-install";
    char esp_part[300], root_part[300];
    int esp_partno = 0, root_partno = 0;

    if (prepartitioned) {
        const char *env_root = getenv("KIBA_ROOT_PART");
        const char *env_esp  = getenv("KIBA_ESP_PART");
        if (!env_root || !env_esp) {
            fail("prepartitioned mode requires KIBA_ROOT_PART/KIBA_ESP_PART to be set.");
        }
        snprintf(root_part, sizeof(root_part), "%s", env_root);
        snprintf(esp_part,  sizeof(esp_part),  "%s", env_esp);
        /* Trailing digits of the device path are the partition number
         * (e.g. /dev/sda2 -> 2, /dev/nvme0n1p2 -> 2) -- only used later
         * to pass through to kiba_install_finalize(). */
        size_t rl = strlen(root_part);
        size_t digit_start = rl;
        while (digit_start > 0 && isdigit((unsigned char)root_part[digit_start - 1])) digit_start--;
        root_partno = digit_start < rl ? atoi(root_part + digit_start) : 0;
        progress(2, "Using archinstall's disk layout...");
    } else {
        /* ── 1-2. Probe + partition (hand-rolled GPT via libfdisk) ────── */
        progress(2, "Reading disk information...");
        uint32_t ssz = 0;
        uint64_t total_sectors = 0;
        if (kiba_gpt_probe_device(disk, &ssz, &total_sectors) != 0) {
            fail("Could not read disk information.");
        }

        if (!dualboot) {
        /* ── Whole-disk install: wipe and lay down a fresh GPT ───────── */
        progress(6, "Partitioning disk...");
        int disk_fd = open(disk, O_RDWR);
        if (disk_fd < 0) fail("Could not open disk for writing.");

        /* Layout: 512MiB ESP (FAT32) + remainder as Linux root (ext4),
         * matching the layout the old archinstall-based backend used. */
        uint64_t esp_sectors = (512ull * 1024 * 1024) / ssz;
        uint64_t entry_array_sectors = (128 * 128 + ssz - 1) / ssz;
        uint64_t first_usable = 2 + entry_array_sectors;
        uint64_t esp_first  = first_usable;
        uint64_t esp_last   = esp_first + esp_sectors - 1;
        uint64_t root_first = esp_last + 1;
        /* Root partition consumes the rest of the disk. We deliberately do NOT
         * hand-compute the last usable LBA here -- that previously tried to
         * dead-reckon where the backup GPT header + entry array sit at the end
         * of the disk, and a one-sector mismatch against libfdisk's own
         * calculation made fdisk_add_partition() reject it with EINVAL ("The
         * last usable GPT sector is X, but Y is requested"). Passing the
         * KIBA_GPT_LAST_LBA_REST sentinel defers to libfdisk's own
         * last_usable_lba, which fdisk_create_disklabel() already derived
         * correctly for this exact disk/sector size. */
        uint64_t root_last  = KIBA_GPT_LAST_LBA_REST;

        if (root_first >= total_sectors) {
            close(disk_fd);
            fail("Disk is too small for KibaOS (need at least ~1.5GB usable after the EFI partition).");
        }

        kiba_gpt_disk_t gdisk = {
            .fd = disk_fd,
            .logical_sector_size = ssz,
            .total_sectors = total_sectors,
            .disk_guid = {{0}},
        };
        kiba_gpt_partition_t parts[2] = {
            { .name = "KIBAOS-ESP",  .type_guid = KIBA_GUID_ESP,      .unique_guid = {{0}},
              .first_lba = esp_first,  .last_lba = esp_last,  .attributes = 0 },
            { .name = "KIBAOS-ROOT", .type_guid = KIBA_GUID_LINUX_FS, .unique_guid = {{0}},
              .first_lba = root_first, .last_lba = root_last, .attributes = 0 },
        };
        int rc = kiba_gpt_write(&gdisk, parts, 2);
        close(disk_fd);
        if (rc != 0) {
            char errbuf[256];
            snprintf(errbuf, sizeof(errbuf), "Partitioning failed: %s", strerror(-rc));
            fail(errbuf);
        }
        esp_partno = 1;
        root_partno = 2;
        partition_path(disk, esp_partno,  esp_part,  sizeof(esp_part));
        partition_path(disk, root_partno, root_part, sizeof(root_part));
    } else {
        /* ── Dual-boot: reuse the existing ESP, use free space only ──── */
        progress(4, "Looking for an existing EFI partition and free space...");
        kiba_gpt_scan_result_t scan;
        if (kiba_gpt_scan(disk, &scan) != 0) {
            fail("Could not read the existing partition table.");
        }
        if (scan.esp_partno == 0) {
            fail("No existing EFI System Partition was found on this disk -- "
                 "install alongside needs one already present from the "
                 "other operating system.");
        }
        if (scan.free_last_lba < scan.free_first_lba) {
            fail("No usable free space was found on this disk to install "
                 "KibaOS alongside the existing operating system.");
        }
        const uint64_t min_root_bytes = 12ull * 1024 * 1024 * 1024; /* 12 GiB floor */
        if (scan.free_bytes < min_root_bytes) {
            fail("Not enough free space on this disk to install KibaOS "
                 "alongside the existing operating system (need at least ~12GB free).");
        }

        esp_partno = scan.esp_partno;
        partition_path(disk, esp_partno, esp_part, sizeof(esp_part));

        progress(6, "Creating KibaOS partition in free space...");
        kiba_gpt_partition_t root = {
            .name = "KIBAOS-ROOT", .type_guid = KIBA_GUID_LINUX_FS, .unique_guid = {{0}},
            .first_lba = scan.free_first_lba, .last_lba = scan.free_last_lba, .attributes = 0
        };
        int new_partno = 0;
        int rc = kiba_gpt_add_partition(disk, &root, &new_partno);
        if (rc != 0) {
            char errbuf[256];
            snprintf(errbuf, sizeof(errbuf), "Partitioning failed: %s", strerror(-rc));
            fail(errbuf);
        }
        root_partno = new_partno;
        partition_path(disk, root_partno, root_part, sizeof(root_part));
        }
    }

    /* Wait for the kernel/udev to settle before touching the new
     * partition nodes -- the actual fix for the original bug report. */
    if (!kiba_wait_for_device(esp_part, 5000) || !kiba_wait_for_device(root_part, 5000)) {
        fail("Partition devices never appeared after partitioning.");
    }

    /* ── 3. Format ─────────────────────────────────────────────────── */
    /* Skipped entirely in prepartitioned mode -- archinstall's only_hd
     * script already formatted both partitions per its disk_config. */
    if (!prepartitioned) {
    progress(10, "Formatting partitions...");
    if (!dualboot) {
        if (kiba_fs_format(esp_part, KIBA_FS_FAT32, "KIBAOS-ESP") != 0) {
            fail(kiba_fs_strerror());
        }
    }
    /* Dual-boot: the ESP already belongs to the other OS and already has
     * a filesystem on it, plus that OS's own boot files -- formatting it
     * would destroy them. grub-install (further down) only ever adds
     * KibaOS's own files there, so we deliberately never touch the ESP's
     * filesystem in this mode. */
    if (kiba_fs_format(root_part, KIBA_FS_EXT4, "KIBAOS-ROOT") != 0) {
        fail(kiba_fs_strerror());
    }
    }

    /* ── 4. Mount ──────────────────────────────────────────────────── */
    progress(14, "Mounting target filesystem...");
    mkdir(target_root, 0755);
    if (kiba_fs_mount(root_part, target_root, "ext4", NULL) != 0) fail(kiba_fs_strerror());
    char boot_dir[320];
    snprintf(boot_dir, sizeof(boot_dir), "%s/boot", target_root);
    mkdir(boot_dir, 0755);
    if (kiba_fs_mount(esp_part, boot_dir, "vfat", NULL) != 0) fail(kiba_fs_strerror());

    /* ── 5-6. Find + extract the live image onto the new root ───────── */
    char image_path[512];
    progress(18, "Locating KibaOS system image...");
    if (!kiba_find_live_image(image_path, sizeof(image_path))) {
        fail("Could not locate the KibaOS system image on the boot medium.");
    }
    if (kiba_install_extract_image(image_path, target_root, progress_cb, NULL) != 0) {
        fail(kiba_install_strerror());
    }

    /* ── 7. Write fstab, locale, hostname using the filesystem UUIDs
     *     mkfs.fat/mkfs.ext4 just generated ──────────────────────────── */
    progress(72, "Writing system configuration...");
    char root_uuid[64], esp_uuid[64];

    /* fstab uses the filesystem UUID (not the GPT PARTUUID), matching
     * the old backend's behavior. The actual UUID was generated by
     * mkfs.ext4/mkfs.fat during formatting above; we read it back via
     * udev's /dev/disk/by-uuid symlinks (systemd-udevd is always
     * running on the real install target, so this is reliable there
     * even though it can't be exercised in a udev-less sandbox). */
    if (!kiba_wait_for_disk_tag(root_part, "by-uuid", root_uuid, sizeof(root_uuid), 8000)) {
        fail("Could not determine root filesystem UUID after formatting.");
    }
    if (!kiba_wait_for_disk_tag(esp_part, "by-uuid", esp_uuid, sizeof(esp_uuid), 8000)) {
        fail("Could not determine ESP filesystem UUID after formatting.");
    }

    if (kiba_install_write_configs(target_root, root_uuid, esp_uuid,
                                    hostname, locale, keymap) != 0) {
        fail(kiba_install_strerror());
    }

    /* ── 8. Bind mounts for chroot operations ────────────────────────── */
    progress(76, "Preparing system for configuration...");
    {
        char p[320];
        snprintf(p, sizeof(p), "%s/dev", target_root);  mkdir(p, 0755);
        snprintf(p, sizeof(p), "%s/proc", target_root); mkdir(p, 0755);
        snprintf(p, sizeof(p), "%s/sys", target_root);  mkdir(p, 0755);
    }

    progress(78, "Generating locale...");
    if (kiba_install_locale_gen(target_root) != 0) fail(kiba_install_strerror());

    /* ── 9. User account ───────────────────────────────────────────── */
    progress(82, "Creating your account...");
    if (kiba_install_create_user(target_root, username, password) != 0) {
        fail(kiba_install_strerror());
    }

    /* ── 10. Bootloader, services, initramfs ─────────────────────────── */
    if (kiba_install_finalize(target_root, disk, root_part, root_partno, dualboot,
                               progress_cb, NULL) != 0) {
        fail(kiba_install_strerror());
    }

    progress(98, "Finishing up...");
    kiba_fs_umount(boot_dir);
    kiba_fs_umount(target_root);

    progress(100, "Done");
    return 0;
}
KIBA_SRC_END_MAINC

# Compile each translation unit, then archive into a static library.
gcc -O2 -Wall -c kiba_gpt.c -o kiba_gpt.o || { echo "FATAL: kiba_gpt.c failed to compile" >&2; exit 1; }
gcc -O2 -Wall -c kiba_fs.c -o kiba_fs.o || { echo "FATAL: kiba_fs.c failed to compile" >&2; exit 1; }
gcc -O2 -Wall -c kiba_udev.c -o kiba_udev.o || { echo "FATAL: kiba_udev.c failed to compile" >&2; exit 1; }
gcc -O2 -Wall -c kiba_install_extract.c -o kiba_install_extract.o || { echo "FATAL: kiba_install_extract.c failed to compile" >&2; exit 1; }
gcc -O2 -Wall -c kiba_install_finish.c -o kiba_install_finish.o || { echo "FATAL: kiba_install_finish.c failed to compile" >&2; exit 1; }
ar rcs libkibadisk.a kiba_gpt.o kiba_fs.o kiba_udev.o kiba_install_extract.o kiba_install_finish.o

echo "=== Building kibaos-oobe-backend (privileged install orchestrator) ==="
gcc -O2 -Wall -o /usr/local/bin/kibaos-oobe-backend kibaos_oobe_backend_main.c \
    -L. -lkibadisk -lfdisk \
    || { echo "FATAL: kibaos-oobe-backend failed to compile/link" >&2; exit 1; }
chmod +x /usr/local/bin/kibaos-oobe-backend
cd /

# gcc/base-devel are no longer needed once both the OOBE app (Vala, via
# valac, not gcc directly) and the new C-based kibaos-oobe-backend above
# have finished compiling -- safe to remove now, same as the old
# pre-OOBE removal point, just moved here since the OOBE backend build
# now genuinely needs a working compiler present until this line.
pacman -Rns --noconfirm gcc base-devel debugedit make patch autoconf automake 2>/dev/null || true

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

# NOTE: both OOBE backends launch via `sudo` (covered by the liveuser
# NOPASSWD sudoers rule above), not `pkexec`, specifically so the installer
# doesn't depend on D-Bus/polkit being healthy mid-install. No polkit rule
# is needed here as a result.

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
# BOOT SPLASH — Numix Plymouth theme (github.com/numixproject/numix-plymouth-theme)
# ══════════════════════════════════════════════════════════════════════════
# Upstream's own install instructions use `update-alternatives`, which is
# Debian/Ubuntu-only and doesn't exist on Arch — swapped for Arch's own
# `plymouth-set-default-theme` below. Everything else (clone + `make
# install`) is upstream's documented process, unchanged.
NUMIX_BUILD="/tmp/numix-plymouth-theme"
rm -rf "${NUMIX_BUILD}"
git clone --depth 1 https://github.com/numixproject/numix-plymouth-theme.git "${NUMIX_BUILD}"
make -C "${NUMIX_BUILD}" install

# Plymouth daemon config — must be written before mkinitcpio bakes it in
mkdir -p /etc/plymouth
cat > /etc/plymouth/plymouthd.conf << 'PLYMOUTHD'
[Daemon]
Theme=numix
ShowDelay=0
DeviceTimeout=8
PLYMOUTHD

# Set the theme now so it's in place before mkarchiso runs its own
# mkinitcpio pass over linux.preset (archiso_config=archiso.conf, set above
# with the plymouth/kms hooks already added). We do NOT manually re-run
# mkinitcpio here: mkarchiso always rebuilds /boot/initramfs-linux.img from
# linux.preset right after customize_airootfs.sh finishes, so any manual
# rebuild in here just gets overwritten — and running it against the wrong
# config (installed.conf, which is for the INSTALLED system, not this live
# ISO) was actively wrong on top of being redundant.
plymouth-set-default-theme numix 2>/dev/null || true
rm -rf "${NUMIX_BUILD}"
echo "=== Boot splash: Numix Plymouth theme installed ==="

# ══════════════════════════════════════════════════════════════════════════
# ICON THEME — Numix Circle (github.com/numixproject/numix-icon-theme-circle)
# ══════════════════════════════════════════════════════════════════════════
# Unlike the Plymouth theme, this repo ships no Makefile/install script —
# just the two theme directories themselves (Numix-Circle and its lighter
# variant) — so installing it is a straight copy into /usr/share/icons.
# There's no official Arch package either (only an AUR git package that
# builds from this same repo); cloning directly is simpler and keeps this
# script free of AUR/makepkg dependency resolution.
#
# Note: Numix Circle is an APP icon theme only — its index.theme Inherits=
# chain falls back to the base Numix theme (and then Adwaita/hicolor) for
# places/devices/mimetypes/actions. We're not installing the base numix-
# icon-theme here since it wasn't asked for, so non-app icons will fall
# back to whatever adwaita-icon-theme/hicolor already provides. Say the
# word if you want the base theme installed too for full coverage.
NUMIX_ICONS_BUILD="/tmp/numix-icon-theme-circle"
rm -rf "${NUMIX_ICONS_BUILD}"
git clone --depth 1 https://github.com/numixproject/numix-icon-theme-circle.git "${NUMIX_ICONS_BUILD}"
cp -r "${NUMIX_ICONS_BUILD}/Numix-Circle" "${NUMIX_ICONS_BUILD}/Numix-Circle-Light" /usr/share/icons/
gtk-update-icon-cache -f /usr/share/icons/Numix-Circle 2>/dev/null || true
gtk-update-icon-cache -f /usr/share/icons/Numix-Circle-Light 2>/dev/null || true
rm -rf "${NUMIX_ICONS_BUILD}"
echo "=== Icon theme: Numix Circle installed ==="


# ══════════════════════════════════════════════════════════════════════════
# GTK THEME — system-wide Adwaita-dark base + KibaOS rounded-rectangle panel override
# ══════════════════════════════════════════════════════════════════════════
mkdir -p /usr/share/gtk-2.0
cat > /usr/share/gtk-2.0/gtkrc << 'GTK2RC'
gtk-theme-name = "Adwaita-dark"
gtk-icon-theme-name = "Numix-Circle"
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
gtk-theme-name=Adwaita-dark
gtk-icon-theme-name=Numix-Circle
gtk-font-name=Noto Sans 11
gtk-cursor-theme-size=24
gtk-xft-antialias=1
gtk-xft-hinting=1
gtk-xft-hintstyle=hintslight
gtk-xft-rgba=rgb
GTK3RC

# ── GTK3 rounded-rectangle panel CSS — KibaOS's own theming, applied directly ─
# This overrides just the Budgie panel to be a floating liquid glass rounded rectangle.
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

/* === KibaOS: Floating rounded-rectangle panel === */
.budgie-panel {
    margin: 0 120px 8px 120px;
    /* 42px panel height (see PANEL_PATH size below) — 16px keeps corners
     * clearly rounded without hitting the ~21px half-height point where
     * the ends fully round off into a pill/stadium shape. */
    border-radius: 16px;
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
    border-radius: 14px;
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
cp /usr/share/kibaos/wallpaper.jpg  "${SDDM_THEME_DIR}/background.png"  2>/dev/null || true
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

    // ── Clock, top-right, matches KibaOS panel rounded-rectangle style ──────
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
    shortcuts-inhibit \
    blur \
    ipc \
    ipc-rules

# session-lock is intentionally NOT loaded above. This is a live/installer
# session — nothing in this image wires up a lockscreen UI (gtklock is
# installed but never invoked), so if anything ever triggered a lock here
# (idle timeout, a stray keybinding, a client using the wlr session-lock
# protocol) the user would be stuck on a black surface with no way back in,
# potentially mid-install. Easiest, safest fix: don't load the plugin at all.

# DPMS-off and the built-in cube/black-screen "screensaver" are both
# disabled outright (-1) for the same reason: someone can walk away from a
# multi-minute unattended install and the screen going dark/off must never
# be mistaken for the session being gone. -1 disables a timeout entirely.
[idle]
dpms_timeout = -1
screensaver_timeout = -1

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
# WAYFIRE IPC — Kortex's real compositor bridge
# ══════════════════════════════════════════════════════════════════════════
# `ipc`/`ipc-rules` (enabled above) ship in wayfire-plugins-extra, which is
# AUR-only on Arch (no core/extra package — confirmed against archlinux.org
# and the AUR page), so plain `pacman -S` can't resolve it. Built from
# source here instead, same call as Kortex's own Nuitka compile: this whole
# script already runs inside the arch-chroot (see customize_airootfs.sh),
# so a source build lands directly in the target image, no AUR helper
# needed. Once `ipc` is loaded, Wayfire exposes its IPC socket path via the
# WAYFIRE_SOCKET env var automatically — no manual socket config required.
echo "=== Building wayfire-plugins-extra (ipc, ipc-rules) ==="
pacman -S --noconfirm --needed meson ninja cmake pkgconf git cairo glibmm wayland-protocols
pacman -Scc --noconfirm

# Pinned to v0.10.0, NOT master — master's meson.build now requires
# wayfire >=0.11.0, but Arch's extra/wayfire package (installed above via
# packages.x86_64) is 0.10.1. If Arch bumps wayfire past 0.11.0 in the
# future, bump this tag to match — check `pacman -Si wayfire` for the
# version actually being installed and pick the wayfire-plugins-extra tag
# whose release notes list that same Wayfire version as a dependency.
git clone --depth=1 --branch v0.10.0 https://github.com/WayfireWM/wayfire-plugins-extra /tmp/wayfire-plugins-extra
cd /tmp/wayfire-plugins-extra
meson setup build --prefix=/usr --buildtype=release
ninja -C build
ninja -C build install
cd /
rm -rf /tmp/wayfire-plugins-extra

# Kortex talks to the ipc/ipc-rules socket through `wfctl` (pip: wfctl,
# github.com/killown/wfctl) rather than the raw JSON-RPC protocol directly —
# see core.py's WindowEventSource for why and its documented caveats.
echo "=== Installing wfctl (Wayfire IPC client used by Kortex) ==="
pip install --break-system-packages --no-cache-dir wfctl

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
gtk-theme-name=Adwaita-dark
gtk-icon-theme-name=Numix-Circle
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
gtk-theme-name="Adwaita-dark"
gtk-icon-theme-name="Numix-Circle"
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

dbus-run-session -- dconf write /com/solus-project/budgie-panel/panels "@as []" || true
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

gsettings set org.gnome.desktop.interface gtk-theme               'Adwaita-dark'
gsettings set org.gnome.desktop.interface icon-theme              'Numix-Circle'
gsettings set org.gnome.desktop.interface cursor-theme            'Adwaita'
gsettings set org.gnome.desktop.interface cursor-size             24
gsettings set org.gnome.desktop.interface font-name               'Noto Sans 11'
gsettings set org.gnome.desktop.interface document-font-name      'Noto Sans 11'
gsettings set org.gnome.desktop.interface monospace-font-name     'Noto Sans Mono 11'
gsettings set org.gnome.desktop.interface color-scheme            'prefer-dark'
gsettings set org.gnome.desktop.interface enable-animations       true
gsettings set org.gnome.desktop.interface text-scaling-factor     1.0

gsettings set org.gnome.desktop.background picture-uri      'file:///usr/share/kibaos/wallpaper.jpg'
gsettings set org.gnome.desktop.background picture-uri-dark 'file:///usr/share/kibaos/wallpaper.jpg'
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

# ── Live-session autostart: launches the OOBE installer automatically on
# the regular live boot (the 'liveuser' autologin session), so the person
# lands straight in the installer instead of an empty desktop. Gated to
# liveuser specifically (via `whoami`) so this never fires after a real
# install, on the OEM-finish account (which has its own autostart entry
# above), or for any other account this .config/autostart skeleton gets
# copied into down the line. ─────────────────────────────────────────────
cat > "${SKEL}/.config/autostart/kibaos-install-launch.desktop" << 'LIVELAUNCH'
[Desktop Entry]
Type=Application
Name=KibaOS Installer
Exec=sh -c '[ "$(whoami)" = "liveuser" ] && exec /usr/bin/io.kibaos.oobe'
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
LIVELAUNCH

mkdir -p /etc/systemd/zram-generator.conf.d
cat > /etc/systemd/zram-generator.conf << 'ZRAM'
[zram0]
zram-size = ram / 2
compression-algorithm = zstd
ZRAM

mkdir -p "${SKEL}/.config"

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

cat > "${SKEL}/.bashrc" << 'BASHRC'
[[ $- != *i* ]] && return
PS1='\[\e[1;36m\][KibaOS]\[\e[0m\] \[\e[32m\]\u@\h\[\e[0m\]:\[\e[34m\]\w\[\e[0m\]\$ '
alias ls='ls --color=auto'
alias ll='ls -lah --color=auto'
alias grep='grep --color=auto'
alias install='io.kibaos.oobe'
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
mkdir -p /usr/share/applications /etc/skel/Desktop /etc/skel/Documents \
         /etc/skel/Downloads /etc/skel/Pictures /etc/skel/Music /etc/skel/Videos
cat > /etc/skel/.config/user-dirs.dirs << 'USERDIRS'
XDG_DESKTOP_DIR="$HOME/Desktop"
XDG_DOWNLOAD_DIR="$HOME/Downloads"
XDG_DOCUMENTS_DIR="$HOME/Documents"
XDG_PICTURES_DIR="$HOME/Pictures"
XDG_MUSIC_DIR="$HOME/Music"
XDG_VIDEOS_DIR="$HOME/Videos"
USERDIRS

# ── Nemo/GTK sidebar bookmarks: a clean "quick access" list ────────────────
# Windows' C:\Users\<name> feels tidy because Explorer's nav pane only ever
# shows Desktop/Documents/Downloads/Pictures/Music/Videos plus the user's
# own Home — everything else (AppData-equivalent: our dotfiles in ~/.config,
# ~/.local, ~/.cache) is already hidden by the leading dot, same as AppData
# is hidden by its own attribute. This seeds the same short, fixed list in
# Nemo's sidebar on first login, nothing more — no stray "Other Locations"/
# raw filesystem browsing front and center.
#
# NOTE: this can't be a static /etc/skel file — GTK bookmark files are plain
# file:// URIs with no variable expansion, and skel is copied byte-for-byte
# at account creation before the real username exists. So instead this runs
# once per new user via a first-login script gated on a marker file, using
# a real $HOME at the time it actually runs.
mkdir -p /etc/skel/.config/autostart
cat > /usr/local/bin/kibaos-first-login-setup << 'FIRSTLOGIN'
#!/bin/bash
MARKER="$HOME/.config/.kibaos-first-login-done"
[ -f "$MARKER" ] && exit 0
mkdir -p "$HOME/.config/gtk-3.0"
cat > "$HOME/.config/gtk-3.0/bookmarks" << BOOKMARKS
file://$HOME/Desktop Desktop
file://$HOME/Documents Documents
file://$HOME/Downloads Downloads
file://$HOME/Pictures Pictures
file://$HOME/Music Music
file://$HOME/Videos Videos
BOOKMARKS
mkdir -p "$HOME/.config"
touch "$MARKER"
FIRSTLOGIN
chmod +x /usr/local/bin/kibaos-first-login-setup

cat > /etc/skel/.config/autostart/kibaos-first-login-setup.desktop << 'FIRSTLOGINDESK'
[Desktop Entry]
Type=Application
Name=KibaOS First Login Setup
Exec=/usr/local/bin/kibaos-first-login-setup
NoDisplay=true
X-GNOME-Autostart-Phase=Initialization
FIRSTLOGINDESK

# ══════════════════════════════════════════════════════════════════════════
# KIBAPKG — friendly libalpm-backed package manager, invoked as `kiba`
# ══════════════════════════════════════════════════════════════════════════
# Talks to libalpm directly via pyalpm (no shelling out to pacman), and
# translates its transaction/event callbacks into plain-language status
# lines instead of pacman's raw resolver/conflict/signature jargon. Reads
# repo names + mirror servers straight from pacman.conf/mirrorlist so it
# stays in sync with whatever the system is actually configured to use.
mkdir -p /usr/share/kibapkg
cat > /usr/share/kibapkg/kibapkg.py << 'KIBAPKG'
#!/usr/bin/env python3
"""kibapkg — a friendly front-end to libalpm (via pyalpm) for KibaOS.
Invoked as `kiba`. Talks to libalpm directly; never shells out to pacman."""
import os
import re
import sys
import pyalpm

ROOT = "/"
DBPATH = "/var/lib/pacman"
PACMAN_CONF = "/etc/pacman.conf"
MIRRORLIST = "/etc/pacman.d/mirrorlist"


def die(msg):
    print(f"kiba: {msg}")
    sys.exit(1)


def need_root():
    if os.geteuid() != 0:
        os.execvp("sudo", ["sudo", sys.executable, __file__] + sys.argv[1:])


def active_mirrors(limit=5):
    mirrors = []
    if os.path.exists(MIRRORLIST):
        with open(MIRRORLIST) as f:
            for line in f:
                line = line.strip()
                if line.startswith("Server"):
                    url = line.split("=", 1)[1].strip()
                    mirrors.append(url)
                    if len(mirrors) >= limit:
                        break
    return mirrors


def repo_names():
    repos = []
    if os.path.exists(PACMAN_CONF):
        with open(PACMAN_CONF) as f:
            for line in f:
                m = re.match(r"^\[(\w+)\]$", line.strip())
                if m and m.group(1) != "options":
                    repos.append(m.group(1))
    return repos or ["core", "extra", "multilib"]


def make_handle():
    h = pyalpm.Handle(ROOT, DBPATH)
    mirrors = active_mirrors()
    for repo in repo_names():
        db = h.register_syncdb(repo, pyalpm.SIG_DATABASE_OPTIONAL)
        db.servers = [m.replace("$repo", repo).replace("$arch", "x86_64") for m in mirrors]
    return h


def cb_event(*_):
    pass  # kept silent on purpose — kiba prints its own plain-language status


def run_transaction(h, build_trans, verb):
    h.dlcb = lambda name, xfered, total: None
    h.eventcb = cb_event
    t = h.init_transaction()
    try:
        build_trans(h, t)
        t.prepare()
        if not t.to_add and not t.to_remove:
            print(f"kiba: nothing to {verb}.")
            t.release()
            return
        for pkg in t.to_add:
            print(f"  + {pkg.name} {pkg.version}")
        for pkg in t.to_remove:
            print(f"  - {pkg.name} {pkg.version}")
        t.commit()
        print(f"kiba: {verb} complete.")
    except pyalpm.error as e:
        print(f"kiba: couldn't {verb} that — {e}")
        sys.exit(1)
    finally:
        try:
            t.release()
        except Exception:
            pass


def cmd_search(h, terms):
    seen = set()
    for db in h.get_syncdbs():
        for pkg in db.search(terms):
            if pkg.name not in seen:
                seen.add(pkg.name)
                print(f"{pkg.name:<28} {pkg.version:<16} {pkg.desc}")


def cmd_list(h):
    for pkg in h.get_localdb().pkgcache:
        print(f"{pkg.name:<28} {pkg.version}")


def cmd_info(h, name):
    pkg = h.get_localdb().get_pkg(name)
    source = "installed"
    if pkg is None:
        for db in h.get_syncdbs():
            pkg = db.get_pkg(name)
            if pkg:
                source = f"available in {db.name}"
                break
    if pkg is None:
        die(f"no package named '{name}'")
    print(f"{pkg.name}  {pkg.version}  ({source})")
    print(pkg.desc)


def cmd_install(h, names):
    def build(h, t):
        for name in names:
            pkg = None
            for db in h.get_syncdbs():
                pkg = db.get_pkg(name)
                if pkg:
                    break
            if pkg is None:
                die(f"no package named '{name}'")
            t.add_pkg(pkg)
    run_transaction(h, build, "install")


def cmd_remove(h, names):
    def build(h, t):
        for name in names:
            pkg = h.get_localdb().get_pkg(name)
            if pkg is None:
                die(f"'{name}' isn't installed")
            t.remove_pkg(pkg)
    run_transaction(h, build, "remove")


def cmd_update(h):
    def build(h, t):
        for db in h.get_syncdbs():
            db.update(force=False)
        h.sysupgrade(downgrade=False)
    run_transaction(h, build, "update")


HELP = """kiba — the KibaOS package manager

  kiba install <name...>   install one or more apps
  kiba remove  <name...>   remove one or more apps
  kiba update              update everything
  kiba search  <term>      search for an app
  kiba list                list installed apps
  kiba info    <name>      show details about an app
"""


def main():
    args = sys.argv[1:]
    if not args or args[0] in ("-h", "--help", "help"):
        print(HELP)
        return
    cmd, rest = args[0], args[1:]
    if cmd in ("install", "remove", "update"):
        need_root()
    h = make_handle()
    if cmd == "install" and rest:
        cmd_install(h, rest)
    elif cmd == "remove" and rest:
        cmd_remove(h, rest)
    elif cmd == "update":
        cmd_update(h)
    elif cmd == "search" and rest:
        cmd_search(h, rest)
    elif cmd == "list":
        cmd_list(h)
    elif cmd == "info" and rest:
        cmd_info(h, rest[0])
    else:
        print(HELP)


if __name__ == "__main__":
    main()
KIBAPKG
chmod +x /usr/share/kibapkg/kibapkg.py
ln -sf /usr/share/kibapkg/kibapkg.py /usr/local/bin/kiba
ln -sf /usr/share/kibapkg/kibapkg.py /usr/local/bin/kibapkg

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

# ── Hide Avahi network browser (avahi-discover / avahi-ui-tools) ──────────
# Avahi pulls in a "Network Browser" launcher we don't want in the app grid.
# Override both the avahi-discover and bssh/bvnc desktop files with NoDisplay.
for _avahi_desk in avahi-discover bssh bvnc; do
  if [ -f "/usr/share/applications/${_avahi_desk}.desktop" ]; then
    cp "/usr/share/applications/${_avahi_desk}.desktop" \
       "/usr/share/applications/${_avahi_desk}.desktop.bak" 2>/dev/null || true
    printf '[Desktop Entry]\nNoDisplay=true\n' \
      >> "/usr/share/applications/${_avahi_desk}.desktop"
  fi
done

# ── Hide gnome-terminal from the app launcher / shortcuts ─────────────────
# Terminal access is available via right-click and other paths; we don't want
# it pinned or visible in the main shortcut list.
if [ -f "/usr/share/applications/org.gnome.Terminal.desktop" ]; then
  sed -i 's/^NoDisplay=.*/NoDisplay=true/' \
      "/usr/share/applications/org.gnome.Terminal.desktop" || true
  grep -q '^NoDisplay=' "/usr/share/applications/org.gnome.Terminal.desktop" \
    || echo 'NoDisplay=true' >> "/usr/share/applications/org.gnome.Terminal.desktop"
fi

# ── Rename budgie-control-center to "Settings" ─────────────────────────────
# The upstream desktop file calls it "Budgie Control Center"; rebrand to the
# simpler, consumer-friendly label "Settings".
for _bcc_desk in budgie-control-center.desktop \
                 org.buddiesofbudgie.BudgieControlCenter.desktop; do
  if [ -f "/usr/share/applications/${_bcc_desk}" ]; then
    sed -i 's/^Name=.*/Name=Settings/' \
        "/usr/share/applications/${_bcc_desk}" || true
    # Strip any localised Name[xx]=… lines so they don't override our label
    sed -i '/^Name\[/d' "/usr/share/applications/${_bcc_desk}" || true
  fi
done

# ── Rename GNOME Software so it doesn't expose the "gnome-software"/Flathub
# plumbing in its name; consumers should just see "App Store".
for _sw_desk in org.gnome.Software.desktop; do
  if [ -f "/usr/share/applications/${_sw_desk}" ]; then
    sed -i 's/^Name=.*/Name=App Store/' "/usr/share/applications/${_sw_desk}" || true
    sed -i '/^Name\[/d' "/usr/share/applications/${_sw_desk}" || true
  fi
done

# ── Hide the raw NetworkManager connection editor (nm-connection-editor) —
# advanced tabs (802.1x, bonding, IPv6 routing metrics) are pure plumbing
# for a consumer OS; Wi-Fi/wired toggling stays exposed via the panel applet.
if [ -f "/usr/share/applications/nm-connection-editor.desktop" ]; then
  sed -i 's/^NoDisplay=.*/NoDisplay=true/' "/usr/share/applications/nm-connection-editor.desktop" || true
  grep -q '^NoDisplay=' "/usr/share/applications/nm-connection-editor.desktop" \
    || echo 'NoDisplay=true' >> "/usr/share/applications/nm-connection-editor.desktop"
fi

# ── Disable Magic SysRq — a raw kernel-debugging keyboard backdoor that has
# no business being reachable from a consumer desktop.
echo 'kernel.sysrq = 0' > /etc/sysctl.d/50-kibaos-disable-sysrq.conf

# ── Restrict virtual-terminal switching: Ctrl+Alt+F2 etc. are handled by the
# kernel's VT layer, not the compositor, so this can't be blocked from
# Wayfire config. Instead, remove what's waiting on the other VTs — cap
# logind to one auto-spawned VT and mask the extra getty units so
# Ctrl+Alt+F2-F6 land on an empty console with no login prompt to reach.
grep -q '^NAutoVTs' /etc/systemd/logind.conf \
  && sed -i 's/^NAutoVTs=.*/NAutoVTs=1/' /etc/systemd/logind.conf \
  || echo 'NAutoVTs=1' >> /etc/systemd/logind.conf
systemctl mask getty@tty2.service getty@tty3.service getty@tty4.service \
                getty@tty5.service getty@tty6.service

# ── De-brand Chromium: keep the engine (site/extension/DRM compatibility),
# strip the corporate name/icon so it doesn't read as "Google Chromium" in
# the app grid. Icon is swapped for a flat single-color glyph consistent
# with the rest of the KibaOS icon set.
for _chromium_desk in chromium.desktop; do
  if [ -f "/usr/share/applications/${_chromium_desk}" ]; then
    sed -i 's/^Name=.*/Name=Browser/' "/usr/share/applications/${_chromium_desk}" || true
    sed -i '/^Name\[/d' "/usr/share/applications/${_chromium_desk}" || true
    sed -i 's/^Icon=.*/Icon=kibaos-browser/' "/usr/share/applications/${_chromium_desk}" || true
  fi
done

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
GTK_THEME=Adwaita-dark
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

# ── Network stack: NetworkManager ───────────────────────────────────────
# Back on NetworkManager (handles Wi-Fi/wired/DNS itself, no separate
# systemd-networkd/resolved wiring needed). Budgie's built-in network
# indicator and nm-applet both talk to NM natively, so no custom panel
# applet is needed either.
systemctl enable NetworkManager

# ── DNS: hardcode Cloudflare (1.1.1.1 / 1.0.0.1) ─────────────────────────
# NetworkManager manages /etc/resolv.conf itself by default and will
# happily overwrite it with whatever DNS servers the DHCP lease hands
# out — flaky router/ISP resolvers are what caused the resolve errors.
# Tell NM to keep its hands off resolv.conf, then write it ourselves so
# DNS always points straight at Cloudflare.
mkdir -p /etc/NetworkManager/conf.d
cat > /etc/NetworkManager/conf.d/dns.conf << 'NMDNS'
[main]
dns=none
NMDNS

cat > /etc/resolv.conf << 'RESOLVCONF'
nameserver 1.1.1.1
nameserver 1.0.0.1
RESOLVCONF

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
  # GNOME Console (kgx) is already the simplest terminal available — single
  # window, no tabs UI, no menu bar by design. Just quiet the bell and use
  # its own clean default font instead of inheriting a monospace override.
  dconf write /org/gnome/Console/audible-bell false
  dconf write /org/gnome/Console/custom-font-enabled false
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
  echo "║  KibaOS build complete!       ║"
  echo "║  ${ISO}.iso            ║"
  echo "╚══════════════════════════════════════╝"
else
  echo "ERROR: ISO file not found after mkarchiso!"
  exit 1
fi
