# Software Management

<p align="center">
  <img src="../branding/kibaos_banner.png" alt="KibaOS Banner" width="100%">
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Manager-GNOME%20Software-blue?style=for-the-badge" alt="GNOME Software">
  <img src="https://img.shields.io/badge/CLI-Pacman-blue?style=for-the-badge" alt="Pacman">
  <img src="https://img.shields.io/badge/Package-Flatpak-orange?style=for-the-badge" alt="Flatpak">
</p>

---

KibaOS provides a dual-layered approach to software management: a beginner-friendly graphical store and a powerful, modern command-line interface.

---

## GNOME Software

The primary graphical interface for managing software in KibaOS is **GNOME Software**.

### Flatpak Integration

GNOME Software comes pre-configured with the **Flathub** remote. This gives you instant access to thousands of sandboxed applications like:

- **Productivity:** LibreOffice, Obsidian, Slack.
- **Creative:** GIMP, Inkscape, OBS Studio.
- **Gaming:** Steam, Heroic Games Launcher, Discord.

---

## Terminal Package Management (Pacman)

For those who prefer the command line, KibaOS uses **Pacman**.

### Why Pacman

- **Parallel Downloads:** Downloads multiple packages simultaneously to save time.
- **Robustness:** The industry standard for Arch Linux package management.

### Common Commands

| Task                     | Command                                         |
| :----------------------- | :---------------------------------------------- |
| **Update system**        | `update` _(Alias for `sudo pacman -Syu`)_       |
| **Search for a package** | `pacman -Ss <name>`                             |
| **Install a package**    | `install <name>` _(Alias for `sudo pacman -S`)_ |
| **Remove a package**     | `sudo pacman -R <name>`                         |
| **View info**            | `pacman -Qi <name>`                             |

---

## Specialized Repositories

### Modern CLI Suite

As detailed in the [UX Design](./ux-design.md) document, KibaOS ships with a suite of modern CLI tools like `fastfetch` to provide a superior terminal experience.

### Flatpak (CLI)

You can manage Flatpaks directly from the terminal:

```bash
## Search for an app
flatpak search <name>

## Install an app
flatpak install flathub <app-id>
```

---

## Related Reading

- [**Architecture**](./architecture.md)
- [**UX & Design**](./ux-design.md)
- [**WIKI**](../WIKI.md)
