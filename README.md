<p align="center">
<img width="1762" height="892" alt="image" src="https://github.com/user-attachments/assets/0c79d218-deb6-47ba-9ee2-d4d524c37f19" />
</p>

<p align="center">
  <a href="https://github.com/WolfTech-Innovations/Kiba/.github/workflows/build.yml">
    <img src="https://img.shields.io/github/actions/workflow/status/WolfTech-Innovations/Kiba/kiba.yml?branch=main&label=Build&style=for-the-badge" alt="Build Status">
  </a>
  <img src="https://img.shields.io/badge/License-MIT-lightblue?style=for-the-badge" alt="License">
  <img src="https://img.shields.io/badge/Arch Linux-13%20Rolling-1793D1?style=for-the-badge&logo=archlinux&logoColor=white" alt="Arch Linux Version">
  <img src="https://img.shields.io/badge/Kiba%20OS-1793D1?style=for-the-badge&logo=linux&logoColor=gray" alt="KibaOS Version">
</p>

<p align="center">
  <img src="https://img.shields.io/github/repo-size/WolfTech-Innovations/Kiba?style=flat-square" alt="Repo Size">
  <img src="https://img.shields.io/github/stars/WolfTech-Innovations/Kiba?style=flat-square" alt="Stars">
  <img src="https://img.shields.io/github/forks/WolfTech-Innovations/Kiba?style=flat-square" alt="Forks">
  <img src="https://img.shields.io/github/last-commit/WolfTech-Innovations/Kiba?style=flat-square" alt="Last Commit">
</p>

KibaOS is a lightweight Linux distribution built on **Arch Linux base (Rolling)** with **Budgie Desktop Enviroment** as the desktop environment. KibaOS is developed and maintained by **WolfTech Innovations**.

<p align="center">
  <a href="https://sourceforge.net/projects/kibaos/files/latest/download">
    <img src="https://a.fsdn.com/con/app/sf-download-button" alt="Download KibaOS">
  </a>
</p>

<a href="https://www.star-history.com/?repos=WolfTech-Innovations%2FKiba&type=date&legend=top-left">
 <picture>
   <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/chart?repos=WolfTech-Innovations/Kiba&type=date&theme=dark&legend=top-left" />
   <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/chart?repos=WolfTech-Innovations/Kiba&type=date&legend=top-left" />
   <img alt="Star History Chart" src="https://api.star-history.com/chart?repos=WolfTech-Innovations/Kiba&type=date&legend=top-left" />
 </picture>
</a>
---

## Table of Contents

