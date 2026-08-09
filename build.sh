#!/bin/bash
set -ex

# ── speed hack: crank up parallel downloads so pacman isn't crawling ───────
sed -i 's/^#ParallelDownloads = 5/ParallelDownloads = 10/' /etc/pacman.conf

# ── gotta pre-make the alpm user inside airootfs or pacman throws a fit
#    when it tries to run inside the chroot later ──────────────────────────
grep -q '^alpm:' "${AIROOTFS}/etc/passwd" 2>/dev/null || \
  echo 'alpm:x:951:951::/var/cache/pacman/pkg:/usr/bin/nologin' >> "${AIROOTFS}/etc/passwd"
grep -q '^alpm:' "${AIROOTFS}/etc/group" 2>/dev/null || \
  echo 'alpm:x:951:' >> "${AIROOTFS}/etc/group"
grep -q '^alpm:' "${AIROOTFS}/etc/shadow" 2>/dev/null || \
  echo 'alpm:!*:19000::::::' >> "${AIROOTFS}/etc/shadow"
mkdir -p "${AIROOTFS}/var/cache/pacman/pkg"
chmod 755 "${AIROOTFS}/var/cache/pacman" "${AIROOTFS}/var/cache/pacman/pkg"

# ── stuff the build container itself needs before we can do anything ──────
pacman-key --init
pacman-key --populate archlinux
pacman -Syy --noconfirm
pacman -Su  --noconfirm
pacman -S --noconfirm --needed \
  archiso base-devel git squashfs-tools libisoburn mtools dosfstools \
  cmake ninja meson \
  grub \
  openssl curl imagemagick jq

