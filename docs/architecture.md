# Architecture Deep-Dive

<p align="center">
  <img src="../branding/kibaos_banner.png" alt="KibaOS Banner" width="100%">
</p>

<p align="center">
  <img src="`https://img.shields.io/badge/Architecture-amd64-blue?style`=for-the-badge" alt="Architecture">
  <img src="`https://img.shields.io/badge/Base-Debian`%20Trixie-D70A53?style=for-the-badge&logo=debian" alt="Base">
  <img src="`https://img.shields.io/badge/Kernel-CachyOS-orange?style`=for-the-badge" alt="Kernel">
</p>

---

This document provides a technical overview of the KibaOS architectural stack, from the base system to the final user-facing components.

---

## System Stack

```mermaid
graph TD
    A[Hardware / VM] --> B[GRUB Bootloader]
    B --> C[CachyOS Kernel]
    C --> D[Debian 13 Trixie Base]
    D --> E[Systemd Init]
    E --> F[Wayland / X11]
    F --> G[KDE Plasma 6.3]
    G --> H[KibaOS UX]
```

---

## Core Foundation

### Debian 13 (Trixie)

KibaOS is built upon the **Debian 13 (Trixie)** testing branch. This allows us to offer cutting-edge software packages (like Plasma 6) while inheriting the robust package management and security infrastructure of Debian.

### CachyOS Kernel

We replace the stock Debian kernel with the **CachyOS Kernel** (integrated via `linux-cachyos-deb`).

- **BORE Scheduler:** Optimized for desktop responsiveness.
- **Improved Performance:** Built with modern compiler optimizations.
- **Gaming Ready:** Includes patches for improved wine/proton performance.

> [!IMPORTANT]
> To maintain a clean system, we explicitly purge the stock `linux-image-amd64` and `linux-headers-amd64` meta-packages during the build process to ensure only the optimized CachyOS kernel remains.

### Init & Display

- **Init System:** **Systemd** provides reliable service orchestration.
- **Display Server:** **Wayland** is the default for its security and modern features, with **X11** (via XWayland) ensuring compatibility with legacy applications.

---

## Extreme Minimization

KibaOS follows a strict "No Bloat" policy. We use aggressive strategies to keep the ISO size small and the runtime environment lean.

### Documentation & Help

During the build process, a custom hook removes all non-essential documentation to save hundreds of megabytes:

- **Paths:** `/usr/share/doc`, `/usr/share/man`, `/usr/share/info`, `/usr/share/help`.
- **Exception:** Shell integration scripts (e.g., **`fzf`** examples) are moved to `/usr/share/fzf` before the purge.

### Locale Pruning

We only keep **`en`** and **`en_US`** locales. All other translations are removed from `/usr/share/locale`, significantly reducing the package footprint.

### Dependency Pruning

We avoid meta-packages like `kde-plasma-desktop`. Instead, we install `plasma-desktop` and `plasma-workspace` and manually add only the essential KDE components required for a functional desktop.

---

## Filesystem & Boot Performance

### SquashFS Optimization

The live root filesystem is compressed using **Zstd** at level 19 with a 1MB block size.

- **Benefit:** High compression ratio (smaller ISO) with extremely fast decompression (faster app launches).

### Initramfs

### Documentation Stripping

During the build process, a custom hook removes all non-essential documentation files:

- `/usr/share/doc/*`
- `/usr/share/man/*`
- `/usr/share/info/*`
- `/usr/share/help/*`

_Note: Critical shell integration scripts (like those for `fzf`) are preserved before stripping._

### Locale Optimization

To save space, KibaOS limits system locales to only `en` and `en_US`. All other locale data is purged from `/usr/share/locale`.

### Dependency Pruning (Optimized)

We avoid heavy meta-packages. For example, instead of `kde-plasma-desktop`, we install a hand-picked minimal set including `plasma-desktop` and `plasma-workspace`, adding only the necessary components for a functional and beautiful desktop.

### Binary Compression

ELF binaries in `/usr/bin` and `/usr/sbin` (larger than 64KB) are compressed using **UPX** (Ultimate Packer for eXecutables) with the `--best` setting. Critical system components (like systemd, sddm, and the kernel) are excluded from compression to ensure system stability.
Configured for maximum compression using **`zstd -19`** in **`/etc/initramfs-tools/initramfs.conf`**. This reduces the size of the initial RAM disk, leading to faster boot times.

### Bootloader

KibaOS uses **GRUB** (`grub-pc` and `grub-efi`) as the primary bootloader.

- **Hybrid Support:** Works on both BIOS (Legacy) and UEFI systems.
- **Branded Menu:** A custom binary hook patches `grub.cfg` to provide user-friendly, branded menu entries like _"Start KibaOS"_ and _"Install KibaOS"_.

---

## Related Reading

- [**Build System**](./build-system.md)
- [**UX & Design**](./ux-design.md)
- [**WIKI**](../WIKI.md)
