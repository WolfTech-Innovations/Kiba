<p align="center">
  <img src="https://github.com/WolfTech-Innovations/Kiba/blob/76dfc8fa4c96461c42a14f57b46689fec858b735/branding/file_00000000ba3081f7bfd242de31c8979b.png?raw=true" width="250" alt="Kiba Badge">
</p>

> [!IMPORTANT]
>
> KibaOS only supports UEFI-based systems. Virtual machine installation is currently unsupported because KibaOS is designed to run on physical hardware.

<div align="center">

# KibaOS
![OIN](https://github.com/WolfTech-Innovations/Kiba/blob/main/branding/oin-member-2-0-horiz-1.png?raw=true)
**A friendly, ready-to-use ~~Linux~~ general OS desktop, built for people switching to simple.**

[![Build Status](https://img.shields.io/github/actions/workflow/status/WolfTech-Innovations/Kiba/build.yml?branch=main&label=Build&style=for-the-badge&logo=githubactions&logoColor=white)](https://github.com/WolfTech-Innovations/Kiba/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-3DDC97?style=for-the-badge&logo=opensourceinitiative&logoColor=white)](#license)
[![Arch Linux](https://img.shields.io/badge/Base-Arch_Linux-1793D1?style=for-the-badge&logo=archlinux&logoColor=white)](https://archlinux.org)
[![Budgie Desktop](https://img.shields.io/badge/Desktop-Budgie-2C001E?style=for-the-badge&logo=linux&logoColor=white)](https://buddiesofbudgie.org)

<sub>
<img src="https://img.shields.io/badge/Icons-Numix_Circle-6b5ce7?style=flat-square" alt="Numix Circle Icons">
<img src="https://img.shields.io/badge/Boot_Splash-Numix_Plymouth-6b5ce7?style=flat-square" alt="Numix Plymouth">
<img src="https://img.shields.io/badge/Package_Manager-kibapkg-00b0d8?style=flat-square" alt="kibapkg">
<img src="https://img.shields.io/badge/Installer-archinstall_%2B_squashfs-00b0d8?style=flat-square" alt="sgdisk + squashfs installer">
</sub>

<br>

<sub>
<img src="https://img.shields.io/github/repo-size/WolfTech-Innovations/Kiba?style=flat-square&color=blue" alt="Repo Size">
<img src="https://img.shields.io/github/stars/WolfTech-Innovations/Kiba?style=flat-square&color=yellow" alt="Stars">
<img src="https://img.shields.io/github/forks/WolfTech-Innovations/Kiba?style=flat-square&color=lightgrey" alt="Forks">
<img src="https://img.shields.io/github/last-commit/WolfTech-Innovations/Kiba?style=flat-square&color=green" alt="Last Commit">
<img src="https://img.shields.io/sourceforge/dt/kibaos?style=flat-square&color=orange" alt="SourceForge Downloads">
</sub>

<br><br>

[![Download KibaOS](https://a.fsdn.com/con/app/sf-download-button)](https://sourceforge.net/projects/kibaos/files/latest/download)

</div>

<img width="1000" alt="Desktop screenshot" src="https://raw.githubusercontent.com/WolfTech-Innovations/Kiba/refs/heads/main/branding/file_000000008ac881f5beb3622a8ec72855.png?raw=true" />

---

KibaOS is built on **Arch Linux** (the "Rolling" release, meaning it's always kept up to date rather than released in big yearly versions). It uses the **Budgie** desktop environment and is designed so that anyone switching to simple can sit down and use it immediately, without having to configure anything first.

Every piece of it — the installer, the app icons, the terminal, even the boot screen — is chosen or built with one rule in mind: **nothing should look or feel like it's still showing you the plumbing.**

KibaOS is built and maintained by **Kiba Labs**.

> [!NOTE]
> New to Linux? A "distribution" (or "distro") is just a complete, ready-to-install version of the Linux operating system, bundled with a desktop, apps, and settings. KibaOS is one such distribution.

### Want KibaOS on real hardware?

We're happy to tell you about our partners, **[ArkPC](https://arkpc.com.au)**, a builder of Linux-first desktops, workstations, and laptops. ArkPC is affiliated with KibaOS and plan to/may soon pre-install KibaOS on the machines they sell. If you're looking for hardware that's well-suited to running Linux in general, if you still want to install KibaOS yourself by following the steps below.

---

## Table of Contents

- [What KibaOS Includes](#what-kibaos-includes)
- [Design & Theming](#design--theming)
- [Recommended Hardware: ArkPC](#want-kibaos-on-real-hardware)
- [Getting Started](#getting-started)
  - [Step 1: Download the ISO](#step-1-download-the-iso)
  - [Step 2: Write It to a USB Drive](#step-2-write-it-to-a-usb-drive)
  - [Step 3: Try the Live Session](#step-3-try-the-live-session)
  - [Step 4: Install KibaOS](#step-4-install-kibaos)
- [System Requirements](#system-requirements)
- [Everyday Use](#everyday-use)
  - [Managing Apps with kibapkg](#managing-apps-with-kibapkg)
  - [Running Windows Programs](#running-windows-programs)
  - [Automatic Updates](#automatic-updates)
- [Building KibaOS Yourself](#building-kibaos-yourself)
- [Project Structure](#project-structure)
- [Contributing](#contributing)
- [License](#license)
- [About](#about)

---

## What KibaOS Includes

KibaOS aims to work well right out of the box, so there's no need to spend an afternoon installing extra software just to get a usable computer.

| Feature | What it means for you |
| --- | --- |
| **A solid foundation** | Built on Arch Linux, a well-respected base known for staying current and supporting the newest hardware. |
| **A clean, familiar desktop** | The Budgie desktop environment provides a taskbar, a centered dock, and a clock applet, laid out so everything is easy to find. |
| **Everyday apps, already installed** | A file manager (Nemo), a web browser, a calculator, a calendar, email (Geary), notes, music, and a to-do list app — all picked or relabeled so they read as plain, simple tools instead of a pile of separately-branded software. |
| **A simple terminal, when you need it** | The built-in terminal is deliberately minimal — one window, no tabs, no menus — for the rare moments you need it, without it ever feeling like the "real" way to use the computer. |
| **`kiba`, a friendly app manager** | Install, remove, and update software with plain-language commands instead of memorizing package-manager flags. See [Managing Apps with kibapkg](#managing-apps-with-kibapkg). |
| **A guided setup experience** | KibaOS's own built-in installer (the OOBE app, short for "Out-Of-Box Experience") asks you one simple question at a time. |
| **A calm, uncluttered live session** | The trial/install session never dims, locks, or falls asleep on you mid-setup, and stays free of raw system dialogs, developer tools, and other things you'd never need to see. |
| **Windows program support** | Many simple Windows programs can be double-clicked and run directly — no extra setup needed. |
| **Automatic background updates** | Small fixes download and apply on their own, without interrupting what you're doing. |

> [!TIP]
> If a word here is unfamiliar — like "desktop environment" or "ISO" — don't worry. We explain each one the first time it comes up.

---

## Design & Theming

KibaOS's look isn't an afterthought bolted onto stock Arch + Budgie — every visual layer is deliberately chosen so the system feels like one coherent product, not a collection of default Linux app icons and system dialogs.

| Layer | What's used | Why |
| --- | --- | --- |
| **Boot splash** | [Numix Plymouth](https://github.com/numixproject/numix-plymouth-theme) | Replaces the default distro boot screen with a clean, animated splash — the first thing you see sets the tone. |
| **App icons** | [Numix Circle](https://github.com/numixproject/numix-icon-theme-circle) | A consistent, modern, single-style icon set across every app, instead of each app showing its own designer's take on an icon. |
| **Window & UI theme** | Adwaita-dark, with a KibaOS rounded-rectangle panel override | A calm dark base that avoids the visual noise of a stock desktop while staying easy on the eyes. |
| **Motion** | KibaOS's own "Organic Motion Language" | A shared set of named, natural-feeling animation curves used consistently across the desktop and installer, so things like window opens and panel transitions feel like part of the same system rather than a grab-bag of default GTK animations. |
| **App branding** | De-branded where it matters | A handful of apps that would otherwise show a separate company's name or logo (the browser, the software store, the settings app) are relabeled to plain, generic names — "Browser," "App Store," "Settings" — so the desktop reads as one product. |

---

## Getting Started

### Step 1: Download the ISO

An **ISO file** is a single file that contains an entire disc's (or USB drive's) worth of data. It's how most Linux operating systems are distributed. You'll write this ISO onto a USB drive, then boot your computer from that USB drive to try or install KibaOS.

You can download the latest KibaOS ISO file here:
[Download KibaOS on SourceForge](https://sourceforge.net/projects/kibaos/files/)

> [!IMPORTANT]
> Each release comes with a SHA256 checksum, which is a short code used to verify your download wasn't corrupted or tampered with. It's good practice to check it, though not strictly required to get started.

### Step 2: Write It to a USB Drive

You'll need a USB flash drive (8 GB or larger is plenty) that you don't mind erasing — everything currently on it will be deleted.

Free graphical tools like [Balena Etcher](https://etcher.balena.io) or [Ventoy](https://www.ventoy.net) make this easy — you just select the ISO file and the USB drive, and click "Flash."

### Step 3: Try the Live Session

A **live session** lets you try KibaOS directly from the USB drive, without installing anything or changing your computer in any way. This is a great way to check that your hardware (Wi-Fi, graphics, etc.) works well with KibaOS before committing to install it.

1. Plug in the USB drive.
2. Restart your computer and open the boot menu (usually by pressing a key like `F12`, `F2`, `Esc`, or `Del` right after powering on — it varies by computer).
3. Choose the USB drive from the list.
4. KibaOS will boot and log you in automatically.

> [!NOTE]
> Anything you do in the live session — files you create, settings you change — is **not saved** once you restart. It's meant only for trying things out. To make KibaOS permanent, continue to Step 4.

#### Default Login (Live Session Only)

These accounts only exist while you're trying KibaOS from the USB drive — they are replaced by your own account when you install:

| Account | Password |
| ------- | -------- |
| `liveuser` | `live` |

### Step 4: Install KibaOS

From the live desktop, open the **"Install KibaOS"** icon. This launches KibaOS's own built-in installer, which asks you a few simple questions one at a time:

1. Your preferred language and region
2. Your keyboard layout
3. Which disk to install onto
4. Your username and password
5. A short confirmation screen before anything is written to disk

After you confirm, the installer prepares your disk, copies KibaOS onto it, sets up the bootloader (the part that lets your computer find and start KibaOS when it turns on), and finishes by creating your personal user account. Behind the scenes it uses the well-tested, community-maintained [archinstall](https://github.com/archlinux/archinstall) project to handle disk partitioning, then copies over the exact same system image you tried in the live session — so what you installed is what you tested.

> [!CAUTION]
> Installing KibaOS will erase the disk you choose in step 3 above. Make sure you've backed up anything important, and double check you're installing to the correct disk if your computer has more than one.

Once installation finishes, restart your computer, remove the USB drive, and KibaOS will start normally from your computer's own disk.

---

## System Requirements

| Component | Minimum                | Recommended         |
| --------- | ---------------------- | -------------------- |
| **CPU**   | 64-bit (x86_64)        | Dual-core or better |
| **RAM**   | 2 GB                   | 4 GB                 |
| **Disk**  | 20 GB free space       | An SSD is much faster than a traditional hard drive |
| **Graphics** | A GPU supporting OpenGL 2.0 | A dedicated graphics card |

---

## Everyday Use

### Managing Apps with kibapkg

KibaOS includes its own app manager, **kibapkg**, used from the terminal as the short command `kiba`. It talks directly to the same underlying package system Arch itself uses, but skips the jargon — no flags to memorize, no wall of resolver output.

```bash
kiba install <app name>   # install an app
kiba remove  <app name>   # remove an app
kiba update                # update everything
kiba search  <term>        # search for an app
kiba list                  # see what's installed
kiba info    <app name>    # details about an app
```

> [!TIP]
> Most people won't need `kiba` day-to-day — the App Store handles installing and updating apps visually. `kiba` is there for when you'd rather type a command.

### Running Windows Programs

KibaOS can run many Windows programs right out of the box. Just double-click the program's file, and it'll open and run — no extra setup needed.

> [!TIP]
> Not every Windows program will work perfectly — this depends on the program itself, not on KibaOS. Simpler desktop applications tend to work best.

### Automatic Updates

KibaOS quietly checks for small, official patches in the background and applies them on their own, without interrupting your work. There's generally nothing you need to do — updates just happen.

---

## Building KibaOS Yourself

If you'd like to build your own copy of the KibaOS ISO from source instead of downloading the prebuilt one, you'll need:

- [Docker](https://www.docker.com) installed
- A Linux computer with at least 15 GB of free disk space

```bash
git clone https://github.com/WolfTech-Innovations/Kiba
cd Kiba
docker run --rm --privileged \
  -v "$PWD:/w" \
  -e RUN_NUM=local \
  archlinux:latest \
  /w/build.sh
```

> [!NOTE]
> The `build.sh` script does the real work: it installs Arch Linux's `archiso` tool, configures the Budgie desktop, applies the Numix boot splash and icon theme, builds KibaOS's custom graphical installer and `kibapkg`, sets up automatic updates, and finally packages everything into a bootable ISO file. The official KibaOS releases on SourceForge are built automatically using this exact same script, run by GitHub Actions (a service that builds and tests projects automatically) every time changes are pushed to the project or on a regular weekly schedule.

---

## Project Structure

```text
Kiba/
├── .github/
│   └── workflows/
│       └── kiba.yml           # Tells GitHub Actions when and how to build KibaOS
├── branding/
│   └── kibaos_banner.png      # KibaOS logo and brand images
├── build.sh                   # The full build script — the heart of the project
└── README.md                  # This file
```

---

## Contributing

Issues and pull requests are welcome at the [WolfTech-Innovations/Kiba](https://github.com/WolfTech-Innovations/Kiba) repository. If you're planning a larger change, please open an issue first so we can talk it through — thanks!

---

## License

KibaOS is a distribution, not a single piece of software — it bundles together many separate projects (the Linux kernel, Budgie, Wine, Numix, and more), each with its own license. The build scripts and configuration files in this repository are released under the **MIT License**.

---

## About

KibaOS is a **Kiba Labs** project.

[Visit our GitHub](https://github.com/WolfTech-Innovations)
