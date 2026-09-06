# Frequently Asked Questions (FAQ)

<p align="center">
  <img src="../branding/kibaos_banner.png" alt="KibaOS Banner" width="100%">
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Status-Helpful-blue?style=for-the-badge" alt="Helpful">
</p>

---

## Table of Contents

- [General Questions](#general-questions)
  - [What is KibaOS?](#what-is-kibaos)
  - [Why "Kiba"?](#why-kiba)
  - [Who is KibaOS for?](#who-is-kibaos-for)
- [Technical Questions](#technical-questions)
  - [Why Arch Linux Rolling (Testing)?](#why-arch-linux-rolling-testing)
  - [What is the CachyOS Kernel?](#what-is-the-cachyos-kernel)
  - [How do I update KibaOS?](#how-do-i-update-kibaos)
  - [Can I change the theme?](#can-i-change-the-theme)
- [Software Questions](#software-questions)
  - [What is KibaStore?](#what-is-kibastore)
  - [Why Ungoogled Chromium?](#why-ungoogled-chromium)
  - [Can I install standard Arch packages?](#can-i-install-standard-arch-packages)
- [Troubleshooting](#troubleshooting)
  - [The installer didn't start automatically](#the-installer-didnt-start-automatically)
  - [My Wi-Fi isn't working](#my-wi-fi-isnt-working)
  - [I need proprietary drivers](#i-need-proprietary-drivers)
- [Related Reading](#related-reading)

---

## General Questions

### What is KibaOS

KibaOS is a modern, lightweight Linux distribution built on **Arch Linux base (Rolling)** with **Cutefish OS** desktop environment and the **CachyOS kernel**. It is designed to be simple, beautiful, and ready to use out-of-the-box.

### Why "Kiba"

Kiba (牙) means "Fang" in Japanese. The name reflects our goal of creating a sharp, lean, and powerful system that cuts through the bloat of modern computing.

### Who is KibaOS for

KibaOS is designed for:
- **Beginners** who want a beautiful and fast system that works out of the box
- **Power users** who appreciate a pre-configured, modern terminal experience
- **Privacy-conscious users** who want a system without telemetry or tracking
- **Performance seekers** who benefit from a performance-optimized kernel

---

## Technical Questions

### Why Arch Linux Rolling (Testing)

We use **Arch Linux Rolling** to provide users with modern software like Cutefish OS and the latest toolchains, while still benefiting from Arch Linux's legendary stability and massive package repository.

### What is the CachyOS Kernel

It is a performance-optimized Linux kernel that uses the **BORE scheduler**. It is specifically tuned for desktop responsiveness, making the system feel much snappier under load compared to the stock Arch Linux kernel. Additional features include:

- Modern compiler optimizations
- Gaming patches for improved wine/proton performance
- Regular security updates

### How do I update KibaOS

You can update through:

1. **KibaStore** (graphical) - Check for Flatpak updates
2. **Terminal** - Run `update` (alias for `sudo pacman -Syu`)
3. **Automatic** - Background updates for critical security patches

### Can I change the theme

Absolutely! While KibaOS comes pre-configured with the **Dracula** theme, it is a standard Cutefish OS system. You can change the global theme, icons, and colors in **System Settings**.

Popular alternatives:
- **Global Theme:** Adwaita, Breeze, Matcha
- **Icons:** Papirus, Tela, WhiteSur
- **Cursors:** Bibata, Capitaine

---

## Software Questions

### What is KibaStore

**KibaStore** is our native build of **Bazaar**. It is a lightweight graphical store designed specifically for discovering and managing **Flatpaks** from Flathub.

Features:
- Clean, modern GTK4 interface
- Fast and responsive
- Minimal dependencies
- Native build for KibaOS

### Why Ungoogled Chromium

We chose **Ungoogled Chromium** as the default browser because it provides a familiar Chrome-like experience but with all Google tracking and background services removed for better privacy.

Benefits:
- No Google tracking
- No background services calling home
- Regular security updates via OBS repository
- Familiar Chromium interface

### Can I install standard Arch packages

Yes! Since KibaOS is based on Arch Linux, you can install any package from the Arch repositories using:

```bash
sudo pacman -S <package-name>
```

Or use the `install` alias:
```bash
install <package-name>
```

---

## Troubleshooting

### The installer didn't start automatically

In the live session, the installer is pinned to the desktop and the taskbar. If it fails to launch:

1. Check if the Calamares service is running
2. Open a terminal and type `sudo calamares`
3. Check the logs at `/var/log/calamares.log`

### My Wi-Fi isn't working

KibaOS includes the necessary firmware for most modern wireless cards. If your Wi-Fi isn't detected:

1. Check if your hardware switch is enabled
2. Try connecting via Ethernet temporarily
3. Install specific drivers: `sudo pacman -S <driver-package>`
4. Check if your card needs proprietary firmware

### I need proprietary drivers

For NVIDIA, AMD, or other proprietary drivers:

```bash
# For NVIDIA
sudo pacman -S nvidia nvidia-utils

# For AMD
sudo pacman -S xf86-video-amdgpu

# For Broadcom Wi-Fi
sudo pacman -S broadcom-wl-dkms
```

> [!NOTE]
> Proprietary drivers may require additional configuration. Check the Arch Wiki for specific instructions.

---

## Related Reading

- [**Architecture**](./architecture.md)
- [**UX & Design**](./ux-design.md)
- [**WIKI**](../WIKI.md)
- [**Contributing Guide**](../CONTRIBUTING.md)
