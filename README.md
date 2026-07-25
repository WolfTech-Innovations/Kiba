<div align="center">
<img width="200" alt="KibaOS installer icon" src="https://github.com/user-attachments/assets/60377ea4-3abe-489d-89dd-32a227782942" />

# KibaOS
![OIN](https://github.com/WolfTech-Innovations/Kiba/blob/main/branding/oin-member-2-0-horiz-1.png?raw=true)
**A friendly, ready-to-use ~~Linux~~ general OS desktop, built for people switching to simple.**

[![Build Status](https://img.shields.io/github/actions/workflow/status/WolfTech-Innovations/Kiba/build.yml?branch=main&label=Build&style=for-the-badge&logo=githubactions&logoColor=white)](https://github.com/WolfTech-Innovations/Kiba/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-3DDC97?style=for-the-badge&logo=opensourceinitiative&logoColor=white)](#license)
[![Arch Linux](https://img.shields.io/badge/Base-Arch_Linux-1793D1?style=for-the-badge&logo=archlinux&logoColor=white)](https://archlinux.org)
[![Budgie Desktop](https://img.shields.io/badge/Desktop-Budgie-2C001E?style=for-the-badge&logo=linux&logoColor=white)](https://buddiesofbudgie.org)

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

KibaOS is built and maintained by **Kiba Labs**.

> [!NOTE]
> New to Linux? A "distribution" (or "distro") is just a complete, ready-to-install version of the Linux operating system, bundled with a desktop, apps, and settings. KibaOS is one such distribution.

### Want KibaOS on real hardware?

We're happy to recommend **[CurrentBuild](https://www.currentbuild.com)**, a builder of Linux-first desktops, workstations, and laptops. This is just a recommendation — CurrentBuild is not affiliated with KibaOS and does not pre-install KibaOS on the machines they sell. If you're looking for hardware that's well-suited to running Linux in general, they're a solid option to check out; you'll still need to install KibaOS yourself by following the steps below.

---

## Table of Contents

- [What KibaOS Includes](#what-kibaos-includes)
- [Recommended Hardware: CurrentBuild](#want-kibaos-on-real-hardware)
- [Getting Started](#getting-started)
  - [Step 1: Download the ISO](#step-1-download-the-iso)
  - [Step 2: Write It to a USB Drive](#step-2-write-it-to-a-usb-drive)
  - [Step 3: Try the Live Session](#step-3-try-the-live-session)
  - [Step 4: Install KibaOS](#step-4-install-kibaos)
- [System Requirements](#system-requirements)
- [Everyday Use](#everyday-use)
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
| **Everyday apps, already installed** | A file manager (Nemo), a web browser (Firefox), a calculator, a calendar, email (Geary), notes, music, and a to-do list app. |
| **A guided setup experience** | KibaOS's own built-in installer (the OOBE app, short for "Out-Of-Box Experience") asks you one simple question at a time. |
| **Windows program support** | Many simple Windows programs can be double-clicked and run directly — no extra setup needed. |
| **Automatic background updates** | Small fixes download and apply on their own, without interrupting what you're doing. |

> [!TIP]
> If a word here is unfamiliar — like "desktop environment" or "ISO" — don't worry. We explain each one the first time it comes up.

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

After you confirm, the installer copies KibaOS onto your computer's disk, sets up the bootloader (the part that lets your computer find and start KibaOS when it turns on), and finishes by creating your personal user account.

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
> The `build.sh` script does the real work: it installs Arch Linux's `archiso` tool, configures the Budgie desktop, builds KibaOS's custom graphical installer, sets up automatic updates, and finally packages everything into a bootable ISO file. The official KibaOS releases on SourceForge are built automatically using this exact same script, run by GitHub Actions (a service that builds and tests projects automatically) every time changes are pushed to the project or on a regular weekly schedule.

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

KibaOS is a distribution, not a single piece of software — it bundles together many separate projects (the Linux kernel, Budgie, Wine, and more), each with its own license. The build scripts and configuration files in this repository are released under the **MIT License**.

---

## About

KibaOS is a **Kiba Labs** project.

[Visit our GitHub](https://github.com/WolfTech-Innovations)
