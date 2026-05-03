
# Software Management

<p align="center">
  <img src="../branding/kibaos_banner.png" alt="KibaOS Banner" width="100%">
</p>

<p align="center">
  <img src="`https://img.shields.io/badge/Manager-KibaStore-purple?style=for-the-badge`" alt="KibaStore">
  <img src="`https://img.shields.io/badge/CLI-Nala-blue?style=for-the-badge`" alt="Nala">
  <img src="`https://img.shields.io/badge/Package-Flatpak-orange?style=for-the-badge`" alt="Flatpak">
</p>

---

KibaOS provides a dual-layered approach to software management: a beginner-friendly graphical store and a powerful, modern command-line interface.

---

\n## KibaStore (Bazaar)

The primary graphical interface for managing software in KibaOS is **KibaStore**, which is a native implementation of **Bazaar**.

#\n## Native Build Philosophy

Unlike other distributions that ship heavy, generic software centers, KibaStore is:

- **Built from Source:** Compiled during the ISO build process using `meson` and `ninja`.
- **Lightweight:** Designed specifically to manage **Flatpaks** without the overhead of the full GNOME or KDE software suites.
- **Modern UI:** Built with **GTK4** and **Libadwaita**, providing a sleek and responsive user interface.

#\n## Flatpak Integration

KibaStore comes pre-configured with the **Flathub** remote. This gives you instant access to thousands of sandboxed applications like:

- **Productivity:** LibreOffice, Obsidian, Slack.
- **Creative:** GIMP, Inkscape, OBS Studio.
- **Gaming:** Steam, Heroic Games Launcher, Discord.

---

\n## Terminal Package Management (Nala)

For those who prefer the command line, KibaOS defaults to **Nala** — a modern frontend for `apt` that makes package management beautiful and safer.

#\n## Why Nala?

- **Parallel Downloads:** Downloads multiple packages simultaneously to save time.
- **Transaction History:** View every install/remove operation and easily **undo** changes.
- **Beautiful Output:** Clearer, color-coded summaries of what will be installed or removed.

#\n## Common Commands

| Task                     | Command                                                        |
| :----------------------- | :------------------------------------------------------------- |
| **Update system**        | `update` _(Alias for `sudo nala update && sudo nala upgrade`)_ |
| **Search for a package** | `search <name>`                                                |
| **Install a package**    | `install <name>`                                               |
| **Remove a package**     | `remove <name>`                                                |
| **View history**         | `nala history`                                                 |
| **Undo an operation**    | `sudo nala history undo <ID>`                                  |

> [!NOTE]
> For maximum convenience, `apt` and `apt-get` are system-wide aliases for `nala`. You can continue using your muscle memory while enjoying Nala's features.

---

\n## Specialized Repositories

#\n## Ungoogled Chromium

KibaOS includes **Ungoogled Chromium** as a privacy-focused browser alternative. It is integrated into the system via a dedicated Open Build Service (OBS) repository to ensure regular updates directly from the source.

#\n## Modern CLI Suite

As detailed in the [UX Design](./ux-design.md) document, KibaOS ships with a suite of modern CLI tools like `eza`, `bat`, `btop`, and `yt-dlp` to provide a superior terminal experience.

KibaOS includes **Ungoogled Chromium** as the default browser for users who prioritize privacy. It is integrated via a dedicated **OBS (Open Build Service)** repository, ensuring you receive timely security updates directly from the source.

#\n## Flatpak (CLI)

While KibaStore is the preferred way to browse, you can manage Flatpaks directly from the terminal:

```bash

## Search for an app

flatpak search <name>

## Install an app

flatpak install flathub <app-id>
```bash

---

\n## Related Reading

- [**Architecture**](./architecture.md)
- [**UX & Design**](./ux-design.md)
- [**WIKI**](../WIKI.md)
