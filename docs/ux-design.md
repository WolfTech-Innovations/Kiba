# UX & Visual Design

<p align="center">
  <img src="../branding/kibaos_banner.png" alt="KibaOS Logo: A minimalist dark blue geometric emblem" width="100%">
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Theme-KibaOS-0099cc?style=for-the-badge" alt="Theme">
  <img src="https://img.shields.io/badge/Desktop-Budgie-22a7f0?style=for-the-badge" alt="Desktop">
  <img src="https://img.shields.io/badge/Font-Inter-white?style=for-the-badge" alt="Font">
</p>

---

KibaOS is built with a focus on "modern simplicity." This document details the visual identity, the blue-accented aesthetic, and the highly optimized terminal experience.

---

## Table of Contents

- [Visual Identity](#visual-identity)
  - [Color Palette](#color-palette)
  - [Look and Feel](#look-and-feel)
  - [Window Management](#window-management)
- [Shell Experience](#shell-experience)
  - [KibaOS Prompt](#kibaos-prompt)
  - [Modern CLI Tools](#modern-cli-tools)
  - [System-wide Aliases](#system-wide-aliases)
- [Boot Branding](#boot-branding)
  - [Interface Components](#interface-components)
  - [Typography](#typography)
- [Desktop Experience (Budgie Desktop)](#desktop-experience-budgie)
  - [Window Management Polish](#window-management-polish)
  - [Desktop Layout](#desktop-layout)
- [The Modern Terminal](#the-modern-terminal)
  - [Shell Configuration (Bash)](#shell-configuration-bash)
- [Related Reading](#related-reading)

---

## Visual Identity

The KibaOS aesthetic is built around the official blue color palette, providing a high-contrast, dark interface that reduces eye strain and looks modern.

### Color Palette

| Color          | Hex       | Role                                    |
| :------------- | :-------- | :-------------------------------------- |
| **Background** | `#0d1b2a` | Primary window and desktop background   |
| **Surface**    | `#ffffff` | Light surface and card background       |
| **Accent**     | `#0099cc` | Primary branding and interactive states |
| **Sub-text**   | `#4a5a70` | Secondary text and disabled elements    |

### Look and Feel

- **Desktop Environment:** Budgie Desktop.
- **Global Theme:** **ChromeOS-Dark**.
- **Color Scheme:** **KibaOS Blue**, applied system-wide to widgets and applications.
- **Icons:** **Kora** icon theme for a colorful and modern look.
- **Cursors:** **Vimix-Cursors** theme.
- **Fonts:** **Inter** for the system UI and **JetBrains Mono** for monospace/terminal text.

### Window Management

- **Rounded Corners:** **labwc** is configured to provide 14px rounded corners for all windows.
- **Liquid Glass:** Panels and popovers use a floating, translucent liquid glass effect.
- **Floating Panel:** The Budgie panel is configured as a floating liquid glass pill by default.

## Shell Experience

KibaOS provides a highly optimized terminal experience using **Bash** as the default shell for all users.

### KibaOS Prompt

A custom KibaOS branded prompt is pre-configured to be fast and minimalist.

### Modern CLI Tools

We prefer high-performance tools and system utilities:

- **`fastfetch`**: A fast and highly customizable system information tool.
- **`gnupg`**: Full GPG integration for security.
- **`imagemagick`**: Advanced image processing via the command line.

### System-wide Aliases

Common aliases are configured to improve workflow:

- `ll` -> `ls -lah`
- `update` -> `sudo pacman -Syu`
- `install` -> `sudo pacman -S`

## Boot Branding

The branding experience starts from the moment the system boots:

- **Plymouth:** A custom "kibaos" theme with a blue-accented progress bar.
- **Boot Menu:** Branded **Systemd-boot** or **GRUB** depending on your hardware.

### Interface Components

- **Global Theme:** **ChromeOS-Dark**, providing a consistent base for all applications.
- **Icons:** The **Kora** icon theme offers a colorful, modern, and high-resolution set of assets.
- **Cursors:** **Vimix-Cursors** are used for a sleek, high-visibility pointer experience.
- **Typography:**
  - **System UI:** **Inter** (11pt) — A modern sans-serif designed for screens.
  - **Monospace:** **JetBrains Mono** (11pt) — Optimized for code and terminal legibility.

---

## Desktop Experience (Budgie Desktop)

KibaOS leverages the power of **Budgie Desktop** but configures it for a streamlined "out-of-the-box" experience.

### Window Management Polish

- **Rounded Corners:** **labwc** applies 14px rounded corners to all windows.
- **Liquid Glass:** Floating translucent panels and popovers with organic motion easing.
- **Floating Panel:** The system panel is configured as a floating liquid glass pill at the bottom.

### Desktop Layout

- **Minimalist Panel:** Contains the application launcher, task manager, system tray, and clock.
- **Clean Desktop:** No icons by default, keeping the workspace clutter-free.

---

## The Modern Terminal

KibaOS provides one of the most powerful terminal experiences of any distribution, replacing aging Unix utilities with modern, faster, and more feature-rich alternatives.

### Shell Configuration (Bash)

**Bash** is the default shell for all users, pre-configured with:

- **KibaOS Prompt:** A minimalist, fast, and branded shell prompt.
- **XDG Standards:** Full compliance with XDG Base Directory Specification.
- **Fastfetch:** Automatic system information display on login.

---

## Related Reading

- [**Architecture**](./architecture.md)
- [**Software Management**](./software-management.md)
- [**WIKI**](../WIKI.md)
