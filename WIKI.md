# KibaTV Wiki

<p align="center">
  <img src="branding/kibatv_banner.png" alt="KibaTV Banner" width="100%">
</p>

<p align="center">
  <a href="`https://github.com/WolfTech-Innovations/Kiba/actions/workflows/kiba.yml`">
    <img src="`https://img.shields.io/github/actions/workflow/status/WolfTech-Innovations/Kiba/kiba.yml?branch=main`&label=Build&style=for-the-badge" alt="Build Status">
  </a>
  <img src="`https://img.shields.io/badge/License-MIT-purple?style=for-the-badge`" alt="License">
  <img src="`https://img.shields.io/badge/Status-Stable-success?style=for-the-badge`" alt="Status">
</p>

Welcome to the official **KibaTV Wiki**. This document provides an exhaustive deep-dive into the internals, design philosophy, and technical implementation of KibaTV.

---

\n## 📖 Extended Documentation

For more specific details on the various components of KibaTV, please refer to the following documents:

- [**Architecture Deep-Dive**](./docs/architecture.md)
- [**UX & Visual Design**](./docs/ux-design.md)
- [**Software & Package Management**](./docs/software-management.md)
- [**Security & Compliance**](./docs/security-compliance.md)
- [**Build Infrastructure & Automation**](./docs/build-system.md)
- [**Contributing Guidelines**](./docs/contributing.md)
- [**Frequently Asked Questions**](./docs/faq.md)

---

\n## 🏗️ Architecture & Core Components

#\n## Base System

KibaTV is built upon the **Debian 13 (Trixie)** testing branch, providing a modern yet stable foundation intended for use until at least 2030.

- **Kernel:** **CachyOS Kernel** (optimized for desktop responsiveness and performance).
- **Init System:** **Systemd**.
- **Display Server:** **Wayland** (default) with **X11** fallback.
- **Bootloader:** **GRUB** (provides hybrid support for BIOS and UEFI systems).

#\n## Extreme Minimization

The system undergoes aggressive footprint reduction during the build process:

- **Documentation Stripping:** All `/usr/share/doc`, `/usr/share/man`, and `/usr/share/info` files are removed.
- **Locale Optimization:** Only `en` and `en_US` locales are preserved.
- **Dependency Pruning:** Meta-packages like `kde-plasma-desktop` are avoided in favor of a minimal `plasma-bigscreen` + `plasma-workspace` combination.
- **Binary Compression:** ELF binaries are compressed using **UPX** (best mode, excluding critical system components) to reduce disk usage.

---

\n## 🎨 User Experience (UX) & Design

#\n## Visual Identity

KibaTV follows the **Dracula** color palette for system-wide visual consistency.

| Component               | Choice               |
| ----------------------- | -------------------- |
| **Desktop Environment** | **Plasma Bigscreen** |
| **Global Theme**        | **Ant-Dark**         |
| **Color Scheme**        | **Dracula**          |
| **Icon Theme**          | **Kora**             |
| **Cursor Theme**        | **Vimix**            |
| **System Font**         | **Inter**            |
| **Monospace Font**      | **JetBrains Mono**   |

#\n## Shell Experience

**Zsh** is the default shell for all users, including `root`.

- **Prompt:** **Starship** (Pre-configured with a minimalist Dracula theme).
- **Plugins:** Autosuggestions and Syntax Highlighting are enabled by default.
- **Modern CLI Tools:**
  - `nala` (Beautiful frontend for `apt`)
  - `eza` (Modern `ls` replacement)
  - `bat` (Syntax-highlighting `cat`)
  - `fastfetch` (System information)
  - `btop` (Resource monitor)
  - `ripgrep` (Fast search)
  - `fd-find` (Fast file finder)
  - `tealdeer` (`tldr` implementation)

#\n## Boot & Branding

- **Plymouth:** Custom "kibatv-spinner" theme with a Dracula-themed progress bar and logo.
- **Boot Menu:** Branded **GRUB** menu with plain-English options for beginners.

---

\n## 📦 Software Management

#\n## KibaStore

KibaTV features **KibaStore**, which is a native build of **Bazaar**. It serves as a user-friendly frontend for managing **Flatpaks** without the overhead of heavy software centers.

#\n## Repositories & Packages

- **Ungoogled Chromium:** Provided via OBS (Open Build Service) repository.
- **Flatpak:** Integrated by default with the **Flathub** remote.
- **Nala:** Configured as the primary package manager frontend with system-wide aliases (`apt` -> `nala`).

---

\n## 🛡️ Security & Compliance

#\n## California AADC (AB 2273)

KibaTV includes a custom **Age Verification** module within the **Calamares** installer to comply with the **California Age-Appropriate Design Code Act**.

- **Implementation:** A Python-based view module in the installer.
- **Privacy:** Data is stored **locally only** at `/etc/kibatv/age-verify` and is never transmitted to external servers.

---

\n## 🚀 Build Infrastructure

KibaTV uses a highly automated CI/CD pipeline.

#\n## Build Pipeline

1. **Tooling:** Built using **live-build** (lb).
2. **Environment:** **Docker** container running **Debian Trixie**.
3. **Orchestration:** **GitHub Actions** (`.github/workflows/kiba.yml`).
4. **Caching:** Extensive stage caching (bootstrap, chroot, rootfs, binary) for fast builds.

#\n## Image Optimization

- **Compression:** The SquashFS filesystem is repacked with **Zstd** (compression level 19) for maximum space efficiency and decompression speed.
- **Initramfs:** Configured with `zstd -19` for faster boot times.

---

\n## 🛠️ Build Locally

To reproduce the build environment on your own machine:

````bash
git clone `https://github.com/WolfTech-Innovations/Kiba`
cd Kiba
docker run --rm --privileged \
  -v "$PWD:/w" \
  -e RUN_NUM=local \
  debian:trixie \
  /w/build.sh
```bash

> [!IMPORTANT]
> Ensure you have at least 15 GB of free space and a working internet connection.

---

\n## 🤝 Community & Support

- **Repository:** [GitHub](https://github.com/WolfTech-Innovations/Kiba)
- **Downloads:** [SourceForge](https://sourceforge.net/projects/kibaos/)
- **Organization:** [WolfTech Innovations](https://github.com/WolfTech-Innovations)
- **Acknowledgments:** [Community & FOSS](./ACKNOWLEDGMENTS.md)

---

\n## ⚖️ License

KibaTV is a distribution composed of many independent components. While each component carries its own license, the build scripts, configurations, and original tooling in this repository are licensed under the [**MIT License**](./LICENSE).

> [!NOTE]
> KibaTV is a community-driven project. Contributions in the form of code, documentation, or bug reports are highly encouraged.
````