- [Documentation](#documentation)
- [Features](#features)
- [Quick Start](#quick-start)
  - [Download](#download)
  - [Writing to a USB Drive](#writing-to-a-usb-drive)
  - [Live Session](#live-session)
  - [Installation](#installation)
- [Technical Details](#technical-details)
  - [Shell](#shell)
  - [Theme](#theme)
  - [System Requirements](#system-requirements)
- [Build System](#build-system)
  - [Building Locally](#building-locally)
- [Project Structure](#project-structure)
- [Contributing](#contributing)
- [License](#license)
- [About](#about)

---

The goal of KibaOS is to provide a clean, modern, and visually consistent out-of-the-box experience without requiring post-install configuration. Everything from the boot splash to the terminal color scheme is pre-configured and ready to use.

---

## Documentation

For a more in-depth look at KibaOS, check out our detailed documentation:

- [**Architecture**](./docs/architecture.md): Base system, kernel, and minimization strategies.
- [**UX & Design**](./docs/ux-design.md): The Dracula aesthetic and terminal experience.
- [**Software Management**](./docs/software-management.md): KibaStore, Nala, and Flatpaks.
- [**Security & Compliance**](./docs/security-compliance.md): Privacy and AB 2273 compliance.
- [**Build System**](./docs/build-system.md): How we build and release KibaOS.
- [**Manual Compilation**](./docs/manual-compilation.md): Building the Budgie Desktop Enviroment from source.
- [**FAQ**](./docs/faq.md): Frequently asked questions.
- [**WIKI**](./WIKI.md): Comprehensive technical manual.

---

## Features

- **Arch Linux Base:** Built on **Arch Linux Rolling**
- **Deep Cloud Integration:** System-wide file and setting sync powered by Cloud Services. Built on **Arch Linux Rolling** (supported until 2030).
- **Modern Desktop:** **Budgie Desktop Enviroment** with **Wayland** as the default session.
- **Dracula Aesthetic:** **Dracula** color scheme applied system-wide — terminal, widgets, window decorations, and the panel.
- **Polished UI:** Floating rounded taskbar and 12px rounded window corners via **KWin** compositor.
- **Optimized Shell:** **Zsh** as the default shell with autosuggestions and syntax highlighting.
- **Custom Branding:** **Plymouth** boot splash and **Calamares** graphical installer with KibaOS branding.
- **Essential Apps:** **Firefox ESR**, **Dolphin**, **Konsole**, **Kate**, **VLC**, **GParted** included.
- **Performance:** No bloat — only what you need is installed.

---

## Quick Start

### Download

<img src="https://img.shields.io/sourceforge/dt/kibaos?style=flat-square" alt="SourceForge Downloads">

ISO images are available on **SourceForge**:
[Download KibaOS on SourceForge](https://sourceforge.net/projects/kibaos/files/)

SHA256 checksums are provided alongside each release. Always verify your download.

### Writing to a USB Drive

On Linux:

```bash
sudo dd if=kibaos-vN.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

> [!IMPORTANT]
> Replace `/dev/sdX` with your actual drive and `N` with the build number. You can also use tools like **Balena Etcher** or **Ventoy**.

### Live Session

Boot from the USB drive to enter the live environment. The session logs in automatically.

> [!NOTE]
> No changes made in the live session are saved after reboot. To install KibaOS permanently, launch the **Calamares** installer from the desktop.

#### Default Credentials (Live Session Only)

| Account | Password |
| ------- | -------- |
| `user`  | `live`   |
| `root`  | `root`   |

### Installation

The **Calamares** installer guides you through:

1. Language and locale selection
2. Keyboard layout
3. Disk partitioning (automatic or manual)
4. User account creation
5. Installation and bootloader setup

Post-install, update your system:

```bash
sudo pacman -Syu
```

---

## Technical Details

### Shell

<img src="https://img.shields.io/badge/Shell-Zsh-blue?style=flat-square&logo=zsh&logoColor=white" alt="Shell: Zsh">

KibaOS uses **Zsh** by default with a pre-configured system-wide config at **`/etc/zsh/zshrc`**:

- Shared history across sessions.
- Tab completion with menu select.
- Autosuggestions & syntax highlighting.
- Minimalist Dracula-themed prompt.

**Useful Aliases:**

- `ll` -> `ls -lah`
- `update` -> `sudo pacman -Syu`
- `install` -> `sudo pacman -S`

### Theme

<img src="https://img.shields.io/badge/Theme-Dracula-bd93f9?style=flat-square&logo=dracula&logoColor=white" alt="Theme: Dracula">

KibaOS ships the **Dracula** color scheme system-wide using the official palette

| Color      | Hex       | Role         |
| ---------- | --------- | ------------ |
| Background | `#282a36` | Primary BG   |
| Purple     | `#bd93f9` | Accent Color |
| Pink       | `#ff79c6` | Selection    |
| Green      | `#50fa7b` | Success      |

The scheme is applied to **Cutefish OS**, **Konsole**, **KWin** decorations, **Breeze Dark** panel, and **Plymouth**.

### System Requirements

| Component | Minimum                | Recommended         |
| --------- | ---------------------- | ------------------- |
| **CPU**   | 64-bit x86 (amd64)     | Dual-core or better |
| **RAM**   | 2 GB                   | 4 GB                |
| **Disk**  | 20 GB                  | **SSD** recommended |
| **GPU**   | **OpenGL 2.0** support | Dedicated GPU       |

---

## Build System

<p align="left">
  <img src="https://img.shields.io/badge/Build-live--build-blue?style=flat-square" alt="Build: live-build">
  <img src="https://img.shields.io/badge/CI-GitHub%20Actions-2088FF?style=flat-square&logo=github-actions&logoColor=white" alt="CI: GitHub Actions">
  <img src="https://img.shields.io/badge/Infrastructure-Docker-2496ED?style=flat-square&logo=docker&logoColor=white" alt="Infrastructure: Docker">
</p>

KibaOS is built using **live-build** inside a **Arch Linux Rolling** **Docker** container via **GitHub Actions**.

- **Orchestration:** `.github/workflows/kiba.yml`
- **Automation:** Workflow runs on push to `main`, weekly schedules, and manual dispatch.
- **Delivery:** Completed ISOs are automatically uploaded to **SourceForge** from the `main` branch.

### Building Locally

Requirements: **Docker**, a Linux host with at least 15 GB free space.

```bash
git clone https://github.com/WolfTech-Innovations/Kiba
cd Kiba
docker run --rm --privileged \
  -v "$PWD:/w" \
  -e RUN_NUM=local \
  archlinux:latest \
  /w/build.sh
```

> [!NOTE]
> The `build.sh` script is generated at build-time by the **GitHub Actions** workflow and contains the full configuration and customization hooks.

---

## Project Structure

```text
Kiba/
├── .github/
│   └── workflows/
│       └── kiba.yml           # Main build and release workflow
├── branding/
│   └── kibaos_banner.png      # KibaOS brand assets
├── docs/                      # In-depth documentation
└── README.md                  # Project documentation
```

---

## Contributing

Issues and pull requests are welcome at the [WolfTech-Innovations/Kiba](https://github.com/WolfTech-Innovations/Kiba) repository. Please open an issue before starting significant work, thanks!

---

## License

KibaOS is a distribution, not a single codebase. Individual components are subject to their own licenses. The build scripts and configuration files in this repository are released under the **MIT License**.

---

## About

KibaOS is a **WolfTech Innovations** project.
[Visit our GitHub](https://github.com/WolfTech-Innovations) | [**Acknowledgments**](./ACKNOWLEDGMENTS.md)
