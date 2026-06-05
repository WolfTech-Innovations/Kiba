# Frequently Asked Questions (FAQ)

<p align="center">
  <img src="../branding/kibaos_banner.png" alt="KibaOS Banner" width="100%">
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Status-Helpful-blue?style=for-the-badge" alt="Status: Helpful">
</p>

---

## General Questions

### What is KibaOS

KibaOS is a modern, lightweight Linux distribution built on **Arch Linux base (Rolling)** with **Budgie Desktop** and the **CachyOS kernel**. It is designed to be simple, beautiful, and ready to use out-of-the-box.

### Why "Kiba"

Kiba (牙) means "Fang" in Japanese. The name reflects our goal of creating a sharp, lean, and powerful system that cuts through the bloat of modern computing.

### Who is KibaOS for

KibaOS is designed for beginners who want a beautiful and fast system, as well as power users who appreciate a pre-configured, modern terminal experience and a performance-optimized kernel.

---

## Technical Questions

### Why Arch Linux Rolling (Testing)

We use **Arch Linux Rolling** to provide users with modern software like Budgie Desktop and the latest toolchains, while still benefiting from Arch Linux's legendary stability and massive package repository.

### What is the CachyOS Kernel

It is a performance-optimized Linux kernel that uses the **BORE scheduler**. It is specifically tuned for desktop responsiveness, making the system feel much snappier under load compared to the stock Arch Linux kernel.

### How do I update KibaOS

You can update through **KibaStore** (graphical) or simply by typing **`update`** in the terminal. This is a pre-configured alias that runs `sudo pacman -Syu`.

### Can I change the theme

Absolutely! While KibaOS comes pre-configured with the **Dracula** theme, it is a standard Budgie Desktop system. You can change the global theme, icons, and colors in **Budgie Control Center**.

---

## Software Questions

### What is KibaStore

**KibaStore** is our native build of **Bazaar**. It is a lightweight graphical store designed specifically for discovering and managing **Flatpaks**.

### Why Ungoogled Chromium

We chose **Ungoogled Chromium** as the default browser because it provides a familiar Chrome-like experience but with all Google tracking and background services removed for better privacy.

### Can I install standard `.deb` packages

Yes! Since KibaOS is based on Arch Linux, you can install any compatible `.deb` file using **Nala** (`sudo pacman -S ./file.deb`) or standard `dpkg`.

---

## Troubleshooting

### The installer didn't start automatically

In the live session, the installer is pinned to the desktop and the taskbar. If it fails to launch, open a terminal and type `sudo calamares`.

### My Wi-Fi isn't working

KibaOS includes the `non-free-firmware` repository by default to support most modern wireless cards. If your card isn't detected, you may need to install a specific driver via `pacman`.

---

## Related Reading

- [**Architecture**](./architecture.md)
- [**UX & Design**](./ux-design.md)
- [**WIKI**](../WIKI.md)