# ══════════════════════════════════════════════════════════════════════════
# LINUX-KIBA — custom-branded kernel, built from vanilla kernel.org, NOT
# from Arch's linux packaging
# ══════════════════════════════════════════════════════════════════════════
# Three build breaks in a row (prepare() shadowing, a working-directory
# assumption, then a fully relocated CONFIG_LOCALVERSION anchor) all
# traced back to Arch's own `linux` PKGBUILD restructuring itself between
# CI runs, not anything wrong on our end -- it's a live rolling-release
# packaging repo, so `git clone --depth 1` was tracking a moving target
# by design. Rather than keep chasing upstream's internal refactors, this
# writes a from-scratch PKGBUILD against a vanilla kernel.org tarball: no
# Arch patches, no Arch config, no Arch prepare()/build() structure to
# drift out from under us -- the only thing that can move now is the
# kernel source itself, which we pin explicitly below by resolving
# kernel.org's *current* "stable" release once and hashing exactly the
# tarball we downloaded.
#
# This is deliberately NOT a from-scratch config (that'd be closer to
# what Android calls a GKI -- deliberately minimal, missing most desktop
# hardware/filesystem support). `make defconfig` is the base, same as
# any generic/GKI-style build would start from, but layered with the
# filesystem, virtualization, and container primitives an actual desktop
# distro needs, so it's fully func -- ext4/btrfs/ntfs3, overlayfs (fuse
# for FUSE-based tools), KVM, cgroups/namespaces -- while never touching
# Arch's own config or patch set. Everything about how this REPORTS
# itself (pkgbase, install paths, CONFIG_LOCALVERSION) is KibaOS's own;
# everything about how the kernel actually BEHAVES (syscalls, drivers,
# ABI) is stock upstream Linux -- full compatibility, no translation
# layer, so no speed penalty either. kiba-identity's LD_PRELOAD uname
# shim (elsewhere in this file) still handles the userspace-visible
# rebrand on top of this.
echo "=== Resolving current kernel.org stable release ==="
KVER=$(curl -fsSL https://www.kernel.org/releases.json | jq -r '[.releases[] | select(.moniker=="stable")][0].version')
if [ -z "${KVER}" ] || [ "${KVER}" = "null" ]; then
  echo "ERROR: couldn't resolve a 'stable' release from kernel.org/releases.json" >&2
  exit 1
fi
KMAJOR="${KVER%%.*}"
echo "=== Building kiba-kernel against vanilla kernel.org ${KVER} ==="

KBUILD_DIR="/w/kiba-kernel-build"
KIBA_REPO_DIR="/w/kiba-repo/x86_64"
mkdir -p "${KBUILD_DIR}" "${KIBA_REPO_DIR}"

# Pre-download into $KBUILD_DIR itself (makepkg's default srcdest is the
# directory containing PKGBUILD) so makepkg finds it already cached and
# just verifies the checksum below instead of re-fetching.
KTARBALL="linux-${KVER}.tar.xz"
KURL="https://cdn.kernel.org/pub/linux/kernel/v${KMAJOR}.x/${KTARBALL}"
curl -fsSL "${KURL}" -o "${KBUILD_DIR}/${KTARBALL}"
KSHA256=$(sha256sum "${KBUILD_DIR}/${KTARBALL}" | awk '{print $1}')
echo "=== ${KTARBALL} sha256: ${KSHA256} ==="

cat > "${KBUILD_DIR}/PKGBUILD" << 'PKGBUILDEOF'
pkgbase=kiba-kernel
pkgname=(kiba-kernel kiba-kernel-headers)
pkgver=@@KVER@@
pkgrel=1
arch=(x86_64)
url="https://kernel.org/"
license=(GPL-2.0-only)
makedepends=(bc cpio gettext libelf pahole perl python tar xz kmod openssl)
options=(!strip !debug)
_srcname="linux-@@KVER@@"
source=("https://cdn.kernel.org/pub/linux/kernel/v@@KMAJOR@@.x/${_srcname}.tar.xz")
sha256sums=('@@KSHA256@@')

prepare() {
  cd "${_srcname}"

  # UTS_SYSNAME is the literal string the raw uname(2) syscall hands
  # back, straight from the kernel, before libc/kiba-identity's shim
  # ever gets a chance to run -- also what shows up in dmesg's boot
  # banner ("Linux version ...") and /proc/sys/kernel/ostype. Patching
  # it here means the rebrand holds even for statically-linked binaries
  # and anything making raw syscalls, no escape hatch, fully committed.
  sed -i 's/#define UTS_SYSNAME "Linux"/#define UTS_SYSNAME "KibaOS"/' include/linux/uts.h

  make defconfig

  # Rebrand the release string -- this is what makes `uname -r` read
  # "<ver>-kibaos" for real, not just a cosmetic string swap.
  scripts/config --set-str CONFIG_LOCALVERSION "-kibaos"
  # LOCALVERSION_AUTO would append a "-gxxxxxxxx" git-hash suffix if it
  # ever detects a git tree -- shouldn't trigger from a plain tarball,
  # but disabling it explicitly guarantees a clean, deterministic
  # "-kibaos" with no chance of stray noise appended.
  scripts/config --disable CONFIG_LOCALVERSION_AUTO
  # Hostname baked into the kernel itself, shown before userspace/DHCP
  # ever sets a real one -- otherwise defaults to the generic "(none)".
  scripts/config --set-str CONFIG_DEFAULT_HOSTNAME "kibaos"
  # Purely cosmetic, folds into the kernel's build-ID.
  scripts/config --set-str CONFIG_BUILD_SALT "kibaos"

  # Broad desktop-usable filesystem/virtualization support on top of
  # defconfig's deliberately minimal baseline.
  scripts/config --enable CONFIG_DEBUG_INFO_BTF
  scripts/config --enable CONFIG_MODULES
  scripts/config --enable CONFIG_BTRFS_FS
  scripts/config --enable CONFIG_NTFS3_FS
  scripts/config --enable CONFIG_NTFS3_LZX_XPRESS
  scripts/config --enable CONFIG_OVERLAY_FS
  # archiso's live boot loop-mounts airootfs.sfs/.erofs (see the
  # archiso mkinitcpio hook + /run/archiso/bootmnt paths elsewhere in
  # this script) -- without these, /dev/loop0 either doesn't exist or
  # has nothing that can actually read what's mounted on it. Arch's
  # stock kernel always had this built in by default, so it was never
  # something we had to think about until moving to our own config.
  scripts/config --enable CONFIG_BLK_DEV_LOOP
  scripts/config --enable CONFIG_SQUASHFS
  scripts/config --enable CONFIG_SQUASHFS_XZ
  scripts/config --enable CONFIG_SQUASHFS_ZSTD
  scripts/config --enable CONFIG_EROFS_FS
  scripts/config --enable CONFIG_EROFS_FS_ZIP
  # archiso's mkinitcpio hooks need these two beyond squashfs/loop:
  # 'memdisk' hook wants phram+mtdblock (MTD -- Memory Technology Device
  # -- support for the BIOS/SYSLINUX memdisk boot fallback path), and
  # 'archiso' hook wants dm_snapshot (device-mapper, for the live
  # session's cow/persistence overlay). Same story as squashfs/loop --
  # Arch's stock kernel always had these, defconfig doesn't.
  scripts/config --enable CONFIG_MTD
  scripts/config --enable CONFIG_MTD_PHRAM
  scripts/config --enable CONFIG_MTD_BLOCK
  scripts/config --enable CONFIG_BLK_DEV_DM
  scripts/config --enable CONFIG_DM_SNAPSHOT
  # zram-generator is configured (see zram-generator.conf later in this
  # script) to bring up /dev/zram0 for swap, but that's userspace config
  # for a kernel driver that was never actually enabled -- without it,
  # systemd-zram-setup@zram0.service waits out a full device timeout
  # before giving up, adding real boot delay for a feature that silently
  # never worked.
  scripts/config --enable CONFIG_ZRAM
  scripts/config --enable CONFIG_ZSMALLOC
  scripts/config --enable CONFIG_CRYPTO_LZO
  scripts/config --enable CONFIG_CRYPTO_ZSTD
  scripts/config --enable CONFIG_FUSE_FS
  scripts/config --enable CONFIG_USB_STORAGE
  scripts/config --enable CONFIG_VIRTIO
  scripts/config --enable CONFIG_VIRTIO_PCI
  scripts/config --enable CONFIG_VIRTIO_NET
  scripts/config --enable CONFIG_VIRTIO_BLK
  scripts/config --enable CONFIG_VIRTIO_CONSOLE
  scripts/config --enable CONFIG_KVM
  scripts/config --enable CONFIG_KVM_INTEL
  scripts/config --enable CONFIG_KVM_AMD
  scripts/config --enable CONFIG_CGROUPS
  scripts/config --enable CONFIG_NAMESPACES
  scripts/config --module CONFIG_NF_TABLES
  scripts/config --module CONFIG_WIREGUARD

  # Graphics/KMS -- without these, Plymouth (via mkinitcpio's kms hook)
  # has no framebuffer to draw to at all, which is exactly what produces
  # a black screen that hangs forever instead of erroring out: kms waits
  # for a DRM device to appear, and none ever does. defconfig alone
  # doesn't reliably include these.
  scripts/config --enable CONFIG_DRM
  scripts/config --enable CONFIG_DRM_KMS_HELPER
  scripts/config --enable CONFIG_DRM_FBDEV_EMULATION
  scripts/config --enable CONFIG_FB
  scripts/config --enable CONFIG_FRAMEBUFFER_CONSOLE
  scripts/config --enable CONFIG_SYSFB_SIMPLEFB
  scripts/config --enable CONFIG_DRM_SIMPLEDRM
  scripts/config --enable CONFIG_BACKLIGHT_CLASS_DEVICE
  scripts/config --module CONFIG_DRM_I915
  scripts/config --module CONFIG_DRM_AMDGPU
  scripts/config --enable CONFIG_DRM_AMD_DC
  scripts/config --module CONFIG_DRM_NOUVEAU
  scripts/config --module CONFIG_DRM_VIRTIO_GPU
  # mkinitcpio's COMPRESSION is now pinned to gzip (see mkinitcpio.conf.d
  # fragments) for GRUB compatibility on older boards -- make sure the
  # kernel's own initramfs decompressor actually matches, rather than
  # assuming defconfig's default covers it.
  scripts/config --enable CONFIG_RD_GZIP

  make olddefconfig

  # scripts/config --enable/--module only *requests* a symbol -- if its
  # `depends on` chain isn't already satisfied, olddefconfig silently
  # answers "disabled" instead of erroring, with nothing in the log to
  # show it happened. This has already bitten BTF, squashfs/loop, and
  # zram earlier in this project, all silently -- so verify the DRM
  # chain landed instead of assuming it did.
  for _drmopt in CONFIG_DRM CONFIG_DRM_KMS_HELPER CONFIG_DRM_SIMPLEDRM \
                 CONFIG_FRAMEBUFFER_CONSOLE CONFIG_DRM_I915 \
                 CONFIG_DRM_AMDGPU CONFIG_DRM_AMD_DC CONFIG_DRM_NOUVEAU \
                 CONFIG_DRM_VIRTIO_GPU CONFIG_DEBUG_INFO_BTF CONFIG_RD_GZIP \
                 CONFIG_MTD_PHRAM CONFIG_MTD_BLOCK CONFIG_DM_SNAPSHOT; do
    echo "=== ${_drmopt} resolved to: $(grep -E "^${_drmopt}=" .config || echo NOT-SET) ==="
  done

  echo "=== pahole: $(pahole --version 2>&1) ==="
}

build() {
  cd "${_srcname}"
  # Without these, /proc/version and `uname -v` bake in whoever actually
  # ran the compile -- on CI that's the runner's real username@hostname,
  # leaking straight into every install. Override explicitly.
  export KBUILD_BUILD_USER=kiba
  export KBUILD_BUILD_HOST=kibaos
  make -j"$(nproc)" all
}

package_kiba-kernel() {
  pkgdesc="The KibaOS kernel and modules (vanilla kernel.org @@KVER@@, kibaos-branded)"
  depends=(coreutils kmod)
  cd "${_srcname}"
  local kernver
  kernver=$(make -s kernelrelease)

  make -j"$(nproc)" INSTALL_MOD_PATH="${pkgdir}/usr" INSTALL_MOD_STRIP=1 modules_install

  install -Dm644 arch/x86/boot/bzImage "${pkgdir}/boot/vmlinuz-kiba-kernel"
  install -Dm644 System.map "${pkgdir}/usr/lib/modules/${kernver}/System.map"
  echo kiba-kernel | install -Dm644 /dev/stdin "${pkgdir}/usr/lib/modules/${kernver}/pkgbase"

  # modules_install drops build/source symlinks pointing at a kernel
  # tree that doesn't exist inside this package -- kiba-kernel-headers
  # provides the real target, so drop these here to avoid dangling
  # symlinks in the runtime package.
  rm -f "${pkgdir}/usr/lib/modules/${kernver}/build" \
        "${pkgdir}/usr/lib/modules/${kernver}/source"
}

package_kiba-kernel-headers() {
  pkgdesc="Headers and scripts for building modules against kiba-kernel"
  depends=(pahole)
  cd "${_srcname}"
  local kernver
  kernver=$(make -s kernelrelease)
  local hdrdir="${pkgdir}/usr/lib/modules/${kernver}/build"

  install -Dm644 Makefile "${hdrdir}/Makefile"
  install -Dm644 .config "${hdrdir}/.config"
  install -Dm644 Module.symvers "${hdrdir}/Module.symvers"
  install -Dm644 System.map "${hdrdir}/System.map"

  mkdir -p "${hdrdir}/kernel" "${hdrdir}/arch/x86"
  cp -a scripts "${hdrdir}/"
  cp -a include "${hdrdir}/"
  cp -a arch/x86/include "${hdrdir}/arch/x86/"
  cp -a arch/x86/Makefile* "${hdrdir}/arch/x86/" 2>/dev/null || true
  install -Dm644 kernel/Makefile "${hdrdir}/kernel/Makefile" 2>/dev/null || true
  install -Dm755 tools/objtool/objtool "${hdrdir}/tools/objtool/objtool" 2>/dev/null || true

  ln -sf "/usr/lib/modules/${kernver}/build" "${pkgdir}/usr/lib/modules/${kernver}/source"
}
PKGBUILDEOF

sed -i \
  -e "s/@@KVER@@/${KVER}/g" \
  -e "s/@@KMAJOR@@/${KMAJOR}/g" \
  -e "s/@@KSHA256@@/${KSHA256}/g" \
  "${KBUILD_DIR}/PKGBUILD"

# Install build deps as root first -- makepkg -s would try to do this
# itself via sudo once we drop to `nobody` below, but nobody has no tty
# and no passwordless sudo in CI, so that just fails with "a password is
# required". Preinstalling here and dropping -s sidesteps that entirely.
pacman -S --noconfirm --needed \
  base-devel bc cpio gettext libelf pahole perl python

chown -R nobody:nobody "${KBUILD_DIR}"   # makepkg refuses to run as root
runuser -u nobody -- bash -c 'cd '"${KBUILD_DIR}"' && makepkg --noconfirm --skippgpcheck'

cp "${KBUILD_DIR}"/*.pkg.tar.zst "${KIBA_REPO_DIR}/"
repo-add "${KIBA_REPO_DIR}/kiba-repo.db.tar.gz" "${KIBA_REPO_DIR}"/*.pkg.tar.zst
echo "=== kiba-kernel built: $(ls "${KIBA_REPO_DIR}") ==="
cd /

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

# kiba-repo: the throwaway local repo kiba-kernel was just built into,
# above. Name doesn't collide with anything on Arch's actual mirrors --
# kiba-kernel doesn't exist upstream -- so append-at-the-end is fine,
# no need to fight pacman.conf's include ordering for a priority that
# doesn't matter here. SigLevel Never because this is a same-build-run
# local repo, not something fetched over the network: there's nothing
# in it that wasn't just produced by this exact CI job.
cat >> "${PROFILE}/pacman.conf" << 'KIBAREPOCONF'

[kiba-repo]
SigLevel = Never
Server = file:///w/kiba-repo/x86_64
KIBAREPOCONF

# ══════════════════════════════════════════════════════════════════════════
# profiledef.sh
# ══════════════════════════════════════════════════════════════════════════
cat > "${PROFILE}/profiledef.sh" << 'PROFILEDEF'
#!/usr/bin/env bash
iso_name="kibaos"
iso_label="KIBAOS"
iso_publisher="WolfTech Innovations <https://github.com/WolfTech-Innovations>"
iso_application="KibaOS — A friendly general OS for all users"
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
PRETTY_NAME="KibaOS"
ID=kibaos
BUILD_ID=rolling
VENDOR_NAME="Kiba Labs"
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
kiba-kernel
kiba-kernel-headers
linux-firmware
mkinitcpio
mkinitcpio-archiso
earlyoom
fakeroot
efibootmgr
systemd-ukify
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
python
pyalpm
parted
gptfdisk
# memdiskfind (mkinitcpio's [memdisk] hook needs it at initramfs-build time,
# for RAM-loading the live ISO) ships in this package -- NOT pulled in for
# BIOS/isolinux boot itself, that's GRUB/UEFI-only and staying that way.
# Easy to conflate the two: ${PROFILE}/syslinux (the isolinux config dir,
# removed further down when BIOS boot got dropped) and this `syslinux`
# pacman package are different things, and only the config dir should
# have gone. Without this, mkinitcpio logs "ERROR: binary not found:
# 'memdiskfind'" and ships an incomplete initramfs.
syslinux
pv
lib32-mesa
lib32-vulkan-icd-loader
pkg-config
labwc
sddm
budgie
budgie-desktop-view
budgie-desktop-services
swaybg
grim
slurp
wl-clipboard
tesseract
tesseract-data-eng
libnotify
swayidle
gtklock
wlopm
wlr-randr
nemo
nemo-fileroller
gnome-console
gnome-disk-utility
gnome-backgrounds
gnome-keyring
gnome-settings-daemon
gnome-control-center
gvfs
gvfs-mtp
gvfs-smb
file-roller
gnome-text-editor
loupe
evince
papirus-icon-theme
adwaita-icon-theme
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
fuse3
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
totem
gstreamer
gst-plugins-base
gst-plugins-good
gst-plugins-bad
plymouth
squashfs-tools

# ── Windows app support (WinApps) ────────────────────────────────────────
# Runtime deps per https://github.com/winapps-org/winapps. curl, git,
# libnotify already pulled in above for other reasons. Arch's "freerdp"
# package is already v3+, unlike Debian which needs the freerdp3-x11 split.
# pciutils (lspci) is for kibaos-winapps-setup's automatic NVIDIA GPU
# passthrough detection -- not a WinApps dependency itself.
freerdp
docker
docker-compose
dialog
iproute2
openbsd-netcat
zenity
pciutils

# ── Security ────────────────────────────────────────────────────────────
sbctl
apparmor
firejail

# ── System tuning/maintenance ────────────────────────────────────────────
tuned
PACKAGES

# ══════════════════════════════════════════════════════════════════════════
# mkinitcpio
# ══════════════════════════════════════════════════════════════════════════
# archiso.conf is ONLY for the live environment (memdisk/archiso hooks).
# plymouth's in there so live boot can actually show our splash, and kms
# has to come before archiso so the framebuffer exists in time for
# plymouth to have something to draw on. gotta add both here since
# mkarchiso only bakes this file's hooks into the live ISO initramfs
# (see linux.preset's archiso_config= below) — installed.conf is a
# completely separate thing and mkarchiso never even looks at it.
mkdir -p "${AIROOTFS}/etc/mkinitcpio.conf.d"
cat > "${AIROOTFS}/etc/mkinitcpio.conf.d/archiso.conf" << 'INITRAMFS'
HOOKS=(base udev kms plymouth keyboard keymap modconf memdisk archiso block filesystems)
# mkinitcpio's default compression is zstd, which some older GRUB builds
# don't recognize -- known upstream as an "invalid magic number" error on
# newer image/decompressor formats that predates the GRUB patch adding
# support for them. Older UEFI boards are exactly where an older,
# unpatched GRUB is more likely to still be in the boot chain. gzip is
# the one format every GRUB version has always understood, at the cost
# of a slightly larger initramfs and marginally slower decompression --
# a fine trade for booting reliably on old hardware.
COMPRESSION="gzip"
INITRAMFS

# installed.conf is what the INSTALLED system uses once the OOBE installer
# runs initcpio. no memdisk/archiso hooks allowed here, those are live-only
cat > "${AIROOTFS}/etc/mkinitcpio.conf.d/installed.conf" << 'INSTALLED_HOOKS'
HOOKS=(base udev kms plymouth autodetect modconf block keyboard keymap filesystems fsck)
COMPRESSION="gzip"
INSTALLED_HOOKS

# Filename here has to stay "linux.preset" -- that's the specific path
# mkarchiso's own initramfs-build step looks for, regardless of what the
# actual kernel package is named. kiba-kernel's own pacman hook would
# normally auto-generate a kiba-kernel.preset of its own on a real install,
# but mkarchiso never touches that one; it only ever runs this hand-
# written file. Its CONTENTS do need to point at kiba-kernel's actual
# installed filenames though, since ALL_kver/archiso_image are real paths,
# not package-name-agnostic.
mkdir -p "${AIROOTFS}/etc/mkinitcpio.d"
cat > "${AIROOTFS}/etc/mkinitcpio.d/linux.preset" << 'PRESET'
PRESETS=('archiso')
ALL_kver='/boot/vmlinuz-kiba-kernel'
archiso_config='/etc/mkinitcpio.conf.d/archiso.conf'
archiso_image='/boot/initramfs-kiba-kernel.img'
PRESET

# ══════════════════════════════════════════════════════════════════════════
# Boot menu — GRUB, UEFI only
# ══════════════════════════════════════════════════════════════════════════
# releng ships both syslinux/ (BIOS) and efiboot/ (systemd-boot) by
# default, but neither one matters now that bootmodes up top is
# GRUB/UEFI-only, so out they go — no point leaving dead config sitting
# around in the profile.
rm -rf "${PROFILE}/syslinux" "${PROFILE}/efiboot"
mkdir -p "${PROFILE}/grub"

# grub.cfg is a template — mkarchiso fills in %ARCHISO_LABEL%,
# %INSTALL_DIR%, %ARCH%, %ARCHISO_SEARCH_FILENAME% for us at build time
# (see _build_grub_config in mkarchiso). GRUB just draws its splash right
# away no matter what the timeout is — unlike systemd-boot, which needs
# timeout>=1 to even show one — so timeout=0 here means we boot straight
# in without hitting that systemd-boot splash bug from before.
cat > "${PROFILE}/grub/grub.cfg" << 'GRUBCFG'
set default=0
set timeout=0
insmod all_video
insmod gfxterm
terminal_output gfxterm

search --no-floppy --set=root --label %ARCHISO_LABEL%

menuentry "KibaOS" --class kibaos {
    linux /%INSTALL_DIR%/boot/x86_64/vmlinuz-kiba-kernel archisobasedir=%INSTALL_DIR% archisolabel=%ARCHISO_LABEL% cow_spacesize=4G quiet splash loglevel=3 rd.udev.log_level=3 vt.global_cursor_default=0 plymouth.use-simpledrm=1
    initrd /%INSTALL_DIR%/boot/x86_64/initramfs-kiba-kernel.img
}

menuentry "KibaOS (safe mode)" --class kibaos {
    linux /%INSTALL_DIR%/boot/x86_64/vmlinuz-kiba-kernel archisobasedir=%INSTALL_DIR% archisolabel=%ARCHISO_LABEL% cow_spacesize=4G nomodeset systemd.unit=multi-user.target systemd.log_level=info
    initrd /%INSTALL_DIR%/boot/x86_64/initramfs-kiba-kernel.img
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

# ── spin up the sysusers.d users (polkitd etc) by hand ─────────────────────
# normally pacman fires this off as a post-install hook on a live system,
# but that hook just doesn't reliably trigger when packages get unpacked
# straight into an airootfs, so stuff like polkitd never gets a user and
# then polkitd faceplants on boot ("Could not activate remote peer
# 'org.freedesktop.PolicyKit1': startup job failed"). so just run it
# ourselves here instead of hoping pacman does it.
rm /usr/lib/sysusers.d/basic.conf
rm /usr/lib/sysusers.d/arch.conf
systemd-sysusers || true
systemd-tmpfiles --create 2>/dev/null || true

# ── polkitd fallback, just in case ──────────────────────────────────────────
# belt and suspenders: if systemd-sysusers above whiffed in this chroot for
# whatever reason, this makes sure the polkitd user exists anyway so
# polkitd can actually start (same failure mode as above otherwise)
id polkitd &>/dev/null || useradd -r -U -M -d /run/polkit -s /usr/bin/nologin polkitd

# ── alpm user ──────────────────────────────────────────────────────────────
useradd -r -s /usr/bin/nologin -U alpm 2>/dev/null || true
mkdir -p /var/cache/pacman/pkg
chmod 755 /var/cache/pacman /var/cache/pacman/pkg
chown -R alpm:alpm /var/cache/pacman
sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' /etc/pacman.conf

# CheckSpace already got disabled for the airootfs pacstrap up in
# kibaos.sh's PROFILE/pacman.conf, but that edit isn't guaranteed to have
# carried over into THIS chroot's own live /etc/pacman.conf, so — belt and
# suspenders again — do it here too. CheckSpace is notorious for false-
# positiving on overlay filesystems (its statvfs() call just lies about
# free space on overlay2, which is what basically every Docker CI runner
# uses), and worse, its "not enough free disk space... Proceed? [Y/n]"
# prompt doesn't respect --noconfirm like the normal prompts do. in a
# non-interactive CI shell with no stdin that's the actual thing hanging
# the build, not a real space problem.
sed -i 's/^CheckSpace/#CheckSpace/' /etc/pacman.conf

# ── nuke and rebuild the pacman keyring inside THIS chroot ─────────────────
# "keyring is not writable" / "required key missing from keyring" shows up
# whenever /etc/pacman.d/gnupg's ownership/perms don't line up with
# whatever UID is actually running pacman in here — happens a lot in CI
# where the outer Docker layer and this arch-chroot session don't quite
# match, even though mkarchiso already set up a keyring earlier. GnuPG's
# picky about homedir perms (has to be 0700, owned by whoever's calling
# it), so instead of chasing down which UID owns what, just blow it away
# and rebuild clean under whatever's actually running this script.
rm -rf /etc/pacman.d/gnupg
pacman-key --init
pacman-key --populate archlinux
pacman -Syy --noconfirm

# ── clear out disk before we install anything else ──────────────────────────
# by now mkarchiso's already pacstrapped the whole ~195-package
# packages.x86_64 list (chromium, mesa, all of it) into this
# airootfs, and every single .pkg.tar.zst is still sitting in the cache —
# nothing cleared it until the very end of the script before. everything
# coming up next (Kortex's own installs, the Nuitka onefile compile,
# building whatever compositor plugins from source) needs real scratch
# disk on top of that, and THAT'S what was actually running the image out
# of space, not any one install being huge. -Scc (double-c) nukes cached
# packages of every version, not just the outdated ones.
pacman -Scc --noconfirm

# earlyoom (just polls free mem/swap thresholds) and systemd-oomd
# (cgroup-aware, uses PSI) both do the same job of OOM-killing stuff, so
# running both at once just means they can race and kill different
# processes for the same pressure event. systemd-oomd already ships
# inside systemd itself (no extra package) and is the more modern,
# desktop-integrated pick since it already understands user.slice/session
# cgroups, so that's the one that's actually enabled. earlyoom stays
# installed but off, just sitting there as a fallback if oomd ever gets
# ripped out.
systemctl disable earlyoom 2>/dev/null || true
mkdir -p /etc/systemd/oomd.conf.d
cat > /etc/systemd/oomd.conf.d/kibaos.conf << 'OOMDCONF'
[OOM]
SwapUsedLimit=90%
DefaultMemoryPressureDurationSec=20s
OOMDCONF
systemctl enable systemd-oomd

cat > /etc/sysctl.d/99-kibaos.conf << 'SYSCTL'
vm.swappiness=10
vm.vfs_cache_pressure=50
vm.dirty_ratio=10
vm.dirty_background_ratio=5
fs.inotify.max_user_watches=524288
net.core.netdev_max_backlog=16384
SYSCTL

# NOTE: there used to be a binfmt_misc registration here
# (/etc/binfmt.d/wine.conf, matching on the MZ header) that routed .exe
# execution straight through Wine at the kernel level. That's gone now
# along with Wine itself. Windows programs aren't launched by double-
# clicking an .exe anymore either -- see the WinApps section below, which
# now opens the whole Windows environment as one fullscreen workspace
# instead of routing individual files through a mimeapps default.

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
# pywayland: real client bindings for the labwc bridge (WindowEventSource
# below talks to zwlr_foreign_toplevel_manager_v1 directly instead of
# shelling out — labwc's own wlrctl build has no watch/event-stream mode
# and no move/resize actions, so a CLI wrapper isn't an option here, see
# kortexd/labwc_bridge.py for the full rationale). Same story as nuitka
# above: python-pywayland is AUR-only, pip sidesteps that. Its cffi
# extension builds against libwayland-client, whose headers already come
# from the "wayland" package pulled in earlier for the compositor itself.
pip install --break-system-packages --no-cache-dir pywayland cffi

# ---- generate the wlr-foreign-toplevel-management-v1 protocol module ----
# pywayland only ships bindings for core wayland.xml out of the box; wlr
# protocol extensions (this one lives in the wlr-protocols repo, not
# wayland-protocols) have to be scanned separately.
#
# NOTE: an earlier revision of this step called
# Protocol.output(out_dir, {}) — the two-line form shown in pywayland's own
# docs. That only actually works for XML with zero cross-interface
# references. method.imports() looks up module_imports[interface] using
# the CURRENT interface's own name (not just the interfaces it references)
# to decide same-module vs. cross-module imports, so an empty dict
# KeyErrors the moment ANY interface in the file — including one defined
# in the file itself, e.g. zwlr_foreign_toplevel_manager_v1's own
# self/new_id references — isn't a registered key. This protocol also
# references wl_output/wl_seat from core wayland.xml, which need the same
# treatment. So module_imports has to be built for real: core wayland.xml
# interfaces mapped to pywayland's own module, plus every interface
# defined in THIS protocol self-mapped to its own output module — which is
# what pywayland-scanner's actual CLI does internally, just done by hand
# here since we're invoking the scanner API directly instead of shelling
# out to pywayland-scanner with flags that aren't documented anywhere.
WLR_FOREIGN_TOPLEVEL_XML="/tmp/wlr-foreign-toplevel-management-unstable-v1.xml"
curl -fL --retry 5 --retry-delay 3 -o "${WLR_FOREIGN_TOPLEVEL_XML}" \
  "https://raw.githubusercontent.com/swaywm/wlr-protocols/master/unstable/wlr-foreign-toplevel-management-unstable-v1.xml"

# Core wayland.xml ships with the "wayland" package (already pulled into
# packages.x86_64 for the compositor itself), so it's on disk in the
# build chroot at this standard location.
WAYLAND_CORE_XML="/usr/share/wayland/wayland.xml"

mkdir -p /usr/lib/kortex/kortexd/_protocols
# Use pywayland's own CLI scanner instead of hand-driving its internal
# scanner API — it builds the interface->module import map itself (across
# every XML file passed to -i), so there's no manually-maintained
# module_imports dict here for someone to get wrong. It regenerates
# core wl_output/wl_seat/wl_surface bindings locally alongside the wlr
# protocol (relative-imported as ..wayland) rather than reusing
# pywayland's own built-in pywayland.protocol.wayland module, which
# keeps this self-contained and not dependent on pywayland's internal
# package layout.
pywayland-scanner -i "${WAYLAND_CORE_XML}" "${WLR_FOREIGN_TOPLEVEL_XML}" \
  -o /usr/lib/kortex/kortexd/_protocols
touch /usr/lib/kortex/kortexd/_protocols/__init__.py
rm -f "${WLR_FOREIGN_TOPLEVEL_XML}"

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

    def get_last_placement_monitor(self, app):
        """Most-recently-updated monitor with a learned placement for this
        app, or None. Used as a fallback when the window-event backend
        can't report which monitor a launch happened on — the labwc
        bridge, notably, since zwlr_foreign_toplevel_manager_v1 has no
        output info available at launch time (see WindowEventSource /
        labwc_bridge.py docstrings).
        """
        with self.cursor() as c:
            c.execute(
                "SELECT monitor FROM placement WHERE app=? ORDER BY updated DESC LIMIT 1",
                (app,),
            )
            row = c.fetchone()
            return row["monitor"] if row else None

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
# writes). Rather than granting kortexd itself any privilege, it
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
    # Calls into kibaos-ota's file-level rollback (see rollback_config in
    # kortex-helper) -- restores whatever the most recent OTA patch
    # overwrote, from the backup kibaos-ota kept at patch time. This is
    # NOT the old A/B root-swap design (that's gone for good, see the
    # installer's single-root layout); it only undoes the last live
    # patch, so it's a no-op if no OTA patch has ever landed yet.
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
# runs modprobe/systemctl/udevadm/sysfs-writes itself — it asks
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
# that exec.path annotation is the whole trick — it's what lets
# `pkexec /usr/lib/kortex/kortex-helper` resolve to THIS specific action id
# instead of falling back to the generic org.freedesktop.policykit.exec
# action, which asks for the admin password every single time. that's a
# dealbreaker for silent background repair.
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

# ── Polkit rule: no password prompt, but only for the active local session ─
# heads up — this is a deliberate tradeoff, not something to ship blind:
# <defaults> up above says auth_admin_keep (password once, then cached).
# this rule straight up overrides that to YES with zero password for the
# active local user, because a "repair" popup that then makes you type a
# sudo password kind of defeats the whole point of automatic repair on a
# consumer OS. the blast radius is capped by kortex-helper's own fixed
# whitelist + re-validation above, but yeah — it does mean any process
# running locally as the active user can fire these six specific root
# actions with no prompt at all. if that doesn't sit right with you, just
# delete this .rules file and keep the auth_admin_keep default — Kortex
# will fall back to asking for a password on the first repair each
# session instead of doing it silently.
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

# ══════════════════════════════════════════════════════════════════════════
# KORTEX LABWC BRIDGE — replaces the old Wayfire/wfctl WindowEventSource
# backend with a real one for labwc.
#
# What labwc actually exposes, and what that does and doesn't buy us:
#
#   - zwlr_foreign_toplevel_manager_v1 (labwc >=2.1.0) gives us, per
#     toplevel: app_id, title, output_enter/leave, and a `state` event
#     whose bitset includes "activated" — i.e. focus tracking and launch
#     detection are both real and event-driven, no polling. This is the
#     part Kortex's usage model (Beta posteriors, KDE density, break
#     pressure) actually depends on, and it fully works.
#
#   - That protocol has NO geometry/rectangle event on the toplevel
#     handle — title/app_id/state/output/done/closed, nothing else. So
#     there is no way to observe where the user drags or resizes a
#     window under labwc, at all, with anything currently implemented.
#     Wayfire's IPC (the old backend) did expose this; labwc doesn't.
#     on_window_moved() — the *learning* half of placement — has no data
#     source here and stays a documented no-op, same as the whole class
#     used to be pre-bridge. If labwc's foreign-toplevel implementation
#     ever grows a geometry event, or ext-foreign-toplevel-list gains
#     one, this is the only place that needs to change.
#
#   - There is also no live move/resize request anywhere in the
#     protocol, and wlrctl (which only wraps this same protocol) doesn't
#     have one either — see wlrctl(1): minimize/maximize/fullscreen/
#     focus/find/wait/waitfor, that's the complete list, no move/resize.
#     In Wayland generally, compositors don't take positioning requests
#     from arbitrary external clients over IPC; the one place labwc
#     *does* accept a position is a windowRule's <action name="MoveTo">/
#     <action name="ResizeTo">, applied by labwc itself as a window
#     maps, and reloadable at runtime via SIGHUP.
#
#     So the *application* half of placement (move_window, below) works,
#     but the mechanism is different in kind from the old wfctl one: it
#     doesn't reach in and shove a live window to a new spot, it writes
#     a rule that labwc applies the next time that app_id maps. Since
#     KortexDaemon.on_window_launch already only ever calls move_window
#     right as a launch is detected — never on an already-settled window
#     — the practical behavior converges anyway, with one caveat: the
#     rule has to exist *before* that particular instance maps to catch
#     it. A launch is detected via toplevel_created, which only fires
#     after mapping, so the instance that triggered the rule write is
#     itself too late — it'll be positioned by whatever labwc/the app
#     picked by default. The next launch of that app_id (including the
#     very common case of quit/relaunch) picks the rule up correctly.
#     This is a one-launch lag, not a missing feature, and it's called
#     out again at the LabwcPlacementRules docstring.
# ══════════════════════════════════════════════════════════════════════════
echo "=== Installing kortexd labwc bridge ==="
cat > /usr/lib/kortex/kortexd/labwc_bridge.py << 'KORTEX_LABWC_BRIDGE_PY'
"""
kortexd.labwc_bridge
---------------------
Real WindowEventSource backend for labwc. See the build script's banner
comment above this file's install step for the full rationale; short
version: focus/launch tracking is real and event-driven (foreign-toplevel
protocol), placement learning (on_window_moved) has no protocol source and
is a documented no-op, and placement application (move_window) works by
writing a labwc windowRule + SIGHUP reload rather than a live move, which
takes effect on that app_id's *next* launch rather than the one that
triggered it.

Capability is detected by trying to bind the protocol global itself,
rather than checking the compositor name — if some other compositor ever
implements zwlr_foreign_toplevel_manager_v1, this backend works there too
with zero changes, and if labwc ever stops advertising it for any reason,
this degrades the same way the old wfctl path did: log once, no-op.
"""

import logging
import os
import shutil
import subprocess
import threading
import time

log = logging.getLogger("kortexd.labwc_bridge")

try:
    from pywayland.client import Display
    from .._protocols.wlr_foreign_toplevel_management_unstable_v1 import (
        ZwlrForeignToplevelManagerV1,
    )
    _HAVE_PYWAYLAND = True
except Exception as e:  # pywayland missing, protocol module missing, etc.
    _HAVE_PYWAYLAND = False
    _IMPORT_ERROR = e


# Bit values from the protocol's zwlr_foreign_toplevel_handle_v1.state
# enum. Kept as a local constant rather than pulled from the generated
# module since only "activated" is actually used here.
_STATE_ACTIVATED = 2


class LabwcToplevelWatcher:
    """Binds zwlr_foreign_toplevel_manager_v1 and turns its events into the
    same on_focus/on_launch/on_close callback shape WindowEventSource
    already expects from the old wfctl backend, so core.py's KortexDaemon
    doesn't need to know which backend is live underneath it.

    Runs its own Wayland connection on a dedicated thread — kortexd
    already owns the GTK main loop for the notifier (see core.py's
    docstring on thread ownership), so this can't share a loop with
    that; a second, separate wl_display connection is the simplest way
    to keep the two totally independent.
    """

    def __init__(self, on_focus, on_launch, on_close):
        self.on_focus = on_focus
        self.on_launch = on_launch
        self.on_close = on_close
        self._display = None
        self._manager = None
        self._known = {}   # handle -> {"app_id": str, "activated": bool}
        self._thread = None
        self._stop = threading.Event()

    @staticmethod
    def available():
        """Cheap pre-check before spinning up a thread: pywayland has to
        have imported cleanly, and a compositor socket has to exist to
        even try connecting to. Doesn't guarantee the global is
        advertised — that's only knowable after actually binding the
        registry, which start() does.
        """
        if not _HAVE_PYWAYLAND:
            log.info(
                f"LabwcToplevelWatcher unavailable: pywayland/protocol "
                f"module didn't import ({_IMPORT_ERROR}). Window-event "
                f"tracking is disabled; everything else in Kortex is "
                f"unaffected."
            )
            return False
        if not (os.environ.get("WAYLAND_DISPLAY") or os.environ.get("XDG_RUNTIME_DIR")):
            log.info("LabwcToplevelWatcher unavailable: no Wayland session in env")
            return False
        return True

    def start(self):
        if not self.available():
            return False
        try:
            self._display = Display()
            self._display.connect()
        except Exception as e:
            log.info(f"LabwcToplevelWatcher: couldn't connect to compositor: {e}")
            return False

        registry = self._display.get_registry()
        found = {"manager": None}

        def _global_handler(reg, name, interface, version):
            if interface == "zwlr_foreign_toplevel_manager_v1":
                found["manager"] = reg.bind(name, ZwlrForeignToplevelManagerV1, version)

        registry.dispatcher["global"] = _global_handler
        self._display.dispatch(block=True)
        self._display.roundtrip()

        if found["manager"] is None:
            log.info(
                "LabwcToplevelWatcher: compositor doesn't advertise "
                "zwlr_foreign_toplevel_manager_v1 (expected pre-2.1.0 "
                "labwc, or a compositor without this protocol at all). "
                "Window-event tracking is disabled; everything else in "
                "Kortex is unaffected."
            )
            self._display.disconnect()
            return False

        self._manager = found["manager"]
        self._manager.dispatcher["toplevel"] = self._on_toplevel_created
        self._thread = threading.Thread(target=self._run_loop, daemon=True)
        self._thread.start()
        log.info("LabwcToplevelWatcher started (zwlr_foreign_toplevel_manager_v1)")
        return True

    def stop(self):
        self._stop.set()

    def _run_loop(self):
        while not self._stop.is_set():
            try:
                self._display.dispatch(block=True)
            except Exception as e:
                log.warning(f"labwc bridge dispatch loop crashed, restarting in 5s: {e}")
                time.sleep(5)
                try:
                    self._display.connect()
                except Exception:
                    pass

    def _on_toplevel_created(self, manager, handle):
        state = {"app_id": None, "title": None, "activated": False, "seen": False}
        self._known[handle] = state

        def _on_app_id(h, app_id):
            state["app_id"] = app_id

        def _on_title(h, title):
            state["title"] = title

        def _on_state(h, states_bytes):
            # states_bytes is a packed array of uint32 state enum values
            was_active = state["activated"]
            state["activated"] = _STATE_ACTIVATED in _unpack_states(states_bytes)
            if state["activated"] and not was_active and state["app_id"]:
                self.on_focus(state["app_id"])

        def _on_done(h):
            if not state["seen"] and state["app_id"]:
                state["seen"] = True
                self.on_launch(state["app_id"])

        def _on_closed(h):
            app_id = state.get("app_id")
            self._known.pop(handle, None)
            if app_id:
                self.on_close(app_id)

        handle.dispatcher["app_id"] = _on_app_id
        handle.dispatcher["title"] = _on_title
        handle.dispatcher["state"] = _on_state
        handle.dispatcher["done"] = _on_done
        handle.dispatcher["closed"] = _on_closed


def _unpack_states(raw) -> set:
    """The state event's argument is a wl_array of uint32 — pywayland
    hands it back as raw bytes rather than pre-decoded ints.
    """
    import struct
    n = len(raw) // 4
    return set(struct.unpack(f"{n}I", raw[: n * 4]))


class LabwcPlacementRules:
    """Applies learned placements the only way labwc actually allows:
    a windowRule with MoveTo/ResizeTo, written into a clearly-delimited
    managed block inside rc.xml, reloaded live via SIGHUP.

    IMPORTANT — this is NOT a live move. It takes effect the next time
    the given app_id's window maps, not the instance that was open when
    move_window() was called (see the build script banner comment above
    this file's install step for why: there's no protocol request to
    reposition an already-mapped window under labwc). For an app that
    gets relaunched routinely — which is the normal case Kortex's
    placement-confidence threshold is built around, since it only fires
    after repeated consistent launches of the *same* app — this reaches
    the same end state as a live move within one more launch of it.

    The managed block is delimited with comments so this can coexist
    with whatever windowRules Chris already has by hand in rc.xml
    elsewhere in the file; only the content between the markers is ever
    rewritten.
    """

    BEGIN_MARKER = "<!-- KORTEX:BEGIN managed placement rules, do not hand-edit -->"
    END_MARKER = "<!-- KORTEX:END -->"

    def __init__(self, rc_xml_path=None):
        self.rc_xml_path = rc_xml_path or os.path.expanduser("~/.config/labwc/rc.xml")
        self._rules = {}   # app_id -> (x, y, w, h)
        self._lock = threading.Lock()

    def set_rule(self, app_id: str, x: int, y: int, w: int, h: int):
        with self._lock:
            self._rules[app_id] = (x, y, w, h)
            self._write_and_reload()

    def clear_rule(self, app_id: str):
        with self._lock:
            if self._rules.pop(app_id, None) is not None:
                self._write_and_reload()

    def _write_and_reload(self):
        if not os.path.isfile(self.rc_xml_path):
            log.warning(f"LabwcPlacementRules: no rc.xml at {self.rc_xml_path}, skipping")
            return
        try:
            with open(self.rc_xml_path, "r") as f:
                content = f.read()
        except OSError as e:
            log.warning(f"LabwcPlacementRules: couldn't read rc.xml: {e}")
            return

        block_lines = [self.BEGIN_MARKER, "<windowRules>"]
        for app_id, (x, y, w, h) in self._rules.items():
            escaped = app_id.replace("&", "&amp;").replace('"', "&quot;")
            block_lines.append(f'  <windowRule identifier="{escaped}" matchOnce="true">')
            block_lines.append(f'    <action name="MoveTo" x="{x}" y="{y}" />')
            block_lines.append(f'    <action name="ResizeTo" width="{w}" height="{h}" />')
            block_lines.append("  </windowRule>")
        block_lines.append("</windowRules>")
        block_lines.append(self.END_MARKER)
        block = "\n".join(block_lines)

        if self.BEGIN_MARKER in content and self.END_MARKER in content:
            pre = content.split(self.BEGIN_MARKER)[0]
            post = content.split(self.END_MARKER)[1]
            new_content = pre + block + post
        elif "</labwc_config>" in content:
            new_content = content.replace("</labwc_config>", block + "\n</labwc_config>")
        else:
            log.warning(
                "LabwcPlacementRules: rc.xml has no </labwc_config> closing "
                "tag and no existing managed block — refusing to guess "
                "where to insert, leaving rc.xml untouched"
            )
            return

        tmp_path = self.rc_xml_path + ".kortex-tmp"
        try:
            with open(tmp_path, "w") as f:
                f.write(new_content)
            os.replace(tmp_path, self.rc_xml_path)
        except OSError as e:
            log.warning(f"LabwcPlacementRules: couldn't write rc.xml: {e}")
            return

        self._reload_labwc()

    def _reload_labwc(self):
        # Same-user SIGHUP — kortexd runs as a per-user systemd service,
        # same UID as the compositor it's reconfiguring, so this needs
        # no privilege escalation (unlike kortex-helper's repair actions).
        try:
            r = subprocess.run(["pgrep", "-x", "labwc"], capture_output=True, text=True)
            pids = [p for p in r.stdout.split() if p]
            for pid in pids:
                os.kill(int(pid), 1)  # SIGHUP
        except Exception as e:
            log.warning(f"LabwcPlacementRules: couldn't SIGHUP labwc: {e}")


def resolve_monitor_origin(monitor_name: str):
    """Global-coordinate (x, y) origin of a named output, so a per-monitor
    learned placement can be turned into the absolute coordinates MoveTo
    wants. Shells out to wlr-randr (already in the image for the
    display-settings panel) rather than adding a second Wayland protocol
    binding here just for output geometry — wlr-randr's plain-text output
    is stable enough for this one field, and it's already a hard
    dependency of the image regardless of Kortex.
    """
    if shutil.which("wlr-randr") is None:
        return None
    try:
        out = subprocess.run(["wlr-randr"], capture_output=True, text=True, timeout=5).stdout
    except Exception:
        return None

    current_output = None
    for line in out.splitlines():
        if line and not line.startswith(" "):
            current_output = line.split()[0]
            continue
        stripped = line.strip()
        if current_output == monitor_name and stripped.startswith("Position"):
            # e.g. "Position 1920,0"
            coords = stripped.split()[-1]
            try:
                x_str, y_str = coords.split(",")
                return (int(x_str), int(y_str))
            except ValueError:
                return None
    return None
KORTEX_LABWC_BRIDGE_PY

cat > /usr/lib/kortex/kortexd/core.py << 'KORTEX_CORE_PY'
"""
kortexd.core
------------
Entrypoint. Runs the repair watcher + usage/session trackers on a background
thread, and the GTK notifier on the main thread (GTK requires the main
thread on most platforms).

Window-focus/launch/move events used to come from Wayfire's IPC (the
`ipc`/`ipc-rules` plugins from wayfire-plugins-extra, built from source
since that package was AUR-only on Arch), read here via the `wfctl` CLI.
Now that the build's back on labwc, that whole compositor IPC layer
doesn't exist anymore — labwc has no plugin system and nothing like it.
WindowEventSource below still exists and still gets wired up the same
way, it just detects there's no `wfctl` binary to talk to, logs that
once, and turns itself into a no-op instead of ever starting a watcher
thread. Everything else in Kortex — usage prediction, break reminders,
repair — has zero dependency on this and runs completely normally either
way. See WindowEventSource for the actual degrade-gracefully logic.
"""

import threading
import time
import datetime
import logging
import subprocess
import json
import shutil

from .storage import Store
from . import models
from .repair import RepairEngine, watch_journal
from .notifier import KortexNotifier
from .labwc_bridge import LabwcToplevelWatcher, LabwcPlacementRules, resolve_monitor_origin

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
    """Focus/launch/close events, plus best-effort placement, from
    whichever compositor backend is actually available. Two backends,
    tried in order, so KortexDaemon's call sites never need to know or
    care which one is live:

      1. labwc, via LabwcToplevelWatcher (kortexd.labwc_bridge) — real,
         event-driven, talks to zwlr_foreign_toplevel_manager_v1
         directly. This is the current image's compositor and the
         primary path now. See labwc_bridge.py's module docstring and
         the build script's banner comment above its install step for
         exactly what this protocol does and doesn't expose — short
         version: focus/launch/close are real, live window geometry
         (on_move) is not observable at all under this protocol, and
         placement application goes through a windowRule + SIGHUP
         reload rather than a live move, taking effect on that app_id's
         *next* launch rather than the instance that triggered it.

      2. wfctl / Wayfire IPC (pip: wfctl, github.com/killown/wfctl) —
         the original backend, from when this image ran Wayfire instead
         of labwc. Left in as a fallback purely in case this ever runs
         on a Wayfire session again; on a labwc-only image it will
         simply never find `wfctl` on $PATH and get skipped.

      3. True no-op — if neither backend is available (unknown
         compositor, headless, whatever), every method here is still
         safely callable and just does nothing. Same fail-closed
         philosophy this class always had.

    CAVEAT (left over from the Wayfire days, still accurate for that
    fallback path): the wfctl event/field names below (event,
    view.app-id, view.geometry, view-mapped/focused/geometry-changed)
    were based on wfctl's documented command surface and Wayfire's IPC
    changelog, never checked field-by-field against a live socket — if
    they ever turn out wrong, only _handle_wfctl_event() needs to change.

    CAVEAT: clicks aren't covered by either backend — no wlroots-based
    compositor IPC hands one client another client's raw pointer input
    by design, so `on_click` is wired but nothing calls it yet.
    Rage/dead-click detection would need a per-toolkit (GTK/Qt) hook
    instead, separate work from anything a compositor-IPC bridge could
    ever cover.
    """

    def __init__(self, on_focus, on_move, on_click, on_launch=None):
        self.on_focus = on_focus
        self.on_move = on_move
        self.on_click = on_click
        self.on_launch = on_launch
        self._known_views = set()   # wfctl path: view ids seen -> mapped vs re-mapped
        self._view_apps = {}        # wfctl path: view id -> app-id, for move_window
        self._backend = None        # "labwc", "wfctl", or None
        self._labwc_watcher = None
        self._labwc_rules = LabwcPlacementRules()

    def start(self):
        watcher = LabwcToplevelWatcher(
            on_focus=self.on_focus,
            on_launch=lambda app: self.on_launch and self.on_launch(app, None, None),
            on_close=lambda app: None,  # on_window_close isn't wired to a source yet either backend
        )
        if watcher.start():
            self._labwc_watcher = watcher
            self._backend = "labwc"
            log.info("WindowEventSource started (labwc bridge, zwlr_foreign_toplevel_manager_v1)")
            return

        if shutil.which("wfctl") is not None:
            self._backend = "wfctl"
            threading.Thread(target=self._watch_loop, daemon=True).start()
            log.info("WindowEventSource started (wfctl -m watching compositor IPC)")
            return

        log.info(
            "WindowEventSource: no working backend (neither the labwc "
            "bridge nor wfctl came up). Window-event tracking is "
            "disabled; everything else in Kortex is unaffected."
        )

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
                self._handle_wfctl_event(event)
        finally:
            proc.terminate()

    def _handle_wfctl_event(self, event):
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
        """Applies a placement, via whichever backend is live.

        wfctl backend: live move/resize on the current view (used both
        for Kortex-initiated shifts and for reverting one via the Undo
        button) — same as it always did.

        labwc backend: NOT a live move — see this class's and
        labwc_bridge.LabwcPlacementRules's docstrings for why one isn't
        possible under labwc's currently-implemented protocol set. This
        writes/refreshes a windowRule (MoveTo/ResizeTo) for `app` and
        SIGHUPs labwc to reload it, which then applies the next time
        `app` maps a window — not necessarily the instance open right
        now. `monitor` is treated as an output *name* (matching
        wlr-randr's naming) and resolved to a global-coordinate origin
        that x/y get added to, since labwc's MoveTo takes coordinates in
        the full multi-output layout space, not per-output-relative
        ones — if `monitor` doesn't resolve to a known output, x/y are
        used as-is on the assumption they're already global.
        """
        if self._backend == "labwc":
            ox, oy = 0, 0
            origin = resolve_monitor_origin(monitor) if monitor else None
            if origin:
                ox, oy = origin
            self._labwc_rules.set_rule(app, int(x) + ox, int(y) + oy, int(w), int(h))
            return

        if self._backend == "wfctl":
            view_id = self._resolve_view_id(app)
            if view_id is None:
                log.warning(f"move_window: no live view found for {app!r}, skipping")
                return
            ok1, out1 = _run(["wfctl", "move", "view", str(view_id), str(int(x)), str(int(y))])
            ok2, out2 = _run(["wfctl", "resize", "view", str(view_id), str(int(w)), str(int(h))])
            if not (ok1 and ok2):
                log.warning(f"move_window failed for {app!r} (view {view_id}): {out1} / {out2}")
            return

        log.warning(f"move_window: no backend available, skipping placement for {app!r}")

    def _resolve_view_id(self, app):
        for vid, a in self._view_apps.items():
            if a == app:
                return vid
        return None

    def clear_placement(self, app):
        """Stops applying a learned placement for `app` going forward.
        Only meaningful for the labwc backend, where "undo" without a
        known prior position means removing the windowRule rather than
        moving anywhere (see KortexDaemon._undo_shift) — the wfctl
        backend always has a real old_xywh to move back to instead, so
        this is never reached on that path.
        """
        if self._backend == "labwc":
            self._labwc_rules.clear_rule(app)


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

        Under the labwc backend, `monitor` and `current_xywh` both arrive
        as None — zwlr_foreign_toplevel_manager_v1 doesn't hand back
        geometry or (at launch time) even a resolved output, so there's
        nothing to fill them in with. Falls back to the most-recently-
        learned monitor for this app rather than guessing 0, and skips
        the "already there" short-circuit since there's no current
        geometry to compare against — move_window() is idempotent
        (rewrites the same windowRule) so a redundant call just costs a
        wasted SIGHUP, not a wrong result.
        """
        confidence = self.store.get_placement_confidence(app)
        if confidence < self.PLACEMENT_APPLY_THRESHOLD:
            return  # still just accumulating weight, not acted on yet

        if monitor is None:
            monitor = self.store.get_last_placement_monitor(app)
            if monitor is None:
                return  # no history to fall back to yet

        learned = self.store.get_placement(app, monitor)
        if not learned:
            return
        if current_xywh is not None and learned[:4] == current_xywh:
            return  # already there (only knowable on backends with live geometry)

        old_xywh = current_xywh  # may be None under labwc — _undo_shift handles that
        new_xywh = learned[:4]
        self.window_source.move_window(app, monitor, *new_xywh)
        self.notifier.on_preference_shift(
            on_undo=lambda: self._undo_shift(app, monitor, old_xywh)
        )

    def _undo_shift(self, app, monitor, old_xywh):
        # Move it back — or, under labwc when old_xywh is unknown (see
        # on_window_launch), just stop applying the learned rule going
        # forward rather than moving to a position we never actually
        # observed. Either way this is "undo the automatic behavior,"
        # not "reproduce the exact prior pixel position."
        if old_xywh is not None:
            self.window_source.move_window(app, monitor, *old_xywh)
        else:
            self.window_source.clear_placement(app)
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
# --include-package=pywayland: needed explicitly, unlike kortexd's own
# submodules — pywayland isn't imported unconditionally at module scope
# (labwc_bridge.py wraps the import in try/except so the daemon still
# runs on non-labwc/non-Wayland sessions), and Nuitka's static import
# scan can miss packages that are only ever reached through a guarded
# import. --include-package-data pulls in pywayland's bundled protocol
# XML/cffi build artifacts alongside it.
#
# CAVEAT, not yet verified end-to-end: pywayland's Wayland calls go
# through a cffi extension module (_ffi), and cffi extensions inside a
# Nuitka --onefile binary are a known rough edge — the onefile bootstrap
# unpacks to a temp dir at runtime and dynamic/cffi-loaded .so files
# don't always resolve correctly from there. If kortexd's labwc bridge
# comes up as unavailable in a compiled build despite working fine when
# run straight from `python -m kortexd`, this is the first place to
# check — --standalone (non-onefile) sidesteps the temp-unpack step
# entirely and is the fallback if onefile turns out not to work here.
#
# Working directory matters here: `kortexd` below is a bare module name,
# resolved via --python-flag=-m against the CURRENT directory (nothing
# earlier in this script ever cd's into /usr/lib/kortex — the last cd
# anywhere above this point is `cd "${WORKDIR}"` for the archiso profile
# at the very top). Without this cd, Nuitka looks for `kortexd` wherever
# that leaves us and fails with "file 'kortexd' is not found". The
# `build/kortexd` relative path in the install step below, and the
# absolute /usr/lib/kortex/... cleanup paths after it, both already
# assumed this cwd — this was the one piece that was missing.
cd /usr/lib/kortex
python -m nuitka \
  --standalone \
  --onefile \
  --output-dir=build \
  --output-filename=kortexd \
  --include-package=kortexd \
  --include-package-data=kortexd \
  --include-package=pywayland \
  --include-package-data=pywayland \
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

# ══════════════════════════════════════════════════════════════════════════
# KIBA IDENTITY MASK — brand the OS name reported to userspace software
# ══════════════════════════════════════════════════════════════════════════
# Honest scope note up front: this rebrand the *sysname* string
# (Linux -> KibaOS) that libc's uname(2) wrapper hands to any dynamically
# linked process, since that's the field software actually surfaces to
# users ("uname -a", Python's platform.system(), Node's os.type(), etc).
# It deliberately leaves release/version/machine untouched -- those are
# the fields real software parses for kernel feature detection (Docker,
# some drivers, some game anti-cheat, etc), and lying about them doesn't
# hide anything, it just breaks things. This is branding, not a security
# boundary: statically linked binaries and anything issuing the raw
# uname(2) syscall directly (rare, but e.g. Go binaries with CGO
# disabled) bypass it entirely, and any process is free to unset
# LD_PRELOAD or export KIBAOS_REAL_UNAME=1 to see the real value. If
# that matters for a given workload (kernel version probing in a
# container build, driver installers, etc), that's what the escape
# hatch is for.
echo "=== Building kiba-identity (uname sysname rebrand, LD_PRELOAD) ==="
mkdir -p /usr/lib/kibaos/src
cat > /usr/lib/kibaos/src/kiba_identity.c << 'KIBA_IDENTITY_C'
/* kiba_identity.c — LD_PRELOAD shim rebranding uname(2)'s sysname field
 * from "Linux" to "KibaOS" for any dynamically linked process that
 * loads it. See the build-script comment above this heredoc for the
 * full scope note (what this does and deliberately does not cover).
 */
#define _GNU_SOURCE
#include <sys/utsname.h>
#include <dlfcn.h>
#include <string.h>
#include <stdlib.h>

typedef int (*real_uname_fn)(struct utsname *);

int uname(struct utsname *buf) {
    static real_uname_fn real_uname = NULL;
    if (!real_uname) real_uname = (real_uname_fn)dlsym(RTLD_NEXT, "uname");
    int rc = real_uname(buf);
    /* KIBAOS_REAL_UNAME is the documented escape hatch -- any process
     * that actually needs the real kernel-reported sysname (rare, but
     * real) can set it rather than fight LD_PRELOAD. */
    if (rc == 0 && !getenv("KIBAOS_REAL_UNAME")) {
        strncpy(buf->sysname, "KibaOS", sizeof(buf->sysname) - 1);
        buf->sysname[sizeof(buf->sysname) - 1] = '\0';
    }
    return rc;
}
KIBA_IDENTITY_C

gcc -shared -fPIC -O2 -Wall /usr/lib/kibaos/src/kiba_identity.c \
    -o /usr/lib/kibaos/libkibaidentity.so -ldl \
  || { echo "FATAL: kiba_identity.c failed to compile" >&2; exit 1; }
rm -rf /usr/lib/kibaos/src
chown root:root /usr/lib/kibaos/libkibaidentity.so
chmod 755 /usr/lib/kibaos/libkibaidentity.so

# System-wide activation. /etc/ld.so.preload is honored by the dynamic
# linker for every dynamically linked process on the system (not just
# graphical-session ones, unlike kortex-authd above) -- that's the
# whole point here, since the goal is "uname just says KibaOS" without
# every individual app needing to opt in.
echo "/usr/lib/kibaos/libkibaidentity.so" > /etc/ld.so.preload
chmod 644 /etc/ld.so.preload
echo "=== kiba-identity installed ==="

# ══════════════════════════════════════════════════════════════════════════
# KIBA VIEW — a per-session translated filesystem view over XDG user dirs
# ══════════════════════════════════════════════════════════════════════════
# Honest scope note: this is a real FUSE read/write passthrough (getattr,
# readdir, open/create, read, write, truncate, mkdir, unlink, rmdir,
# rename -- tested against exactly this operation set during development),
# not a symlink farm. A symlink farm is trivially seen through with a
# single `ls -la` (every entry shows its real target); a passthrough FUSE
# mount doesn't expose the backing path to callers at all through any of
# the operations it implements. It is NOT a security boundary and doesn't
# try to be one -- the real ~/Documents etc. still exist at their real
# paths, still owned by the same user, still readable by that user or
# root through the real path exactly as before. What this actually does
# is give the desktop (Nemo's sidebar/bookmarks, see the desktop-config
# section) somewhere friendly-looking to point at instead of the FHS-y
# real path, for the same "the user never needs to see /home/username"
# reason the KibaOS branding work elsewhere in this file exists. Runs
# per-user via a systemd --user unit (below), not system-wide -- root
# and other users are unaffected.
#
# Coverage: this used to only translate the six curated XDG roots, which
# meant anything else living under $HOME (a stray project folder, a
# manually-created directory) simply wasn't reachable through the view
# at all -- not hidden, just absent. There's now a seventh catch-all
# root, "Other Files", that passes through the rest of $HOME so nothing
# a user has actually put there goes missing. Dotfiles/dot-directories
# (.config, .cache, .local, .var, etc. -- our AppData-equivalent) are
# filtered out of every directory listing this filesystem serves, the
# same "hidden by convention" treatment they already got everywhere
# else. That, plus pointing the desktop's default file-manager location
# and sidebar bookmarks at this mount instead of raw $HOME (see the
# desktop-config and first-login sections below), makes ~/KibaOS the
# only filesystem view a user browsing files graphically ever lands on
# -- the ChromeOS Files-app idea, just backed by a real POSIX overlay
# instead of a sandboxed Downloads folder. This is still additive, not
# a takeover: the mount lives at ~/KibaOS, a directory alongside the
# real $HOME rather than over top of it, so anything that legitimately
# wants a regular file path -- a terminal, an editor, dev tooling, the
# package manager, systemd itself -- keeps using real $HOME exactly as
# before and is completely unaffected by any of this.
echo "=== Building kiba-view (translated per-user FUSE filesystem) ==="
mkdir -p /usr/lib/kibaos/src
cat > /usr/lib/kibaos/src/kiba_view_fs.c << 'KIBA_VIEW_FS_C'
/* kiba_view_fs.c — FUSE3 read/write passthrough presenting a curated
 * top-level layout (Documents/Downloads/Pictures/Music/Videos/Desktop)
 * mapped onto the real $HOME's XDG user dirs, resolved once at startup
 * via xdg-user-dir(1) rather than hardcoded -- respects whatever
 * localized/relocated directories the user (or KibaOS's OOBE locale
 * step) actually configured. See kv_ops at the bottom for the exact
 * operation set implemented; anything not listed there (symlinks,
 * xattrs, hardlinks, special files) isn't supported by this passthrough
 * and will surface ENOSYS/ENOTSUP to the caller rather than silently
 * doing the wrong thing.
 */
#define FUSE_USE_VERSION 31
#include <fuse3/fuse.h>
#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdlib.h>
#include <dirent.h>
#include <limits.h>
#include <stdbool.h>

/* The first 6 are the curated XDG roots, resolved via xdg-user-dir(1)
 * below. The 7th, "Other Files", is a catch-all passthrough straight to
 * $HOME itself -- see the coverage note above the build step that emits
 * this file for why it exists. It has no XDG key (index kept in sync
 * with OTHER_IDX, not looked up via xdg-user-dir). */
#define N_CURATED_ROOTS 6
#define N_ROOTS (N_CURATED_ROOTS + 1)
#define OTHER_IDX (N_ROOTS - 1)
static const char *ROOT_NAMES[N_ROOTS] = {
    "Documents", "Downloads", "Pictures", "Music", "Videos", "Desktop",
    "Other Files"
};
static const char *XDG_KEYS[N_CURATED_ROOTS] = {
    "DOCUMENTS", "DOWNLOAD", "PICTURES", "MUSIC", "VIDEOS", "DESKTOP"
};
static char root_backing[N_ROOTS][PATH_MAX];

/* Resolves each translated root's real path once at startup by shelling
 * out to xdg-user-dir(1) -- the same source of truth the rest of the
 * desktop (file manager, portals, xdg-user-dirs.service) already uses,
 * so this view never drifts out of sync with wherever those actually
 * point. Falls back to $HOME/<name> if xdg-user-dir isn't available or
 * a given dir hasn't been configured yet. "Other Files" backs directly
 * onto $HOME with no xdg-user-dir lookup and no mkdir (it always
 * exists -- it's the home directory). */
static void resolve_roots(void) {
    const char *home = getenv("HOME");
    if (!home) home = "/tmp";
    for (int i = 0; i < N_CURATED_ROOTS; i++) {
        char cmd[256];
        snprintf(cmd, sizeof(cmd), "xdg-user-dir %s 2>/dev/null", XDG_KEYS[i]);
        FILE *fp = popen(cmd, "r");
        bool got = false;
        if (fp) {
            if (fgets(root_backing[i], sizeof(root_backing[i]), fp)) {
                size_t len = strlen(root_backing[i]);
                if (len > 0 && root_backing[i][len - 1] == '\n') root_backing[i][len - 1] = '\0';
                if (root_backing[i][0] == '/') got = true;
            }
            pclose(fp);
        }
        if (!got) snprintf(root_backing[i], sizeof(root_backing[i]), "%s/%s", home, ROOT_NAMES[i]);
        mkdir(root_backing[i], 0755); /* no-op if it already exists */
    }
    snprintf(root_backing[OTHER_IDX], sizeof(root_backing[OTHER_IDX]), "%s", home);
}

static int resolve(const char *path, char *out, size_t outsz) {
    if (strcmp(path, "/") == 0) return -1;
    for (int i = 0; i < N_ROOTS; i++) {
        size_t nlen = strlen(ROOT_NAMES[i]);
        if (strncmp(path + 1, ROOT_NAMES[i], nlen) == 0 &&
            (path[1 + nlen] == '\0' || path[1 + nlen] == '/')) {
            snprintf(out, outsz, "%s%s", root_backing[i], path + 1 + nlen);
            return 0;
        }
    }
    return -2;
}

static int kv_getattr(const char *path, struct stat *st, struct fuse_file_info *fi) {
    (void)fi;
    memset(st, 0, sizeof(*st));
    if (strcmp(path, "/") == 0) { st->st_mode = S_IFDIR | 0755; st->st_nlink = 2; return 0; }
    char real[PATH_MAX];
    int r = resolve(path, real, sizeof(real));
    if (r == -1) { st->st_mode = S_IFDIR | 0755; st->st_nlink = 2; return 0; }
    if (r == -2) return -ENOENT;
    if (lstat(real, st) != 0) return -errno;
    return 0;
}

static int kv_readdir(const char *path, void *buf, fuse_fill_dir_t filler,
                       off_t offset, struct fuse_file_info *fi, enum fuse_readdir_flags flags) {
    (void)offset; (void)fi; (void)flags;
    filler(buf, ".", NULL, 0, 0);
    filler(buf, "..", NULL, 0, 0);
    if (strcmp(path, "/") == 0) {
        for (int i = 0; i < N_ROOTS; i++) filler(buf, ROOT_NAMES[i], NULL, 0, 0);
        return 0;
    }
    char real[PATH_MAX];
    if (resolve(path, real, sizeof(real)) != 0) return -ENOENT;
    DIR *d = opendir(real);
    if (!d) return -errno;
    /* Top level of the "Other Files" catch-all is the one place that can
     * legitimately show the same real entries the curated roots already
     * show elsewhere in this view (Documents, Downloads, ... all live
     * directly under $HOME on disk). Skip those names there so they
     * don't appear twice under two different names in the same view. */
    bool at_other_top = (strcmp(path, "/") != 0 &&
                          strcmp(path + 1, ROOT_NAMES[OTHER_IDX]) == 0);
    struct dirent *e;
    while ((e = readdir(d))) {
        /* Hide dotfiles/dot-directories everywhere this filesystem is
         * browsed -- our AppData-equivalent (.config, .cache, .local,
         * .var, ...) shouldn't clutter a view meant to be the tidy,
         * ChromeOS-style "this is all your stuff" surface. They're
         * still real files at their real path for anything that opens
         * them directly by name (e.g. an app reading its own config)
         * -- this only affects what shows up in a directory listing. */
        if (e->d_name[0] == '.') continue;
        if (at_other_top) {
            bool is_curated_dup = false;
            for (int i = 0; i < N_CURATED_ROOTS; i++) {
                if (strcmp(e->d_name, ROOT_NAMES[i]) == 0) { is_curated_dup = true; break; }
            }
            if (is_curated_dup) continue;
        }
        filler(buf, e->d_name, NULL, 0, 0);
    }
    closedir(d);
    return 0;
}

static int kv_open(const char *path, struct fuse_file_info *fi) {
    char real[PATH_MAX];
    if (resolve(path, real, sizeof(real)) != 0) return -ENOENT;
    int fd = open(real, fi->flags);
    if (fd < 0) return -errno;
    fi->fh = fd;
    return 0;
}

static int kv_create(const char *path, mode_t mode, struct fuse_file_info *fi) {
    char real[PATH_MAX];
    if (resolve(path, real, sizeof(real)) != 0) return -ENOENT;
    int fd = open(real, fi->flags | O_CREAT, mode);
    if (fd < 0) return -errno;
    fi->fh = fd;
    return 0;
}

static int kv_read(const char *path, char *buf, size_t size, off_t offset, struct fuse_file_info *fi) {
    (void)path;
    ssize_t r = pread(fi->fh, buf, size, offset);
    return r < 0 ? -errno : (int)r;
}

static int kv_write(const char *path, const char *buf, size_t size, off_t offset, struct fuse_file_info *fi) {
    (void)path;
    ssize_t r = pwrite(fi->fh, buf, size, offset);
    return r < 0 ? -errno : (int)r;
}

static int kv_truncate(const char *path, off_t size, struct fuse_file_info *fi) {
    if (fi) return ftruncate(fi->fh, size) == 0 ? 0 : -errno;
    char real[PATH_MAX];
    if (resolve(path, real, sizeof(real)) != 0) return -ENOENT;
    return truncate(real, size) == 0 ? 0 : -errno;
}

static int kv_release(const char *path, struct fuse_file_info *fi) { (void)path; close(fi->fh); return 0; }

static int kv_mkdir(const char *path, mode_t mode) {
    char real[PATH_MAX];
    if (resolve(path, real, sizeof(real)) != 0) return -ENOENT;
    return mkdir(real, mode) == 0 ? 0 : -errno;
}

static int kv_unlink(const char *path) {
    char real[PATH_MAX];
    if (resolve(path, real, sizeof(real)) != 0) return -ENOENT;
    return unlink(real) == 0 ? 0 : -errno;
}

static int kv_rmdir(const char *path) {
    char real[PATH_MAX];
    if (resolve(path, real, sizeof(real)) != 0) return -ENOENT;
    return rmdir(real) == 0 ? 0 : -errno;
}

static int kv_rename(const char *from, const char *to, unsigned int flags) {
    (void)flags;
    char rfrom[PATH_MAX], rto[PATH_MAX];
    if (resolve(from, rfrom, sizeof(rfrom)) != 0) return -ENOENT;
    /* Cross-root renames (Documents/x -> Downloads/x) aren't supported
     * by this prototype-derived passthrough -- each translated root maps
     * to a different real XDG directory, and silently doing a copy+
     * unlink instead of an atomic rename would be a correctness
     * footgun for anything relying on rename's atomicity. Surfacing
     * EXDEV (the same errno a real cross-filesystem rename gives) lets
     * the file manager fall back to its own copy+delete UI flow instead. */
    if (resolve(to, rto, sizeof(rto)) != 0) return -ENOENT;
    char from_root[64], to_root[64];
    sscanf(from + 1, "%63[^/]", from_root);
    sscanf(to + 1, "%63[^/]", to_root);
    if (strcmp(from_root, to_root) != 0) return -EXDEV;
    return rename(rfrom, rto) == 0 ? 0 : -errno;
}

static const struct fuse_operations kv_ops = {
    .getattr  = kv_getattr,
    .readdir  = kv_readdir,
    .open     = kv_open,
    .create   = kv_create,
    .read     = kv_read,
    .write    = kv_write,
    .truncate = kv_truncate,
    .release  = kv_release,
    .mkdir    = kv_mkdir,
    .unlink   = kv_unlink,
    .rmdir    = kv_rmdir,
    .rename   = kv_rename,
};

int main(int argc, char *argv[]) {
    resolve_roots();
    return fuse_main(argc, argv, &kv_ops, NULL);
}
KIBA_VIEW_FS_C

gcc -O2 -Wall $(pkg-config --cflags fuse3) /usr/lib/kibaos/src/kiba_view_fs.c \
    -o /usr/lib/kibaos/kiba-view-fs $(pkg-config --libs fuse3) \
  || { echo "FATAL: kiba_view_fs.c failed to compile/link" >&2; exit 1; }
rm -rf /usr/lib/kibaos/src
chown root:root /usr/lib/kibaos/kiba-view-fs
chmod 755 /usr/lib/kibaos/kiba-view-fs

# Per-user session unit: mounts at ~/KibaOS right before the desktop
# comes up, unmounts on session teardown. "-o auto_unmount" means an
# unclean session death (crash, kill -9) still gets fusermount'd rather
# than leaving a stale mountpoint behind next login.
cat > /usr/lib/systemd/user/kiba-view.service << 'KIBA_VIEW_SERVICE'
[Unit]
Description=KibaOS translated file view (~/KibaOS)
After=graphical-session-pre.target
Before=graphical-session.target
PartOf=graphical-session.target

[Service]
Type=simple
ExecStartPre=/usr/bin/mkdir -p %h/KibaOS
ExecStart=/usr/lib/kibaos/kiba-view-fs -f -o auto_unmount %h/KibaOS
# Type=simple only means "the process was forked" -- it says nothing
# about whether the FUSE handshake with the kernel has actually
# finished, i.e. whether %h/KibaOS is really mountable yet. The labwc
# wrapper (kibaos-session-userview, see the SESSION-SCOPED HOME VIEW
# section) needs a real "yes, it's live" signal before it dares
# bind-mount this over $HOME for the whole session, so poll for the
# mountpoint to actually come up (bounded, half a second max) and only
# then touch the ready marker it waits on. Cleaned up on the way down so
# a crashed/stopped session can never be mistaken for a ready one.
ExecStartPost=/bin/sh -c 'for i in $(seq 1 50); do mountpoint -q %h/KibaOS && { touch %t/kiba-view-ready; exit 0; }; sleep 0.01; done; exit 1'
ExecStopPost=/usr/bin/rm -f %t/kiba-view-ready
ExecStop=/usr/bin/fusermount3 -u %h/KibaOS
Restart=on-failure
RestartSec=3

[Install]
WantedBy=graphical-session.target
KIBA_VIEW_SERVICE

mkdir -p /etc/skel/.config/systemd/user/graphical-session.target.wants
ln -sf /usr/lib/systemd/user/kiba-view.service \
  /etc/skel/.config/systemd/user/graphical-session.target.wants/kiba-view.service
echo "=== kiba-view installed ==="

# ══════════════════════════════════════════════════════════════════════════
# SESSION-SCOPED HOME VIEW — the other half of KIBA VIEW
# ══════════════════════════════════════════════════════════════════════════
# Everything above gives kiba-view its own separate mountpoint at
# ~/KibaOS, alongside real $HOME, which apps only see if something
# (Nemo's sidebar, the Files launcher) specifically points them there.
# This section goes further: it makes ~/KibaOS what $HOME itself
# *resolves to* for the graphical session, so every GUI app -- not just
# the ones explicitly wired to it -- gets the curated view by default,
# while everything outside the graphical session (SSH logins, systemd
# services, cron, and -- deliberately carved back out below -- a
# terminal opened from inside the session) keeps seeing the real thing.
#
# The mechanism is a private Linux mount namespace (unshare(CLONE_NEWNS)),
# NOT a symlink or a bind mount at the filesystem level everyone shares --
# see https://zameermanji.com/blog/2022/8/5/using-fuse-without-root-on-linux/
# for the background this leans on: an unprivileged user can create a new
# user+mount namespace via `unshare --user --mount` and mount/bind-mount
# freely inside it, and -- critically -- nothing done inside that
# namespace is visible from outside it, not even by bind-mounting the
# mountpoint back out. That second property is exactly what "the user
# sees X, programs still see real $HOME" needs: it's not a permissions
# trick or a filter, it's two genuinely different views of the
# filesystem that can't leak into each other by accident.
#
# `--map-current-user` (added to util-linux's unshare specifically for
# this kind of use case) rather than the more commonly-seen
# `--map-root-user`: it identity-maps the real UID/GID into the new user
# namespace instead of remapping to 0. That matters here because the
# Wayland socket, the D-Bus session bus, and XDG_RUNTIME_DIR are all
# permission-checked by numeric UID -- remapping to root would make
# every one of those checks see a different "user" than the one that
# actually owns them and break the session outright. Identity mapping
# sidesteps that: as far as any ownership check anywhere on the system
# is concerned, this is still exactly the same user it always was, just
# with a private view of the mount table.
#
# Where the substitution happens: PATH-shadowing /usr/bin/labwc with a
# wrapper of the same name in /usr/local/bin (which sits earlier in
# PATH), rather than editing Budgie's own packaged wayland-sessions
# .desktop file or adding a competing one. That keeps this update-safe
# -- a `pacman -Syu` to budgie-desktop can't clobber or conflict with a
# file it doesn't know exists -- and self-contained to one script.
#
# Known limitation, stated plainly rather than glossed over: this relies
# on GUI apps being launched as actual descendants of this process tree
# (which is how Budgie's panel/dock launch things -- direct fork, not
# GNOME Shell's systemd-scope-per-app model). An app launched via
# `systemd-run --user --scope` instead of a direct fork would be
# reparented under systemd --user itself and would NOT inherit this
# namespace, since it was never a child of it in the first place. If
# KibaOS ever moves to that launch model, this needs revisiting -- it
# would silently stop taking effect for newly-launched apps rather than
# fail loudly, which is worth knowing going in.
cat > /usr/local/bin/labwc << 'LABWC_WRAPPER'
#!/bin/bash
# PATH-shadowed wrapper for the real labwc (/usr/bin/labwc) -- see the
# SESSION-SCOPED HOME VIEW comment block in the build script for the
# full design. Fails open at every step: a broken/missing unshare, an
# old kernel with unprivileged user namespaces disabled, kiba-view.service
# never coming up in time -- none of it may ever block login. Worst case
# is just "no view substitution this session," never "can't log in."
REAL_LABWC="/usr/bin/labwc"
REAL_HOME_MARK="${XDG_RUNTIME_DIR:-/tmp}/kibaos-real-home"
READY_MARK="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/kiba-view-ready"

can_userns() {
  command -v unshare >/dev/null 2>&1 && \
    unshare --user --map-current-user --mount true 2>/dev/null
}

wait_for_kiba_view() {
  # kiba-view.service is what actually populates ~/KibaOS -- it's
  # started as part of reaching graphical-session.target, which is
  # usually pulled in from labwc's own autostart, i.e. *after* this
  # wrapper's exec happens. Poll its readiness marker for a few seconds
  # rather than assume any particular ordering -- if it never shows up
  # (service failed, disabled, whatever), fail open and skip the
  # substitution entirely instead of hanging the session waiting for it.
  for _ in $(seq 1 100); do
    [ -f "${READY_MARK}" ] && return 0
    sleep 0.1
  done
  return 1
}

if can_userns && wait_for_kiba_view; then
  exec unshare --user --map-current-user --mount --propagation private -- \
    bash -c 'mkdir -p "$0" 2>/dev/null
             mount --bind "$HOME" "$0" 2>/dev/null &&
             mount --bind "$HOME/KibaOS" "$HOME" 2>/dev/null
             exec "$1" "${@:2}"' \
    "${REAL_HOME_MARK}" "${REAL_LABWC}" "$@"
fi

exec "${REAL_LABWC}" "$@"
LABWC_WRAPPER
chmod +x /usr/local/bin/labwc

# ── The terminal's escape hatch back to the real $HOME ──────────────────
# Without this, a terminal opened from inside the substituted session
# would inherit the overlay too -- meaning dev tools, git, the package
# manager, and anything else run from a shell would be working against
# ~/KibaOS instead of real $HOME, which is exactly the "programs still
# see real $HOME" half of this feature. Same PATH-shadow trick, this
# time against kgx (GNOME Console's actual binary name -- see the
# "GNOME Console (kgx)" note elsewhere in this file for why it's the
# one that matters; gnome-terminal is hidden from the app menu entirely
# and only used internally by the WinApps setup flow, and its D-Bus
# single-instance-server architecture means a simple exec-time wrapper
# like this one can't reliably reach it anyway -- not attempting to
# solve that here).
#
# Nested unshare, not just "undo the parent's mount": this needs its own
# fresh private mount namespace to safely re-bind $HOME without
# disturbing every other window/app still running in the session's
# substituted view -- mount namespaces nest cleanly (a child namespace
# starts as a copy of the parent's table and diverges from there), so
# this only changes what *this terminal and its own children* see.
cat > /usr/local/bin/kgx << 'KGX_WRAPPER'
#!/bin/bash
REAL_KGX="/usr/bin/kgx"
REAL_HOME_MARK="${XDG_RUNTIME_DIR:-/tmp}/kibaos-real-home"

if [ -d "${REAL_HOME_MARK}" ] && command -v unshare >/dev/null 2>&1 && \
   unshare --user --map-current-user --mount true 2>/dev/null
then
  exec unshare --user --map-current-user --mount --propagation private -- \
    bash -c 'mount --bind "$0" "$HOME" 2>/dev/null
             exec "$1" "${@:2}"' \
    "${REAL_HOME_MARK}" "${REAL_KGX}" "$@"
fi

# REAL_HOME_MARK missing means this terminal isn't actually running
# inside a substituted session (e.g. the labwc wrapper above never got
# a chance to set it up) -- there's nothing to undo, just run kgx as
# normal rather than fail or loop.
exec "${REAL_KGX}" "$@"
KGX_WRAPPER
chmod +x /usr/local/bin/kgx

echo "=== session-scoped home view installed ==="


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
# One shared source image now backs both the app-icon set (kibaos.png /
# hicolor icons) and the Plymouth boot splash -- previously LOGO_URL
# ("boot.png") and BOOT_SPLASH_URL were two separate fetches of two
# different images. This is the circular "K" badge over "KibaOS" wordmark
# lockup on a black field, 1536x1024, landscape -- NOT a pre-cropped square
# icon like the old boot.png was, so it can't just be resized straight into
# square icon sizes without letterboxing and dragging the wordmark along.
# Icon generation below crops out just the circular badge first; the boot
# splash uses the full lockup (wordmark included) unmodified. The OOBE
# installer logo further below now reuses this same processed boot splash
# image directly too -- previously its own separate installer.png fetch,
# which meant two brand assets that had to be kept in sync by hand for no
# real benefit, since they're meant to be the same mark anyway.
BOOT_SPLASH_URL="https://github.com/WolfTech-Innovations/Kiba/blob/76dfc8fa4c96461c42a14f57b46689fec858b735/branding/file_00000000ba3081f7bfd242de31c8979b.png?raw=true"
WALLPAPER_DEST="/usr/share/kibaos/wallpaper.jpg"
LOGO_SRC="/usr/share/kibaos/logo-raw.png"
LOGO_256="/usr/share/kibaos/logo-256.png"
LOGO_96="/usr/share/kibaos/logo-96.png"
LOGO_48="/usr/share/kibaos/logo-48.png"
LOGO_32="/usr/share/kibaos/logo-32.png"
INSTALLER_LOGO="/usr/share/kibaos/installer-logo.png"
BOOT_SPLASH_RAW="/usr/share/kibaos/boot-splash-raw.png"
BOOT_SPLASH="/usr/share/kibaos/boot-splash.png"

mkdir -p /usr/share/kibaos /usr/share/pixmaps

curl -fL --retry 5 --retry-delay 3 -o "${BOOT_SPLASH_RAW}" "${BOOT_SPLASH_URL}" || true

if [ -f "${BOOT_SPLASH_RAW}" ] && file "${BOOT_SPLASH_RAW}" | grep -qi 'image'; then
  # Boot splash: full lockup (badge + wordmark), scaled down, aspect kept.
  magick "${BOOT_SPLASH_RAW}" -filter Lanczos -resize '480x480>' "${BOOT_SPLASH}"

  # App icons: crop out just the circular badge before resizing, so square
  # icon sizes get a clean centered mark instead of a letterboxed lockup
  # with the wordmark jammed in. Crop box (640x640, offset 450,117) is a
  # fixed region measured against this specific source image -- centered on
  # the badge with even padding on all sides, wordmark excluded. If the
  # source branding image is ever swapped again, re-measure this box.
  magick "${BOOT_SPLASH_RAW}" -crop 640x640+450+117 +repage "${LOGO_SRC}"
  rm -f "${BOOT_SPLASH_RAW}"
fi

curl -fL --retry 5 --retry-delay 3 -o "${WALLPAPER_DEST}" "${WALLPAPER_URL}" || \
  magick -size 1920x1080 gradient:"#003f5c-#0099cc" "${WALLPAPER_DEST}"

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

# ── OOBE installer logo — same image as the boot splash ─────────────────
# Reuses the already-processed BOOT_SPLASH file directly (full lockup:
# badge + "KibaOS" wordmark) instead of fetching/maintaining a second,
# separate installer.png brand asset. Falls back to the generic cropped-
# badge logo only if the boot splash itself never downloaded (offline
# build, URL moved, etc.) -- same fallback behavior as before.
if [ -f "${BOOT_SPLASH}" ]; then
  cp "${BOOT_SPLASH}" "${INSTALLER_LOGO}"
else
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
# backstory: I originally tried porting elementary/installer + distinst
# over to Arch/pacman. gave up on that road entirely — distinst's
# apt/dpkg assumptions needed a Rust source patch (did that), which then
# needed GNU parted built from source just to get full libparted headers
# for bindgen (did that too), which then ran face-first into an unrelated
# upstream parted CLI compile bug. at that point I was just patching a
# dependency chain that was never built for Arch in the first place, so
# screw it, this whole section is a small from-scratch Vala/GTK4/
# libadwaita app instead:
#   - UI: a NavigationView stack, one page per step (welcome, locale,
#     disk, account, confirm, installing, done). no sidebar, no visible
#     step list — matches the Windows-OOBE single-question-per-screen
#     vibe I actually wanted, themed in KibaOS's own navy/glass palette
#     (same colors as gtk-3.0/gtk.css elsewhere in this script).
#   - Backend: a privileged C binary (kibaos-oobe-backend), called via
#     sudo with a plain argv array — no shell string, no quoting/
#     injection surface, no D-Bus/polkit dependency to worry about. the
#     udev-settle wait is hand-rolled in libkibadisk against raw ioctls,
#     and GPT partitioning shells out to sgdisk (argv array via execvp,
#     never a shell — see kiba_gpt.c) instead of writing my own or
#     dragging in a libfdisk link dependency. no archinstall, no parted,
#     no blkid/partprobe subprocess anywhere near the disk-critical path.
#     whatever external tools are left (sgdisk, unsquashfs, mkfs.fat/
#     mkfs.ext4, arch-chroot, refind-install, mkinitcpio, useradd/
#     chpasswd, locale-gen, pacman) just don't have a sane from-scratch
#     replacement, so those get invoked via argv arrays too, never a
#     shell. the library source lives in /usr/share/kibaos-oobe/src/disk/
#     (kiba_gpt.c, kiba_fs.c, kiba_udev.c, kiba_install_*.c) and
#     kibaos_oobe_backend_main.c is the orchestrator tying it together.
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

    // tiny inline translator — t("English", "Türkçe") right at each call
    // site instead of a separate lookup table, so a string and its
    // translation stay glued together in the source instead of drifting
    // apart in two different files.
    private string t (string en, string tr, string pl) {
        return ui_lang == "tr" ? tr : ui_lang == "pl" ? pl : en;
    }

    // ── Dark mode ─────────────────────────────────────────────────────
    private bool is_dark = true;

    private void apply_dark_mode () {
        if (is_dark) window.add_css_class ("dark");
        else window.remove_css_class ("dark");
    }

    // ── VM detection ──────────────────────────────────────────────────
    // No longer used to block installation (VDI/VMDK/qcow2 handling has
    // been solid enough in practice that the original blanket refusal
    // wasn't buying anything except friction for people testing/running
    // KibaOS in a VM) -- still used below for OEM-mode detection, since
    // a VM's virtual disk can spuriously look like "already on the
    // computer" the same way a real OEM-preloaded disk does, and we
    // don't want that misfiring in a test VM.
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
            decorated      = false,
            resizable      = false,
            title          = in_vm ? "KibaOS Setup"
                             : is_oem_mode ? "Finish Setting Up KibaOS" : "KibaOS Setup"
        };
        window.add_css_class ("kibaos-oobe-window");
        // No decorations means no close button already, but Alt+F4/compositor
        // shortcuts can still fire a close request -- OOBE isn't something
        // you dismiss out from under yourself mid-install, same as Windows'
        // setup flow never gives you a way out either. Block it outright.
        window.close_request.connect (() => { return true; });
        // Belt-and-suspenders: if a compositor keybinding (or anything else)
        // ever drops fullscreen out from under us, snap straight back into
        // it instead of leaving OOBE sitting in a windowed state.
        window.notify["fullscreened"].connect (() => {
            if (!window.fullscreened) window.fullscreen ();
        });
        // Default to dark mode; the toggle on every page still lets the
        // user switch to light from there.
        Adw.StyleManager.get_default ().color_scheme = Adw.ColorScheme.FORCE_DARK;
        is_dark = true;
        apply_dark_mode ();
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
            width_request = 640
        };
        card.add_css_class ("oobe-card");

        // ── Step-dots (shown when step_total > 1) ──────────────────────
        if (step_total > 1) {
            var dots_row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6) {
                halign = Gtk.Align.CENTER,
                margin_bottom = 10
            };
            for (int i = 0; i < step_total; i++) {
                var dot = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0) {};
                dot.add_css_class ("oobe-step-dot");
                if (i == step_index) dot.add_css_class ("oobe-step-dot-active");
                dots_row.append (dot);
            }
            card.append (dots_row);

            var step_label = new Gtk.Label (
                t ("Step %d of %d", "Adım %d / %d", "Krok %d z %d")
                    .printf (step_index + 1, step_total)) {
                halign = Gtk.Align.CENTER,
                margin_bottom = 16
            };
            step_label.add_css_class ("oobe-step-label");
            card.append (step_label);
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
            var back_btn = new Gtk.Button.with_label (t ("Back", "Geri", "Wstecz"));
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

        var lang_btn = new Gtk.Button.with_label (
            ui_lang == "en" ? "TR" : ui_lang == "tr" ? "PL" : "EN");
        lang_btn.add_css_class ("oobe-corner-button");
        // Tooltip is always phrased in the CURRENT language, naming the NEXT
        // one in the cycle (en -> tr -> pl -> en) -- matches the original
        // en/tr behaviour, just extended to a third stop.
        lang_btn.tooltip_text = ui_lang == "en" ? "Switch to Turkish"
                               : ui_lang == "tr" ? "Lehçeye geç"
                               : "Przełącz na angielski";
        lang_btn.clicked.connect (() => {
            ui_lang = ui_lang == "en" ? "tr" : ui_lang == "tr" ? "pl" : "en";
            refresh_current_page ();
        });
        corner.append (lang_btn);

        var dark_btn = new Gtk.Button.with_label (
            is_dark ? t ("Light", "Açık", "Jasny") : t ("Dark", "Koyu", "Ciemny"));
        dark_btn.add_css_class ("oobe-corner-button");
        dark_btn.tooltip_text = is_dark
            ? t ("Switch to light mode", "Açık moda geç", "Przełącz na jasny motyw")
            : t ("Switch to dark mode", "Koyu moda geç", "Przełącz na ciemny motyw");
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
        var content = new Gtk.Box (Gtk.Orientation.VERTICAL, 20) {
            halign = Gtk.Align.CENTER
        };

        // Logo — centered above the greeting, Apple's own "Hello" screen
        // skips a brand mark entirely and lets the greeting carry the
        // whole moment, but KibaOS keeps a small centered one here since
        // the persistent corner wordmark is easy to miss on a first boot.
        var logo = new Gtk.Image.from_file ("/usr/share/kibaos/installer-logo.png") {
            pixel_size = 64,
            halign     = Gtk.Align.CENTER
        };
        content.append (logo);

        // The greeting itself -- plain system font, same treatment as
        // every other page title. HIG is explicit that custom/script
        // faces are for branding moments or "an immersive gaming
        // experience," not a plain OS installer -- one typeface used
        // consistently reads calmer and more native than a flourish here.
        var greeting = new Gtk.Label (
            t ("Welcome", "Hoş geldiniz", "Witamy")) {
            halign = Gtk.Align.CENTER,
            justify = Gtk.Justification.CENTER
        };
        greeting.add_css_class ("oobe-welcome-greeting");
        content.append (greeting);

        var subtitle = new Gtk.Label (
            t ("Let's get your system set up. This should only take a few minutes.",
               "Sisteminizi kuralım. Bu işlem yalnızca birkaç dakika sürecek.",
               "Skonfigurujmy Twój system. To zajmie tylko kilka minut.")) {
            halign = Gtk.Align.CENTER,
            justify = Gtk.Justification.CENTER,
            margin_top = 4
        };
        subtitle.add_css_class ("oobe-subtitle");
        content.append (subtitle);

        var nav_row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 10) {
            halign = Gtk.Align.CENTER,
            margin_top = 24
        };
        var try_btn = new Gtk.Button.with_label (t ("Try KibaOS", "KibaOS'u Dene", "Wypróbuj KibaOS"));
        try_btn.add_css_class ("oobe-secondary-button");
        try_btn.tooltip_text = t ("Explore the live desktop without installing anything yet.",
            "Henüz hiçbir şey kurmadan canlı masaüstünü keşfedin.",
            "Poznaj system na żywo, nie instalując jeszcze niczego.");
        try_btn.clicked.connect (() => { this.quit (); });
        nav_row.append (try_btn);
        content.append (nav_row);

        return make_page ("Welcome", content, t ("Get Started", "Başla", "Rozpocznij"), () => {
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
            t ("Connect to Wi-Fi", "Wi-Fi'ye Bağlan", "Połącz z Wi-Fi"),
            t ("Choose a network to continue. You can also skip this step.",
               "Devam etmek için bir ağ seçin. Bu adımı atlayabilirsiniz de.",
               "Wybierz sieć, aby kontynuować. Możesz też pominąć ten krok.")));

        // Status label shown below the list ("Connecting…", "Connected ✓", errors)
        var status_label = new Gtk.Label ("") {
            halign = Gtk.Align.CENTER,
            wrap   = true
        };
        status_label.add_css_class ("oobe-subtitle");

        // Network is now required (codec install during finalize needs it,
        // and skipping used to leave people on a system with no way to
        // reach the mirrors afterward either). Next just refuses to
        // navigate until this is true -- either flipped by
        // do_connect_async below, or here already if wired/some other
        // connection is already up (don't force a Wi-Fi-specific flow on
        // someone plugged into Ethernet).
        bool[] connected_box = { false };
        try {
            string state_out = "";
            GLib.Process.spawn_command_line_sync (
                "nmcli -t -f STATE general status", out state_out);
            if (state_out.strip () == "connected") {
                connected_box[0] = true;
                status_label.label = t ("Already connected ✓", "Zaten bağlı ✓", "Już połączono ✓");
            }
        } catch (GLib.SpawnError e) {}

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
        // set_data on widgets without GObject subclassing tricks. Boxed
        // (double-array) so refresh_networks() below can reassign the
        // contents and have row_activated's closure (created once, further
        // down) see the updated values on every rescan -- reassigning a
        // plain unboxed local wouldn't be visible from a closure created
        // before the reassignment.
        // NOTE: `string[][] x = { {} };` is NOT valid Vala -- "stacked
        // array" literals like that aren't supported by the compiler
        // (confirmed: valac 0.56.19 rejects it outright). Gee.ArrayList
        // gives the same "closures see later mutations" property since
        // it's a reference type -- refresh_networks() below just
        // clear()/add()s into the same list object instead of reassigning
        // a boxed array slot.
        var ssid_box    = new Gee.ArrayList<string> ();
        var secured_box = new Gee.ArrayList<bool> ();

        // Set while a password dialog is open or a connection attempt is
        // in flight, so the periodic rescan below doesn't yank the row
        // list out from under someone mid-pick or mid-typing.
        bool[] scan_paused_box = { false };

        // Pulled out into its own function so the periodic timer further
        // down can just call this again instead of duplicating the whole
        // scan-and-render pass. Safe to call repeatedly: it fully rebuilds
        // list_box's rows and ssid_box/secured_box each time rather than
        // diffing, which is fine at Wi-Fi-scan-list sizes.
        void refresh_networks () {
            if (scan_paused_box[0]) return;

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

            // Clear whatever's there from the previous pass before
            // repopulating -- including the "No networks found" placeholder
            // row, if that's what's currently shown.
            Gtk.Widget? child = list_box.get_first_child ();
            while (child != null) {
                var next = child.get_next_sibling ();
                list_box.remove (child);
                child = next;
            }
            ssid_box.clear ();
            secured_box.clear ();

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

                // Choose a text signal-bar glyph based on nmcli's 0-100 signal
                // percentage, instead of an icon-theme lookup.
                string signal_bars;
                if      (pct >= 80) signal_bars = "▂▄▆█";
                else if (pct >= 55) signal_bars = "▂▄▆";
                else if (pct >= 30) signal_bars = "▂▄";
                else                signal_bars = "▂";

                var row = new Adw.ActionRow () {
                    title         = ssid,
                    subtitle      = "%s\n%s".printf (signal_pct,
                                        secured
                                            ? t ("Secured", "Güvenli", "Zabezpieczona")
                                            : t ("Open", "Açık", "Otwarta")),
                    subtitle_lines = 2,
                    activatable   = true
                };
                row.add_prefix (new Gtk.Label (signal_bars) { css_classes = { "oobe-signal-glyph" } });
                list_box.append (row);

                ssid_box.add (ssid);
                secured_box.add (secured);
                any = true;
            }
            if (!any) {
                var row = new Adw.ActionRow () {
                    title = t ("No networks found nearby", "Yakında ağ bulunamadı", "Nie znaleziono pobliskich sieci")
                };
                list_box.append (row);
            }
        }

        refresh_networks ();

        content.append (list_box);
        content.append (status_label);

        // Periodic rescan so networks that come into/out of range while
        // this page is up actually show up, instead of only ever
        // reflecting a single scan taken the instant the page was built.
        // Torn down via list_box.destroy so it stops firing (and touching
        // a dead widget) once the user navigates past this page.
        uint[] refresh_timer_box = { 0 };
        refresh_timer_box[0] = GLib.Timeout.add_seconds (5, () => {
            refresh_networks ();
            return GLib.Source.CONTINUE;
        });
        list_box.destroy.connect (() => {
            if (refresh_timer_box[0] != 0) {
                GLib.Source.remove (refresh_timer_box[0]);
                refresh_timer_box[0] = 0;
            }
        });

        // ── Row activation: password dialog → nmcli connect ──────────────
        // Captures: dev_box, ssid_box, secured_box, status_label, window,
        // scan_paused_box
        list_box.row_activated.connect ((row) => {
            int idx = row.get_index ();
            if (idx < 0 || idx >= ssid_box.size) return;

            string ssid    = ssid_box[idx];
            bool   secured = secured_box[idx];

            if (secured) {
                // ── Password dialog ───────────────────────────────────────
                // Pause the 5s rescan for as long as this dialog (or the
                // resulting connect attempt) is live -- a scan mid-typing
                // would rebuild list_box's rows out from under the user.
                scan_paused_box[0] = true;

                var dialog = new Adw.MessageDialog (window,
                    t ("Enter Wi-Fi Password", "Wi-Fi Şifresini Girin", "Wprowadź hasło Wi-Fi"),
                    t ("""Enter the password for "%s".""",
                       """"%s" ağının şifresini girin.""",
                       "Wprowadź hasło dla „%s”.").printf (ssid));

                var pw_entry = new Gtk.PasswordEntry () {
                    show_peek_icon = true,
                    placeholder_text = t ("Password", "Şifre", "Hasło")
                };
                pw_entry.add_css_class ("oobe-entry");
                dialog.set_extra_child (pw_entry);

                dialog.add_response ("cancel", t ("Cancel", "İptal", "Anuluj"));
                dialog.add_response ("connect", t ("Connect", "Bağlan", "Połącz"));
                dialog.set_response_appearance ("connect", Adw.ResponseAppearance.SUGGESTED);
                dialog.set_default_response ("connect");
                dialog.set_close_response ("cancel");

                // Allow pressing Enter in the password field to confirm
                pw_entry.activate.connect (() => {
                    dialog.response ("connect");
                });

                dialog.response.connect ((resp) => {
                    if (resp != "connect") { dialog.destroy (); scan_paused_box[0] = false; return; }
                    string password = pw_entry.get_text ();
                    dialog.destroy ();

                    if (password == "") {
                        status_label.remove_css_class ("oobe-subtitle");
                        status_label.add_css_class ("oobe-error");
                        status_label.label = t ("Password cannot be empty.",
                                                 "Şifre boş olamaz.",
                                                 "Hasło nie może być puste.");
                        scan_paused_box[0] = false;
                        return;
                    }

                    status_label.remove_css_class ("oobe-error");
                    status_label.add_css_class ("oobe-subtitle");
                    status_label.label = t ("Connecting to %s…", "%s ağına bağlanıyor…", "Łączenie z %s…").printf (ssid);
                    do_connect_async (dev_box[0], ssid, password, status_label, connected_box);
                });

                dialog.present ();

            } else {
                // ── Open network — connect directly ───────────────────────
                scan_paused_box[0] = true;
                status_label.label = t ("Connecting to %s…", "%s ağına bağlanıyor…", "Łączenie z %s…").printf (ssid);
                do_connect_async (dev_box[0], ssid, null, status_label, connected_box);
            }
        });

        return make_page ("Wi-Fi", content, t ("Next", "İleri", "Dalej"), () => {
            if (!connected_box[0]) {
                status_label.remove_css_class ("oobe-subtitle");
                status_label.add_css_class ("oobe-error");
                status_label.label = t ("Connect to a network to continue -- KibaOS needs it to fetch media codecs during install.",
                                         "Devam etmek için bir ağa bağlanın -- KibaOS, kurulum sırasında medya kodeklerini almak için buna ihtiyaç duyar.",
                                         "Połącz się z siecią, aby kontynuować -- KibaOS potrzebuje jej do pobrania kodeków multimedialnych podczas instalacji.");
                return;
            }
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
                                    Gtk.Label status_label,
                                    bool[] connected_box) {
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
                    lbl.label = t ("Could not connect: %s", "Bağlanılamadı: %s", "Nie udało się połączyć: %s").printf (err_f);
                    return GLib.Source.REMOVE;
                }
                // Start polling for association on the main thread
                lbl.remove_css_class ("oobe-error");
                lbl.add_css_class ("oobe-subtitle");
                lbl.label = t ("Verifying connection…", "Bağlantı doğrulanıyor…", "Weryfikowanie połączenia…");
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
                        lbl.label = t ("Connected to %s ✓", "%s ağına bağlanıldı ✓", "Połączono z %s ✓").printf (ssid_copy);
                        connected_box[0] = true;
                        return GLib.Source.REMOVE;
                    }
                    if (attempts[0] >= 30) {   // 30 × 500 ms = 15 s
                        lbl.remove_css_class ("oobe-subtitle");
                        lbl.add_css_class ("oobe-error");
                        lbl.label = t ("Timed out — check the password and try again.",
                                        "Zaman aşımı — şifreyi kontrol edip tekrar deneyin.",
                                        "Przekroczono czas oczekiwania — sprawdź hasło i spróbuj ponownie.");
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
            t ("Language & Keyboard", "Dil ve Klavye", "Język i klawiatura"),
            t ("Choose how KibaOS should communicate with you.",
               "KibaOS'un sizinle nasıl iletişim kuracağını seçin.",
               "Wybierz, w jaki sposób KibaOS ma się z Tobą komunikować.")));

        var locale_row = new Adw.ComboRow () { title = t ("Language", "Dil", "Język") };
        var locale_model = new Gtk.StringList (null);
        // Display names shown in the picker; `locales` holds the actual
        // locale strings the installed system will use, in the same order.
        string[] locale_labels = {
            "English (US)", "English (UK)", "Deutsch", "Français",
            "Español", "日本語", "中文（简体）", "Türkçe", "Polski"
        };
        string[] locales = {
            "en_US.UTF-8", "en_GB.UTF-8", "de_DE.UTF-8",
            "fr_FR.UTF-8", "es_ES.UTF-8", "ja_JP.UTF-8", "zh_CN.UTF-8",
            "tr_TR.UTF-8", "pl_PL.UTF-8"
        };
        foreach (var l in locale_labels) locale_model.append (l);
        locale_row.set_model (locale_model);
        locale_row.notify["selected"].connect (() => {
            selected_locale = locales[locale_row.get_selected ()];
        });
        content.append (locale_row);

        var keymap_row = new Adw.ComboRow () { title = t ("Keyboard layout", "Klavye düzeni", "Układ klawiatury") };
        var keymap_model = new Gtk.StringList (null);
        string[] keymap_labels = {
            "English (US)", "English (UK)", "Deutsch", "Français",
            "Español", "日本語", "Dvorak", "Türkçe (Q)", "Polski"
        };
        string[] keymaps = { "us", "uk", "de", "fr", "es", "jp106", "dvorak", "trq", "pl" };
        foreach (var k in keymap_labels) keymap_model.append (k);
        keymap_row.set_model (keymap_model);
        keymap_row.notify["selected"].connect (() => {
            selected_keymap = keymaps[keymap_row.get_selected ()];
        });
        content.append (keymap_row);

        return make_page ("Language", content, t ("Next", "İleri", "Dalej"), () => {
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
            opt.label   = t ("Your computer's storage (%s)", "Bilgisayarınızın deposu (%s)", "Pamięć Twojego komputera (%s)").printf (
                label == "" ? t ("internal drive", "dahili disk", "dysk wewnętrzny") : label);
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
            t ("Where should KibaOS go?", "KibaOS nereye kurulsun?", "Gdzie zainstalować KibaOS?"),
            t ("Your computer has more than one drive. Pick the one to set up.",
               "Bilgisayarınızda birden fazla disk var. Kurulacak olanı seçin.",
               "Twój komputer ma więcej niż jeden dysk. Wybierz ten, na którym chcesz zainstalować system.")));

        var picker = new Gtk.ListBox ();
        picker.add_css_class ("oobe-list");
        picker.selection_mode = Gtk.SelectionMode.SINGLE;

        foreach (var opt in options) {
            var row = new Adw.ActionRow () { title = opt.label };
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

        return make_page ("Storage", content, t ("Next", "İleri", "Dalej"), () => {
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
            t ("How should KibaOS be installed?", "KibaOS nasıl kurulsun?", "Jak zainstalować KibaOS?"),
            t ("We found an existing operating system on this drive.",
               "Bu diskte mevcut bir işletim sistemi bulduk.",
               "Znaleźliśmy na tym dysku istniejący system operacyjny.")));

        var picker = new Gtk.ListBox ();
        picker.add_css_class ("oobe-list");
        picker.selection_mode = Gtk.SelectionMode.SINGLE;

        var erase_row = new Adw.ActionRow () {
            title    = t ("Erase disk", "Diski sil", "Wyczyść dysk"),
            subtitle = t ("Delete everything on this drive and install KibaOS by itself.",
                           "Bu diskteki her şeyi silip yalnızca KibaOS'u kurun.",
                           "Usuń wszystko z tego dysku i zainstaluj wyłącznie KibaOS.")
        };
        erase_row.set_data ("mode", "erase");
        picker.append (erase_row);

        var alongside_row = new Adw.ActionRow () {
            title    = t ("Install alongside", "Yanına kur", "Zainstaluj obok"),
            subtitle = t ("Keep what's already here and set up KibaOS in the free space next to it (dual boot).",
                           "Mevcut sistemi koru, KibaOS'u yanındaki boş alana kur (çift önyükleme).",
                           "Zachowaj to, co już tu jest, i zainstaluj KibaOS w wolnym miejscu obok (dual boot).")
        };
        alongside_row.set_data ("mode", "alongside");
        picker.append (alongside_row);

        picker.row_selected.connect ((row) => {
            if (row != null) install_mode = row.get_data<string> ("mode");
        });
        install_mode = "erase";
        picker.select_row (picker.get_row_at_index (0));
        content.append (picker);

        return make_page ("Install Mode", content, t ("Next", "İleri", "Dalej"), () => {
            nav_view.push (build_account_page ());
        }, false, 3, 6);
    }

    // ══════════════════════════════════════════════════════════════════
    // Page 5: Account creation
    // ══════════════════════════════════════════════════════════════════
    private Adw.NavigationPage build_account_page () {
        var content = new Gtk.Box (Gtk.Orientation.VERTICAL, 16);
        content.append (oobe_heading (
            t ("Create Your Account", "Hesabınızı Oluşturun", "Utwórz swoje konto"),
            t ("This is the account you'll use every day.",
               "Bu, her gün kullanacağınız hesap.",
               "To konto, którego będziesz używać na co dzień.")));

        var group = new Adw.PreferencesGroup ();
        group.add_css_class ("oobe-prefs-group");
        // "overflow: hidden" in oobe.css doesn't do anything -- GTK4's CSS
        // engine doesn't have that property, confirmed by the theme parser
        // warning it throws on startup. Clipping child rows to the
        // rounded-corner container is a widget property, not CSS.
        group.overflow = Gtk.Overflow.HIDDEN;

        var hostname_entry = new Adw.EntryRow () { title = t ("Computer name", "Bilgisayar adı", "Nazwa komputera") };
        hostname_entry.text = "kibaos";
        hostname_entry.changed.connect (() => { hostname_value = hostname_entry.text; });
        group.add (hostname_entry);

        var user_entry = new Adw.EntryRow () { title = t ("Username", "Kullanıcı adı", "Nazwa użytkownika") };
        user_entry.changed.connect (() => { username_value = user_entry.text; });
        group.add (user_entry);

        var pass_entry = new Adw.PasswordEntryRow () { title = t ("Password", "Şifre", "Hasło") };
        pass_entry.changed.connect (() => { password_value = pass_entry.text; });
        group.add (pass_entry);

        content.append (group);

        // No WinApps toggle here -- it's a listed, always-on feature (see
        // WINDOWS APP SUPPORT section), not opt-in. Both backends always
        // drop /etc/kibaos/winapps-pending unconditionally on finish.

        return make_page ("Account", content,
            is_oem_mode ? t ("Finish Setup", "Kurulumu Bitir", "Zakończ konfigurację") : t ("Next", "İleri", "Dalej"), () => {
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
            t ("Ready to Set Up KibaOS", "KibaOS Kurulumuna Hazır", "Gotowy do instalacji KibaOS"),
            install_mode == "alongside"
                ? t ("KibaOS will be installed next to your existing operating system, " +
                     "using the free space on this drive. Nothing else will be touched.",
                     "KibaOS, mevcut işletim sisteminizin yanına, bu diskteki boş alan " +
                     "kullanılarak kurulacak. Başka hiçbir şeye dokunulmayacak.",
                     "KibaOS zostanie zainstalowany obok Twojego obecnego systemu operacyjnego, wykorzystując wolne miejsce na tym dysku. Nic innego nie zostanie zmienione.")
                : t ("Everything on your computer will be replaced. " +
                     "Make sure anything important is backed up first.",
                     "Bilgisayarınızdaki her şeyin yerine yenisi kurulacak. " +
                     "Önemli olan her şeyi önceden yedeklediğinizden emin olun.",
                     "Wszystko na Twoim komputerze zostanie zastąpione. Upewnij się wcześniej, że wszystkie ważne dane masz zapisane w kopii zapasowej.")));

        // Summary card
        var summary = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        summary.add_css_class ("oobe-summary-box");
        summary.overflow = Gtk.Overflow.HIDDEN;

        OobeSummaryItem[] items = {
            { t ("Storage", "Depolama", "Pamięć"),
              selected_disk == "" ? t ("Auto-detected", "Otomatik algılandı", "Wykryto automatycznie") : GLib.Path.get_basename (selected_disk) },
            { t ("Install mode", "Kurulum modu", "Tryb instalacji"),
              install_mode == "alongside" ? t ("Install alongside (dual boot)", "Yanına kur (çift önyükleme)", "Zainstaluj obok (dual boot)") : t ("Erase disk", "Diski sil", "Wyczyść dysk") },
            { t ("Language", "Dil", "Język"), selected_locale },
            { t ("Keyboard", "Klavye", "Klawiatura"), selected_keymap },
            { t ("Account", "Hesap", "Konto"),
              username_value == "" ? t ("(not set)", "(ayarlanmadı)", "(nie ustawiono)") : username_value }
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

        return make_page ("Confirm", content, t ("Install KibaOS", "KibaOS'u Kur", "Zainstaluj KibaOS"), () => {
            nav_view.push (build_installing_page ());
            start_install ();
        }, false, 5, 6);
    }

    // ══════════════════════════════════════════════════════════════════
    // Page 7: Installing
    // ══════════════════════════════════════════════════════════════════
    private Gtk.Label      progress_label;
    private Gtk.ProgressBar progress_bar;
    private Gtk.Stack      feature_stack;
    private uint            feature_timer_id = 0;

    private Adw.NavigationPage build_installing_page () {
        var content = new Gtk.Box (Gtk.Orientation.VERTICAL, 20);
        content.append (oobe_heading (
            t ("Installing KibaOS", "KibaOS Kuruluyor", "Instalowanie KibaOS"),
            t ("Sit tight — this won't take long.", "Biraz bekleyin — çok sürmeyecek.", "Chwila cierpliwości — to nie potrwa długo.")));

        progress_bar = new Gtk.ProgressBar () { show_text = false };
        progress_bar.add_css_class ("oobe-progress");
        content.append (progress_bar);

        progress_label = new Gtk.Label (t ("Preparing…", "Hazırlanıyor…", "Przygotowywanie…"));
        progress_label.add_css_class ("oobe-subtitle");
        content.append (progress_label);

        // Feature slideshow -- something to actually read while the real
        // progress line above is stuck on one status for a while (e.g.
        // "Copying files…" during the unsquashfs step, which takes a lot
        // longer than everything else combined and gives no finer-grained
        // updates). Cycles independently of install progress; the two
        // labels aren't tied together.
        string[,] features = {
            { t ("Your computer learns how you use it", "Bilgisayarınız sizi nasıl kullandığınızı öğrenir", "Twój komputer uczy się, jak go używasz"),
              t ("KibaOS quietly notices your habits and adjusts things to fit — everything stays on your computer.",
                 "KibaOS alışkanlıklarınızı sessizce fark eder ve buna göre ayarlar yapar — her şey bilgisayarınızda kalır.",
                 "KibaOS po cichu zauważa Twoje nawyki i odpowiednio się dostosowuje — wszystko zostaje na Twoim komputerze.") },
            { t ("Built just for this installer", "Sadece bu kurulum için yapıldı", "Zbudowany specjalnie dla tego instalatora"),
              t ("This setup screen was made specifically for KibaOS, not borrowed from another system.",
                 "Bu kurulum ekranı özellikle KibaOS için yapıldı, başka bir sistemden alınmadı.",
                 "Ten ekran instalacji został stworzony specjalnie dla KibaOS, a nie zapożyczony z innego systemu.") },
            { t ("Starts up fast", "Hızlı açılır", "Szybko się uruchamia"),
              t ("KibaOS uses your computer's modern startup process, which gets you to the desktop quicker.",
                 "KibaOS, bilgisayarınızın modern açılış sürecini kullanır ve bu sayede masaüstüne daha hızlı ulaşırsınız.",
                 "KibaOS korzysta z nowoczesnego procesu uruchamiania komputera, dzięki czemu szybciej trafiasz na pulpit.") },
            { t ("Fixes small problems on its own", "Küçük sorunları kendi kendine çözer", "Samodzielnie naprawia drobne problemy"),
              t ("If something starts acting up, KibaOS notices and tries to repair it automatically.",
                 "Bir şey tuhaf davranmaya başlarsa, KibaOS bunu fark eder ve otomatik olarak onarmaya çalışır.",
                 "Jeśli coś zacznie działać nieprawidłowo, KibaOS to zauważy i spróbuje to automatycznie naprawić.") },
            { t ("Ready to play your videos and music", "Videolarınızı ve müziklerinizi oynatmaya hazır", "Gotowy do odtwarzania Twoich filmów i muzyki"),
              t ("A video player and everything it needs are already installed — nothing extra to download.",
                 "Bir video oynatıcı ve ihtiyaç duyduğu her şey zaten kurulu — indirmeniz gereken ekstra bir şey yok.",
                 "Odtwarzacz wideo i wszystko, czego potrzebuje, jest już zainstalowane — nie trzeba niczego dodatkowo pobierać.") }
        };

        feature_stack = new Gtk.Stack () {
            transition_type = Gtk.StackTransitionType.CROSSFADE,
            transition_duration = 420,
            margin_top = 40,
            halign = Gtk.Align.CENTER
        };
        feature_stack.add_css_class ("oobe-feature-stack");
        for (int i = 0; i < features.length[0]; i++) {
            var pane = new Gtk.Box (Gtk.Orientation.VERTICAL, 6) { halign = Gtk.Align.CENTER };
            var f_title = new Gtk.Label (features[i, 0]) { halign = Gtk.Align.CENTER, justify = Gtk.Justification.CENTER };
            f_title.add_css_class ("oobe-feature-title");
            var f_body = new Gtk.Label (features[i, 1]) {
                halign = Gtk.Align.CENTER, justify = Gtk.Justification.CENTER, wrap = true, max_width_chars = 46
            };
            f_body.add_css_class ("oobe-feature-body");
            pane.append (f_title);
            pane.append (f_body);
            feature_stack.add_named (pane, i.to_string ());
        }
        feature_stack.visible_child_name = "0";
        content.append (feature_stack);

        int feature_index = 0;
        int feature_count = features.length[0];
        feature_timer_id = GLib.Timeout.add_seconds (5, () => {
            feature_index = (feature_index + 1) % feature_count;
            feature_stack.visible_child_name = feature_index.to_string ();
            return GLib.Source.CONTINUE;
        });

        return make_page ("Installing", content, null, null, true);
    }

    // Stops the feature-slideshow timer -- called once install finishes
    // (success or failure) so it doesn't keep firing against a stack that
    // no longer has a reason to update once this page is behind us.
    private void stop_feature_slideshow () {
        if (feature_timer_id != 0) {
            GLib.Source.remove (feature_timer_id);
            feature_timer_id = 0;
        }
    }

    // ══════════════════════════════════════════════════════════════════
    // Page 8: Done
    // ══════════════════════════════════════════════════════════════════
    private Adw.NavigationPage build_done_page () {
        var content = new Gtk.Box (Gtk.Orientation.VERTICAL, 20);

        var check = new Gtk.Label ("✓") {
            halign = Gtk.Align.START
        };
        check.add_css_class ("oobe-done-check");
        content.append (check);

        content.append (oobe_heading (
            t ("You're all set.", "Her şey hazır.", "Wszystko gotowe."),
            t ("KibaOS is installed and ready. Restart your computer to get started.",
               "KibaOS kuruldu ve hazır. Başlamak için bilgisayarınızı yeniden başlatın.",
               "KibaOS został zainstalowany i jest gotowy. Uruchom ponownie komputer, aby rozpocząć.")));

        return make_page ("Done", content, t ("Restart Now", "Şimdi Yeniden Başlat", "Uruchom ponownie teraz"), () => {
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
        // Disk partitioning/formatting, base extraction, and bootloader
        // install all go through libkibadisk (sgdisk-subprocess-backed GPT
        // writer) in kibaos-oobe-backend directly -- no archinstall detour.
        string[] argv = {
            "sudo", "/usr/local/bin/kibaos-oobe-backend",
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
            progress_label.label = t ("Failed to start: %s", "Başlatılamadı: %s", "Nie udało się uruchomić: %s").printf (e.message);
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
            stop_feature_slideshow ();
            if (proc.get_exit_status () == 0) {
                nav_view.push (build_done_page ());
            } else if (last_fatal_message != "") {
                progress_label.label = last_fatal_message +
                    t ("\n(Full log: /var/log/kibaos-oobe.log)",
                       "\n(Tam günlük: /var/log/kibaos-oobe.log)",
                       "\\n(Pełny dziennik: /var/log/kibaos-oobe.log)");
            } else {
                progress_label.label = t (
                    "Something went wrong. Check /var/log/kibaos-oobe.log for details.",
                    "Bir şeyler ters gitti. Ayrıntılar için /var/log/kibaos-oobe.log dosyasına bakın.",
                    "Coś poszło nie tak. Szczegóły znajdziesz w /var/log/kibaos-oobe.log.");
            }
        } catch (GLib.Error e) {
            stop_feature_slideshow ();
            progress_label.label = t ("Lost connection to installer: %s",
                                       "Kurulum programıyla bağlantı kesildi: %s",
                                       "Utracono połączenie z instalatorem: %s").printf (e.message);
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
    background: #ffffff;
    transition: background 260ms cubic-bezier(0.22, 1, 0.36, 1);
}
window.dark .oobe-background {
    background: #12161d;
}

/* ── Brand wordmark ────────────────────────────────────────────────────── */
.oobe-brand {
    font-size: 15px;
    font-weight: 700;
    letter-spacing: 0.5px;
    color: rgba(15,23,42,0.80);
}

/* ── Corner controls (language / dark-mode toggle) ───────────────────────── */
.oobe-corner-button {
    background:    rgba(15,23,42,0.05);
    color:         #334155;
    border:        1px solid rgba(15,23,42,0.10);
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
.oobe-corner-button:hover  { background: rgba(15,23,42,0.09); transform: translateY(-1px); }
.oobe-corner-button:active { transform: translateY(0); transition-duration: 70ms; }
window.dark .oobe-corner-button {
    background: rgba(30,41,59,0.65);
    color:      #e2e8f0;
    border-color: rgba(255,255,255,0.12);
}
window.dark .oobe-corner-button:hover { background: rgba(51,65,85,0.85); }

/* ── Card ──────────────────────────────────────────────────────────────── */
/* Windows' OOBE puts content straight on the full-bleed background with no
 * visible container at all -- no border, no shadow, no card edge to notice.
 * That's deliberate: one less visual boundary for the eye to register while
 * reading a screen you'll only ever see once. Acrylic/card-style framing
 * stays reserved for genuinely transient surfaces (the Wi-Fi password
 * dialog, which already uses Adw.MessageDialog rather than this class). */
.oobe-card {
    background:    transparent;
    border:        none;
    box-shadow:    none;
    animation: card-in 460ms cubic-bezier(0.22, 1, 0.36, 1) both;
}
window.dark .oobe-card {
    background:    transparent;
    border:        none;
    box-shadow:    none;
}

@keyframes card-in {
    from { opacity: 0; transform: translateY(14px); }
    to   { opacity: 1; transform: translateY(0);    }
}

/* Inner padding -- extra room now that there's no card edge doing any of
 * the visual separation work; whitespace is the boundary instead. */
.oobe-inner {
    padding: 8px 12px 12px;
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
    background: #0071e3;
}
window.dark .oobe-step-dot { background: rgba(255,255,255,0.18); }
window.dark .oobe-step-dot-active { background: #409cff; }

/* ── Nav row ───────────────────────────────────────────────────────────── */
.oobe-nav-row { margin-top: 4px; }

/* ── Typography ────────────────────────────────────────────────────────── */
/* Welcome-page greeting -- same system font as everything else, just set
 * large. No script/cursive face: HIG reserves custom typefaces for
 * branding or "an immersive gaming experience," and a plain OS installer
 * is neither -- one consistent typeface reads calmer and more native. */
.oobe-welcome-greeting {
    font-size:      44px;
    font-weight:    650;
    color:          #1d1d1f;
    letter-spacing: -0.4px;
    margin-top:     4px;
    animation: fade-up 460ms cubic-bezier(0.22, 1, 0.36, 1) both;
}
window.dark .oobe-welcome-greeting { color: #f1f5f9; }

.oobe-title {
    font-size:      30px;
    font-weight:    650;
    color:          #0f172a;
    letter-spacing: -0.4px;
    line-height:    1.25;
    margin-bottom:  4px;
    animation: fade-up 380ms cubic-bezier(0.22, 1, 0.36, 1) 60ms both;
}
.oobe-subtitle {
    font-size:   16px;
    color:       #64748b;
    line-height: 1.6;
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
 * .oobe-subtitle so an error doesn't read as just another status update.
 * Deliberately no shake/motion here: a startling animation adds stress
 * right when someone's already hit a snag, a steady color change says
 * the same thing calmly. */
.oobe-error {
    font-size:   16px;
    color:       #dc2626;
    line-height: 1.6;
    animation:   fade-up 220ms cubic-bezier(0.22, 1, 0.36, 1) both;
}
window.dark .oobe-error { color: #f87171; }

/* ── Step counter (text alongside the dots) ──────────────────────────────
 * "Step 3 of 6" removes any guesswork about how much is left -- knowing
 * where you are and how far there is to go is one of the cheapest ways to
 * lower anxiety in a multi-step flow you can't preview ahead of time. */
.oobe-step-label {
    font-size: 13px;
    font-weight: 600;
    color: rgba(0,0,0,0.38);
    letter-spacing: 0.2px;
}
window.dark .oobe-step-label { color: rgba(255,255,255,0.40); }

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

.oobe-signal-glyph {
    font-family: monospace;
    font-size: 15px;
    font-weight: 700;
    color: #0071e3;
    min-width: 34px;
}
window.dark .oobe-signal-glyph { color: #409cff; }

.oobe-list row,
listview > row {
    background:    rgba(248,250,252,0.9);
    border:        1px solid rgba(0,0,0,0.07);
    border-radius: 18px;
    margin:        4px 0;
    padding:       14px 16px;
    color:         #1e293b;
    transition:
        background-color 180ms cubic-bezier(0.22, 1, 0.36, 1),
        border-color     180ms cubic-bezier(0.22, 1, 0.36, 1),
        box-shadow       180ms cubic-bezier(0.22, 1, 0.36, 1),
        transform        180ms cubic-bezier(0.22, 1, 0.36, 1);
    animation: fade-up 260ms cubic-bezier(0.22, 1, 0.36, 1) both;
}
.oobe-list row:hover { background: #f0f9ff; border-color: rgba(0,113,227,0.28); transform: translateX(2px); }
.oobe-list row:selected {
    background: rgba(0,113,227,0.10);
    border-color: rgba(0,113,227,0.55);
    box-shadow: 0 0 0 3px rgba(0,113,227,0.14);
}
window.dark .oobe-list row,
window.dark listview > row {
    background: rgba(30,41,59,0.55);
    border-color: rgba(255,255,255,0.08);
    color: #e2e8f0;
}
window.dark .oobe-list row:hover { background: rgba(0,113,227,0.16); border-color: rgba(0,113,227,0.4); }
window.dark .oobe-list row:selected {
    background: rgba(0,113,227,0.22);
    border-color: rgba(0,113,227,0.6);
}

/* ── Preferences group (account page) ─────────────────────────────────── */
.oobe-prefs-group {
    border-radius: 20px;
    overflow: hidden;
}

/* ── Summary box (confirm page) ────────────────────────────────────────── */
.oobe-summary-box {
    background:    rgba(248,250,252,0.9);
    border:        1px solid rgba(0,0,0,0.07);
    border-radius: 20px;
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
    color: #0071e3;
    font-size: 48px;
    font-weight: 800;
    animation: pop-in 500ms cubic-bezier(0.34, 1.56, 0.64, 1) both;
}
@keyframes pop-in {
    from { opacity: 0; transform: scale(0.4); }
    to   { opacity: 1; transform: scale(1);   }
}

/* ── Buttons ───────────────────────────────────────────────────────────── */
.oobe-primary-button {
    background:    #0071e3;
    color:         #ffffff;
    border:        none;
    border-radius: 999px;
    padding:       15px 34px;
    font-weight:   650;
    font-size:     16px;
    min-width:     120px;
    box-shadow:    0 1px 2px rgba(15,23,42,0.12);
    transition:
        background-color 140ms cubic-bezier(0.22, 1, 0.36, 1),
        box-shadow       140ms cubic-bezier(0.22, 1, 0.36, 1),
        transform        120ms cubic-bezier(0.22, 1, 0.36, 1);
}
.oobe-primary-button:hover {
    background: #0077ed;
    box-shadow: 0 2px 6px rgba(15,23,42,0.16);
    transform:  translateY(-1px);
}
.oobe-primary-button:active {
    background:        #0068d6;
    transform:         translateY(0);
    box-shadow:        0 1px 3px rgba(0,113,227,0.20);
    transition-duration: 70ms;
}

.oobe-secondary-button {
    background:    transparent;
    color:         #475569;
    border:        1px solid rgba(0,0,0,0.14);
    border-radius: 999px;
    padding:       15px 28px;
    font-size:     16px;
    min-width:     100px;
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
    background:  linear-gradient(90deg, #0071e3, #409cff);
    border-radius: 999px;
    transition:  all 450ms cubic-bezier(0.22, 1, 0.36, 1);
}
window.dark .oobe-progress trough { background: rgba(255,255,255,0.10); }

/* ── Feature slideshow (installing page) ─────────────────────────────────
 * Something to read while the real progress line is stuck on one status
 * for a while -- unsquashfs extraction in particular takes far longer
 * than anything else in the install and gives no finer-grained updates. */
.oobe-feature-stack { min-height: 90px; }
.oobe-feature-title {
    font-size:   17px;
    font-weight: 650;
    color:       #0f172a;
}
.oobe-feature-body {
    font-size:   14px;
    color:       #64748b;
    line-height: 1.5;
    margin-top:  2px;
}
window.dark .oobe-feature-title { color: #f1f5f9; }
window.dark .oobe-feature-body  { color: #94a3b8; }

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
    border-color: #0071e3;
    background:   #ffffff;
    box-shadow:   0 0 0 3px rgba(0,113,227,0.18);
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

# ── Watermark icon: just reusing the existing KibaOS logo as the symbolic
# watermark instead of making a whole separate asset — it's the same
# K-mark already used for the panel/branding everywhere else in this
# build, no reason to duplicate it. ────────────────────────────────────────
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

# ── Privileged backend: libkibadisk + kibaos-oobe-backend ─────────────────
# this fully replaces the old Python/archinstall-based backend. no
# archinstall, no parted, no blkid/partprobe subprocesses anywhere near
# the disk-critical path — check kiba_gpt.c/kiba_fs.c/kiba_udev.c for the
# from-scratch GPT writer, mkfs/mount wrapper, and udev-settle
# replacement respectively. the only external tools I kept around are
# ones that genuinely have no sane from-scratch replacement: unsquashfs,
# mkfs.fat, mkfs.ext4, useradd/chpasswd, refind-install, mkinitcpio,
# locale-gen, pacman — all invoked via posix_spawn argv arrays, never a
# shell, so there's zero string-quoting/injection surface in this
# backend (same argv-array fix I already did on the Vala/sudo side).
echo "=== Building libkibadisk (disk/install backend library) ==="
mkdir -p /usr/share/kibaos-oobe/src/disk
cd /usr/share/kibaos-oobe/src/disk

cat > kiba_gpt.h << 'KIBA_SRC_END_GPTH'
/* kiba_gpt.h — GPT partition table writer, backed by sgdisk.
 *
 * Previously this was a from-scratch, hand-rolled implementation of
 * UEFI Spec 2.10 chapter 5 (protective MBR + primary/backup GPT header +
 * entry array) written directly via pwrite(), with BLKPG ioctls standing
 * in for partprobe. That was later swapped for libfdisk's C API, which
 * pulled in a link-time dependency (-lfdisk) and a fair amount of
 * fdisk_context/fdisk_partition object plumbing for what's fundamentally
 * a handful of "add this partition" calls. This revision replaces that
 * API dependency with `sgdisk` (from the gptfdisk package) invoked as a
 * plain subprocess — same underlying correctness guarantee (sgdisk is
 * the same kind of reference GPT implementation libfdisk is, and is
 * what most distro installers already shell out to), but the call
 * surface is now just "build an argv array, exec it, check the exit
 * code" instead of a C library binding. Every invocation goes through
 * execvp() with a real argv array — never a shell — so partition names
 * or GUIDs containing spaces or shell metacharacters are passed through
 * literally with no quoting/injection surface, same guarantee the rest
 * of this backend already holds itself to.
 *
 * The layout math (where each partition starts/ends, accounting for the
 * GPT header + entry array at both ends of the disk) is still computed
 * by this code rather than left to sgdisk's own "-n 0:0:0" defaults, so
 * placement stays fully deterministic and doesn't require parsing
 * sgdisk's output back out to find out where it actually put things.
 *
 * The public API below is UNCHANGED from the previous version, so
 * kibaos_oobe_backend_main.c and every other caller needs zero changes.
 *
 * Build requirement: none beyond the `sgdisk` binary being on PATH at
 * runtime (package: gptfdisk, already in packages.x86_64). No extra
 * -l flag needed at link time — see the gcc invocation building
 * kibaos-oobe-backend.
 */
#ifndef KIBA_GPT_H
#define KIBA_GPT_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

/* 16-byte little/mixed-endian GUID, stored exactly as UEFI expects on disk.
 * Kept for ABI compatibility with existing callers — internally this is
 * now converted to/from the canonical string-GUID format sgdisk's -u/-U
 * flags expect. */
typedef struct {
    uint8_t b[16];
} kiba_guid_t;

/* Well-known partition type GUIDs (UEFI Spec 2.10 Table 5-7 + Linux conventions) */
extern const kiba_guid_t KIBA_GUID_ESP;          /* C12A7328-F81F-11D2-BA4B-00A0C93EC93B */
extern const kiba_guid_t KIBA_GUID_LINUX_FS;     /* 0FC63DAF-8483-4772-8E79-3D69D8477DE4 */

typedef struct {
    char        name[37];      /* NUL-terminated, displayed only; truncated to 36 UTF-16 chars on disk */
    kiba_guid_t type_guid;
    kiba_guid_t unique_guid;   /* if all-zero, sgdisk generates one */
    uint64_t    first_lba;     /* Pass KIBA_GPT_FIRST_LBA_DEFAULT to let this
                                 * code compute the first usable LBA itself
                                 * (only valid for the first partition in the
                                 * array) or KIBA_GPT_FIRST_LBA_CONTIGUOUS to
                                 * start right after the previous partition's
                                 * resolved on-disk placement. Either way, when
                                 * first_lba isn't a concrete number, last_lba
                                 * below is reinterpreted as a sector COUNT
                                 * rather than an absolute LBA, since the real
                                 * start (and therefore the real end) isn't
                                 * resolved until write time. */
    uint64_t    last_lba;      /* inclusive. Pass KIBA_GPT_LAST_LBA_REST to
                                 * consume all remaining space on the disk --
                                 * this uses this code's own computed
                                 * last-usable-LBA (which already accounts for
                                 * the backup GPT header + entry array at the
                                 * end of the disk) instead of recomputing it
                                 * by hand at every call site. */
    uint64_t    attributes;
} kiba_gpt_partition_t;

/* Sentinels for first_lba/last_lba: never legitimate LBA values (or sector
 * counts, for KIBA_GPT_FIRST_LBA_DEFAULT's reinterpretation of last_lba), so
 * safe to reuse as flags. The first/last usable LBA math (GPT header +
 * 128-entry array on each end of the disk, sized off the real logical
 * sector size) is centralized once in kiba_gpt_write() instead of being
 * duplicated by hand at every call site -- see the entry_array_sectors
 * calculation there. This is the same math sgdisk and libfdisk both use
 * internally for a standard 128-entry GPT, so callers land on exactly
 * the same first/last usable LBAs those tools would pick by default. */
#define KIBA_GPT_LAST_LBA_REST        UINT64_MAX
#define KIBA_GPT_FIRST_LBA_DEFAULT    UINT64_MAX
#define KIBA_GPT_FIRST_LBA_CONTIGUOUS (UINT64_MAX - 1)

typedef struct {
    int      fd;                 /* open O_RDWR on the whole-disk block device */
    uint32_t logical_sector_size;
    uint64_t total_sectors;
    kiba_guid_t disk_guid;       /* if all-zero, sgdisk generates one */
} kiba_gpt_disk_t;

/* Generates a random RFC-4122 v4 GUID using /dev/urandom — no external tool. */
kiba_guid_t kiba_guid_random(void);

/* Creates a fresh GPT label and writes the given partitions (in order) to
 * disk->fd by invoking sgdisk as a subprocess (single call, all -n/-t/-c/-u
 * options for every partition passed in one argv array). Returns 0 on
 * success, -errno on failure (sgdisk's own error is collapsed to -EIO,
 * since it reports failures via stderr text rather than a stable numeric
 * code — the message is left on stderr for anyone debugging a failed run).
 *
 * On success, the kernel partition table is updated for each partition
 * automatically (sgdisk issues the BLKPG/BLKRRPART reread itself) —
 * caller does not need to call partprobe.
 *
 * out_last_lba: optional (may be NULL). If non-NULL, must point to an
 * array of n_parts uint64_t -- filled in with each partition's resolved
 * on-disk last LBA, computed by this function before it ever calls
 * sgdisk. Needed whenever a later partition uses
 * KIBA_GPT_FIRST_LBA_CONTIGUOUS, so the next iteration knows where the
 * previous partition actually landed.
 *
 * NOTE: disk->fd is used only to derive the device path (via
 * /proc/self/fd) to pass to sgdisk on argv — sgdisk opens the device
 * itself. The fd passed in must stay open for the duration of the call.
 */
int kiba_gpt_write(kiba_gpt_disk_t *disk,
                    const kiba_gpt_partition_t *parts, size_t n_parts,
                    uint64_t *out_last_lba);

/* Reads back sector size + total size for `path` (e.g. "/dev/vda") via
 * ioctl (BLKSSZGET, BLKGETSIZE64) — no `blockdev`/`lsblk` subprocess.
 * (Unchanged — these ioctls were never the risky part.) */
int kiba_gpt_probe_device(const char *path, uint32_t *sector_size,
                           uint64_t *total_sectors);

/* ── Dual-boot / "install alongside" support ─────────────────────────
 * Everything above this point assumes we own the whole disk and are
 * free to lay down a brand-new GPT (kiba_gpt_write() runs `sgdisk -Z`
 * first, which wipes whatever was there). The functions below are the
 * non-destructive counterparts used when the disk already has an OS on
 * it that the user wants to keep. */

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
 * anything on disk (runs `sgdisk -p`, read-only). Locates an existing
 * EFI System Partition, if any, and the single largest gap of
 * unallocated sectors, for dual-boot free-space installs. If the disk
 * has no valid GPT label at all, *out is zeroed and this returns 0 —
 * callers should treat that the same as "no free space / no ESP found"
 * rather than as an error, since an unpartitioned disk simply isn't a
 * dual-boot candidate. Returns -errno only if the device itself
 * couldn't be opened/read. */
int kiba_gpt_scan(const char *path, kiba_gpt_scan_result_t *out);

/* Adds ONE new partition to an EXISTING GPT table on `path` — unlike
 * kiba_gpt_write(), this does NOT run `sgdisk -Z`/-o and does NOT touch
 * any partition already on the disk. `part->first_lba`/`last_lba`
 * should fall inside a free region (normally taken straight from a
 * prior kiba_gpt_scan() call's free_first_lba/free_last_lba).
 * On success, writes the new partition's 1-indexed partition number to
 * *out_partno. Returns 0 on success, -EIO/-errno on failure. */
int kiba_gpt_add_partition(const char *path, const kiba_gpt_partition_t *part,
                            int *out_partno);

#endif
KIBA_SRC_END_GPTH

cat > kiba_gpt.c << 'KIBA_SRC_END_GPTC'
/* kiba_gpt.c — GPT writer backed by sgdisk (gptfdisk), run as a subprocess.
 *
 * The previous revision of this file called into libfdisk's C API
 * (fdisk_new_context / fdisk_add_partition / etc). This revision drops
 * that library dependency entirely and instead builds a plain argv
 * array and hands it to sgdisk via fork()+execvp() -- never a shell, so
 * nothing here (partition names, GUIDs, device paths) needs escaping
 * regardless of its contents. The public API (kiba_gpt.h) is unchanged
 * -- all callers continue to work without modification.
 *
 * sgdisk still handles the parts that are genuinely easy to get subtly
 * wrong by hand:
 *   - Protective MBR
 *   - Primary + backup GPT headers (including CRC32)
 *   - Partition entry array
 *   - BLKPG / BLKRRPART kernel notification (sgdisk does this itself
 *     after a successful write, same as partprobe would)
 *
 * What THIS file now owns instead of deferring to the library: the
 * actual sector-placement math (first/last usable LBA, where each
 * partition starts/ends). Computing that ourselves means every call to
 * sgdisk is a single, fully-formed command with concrete numbers --
 * no "-n 0:0:0 let sgdisk pick" placeholders whose result would then
 * need to be read back out of sgdisk's text output just to know where
 * things landed.
 *
 * We retain our own kiba_gpt_probe_device() (raw ioctls, unchanged) and
 * kiba_guid_random() since neither has anything to do with sgdisk.
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
#include <limits.h>        /* PATH_MAX */
#include <sys/ioctl.h>
#include <sys/wait.h>
#include <linux/fs.h>     /* BLKSSZGET, BLKGETSIZE64 */

/* ── Well-known type GUIDs (string form for sgdisk's -u/-U flags) ───── */
/* sgdisk accepts full GUIDs as canonical strings: 8-4-4-4-12 hex. For
 * partition *type* it also accepts short 4-hex-digit codes (ef00 = EFI
 * System, 8300 = Linux filesystem) which is what we pass to -t below --
 * these full-GUID #defines are only used for the type comparison against
 * caller-supplied kiba_guid_t values and for kiba_gpt_scan()'s output
 * parsing. */
#define KIBA_GUID_ESP_STR      "C12A7328-F81F-11D2-BA4B-00A0C93EC93B"
#define KIBA_GUID_LINUX_FS_STR "0FC63DAF-8483-4772-8E79-3D69D8477DE4"
#define KIBA_TYPE_CODE_ESP       "ef00"
#define KIBA_TYPE_CODE_LINUX_FS  "8300"

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
 * 8-4-4-4-12 string that sgdisk's -u/-U flags expect.
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

/* ── Run sgdisk as a subprocess via a real argv array — never a shell.
 * Discards sgdisk's (very chatty) stdout; leaves stderr connected so a
 * real failure still shows up in the caller's logs. Returns 0 on a
 * clean exit, -ENOENT if the sgdisk binary itself couldn't be found,
 * -EIO if sgdisk ran but reported failure, or -errno if fork/wait
 * itself failed. */
static int run_sgdisk(char *const argv[]) {
    pid_t pid = fork();
    if (pid < 0) return -errno;

    if (pid == 0) {
        int devnull = open("/dev/null", O_WRONLY);
        if (devnull >= 0) { dup2(devnull, STDOUT_FILENO); close(devnull); }
        execvp("sgdisk", argv);
        _exit(127); /* only reached if execvp() itself failed */
    }

    int status = 0;
    if (waitpid(pid, &status, 0) < 0) return -errno;
    if (!WIFEXITED(status)) return -EIO;
    int code = WEXITSTATUS(status);
    if (code == 127) return -ENOENT;
    return code == 0 ? 0 : -EIO;
}

/* Same as run_sgdisk(), but captures stdout into `out` (NUL-terminated,
 * truncated to out_sz - 1 bytes) instead of discarding it -- used by
 * kiba_gpt_scan(), which actually needs to read sgdisk's `-p` table
 * back out. Stderr is silenced here since sgdisk prints routine
 * "Creating new GPT entries in memory" notices there even on success. */
static int run_sgdisk_capture(char *const argv[], char *out, size_t out_sz) {
    int pipefd[2];
    if (pipe(pipefd) != 0) return -errno;

    pid_t pid = fork();
    if (pid < 0) { close(pipefd[0]); close(pipefd[1]); return -errno; }

    if (pid == 0) {
        close(pipefd[0]);
        dup2(pipefd[1], STDOUT_FILENO);
        close(pipefd[1]);
        int devnull = open("/dev/null", O_WRONLY);
        if (devnull >= 0) { dup2(devnull, STDERR_FILENO); close(devnull); }
        execvp("sgdisk", argv);
        _exit(127);
    }
    close(pipefd[1]);

    size_t used = 0;
    ssize_t n;
    while (used < out_sz - 1 &&
           (n = read(pipefd[0], out + used, out_sz - 1 - used)) > 0) {
        used += (size_t)n;
    }
    out[used] = '\0';
    /* Drain any remainder so the child never blocks writing to a full pipe. */
    char scratch[256];
    while (read(pipefd[0], scratch, sizeof(scratch)) > 0) {}
    close(pipefd[0]);

    int status = 0;
    if (waitpid(pid, &status, 0) < 0) return -errno;
    if (!WIFEXITED(status)) return -EIO;
    int code = WEXITSTATUS(status);
    if (code == 127) return -ENOENT;
    return code == 0 ? 0 : -EIO;
}

/* ── kiba_gpt_write — the sgdisk-subprocess implementation ──────────── */
int kiba_gpt_write(kiba_gpt_disk_t *disk,
                    const kiba_gpt_partition_t *parts, size_t n_parts,
                    uint64_t *out_last_lba) {
    if (n_parts == 0 || n_parts > 128) return -EINVAL;
    if (disk->logical_sector_size == 0) return -EINVAL;

    /* Resolve the block device path from our open fd via /proc/self/fd --
     * sgdisk needs a path string on argv, not an fd. */
    char fd_link[64];
    char dev_path[PATH_MAX];
    snprintf(fd_link, sizeof(fd_link), "/proc/self/fd/%d", disk->fd);
    ssize_t len = readlink(fd_link, dev_path, sizeof(dev_path) - 1);
    if (len < 0) return -errno;
    dev_path[len] = '\0';

    /* GPT layout constants -- the same math a standard 128-entry table
     * uses under sgdisk/libfdisk: entry array is 128 * 128 bytes,
     * rounded up to whole sectors, with one header sector at each end
     * of the disk (LBA 0 is the protective MBR; LBA 1 is the primary
     * header; the very last LBA is the backup header). Computed once
     * here instead of asking sgdisk where it put things afterward. */
    uint32_t ssz = disk->logical_sector_size;
    uint64_t entry_array_sectors = (16384 + ssz - 1) / ssz;
    uint64_t first_usable = 2 + entry_array_sectors;
    uint64_t last_usable  = disk->total_sectors - 2 - entry_array_sectors;

    /* Per-partition argv string storage -- heap-allocated since n_parts
     * isn't a compile-time constant. Every string here becomes a literal
     * argv element (no shell in between), so partition names containing
     * spaces or odd characters need no escaping at all. */
    struct { char n[48], t[24], c[80], u[56]; } *buf = calloc(n_parts, sizeof(*buf));
    if (!buf) return -ENOMEM;

    bool have_disk_guid = !guid_is_zero(&disk->disk_guid);
    char disk_guid_str[37];
    if (have_disk_guid) guid_to_str(&disk->disk_guid, disk_guid_str);

    /* Upper bound: sgdisk, -Z, -a, 1, [-U guid], (per part: -n v -t v [-c v] [-u v]), path, NULL */
    char *argv[8 + n_parts * 8 + 2];
    size_t ai = 0;
    argv[ai++] = "sgdisk";
    argv[ai++] = "-Z";                       /* wipe any existing MBR/GPT, start clean */
    /* -a 1: keep our LBAs exact. Without this, sgdisk uses its normal
     * 2048-sector (1MiB) alignment grid and silently snaps any explicit
     * numeric start passed via -n up to that grid -- and first_usable
     * above (LBA 34 for a standard 512-byte-sector 128-entry table) is
     * NOT itself a multiple of that grid. That meant partition 1's
     * *real* on-disk start could land ~2014 sectors later than the
     * first_usable value this function's own resolved_first/resolved_last
     * math was built on, while every partition after it was still placed
     * using the unsnapped numbers -- a genuine positional mismatch
     * between what we told the kernel and what sgdisk actually wrote,
     * not just a cosmetic rounding difference. That class of drift is
     * exactly what produces the kernel's in-core partition table
     * disagreeing with what's really on disk, which is what makes
     * mke2fs report a device size of zero right after formatting even
     * though the partition is right there. kiba_gpt_add_partition()
     * below already does this for exactly the same reason -- this just
     * brings kiba_gpt_write() in line with it, so out_last_lba is
     * always the truth, not merely what we asked for. */
    argv[ai++] = "-a"; argv[ai++] = "1";
    if (have_disk_guid) { argv[ai++] = "-U"; argv[ai++] = disk_guid_str; }

    uint64_t prev_end = 0;
    for (size_t i = 0; i < n_parts; i++) {
        const kiba_gpt_partition_t *p = &parts[i];

        bool first_is_default    = (p->first_lba == KIBA_GPT_FIRST_LBA_DEFAULT);
        bool first_is_contiguous = (p->first_lba == KIBA_GPT_FIRST_LBA_CONTIGUOUS);
        /* Per kiba_gpt.h: "Either way, when first_lba isn't a concrete
         * number, last_lba below is reinterpreted as a sector COUNT" --
         * that "either way" covers BOTH computed-start sentinels, not
         * just DEFAULT. Previously only DEFAULT actually got count
         * semantics here, which meant a CONTIGUOUS partition (used for
         * root, right after the ESP) could only ever mean "-1" (REST)
         * or an absolute LBA nobody at the call site could compute in
         * advance -- there was no way to give a CONTIGUOUS partition a
         * concrete size and leave the remainder of the disk free. */
        bool uses_computed_start = first_is_default || first_is_contiguous;
        uint64_t resolved_first;
        if (first_is_contiguous) {
            if (i == 0) { free(buf); return -EINVAL; }
            resolved_first = prev_end + 1;
        } else if (first_is_default) {
            resolved_first = first_usable;
        } else {
            resolved_first = p->first_lba;
        }

        uint64_t resolved_last;
        if (p->last_lba == KIBA_GPT_LAST_LBA_REST) {
            resolved_last = last_usable;
        } else if (uses_computed_start) {
            /* last_lba is a sector COUNT here, not an absolute LBA --
             * see the kiba_gpt_partition_t doc comment in kiba_gpt.h. */
            resolved_last = resolved_first + p->last_lba - 1;
        } else {
            resolved_last = p->last_lba;
        }

        snprintf(buf[i].n, sizeof(buf[i].n), "%zu:%llu:%llu", i + 1,
                  (unsigned long long)resolved_first, (unsigned long long)resolved_last);
        argv[ai++] = "-n"; argv[ai++] = buf[i].n;

        const char *type_code = (memcmp(p->type_guid.b, KIBA_GUID_ESP.b, 16) == 0)
                                     ? KIBA_TYPE_CODE_ESP : KIBA_TYPE_CODE_LINUX_FS;
        snprintf(buf[i].t, sizeof(buf[i].t), "%zu:%s", i + 1, type_code);
        argv[ai++] = "-t"; argv[ai++] = buf[i].t;

        if (p->name[0]) {
            snprintf(buf[i].c, sizeof(buf[i].c), "%zu:%s", i + 1, p->name);
            argv[ai++] = "-c"; argv[ai++] = buf[i].c;
        }
        if (!guid_is_zero(&p->unique_guid)) {
            char g[37];
            guid_to_str(&p->unique_guid, g);
            snprintf(buf[i].u, sizeof(buf[i].u), "%zu:%s", i + 1, g);
            argv[ai++] = "-u"; argv[ai++] = buf[i].u;
        }

        if (out_last_lba) out_last_lba[i] = resolved_last;
        prev_end = resolved_last;
    }

    argv[ai++] = dev_path;
    argv[ai]   = NULL;

    /* One sgdisk invocation writes the whole table (zap + optional disk
     * GUID + every partition) in a single pass, including the kernel
     * reread on success -- no separate partprobe step needed. */
    int rc = run_sgdisk(argv);
    free(buf);
    return rc;
}

/* ── Dual-boot: scan an existing table for an ESP + the largest gap ─── */
int kiba_gpt_scan(const char *path, kiba_gpt_scan_result_t *out) {
    memset(out, 0, sizeof(*out));

    uint32_t ssz = 0;
    uint64_t total_sectors = 0;
    if (kiba_gpt_probe_device(path, &ssz, &total_sectors) != 0) {
        /* Device couldn't even be opened/probed -- that's the one case
         * this function treats as a real error, per kiba_gpt.h. */
        return -errno;
    }

    char outbuf[16384];
    char *argv[] = { "sgdisk", "-p", (char *)path, NULL };
    int rc = run_sgdisk_capture(argv, outbuf, sizeof(outbuf));
    if (rc == -ENOENT) return rc; /* sgdisk itself missing -- real error */
    /* Any other non-zero exit (including "no valid partition table")
     * is treated as "nothing to scan" per kiba_gpt.h -- out stays
     * zeroed and this returns success, same as the old libfdisk version
     * did for a blank/non-GPT disk. */
    if (rc != 0) return 0;

    /* ── Parse "First usable sector is X, last usable sector is Y" ──── */
    uint64_t first_usable = 0, last_usable = 0;
    bool have_usable = false;
    {
        const char *m = strstr(outbuf, "First usable sector is ");
        if (m) {
            unsigned long long fu = 0, lu = 0;
            if (sscanf(m, "First usable sector is %llu, last usable sector is %llu",
                        &fu, &lu) == 2) {
                first_usable = fu; last_usable = lu; have_usable = true;
            }
        }
    }
    if (!have_usable) return 0; /* no valid GPT label found -- treat as empty */

    /* ── Parse the partition table lines: "  N   start   end   size  unit  code  name" ── */
    uint64_t starts[128], ends[128];
    size_t n = 0;
    char type_codes[128][8];

    char *line = outbuf;
    while (line && *line) {
        char *nl = strchr(line, '\n');
        if (nl) *nl = '\0';

        unsigned partno = 0;
        unsigned long long s = 0, e = 0;
        char code[8] = {0};
        /* First three whitespace-separated tokens are partno/start/end;
         * skip the "size" + "unit" tokens, then grab the 4-hex-digit
         * type code. Any line that doesn't match this shape (headers,
         * blank lines, warnings) is simply not a partition row. */
        double size_val;
        char unit[8] = {0}, junk_size[16] = {0};
        int matched = sscanf(line, " %u %llu %llu %15s %7s %7s",
                              &partno, &s, &e, junk_size, unit, code);
        (void)size_val;
        if (matched == 6 && partno >= 1 && partno <= 128 && n < 128) {
            starts[n] = s;
            ends[n]   = e;
            snprintf(type_codes[n], sizeof(type_codes[n]), "%s", code);
            if (out->esp_partno == 0 && strcasecmp(code, KIBA_TYPE_CODE_ESP) == 0) {
                out->esp_partno    = (int)partno;
                out->esp_first_lba = s;
                out->esp_last_lba  = e;
            }
            n++;
        }

        line = nl ? nl + 1 : NULL;
    }

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

    uint64_t best_first = 0, best_last = 0, best_len = 0;
    uint64_t cursor = first_usable;
    for (size_t i = 0; i <= n; i++) {
        uint64_t gap_start = cursor;
        uint64_t gap_end   = (i < n) ? (starts[i] > 0 ? starts[i] - 1 : 0)
                                      : last_usable;
        if (gap_end >= gap_start) {
            uint64_t glen = gap_end - gap_start + 1;
            if (glen > best_len) { best_len = glen; best_first = gap_start; best_last = gap_end; }
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
    return 0;
}

/* ── Dual-boot: append one partition to an existing table ───────────── */
int kiba_gpt_add_partition(const char *path, const kiba_gpt_partition_t *part,
                            int *out_partno) {
    /* Caller is responsible for having already confirmed (via
     * kiba_gpt_scan()) that a GPT label exists. sgdisk itself refuses
     * to add a sane partition to a disk with no label rather than
     * silently creating one -- that's what kiba_gpt_write() is for. */

    uint64_t resolved_last = part->last_lba;
    if (part->last_lba == KIBA_GPT_LAST_LBA_REST) {
        uint32_t ssz = 0;
        uint64_t total_sectors = 0;
        if (kiba_gpt_probe_device(path, &ssz, &total_sectors) != 0) return -errno;
        uint64_t entry_array_sectors = (16384 + ssz - 1) / ssz;
        resolved_last = total_sectors - 2 - entry_array_sectors;
    }

    /* "0" as the partition number tells sgdisk to use the next free
     * slot itself -- we don't need to know which slots are occupied. */
    char n_arg[48];
    snprintf(n_arg, sizeof(n_arg), "0:%llu:%llu",
              (unsigned long long)part->first_lba, (unsigned long long)resolved_last);

    const char *type_code = (memcmp(part->type_guid.b, KIBA_GUID_ESP.b, 16) == 0)
                                 ? KIBA_TYPE_CODE_ESP : KIBA_TYPE_CODE_LINUX_FS;
    char t_arg[24];
    snprintf(t_arg, sizeof(t_arg), "0:%s", type_code);

    char c_arg[80] = {0};
    if (part->name[0]) snprintf(c_arg, sizeof(c_arg), "0:%s", part->name);

    char u_arg[56] = {0};
    if (!guid_is_zero(&part->unique_guid)) {
        char g[37];
        guid_to_str(&part->unique_guid, g);
        snprintf(u_arg, sizeof(u_arg), "0:%s", g);
    }

    char *argv[14];
    size_t ai = 0;
    argv[ai++] = "sgdisk";
    argv[ai++] = "-a"; argv[ai++] = "1"; /* see kiba_gpt_write() -- keep our LBAs exact */
    argv[ai++] = "-n"; argv[ai++] = n_arg;
    argv[ai++] = "-t"; argv[ai++] = t_arg;
    if (c_arg[0]) { argv[ai++] = "-c"; argv[ai++] = c_arg; }
    if (u_arg[0]) { argv[ai++] = "-u"; argv[ai++] = u_arg; }
    argv[ai++] = (char *)path;
    argv[ai]   = NULL;

    int rc = run_sgdisk(argv);
    if (rc != 0) return rc;

    /* Find the partition number sgdisk actually assigned by re-scanning
     * the table and matching on the start LBA we just requested. */
    if (out_partno) {
        kiba_gpt_scan_result_t scan;
        if (kiba_gpt_scan(path, &scan) == 0) {
            char outbuf[16384];
            char *pargv[] = { "sgdisk", "-p", (char *)path, NULL };
            if (run_sgdisk_capture(pargv, outbuf, sizeof(outbuf)) == 0) {
                unsigned partno = 0;
                unsigned long long s = 0;
                char *line = outbuf;
                while (line && *line) {
                    char *nl = strchr(line, '\n');
                    if (nl) *nl = '\0';
                    unsigned long long e; char junk[16], unit[8], code[8];
                    if (sscanf(line, " %u %llu %llu %15s %7s %7s",
                                &partno, &s, &e, junk, unit, code) == 6 &&
                        s == part->first_lba) {
                        *out_partno = (int)partno;
                        break;
                    }
                    line = nl ? nl + 1 : NULL;
                }
            }
        }
    }
    return 0;
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

/* Polls (no subprocess) until `path` (e.g. "/dev/vda1") exists AND
 * reports a stable, non-zero size (via BLKGETSIZE64 for block devices,
 * st_size otherwise), or `timeout_ms` elapses. Node existence alone is
 * not sufficient -- see kiba_udev.c for why. Returns true once the
 * device is both present and settled. */
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

/* Forces the kernel to re-emit a "change" uevent for a partition device
 * by writing to its sysfs uevent file, which is what actually causes
 * udev to (re-)run its blkid probe and update /dev/disk/by-uuid,
 * /dev/disk/by-label, etc. This is the missing half of the story the
 * rest of this header solves: BLKPG/BLKRRPART at partition-table-write
 * time tells the kernel about a partition's existence, but writing an
 * actual filesystem into that partition afterward (mkfs.ext4, mkfs.fat)
 * doesn't itself trigger any uevent -- so without calling this right
 * after formatting, kiba_wait_for_disk_tag() below can end up polling a
 * by-uuid symlink that either never appears, or (on a disk that's been
 * formatted before) resolves to a stale UUID left over from whatever
 * filesystem used to be there. Call this once per partition immediately
 * after kiba_fs_format() succeeds, before reading its UUID back.
 * Returns true if the uevent was written; false just means the sysfs
 * node couldn't be opened (caller should treat that as "couldn't
 * confirm the retrigger", not necessarily fatal on its own). */
bool kiba_trigger_uevent(const char *part_path);

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
#include <sys/ioctl.h>
#include <sys/stat.h>
#include <time.h>
#include <unistd.h>
#include <linux/fs.h> /* BLKGETSIZE64 */

static void sleep_ms(int ms) {
    struct timespec ts = { .tv_sec = ms / 1000, .tv_nsec = (long)(ms % 1000) * 1000000L };
    nanosleep(&ts, NULL);
}

/* Node existence alone isn't enough: udev can materialize the dentry for
 * a freshly-created partition device node microseconds before the
 * kernel's block layer has finished wiring up that partition's actual
 * size -- BLKGETSIZE64 still reads 0 (or the node is openable but
 * "there" in name only) for a brief window right after the mknod. A
 * caller that proceeds the instant stat() succeeds can race ahead of
 * that and format/write against a device the kernel doesn't consider
 * fully live yet -- the same class of race kiba_gpt.c's BLKPG comment
 * describes, just one layer further down the stack. So this now polls
 * the actual reported size (via BLKGETSIZE64 for block devices, or
 * st_size for anything else, e.g. a loopback-backed regular file in a
 * test harness) and requires two consecutive non-zero reads of the
 * *same* size before calling the device ready -- a single non-zero
 * read could still be mid-transition on some drivers, so we want it to
 * have settled, not just briefly been non-zero once. */
bool kiba_wait_for_device(const char *path, int timeout_ms) {
    struct stat st;
    int waited = 0;
    const int step_ms = 100;
    uint64_t last_size = 0;
    int stable_reads = 0;

    while (waited <= timeout_ms) {
        if (stat(path, &st) == 0) {
            uint64_t size = 0;
            bool have_size = false;

            if (S_ISBLK(st.st_mode)) {
                int fd = open(path, O_RDONLY | O_CLOEXEC);
                if (fd >= 0) {
                    have_size = (ioctl(fd, BLKGETSIZE64, &size) == 0);
                    close(fd);
                }
            } else {
                size = (uint64_t)st.st_size;
                have_size = true;
            }

            if (have_size && size > 0) {
                if (size == last_size) {
                    if (++stable_reads >= 2) return true;
                } else {
                    last_size = size;
                    stable_reads = 1;
                }
            } else {
                stable_reads = 0;
                last_size = 0;
            }
        }
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

bool kiba_trigger_uevent(const char *part_path) {
    /* Partition device paths are always a flat basename directly under
     * /dev (e.g. "/dev/vda1", "/dev/nvme0n1p1", "/dev/sda1") -- the
     * kernel exposes a matching flat entry for every block device
     * (whole-disk or partition) directly under /sys/class/block/ by
     * that same basename, no need to walk /sys/block/<disk>/<part>
     * separately or resolve any symlink ourselves first. */
    const char *slash = strrchr(part_path, '/');
    const char *name = slash ? slash + 1 : part_path;
    if (name[0] == '\0') return false;

    char sysfs_path[PATH_MAX];
    snprintf(sysfs_path, sizeof(sysfs_path), "/sys/class/block/%s/uevent", name);

    int fd = open(sysfs_path, O_WRONLY | O_CLOEXEC);
    if (fd < 0) return false;
    /* "change" (not "add") -- the partition already exists as far as the
     * kernel/udev's device model is concerned; what changed is its
     * *content* (a filesystem got written where there wasn't one, or a
     * different one than before), which is exactly what the "change"
     * action means and what triggers udev's blkid rule to re-probe. */
    ssize_t w = write(fd, "change", 6);
    close(fd);
    return w == 6;
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
 * decompression, arch-chroot's mount namespace setup, refind-install's
 * rEFInd installation), it's invoked via posix_spawnp with a
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

/* mkarchiso's _cleanup_pacstrap_dir() deletes everything under
 * pacstrap_dir/boot (including vmlinuz-kiba-kernel and initramfs-kiba-kernel.img)
 * *before* the airootfs image is built, so the kernel is never actually
 * inside the squashfs/erofs image kiba_install_extract_image just
 * extracted -- it only exists on the boot medium, copied there
 * separately by mkarchiso alongside the image (as a sibling "boot/"
 * dir next to the arch dir holding airootfs.sfs/.erofs). Must be
 * called once, right after kiba_install_extract_image succeeds, or
 * the installed system boots to nothing. image_path is the same path
 * kiba_find_live_image returned. */
int kiba_install_copy_kernel(const char *image_path, const char *target_root);

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
 * posix_spawnp arch-chroot refind-install (rEFInd) plus a hand-written
 * refind.conf/refind_linux.conf, enables services, rebuilds the initramfs.
 * This only affects the INSTALLED system's bootloader -- the live ISO
 * itself still boots via GRUB (see the archiso profile config), this
 * function is never invoked for the ISO build. */
/* root_partno/disk_path are no longer used by the rEFInd path
 * (refind_linux.conf is written directly from root_uuid, which the
 * caller already resolved from the freshly-formatted filesystem) but
 * are kept in the signature for compatibility with the rest of the
 * install pipeline. */
/* dualboot: when true, the ESP being installed to is shared with an
 * existing OS. We leave that OS's own boot files on the ESP completely
 * untouched (refind-install only ever adds rEFInd's own files under
 * /EFI/refind and an NVRAM entry -- it never removes anyone else's).
 * Unlike GRUB, rEFInd auto-discovers other EFI bootloaders already
 * present on the ESP on its own (no os-prober equivalent needed) -- we
 * just give it a longer timeout on dual-boot installs so that menu is
 * actually visible instead of auto-booting straight into KibaOS. Note
 * we deliberately write refind_linux.conf ourselves rather than letting
 * refind-install/mkrlconf auto-generate it: when run inside a chroot,
 * that auto-generation picks up kernel parameters from the live/host
 * environment rather than the target system (a known rEFInd/chroot
 * footgun per the ArchWiki), so hand-writing it from root_uuid sidesteps
 * that entirely. */
int kiba_install_finalize(const char *target_root, const char *disk_path,
                           const char *root_part, const char *root_uuid,
                           int root_partno, bool dualboot,
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

int kiba_install_copy_kernel(const char *image_path, const char *target_root) {
    /* image_path is ".../<install_dir>/x86_64/airootfs.sfs" (or
     * airootfs.erofs). The kernel/initramfs mkarchiso stripped out of
     * the image live at the sibling "<install_dir>/boot/x86_64/" dir
     * instead (see kiba_install.h for why). Peel off two path
     * components to get from the image to <install_dir>. */
    char work[512];
    int n = snprintf(work, sizeof(work), "%s", image_path);
    if (n <= 0 || (size_t)n >= sizeof(work)) {
        snprintf(g_install_err, sizeof(g_install_err), "image path too long");
        return -1;
    }

    char *slash = strrchr(work, '/');   /* strip "/airootfs.sfs" */
    if (!slash) {
        snprintf(g_install_err, sizeof(g_install_err), "unexpected image path layout: %s", image_path);
        return -1;
    }
    *slash = '\0';

    slash = strrchr(work, '/');         /* strip "/x86_64" */
    if (!slash) {
        snprintf(g_install_err, sizeof(g_install_err), "unexpected image path layout: %s", image_path);
        return -1;
    }
    *slash = '\0';
    /* work is now ".../<install_dir>" */

    char vmlinuz_src[600], initrd_src[600], vmlinuz_dst[600], initrd_dst[600];
    snprintf(vmlinuz_src, sizeof(vmlinuz_src), "%s/boot/x86_64/vmlinuz-kiba-kernel", work);
    snprintf(initrd_src,  sizeof(initrd_src),  "%s/boot/x86_64/initramfs-kiba-kernel.img", work);
    snprintf(vmlinuz_dst, sizeof(vmlinuz_dst), "%s/boot/vmlinuz-kiba-kernel", target_root);
    snprintf(initrd_dst,  sizeof(initrd_dst),  "%s/boot/initramfs-kiba-kernel.img", target_root);

    struct stat st;
    if (stat(vmlinuz_src, &st) != 0) {
        snprintf(g_install_err, sizeof(g_install_err),
                  "kernel not found on boot medium at %s: %s", vmlinuz_src, strerror(errno));
        return -1;
    }

    char *argv[] = { (char *)"cp", (char *)"-a", vmlinuz_src, vmlinuz_dst, NULL };
    if (run_argv(argv) != 0) return -1;

    /* initramfs-kiba-kernel.img gets rebuilt from scratch a few steps later
     * in kiba_install_finalize (mkinitcpio -g), so this copy isn't load-
     * bearing the way vmlinuz-kiba-kernel is -- but it means the target isn't
     * momentarily without any initrd at all if that later step fails
     * partway through, so still worth doing and still best-effort. */
    char *argv2[] = { (char *)"cp", (char *)"-a", initrd_src, initrd_dst, NULL };
    run_argv(argv2);

    return 0;
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
            }
            /* f already closed above on the success path */
        }
        /* fopen() failed: f is NULL here, nothing to close */
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
    /* The build-time kibaos.conf (customize_airootfs.sh) ships an
     * [Autologin] block pointing at "liveuser". That block survived on
     * the installed target untouched, and since liveuser gets userdel'd
     * a few lines below, SDDM was left trying to autologin a user that
     * no longer exists -- which is what was actually causing the
     * installed system to come up with no desktop at all (labwc/Budgie
     * were never the problem; SDDM never got that far).
     * Fix: swap just the "User=liveuser" value to the real account name,
     * in place, rather than re-writing the whole file from a hardcoded
     * copy of the template -- that copy drifts the moment kibaos.conf
     * picks up a new key at build time and this function doesn't. Net
     * effect: the installed system autologins straight to the account
     * just created here, same as the live session did; the user can flip
     * that off in Settings afterward if they want a login prompt. */
    char path[1024];
    snprintf(path, sizeof(path), "%s/etc/sddm.conf.d/kibaos.conf", target_root);
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

                const char *needle = "User=liveuser";
                char *pos = strstr(buf, needle);
                if (pos) {
                    size_t prefix_len = (size_t)(pos - buf) + strlen("User=");
                    const char *suffix = pos + strlen(needle);
                    char *out = malloc(prefix_len + strlen(username) + strlen(suffix) + 1);
                    if (out) {
                        memcpy(out, buf, prefix_len);
                        strcpy(out + prefix_len, username);
                        strcat(out, suffix);

                        FILE *fw = fopen(path, "w");
                        if (fw) { fwrite(out, 1, strlen(out), fw); fclose(fw); }
                        free(out);
                    }
                }
                free(buf);
            }
            /* f already closed above on the success path */
        }
        /* fopen() failed: f is NULL here, nothing to close */
    }

    /* Remove the live user -- best effort, ignore failure if absent. */
    {
        char *argv[] = { (char *)"userdel", (char *)"-r", (char *)"liveuser", NULL };
        chroot_run(target_root, argv); /* ignore result intentionally */
    }

    /* Only request supplementary groups that actually exist in the target
     * root's /etc/group. useradd fails its ENTIRE invocation -- creating
     * no user at all -- if even one -G group is missing, and `docker` is
     * exactly that case by design: its group isn't meant to exist until
     * after setup (created once systemd-sysusers actually runs against
     * the installed system, not the image-capture snapshot), so trying
     * to add it here at useradd time was never going to work. That
     * failure used to get silently swallowed, so the account was never
     * created at all, and the *next* step (chpasswd) failed instead with
     * no indication the real problem was upstream. Filtering to groups
     * that are confirmed present -- and separately remembering which
     * ones got deferred, so a first-boot step can add them once they
     * actually exist -- replaces the useradd crash with a proper
     * catch-up instead of just permanently dropping `docker` membership. */
    {
        static const char *const candidate_groups[] = {
            "wheel", "audio", "video", "input", "network",
            "storage", "power", "docker"
        };
        char group_list[256] = "";
        char skipped_list[256] = "";
        char group_line[128];
        for (size_t gi = 0; gi < sizeof(candidate_groups) / sizeof(candidate_groups[0]); gi++) {
            char group_path[1024];
            snprintf(group_path, sizeof(group_path), "%s/etc/group", target_root);
            FILE *gf = fopen(group_path, "r");
            bool found = false;
            if (gf) {
                snprintf(group_line, sizeof(group_line), "%s:", candidate_groups[gi]);
                size_t prefix_len = strlen(group_line);
                char line[256];
                while (fgets(line, sizeof(line), gf)) {
                    if (strncmp(line, group_line, prefix_len) == 0) { found = true; break; }
                }
                fclose(gf);
            }
            if (found) {
                if (group_list[0] != '\0') strncat(group_list, ",", sizeof(group_list) - strlen(group_list) - 1);
                strncat(group_list, candidate_groups[gi], sizeof(group_list) - strlen(group_list) - 1);
            } else {
                if (skipped_list[0] != '\0') strncat(skipped_list, ",", sizeof(skipped_list) - strlen(skipped_list) - 1);
                strncat(skipped_list, candidate_groups[gi], sizeof(skipped_list) - strlen(skipped_list) - 1);
                /* Expected, not exceptional -- docker's group isn't meant
                 * to exist until first boot, so no warning here. The
                 * marker file below is how the first-boot service finds
                 * out, not a log message. */
            }
        }

        char *argv[] = {
            (char *)"useradd", (char *)"-m",
            (char *)"-G", group_list,
            (char *)"-s", (char *)"/bin/bash",
            (char *)username, NULL
        };

        /* Idempotent: if a prior install attempt got this far before
         * failing later on, the user may already exist in target root's
         * /etc/passwd. That's fine -- skip useradd rather than erroring,
         * same intent as the old "tolerate already exists" comment, but
         * checked explicitly instead of swallowing every possible
         * useradd failure (including real ones) to get there. */
        char passwd_path[1024];
        snprintf(passwd_path, sizeof(passwd_path), "%s/etc/passwd", target_root);
        bool user_exists = false;
        FILE *pf = fopen(passwd_path, "r");
        if (pf) {
            char uline[256];
            char prefix[128];
            snprintf(prefix, sizeof(prefix), "%s:", username);
            size_t prefix_len = strlen(prefix);
            while (fgets(uline, sizeof(uline), pf)) {
                if (strncmp(uline, prefix, prefix_len) == 0) { user_exists = true; break; }
            }
            fclose(pf);
        }

        if (!user_exists && chroot_run(target_root, argv) != 0) {
            snprintf(g_finish_err, sizeof(g_finish_err), "useradd failed for %s", username);
            return -1;
        }

        /* Hand off any deferred groups (docker, etc.) to a first-boot
         * service -- writes "username:group1,group2" so it knows who to
         * catch up and with what, once those groups actually exist. */
        if (skipped_list[0] != '\0') {
            char kibaos_dir[1024];
            snprintf(kibaos_dir, sizeof(kibaos_dir), "%s/etc/kibaos", target_root);
            mkdir(kibaos_dir, 0755); /* fine if it already exists */
            char marker_path[1024];
            snprintf(marker_path, sizeof(marker_path), "%s/pending-user-groups", kibaos_dir);
            FILE *mf = fopen(marker_path, "w");
            if (mf) {
                fprintf(mf, "%s:%s\n", username, skipped_list);
                fclose(mf);
            }
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

    /* Stash the plaintext account password briefly, root-only, so the
     * WinApps first-login setup (see WINDOWS APP SUPPORT further down)
     * can reuse it as the Windows guest's login too, instead of a random
     * string the person is never shown and can't log in with. This is
     * the only point in the whole install where the password exists in
     * plaintext outside of chpasswd's own stdin pipe, so it's written
     * here and nowhere else. kibaos-winapps-setup reads it exactly once
     * (via pkexec, since it's 0600 root:root) and deletes it immediately
     * after, so it never outlives the single setup step it exists for. */
    {
        char kibaos_dir[1024];
        snprintf(kibaos_dir, sizeof(kibaos_dir), "%s/etc/kibaos", target_root);
        mkdir(kibaos_dir, 0755); /* fine if it already exists */
        char pass_path[1024];
        snprintf(pass_path, sizeof(pass_path), "%s/winapps-userpass", kibaos_dir);
        int fd = open(pass_path, O_WRONLY | O_CREAT | O_TRUNC, 0600);
        if (fd >= 0) {
            ssize_t len = (ssize_t)strlen(password);
            ssize_t written = 0;
            while (written < len) {
                ssize_t w = write(fd, password + written, (size_t)(len - written));
                if (w < 0) { if (errno == EINTR) continue; break; }
                written += w;
            }
            close(fd);
        }
        /* Not fatal if this failed to write -- kibaos-winapps-setup
         * falls back to asking the person for their password directly
         * if the stash file isn't there. */
    }

    /* Pre-create ~/.local/bin, owned by the new account, on the just-
     * installed target -- not the live session. WinApps' setup.sh --user
     * (run later at first login, see kibaos-winapps-firstrun) installs
     * the `winapps` binary itself by `cp`/`tee`-ing straight into
     * ~/.local/bin, and neither of those commands create missing parent
     * directories -- a bare install onto a fresh useradd -m home (which
     * has no .local at all yet) fails outright with e.g. "cp: cannot
     * create regular file '/home/user/.local/bin/winapps': No such file
     * or directory", a documented failure mode upstream. useradd -m
     * populates skel but never creates .local/bin, so this closes that
     * gap once, here, rather than depending on WinApps' installer to
     * handle its own missing directory (best-effort: a failure here
     * shouldn't fail the whole install over a directory WinApps can
     * still create for itself in the common case). */
    {
        char local_bin[1024];
        snprintf(local_bin, sizeof(local_bin), "/home/%s/.local/bin", username);
        char *mkdir_argv[] = {
            (char *)"install", (char *)"-d", (char *)"-m", (char *)"755",
            (char *)"-o", (char *)username, (char *)"-g", (char *)username,
            local_bin, NULL
        };
        chroot_run(target_root, mkdir_argv); /* best-effort, see comment above */
    }

    return 0;
}

int kiba_install_finalize(const char *target_root, const char *disk_path,
                           const char *root_part, const char *root_uuid,
                           int root_partno, bool dualboot,
                           kiba_progress_cb cb, void *user_data) {
    char path[1024];

    if (cb) cb(80, "Cleaning up installer files...", user_data);

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
        /* grub/os-prober only ever existed to boot the INSTALLED system;
         * now that's rEFInd's job (refind package, already pulled in via
         * packages.x86_64), so drop them here same as the other live/
         * no-longer-needed packages. The live ISO itself is unaffected --
         * it's built from a separate GRUB-based archiso profile, not this
         * chroot. */
        char *argv[] = {
            (char *)"pacman", (char *)"-Rns", (char *)"--noconfirm",
            (char *)"archiso", (char *)"mkinitcpio-archiso", (char *)"squashfs-tools",
            (char *)"grub", (char *)"os-prober", NULL
        };
        chroot_run(target_root, argv); /* best-effort, same as old backend */
    }

    if (cb) cb(84, "Setting up your computer to start KibaOS...", user_data);
    {
        /* KibaOS is UEFI-only, which needs /sys/firmware/efi/efivars to
         * write the NVRAM boot entry. Fail fast with a clear message
         * instead of letting bootctl die with a cryptic error. This is
         * a firmware requirement, not a VM restriction -- a VM booted
         * in UEFI mode passes this check exactly like real hardware
         * does; it's specifically legacy/BIOS boot mode that trips it,
         * which happens to be a VM's *default* in a lot of hypervisors
         * (VirtualBox, QEMU without OVMF, etc.) unless UEFI firmware is
         * explicitly selected for that VM. */
        if (access("/sys/firmware/efi", F_OK) != 0) {
            snprintf(g_finish_err, sizeof(g_finish_err),
                     "KibaOS requires UEFI boot, and this system appears to "
                     "have booted in BIOS/legacy mode. If you're installing "
                     "in a VM, check that its firmware type is set to UEFI "
                     "(not BIOS/legacy) in the hypervisor's settings, then "
                     "boot the installer again -- otherwise, this system's "
                     "firmware doesn't support UEFI at all.");
            return -1;
        }

        /* bootctl install (run from inside the chroot, so no --esp-path
         * flag needed -- /boot is already the ESP mount point) drops
         * systemd-boot's own loader at <esp>/EFI/systemd/systemd-bootx64.efi
         * and a removable-media fallback copy at <esp>/EFI/BOOT/BOOTX64.EFI,
         * and registers the NVRAM boot entry itself (no efibootmgr
         * subprocess needed -- bootctl talks to efivarfs directly). This
         * replaces the old refind-install call; see the KIBA IDENTITY/VIEW
         * section's own comments elsewhere in this file for the general
         * "why switch bootloaders" reasoning -- short version here: native
         * GPT/BLS boot-counting (tries-left/tries-done, systemd-boot-
         * check-no-failures.service, systemd-bless-boot.service) only
         * works with systemd-boot, and rEFInd doesn't read any of it. */
        char *argv[] = { (char *)"bootctl", (char *)"install", NULL };
        if (chroot_run(target_root, argv) != 0) {
            snprintf(g_finish_err, sizeof(g_finish_err), "bootctl install failed");
            return -1;
        }
    }

    /* loader.conf: systemd-boot's own top-level config, plain text same
     * spirit as the old refind.conf. "default" is a glob matched against
     * the boot entry/UKI filename -- kibaos+3.efi matches "kibaos*.efi"
     * regardless of its current tries-left suffix, so this doesn't need
     * rewriting every time the counter changes. timeout semantics here
     * are systemd-boot's NORMAL ones (0 = boot default immediately
     * without showing the menu unless a key is already buffered) -- this
     * is actually what "switching back to systemd-boot" restores:
     * rEFInd's "timeout 0 means wait forever" was the inverted,
     * surprising case that needed its own callout comment; systemd-boot
     * needs no such caveat here. */
    snprintf(path, sizeof(path), "%s/boot/loader/loader.conf", target_root);
    if (dualboot) {
        /* Honest limitation carried over from the switch: unlike rEFInd,
         * which scans the whole ESP for ANY .efi it recognizes, systemd-
         * boot's own auto-discovery is narrower -- it lists BLS entries
         * under /loader/entries/*.conf and UKIs under /EFI/Linux/*.efi,
         * plus it specifically special-cases detecting an existing
         * Windows Boot Manager (\\EFI\\Microsoft\\Boot\\bootmgfw.efi) and
         * offering "Reboot Into Firmware Setup". It does NOT do rEFInd's
         * broad "scan every vendor's EFI subdirectory" discovery of
         * arbitrary other Linux installs' own bootloaders. For the
         * Windows-dual-boot case (the actual common one) this is a
         * non-issue; for dual-booting alongside another Linux distro's
         * own GRUB/systemd-boot, that other loader's entry may not
         * appear automatically the way it did under rEFInd. */
        write_file(path,
                   "timeout 5\n"
                   "default kibaos*.efi\n"
                   "editor no\n");
    } else {
        write_file(path,
                   "timeout 0\n"
                   "default kibaos*.efi\n"
                   "editor no\n");
    }

    {
        /* Build the initial UKI (Unified Kernel Image): kernel +
         * initramfs + kernel cmdline + os-release bundled into one signed-
         * later PE binary, dropped straight at the ESP path systemd-boot
         * auto-discovers (<esp>/EFI/Linux/*.efi). "+3" is the initial
         * boot-counting suffix (UAPI Boot Loader Specification / systemd's
         * Automatic Boot Assessment) -- systemd-boot decrements it on
         * every attempt and systemd-bless-boot.service (enabled below)
         * clears it entirely once boot-complete.target is reached, so an
         * install that boots fine on the very first try just becomes a
         * permanently "good" entry with no counter in its name at all.
         * mkinitcpio's own preset (installed.conf) hasn't changed -- it
         * still just builds a plain initramfs; ukify is what wraps that
         * plus vmlinuz-kiba-kernel into the actual bootable artifact. */
        snprintf(path, sizeof(path), "%s/etc/kernel", target_root);
        mkdir(path, 0755);
        snprintf(path, sizeof(path), "%s/etc/kernel/cmdline", target_root);
        char cmdline[512];
        snprintf(cmdline, sizeof(cmdline),
                 "root=UUID=%s rw quiet splash loglevel=3 "
                 "rd.udev.log_level=3 vt.global_cursor_default=0 "
                 "plymouth.use-simpledrm=1 "
                 "lsm=landlock,lockdown,yama,integrity,apparmor,bpf\n",
                 root_uuid);
        if (write_file(path, cmdline) != 0) {
            snprintf(g_finish_err, sizeof(g_finish_err), "writing /etc/kernel/cmdline failed");
            return -1;
        }

        snprintf(path, sizeof(path), "%s/boot/EFI/Linux", target_root);
        /* mkdir -p equivalent: EFI/ likely already exists from bootctl
         * install above, /Linux under it doesn't yet. */
        char mkdir_efi[1024];
        snprintf(mkdir_efi, sizeof(mkdir_efi), "%s/boot/EFI", target_root);
        mkdir(mkdir_efi, 0755);
        mkdir(path, 0755);

        char *argv[] = {
            (char *)"ukify", (char *)"build",
            (char *)"--linux=/boot/vmlinuz-kiba-kernel",
            (char *)"--initrd=/boot/initramfs-kiba-kernel.img",
            (char *)"--cmdline=@/etc/kernel/cmdline",
            (char *)"--os-release=@/etc/os-release",
            (char *)"--output=/boot/EFI/Linux/kibaos+3.efi",
            NULL
        };
        if (chroot_run(target_root, argv) != 0) {
            snprintf(g_finish_err, sizeof(g_finish_err), "ukify build failed");
            return -1;
        }
    }

    (void)disk_path;   /* no longer needed -- the UKI's cmdline is written directly from root_uuid */
    (void)root_partno;

    if (cb) cb(88, "Turning on background features...", user_data);
    {
        static const char *services[] = {
            "NetworkManager", "sddm", "bluetooth",
            "systemd-timesyncd", "systemd-time-wait-sync",
            /* Automatic Boot Assessment: clears a UKI's tries-left/
             * tries-done counter once boot-complete.target is actually
             * reached, turning "indeterminate" into "good" so a later
             * boot attempt isn't racing against a stale failure state.
             * Without this enabled, tries-left would just
             * count down to zero on every normal boot and the slot would
             * eventually get marked bad even with nothing wrong. */
            "systemd-bless-boot.service", "systemd-boot-check-no-failures.service",
        };
        for (size_t i = 0; i < sizeof(services)/sizeof(services[0]); i++) {
            char *argv[] = { (char *)"systemctl", (char *)"enable", (char *)services[i], NULL };
            chroot_run(target_root, argv); /* best-effort */
        }
    }

    if (cb) cb(89, "Saving your Wi-Fi settings...", user_data);
    {
        /* arch-chroot shares the host's network namespace, so the live
         * session's own connection is already what pacman used above and
         * below -- this copy isn't for that. It's so the INSTALLED system
         * comes up already connected on first boot instead of making
         * someone re-enter the Wi-Fi password they just typed into OOBE
         * two minutes ago. NetworkManager refuses to load a connection
         * profile unless it's mode 600 owned by root, so that's set
         * explicitly rather than trusting whatever the live session left
         * them as. */
        snprintf(path, sizeof(path), "%s/etc/NetworkManager/system-connections", target_root);
        mkdir(path, 0700);

        char *argv[] = {
            (char *)"bash", (char *)"-c",
            (char *)"cp -a /etc/NetworkManager/system-connections/. \"$1\"/ 2>/dev/null; "
                    "chown -R root:root \"$1\"; find \"$1\" -type f -exec chmod 600 {} +",
            (char *)"--", path, NULL
        };
        run_argv(argv); /* best-effort -- fine if the live session never had a saved connection */
    }

    if (cb) cb(90, "Adding support for videos and music...", user_data);
    {
        /* gst-plugins-ugly, gst-libav, and ffmpeg cover the actually
         * patent-encumbered codecs (h264, mp3, aac, etc.) -- deliberately
         * left out of packages.x86_64 so the ISO itself never carries
         * them, and pulled here instead, straight onto the disk being
         * installed to. This needs a live network connection on the
         * install machine; if there isn't one, pacman just fails and we
         * carry on -- Totem still plays the royalty-free formats gst-
         * plugins-good/-bad already cover from the ISO packages, and the
         * user can pull these later from Settings/pacman once online. */
        char *argv[] = {
            (char *)"pacman", (char *)"-S", (char *)"--noconfirm", (char *)"--needed",
            (char *)"gst-plugins-ugly", (char *)"gst-libav", (char *)"ffmpeg", NULL
        };
        if (chroot_run(target_root, argv) != 0 && cb) {
            cb(90, "Couldn't add video/music support right now (no internet?) -- "
                   "you can add it later from Settings",
               user_data);
        }
    }

    if (cb) cb(91, "Adding your startup screen...", user_data);
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
    write_file(path, "[Daemon]\nTheme=kibaos\nShowDelay=0\nDeviceTimeout=8\n");
    {
        /* Sanity-check the theme actually landed in target_root before we
         * try to switch to it -- if the airootfs->target copy ever misses
         * it, this turns a silent "boot shows the stock theme" bug into a
         * clear, logged failure instead. */
        char theme_check[1024];
        snprintf(theme_check, sizeof(theme_check), "%s/usr/share/plymouth/themes/kibaos/kibaos.plymouth", target_root);
        struct stat st;
        if (stat(theme_check, &st) != 0) {
            if (cb) cb(93, "Couldn't find the KibaOS startup screen -- using the default one instead", user_data);
        } else {
            char *argv[] = { (char *)"plymouth-set-default-theme", (char *)"kibaos", NULL };
            if (chroot_run(target_root, argv) != 0) {
                /* Non-fatal: a missing splash theme shouldn't abort the
                 * whole install, but MUST be visible, or the initramfs
                 * rebuild below will silently bake in whatever theme was
                 * already active (the stock default) instead of kibaos --
                 * this was previously discarded with no error or log line. */
                if (cb) cb(93, "Couldn't set the KibaOS startup screen -- using the default one instead", user_data);
            }
        }
    }

    if (cb) cb(94, "Finishing up...", user_data);
    {
        char *argv[] = {
            (char *)"mkinitcpio", (char *)"-c", (char *)"/etc/mkinitcpio.conf.d/installed.conf",
            (char *)"-g", (char *)"/boot/initramfs-kiba-kernel.img", NULL
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
 * Windows app support (WinApps) is a listed, always-on feature, not a
 * user choice: this always drops /etc/kibaos/winapps-pending under
 * target_root so kibaos-winapps-firstrun.desktop (see WINDOWS APP SUPPORT
 * below) offers the WinApps setup wizard on first login into the freshly
 * installed system.
 *
 * Internally this no longer touches archinstall, parted, blkid, or
 * partprobe as subprocesses: all of that is libkibadisk (kiba_gpt.c /
 * kiba_fs.c / kiba_udev.c). The only external tools left are the ones
 * with no sane from-scratch replacement: sgdisk (GPT writer, see
 * kiba_gpt.c), unsquashfs, useradd/chpasswd, refind-install,
 * mkinitcpio, locale-gen, pacman -- all invoked via argv
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

/* VM detection is no longer used to refuse installation here (see the
 * matching change in the Vala frontend's is_running_in_vm() comment) --
 * virtual disk handling has been solid enough in practice that the
 * original blanket refusal was pure friction, not a real safeguard. */

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
    if (argc != 8) {
        fprintf(stderr,
            "usage: %s <disk> <mode: erase|alongside> <locale> <keymap> <hostname> <username> <password>\n",
            argv[0]);
        return 2;
    }
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

    /* ── 1-2. Probe + partition (GPT via sgdisk) ───────────────────── */
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
         * matching the layout the old archinstall-based backend used.
         *
         * Deliberately NOT re-deriving first/last usable LBAs here by
         * hand a second time. kiba_gpt_write() already computes them
         * once, internally, from the real sector size/total sectors and
         * the standard 128-entry GPT layout -- duplicating that math at
         * every call site is exactly how the old hand-rolled version
         * used to drift by a sector or two and get rejected. Just use
         * the sentinels below and let kiba_gpt_write() own the layout:
         * KIBA_GPT_FIRST_LBA_DEFAULT / _CONTIGUOUS / KIBA_GPT_LAST_LBA_REST
         * -- see kiba_gpt_write()'s handling of these sentinels and the
         * doc comment on kiba_gpt_partition_t. */
        uint64_t esp_sectors = (512ull * 1024 * 1024) / ssz;

        /* Rough pre-flight sanity check only (not used for the actual
         * partition layout below) -- catches "disk is way too small"
         * early with a friendly message instead of a raw sgdisk error. */
        uint64_t rough_overhead = (128 * 128 + ssz - 1) / ssz + 34;
        if (esp_sectors + rough_overhead >= total_sectors) {
            close(disk_fd);
            fail("Disk is too small for KibaOS (need at least ~1.5GB usable after the EFI partition).");
        }

        /* Root now gets everything left after the ESP -- the previous
         * "give root-a only half, leave the rest free for systemd-repart
         * to carve out root-b" A/B scheme has been removed entirely (see
         * the TRUE A/B ROOT section, which used to live further down in
         * this build script and no longer does). KIBA_GPT_LAST_LBA_REST
         * just fills the rest of the disk -- exactly the "disk too small
         * for two slots" fallback this code already had, now the only
         * path, so there's no root_sectors variable left to compute. */

        kiba_gpt_disk_t gdisk = {
            .fd = disk_fd,
            .logical_sector_size = ssz,
            .total_sectors = total_sectors,
            .disk_guid = {{0}},
        };
        kiba_gpt_partition_t parts[2] = {
            { .name = "KIBAOS-ESP",  .type_guid = KIBA_GUID_ESP,      .unique_guid = {{0}},
              .first_lba = KIBA_GPT_FIRST_LBA_DEFAULT, .last_lba = esp_sectors, .attributes = 0 },
            { .name = "KIBAOS-ROOT", .type_guid = KIBA_GUID_LINUX_FS, .unique_guid = {{0}},
              .first_lba = KIBA_GPT_FIRST_LBA_CONTIGUOUS,
              .last_lba = KIBA_GPT_LAST_LBA_REST, .attributes = 0 },
        };
        uint64_t placed_ends[2] = {0};
        int rc = kiba_gpt_write(&gdisk, parts, 2, placed_ends);
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

    /* Wait for the kernel/udev to settle before touching the new
     * partition nodes -- the actual fix for the original bug report. */
    if (!kiba_wait_for_device(esp_part, 5000) || !kiba_wait_for_device(root_part, 5000)) {
        fail("Partition devices never appeared after partitioning.");
    }

    /* ── 3. Format ─────────────────────────────────────────────────── */
    progress(10, "Formatting partitions...");
    if (!dualboot) {
        if (kiba_fs_format(esp_part, KIBA_FS_FAT32, "KIBAOS-ESP") != 0) {
            fail(kiba_fs_strerror());
        }
        /* mkfs.fat just wrote a brand-new filesystem directly to the
         * block device -- the kernel/udev have no way to know that
         * happened on their own (see kiba_trigger_uevent's own comment
         * in kiba_udev.c for the full story: BLKPG at partition-create
         * time only covers the partition table, not what gets written
         * into a partition afterward). Without this, kiba_wait_for_
         * disk_tag() below could poll a /dev/disk/by-uuid symlink that
         * either never appears, or -- worse, and silently -- resolves to
         * a stale UUID left over from whatever was on this partition
         * before, which is exactly the kind of bug that produces a
         * clean-looking install that then can't find its own root
         * filesystem on first boot. */
        kiba_trigger_uevent(esp_part);
    }
    /* Dual-boot: the ESP already belongs to the other OS and already has
     * a filesystem on it, plus that OS's own boot files -- formatting it
     * would destroy them. refind-install (further down) only ever adds
     * KibaOS's own files there, so we deliberately never touch the ESP's
     * filesystem in this mode. */
    if (kiba_fs_format(root_part, KIBA_FS_EXT4, "KIBAOS-ROOT") != 0) {
        fail(kiba_fs_strerror());
    }
    kiba_trigger_uevent(root_part); /* same reasoning as the ESP one above */

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

    /* mkarchiso strips vmlinuz-kiba-kernel/initramfs-kiba-kernel.img out of the
     * airootfs before building the image extracted above -- pull them
     * back in from the boot medium or the install has no kernel. */
    progress(70, "Copying kernel to target system...");
    if (kiba_install_copy_kernel(image_path, target_root) != 0) {
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
     * -- now that kiba_trigger_uevent() forces a fresh probe right
     * after each format call above. Without that trigger this could
     * previously read back a stale UUID left over from a partition's
     * PREVIOUS filesystem on a disk that had been installed to before,
     * since udev has no way to notice a raw mkfs write on its own --
     * see kiba_trigger_uevent's comment in kiba_udev.c for the full
     * story, and note this can't be exercised in a udev-less sandbox
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
    if (kiba_install_finalize(target_root, disk, root_part, root_uuid, root_partno, dualboot,
                               progress_cb, NULL) != 0) {
        fail(kiba_install_strerror());
    }

    /* ── 11. Windows app support ────────────────────────────────────────
     * Listed as a standing feature, not opt-in, so this always drops the
     * marker inside the freshly installed root -- the actual setup wizard
     * (kibaos-winapps-setup) only ever runs later, on first login into the
     * *installed* system via kibaos-winapps-firstrun.desktop, never from
     * in here. Mirrors the exact same marker kibaos-oem-finish.sh drops
     * for OEM-finish mode, just written under target_root instead of the
     * live root since this path is a fresh install, not an already-booted
     * system. */
    {
        char p[320];
        snprintf(p, sizeof(p), "%s/etc/kibaos", target_root);
        mkdir(p, 0755); /* ignore EEXIST -- /etc already exists under target_root */
        snprintf(p, sizeof(p), "%s/etc/kibaos/winapps-pending", target_root);
        FILE *f = fopen(p, "w");
        if (f) fclose(f); /* best-effort: a missed marker just means the
                            * user runs "Set Up Windows Apps" from the app
                            * menu themselves instead of it prompting them */
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
    -L. -lkibadisk \
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
# installers like this one. Also always drops /etc/kibaos/winapps-pending
# -- WinApps is a listed, always-on feature -- see WINDOWS APP SUPPORT
# further down for what that marker actually triggers.
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
useradd -m -G wheel,audio,video,input,network,storage,power,docker -s /bin/bash "${USERNAME_VAL}" \
  || fail "useradd failed"
echo "${USERNAME_VAL}:${PASSWORD_VAL}" | chpasswd || fail "chpasswd failed"

# Stash the plaintext password briefly, root-only, so first-login WinApps
# setup can reuse it as the Windows guest's login instead of a random
# string nobody's ever shown (see kibaos-winapps-setup, which reads this
# once via pkexec and deletes it right after). Mirrors what
# kiba_install_create_user() does for the disk-install path -- this is
# the OEM-finish equivalent of that same account-creation moment.
mkdir -p /etc/kibaos
umask 077
printf '%s' "${PASSWORD_VAL}" > /etc/kibaos/winapps-userpass
chmod 600 /etc/kibaos/winapps-userpass
umask 022

progress 85 "Cleaning up OEM account..."
# Remove the temporary OEM account created by kibaos-oem-prepare, if present.
userdel -r oem 2>/dev/null || true
rm -f /etc/sddm.conf.d/kibaos-oem-autologin.conf 2>/dev/null || true

progress 95 "Finishing up..."
mkdir -p /etc/kibaos
touch /etc/kibaos/winapps-pending
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

id oem &>/dev/null || useradd -m -G wheel,audio,video,input,network,storage,power,docker -s /bin/bash oem
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
# BOOT SPLASH — custom "kibaos" Plymouth theme (script-type plugin)
# ══════════════════════════════════════════════════════════════════════════
# Previously the Numix Plymouth theme, cloned + `make install`ed from
# upstream. Swapped out for a small hand-written script theme so the splash
# uses WolfTech's own branding image (BOOT_SPLASH, fetched above) instead of
# generic Numix art. `script` is a built-in Plymouth plugin, so this needs
# no clone/build step — just the theme dir, the .plymouth descriptor, the
# .script itself, and the image copied in.
KIBA_PLYMOUTH_DIR="/usr/share/plymouth/themes/kibaos"
mkdir -p "${KIBA_PLYMOUTH_DIR}"

if [ -f "${BOOT_SPLASH}" ]; then
  cp "${BOOT_SPLASH}" "${KIBA_PLYMOUTH_DIR}/splash.png"
else
  # Fallback so the theme never references a missing image if the fetch
  # above failed — reuse the existing 256px logo instead.
  cp /usr/share/kibaos/logo-256.png "${KIBA_PLYMOUTH_DIR}/splash.png" 2>/dev/null || true
fi

cat > "${KIBA_PLYMOUTH_DIR}/kibaos.plymouth" << 'PLYMOUTHDESC'
[Plymouth Theme]
Name=KibaOS
Description=KibaOS boot splash
ModuleName=script

[script]
ImageDir=/usr/share/plymouth/themes/kibaos
ScriptFile=/usr/share/plymouth/themes/kibaos/kibaos.script
PLYMOUTHDESC

cat > "${KIBA_PLYMOUTH_DIR}/kibaos.script" << 'PLYMOUTHSCRIPT'
// KibaOS boot splash — Plymouth script theme.
// Centered brand image on a dark background, with a small three-dot
// progress pulse underneath and a minimal password prompt for
// full-disk-encryption unlocks.

Window.SetBackgroundTopColor(0.043, 0.055, 0.078);
Window.SetBackgroundBottomColor(0.043, 0.055, 0.078);

logo.image = Image("splash.png");
logo.sprite = Sprite(logo.image);
logo.sprite.SetX(Window.GetWidth() / 2 - logo.image.GetWidth() / 2);
logo.sprite.SetY(Window.GetHeight() / 2 - logo.image.GetHeight() / 2);
logo.sprite.SetOpacity(1);

dot_count = 3;
dot_spacing = 26;
dots = [];
for (i = 0; i < dot_count; i++) {
  dots[i].image = Image.Text("•", 1, 1, 1, 1, "Sans 28");
  dots[i].sprite = Sprite(dots[i].image);
  dots[i].sprite.SetX(Window.GetWidth() / 2 - (dot_count * dot_spacing) / 2 + i * dot_spacing);
  dots[i].sprite.SetY(logo.sprite.GetY() + logo.image.GetHeight() + 36);
  dots[i].sprite.SetOpacity(0.25);
}

progress_tick = 0;
fun refresh_callback() {
  progress_tick++;
  active = Math.Int(progress_tick / 8) % dot_count;
  for (i = 0; i < dot_count; i++) {
    if (i == active)
      dots[i].sprite.SetOpacity(1);
    else
      dots[i].sprite.SetOpacity(0.25);
  }
}
Plymouth.SetRefreshFunction(refresh_callback);

fun display_password_callback(prompt, bullets) {
  if (prompt == "")
    prompt = "Enter your password to unlock the disk:";
  prompt_text.image = Image.Text(prompt, 1, 1, 1, 1);
  prompt_text.sprite = Sprite(prompt_text.image);
  prompt_text.sprite.SetX(Window.GetWidth() / 2 - prompt_text.image.GetWidth() / 2);
  prompt_text.sprite.SetY(dots[0].sprite.GetY() + 50);
}
Plymouth.SetDisplayPasswordFunction(display_password_callback);
PLYMOUTHSCRIPT

# Plymouth daemon config — must be written before mkinitcpio bakes it in
mkdir -p /etc/plymouth
cat > /etc/plymouth/plymouthd.conf << 'PLYMOUTHD'
[Daemon]
Theme=kibaos
ShowDelay=0
DeviceTimeout=8
PLYMOUTHD

# Set the theme now so it's in place before mkarchiso runs its own
# mkinitcpio pass over linux.preset (archiso_config=archiso.conf, set above
# with the plymouth/kms hooks already added).
#
# -R forces plymouth-set-default-theme to rebuild the initramfs itself
# right now, per ArchWiki: "every time a theme is changed, the initramfs
# must be rebuilt -- the -R option ensures that it is rebuilt".
#
# Non-fatal on failure -- the underlying causes that made this fail
# during development (missing MTD/dm_snapshot/DRM kernel config) are
# fixed now, and the belt-and-suspenders logo overwrite right below
# still gets the correct splash showing even if theme *selection* has a
# hiccup, so this doesn't need to hard-stop the whole build.
plymouth-set-default-theme -R kibaos 2>/dev/null || true
echo "=== Boot splash: custom kibaos Plymouth theme installed ==="

# Belt-and-suspenders: Arch's own `plymouth` package ships a pacman hook
# that runs `plymouth-set-default-theme -R bgrt` automatically on every
# install/upgrade of that package -- so if anything later in this script
# (an AUR build, a stray `pacman -S`) touches plymouth again, the theme
# selection above gets silently reset back to bgrt. Overwriting the
# actual shared logo assets Arch's built-in themes read from means the
# splash is still correctly branded even if theme *selection* ever
# regresses -- per ArchWiki, fade-in/script/solar/spinfinity all read
# from one shared file, and spinner/bgrt each read their own
# watermark.png.
cp "${KIBA_PLYMOUTH_DIR}/splash.png" /usr/share/plymouth/arch-logo.png
for _theme_dir in bgrt spinner; do
  if [ -d "/usr/share/plymouth/themes/${_theme_dir}" ]; then
    cp "${KIBA_PLYMOUTH_DIR}/splash.png" \
       "/usr/share/plymouth/themes/${_theme_dir}/watermark.png"
  fi
done

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
# WINAPPS — vendor the repo into the image instead of curling it at
# first-run. Same reasoning as ditching archinstall for libkibadisk: don't
# make a fresh install's success depend on a network fetch of someone
# else's script at the exact moment a brand-new user is going through it.
# setup.sh from this same checkout gets run locally by
# kibaos-winapps-firstrun later (see near kibaos-first-login below), so the
# installed WinApps version is pinned to whatever was current at ISO build
# time, not whatever's on main the day someone installs KibaOS.
# ══════════════════════════════════════════════════════════════════════════
WINAPPS_SRC="/opt/kibaos/winapps-src"
rm -rf "${WINAPPS_SRC}"
mkdir -p "$(dirname "${WINAPPS_SRC}")"
git clone --depth 1 https://github.com/winapps-org/winapps.git "${WINAPPS_SRC}"
chmod +x "${WINAPPS_SRC}/setup.sh" "${WINAPPS_SRC}/bin/"* 2>/dev/null || true
echo "=== WinApps: vendored $(git -C "${WINAPPS_SRC}" rev-parse --short HEAD) ==="

# dockur/windows (the container image WinApps' compose.yaml runs) NATs its
# own tap network for the Windows guest and needs the netfilter NAT modules
# loaded on the host to do it -- per winapps-org/winapps docs/docker.md,
# without ip_tables/iptable_nat loaded, folder sharing (and the guest's
# network setup in general) breaks. Baking this in at build time so it's
# just working on first boot rather than a manual post-install step.
mkdir -p /etc/modules-load.d
cat > /etc/modules-load.d/kibaos-winapps.conf << 'IPTABLESMODS'
ip_tables
iptable_nat
IPTABLESMODS
echo "=== WinApps: ip_tables/iptable_nat set to load at boot ==="

# ══════════════════════════════════════════════════════════════════════════

flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

# ══════════════════════════════════════════════════════════════════════════
# JUNCTION — app/link chooser (re.sonny.Junction), pops up on open so the
# user picks which installed app handles a given file/link instead of
# silently locking to one default. Installed system-wide (--system) at
# build time so it's present for every user account on first boot, not
# just whichever account happens to run flatpak first.
# ══════════════════════════════════════════════════════════════════════════
flatpak install --system --noninteractive flathub re.sonny.Junction
echo "=== Junction: installed via flatpak (re.sonny.Junction) ==="

# ══════════════════════════════════════════════════════════════════════════
# TASKBAR LAUNCHER ICON — replace the default Budgie Menu (start button) icon
# ══════════════════════════════════════════════════════════════════════════
# The Budgie Menu applet's default icon name is "start-here-symbolic"
# (solus-project/budgie-desktop#457). Numix-Circle is an APP icon theme only
# (see note above) and doesn't cover the "places" category that icon lives
# in, so the lookup falls through to adwaita-icon-theme — which means the
# taskbar launcher button would otherwise show Adwaita's literal "GNOME
# foot" logo, a well-known rough edge (bbs.archlinux.org/viewtopic.php?
# id=209293) that has no place on a consumer OS.
#
# Uses the SAME source badge as the app-icon set and Plymouth splash (see
# BRANDING ASSETS above, LOGO_256) rather than a generated placeholder --
# the "start menu" button is the single most-clicked spot on the whole
# desktop, so it should be showing the actual KibaOS mark, not a generic
# stand-in shape. That crop is already a clean centered circular badge with
# no wordmark, which is exactly the composition a launcher icon needs.
ADWAITA_ICONS="/usr/share/icons/Adwaita"
LAUNCHER_MASTER="/tmp/kibaos-launcher-icon.png"
if [ -f "${LOGO_256}" ]; then
  cp "${LOGO_256}" "${LAUNCHER_MASTER}"
else
  # Defensive fallback only -- shouldn't trigger since BRANDING ASSETS
  # above always produces LOGO_256, even in its own "fetch failed" branch
  # (the drawn black-circle/white-'K' fallback). Kept so a future refactor
  # of that section can't silently turn this into a hard build failure.
  magick -size 512x512 xc:none \
    -fill black -draw "circle 256,256 256,16" \
    -stroke white -strokewidth 20 -fill none -draw "circle 256,256 256,60" \
    "${LAUNCHER_MASTER}"
fi

if [ -d "${ADWAITA_ICONS}" ]; then
  find "${ADWAITA_ICONS}" -path '*/places/start-here-symbolic.svg' -print0 2>/dev/null \
    | while IFS= read -r -d '' _svg; do
        _dir=$(dirname "${_svg}")
        _size=$(basename "$(dirname "${_dir}")")   # e.g. "48x48", or "scalable"
        _px="${_size%%x*}"
        case "${_px}" in
          ''|*[!0-9]*) _px=256 ;;   # "scalable" or anything unparsable -> high-res master
        esac
        magick "${LAUNCHER_MASTER}" -filter Lanczos -resize "${_px}x${_px}" \
          "${_dir}/start-here-symbolic.png"
        rm -f "${_svg}"
      done
  gtk-update-icon-cache -f "${ADWAITA_ICONS}" 2>/dev/null || true
fi
rm -f "${LAUNCHER_MASTER}"
echo "=== Taskbar launcher icon: KibaOS boot-logo badge installed ==="


# ══════════════════════════════════════════════════════════════════════════
# GTK THEME — system-wide Adwaita-dark base + KibaOS rounded-rectangle panel override
# ══════════════════════════════════════════════════════════════════════════
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
 *   grow    cubic-bezier(0.16, 1, 0.3, 1)       — easeOutExpo. Reserved
 *           for STRUCTURAL reveals (Raven and the Budgie Menu appearing/
 *           dismissing), never for small in-place state changes. A leaf
 *           unfurling and a light switching on are different kinds of
 *           motion even though both are "something turning on" — settle
 *           is the latter (a value flips, fast and certain), grow is the
 *           former (a whole shape is arriving, slightly unhurried at the
 *           start before resolving quickly). Kept distinct from settle
 *           so the two don't blur into a single generic "ease-ish" feel.
 *
 * Organic radius scale — every corner-radius below is a mild asymmetric
 * quad (top-left top-right bottom-right bottom-left) instead of one flat
 * number on all four corners. The spread is deliberately small (2-6px on
 * surfaces in the 16-28px range) so it reads as machined-but-grown at a
 * glance — closer to a river stone or a leaf edge than a die-cut card —
 * without tipping into the blobby/cartoonish territory a bigger spread
 * would. Applied only to the handful of surfaces that carry the brand
 * (panel, Raven, Budgie Menu, OSD, tooltips, context menus), not to every
 * button and row — restraint matters more than coverage here.
 *
 * Caveat: this only governs GTK widget-state transitions — it's NOT doing
 * compositor-level window drag physics. that used to be Wayfire's wobbly
 * plugin, but labwc has no wobbly equivalent (see the LABWC CONFIG
 * section for the whole story on that), so window dragging is back to
 * flat/rigid movement for now — nothing to verify here, it's just gone
 * until/unless a labwc plugin fills that gap. Raven/the Budgie Menu's
 * open/close slide is still Budgie's own compiled animation code, not GTK
 * CSS — the opacity transitions below are best-effort and may be
 * superseded by that native motion. Verify visually.
 * ════════════════════════════════════════════════════════════════════════ */

/* === KibaOS: Floating rounded-rectangle panel === */
.budgie-panel {
    margin: 0 120px 8px 120px;
    /* 42px panel height (see PANEL_PATH size below) — asymmetric quad
     * keeps every corner clearly rounded without hitting the ~21px
     * half-height point where the ends fully round off into a pill. */
    border-radius: 14px 20px 18px 22px;
    /* Faint radial bloom in a muted moss green (#7fae86, ~5% opacity),
     * layered under the existing navy glass — the one deliberate "nature"
     * accent color in the whole sheet, used nowhere else as a flat fill,
     * only ever as this kind of soft grown-from-behind glow. */
    background-image: radial-gradient(ellipse at 30% -40%,
        rgba(127, 174, 134, 0.05), transparent 65%);
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
    border-radius: 20px 26px 24px 28px;
    background-image: radial-gradient(ellipse at 80% -20%,
        rgba(127, 174, 134, 0.05), transparent 60%);
    background-color: rgba(16, 24, 40, 0.72);
    border: 1px solid rgba(255, 255, 255, 0.14);
    box-shadow:
        0 12px 48px rgba(0, 0, 0, 0.50),
        inset 0 1px 0 rgba(255, 255, 255, 0.10);
    opacity: 1;
    transition: opacity 280ms cubic-bezier(0.16, 1, 0.3, 1); /* grow — structural reveal, best-effort, see note above */
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
    border-radius: 22px 28px 20px 26px;
    background-image: radial-gradient(ellipse at 20% -30%,
        rgba(127, 174, 134, 0.05), transparent 60%);
    background-color: rgba(16, 24, 40, 0.80);
    border: 1px solid rgba(255, 255, 255, 0.14);
    box-shadow: 0 12px 48px rgba(0, 0, 0, 0.50);
    transition: opacity 260ms cubic-bezier(0.16, 1, 0.3, 1); /* grow — structural reveal, best-effort, see note above */
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

/* ════════════════════════════════════════════════════════════════════════
 * KibaOS extra polish pass — the small stuff that adds up
 * ════════════════════════════════════════════════════════════════════════ */

/* Crisp, on-brand focus rings instead of GTK's default dotted/heavy outline —
 * keyboard navigation should always be obvious, never ugly. */
*:focus-visible {
    outline: 2px solid rgba(0, 153, 204, 0.75);
    outline-offset: 1px;
    transition: outline-color 150ms cubic-bezier(0.22, 1, 0.36, 1);
}

/* Tooltips as small glass cards, matching Raven/the menu popover language
 * instead of GTK's flat dark rectangle. */
tooltip {
    background-color: rgba(20, 26, 40, 0.92);
    color: #e8eef5;
    border: 1px solid rgba(255, 255, 255, 0.12);
    border-radius: 8px 12px 9px 11px;
    padding: 6px 10px;
    box-shadow: 0 6px 18px rgba(0, 0, 0, 0.45);
}
tooltip decoration { background: transparent; box-shadow: none; }

/* Thin, rounded, low-profile scrollbars — always present but never loud. */
scrollbar {
    background-color: transparent;
}
scrollbar slider {
    background-color: rgba(255, 255, 255, 0.18);
    border-radius: 999px;
    min-width: 6px;
    min-height: 6px;
    transition: background-color 200ms cubic-bezier(0.5, 0, 0.75, 0);
}
scrollbar slider:hover {
    background-color: rgba(255, 255, 255, 0.32);
    transition: background-color 130ms cubic-bezier(0.22, 1, 0.36, 1);
}
scrollbar slider:active {
    background-color: rgba(0, 153, 204, 0.65);
}

/* Selected text uses the accent colour, not GTK's default blue. */
selection, *:selected {
    background-color: rgba(0, 153, 204, 0.55);
    color: #ffffff;
}

/* Checkboxes/radios: rounded box, accent fill when checked, same settle/fade
 * pair as everything else — these were the one obviously-untouched stock
 * GTK widget left standing next to switches/sliders that already got it. */
checkbutton check,
radiobutton radio {
    border-radius: 5px;
    border: 1px solid rgba(255, 255, 255, 0.28);
    background-color: rgba(255, 255, 255, 0.06);
    transition: background-color 200ms cubic-bezier(0.5, 0, 0.75, 0),
                border-color    200ms cubic-bezier(0.5, 0, 0.75, 0);
}
radiobutton radio { border-radius: 999px; }
checkbutton check:checked,
radiobutton radio:checked {
    background-color: #0099cc;
    border-color: #0099cc;
    transition: background-color 150ms cubic-bezier(0.22, 1, 0.36, 1),
                border-color    150ms cubic-bezier(0.22, 1, 0.36, 1);
}

/* Progress bars: rounded pill track matching the volume/brightness sliders
 * in Raven, instead of GTK's square-edged default. */
progressbar trough {
    border-radius: 999px;
    background-color: rgba(255, 255, 255, 0.10);
    min-height: 6px;
}
progressbar progress {
    border-radius: 999px;
    background-color: #0099cc;
    transition: background-color 200ms cubic-bezier(0.22, 1, 0.36, 1);
}

/* Right-click / app context menus as the same floating glass card as
 * Raven and the Budgie Menu, instead of a flat GTK menu rectangle. */
menu,
popover.menu > contents {
    background-color: rgba(20, 26, 40, 0.92);
    border: 1px solid rgba(255, 255, 255, 0.12);
    border-radius: 10px 14px 11px 13px;
    box-shadow: 0 10px 32px rgba(0, 0, 0, 0.45);
    padding: 4px;
}
menuitem,
modelbutton {
    border-radius: 8px;
    padding: 6px 10px;
    transition: background-color 180ms cubic-bezier(0.5, 0, 0.75, 0);
}
menuitem:hover,
modelbutton:hover {
    background-color: rgba(255, 255, 255, 0.10);
    transition: background-color 120ms cubic-bezier(0.22, 1, 0.36, 1);
}

/* The volume/brightness/etc. on-screen bezel (.osd) as a small floating
 * glass pill, matching everything else instead of GTK's plain dark box. */
.osd {
    background-color: rgba(16, 24, 40, 0.85);
    border: 1px solid rgba(255, 255, 255, 0.14);
    border-radius: 18px 24px 20px 22px;
    box-shadow: 0 12px 36px rgba(0, 0, 0, 0.50);
}

/* Unfocused windows recede slightly — a small depth cue that makes the
 * focused window unambiguous at a glance, especially with several floating
 * glass panels/popovers on screen at once. */
window:backdrop {
    opacity: 0.96;
    transition: opacity 300ms cubic-bezier(0.5, 0, 0.75, 0);
}
window:not(:backdrop) {
    transition: opacity 180ms cubic-bezier(0.22, 1, 0.36, 1);
}

/* Linked button groups (segmented controls) read as one pill-shaped
 * control instead of GTK's default row of square-joined buttons. */
.linked > button {
    transition: background-color 200ms cubic-bezier(0.5, 0, 0.75, 0);
}
.linked > button:first-child { border-radius: 10px 0 0 10px; }
.linked > button:last-child  { border-radius: 0 10px 10px 0; }
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

window, .window-frame          { border-radius: 16px 20px 18px 22px; }
headerbar                      { border-radius: 18px 22px 0 0; }
.card, frame, .frame           { border-radius: 13px 16px 14px 17px; }
button                         { border-radius: 10px; }
entry                          { border-radius: 10px; }
popover > contents             { border-radius: 14px 18px 13px 17px; }
.sidebar-row                   { border-radius: 8px; }
listview                       { border-radius: 12px; }
notebook > header              { border-radius: 12px 12px 0 0; }
button { box-shadow: none; -gtk-icon-shadow: none; }
.suggested-action { background: @accent_bg_color; color: @accent_fg_color; border: none; }
.suggested-action:hover { background: shade(@accent_bg_color, 0.88); }
headerbar { padding: 8px 12px; min-height: 44px; }
row        { padding: 4px 8px; }
/* Same faint moss-green (#7fae86) bloom as the GTK3 panel — the one
 * deliberate nature accent, kept identical across GTK3/GTK4 so a mixed
 * Budgie+libadwaita desktop still reads as one coherent surface. */
window {
    background-image: radial-gradient(ellipse at 30% -30%,
        rgba(127, 174, 134, 0.04), transparent 65%);
}

/* KibaOS organic motion — same settle/fade/grow set as GTK3 (see
 * gtk-3.0/gtk.css for the full naming/rationale); GTK4 apps get the same
 * asymmetric feel. */
button, row, .sidebar-row, switch slider {
    transition: background-color 220ms cubic-bezier(0.5, 0, 0.75, 0),
                border-color    220ms cubic-bezier(0.5, 0, 0.75, 0);
}
button:hover, row:hover, .sidebar-row:hover {
    transition: background-color 140ms cubic-bezier(0.22, 1, 0.36, 1),
                border-color    140ms cubic-bezier(0.22, 1, 0.36, 1);
}
switch slider { transition: margin 260ms cubic-bezier(0.34, 1.56, 0.64, 1); }
popover > contents {
    transition: opacity 260ms cubic-bezier(0.16, 1, 0.3, 1); /* grow — structural reveal */
}

/* Same extra polish pass as gtk-3.0/gtk.css (see that file for the full
 * rationale on each rule) — GTK4/libadwaita apps get the same treatment
 * as Budgie's own chrome instead of looking like a different OS. */
*:focus-visible {
    outline: 2px solid rgba(0, 153, 204, 0.75);
    outline-offset: 1px;
    transition: outline-color 150ms cubic-bezier(0.22, 1, 0.36, 1);
}
tooltip {
    background-color: rgba(20, 26, 40, 0.92);
    color: #e8eef5;
    border: 1px solid rgba(255, 255, 255, 0.12);
    border-radius: 8px 12px 9px 11px;
    padding: 6px 10px;
    box-shadow: 0 6px 18px rgba(0, 0, 0, 0.45);
}
scrollbar slider {
    background-color: rgba(255, 255, 255, 0.18);
    border-radius: 999px;
    min-width: 6px;
    min-height: 6px;
    transition: background-color 200ms cubic-bezier(0.5, 0, 0.75, 0);
}
scrollbar slider:hover {
    background-color: rgba(255, 255, 255, 0.32);
    transition: background-color 130ms cubic-bezier(0.22, 1, 0.36, 1);
}
selection, *:selected {
    background-color: rgba(0, 153, 204, 0.55);
    color: #ffffff;
}
checkbutton check,
radiobutton radio {
    border-radius: 5px;
    border: 1px solid rgba(255, 255, 255, 0.28);
    background-color: rgba(255, 255, 255, 0.06);
    transition: background-color 200ms cubic-bezier(0.5, 0, 0.75, 0);
}
radiobutton radio { border-radius: 999px; }
checkbutton check:checked,
radiobutton radio:checked {
    background-color: #0099cc;
    border-color: #0099cc;
    transition: background-color 150ms cubic-bezier(0.22, 1, 0.36, 1);
}
.osd {
    background-color: rgba(16, 24, 40, 0.85);
    border: 1px solid rgba(255, 255, 255, 0.14);
    border-radius: 18px 24px 20px 22px;
    box-shadow: 0 12px 36px rgba(0, 0, 0, 0.50);
}
window:backdrop {
    opacity: 0.96;
    transition: opacity 300ms cubic-bezier(0.5, 0, 0.75, 0);
}

/* libadwaita toasts (AdwToast — the little "Undo" bar that slides up from
 * the bottom) as the same floating glass pill as everything else. */
.toast {
    background-color: rgba(20, 26, 40, 0.92);
    color: #e8eef5;
    border: 1px solid rgba(255, 255, 255, 0.14);
    border-radius: 999px;
    box-shadow: 0 10px 32px rgba(0, 0, 0, 0.45);
    padding: 4px 6px;
}
.toast button {
    border-radius: 999px;
}
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
        // emulated glass: just a solid translucent fill, no real blur.
        // labwc doesn't have a blur plugin at all (Wayfire did, sorta — see
        // LABWC CONFIG notes for the full story on why I dropped it), so
        // this fake-glass approach is doing all the work here now, not
        // just backstopping a spot where real blur wouldn't reach anyway.
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

# ── Wayland session — back to stock Budgie-on-labwc ─────────────────────
# so, funny enough, this is actually going BACK to how Budgie wants to run.
# Budgie 10.10's own package already ships /usr/share/wayland-sessions/
# budgie-desktop.desktop with Exec=labwc baked in — labwc is Budgie's
# official recommended/default Wayland compositor as of 10.10 (see
# buddiesofbudgie.org/blog/budgie-10-10-released). I'd previously deleted
# that stock file and dropped in my own budgie-wayfire.desktop to force
# Wayfire instead, chasing real compositor-level wobbly window physics
# that labwc just doesn't have (it's a deliberate design choice on their
# end — no compositor animation, period). Ripping that back out now: no
# more deleting the stock session file, no more custom .desktop, we just
# let Budgie's own packaged session do its thing.
#
# net effect: wobbly window drag and the real Kawase blur plugin are both
# gone, and there's no labwc equivalent for either — see LABWC CONFIG
# below for how that's handled (short version: gracefully dropped, not
# faked, nothing crashes because of it).
mkdir -p /usr/share/wayland-sessions

mkdir -p /etc/sddm.conf.d
cat > /etc/sddm.conf.d/kibaos.conf << 'SDDMCONF'
[General]
DisplayServer=wayland

[Wayland]
CompositorCommand=labwc

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
# LABWC CONFIG
# ══════════════════════════════════════════════════════════════════════════
# back on labwc — Budgie's own officially-supported/default compositor,
# so this gets the real integration bridge (keybinding + theme sync) that
# Wayfire never had, and it's just a way better-tested combo overall.
#
# what this costs us, said plainly: labwc has NO wobbly/jelly window
# physics and NO real compositor blur plugin, full stop — that's not a
# config knob I'm missing, it's an intentional design choice on labwc's
# end (they keep animation out of the compositor on purpose). rather than
# fake it or leave dangling references to plugins that don't exist here,
# both features are just gone: the GTK theme's motion-language comment
# above already flags where wobbly used to hook in, and the login/Raven
# glass effects fall back to the plain translucent-fill version instead
# of real Kawase blur. Kortex's compositor IPC bridge is also gone for
# the same reason — see the note where WAYFIRE IPC used to be, now
# replaced with a graceful no-op instead of a hard build/crash.
#
# unlike Wayfire, labwc DOES read a system-wide config from /etc/xdg/labwc
# as a fallback, but per-user ~/.config/labwc still wins, so — same as
# before — the actual default config gets dropped into /etc/skel and
# copied into every new user's home (liveuser, and whoever the OOBE
# installer creates).
# ── Screenshot + screenshot-OCR ──────────────────────────────────────────
# bound to Print/Shift+Print/Super+Shift+Print down in rc.xml's <keyboard>
# section below. all three copy straight to the clipboard via wl-copy (so
# paste-anywhere just works right away) as well as saving a file, and pop
# a toast to confirm — don't want a keypress silently doing something and
# leaving you wondering if it worked.
cat > /usr/local/bin/kibaos-screenshot << 'SCREENSHOT'
#!/bin/bash
# kibaos-screenshot [region] — grabs the full screen by default, or a
# user-selected region if "region" is passed as the first argument.
set -euo pipefail
OUT_DIR="$HOME/Pictures/Screenshots"
mkdir -p "$OUT_DIR"
FILE="$OUT_DIR/Screenshot from $(date '+%Y-%m-%d %H-%M-%S').png"

if [ "${1:-}" = "region" ]; then
  GEOM=$(slurp) || exit 0   # empty selection (Esc) -> exit quietly
  grim -g "$GEOM" "$FILE"
else
  grim "$FILE"
fi

wl-copy < "$FILE"
notify-send -i "$FILE" "Screenshot saved" "Copied to clipboard · $(basename "$FILE")"
SCREENSHOT
chmod +x /usr/local/bin/kibaos-screenshot

cat > /usr/local/bin/kibaos-screenshot-ocr << 'SCREENSHOTOCR'
#!/bin/bash
# kibaos-screenshot-ocr — select a region, extract its text with Tesseract,
# and put the text (not the image) on the clipboard.
set -euo pipefail
GEOM=$(slurp) || exit 0
TMP=$(mktemp --suffix=.png -t kibaos-ocr.XXXXXX)
trap 'rm -f "$TMP"' EXIT
grim -g "$GEOM" "$TMP"

TEXT=$(tesseract "$TMP" - 2>/dev/null | sed -e '$ { /^$/d }')
if [ -z "$TEXT" ]; then
  notify-send "Screenshot OCR" "No text found in that selection."
  exit 0
fi

printf '%s' "$TEXT" | wl-copy
PREVIEW=$(printf '%s' "$TEXT" | head -c 120)
notify-send "Text copied to clipboard" "${PREVIEW}$([ ${#TEXT} -gt 120 ] && echo …)"
SCREENSHOTOCR
chmod +x /usr/local/bin/kibaos-screenshot-ocr

# ── Output scale: real per-monitor DPI via wlr-randr ──────────────────────
# labwc doesn't do auto-DPI either -- outputs just default to scale 1
# unless something explicitly sets them, same story as before. runs on
# every session start (wired into the labwc autostart file below) so it
# re-applies correctly on dock/undock and monitor hotplug too, not just
# at first login. scale gets worked out from actual DPI (px / physical
# size in inches) when the monitor reports its physical dimensions over
# EDID, and falls back to a plain resolution heuristic when it doesn't
# (common on some external monitors and pretty much all VMs).
cat > /usr/local/bin/kibaos-apply-output-scale << 'OUTPUTSCALE'
#!/bin/bash
# Give the compositor a moment to enumerate outputs on cold start.
for _ in 1 2 3 4 5; do
    wlr-randr >/tmp/.kiba-outputs 2>/dev/null && [ -s /tmp/.kiba-outputs ] && break
    sleep 1
done
[ -s /tmp/.kiba-outputs ] || exit 0

current_name=""
current_w=""
current_h=""
current_mm_w=""
current_mm_h=""

apply_scale() {
    [ -n "$current_name" ] || return
    scale=1
    if [ -n "$current_mm_w" ] && [ "$current_mm_w" -gt 0 ] 2>/dev/null; then
        # DPI = px / (mm / 25.4); compare against a 168dpi HiDPI threshold.
        dpi=$(( current_w * 254 / (current_mm_w * 10) ))
        if [ "$dpi" -ge 168 ]; then
            scale=2
        fi
    elif [ -n "$current_w" ] && [ "$current_w" -ge 3000 ] 2>/dev/null; then
        # No physical size reported (VM, some externals) -- fall back to a
        # plain resolution heuristic. 4K+ panels are HiDPI in practice.
        scale=2
    fi
    wlr-randr --output "$current_name" --scale "$scale" >/dev/null 2>&1
}

while IFS= read -r line; do
    case "$line" in
        [A-Za-z]*)
            apply_scale
            current_name=$(printf '%s' "$line" | awk '{print $1}')
            current_w=""; current_h=""; current_mm_w=""; current_mm_h=""
            ;;
        *"Physical size:"*)
            # e.g. "  Physical size: 344x194 mm"
            dims=$(printf '%s' "$line" | grep -oE '[0-9]+x[0-9]+')
            current_mm_w=${dims%x*}
            current_mm_h=${dims#*x}
            ;;
        *"current"*)
            # e.g. "  1920x1080 px, 60.000000 Hz (current)"
            dims=$(printf '%s' "$line" | grep -oE '^[[:space:]]*[0-9]+x[0-9]+' | tr -d ' ')
            current_w=${dims%x*}
            current_h=${dims#*x}
            ;;
    esac
done < /tmp/.kiba-outputs
apply_scale
rm -f /tmp/.kiba-outputs
OUTPUTSCALE
chmod +x /usr/local/bin/kibaos-apply-output-scale

# SKEL gets defined here (instead of waiting for the "SKELETON" section
# further down) because this is its first real use: the labwc config gets
# written to /etc/skel so it's copied into every new user's home
# (liveuser, and anyone the OOBE installer creates). SKEL used to not get
# set until way later in the script, so under `set -ex` (no -u) it just
# silently expanded to an empty string here, and the config was written to
# /.config instead of /etc/skel/.config — meaning nobody actually got it,
# nothing autostarted budgie-desktop, gray screen and giant cursor on a
# bare compositor. The later "SKELETON" section still re-assigns
# SKEL="/etc/skel" too — redundant now, but harmless, so left as-is.
SKEL="/etc/skel"
mkdir -p "${SKEL}/.config/labwc"

# rc.xml — labwc's main config: window rules, theme geometry, keybinds.
# no [core] plugin list like wayfire.ini had, because labwc doesn't have
# plugins at all — it's one static binary with a fixed feature set, on
# purpose. virtual desktop count replaces Wayfire's vwidth/vheight grid.
cat > "${SKEL}/.config/labwc/rc.xml" << 'LABWCRC'
<?xml version="1.0"?>
<labwc_config>
  <core>
    <gap>0</gap>
  </core>

  <desktops>
    <number>4</number>
  </desktops>

  <!-- border colors as plain hex, unlike Wayfire's decoration plugin which
       needed 0.0-1.0 floats -- #1a2030 active, #232b3a inactive, same
       values as before, just a saner format this time -->
  <theme>
    <name>kibaos</name>
    <titlebar>
      <height>0</height>
    </titlebar>
    <border>
      <width>1</width>
    </border>
  </theme>

  <!-- Print = full-screen screenshot, Shift+Print = region screenshot,
       both go to the clipboard + ~/Pictures/Screenshots. Super+Shift+Print
       = region -> OCR -> text on the clipboard (see the two scripts
       written just above). -->
  <keyboard>
    <keybind key="Print">
      <action name="Execute" command="kibaos-screenshot"/>
    </keybind>
    <keybind key="S-Print">
      <action name="Execute" command="kibaos-screenshot region"/>
    </keybind>
    <keybind key="W-S-Print">
      <action name="Execute" command="kibaos-screenshot-ocr"/>
    </keybind>
  </keyboard>
</labwc_config>
LABWCRC

# themerc-override — labwc's flat-file theme knobs, separate from rc.xml.
# this is where the active/inactive titlebar colors actually live (rc.xml
# only points at a theme NAME). plain hex, no float conversion needed.
mkdir -p "${SKEL}/.config/labwc/themes/kibaos"
cat > "${SKEL}/.config/labwc/themes/kibaos/themerc" << 'LABWCTHEME'
window.active.border.color: #1a2030
window.inactive.border.color: #232b3a
window.active.title.bg.color: #1a2030
window.inactive.title.bg.color: #232b3a
LABWCTHEME

# autostart — labwc's equivalent of Wayfire's [autostart] section, just a
# plain shell script labwc sources on session start. THIS is what
# actually launches Budgie now instead of Wayfire's autostart_budgie line
# -- without it, labwc boots to a totally empty compositor, same
# load-bearing deal as before. no [idle] plugin equivalent to disable
# here, because labwc doesn't blank the screen on its own in the first
# place -- that'd be swayidle's job, and swayidle is installed but
# deliberately never invoked anywhere in this image, so idle/DPMS
# blanking mid-install just isn't a thing that can happen. simplest fix
# available: don't run the thing that would cause the problem.
cat > "${SKEL}/.config/labwc/autostart" << 'LABWCAUTOSTART'
#!/bin/bash
kibaos-apply-output-scale &
budgie-desktop &
LABWCAUTOSTART
chmod +x "${SKEL}/.config/labwc/autostart"

# environment — plain KEY=VALUE, sourced into the session before autostart
# runs. wayfire.ini had no equivalent of this since it was one flat INI
# file; labwc splits config into rc.xml/environment/autostart on purpose.
cat > "${SKEL}/.config/labwc/environment" << 'LABWCENV'
XDG_CURRENT_DESKTOP=Budgie:GNOME
LABWCENV

# ══════════════════════════════════════════════════════════════════════════
# COMPOSITOR IPC — none, on purpose, and that's fine
# ══════════════════════════════════════════════════════════════════════════
# this whole section used to be a from-source build of wayfire-plugins-
# extra (ipc/ipc-rules, AUR-only, plus a pinned wayfire downgrade just to
# get it compiling) so Kortex could talk to Wayfire's IPC socket via
# `wfctl` for live window-focus/launch/move events. labwc has nothing
# like that — no IPC socket, no plugin system to add one, nothing to
# build here at all. so none of that happens anymore: no meson/ninja
# build, no wayfire version pin, no wfctl pip install.
#
# Kortex itself already knows how to handle this gracefully (see
# WindowEventSource in core.py) — on labwc it just detects there's no
# WAYFIRE_SOCKET/wfctl available, logs that it's running without a
# compositor event feed, and quietly disables the window-tracking
# features that depended on it instead of crashing or busy-looping
# looking for a socket that will never show up. Everything else Kortex
# does (usage prediction, break reminders, driver/service auto-repair)
# doesn't touch this and keeps working exactly the same.
echo "=== Skipping compositor IPC build — labwc has no IPC, Kortex degrades gracefully ==="

# ══════════════════════════════════════════════════════════════════════════
# A/B ROOT + SYSUPDATE INFRASTRUCTURE — stays removed; OTA is back, but
# as a file-level live patcher, not a root-image swap
# ══════════════════════════════════════════════════════════════════════════
# Used to live here: a systemd-repart rule carving a second root-b
# partition out of space the installer reserved for it, systemd-sysupdate
# config pointing at signed root images, kibaos-uki-slot-sync building a
# per-slot UKI, and kibaos-sysupdate-apply running inside
# system-update.target to do the atomic root-b write + slot flip. That
# whole design is still gone -- the installer gives root all the space
# on the disk (see the root_sectors comment in
# kibaos_oobe_backend_main.c's erase-mode branch), there's no root-b to
# repart into existence, and no per-slot UKI naming (just plain
# kibaos+3.efi now).
#
# What's back below is the older, simpler kibaos-ota: it doesn't touch
# partitions or UKIs at all -- it downloads a signed tarball of changed
# files, verifies it, and replaces them on the live root one at a time,
# keeping a backup of whatever it overwrote so kortex's rollback_config
# action (see kortex-helper) can undo the last patch on request. No
# slot to flip, no second root to keep in sync -- just files going in
# and a copy of the old ones sitting in /var/lib/kibaos-ota if something
# needs to come back.
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
# Runs as root via systemd timer — never visible to the user. Also
# callable directly as `kibaos-ota rollback --reason "..."` by kortex's
# kortex-helper (see rollback_config) to undo the most recent patch.

set -euo pipefail

OTA_BASE="https://sourceforge.net/projects/kibaos/files/ota"
OTA_KEYRING="/etc/kibaos/ota-keyring.gpg"
PATCH_LEVEL_FILE="/etc/kibaos/patch-level"
OTA_WORKDIR="/var/lib/kibaos-ota"
OTA_LOG="/var/log/kibaos/ota.log"
FREEZE_PID_FILE="/tmp/kibaos-fb-freeze.pid"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "${OTA_LOG}"; }

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
# labwc has no documented "reconfigure" signal we can rely on across every
# plugin/config combination, so — same call the Wayfire build used to make
# for the same reason — this restarts the whole greeter/session rather than
# gambling on an in-place reload inside an unattended OTA patcher. Slower,
# but it won't leave the user stuck on a half-reloaded compositor.
restart_compositor() {
  log "Restarting session..."
  systemctl restart sddm 2>/dev/null || \
  pkill -TERM labwc 2>/dev/null || true
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
# CLI ROLLBACK — `kibaos-ota rollback --reason "..."`
# ══════════════════════════════════════════════════════════════════════════
# This is the path kortex's rollback_config action (kortex-helper) shells
# out to. It's independent of the unattended timer flow below: the timer
# always invokes this script bare, with no arguments, and never hits this
# branch. Restores whatever the most recent applied patch overwrote, from
# the backup apply_patch() kept alongside it — there's nothing to undo if
# no patch has landed yet, so that's reported rather than silently no-op'd.
if [ "${1:-}" = "rollback" ]; then
  shift || true
  REASON="kortex:unspecified"
  while [ $# -gt 0 ]; do
    case "${1:-}" in
      --reason) REASON="${2:-${REASON}}"; shift 2 || break ;;
      *) shift ;;
    esac
  done
  CURRENT=$(cat "${PATCH_LEVEL_FILE}" 2>/dev/null || echo 0)
  log "Manual rollback requested (reason: ${REASON})"
  if [ -d "${OTA_WORKDIR}/rollback-${CURRENT}" ]; then
    fb_freeze
    rollback_patch
    restart_compositor
    restart_display_manager
    fb_unfreeze
    log "Manual rollback finished."
    exit 0
  else
    log "No rollback data available for patch level ${CURRENT}. Nothing to roll back."
    exit 1
  fi
fi

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
    usr/bin/labwc*)
      # labwc.ini/rc.xml/autostart all live per-user under ~/.config/labwc,
      # seeded from /etc/skel at account creation, same story Wayfire's
      # wayfire.ini used to have. An OTA patch to the skel copy only
      # affects NEWLY created users from that point on -- it can't
      # retroactively update already-installed users' own configs. Only
      # the labwc binary itself triggers a restart here.
      NEEDS_COMPOSITOR_RESTART=true ;;
  esac
done < "${MANIFEST}"

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
# FIRST-BOOT GROUP CATCHUP
# The installer defers any -G group that doesn't exist yet at install time
# (docker is the known case: its group only shows up once systemd-sysusers
# actually runs against the installed system, not the image-capture
# snapshot) and records it in /etc/kibaos/pending-user-groups as
# "username:group1,group2". This runs after sysusers on first boot, adds
# the user to whatever's now available, and cleans up after itself so it's
# a no-op on every boot after the first.
# ══════════════════════════════════════════════════════════════════════════
cat > /usr/local/bin/kibaos-firstboot-groups << 'FIRSTBOOTGROUPS'
#!/usr/bin/env bash
set -euo pipefail
MARKER="/etc/kibaos/pending-user-groups"
[ -f "$MARKER" ] || exit 0

while IFS=: read -r username groups; do
    [ -n "$username" ] || continue
    IFS=',' read -ra group_arr <<< "$groups"
    add_groups=()
    for g in "${group_arr[@]}"; do
        if getent group "$g" > /dev/null 2>&1; then
            add_groups+=("$g")
        else
            echo "kibaos-firstboot-groups: '$g' still doesn't exist, leaving pending" >&2
        fi
    done
    if [ "${#add_groups[@]}" -gt 0 ]; then
        joined=$(IFS=,; echo "${add_groups[*]}")
        usermod -aG "$joined" "$username" \
            && echo "kibaos-firstboot-groups: added $username to $joined" \
            || echo "kibaos-firstboot-groups: usermod failed for $username" >&2
    fi
done < "$MARKER"

# Only remove the marker once every listed group actually got processed --
# if getent still couldn't find something, leave the file so the next boot
# retries it instead of silently dropping that membership forever.
if ! grep -qE ':.*[a-zA-Z]' "$MARKER" 2>/dev/null || \
   ! awk -F: '{print $2}' "$MARKER" | tr ',' '\n' | while read -r g; do
       [ -n "$g" ] && ! getent group "$g" > /dev/null 2>&1 && exit 1
   done; then
    : # some group still missing -- keep retrying on future boots
else
    rm -f "$MARKER"
fi
FIRSTBOOTGROUPS
chmod +x /usr/local/bin/kibaos-firstboot-groups

cat > /etc/systemd/system/kibaos-firstboot-groups.service << 'FIRSTBOOTSVC'
[Unit]
Description=KibaOS first-boot group catch-up (docker, etc.)
After=systemd-sysusers.service
Wants=systemd-sysusers.service
ConditionPathExists=/etc/kibaos/pending-user-groups

[Service]
Type=oneshot
ExecStart=/usr/local/bin/kibaos-firstboot-groups
RemainAfterExit=no

[Install]
WantedBy=multi-user.target
FIRSTBOOTSVC

systemctl enable kibaos-firstboot-groups.service

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

# ── Panel config, schema verified straight from upstream source ──────────
# (src/panel/manager.vala, BuddiesOfBudgie/budgie-desktop main branch), so
# this isn't a guess:
#   ROOT_SCHEMA      = com.solus-project.budgie-panel          (hyphenated!)
#   TOPLEVEL_PREFIX  = /com/solus-project/budgie-panel/panels
#   PANEL_KEY_POSITION    = "location"       (not "position")
#   PANEL_KEY_SHADOW      = "enable-shadow"  (not "shadow")
#   PANEL_KEY_APPLETS     = "applets"        (flat ordered UUID list)
# the previous version of this block was using
# "com.solus-project.budgie.panel" (dotted) with keys "position"/"shadow"
# — neither that schema nor those key names actually exist upstream, so
# those dconf writes were almost certainly a silent no-op this whole
# time, not configuring anything at all.
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
# Budgie's icon-tasklist applet will PERMANENTLY crash the session on
# every future login if pinned-launchers points at a .desktop file that
# doesn't actually exist (solus-project/budgie-desktop#1480 — confirmed
# this happens, not a maybe). so: probe the real filesystem for whichever
# desktop-id variant actually got installed, instead of hardcoding a
# guess and hoping it's right.
find_desktop_id() {
  for candidate in "$@"; do
    [ -f "/usr/share/applications/${candidate}" ] && { echo "${candidate}"; return 0; }
  done
  return 1
}
DOCK_LAUNCHERS=()
for ids in \
  "kibaos-files.desktop nemo.desktop" \
  "org.gnome.Calendar.desktop gnome-calendar.desktop" \
  "org.gnome.Notes.desktop bijiben.desktop gnome-notes.desktop" \
  "org.gnome.eog.desktop eog.desktop" \
  "org.gnome.Geary.desktop geary.desktop" \
  "org.gnome.Music.desktop gnome-music.desktop" \
  "org.gnome.Todo.desktop gnome-todo.desktop"
do
  FOUND=$(find_desktop_id ${ids}) && DOCK_LAUNCHERS+=("${FOUND}")
done

# each applet UUID needs two things written: (1) a generic "which plugin
# is this UUID" lookup entry, and (2) that plugin's OWN settings at ITS
# OWN settings-prefix. (1) I got by direct structural analogy to the
# now-confirmed TOPLEVEL_SCHEMA/TOPLEVEL_PREFIX pattern above — haven't
# directly observed this exact const in source the way I did for the
# panel schema, so flagging it as the one remaining inferential step if
# applets don't show up. (2) for icon-tasklist specifically IS directly
# confirmed: Budgie's own docs give the Budgie Menu applet's
# settings-prefix as /com/solus-project/budgie-panel/instance/budgie-menu/
# {uuid}, same pattern applies to icon-tasklist's instance path below.
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
# the temporary 'oem' autologin account kibaos-oem-prepare sets up. a
# plain Exec= can't conditionally skip launching, so the condition gets
# wrapped in a one-line shell test instead — on a normal (non-OEM)
# install this marker never exists, so the test just fails and nothing
# launches. ───────────────────────────────────────────────────────────
cat > "${SKEL}/.config/autostart/kibaos-oem-finish.desktop" << 'OEMAUTOCFG'
[Desktop Entry]
Type=Application
Name=Finish Setting Up KibaOS
Exec=sh -c 'test -f /etc/kibaos/oem-pending && exec /usr/bin/io.kibaos.oobe'
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
OEMAUTOCFG

# ══════════════════════════════════════════════════════════════════════════
# WINDOWS APP SUPPORT (WinApps) — file-manager integration + first-login
# setup wizard. Package deps (docker, freerdp, dialog, zenity, pciutils,
# etc.) are in packages.x86_64; the winapps-org/winapps repo itself is
# vendored above at ${WINAPPS_SRC}. Both the disk installer
# (kibaos-oobe-backend) and OEM-finish (kibaos-oem-finish.sh) always drop
# /etc/kibaos/winapps-pending on completion — this is a listed, always-on
# feature, not opt-in, so unlike the oem-pending marker it mirrors, nothing
# ever leaves it unset. The marker's what triggers kibaos-winapps-setup on
# first login (see kibaos-winapps-firstrun.desktop below); the user can
# also launch it manually via "Set Up Windows Apps" in the app menu any
# time, e.g. to retry after a failed first attempt.
# ══════════════════════════════════════════════════════════════════════════

# A KibaOS-branded icon for the exe-runner + app-menu entry, pulled from the
# vendored repo's own installer art instead of drawing something new.
install -Dm644 "${WINAPPS_SRC}/install/windows.svg" \
  /usr/share/icons/hicolor/scalable/apps/kibaos-winapps.svg 2>/dev/null || true
gtk-update-icon-cache -f /usr/share/icons/hicolor 2>/dev/null || true

# ── The Windows workspace launcher ──────────────────────────────────────
# Rather than routing individual .exe files through WinApps' RAIL
# integration, this opens the whole Windows environment as one fullscreen
# workspace via its noVNC web console -- simpler mental model for the
# person (one window called "Windows", not per-app RDP plumbing) and
# avoids RAIL edge cases with apps WinApps didn't detect/configure.
cat > /usr/local/bin/kibaos-winapps-workspace << 'WORKSPACE'
#!/bin/bash
# Opens the Windows VM's noVNC console fullscreen. If setup hasn't run
# yet, offers to run it first instead of just opening a browser tab to
# nothing -- same "never dead-end without explanation" rule as before.
CONF_DIR="${HOME}/.config/winapps"
COMPOSE_FILE="${CONF_DIR}/compose.yaml"
RC_XML="${HOME}/.config/labwc/rc.xml"
RC_XML_BAK="${RC_XML}.winapps-workspace-bak"
TEMPBIND_MARKER="kibaos-winapps-workspace-tempbind"
HINT_MARKER="${HOME}/.config/kibaos/.winapps-workspace-hint-shown"
WIN_URL="http://localhost:8006"

if [ ! -f "${COMPOSE_FILE}" ]; then
  zenity --question --title="Windows Apps Aren't Set Up Yet" \
    --text="This computer isn't set up to run Windows programs yet.\n\nWant to set it up now? It takes about 15–20 minutes." \
    --ok-label="Set It Up" --cancel-label="Not Now" 2>/dev/null
  if [ "$?" -eq 0 ]; then
    exec /usr/local/bin/kibaos-winapps-setup --manual-launch
  fi
  exit 1
fi

# ── Single-instance guard ────────────────────────────────────────────────
# Clicking the desktop icon a second time while the workspace is already
# open used to spin up a second chromium --kiosk window and re-run
# `docker compose up` (harmless, but pointless and slow) instead of just
# getting the person back to the window they already have. xdotool is
# already vendored for Kortex's placement rules, so this reuses it rather
# than adding a new dependency: search for a window whose class matches
# chromium's --app= kiosk instance, and if one exists, just raise/focus
# it and exit immediately -- no compose, no pkexec, no wait, no chromium
# relaunch.
EXISTING_WIN="$(xdotool search --class "^chromium.*8006$|^Chromium.*8006$" 2>/dev/null | head -n1)"
if [ -z "${EXISTING_WIN}" ]; then
  # --app= windows aren't always classed by URL depending on chromium
  # version -- fall back to matching by window name instead.
  EXISTING_WIN="$(xdotool search --name "localhost:8006" 2>/dev/null | head -n1)"
fi
if [ -n "${EXISTING_WIN}" ]; then
  xdotool windowactivate "${EXISTING_WIN}" 2>/dev/null
  exit 0
fi

reload_labwc() {
  local pid
  pid="$(pgrep -x labwc | head -n1)"
  [ -n "${pid}" ] && kill -HUP "${pid}" 2>/dev/null || true
}

KEYBIND_ADDED=0
add_keybind() {
  # Super+K minimizes the fullscreen Windows window back to the desktop --
  # bound only while this workspace is actually open, not a permanent
  # shortcut. Backs up rc.xml, patches a keybind in just before the
  # closing </keyboard> tag, and SIGHUPs labwc to pick it up live (same
  # reload mechanism Kortex's own placement rules use).
  if [ -f "${RC_XML}" ] && ! grep -q "${TEMPBIND_MARKER}" "${RC_XML}"; then
    cp "${RC_XML}" "${RC_XML_BAK}"
    sed -i "s#</keyboard>#  <!-- ${TEMPBIND_MARKER} -->\n    <keybind key=\"W-k\">\n      <action name=\"Iconify\"/>\n    </keybind>\n  </keyboard>#" "${RC_XML}"
    reload_labwc
    KEYBIND_ADDED=1
  fi
}

# Runs on ANY exit from this point on -- normal chromium close, the user
# killing the window some other way, or this script itself dying. Without
# a trap, only the "chromium closed normally" path put the keybind back,
# so a killed session could permanently leave Super+K bound to Iconify.
cleanup() {
  if [ "${KEYBIND_ADDED}" -eq 1 ] && [ -f "${RC_XML_BAK}" ]; then
    mv "${RC_XML_BAK}" "${RC_XML}"
    reload_labwc
  fi
}
trap cleanup EXIT

# ── Skip the auth prompt when it's already running ─────────────────────
# `pkexec docker compose up -d` used to run unconditionally on every
# launch -- idempotent, sure, but that still means a polkit password
# prompt every single time someone reopens the workspace, even when the
# container's been sitting there running the whole time (e.g. they
# minimized with Super+K, closed the window some other way, then clicked
# the icon again a minute later). Checking whether noVNC is already
# answering first means the extremely common "it's already up" case
# skips pkexec, docker compose, and the progress dialog entirely and
# goes straight to reopening chromium.
ALREADY_UP=0
if curl -fsS -o /dev/null --max-time 2 "${WIN_URL}" 2>/dev/null; then
  ALREADY_UP=1
fi

if [ "${ALREADY_UP}" -eq 0 ]; then
  # docker compose up is idempotent -- safe to run even if the container's
  # already up (e.g. the curl check above raced a container that was
  # still finishing its own startup), and covers the case where it's
  # stopped since last boot. Runs in the background so the "starting up"
  # dialog below can show right away instead of the whole launch
  # appearing to hang on the pkexec prompt.
  ( cd "${CONF_DIR}" && pkexec docker compose up -d ) >/dev/null 2>&1 &
  COMPOSE_PID=$!

  # The container can take a few seconds (or longer, first boot after a
  # reboot) before noVNC is actually answering on 8006. Opening chromium
  # immediately used to race that -- landing the person on a browser
  # "connection refused" page with no explanation, which looks broken even
  # though nothing's actually wrong. Wait for a real HTTP response rather
  # than just the TCP port accepting a connection -- noVNC's port can
  # start accepting TCP connections slightly before it's actually serving
  # the console page, which was still enough to show a half-loaded blank
  # page for a moment. A visible, cancellable progress dialog stays on
  # screen the whole time either way, so there's always something on
  # screen that makes sense.
  (
    for i in $(seq 1 60); do
      curl -fsS -o /dev/null --max-time 1 "${WIN_URL}" 2>/dev/null && break
      sleep 1
      echo "$((i * 100 / 60))"
    done
    echo "100"
  ) | zenity --progress --title="Windows" --text="Starting your Windows workspace…" \
      --pulsate --auto-close --no-cancel --width=360 2>/dev/null

  wait "${COMPOSE_PID}"
  COMPOSE_STATUS=$?

  if ! curl -fsS -o /dev/null --max-time 2 "${WIN_URL}" 2>/dev/null; then
    if [ "${COMPOSE_STATUS}" -ne 0 ]; then
      zenity --error --title="Windows" --width=420 \
        --text="Windows didn't start. Try again in a moment, or open 'Set Up Windows Apps' from the app menu if this keeps happening." 2>/dev/null
    else
      zenity --error --title="Windows" --width=420 \
        --text="Windows is taking longer than usual to come up. Give it a bit and try 'Run Windows Workspace' again -- nothing's broken, it just needs more time." 2>/dev/null
    fi
    exit 1
  fi
fi

add_keybind

# First time this workspace opens on this account, say what Super+K does
# up front -- it's the only way out of a fullscreen kiosk window, and
# nothing else on screen hints it exists.
if [ "${KEYBIND_ADDED}" -eq 1 ] && [ ! -f "${HINT_MARKER}" ]; then
  mkdir -p "$(dirname "${HINT_MARKER}")"
  touch "${HINT_MARKER}"
  notify-send -i kibaos-winapps "Windows Workspace" \
    "Tip: press Super+K any time to minimize this and get back to your desktop." 2>/dev/null || \
    zenity --info --title="Windows" --width=380 \
      --text="Tip: press Super+K any time to minimize this and get back to your desktop." 2>/dev/null
fi

chromium --kiosk --app="${WIN_URL}" 2>/dev/null
# cleanup() runs automatically via the EXIT trap above.
WORKSPACE
chmod +x /usr/local/bin/kibaos-winapps-workspace

cat > /usr/share/applications/kibaos-winapps-workspace.desktop << 'WORKSPACEDESKTOP'
[Desktop Entry]
Type=Application
Name=Run Windows Workspace
Comment=Open the Windows environment full-screen
Icon=kibaos-winapps
Exec=/usr/local/bin/kibaos-winapps-workspace
Terminal=false
NoDisplay=false
Categories=System;
WORKSPACEDESKTOP

# Also drop it as a desktop icon, not just an app-menu entry -- this is
# meant to be the person's main "open Windows" door, so it should be
# reachable without digging into the menu. Written into skel so it lands
# on every new account's desktop, same as the rest of this section.
mkdir -p "${SKEL}/Desktop"
cp /usr/share/applications/kibaos-winapps-workspace.desktop \
  "${SKEL}/Desktop/kibaos-winapps-workspace.desktop"
chmod +x "${SKEL}/Desktop/kibaos-winapps-workspace.desktop"

# ── The setup wizard itself ─────────────────────────────────────────────
# Written entirely in plain language on purpose — this is the one part of
# KibaOS setup that talks about Docker, RDP ports, and VMs under the
# hood, none of which the person running it should ever need to know.
# Re-runnable: launching it again after a successful setup just re-opens
# the "everything's already working" summary instead of redoing anything.
cat > /usr/local/bin/kibaos-winapps-setup << 'WINAPPSSETUP'
#!/bin/bash
set -uo pipefail

WINAPPS_SRC="/opt/kibaos/winapps-src"
CONF_DIR="${HOME}/.config/winapps"
COMPOSE_FILE="${CONF_DIR}/compose.yaml"
MARKER="/etc/kibaos/winapps-pending"
MANUAL_LAUNCH="${1:-}"

notify() { zenity --info --title="Windows Apps" --text="$1" --width=420 2>/dev/null; }
ask()    { zenity --question --title="Windows Apps" --text="$1" \
             --ok-label="${2:-Yes}" --cancel-label="${3:-No}" --width=420 2>/dev/null; }
err()    { zenity --error --title="Windows Apps" --text="$1" --width=420 2>/dev/null; }

# Group membership in /etc/group only takes effect for *new* login
# sessions, not the one you're already in -- and the OEM-finish flow in
# particular can land someone straight into a desktop session for the
# account that was *just* created, marker and all, with docker group
# membership on disk but not yet in this session's token. Rather than
# make the user log out and back in for what looks like a broken feature,
# re-exec once with the docker group active (see below) if the account
# is a docker-group member on disk but this shell doesn't have it active
# yet. WINAPPS_REGROUPED guards against ever doing this twice.
if [ -z "${WINAPPS_REGROUPED:-}" ] \
   && id -nG "${USER:-$(id -un)}" 2>/dev/null | tr ' ' '\n' | grep -qx docker \
   && ! groups 2>/dev/null | tr ' ' '\n' | grep -qx docker; then
  export WINAPPS_REGROUPED=1
  # `sg` (which used to do this in one shot, no TTY required) no longer
  # ships on Arch -- it's gone from both `shadow` and `util-linux` as of
  # current package file lists, `newgrp` is util-linux's now. `newgrp`
  # normally replaces the shell interactively, but feeding it a command
  # over stdin (rather than a TTY) makes it run that command
  # non-interactively in the new group and then exit, which is the
  # standard script idiom for this. `exec` here still replaces this
  # process rather than nesting another layer of shell.
  exec newgrp docker <<NEWGRPCMD
"$0" ${MANUAL_LAUNCH}
NEWGRPCMD
fi

# Already fully set up? Just say so and offer a normal re-check.
if command -v winapps >/dev/null 2>&1 && [ -f "${CONF_DIR}/winapps.conf" ]; then
  notify "Windows app support is already set up on this computer.\n\nOpen 'Run Windows Workspace' from the app menu or desktop to use Windows full-screen, or find your installed Windows programs in the app menu."
  rm -f "${MARKER}"
  exit 0
fi

# Docker already installed and the Windows container already created from
# a prior attempt (compose.yaml exists), just not finished (setup.sh
# never completed, or the RDP wait timed out last time)? That means
# someone already said yes to this once -- resume instead of asking the
# "want to set this up" question all over again every time this runs.
RESUMING=0
if command -v docker >/dev/null 2>&1 && [ -f "${COMPOSE_FILE}" ]; then
  RESUMING=1
fi

# WinApps is a listed, always-on KibaOS feature, not an opt-in add-on
# (see the WINDOWS APP SUPPORT header above) -- so first-login setup goes
# straight ahead instead of asking permission for something that's not
# actually optional. This still isn't silent: the notify below tells the
# person what's happening and where to watch it, they just don't have to
# click a button to agree to a feature that's already part of KibaOS.
# Manually re-launching from "Run Windows Workspace" already implies
# consent (that's an explicit, deliberate click), so there's nothing left
# to ask there either.
if [ "${RESUMING}" -eq 1 ]; then
  notify "Picking up where Windows app setup left off. This window will let you know once it's ready -- you can also watch progress at localhost:8006 in your browser."
else
  notify "Setting up Windows app support now, so you can run Windows programs (like Office) right from KibaOS.\n\nHere's what's about to happen:\n\n1. KibaOS turns on the background service that runs Windows.\n2. Windows installs itself completely automatically — nothing to click through, just a wait.\n3. This window will let you know once it's ready. It typically takes 15-20 minutes, mostly just downloading and installing, and needs a spare 30+ GB of disk space.\n\nIf you're curious, you can watch progress at localhost:8006 in your browser, but you don't need to do anything there."
fi

pkexec systemctl enable --now docker >/dev/null 2>&1
if ! systemctl is-active --quiet docker; then
  err "KibaOS couldn't start the background service Windows apps need (Docker). Check /var/log for details, or try again later from the app menu."
  exit 1
fi

mkdir -p "${CONF_DIR}"
if [ ! -f "${COMPOSE_FILE}" ]; then
  cp "${WINAPPS_SRC}/compose.yaml" "${COMPOSE_FILE}"
  # compose.yaml references "./oem" as a relative bind-mount source (for
  # post-install RDPApps.reg / install.bat execution inside the guest).
  # That path resolves relative to the directory `docker compose` is run
  # from -- CONF_DIR, not WINAPPS_SRC -- so the oem/ folder has to be
  # copied alongside compose.yaml or the bind mount has nothing to point
  # at and `docker compose up -d` fails before the container is created.
  cp -r "${WINAPPS_SRC}/oem" "${CONF_DIR}/oem"
  # WinApps' docker backend (dockur/windows under the hood) installs
  # Windows completely unattended using whatever USERNAME/PASSWORD is
  # baked into compose.yaml at container creation -- there's no
  # interactive "create your account" step like real Windows Setup, and
  # changing these after the fact means tearing down and recreating the
  # VM. Left at the upstream sample values (MyWindowsUser /
  # MyWindowsPassword), that's a weak, publicly documented password --
  # and per WinApps' own docs, an empty/default password can make Windows
  # auto-login in a way that breaks the RDP handshake WinApps needs.
  #
  # Rather than a random 24-char string the person is never shown (and
  # so can never actually type in if they ever need to log into the
  # Windows console directly -- e.g. after a UAC prompt or a session
  # lock), reuse the same password they already log into KibaOS with.
  # One password to remember, not two. kiba_install_create_user() (disk
  # installs) and kibaos-oem-finish.sh (OEM-imaged devices) both stash it
  # root-only and one-time-use, right after account creation, for
  # exactly this. Read it via pkexec (it's 0600 root:root) and delete
  # the stash the moment it's read, so it never sits around longer than
  # this single read needs it to.
  WIN_USER="KibaUser"
  WIN_PASS=""
  STASH="/etc/kibaos/winapps-userpass"
  if pkexec test -f "${STASH}" 2>/dev/null; then
    WIN_PASS="$(pkexec cat "${STASH}" 2>/dev/null)"
    pkexec rm -f "${STASH}" 2>/dev/null || true
  fi
  # Falls back to asking directly if the stash is missing (setup run long
  # after install, e.g. the Linux password's since been changed) or too
  # short for Windows' own unattended-install minimum. Looped so a too-
  # short retry doesn't just silently continue with a rejected password.
  while [ -z "${WIN_PASS}" ] || [ "${#WIN_PASS}" -lt 8 ]; do
    WIN_PASS="$(zenity --password --title="Set a Windows Password" 2>/dev/null)"
    if [ -z "${WIN_PASS}" ]; then
      err "Windows app support needs a password to finish setting up. Try again from the app menu when you're ready."
      exit 1
    fi
    if [ "${#WIN_PASS}" -lt 8 ]; then
      notify "That password's a bit short -- Windows needs at least 8 characters. Try again."
    fi
  done
  # Rewritten line-by-line rather than with sed/awk substitution -- the
  # password can contain characters (/, &, \) that sed and awk both treat
  # as special in a replacement string, which would silently corrupt the
  # line for anyone whose Linux password has one. printf '%s' never
  # reinterprets its argument, so this is the one substitution method
  # that's actually safe for an arbitrary user-chosen password.
  COMPOSE_TMP="$(mktemp)"
  while IFS= read -r line; do
    if [[ "${line}" =~ ^([[:space:]]*)USERNAME:[[:space:]]* ]]; then
      printf '%sUSERNAME: "%s"\n' "${BASH_REMATCH[1]}" "${WIN_USER}"
    elif [[ "${line}" =~ ^([[:space:]]*)PASSWORD:[[:space:]]* ]]; then
      printf '%sPASSWORD: "%s"\n' "${BASH_REMATCH[1]}" "${WIN_PASS}"
    else
      printf '%s\n' "${line}"
    fi
  done < "${COMPOSE_FILE}" > "${COMPOSE_TMP}"
  mv "${COMPOSE_TMP}" "${COMPOSE_FILE}"
  # Default to Tiny11 rather than stock Windows 11 -- this box's whole
  # audience is "cheap/low-RAM laptop running KibaOS", and stock Win11
  # inside dockur/windows wants noticeably more RAM/disk headroom than
  # this hardware class tends to have to spare on top of the Linux host
  # itself. Only rewrites VERSION if the line exists in upstream's
  # compose.yaml as shipped -- if they ever restructure it, this just
  # quietly no-ops instead of corrupting the file.
  sed -i "s/^\([[:space:]]*VERSION:[[:space:]]*\).*/\1\"tiny11\"/" "${COMPOSE_FILE}"
  chmod 600 "${COMPOSE_FILE}"
fi

# GPU passthrough, auto-detected -- no user prompt for this, it either
# helps or it's a no-op. Only NVIDIA is handled: that's the only vendor
# WinApps' docker/podman backend can pass through today (via the NVIDIA
# Container Toolkit's CDI/legacy runtime), since it needs a driver stack
# installed *inside* the Windows guest anyway, which only NVIDIA ships in
# a form that works headless like this.
#
# Two separate checks, both required:
#   1. lspci -- is there NVIDIA hardware at all.
#   2. docker info -- is the "nvidia" container runtime actually
#      registered, meaning the NVIDIA Container Toolkit is installed and
#      the proprietary driver is loaded on the host.
# Hardware alone isn't enough: plenty of machines have an NVIDIA card
# sitting there on nouveau with no proprietary driver installed, and
# requesting a device reservation docker can't satisfy makes the whole
# "docker compose up" fail outright rather than just skip GPU passthrough.
#
# `docker info` (and `docker compose` below) talk to the Docker daemon's
# socket, which is root-owned. The `sg docker` re-exec earlier only fixes
# up *this shell's* group token, and that's not enough on its own if group
# membership isn't actually granting socket access -- plenty of reports of
# a rootful Docker/Podman only being visible to root, group membership or
# not. Elevate these two calls with pkexec rather than assume the group
# path works. pkexec resets the environment, so $HOME (and therefore any
# path derived from it, like CONF_DIR/COMPOSE_FILE) must NOT be re-derived
# inside the elevated command -- it has to be the already-resolved
# absolute path from this unprivileged part of the script, passed straight
# through as an argument.
COMPOSE_ARGS=(--file "${COMPOSE_FILE}")
GPU_DETECTED=0
if lspci -nnk 2>/dev/null | grep -qi 'nvidia' \
   && pkexec docker info 2>/dev/null | grep -qi 'nvidia'; then
  OVERRIDE_FILE="${CONF_DIR}/compose.override.yaml"
  cat > "${OVERRIDE_FILE}" << 'GPUOVERRIDE'
services:
  windows:
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: all
              capabilities: ["gpu"]
GPUOVERRIDE
  COMPOSE_ARGS+=(--file "${OVERRIDE_FILE}")
  GPU_DETECTED=1
fi

# cd happens *before* pkexec, not inside a command it elevates -- cwd is
# inherited across fork/exec same as any other child process, so this
# still lands docker compose in CONF_DIR (needed for the compose file's
# relative "./oem" mount) without depending on $HOME surviving elevation.
COMPOSE_LOG="$(mktemp)"
if ! ( cd "${CONF_DIR}" && pkexec docker compose "${COMPOSE_ARGS[@]}" up -d ) > "${COMPOSE_LOG}" 2>&1; then
  logger -t kibaos-winapps-setup "docker compose up -d failed: $(cat "${COMPOSE_LOG}")"
  err "Something went wrong starting the Windows environment (see journalctl -t kibaos-winapps-setup for details). Nothing was changed permanently — you can try again from the app menu ('Set Up Windows Apps')."
  rm -f "${COMPOSE_LOG}"
  exit 1
fi
rm -f "${COMPOSE_LOG}"

chromium "http://localhost:8006" >/dev/null 2>&1 &

# Source of truth for credentials from here on is compose.yaml itself,
# not a fresh random generation -- keeps this idempotent if setup gets
# re-run after a partial failure. The container (and whatever account is
# actually inside it) may already exist from a prior attempt, and
# regenerating a new password here would just desync from it.
WIN_USER=$(grep -oP '^\s*USERNAME:\s*"\K[^"]+' "${COMPOSE_FILE}")
WIN_PASS=$(grep -oP '^\s*PASSWORD:\s*"\K[^"]+' "${COMPOSE_FILE}")

if [ -z "${WIN_USER}" ] || [ -z "${WIN_PASS}" ]; then
  err "Couldn't read the Windows account details from the config. Run 'Set Up Windows Apps' again from the app menu, or check ${COMPOSE_FILE} manually."
  exit 1
fi

cat > "${CONF_DIR}/winapps.conf" << CONF
RDP_USER="${WIN_USER}"
RDP_PASS="${WIN_PASS}"
RDP_IP="127.0.0.1"
RDP_PORT="3389"
WAFLAVOR="docker"
DEBUG="true"
# /gfx:AVC444 switches FreeRDP onto the H.264 graphics pipeline instead of
# the legacy bitmap codec -- this is the single biggest lag fix, especially
# for anything Photoshop/video-editing-shaped. /network:lan tells FreeRDP
# this is a fast local link (it is: loopback to a container) rather than
# throttling itself as if it were a WAN connection. Baked in here rather
# than left as a README tweak, since there's no real reason for a user to
# ever want the slower defaults on a local install.
RDP_FLAGS="/gfx:AVC444 /network:lan"
CONF
chmod 600 "${CONF_DIR}/winapps.conf"

# Wait for the unattended install to actually finish -- this is a real
# Windows install (download + setup), not a quick boot, so budget up to
# ~35 minutes rather than the couple of minutes a already-installed VM
# would need to just bring RDP up after a restart. An open RDP port is
# used as the "Windows is ready" signal since there's no other clean
# hook into dockur/windows' unattended install process from out here.
RDP_UP=0
for i in $(seq 1 420); do
  nc -z 127.0.0.1 3389 >/dev/null 2>&1 && { RDP_UP=1; break; }
  sleep 5
done

if [ "${RDP_UP}" -ne 1 ]; then
  err "Windows is taking longer than expected to finish installing. Nothing's broken — it may just need more time on a slower connection. Check progress at http://127.0.0.1:8006, and re-run 'Set Up Windows Apps' from the app menu once it shows a desktop."
  exit 1
fi

notify "Almost done — one more window will open to finish installing the app shortcuts (Word, Excel, whatever Windows found installed). It'll look technical for a minute; that's normal, just follow along."

# NOTE: deliberately not relying on a terminal emulator's "--wait" flag to
# block until setup.sh finishes. gnome-console's --wait is a documented
# no-op (upstream man page literally lists it as "(TODO)"), and even
# gnome-terminal's --wait only helps if gnome-console isn't picked first.
# So: run setup.sh directly in *this* process (a real, unambiguous
# blocking call), log its output to a file, and just tail that log in a
# terminal window purely for the user to watch -- the terminal is
# cosmetic here, not something the script's control flow depends on.
SETUP_LOG="$(mktemp)"
TERMINAL_CMD="gnome-console"
command -v "${TERMINAL_CMD}" >/dev/null 2>&1 || TERMINAL_CMD="gnome-terminal"
"${TERMINAL_CMD}" -- bash -lc "tail -n +1 -f '${SETUP_LOG}'" &
TAIL_TERM_PID=$!

"${WINAPPS_SRC}/setup.sh" --user --setupAllOfficiallySupportedApps > "${SETUP_LOG}" 2>&1
SETUP_STATUS=$?

kill "${TAIL_TERM_PID}" >/dev/null 2>&1

if [ "${SETUP_STATUS}" -ne 0 ]; then
  err "The Windows app shortcut installer hit a problem partway through (see ${SETUP_LOG} for details). Windows itself is still fine -- run 'Set Up Windows Apps' again from the app menu to retry just that step."
  exit 1
fi
rm -f "${SETUP_LOG}"

rm -f "${MARKER}"
if [ "${GPU_DETECTED}" -eq 1 ]; then
  notify "All set! Open 'Run Windows Workspace' from the app menu or desktop to use Windows full-screen, and any Windows programs WinApps found are now in your app menu.\n\nAn NVIDIA GPU was detected and passed through to Windows for faster, hardware-accelerated apps."
else
  notify "All set! Open 'Run Windows Workspace' from the app menu or desktop to use Windows full-screen, and any Windows programs WinApps found are now in your app menu."
fi
WINAPPSSETUP
chmod +x /usr/local/bin/kibaos-winapps-setup

# Menu entry so this is re-runnable any time, not just at first login
# (e.g. if someone skips it initially, or wants to fix a broken setup).
cat > /usr/share/applications/kibaos-winapps-setup.desktop << 'SETUPDESKTOP'
[Desktop Entry]
Type=Application
Name=Set Up Windows Apps
Comment=Set up Windows app support, including the full-screen Windows Workspace
Icon=kibaos-winapps
Exec=/usr/local/bin/kibaos-winapps-setup
Terminal=false
Categories=System;Settings;
SETUPDESKTOP

# First-login autostart: only actually shows anything if the marker from
# kibaos-oobe-backend / kibaos-oem-finish.sh is present, which it always
# is now (WinApps is a mandatory feature, not opt-in). Same gating style
# as the OEM-finish entry above.
cat > "${SKEL}/.config/autostart/kibaos-winapps-firstrun.desktop" << 'WINAPPSAUTOCFG'
[Desktop Entry]
Type=Application
Name=Windows App Support Setup
Exec=sh -c 'test -f /etc/kibaos/winapps-pending && exec /usr/local/bin/kibaos-winapps-setup'
Hidden=false
NoDisplay=true
X-GNOME-Autostart-enabled=true
WINAPPSAUTOCFG

# ── Live-session autostart: launches the OOBE installer automatically on
# the regular live boot (the 'liveuser' autologin session), so the person
# lands straight in the installer instead of staring at an empty desktop.
# gated to liveuser specifically (via `whoami`) so this never fires after
# a real install, on the OEM-finish account (which has its own autostart
# entry above), or on any other account this .config/autostart skeleton
# ends up getting copied into down the line. ────────────────────────────
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
alias update='sudo kiba update'
fastfetch 2>/dev/null || true
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_STATE_HOME="$HOME/.local/state"
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
# ufw used to be in here, but its packaging hooks just don't behave
# inside this chroot build container, and it goes beyond just the
# `ufw enable` CLI call (confirmed — removing that one call wasn't even
# enough, something in ufw's own systemd-enable-time hooks still tries a
# /proc-dependent SSH-detection check and fails the same way, since
# there's no real /proc in this build environment). rather than keep
# fighting a third-party tool's chroot incompatibility for a
# build-time-only step that was never going to filter live traffic
# anyway, ufw's just gone entirely now. so KibaOS currently ships with no
# firewall configured by default — worth coming back to eventually (maybe
# straight nftables, or a different frontend) if network-facing hardening
# ever becomes a priority, but it's not a build-blocking concern for a
# desktop live/install image the way it'd be for a server image.

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

# ── "Files" launcher: opens Nemo straight into the kiba-view overlay ───────
# Plain `nemo` with no path argument opens raw $HOME, which is exactly the
# FHS-y view kiba-view exists to keep users away from (see the KIBA VIEW
# section earlier in this file). Nemo's own .desktop entry can't be edited
# in place without fighting future package updates, so this ships a
# separate launcher that's used everywhere a "Files" icon is needed instead
# (pinned dock slot, app menu) -- Exec= field codes don't expand $HOME, so
# it's a one-line wrapper script rather than a raw Exec= path.
cat > /usr/local/bin/kibaos-files << 'FILESWRAP'
#!/bin/bash
# kiba-view.service should already have this mounted by the time any
# graphical app can launch (see Before=graphical-session.target on that
# unit) -- this check is just a last-resort fallback in case the mount
# ever fails or is still coming up, so "Files" degrades to raw $HOME
# instead of opening an empty/missing directory.
target="$HOME/KibaOS"
mountpoint -q "$target" 2>/dev/null || target="$HOME"
exec nemo "$target"
FILESWRAP
chmod +x /usr/local/bin/kibaos-files

cat > /usr/share/applications/kibaos-files.desktop << 'FILESDESK'
[Desktop Entry]
Type=Application
Name=Files
Comment=Browse your documents, downloads, and other files
Icon=nemo
Exec=/usr/local/bin/kibaos-files
Terminal=false
NoDisplay=false
Categories=System;FileTools;FileManager;
FILESDESK

# ── Nemo/GTK sidebar bookmarks: a clean "quick access" list ────────────────
# Windows' C:\Users\<name> feels tidy because Explorer's nav pane only
# ever shows Desktop/Documents/Downloads/Pictures/Music/Videos plus the
# user's own Home — everything else (our AppData-equivalent: ~/.config,
# ~/.local, ~/.cache) is already hidden by the leading dot, same deal as
# AppData being hidden by its own attribute on Windows. this seeds that
# same short, fixed list into Nemo's sidebar on first login, nothing
# more — no stray "Other Locations"/raw filesystem browsing sitting front
# and center.
#
# These now point into the kiba-view overlay (~/KibaOS/...) rather than
# straight at $HOME/... -- that overlay is what "Files" (above) opens
# into, and is meant to be the only filesystem surface a user browsing
# graphically ever lands on. Content is identical either way (kiba-view
# is a passthrough onto these same real directories), this just keeps
# every door into "my stuff" -- the dock icon, the sidebar, the sidebar's
# own bookmarks -- consistently leading through the same friendly view
# instead of half pointing at the overlay and half at raw $HOME. An
# "Other Files" bookmark is added too, for the overlay's catch-all root.
#
# heads up: this can't just be a static /etc/skel file — GTK bookmark
# files are plain file:// URIs with zero variable expansion, and skel
# gets copied byte-for-byte at account creation before the real username
# even exists. so instead this runs once per new user via a first-login
# script gated on a marker file, using a real $HOME at the moment it
# actually runs.
mkdir -p /etc/skel/.config/autostart
cat > /usr/local/bin/kibaos-first-login-setup << 'FIRSTLOGIN'
#!/bin/bash
MARKER="$HOME/.config/.kibaos-first-login-done"
[ -f "$MARKER" ] && exit 0
mkdir -p "$HOME/.config/gtk-3.0"
cat > "$HOME/.config/gtk-3.0/bookmarks" << BOOKMARKS
file://$HOME/KibaOS/Desktop Desktop
file://$HOME/KibaOS/Documents Documents
file://$HOME/KibaOS/Downloads Downloads
file://$HOME/KibaOS/Pictures Pictures
file://$HOME/KibaOS/Music Music
file://$HOME/KibaOS/Videos Videos
file://$HOME/KibaOS/Other%20Files Other Files
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

# ══════════════════════════════════════════════════════════════════════════
# PACMAN SHIM — `pacman` becomes a thin dispatcher in front of kiba
# ══════════════════════════════════════════════════════════════════════════
# The real pacman binary gets moved aside (NOT removed -- libalpm itself
# isn't touched, and kibapkg already never called the pacman binary
# anyway, it's pyalpm straight to libalpm) and /usr/bin/pacman becomes a
# small dispatcher script instead.
#
# What it does NOT do: try to reimplement pacman's CLI. That's a losing
# game -- makepkg, DKMS's pacman hooks, kortex, and any AUR helper all
# shell out to pacman with exact flag combinations and, in some cases,
# parse its stdout for specific fields. Silently rewriting any of that
# output format would break real tooling for a cosmetic win, which isn't
# a trade worth making.
#
# So the dispatcher only intercepts when BOTH are true:
#   1. stdout is a real terminal (a human is sitting at it, not a script
#      capturing output through a pipe or the DKMS/makepkg machinery)
#   2. the arguments exactly match one of a short list of common,
#      simple, interactively-typed invocations (pacman -S foo, -Syu,
#      -Ss term, etc.)
# Anything else -- any flag combo not on the list, any non-interactive
# invocation, `-U` for local package files, `-T` dependency checks,
# `--asdeps`, multiple mixed flags, whatever makepkg/DKMS actually use --
# execs the real binary with the ORIGINAL argv, completely unmodified.
# The net effect: someone typing `pacman -S firefox` out of habit gets
# kiba's plain-language output; every script, hook, and build tool on the
# system keeps talking to the genuine pacman/libalpm exactly as before,
# because from their side nothing changed.
echo "=== Installing pacman shim (real pacman -> /usr/lib/kibaos/pacman-real) ==="
mkdir -p /usr/lib/kibaos
if [ -f /usr/bin/pacman ] && [ ! -f /usr/lib/kibaos/pacman-real ]; then
  mv /usr/bin/pacman /usr/lib/kibaos/pacman-real
fi

cat > /usr/bin/pacman << 'PACMANSHIM'
#!/usr/bin/env bash
# pacman shim -- see the build-script comment above this heredoc for the
# full design rationale (tty check, exact-match allowlist, fallback).
# KIBAOS_REAL_PACMAN=1 is the documented escape hatch, same pattern as
# kiba-identity's KIBAOS_REAL_UNAME: set it to always get the genuine
# binary regardless of how this is invoked.
REAL=/usr/lib/kibaos/pacman-real

if [ -n "${KIBAOS_REAL_PACMAN:-}" ] || [ ! -t 1 ]; then
  exec "${REAL}" "$@"
fi

# Bail to the real binary the instant anything looks like more than a
# bare "flag + plain package names/terms" -- any additional flag anywhere
# (--noconfirm, --asdeps, --needed, whatever) means this came from a
# script, not someone typing at a prompt, so don't touch it.
rest=("$@"); rest=("${rest[@]:1}")
for a in "${rest[@]}"; do
  case "${a}" in -*) exec "${REAL}" "$@" ;; esac
done

case "$1" in
  -S|--sync)
    [ "${#rest[@]}" -ge 1 ] || exec "${REAL}" "$@"
    exec kiba install "${rest[@]}" ;;
  -R|--remove)
    [ "${#rest[@]}" -ge 1 ] || exec "${REAL}" "$@"
    exec kiba remove "${rest[@]}" ;;
  -Syu|-Syyu)
    [ "${#rest[@]}" -eq 0 ] || exec "${REAL}" "$@"
    exec kiba update ;;
  -Ss|--search)
    [ "${#rest[@]}" -ge 1 ] || exec "${REAL}" "$@"
    exec kiba search "${rest[@]}" ;;
  -Qi)
    [ "${#rest[@]}" -eq 1 ] || exec "${REAL}" "$@"
    exec kiba info "${rest[0]}" ;;
  -Q|--query)
    [ "${#rest[@]}" -eq 0 ] || exec "${REAL}" "$@"
    exec kiba list ;;
  *)
    exec "${REAL}" "$@" ;;
esac
PACMANSHIM
chmod +x /usr/bin/pacman
echo "=== pacman shim installed ==="

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
# avahi drags in a "Network Browser" launcher nobody needs in the app
# grid. override both avahi-discover and bssh/bvnc's desktop files with
# NoDisplay so they stop showing up.
for _avahi_desk in avahi-discover bssh bvnc; do
  if [ -f "/usr/share/applications/${_avahi_desk}.desktop" ]; then
    cp "/usr/share/applications/${_avahi_desk}.desktop" \
       "/usr/share/applications/${_avahi_desk}.desktop.bak" 2>/dev/null || true
    printf '[Desktop Entry]\nNoDisplay=true\n' \
      >> "/usr/share/applications/${_avahi_desk}.desktop"
  fi
done

# ── Hide gnome-terminal from the app launcher / shortcuts ─────────────────
# terminal's still reachable via right-click and other paths, just don't
# want it pinned or sitting visible in the main shortcut list.
if [ -f "/usr/share/applications/org.gnome.Terminal.desktop" ]; then
  sed -i 's/^NoDisplay=.*/NoDisplay=true/' \
      "/usr/share/applications/org.gnome.Terminal.desktop" || true
  grep -q '^NoDisplay=' "/usr/share/applications/org.gnome.Terminal.desktop" \
    || echo 'NoDisplay=true' >> "/usr/share/applications/org.gnome.Terminal.desktop"
fi

# ── Hide budgie-control-center from the app launcher ───────────────────────
# gets pulled in transitively as a dependency of the budgie package
# group, so can't just remove it without risking breaking budgie itself
# — but it's superseded by the visible Settings app below, so just keep
# it out of the menu instead. budgie-desktop-settings (the separate
# panel/applet-layout configurator) is the same story — GNOME Settings
# is the one and only settings entry point users should see.
for _bcc_desk in budgie-control-center.desktop \
                 org.buddiesofbudgie.BudgieControlCenter.desktop \
                 budgie-desktop-settings.desktop \
                 org.buddiesofbudgie.BudgieDesktopSettings.desktop; do
  if [ -f "/usr/share/applications/${_bcc_desk}" ]; then
    sed -i 's/^NoDisplay=.*/NoDisplay=true/' "/usr/share/applications/${_bcc_desk}" || true
    grep -q '^NoDisplay=' "/usr/share/applications/${_bcc_desk}" \
      || echo 'NoDisplay=true' >> "/usr/share/applications/${_bcc_desk}"
  fi
done

# ── Hide dev/power-user tooling that has no business in a consumer app menu
# Kvantum Manager (Qt theme engine config, pulled in as a Qt/KDE-lib dep),
# Sysprof (system profiler), GNOME Extensions (Budgie doesn't run
# gnome-shell extensions, this is a stray dep of some GNOME component),
# qv4l2/qvidcap (the v4l-utils Qt test/capture utilities — camera driver
# debugging tools, not something an end user should stumble into),
# tuned-gui (the tuned power-profile daemon's own GUI — tuned itself stays
# enabled as a service, just the standalone control panel is redundant now
# that power profile switching lives in Settings), and lstopo (hwloc's
# hardware-topology visualizer). all several candidate desktop-file names
# are covered since exact IDs drift across distro packaging.
for _hidden_desk in kvantummanager.desktop \
                     org.gnome.Sysprof.desktop \
                     sysprof.desktop \
                     sysprof4.desktop \
                     org.gnome.Extensions.desktop \
                     com.github.hedges.gnome-extensions.desktop \
                     qv4l2.desktop \
                     qvidcap.desktop \
                     tuned-gui.desktop \
                     tuned-adm-gui.desktop \
                     lstopo.desktop \
                     hwloc.desktop; do
  if [ -f "/usr/share/applications/${_hidden_desk}" ]; then
    sed -i 's/^NoDisplay=.*/NoDisplay=true/' "/usr/share/applications/${_hidden_desk}" || true
    grep -q '^NoDisplay=' "/usr/share/applications/${_hidden_desk}" \
      || echo 'NoDisplay=true' >> "/usr/share/applications/${_hidden_desk}"
  fi
done

# ── Rename gnome-control-center to "Settings" ───────────────────────────────
# plain upstream GNOME Settings here, not the Budgie fork -- current
# libadwaita builds use the sidebar+search layout, which reads a lot
# closer to macOS System Settings than budgie-control-center's older
# layout does. upstream's desktop file already calls it "Settings" in
# most locales, but strip the localised Name[xx]= lines anyway so a
# non-English locale can't override the label — matching the other
# rebrands in this block.
for _gcc_desk in gnome-control-center.desktop \
                 org.gnome.Settings.desktop; do
  if [ -f "/usr/share/applications/${_gcc_desk}" ]; then
    sed -i 's/^Name=.*/Name=Settings/' "/usr/share/applications/${_gcc_desk}" || true
    sed -i '/^Name\[/d' "/usr/share/applications/${_gcc_desk}" || true
  fi
done

# gnome-control-center registers each panel as its own (usually
# NoDisplay) .desktop file just for search indexing (e.g.
# "gnome-wifi-panel.desktop" launches `gnome-control-center wifi`). a
# few of those panels are GNOME-Shell-specific and don't mean anything
# under labwc/Budgie, so hide them from search too. this list is a
# best-effort starting point based on current upstream panel naming --
# check `ls /usr/share/applications/gnome-*-panel.desktop` on a built
# image and extend/trim as needed, since the exact panel-desktop-id
# naming does shift between GNOME releases.
for _panel_desk in gnome-multitasking-panel.desktop \
                    gnome-search-panel.desktop \
                    gnome-wwan-panel.desktop \
                    gnome-online-accounts-panel.desktop; do
  if [ -f "/usr/share/applications/${_panel_desk}" ]; then
    sed -i 's/^NoDisplay=.*/NoDisplay=true/' "/usr/share/applications/${_panel_desk}" || true
    grep -q '^NoDisplay=' "/usr/share/applications/${_panel_desk}" \
      || echo 'NoDisplay=true' >> "/usr/share/applications/${_panel_desk}"
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

# ── Hide cmake-gui from the app launcher ───────────────────────────────────
# leftover safety net: cmake used to get pulled into this chroot to
# compile wayfire-plugins-extra from source, and Arch's cmake package
# drags a cmake-gui.desktop entry along with it -- no business showing up
# in a consumer app menu. cmake isn't installed in the image at all
# anymore now that that build's gone (see where WAYFIRE IPC used to be),
# so this if-check is realistically dead code today. leaving it in
# anyway in case cmake ever ends up pulled in here again for something
# else later -- costs nothing to keep, and it's a lot cheaper than
# forgetting to add it back.
if [ -f "/usr/share/applications/cmake-gui.desktop" ]; then
  sed -i 's/^NoDisplay=.*/NoDisplay=true/' "/usr/share/applications/cmake-gui.desktop" || true
  grep -q '^NoDisplay=' "/usr/share/applications/cmake-gui.desktop" \
    || echo 'NoDisplay=true' >> "/usr/share/applications/cmake-gui.desktop"
fi

# ── Disable Magic SysRq — a raw kernel-debugging keyboard backdoor that has
# no business being reachable from a consumer desktop.
echo 'kernel.sysrq = 0' > /etc/sysctl.d/50-kibaos-disable-sysrq.conf

# ── Restrict virtual-terminal switching: Ctrl+Alt+F2 etc. are handled by
# the kernel's VT layer, not the compositor, so this can't be blocked
# from labwc config no matter what. instead, remove what's waiting on
# the other VTs — cap logind to one auto-spawned VT and mask the extra
# getty units, so Ctrl+Alt+F2-F6 land on an empty console with no login
# prompt to even reach.
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
QT_QPA_PLATFORM=wayland
QT_WAYLAND_SHELL_INTEGRATION=layer-shell
GTK_THEME=Adwaita-dark
QT_STYLE_OVERRIDE=kvantum
XCURSOR_THEME=Adwaita
XCURSOR_SIZE=24
MOZ_ENABLE_WAYLAND=1
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
# NOT systemd-time-wait-sync: that unit exists to BLOCK boot until the
# first NTP sync completes -- built for servers that need a guaranteed
# clock before continuing, not a consumer desktop. timesyncd above already
# syncs the clock in the background with zero boot-time cost; wait-sync
# would instead add a real (sometimes multi-second, sometimes a full
# timeout on a flaky/offline network) delay to every single boot for no
# benefit a desktop actually needs.

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

# ── Boot-time DNS pin ─────────────────────────────────────────────────────
# Runs every boot, live or installed, and forces /etc/resolv.conf back to
# a single "nameserver 1.1.1.1" line before anything else comes up.
cat > /usr/local/bin/kibaos-boot-dns << 'BOOTDNS'
#!/bin/bash
echo "nameserver 1.1.1.1" > /etc/resolv.conf
BOOTDNS
chmod +x /usr/local/bin/kibaos-boot-dns

cat > /etc/systemd/system/kibaos-boot-dns.service << 'BOOTDNSSVC'
[Unit]
Description=Pin /etc/resolv.conf to nameserver 1.1.1.1
DefaultDependencies=no
Before=sysinit.target network-pre.target NetworkManager.service
Conflicts=shutdown.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/kibaos-boot-dns
RemainAfterExit=yes

[Install]
WantedBy=sysinit.target
BOOTDNSSVC
systemctl enable kibaos-boot-dns.service

chown -R 1000:1000 /home/liveuser
chmod 750 /home/liveuser

# ══════════════════════════════════════════════════════════════════════════
# SYSTEM SERVICES — irqbalance, tuned, systemd-sysext, fstrim, tmpfiles
# ══════════════════════════════════════════════════════════════════════════
# irqbalance: was already in packages.x86_64 but never actually enabled --
# distributes IRQ load across cores instead of pinning everything to CPU0,
# which matters more on the low-core-count H616 SBC target than on a
# desktop x86_64 box, but costs nothing either way.
# systemd-oomd: requires PSI + full cgroups-v2 delegation to even start;
# fails to launch in this boot environment regardless of available RAM,
# and its startup failure was cluttering the boot log alongside real
# early-boot failures. Masked (not just disabled) so no dependency chain
# can pull it back in. earlyoom (already in packages.x86_64) replaces it
# as the actual OOM responder.
systemctl mask systemd-oomd.service systemd-oomd.socket
systemctl enable earlyoom

systemctl enable irqbalance

# tuned: ships a "balanced" profile out of the box that's a reasonable
# default for a consumer desktop (dynamic between throughput and power
# saving) without needing power-profiles-daemon and tuned fighting over
# the same knobs -- power-profiles-daemon is already installed for the
# GNOME-side battery/performance toggle in Budgie's quick settings, so
# tuned is set to a profile that doesn't try to override CPU governor
# decisions PPD already owns. tuned-adm needs a running D-Bus session to
# select a profile the normal way, which doesn't exist in this chroot, so
# the active_profile file (what tuned-adm actually writes under the hood)
# is dropped directly instead.
mkdir -p /etc/tuned
echo "balanced" > /etc/tuned/active_profile
systemctl enable tuned

# systemd-sysext: ships inside systemd itself, no separate package. Not
# populated with any extension images at build time -- this just enables
# the mechanism and creates the directories it reads from, so a .raw/
# squashfs extension image (e.g. a driver bundle or dev toolchain for the
# H616 SBC work) can be dropped into /var/lib/extensions and merged into
# /usr at boot with `systemctl restart systemd-sysext`, with no rebuild
# of the base image required. Empty directories are a no-op until
# something's actually placed in them.
mkdir -p /var/lib/extensions /etc/extensions
systemctl enable systemd-sysext

# fstrim.timer: ships inside systemd itself. Weekly TRIM for SSD/NVMe --
# continuous online discard (mount option) is deliberately NOT used
# instead, since batched weekly TRIM avoids the write-amplification and
# latency spikes continuous discard is known for.
systemctl enable fstrim.timer

# systemd-tmpfiles-clean.timer: periodic sweep of tmpfiles.d Age= rules.
# adding one real rule on top of the stock ones: kibaos-screenshot-ocr
# (see LABWC CONFIG above) drops its OCR scratch PNG in /tmp via mktemp
# (now with a "kibaos-ocr." prefix specifically so this rule can target
# just those files) and already cleans up after itself on exit, but a
# killed/crashed OCR run would leak it -- age those out after a day as a
# backstop. scoped to just that prefix instead of touching /tmp's own age
# own age (already handled by systemd's stock tmpfiles.d/tmp.conf) so
# this doesn't shadow or conflict with that default.
cat > /etc/tmpfiles.d/kibaos.conf << 'TMPFILES'
e /tmp/kibaos-ocr.* - - - 1d
TMPFILES
systemctl enable systemd-tmpfiles-clean.timer

# ══════════════════════════════════════════════════════════════════════════
# SECURITY — AppArmor, Firejail, Secure Boot (sbctl)
# ══════════════════════════════════════════════════════════════════════════
# AppArmor: the LSM itself is only live if apparmor is in the kernel's
# lsm= boot param (baked into /etc/kernel/cmdline and bundled into the
# UKI for installed systems; see kiba_install_finish.c's
# kiba_install_finalize()).
# Enabling the service here
# just makes it load whatever profiles ship in /etc/apparmor.d/ at boot
# once that param is active -- profile enforcement (aa-enforce/aa-complain
# for individual apps) is left to Remi/the end user, since KibaOS doesn't
# curate its own profile set.
systemctl enable apparmor

# Firejail: firecfg symlinks /usr/local/bin/<app> -> /usr/bin/firejail for
# every desktop app it recognizes a sandbox profile for (found by scanning
# /usr/share/applications), so e.g. the browser launches sandboxed by
# default without anyone having to type `firejail chromium` by hand.
# NOTE: firejail's own namespace/seccomp sandboxing and AppArmor's
# path-based enforcement have been reported to step on each other for
# some apps (an app both jailed AND under a restrictive profile can get
# denied in confusing ways) -- if something sandboxed misbehaves, check
# `aa-status`/`journalctl` for AppArmor DENIED lines before assuming it's
# just a firejail bug.
firecfg 2>/dev/null || true

# Secure Boot (sbctl): key generation/enrollment is inherently a per-
# machine, post-install action -- it needs the target's own firmware in
# Setup Mode, and on a handful of boards (some ASUS/Lenovo models per the
# Arch wiki) it can interact badly with OEM-signed Option ROMs if done
# carelessly. None of that is safe or meaningful to run against this
# build chroot, so this just installs sbctl (which also drops its own
# pacman hook to auto-resign the kernel/bootloader on future updates once
# keys exist) and a helper script the end user runs themselves.
cat > /usr/local/bin/kibaos-secureboot-setup << 'SBCTLSETUP'
#!/usr/bin/env bash
# Run this AFTER installing KibaOS, on the real target machine, with
# Secure Boot's Setup Mode enabled in firmware settings. It creates and
# enrolls your own Secure Boot keys, then signs systemd-boot's own EFI
# binary (both copies bootctl install drops -- the primary loader under
# EFI/systemd/ and the removable fallback path firmware falls back to on
# some boards) plus the UKI in EFI/Linux/ (sbctl's own pacman hook
# re-signs it automatically on any future kernel update, same as the
# bootloader binaries above).
set -e
echo "This will create and enroll new Secure Boot keys on THIS machine"
echo "and is not easily reversible. Only continue if you understand what"
echo "Secure Boot key enrollment does. See: wiki.archlinux.org/title/Unified_Extensible_Firmware_Interface/Secure_Boot"
read -rp "Continue? [y/N] " _confirm
[ "${_confirm}" = "y" ] || [ "${_confirm}" = "Y" ] || exit 0

sudo sbctl status
sudo sbctl create-keys
sudo sbctl enroll-keys -m
sudo sbctl sign -s /boot/EFI/systemd/systemd-bootx64.efi
sudo sbctl sign -s /boot/EFI/BOOT/BOOTX64.EFI
for uki in /boot/EFI/Linux/kibaos*.efi; do
  [ -e "${uki}" ] && sudo sbctl sign -s "${uki}"
done
sudo sbctl verify
echo "Done. Reboot and re-enable Secure Boot in firmware settings."
SBCTLSETUP
chmod +x /usr/local/bin/kibaos-secureboot-setup

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

# ══════════════════════════════════════════════════════════════════════════
# HIDE UPSTREAM-BRANDED LAUNCHER ENTRIES
# ══════════════════════════════════════════════════════════════════════════
# Scoped to /usr/share/applications ONLY -- deliberately not touching
# /usr/share/wayland-sessions or /usr/share/xsessions, since those are
# session definitions SDDM reads directly for the login screen's session
# picker, not app-menu entries; hiding budgie-desktop.desktop there would
# break login rather than just tidy the menu.
#
# Uses NoDisplay=true (the standard XDG way to hide a launcher without
# deleting the file) rather than removing the .desktop outright -- keeps
# the actual application and anything that might Exec= it intact, just
# not menu-visible. Runs as one of the last steps here specifically so it
# catches every .desktop pacstrap/AUR ended up installing by this point,
# not just the ones known about when this block was written -- matches
# on both filename and the Name= field, since a package can ship e.g.
# budgie-screenshot.desktop with Name=Screenshot (filename gives it away
# even if the display name wouldn't), or the reverse (a generically-named
# file whose Name= field says "Budgie" something).
for _desktop_file in /usr/share/applications/*.desktop; do
  [ -f "${_desktop_file}" ] || continue
  _basename=$(basename "${_desktop_file}")
  _name_line=$(grep -m1 '^Name=' "${_desktop_file}" 2>/dev/null || true)
  if echo "${_basename}" | grep -qi 'budgie' || echo "${_name_line}" | grep -qi 'budgie'; then
    if grep -q '^NoDisplay=' "${_desktop_file}"; then
      sed -i 's/^NoDisplay=.*/NoDisplay=true/' "${_desktop_file}"
    else
      echo 'NoDisplay=true' >> "${_desktop_file}"
    fi
    echo "=== Hid launcher entry: ${_basename} (matched 'budgie') ==="
  fi
done

# ── DNS: hardcode Cloudflare (1.1.1.1 / 1.0.0.1) ─────────────────────────
# Written as the LAST thing this script does, right before mkarchiso packs
# the airootfs into the squashfs -- NetworkManager (or anything else touched
# above) won't get a chance to reset /etc/resolv.conf after this point, so
# what ships in the live ISO is guaranteed to still be this file.
cat > /etc/resolv.conf << 'RESOLVCONF'
nameserver 1.1.1.1
nameserver 1.0.0.1
RESOLVCONF

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
