# Budgie Desktop Manual Compilation Guide

This guide provides step-by-step instructions for manually compiling the Budgie Desktop Environment on KibaOS (Arch Linux base).

## Prerequisites

Install the necessary build tools and base dependencies:

```bash
sudo pacman -S --needed base-devel cmake meson ninja git
sudo pacman -S --needed vala gobject-introspection gtk3 libgee libpeas \
    gsettings-desktop-schemas upower accountsservice gnome-menus \
    gnome-bluetooth-3.0 libibus libnotify pulseaudio
```

## Build Order

To ensure all dependencies are met, follow this specific build order:

1.  **budgie-desktop** (Core Environment)
2.  **budgie-control-center** (Settings)
3.  **budgie-desktop-view** (Desktop Icons)
4.  **budgie-screensaver** (Lock Screen)

---

## Step 1: budgie-desktop

```bash
git clone https://github.com/BuddiesOfBudgie/budgie-desktop.git
cd budgie-desktop
meson build --prefix=/usr
ninja -C build
sudo ninja -C build install
cd ..
```

## Step 2: budgie-control-center

```bash
git clone https://github.com/BuddiesOfBudgie/budgie-control-center.git
cd budgie-control-center
meson build --prefix=/usr
ninja -C build
sudo ninja -C build install
cd ..
```

## Starting the Session

After installing all components, you can start Budgie Desktop using SDDM or by adding the following to your `.xinitrc`:

```bash
exec budgie-desktop
```
