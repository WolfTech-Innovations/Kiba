
# UX & Visual Design

<p align="center">
  <img src="../branding/kibaos_banner.png" alt="KibaOS Banner" width="100%">
</p>

<p align="center">
  <img src="`https://img.shields.io/badge/Theme-Dracula-bd93f9?style=for-the-badge`&logo=dracula" alt="Theme">
  <img src="`https://img.shields.io/badge/Desktop-KDE`%20Plasma%206-22a7f0?style=for-the-badge&logo=kde" alt="Desktop">
  <img src="`https://img.shields.io/badge/Font-Inter-white?style=for-the-badge`" alt="Font">
</p>

---

KibaOS is built with a focus on "modern simplicity." This document details the visual identity, the Dracula-inspired aesthetic, and the highly optimized terminal experience.

---

\n## Visual Identity

The KibaOS aesthetic is built around the official **Dracula** color palette, providing a high-contrast, dark interface that reduces eye strain and looks modern.

#\n## Color Palette

| Color            | Hex       | Role                                                     |
| :--------------- | :-------- | :------------------------------------------------------- |
| **Background**   | `#282a36` | Primary window and desktop background                    |
| **Current Line** | `#44475a` | Highlight and secondary background                       |
| **Foreground**   | `#f8f8f2` | Primary text color                                       |
| **Comment**      | `#6272a4` | Secondary text and disabled elements                     |
| **Purple**       | `#bd93f9` | Accent color, selection background, and primary branding |
| **Pink**         | `#ff79c6` | Selection foreground and highlights                      |
| **Green**        | `#50fa7b` | Success states and active terminal elements              |

#\n## Look and Feel

- **Desktop Environment:** KDE Plasma 6.3.
- **Global Theme:** A customized version of **Ant-Dark**.
- **Color Scheme:** **Dracula**, applied system-wide to Plasma widgets, window decorations, and applications.
- **Icons:** **Kora** icon theme for a colorful and modern look.
- **Cursors:** **Vimix** cursor theme.
- **Fonts:** **Inter** for the system UI and **JetBrains Mono** for monospace/terminal text.

#\n## Window Management

- **Rounded Corners:** KWin is configured to provide 16px rounded corners for all windows.
- **Glass Effects:** Blur and contrast effects are enabled for an elegant, translucent look.
- **Floating Panel:** The Plasma panel is configured to be floating and rounded by default.

\n## Shell Experience

KibaOS provides a highly optimized terminal experience using **Zsh** as the default shell for all users.

#\n## Starship Prompt

The **Starship** cross-shell prompt is pre-installed and configured with a minimalist Dracula-themed layout.

#\n## Modern CLI Tools

We prefer modern, faster alternatives to classic Unix commands:

- **`nala`**: A beautiful and feature-rich frontend for `apt`.
- **`eza`**: A modern replacement for `ls` with icons and color-coding.
- **`bat`**: A `cat` clone with syntax highlighting and Git integration.
- **`fastfetch`**: A fast and highly customizable system information tool.
- **`btop`**: An interactive resource monitor.
- **`ripgrep` (`rg`)**: An extremely fast alternative to `grep`.
- **`fd-find` (`fd`)**: A simple, fast, and user-friendly alternative to `find`.
- **`tealdeer` (`tldr`)**: A fast implementation of `tldr` for simplified man pages.

#\n## System-wide Aliases

Common aliases are configured in `/etc/zsh/zshrc` to improve workflow:

- `apt` -> `nala`
- `ls` -> `eza`
- `cat` -> `bat`
- `grep` -> `ripgrep`
- `update` -> `sudo nala update && sudo nala upgrade -y`
- `edit` -> `micro` (System default editor)
- `please` -> `sudo`
- `cls` -> `clear`
- `path` -> Multi-line `$PATH` overview

\n## Boot Branding

The branding experience starts from the moment the system boots:

- **Plymouth:** A custom "kibaos-spinner" theme with a Dracula-themed progress bar.
- **Grub**

#\n## Interface Components

- **Global Theme:** A customized **Ant-Dark** theme, providing a consistent base for all applications.
- **Icons:** The **Kora** icon theme offers a colorful, modern, and high-resolution set of assets.
- **Cursors:** **Vimix-cursors** are used for a sleek, high-visibility pointer experience.
- **Typography:**
  - **System UI:** **Inter** (11pt) — A modern sans-serif designed for screens.
  - **Monospace:** **JetBrains Mono** (11pt) — Optimized for code and terminal legibility.

---

\n## Desktop Experience (Plasma 6)

KibaOS leverages the power of **KDE Plasma 6.3** but configures it for a streamlined "out-of-the-box" experience.

#\n## Window Management Polish

- **Rounded Corners:** Custom **KWin** rules apply 16px rounded corners to all windows.
- **Glass Effects:** Background blur and translucency are enabled for an elegant, layered look.
- **Floating Panel:** The system panel is configured to be floating and rounded by default, located at the bottom of the screen.

#\n## Desktop Layout

- **Minimalist Panel:** Contains the application launcher, task manager, system tray, and clock.
- **Clean Desktop:** No icons by default, keeping the workspace clutter-free.

---

\n## The Modern Terminal

KibaOS provides one of the most powerful terminal experiences of any distribution, replacing aging Unix utilities with modern, faster, and more feature-rich alternatives.

#\n## Modern Alternative Comparison

| Classic Command | Modern Alternative   | Key Feature                                       |
| :-------------- | :------------------- | :------------------------------------------------ |
| `ls`            | **`eza`**            | Icons, Git status integration, and better colors. |
| `cat`           | **`bat`**            | Syntax highlighting and Git integration.          |
| `grep`          | **`ripgrep`** (`rg`) | Extremely fast recursive search.                  |
| `find`          | **`fd`**             | Simple, fast, and user-friendly syntax.           |
| `top`           | **`btop`**           | Beautiful interactive resource monitoring.        |
| `df`            | **`duf`**            | Clear, color-coded disk usage overview.           |
| `du`            | **`ncdu`**           | Interactive disk usage analyzer.                  |
| `apt`           | **`nala`**           | Parallel downloads and clear transaction history. |

#\n## Shell Configuration (Zsh)

**Zsh** is the default shell for all users, pre-configured with:

- **Starship Prompt:** A minimalist, fast, and informative cross-shell prompt.
- **Autosuggestions:** Fish-like autosuggestions as you type.
- **Syntax Highlighting:** Real-time highlighting of commands and arguments.
- **FZF Integration:** Fuzzy finding for command history and file navigation.

---

\n## Related Reading

- [**Architecture**](./architecture.md)
- [**Software Management**](./software-management.md)
- [**WIKI**](../WIKI.md)
