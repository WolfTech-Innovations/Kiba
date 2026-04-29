# KibaOS Architecture

This document details the architectural decisions and core components of KibaOS.

## Base System

KibaOS is built on a solid, modern foundation designed for stability and performance.

- **Debian 13 (Trixie):** KibaOS uses the Debian testing branch (Trixie) as its base, ensuring access to modern packages while maintaining the legendary stability of Debian.
- **CachyOS Kernel:** Instead of the stock Debian kernel, KibaOS integrates the **CachyOS Kernel**. This kernel is heavily optimized for desktop responsiveness, featuring the BORE (Burst Oriented Response Encoder) scheduler and other performance enhancements.
- **Init System:** KibaOS uses **systemd** as its init system, providing robust service management and fast boot times.
- **Display Server:** The system defaults to **Wayland** for a smooth, modern display experience, with **X11** available as a fallback for maximum compatibility.

## Extreme Minimization

A core philosophy of KibaOS is "Extreme Minimization." We aggressively reduce the system's footprint to ensure it remains lightweight and fast.

### Documentation Stripping
During the build process, a custom hook removes all non-essential documentation files:
- `/usr/share/doc/*`
- `/usr/share/man/*`
- `/usr/share/info/*`
- `/usr/share/help/*`

*Note: Critical shell integration scripts (like those for `fzf`) are preserved before stripping.*

### Locale Optimization
To save space, KibaOS limits system locales to only `en` and `en_US`. All other locale data is purged from `/usr/share/locale`.

### Dependency Pruning
We avoid heavy meta-packages. For example, instead of `kde-plasma-desktop`, we install a hand-picked minimal set including `plasma-desktop` and `plasma-workspace`, adding only the necessary components for a functional and beautiful desktop.

### Binary Compression
ELF binaries in `/usr/bin` and `/usr/sbin` (larger than 64KB) are compressed using **UPX** (Ultimate Packer for eXecutables) with the `--best` setting. Critical system components (like systemd, sddm, and the kernel) are excluded from compression to ensure system stability.

## Filesystem & Boot

- **SquashFS with Zstd:** The live root filesystem is compressed using **Zstd** at compression level 19 with a 1MB block size, offering the best balance between compression ratio and decompression speed.
- **Initramfs:** Also configured to use **Zstd** at level 19 for rapid boot transitions.
- **ISOLINUX:** KibaOS uses **ISOLINUX** exclusively as its bootloader for the ISO, providing a simplified and branded boot menu.
