# UX & Visual Design

<p align="center">
  <img src="../branding/kibaos_banner.png" alt="KibaOS Banner" width="100%">
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Theme-Dracula-bd93f9?style=for-the-badge" alt="Theme">
  <img src="https://img.shields.io/badge/Desktop-Cutefish-22a7f0?style=for-the-badge" alt="Desktop">
  <img src="https://img.shields.io/badge/Font-Inter-white?style=for-the-badge" alt="Font">
</p>

---

KibaOS is built with a focus on "modern simplicity." This document details the visual identity, the Dracula-inspired aesthetic, and the highly optimized terminal experience.

---

## Table of Contents

- [Visual Identity](#visual-identity)
  - [Color Palette](#color-palette)
  - [Look and Feel](#look-and-feel)
  - [Typography](#typography)
- [Shell Experience](#shell-experience)
  - [Starship Prompt](#starship-prompt)
  - [Modern CLI Tools](#modern-cli-tools)
  - [System-wide Aliases](#system-wide-aliases)
- [Boot Branding](#boot-branding)
- [Desktop Experience (Cutefish OS)](#desktop-experience-cutefish-os)
  - [Window Management](#window-management)
  - [Desktop Layout](#desktop-layout)
- [The Modern Terminal](#the-modern-terminal)
  - [Modern Alternative Comparison](#modern-alternative-comparison)
  - [Shell Configuration (Zsh)](#shell-configuration-zsh)
- [Related Reading](#related-reading)

---

## Visual Identity

The KibaOS aesthetic is built around the official **Dracula** color palette, providing a high-contrast, dark interface that reduces eye strain and looks modern.

### Color Palette

| Color | Hex | Role |
| :---- | :-- | :--- |
| **Background** | `#282a36` | Primary window and desktop background |
| **Current Line** | `#44475a` | Highlight and secondary background |
| **Foreground** | `#f8f8f2` | Primary text color |
| **Comment** | `#6272a4` | Secondary text and disabled elements |
| **Purple** | `#bd93f9` | Accent color, selection background, and primary branding |
| **Pink** | `#ff79c6` | Selection foreground and highlights |
| **Green** | `#50fa7b` | Success states and active terminal elements |

### Look and Feel

- **Desktop Environment:** Cutefish OS
- **Global Theme:** A customized version of **Ant-Dark**
- **Color Scheme:** **Dracula**, applied system-wide to Plasma widgets, window decorations, and applications
- **Icons:** **Kora** icon theme for a colorful and modern look
- **Cursors:** **Vimix** cursor theme

### Typography

- **System UI:** **Inter** (11pt) — A modern sans-serif designed for screens
- **Monospace:** **JetBrains Mono** (11pt) — Optimized for code and terminal legibility

---

## Shell Experience

KibaOS provides a highly optimized terminal experience using **Zsh** as the default shell for all users.

### Starship Prompt

The **Starship** cross-shell prompt is pre-installed and configured with a minimalist Dracula-themed layout. It provides:
- Fast, informative prompt
- Git status integration
- Clear visual hierarchy
- Customizable modules

### Modern CLI Tools

We prefer modern, faster alternatives to classic Unix commands:

| Classic Command | Modern Alternative | Key Feature |
| :-------------- | :----------------- | :---------- |
| `ls` | **`eza`** | Icons, Git status integration, and better colors |
| `cat` | **`bat`** | Syntax highlighting and Git integration |
| `grep` | **`ripgrep`** (`rg`) | Extremely fast recursive search |
| `find` | **`fd`** | Simple, fast, and user-friendly syntax |
| `top` | **`btop`** | Beautiful interactive resource monitoring |
| `df` | **`duf`** | Clear, color-coded disk usage overview |
| `du` | **`ncdu`** | Interactive disk usage analyzer |
| `neofetch` | **`fastfetch`** | Fast and highly customizable system information |

### System-wide Aliases

Common aliases are configured in `/etc/zsh/zshrc` to improve workflow:

- `update` → `sudo pacman -Syu` (System update)
- `please` → `sudo` (Friendly sudo)
- `cls` → `clear` (Clear screen)
- `path` → Multi-line `$PATH` overview

---

## Boot Branding

The branding experience starts from the moment the system boots:

- **Plymouth:** Custom "kibaos-spinner" theme with a Dracula-themed progress bar and logo
- **GRUB:** Branded boot menu with plain-English options for beginners

---

## Desktop Experience (Cutefish OS)

KibaOS leverages the power of **Cutefish OS** but configures it for a streamlined "out-of-the-box" experience.

### Window Management

- **Rounded Corners:** Custom KWin rules apply rounded corners to all windows
- **Glass Effects:** Background blur and translucency are enabled for an elegant, layered look
- **Smooth Animations:** Window transitions and effects are optimized for responsiveness

### Desktop Layout

- **Minimalist Panel:** Contains the application launcher, task manager, system tray, and clock
- **Clean Desktop:** No icons by default, keeping the workspace clutter-free
- **Floating Panel:** The system panel is configured to be floating and rounded by default

---

## The Modern Terminal

KibaOS provides one of the most powerful terminal experiences of any distribution, replacing aging Unix utilities with modern, faster, and more feature-rich alternatives.

### Modern Alternative Comparison

All classic Unix commands have modern replacements pre-installed:

| Classic | Modern | Benefit |
| :------ | :----- | :------ |
| `ls` | `eza` | Icons, Git status, colors |
| `cat` | `bat` | Syntax highlighting |
| `grep` | `ripgrep` | Faster recursive search |
| `find` | `fd` | User-friendly syntax |
| `top` | `btop` | Interactive UI |
| `df` | `duf` | Better disk usage display |
| `neofetch` | `fastfetch` | Faster, more customizable |

### Shell Configuration (Zsh)

**Zsh** is the default shell for all users, pre-configured with:

- **Starship Prompt:** A minimalist, fast, and informative cross-shell prompt
- **Autosuggestions:** Fish-like autosuggestions as you type
- **Syntax Highlighting:** Real-time highlighting of commands and arguments
- **FZF Integration:** Fuzzy finding for command history and file navigation

---

## Related Reading

- [**Architecture**](./architecture.md)
- [**Software Management**](./software-management.md)
- [**WIKI**](../WIKI.md)
