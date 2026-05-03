# Frequently Asked Questions (FAQ)

<p align="center">
  <img src="../branding/kibatv_banner.png" alt="KibaTV Banner" width="100%">
</p>

<p align="center">
  <img src="`https://img.shields.io/badge/Status-Helpful-blue?style=for-the-badge`" alt="Helpful">
</p>

---

\n## General Questions

#\n## What is KibaTV?

KibaTV is a modern, lightweight Linux distribution built on **Debian 13 (Trixie)** with **Plasma Bigscreen** and the **CachyOS kernel**. It is designed to be simple, beautiful, and ready to use out-of-the-box.

#\n## Why "Kiba"?

Kiba (牙) means "Fang" in Japanese. The name reflects our goal of creating a sharp, lean, and powerful system that cuts through the bloat of modern computing.

#\n## Who is KibaTV for?

KibaTV is designed for beginners who want a beautiful and fast system, as well as power users who appreciate a pre-configured, modern terminal experience and a performance-optimized kernel.

---

\n## Technical Questions

#\n## Why Debian Trixie (Testing)?

We use **Debian Trixie** to provide users with modern software like Plasma Bigscreen and the latest toolchains, while still benefiting from Debian's legendary stability and massive package repository.

#\n## What is the CachyOS Kernel?

It is a performance-optimized Linux kernel that uses the **BORE scheduler**. It is specifically tuned for desktop responsiveness, making the system feel much snappier under load compared to the stock Debian kernel.

#\n## How do I update KibaTV?

You can update through **KibaStore** (graphical) or simply by typing **`update`** in the terminal. This is a pre-configured alias that runs `sudo nala update && sudo nala upgrade`.

#\n## Can I change the theme?

Absolutely! While KibaTV comes pre-configured with the **Dracula** theme, it is a standard Plasma Bigscreen system. You can change the global theme, icons, and colors in **System Settings**.

---

\n## Software Questions

#\n## What is KibaStore?

**KibaStore** is our native build of **Bazaar**. It is a lightweight graphical store designed specifically for discovering and managing **Flatpaks**.

#\n## Why Ungoogled Chromium?

We chose **Ungoogled Chromium** as the default browser because it provides a familiar Chrome-like experience but with all Google tracking and background services removed for better privacy.

#\n## Can I install standard `.deb` packages?

Yes! Since KibaTV is based on Debian, you can install any compatible `.deb` file using **Nala** (`sudo nala install ./file.deb`) or standard `dpkg`.

---

\n## Troubleshooting

#\n## The installer didn't start automatically

In the live session, the installer is pinned to the desktop and the taskbar. If it fails to launch, open a terminal and type `sudo calamares`.

#\n## My Wi-Fi isn't working

KibaTV includes the `non-free-firmware` repository by default to support most modern wireless cards. If your card isn't detected, you may need to install a specific driver via `nala`.

---

\n## Related Reading

- [**Architecture**](./architecture.md)
- [**UX & Design**](./ux-design.md)
- [**WIKI**](../WIKI.md)
