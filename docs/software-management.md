# Software Management

<p align="center">
  <img src="../branding/kibaos_banner.png" alt="KibaOS Banner" width="100%">
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Manager-KibaStore-purple?style=for-the-badge" alt="KibaStore">
  <img src="https://img.shields.io/badge/CLI-Pacman-blue?style=for-the-badge" alt="Pacman">
  <img src="https://img.shields.io/badge/Package-Flatpak-orange?style=for-the-badge" alt="Flatpak">
</p>

---

KibaOS provides a dual-layered approach to software management: a beginner-friendly graphical store and a powerful, modern command-line interface.

---

## Table of Contents

- [KibaStore (Bazaar)](#kibastore-bazaar)
  - [Native Build Philosophy](#native-build-philosophy)
  - [Flatpak Integration](#flatpak-integration)
- [Terminal Package Management (Pacman)](#terminal-package-management-pacman)
  - [Why Pacman](#why-pacman)
  - [Common Commands](#common-commands)
- [Specialized Repositories](#specialized-repositories)
  - [Ungoogled Chromium](#ungoogled-chromium)
  - [Modern CLI Suite](#modern-cli-suite)
- [Flatpak (CLI)](#flatpak-cli)
- [Related Reading](#related-reading)

---

## KibaStore (Bazaar)

The primary graphical interface for managing software in KibaOS is **KibaStore**, which is a native implementation of **Bazaar**.

### Native Build Philosophy

Unlike other distributions that ship heavy, generic software centers, KibaStore is:

- **Built from Source:** Compiled during the ISO build process using `meson` and `ninja`
- **Lightweight:** Designed specifically to manage **Flatpaks** without the overhead of the full GNOME or KDE software suites
- **Modern UI:** Built with **GTK4** and **Libadwaita**, providing a sleek and responsive user interface

### Flatpak Integration

KibaStore comes pre-configured with the **Flathub** remote. This gives you instant access to thousands of sandboxed applications like:

- **Productivity:** LibreOffice, Obsidian, Slack
- **Creative:** GIMP, Inkscape, OBS Studio
- **Gaming:** Steam, Heroic Games Launcher, Discord
- **Utilities:** File Roller, GNOME Calculator, Text Editor

---

## Terminal Package Management (Pacman)

For those who prefer the command line, KibaOS defaults to **Pacman** — a modern frontend for `pacman` that makes package management beautiful and safer.

### Why Pacman

- **Parallel Downloads:** Downloads multiple packages simultaneously to save time
- **Transaction History:** View every install/remove operation and easily **undo** changes
- **Beautiful Output:** Clearer, color-coded summaries of what will be installed or removed

### Common Commands

| Task | Command | Description |
| :--- | :------ | :---------- |
| **Update system** | `update` | Alias for `sudo pacman -Syu` |
| **Search for a package** | `pacman -Ss <name>` | Search in repositories |
| **Install a package** | `pacman -S <name>` | Install package |
| **Remove a package** | `pacman -R <name>` | Remove package |
| **View history** | `pacman -Qi` | View package info |
| **Clean cache** | `pacman -Sc` | Clean package cache |

> [!NOTE]
> System-wide aliases are configured in `/etc/zsh/zshrc` for convenience. The `update` alias is pre-configured for easy system updates.

---

## Specialized Repositories

### Ungoogled Chromium

KibaOS includes **Ungoogled Chromium** as the default browser for users who prioritize privacy. It is integrated via a dedicated **OBS (Open Build Service)** repository, ensuring you receive timely security updates directly from the source.

Features:
- All Google tracking and background services removed
- Privacy-focused browsing experience
- Regular security updates

### Modern CLI Suite

As detailed in the [UX Design](./ux-design.md) document, KibaOS ships with a suite of modern CLI tools:

| Classic Command | Modern Alternative | Key Feature |
| :-------------- | :----------------- | :---------- |
| `ls` | `eza` | Icons, Git status, better colors |
| `cat` | `bat` | Syntax highlighting, Git integration |
| `grep` | `ripgrep` (`rg`) | Extremely fast recursive search |
| `find` | `fd-find` (`fd`) | Simple, fast, user-friendly syntax |
| `top` | `btop` | Beautiful interactive resource monitoring |
| `df` | `duf` | Clear, color-coded disk usage overview |
| `du` | `ncdu` | Interactive disk usage analyzer |

---

## Flatpak (CLI)

While KibaStore is the preferred way to browse, you can manage Flatpaks directly from the terminal:

### Search for an app
```bash
flatpak search <name>
```

### Install an app
```bash
flatpak install flathub <app-id>
```

### Run an app
```bash
flatpak run <app-id>
```

### Update all Flatpaks
```bash
flatpak update
```

---

## Related Reading

- [**Architecture**](./architecture.md)
- [**UX & Design**](./ux-design.md)
- [**WIKI**](../WIKI.md)
