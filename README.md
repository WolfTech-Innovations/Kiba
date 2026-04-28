# 🦊 KibaOS

<p align="center">
  <img src="branding/kibaos_banner.png" alt="KibaOS Banner" width="100%">
</p>

<p align="center">
  <a href="https://github.com/WolfTech-Innovations/Kiba/actions/workflows/kiba.yml">
    <img src="https://img.shields.io/github/actions/workflow/status/WolfTech-Innovations/Kiba/kiba.yml?branch=main&label=Build&style=for-the-badge" alt="Build Status">
  </a>
  <img src="https://img.shields.io/badge/License-MIT-purple?style=for-the-badge" alt="License">
  <img src="https://img.shields.io/badge/Debian-13%20Trixie-D70A53?style=for-the-badge&logo=debian&logoColor=white" alt="Debian Version">
  <img src="https://img.shields.io/badge/KDE-Plasma%206-22a7f0?style=for-the-badge&logo=kde&logoColor=white" alt="KDE Version">
</p>

KibaOS is a lightweight Linux distribution built on Debian 13 (Trixie) with KDE Plasma 6 as the desktop environment. It is developed and maintained by WolfTech Innovations.

<p align="center">
  <a href="https://sourceforge.net/projects/kibaos/files/latest/download">
    <img src="https://a.fsdn.com/con/app/sf-download-button" alt="Download KibaOS">
  </a>
</p>

_____ 

The goal of KibaOS is to provide a clean, modern, and visually consistent out-of-the-box experience without requiring post-install configuration. Everything from the boot splash to the terminal color scheme is pre-configured and ready to use.

---

## 🚀 Features

- **Debian Base:** Built on Debian 13 Trixie (supported until 2030).
- **Modern Desktop:** KDE Plasma 6.3 with Wayland as the default session.
- **Dracula Aesthetic:** Dracula color scheme applied system-wide — terminal, widgets, window decorations, and the panel.
- **Polished UI:** Floating rounded taskbar and 12px rounded window corners via KWin compositor.
- **Optimized Shell:** Zsh as the default shell with autosuggestions and syntax highlighting.
- **Custom Branding:** Plymouth boot splash and Calamares graphical installer with KibaOS branding.
- **Essential Apps:** Firefox ESR, Dolphin, Konsole, Kate, VLC, GParted included.
- **Performance:** No bloat — only what you need is installed.

---

## 📦 Quick Start

### 📥 Download

ISO images are available on SourceForge:
👉 [Download KibaOS on SourceForge](https://sourceforge.net/projects/kibaos/files/)

SHA256 checksums are provided alongside each release. Always verify your download.

### 💿 Writing to a USB Drive

On Linux:
```bash
sudo dd if=kibaos-vN.iso of=/dev/sdX bs=4M status=progress oflag=sync
```
> [!IMPORTANT]
> Replace `/dev/sdX` with your actual drive and `N` with the build number. You can also use tools like **Balena Etcher** or **Ventoy**.

### 🖥️ Live Session

Boot from the USB drive to enter the live environment. The session logs in automatically.

> [!NOTE]
> No changes made in the live session are saved after reboot. To install KibaOS permanently, launch the **Calamares** installer from the desktop.

#### 🔑 Default Credentials (Live Session Only)

| Account | Password |
|---------|----------|
| `user`  | `live`   |
| `root`  | `root`   |

### ⚙️ Installation

The Calamares installer guides you through:
1. Language and locale selection
2. Keyboard layout
3. Disk partitioning (automatic or manual)
4. User account creation
5. Installation and bootloader setup

Post-install, update your system:
```bash
sudo apt update && sudo apt upgrade -y
```

---

## 🛠️ Technical Details

### 💻 Shell

KibaOS uses **Zsh** by default with a pre-configured system-wide config at `/etc/zsh/zshrc`:
- Shared history across sessions.
- Tab completion with menu select.
- Autosuggestions & syntax highlighting.
- Minimalist Dracula-themed prompt.

**Useful Aliases:**
- `ll` -> `ls -lah`
- `update` -> `sudo apt update && sudo apt upgrade -y`
- `install` -> `sudo apt install`

### 🎨 Theme

KibaOS ships the Dracula color scheme system-wide using the official palette from [draculatheme.com](https://draculatheme.com).

| Color | Hex | Role |
|-------|-----|------|
| Background | `#282a36` | Primary BG |
| Purple | `#bd93f9` | Accent Color |
| Pink | `#ff79c6` | Selection |
| Green | `#50fa7b` | Success |

The scheme is applied to KDE Plasma, Konsole, KWin decorations, Breeze Dark panel, and Plymouth.

### 🖥️ System Requirements

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| **CPU** | 64-bit x86 (amd64) | Dual-core or better |
| **RAM** | 2 GB | 4 GB |
| **Disk** | 20 GB | SSD recommended |
| **GPU** | OpenGL 2.0 support | Dedicated GPU |

---

## 🏗️ Build System

KibaOS is built using `live-build` inside a Debian Trixie Docker container via GitHub Actions.

- **Orchestration:** `.github/workflows/kiba.yml`
- **Automation:** Workflow runs on push to `main`, weekly schedules, and manual dispatch.
- **Delivery:** Completed ISOs are automatically uploaded to SourceForge from the `main` branch.

### 🔨 Building Locally

Requirements: Docker, a Linux host with at least 15 GB free space.

```bash
git clone https://github.com/WolfTech-Innovations/Kiba
cd Kiba
docker run --rm --privileged \
  -v "$PWD:/w" \
  -e RUN_NUM=local \
  debian:trixie \
  /w/build.sh
```

> [!NOTE]
> The `build.sh` script is generated at build-time by the GitHub Actions workflow and contains the full configuration and customization hooks.

---

## 📁 Project Structure

```text
Kiba/
├── .github/
│   └── workflows/
│       └── kiba.yml           # Main build and release workflow
├── branding/
│   └── kibaos_banner.png      # KibaOS brand assets
└── README.md                  # Project documentation
```

---

## 🤝 Contributing

Issues and pull requests are welcome at the [WolfTech-Innovations/Kiba](https://github.com/WolfTech-Innovations/Kiba) repository. Please open an issue before starting significant work.

---

## 📜 License

KibaOS is a distribution, not a single codebase. Individual components are subject to their own licenses. The build scripts and configuration files in this repository are released under the **MIT License**.

---

## 🏢 About

KibaOS is a **WolfTech Innovations** project.
[Visit our GitHub](https://github.com/WolfTech-Innovations)
