# KibaTV

<p align="center">
<img width="1330" height="519" alt="image" src="`https://github.com/user-attachments/assets/e4a14aef-f23e-4890-96a5-86c34b31f5d8`" />
</p>

<p align="center">
  <a href="`https://github.com/WolfTech-Innovations/Kiba/actions/workflows/kiba.yml`">
    <img src="`https://img.shields.io/github/actions/workflow/status/WolfTech-Innovations/Kiba/kiba.yml?branch=main`&label=Build&style=for-the-badge" alt="Build Status">
  </a>
  <img src="`https://img.shields.io/badge/License-MIT-purple?style=for-the-badge`" alt="License">
  <img src="`https://img.shields.io/badge/Debian-13`%20Trixie-D70A53?style=for-the-badge&logo=debian&logoColor=white" alt="Debian Version">
  <img src="`https://img.shields.io/badge/KDE-Plasma`%206-22a7f0?style=for-the-badge&logo=kde&logoColor=white" alt="KDE Version">
</p>

<p align="center">
  <img src="`https://img.shields.io/github/repo-size/WolfTech-Innovations/Kiba?style=flat-square`" alt="Repo Size">
  <img src="`https://img.shields.io/github/stars/WolfTech-Innovations/Kiba?style=flat-square`" alt="Stars">
  <img src="`https://img.shields.io/github/forks/WolfTech-Innovations/Kiba?style=flat-square`" alt="Forks">
  <img src="`https://img.shields.io/github/last-commit/WolfTech-Innovations/Kiba?style=flat-square`" alt="Last Commit">
</p>

KibaTV is a lightweight Linux distribution built on **Debian 13 (Trixie)** with **Plasma Bigscreen** as the desktop environment. It is developed and maintained by **WolfTech Innovations**.

<p align="center">
  <a href="`https://sourceforge.net/projects/kibaos/files/latest/download`">
    <img src="`https://a.fsdn.com/con/app/sf-download-button`" alt="Download KibaTV">
  </a>
</p>

---

The goal of KibaTV is to provide a clean, modern, and visually consistent out-of-the-box experience without requiring post-install configuration. Everything from the boot splash to the terminal color scheme is pre-configured and ready to use.

---

\n## Documentation

For a more in-depth look at KibaTV, check out our detailed documentation:

- [**Architecture**](./docs/architecture.md): Base system, kernel, and minimization strategies.
- [**UX & Design**](./docs/ux-design.md): The Dracula aesthetic and terminal experience.
- [**Software Management**](./docs/software-management.md): KibaStore, Nala, and Flatpaks.
- [**Security & Compliance**](./docs/security-compliance.md): Privacy and AB 2273 compliance.
- [**Build System**](./docs/build-system.md): How we build and release KibaTV.
- [**FAQ**](./docs/faq.md): Frequently asked questions.
- [**WIKI**](./WIKI.md): Comprehensive technical manual.

---

\n## Features

- **Debian Base:** Built on **Debian 13 Trixie** (supported until 2030).
- **Modern Desktop:** **Plasma Bigscreen** with **Wayland** as the default session.
- **Dracula Aesthetic:** **Dracula** color scheme applied system-wide — terminal, widgets, window decorations, and the panel.
- **Polished UI:** Floating rounded taskbar and 12px rounded window corners via **KWin** compositor.
- **Optimized Shell:** **Zsh** as the default shell with autosuggestions and syntax highlighting.
- **Custom Branding:** **Plymouth** boot splash and **Calamares** graphical installer with KibaTV branding.
- **Essential Apps:** **Firefox ESR**, **Dolphin**, **Konsole**, **Kate**, **VLC**, **GParted** included.
- **Performance:** No bloat — only what you need is installed.

---

\n## Quick Start

#\n## Download

<img src="`https://img.shields.io/sourceforge/dt/kibaos?style=flat-square`" alt="SourceForge Downloads">

