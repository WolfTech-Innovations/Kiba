# KibaOS
![Banner](https://github.com/WolfTech-Innovations/Kiba/blob/18c12ea77043ab04b0cd34722c75073a0f861c20/branding/kibaos_banner.png)
KibaOS is a lightweight Linux distribution built on Debian 13 (Trixie) with KDE Plasma 6 as the desktop environment. It is developed and maintained by WolfTech Innovations.

[![Download KibaOS](https://a.fsdn.com/con/app/sf-download-button)](https://sourceforge.net/projects/kibaos/files/latest/download)

_____ 

The goal of KibaOS is to provide a clean, modern, and visually consistent out-of-the-box experience without requiring post-install configuration. Everything from the boot splash to the terminal color scheme is pre-configured and ready to use.

---

## Features

- Based on Debian 13 Trixie (stable, supported until 2030)
- KDE Plasma 6.3 with Wayland as the default session
- Dracula color scheme applied system-wide — terminal, widgets, window decorations, and the panel
- Floating rounded taskbar and 12px rounded window corners via KWin compositor
- Zsh as the default shell with autosuggestions and syntax highlighting pre-configured
- Plymouth boot splash using the KibaOS logo on a Dracula-themed background
- Calamares graphical installer with KibaOS branding
- SDDM login manager with autologin for the live session
- Firefox ESR, Dolphin, Konsole, Kate, VLC, GParted included
- No bloat — only what you need is installed

---

## System Requirements

| Component | Minimum |
|-----------|---------|
| CPU | 64-bit x86 (amd64) |
| RAM | 2 GB (4 GB recommended) |
| Disk | 20 GB for installation |
| GPU | Any with OpenGL 2.0 support |
| Firmware | UEFI or legacy BIOS |

---

## Download

ISO images are available on SourceForge:

https://sourceforge.net/projects/kibaos/files/

SHA256 checksums are provided alongside each release. Verify your download before writing to a drive.

---

## Writing to a USB Drive

On Linux:

```
sudo dd if=kibaos-vN.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

Replace `/dev/sdX` with your actual drive and `N` with the build number. You can also use tools like Balena Etcher or Ventoy.

---

## Live Session

Boot from the USB drive to enter the live environment. The live session logs in automatically as the `user` account with the password `live`. Root password is `root`.

No changes made in the live session are saved after reboot. To install KibaOS permanently, launch the Calamares installer from the desktop or application menu.

---

## Installation

The Calamares installer guides you through:

1. Language and locale selection
2. Keyboard layout
3. Disk partitioning (automatic or manual)
4. User account creation
5. Installation and bootloader setup

A working internet connection is not required for installation. An internet connection is recommended post-install for system updates.

After installation, update the system:

```
sudo apt update && sudo apt upgrade -y
```

---

## Default Credentials (Live Session Only)

| Account | Password |
|---------|----------|
| user | live |
| root | root |

These credentials are only present in the live session. The installer will prompt you to create your own account and set your own passwords.

---

## Shell

KibaOS uses Zsh by default. The system-wide config is at `/etc/zsh/zshrc` and includes:

- Shared history across sessions
- Tab completion with menu select
- Autosuggestions from command history
- Syntax highlighting
- A minimal prompt showing user, host, and current directory

Useful aliases pre-configured:

```
ll        -> ls -lah
update    -> sudo apt update && sudo apt upgrade -y
install   -> sudo apt install
```

---

## Theme

KibaOS ships the Dracula color scheme system-wide using the official palette from draculatheme.com.

| Color | Hex |
|-------|-----|
| Background | #282a36 |
| Current Line | #44475a |
| Foreground | #f8f8f2 |
| Comment | #6272a4 |
| Purple (accent) | #bd93f9 |
| Pink | #ff79c6 |
| Cyan | #8be9fd |
| Green | #50fa7b |
| Yellow | #f1fa8c |
| Orange | #ffb86c |
| Red | #ff5555 |

The Dracula scheme is applied to:

- KDE color roles (all widgets, dialogs, menus)
- Konsole terminal
- KWin window decorations and shadow color
- Breeze Dark panel theme
- Plymouth boot splash background

---

## Build System

KibaOS is built using `live-build` inside a Debian Trixie Docker container via GitHub Actions. The workflow runs on push to `main` or `develop`, on manual dispatch, and on a weekly schedule every Sunday at 02:00 UTC.

Completed ISOs are automatically uploaded to SourceForge when building from the `main` branch.

### Building Locally

Requirements: Docker, a Linux host with sufficient disk space (at least 15 GB free).

```
git clone https://github.com/WolfTech-Innovations/kibaos
cd kibaos
docker run --rm --privileged \
  -v "$PWD:/w" \
  -e RUN_NUM=local \
  debian:trixie \
  /w/build.sh
```

The resulting ISO will appear in the project root as `kibaos-vlocal.iso`.

### SourceForge Upload

Set the following repository secrets to enable automatic uploads:

| Secret | Description |
|--------|-------------|
| SF_USER | Your SourceForge username |
| SF_PASS | Your SourceForge password |

---

## Project Structure

```
kibaos/
  .github/
    workflows/
      kiba-build.yml    - Main build and release workflow
  README.md
```

Build configuration, package lists, hooks, and Calamares branding are all generated at build time by the workflow script.

---

## Contributing

Issues and pull requests are welcome at:

https://github.com/WolfTech-Innovations/kibaos

Please open an issue before starting significant work so effort is not duplicated.

---

## License

KibaOS is a distribution, not a single codebase. Individual components are subject to their own licenses. The build scripts and configuration files in this repository are released under the MIT License.

---

## About

KibaOS is a WolfTech Innovations project.

https://github.com/WolfTech-Innovations