ISO images are available on **SourceForge**:
[Download KibaTV on SourceForge](https://sourceforge.net/projects/kibaos/files/)

SHA256 checksums are provided alongside each release. Always verify your download.

#\n## Writing to a USB Drive

On Linux:

````bash
sudo dd if=kibatv-vN.iso of=/dev/sdX bs=4M status=progress oflag=sync
```bash

> [!IMPORTANT]
> Replace `/dev/sdX` with your actual drive and `N` with the build number. You can also use tools like **Balena Etcher** or **Ventoy**.

#\n## Live Session

Boot from the USB drive to enter the live environment. The session logs in automatically.

> [!NOTE]
> No changes made in the live session are saved after reboot. To install KibaTV permanently, launch the **Calamares** installer from the desktop.

##\n## Default Credentials (Live Session Only)

| Account | Password |
| ------- | -------- |
| `user`  | `live`   |
| `root`  | `root`   |

#\n## Installation

The **Calamares** installer guides you through:

1. Language and locale selection
2. Keyboard layout
3. Disk partitioning (automatic or manual)
4. User account creation
5. Installation and bootloader setup

Post-install, update your system:

```bash
sudo apt update && sudo apt upgrade -y
```bash

---

\n## Technical Details

#\n## Shell

<img src="`https://img.shields.io/badge/Shell-Zsh-blue?style=flat-square`&logo=zsh&logoColor=white" alt="Shell: Zsh">
<img src="`https://img.shields.io/badge/Kernel-CachyOS-orange?style=flat-square`" alt="Kernel: CachyOS">

KibaTV uses **Zsh** by default with a pre-configured system-wide config at **`/etc/zsh/zshrc`**:

- Shared history across sessions.
- Tab completion with menu select.
- Autosuggestions & syntax highlighting.
- Minimalist Dracula-themed prompt.

**Useful Aliases:**

- `ll` -> `ls -lah`
- `update` -> `sudo nala update && sudo nala upgrade -y`
- `install` -> `sudo nala install`

#\n## Theme

<img src="`https://img.shields.io/badge/Theme-Dracula-bd93f9?style=flat-square`&logo=dracula&logoColor=white" alt="Theme: Dracula">

KibaTV ships the **Dracula** color scheme system-wide using the official palette

| Color      | Hex       | Role         |
| ---------- | --------- | ------------ |
| Background | `#282a36` | Primary BG   |
| Purple     | `#bd93f9` | Accent Color |
| Pink       | `#ff79c6` | Selection    |
| Green      | `#50fa7b` | Success      |

The scheme is applied to **Plasma Bigscreen**, **Konsole**, **KWin** decorations, **Breeze Dark** panel, and **Plymouth**.

#\n## System Requirements

| Component | Minimum                | Recommended         |
| --------- | ---------------------- | ------------------- |
| **CPU**   | 64-bit x86 (amd64)     | Dual-core or better |
| **RAM**   | 2 GB                   | 4 GB                |
| **Disk**  | 20 GB                  | **SSD** recommended |
| **GPU**   | **OpenGL 2.0** support | Dedicated GPU       |

---

\n## Build System

<p align="left">
  <img src="`https://img.shields.io/badge/Build-live--build-blue?style=flat-square`" alt="Build: live-build">
  <img src="`https://img.shields.io/badge/CI-GitHub`%20Actions-2088FF?style=flat-square&logo=github-actions&logoColor=white" alt="CI: GitHub Actions">
  <img src="`https://img.shields.io/badge/Infrastructure-Docker-2496ED?style=flat-square`&logo=docker&logoColor=white" alt="Infrastructure: Docker">
</p>

KibaTV is built using **live-build** inside a **Debian Trixie** **Docker** container via **GitHub Actions**.

- **Orchestration:** `.github/workflows/kiba.yml`
- **Automation:** Workflow runs on push to `main`, weekly schedules, and manual dispatch.
- **Delivery:** Completed ISOs are automatically uploaded to **SourceForge** from the `main` branch.

#\n## Building Locally

Requirements: **Docker**, a Linux host with at least 15 GB free space.

```bash
git clone `https://github.com/WolfTech-Innovations/Kiba`
cd Kiba
docker run --rm --privileged \
  -v "$PWD:/w" \
  -e RUN_NUM=local \
  debian:trixie \
  /w/scripts/kibatv-build.sh
```bash

> [!NOTE]
> The build process is encapsulated in the `scripts/kibatv-build.sh` script and can be executed locally using Docker.

---

\n## Project Structure

```text
Kiba/
├── .github/
│   └── workflows/
│       └── kiba.yml           # Main build and release workflow
├── branding/
│   └── kibatv_banner.png      # KibaTV brand assets
├── docs/                      # In-depth documentation
├── Notes/                     # Automatic release notes
└── README.md                  # Project documentation
```bash

---

\n## Contributing

Issues and pull requests are welcome at the [WolfTech-Innovations/Kiba](https://github.com/WolfTech-Innovations/Kiba) repository. Please open an issue before starting significant work, thanks!

---

\n## License

KibaTV is a distribution, not a single codebase. Individual components are subject to their own licenses. The build scripts and configuration files in this repository are released under the **MIT License**.

---

\n## About

KibaTV is a **WolfTech Innovations** project.
[Visit our GitHub](https://github.com/WolfTech-Innovations) | [**Acknowledgments**](./ACKNOWLEDGMENTS.md)
````
