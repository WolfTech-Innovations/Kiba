# Cutefish OS Manual Compilation Guide

This guide provides step-by-step instructions for manually compiling the Cutefish OS Desktop Environment on KibaOS (Arch Linux base).

## Prerequisites

Install the necessary build tools and base dependencies:

```bash
sudo pacman -S --needed base-devel cmake extra-cmake-modules ninja git
sudo pacman -S --needed qt5-base qt5-quickcontrols2 qt5-x11extras qt5-tools qt5-svg \
    kwindowsystem polkit-qt5 xorg-server-devel xf86-input-libinput \
    xf86-input-synaptics libxcb libxcursor libxtst libpulse libkscreen libstatgrab
```

## Build Order

To ensure all dependencies are met, follow this specific build order:

1.  **fishui** (GUI Library)
2.  **libcutefish** (Common Library)
3.  **core** (System Backend)
4.  **Desktop Components** (Dock, Launcher, Statusbar, Settings, Wallpapers)
5.  **Applications** (Terminal, FileManager, Calculator, etc.)

---

## Step 1: fishui

```bash
git clone https://github.com/cutefishos/fishui.git
cd fishui
mkdir build && cd build
cmake -DCMAKE_INSTALL_PREFIX=/usr -GNinja ..
ninja
sudo ninja install
cd ../..
```

## Step 2: libcutefish

```bash
git clone https://github.com/cutefishos/libcutefish.git
cd libcutefish
mkdir build && cd build
cmake -DCMAKE_INSTALL_PREFIX=/usr -GNinja ..
ninja
sudo ninja install
cd ../..
```

## Step 3: core

```bash
git clone https://github.com/cutefishos/core.git
cd core
mkdir build && cd build
cmake -DCMAKE_INSTALL_PREFIX=/usr -GNinja ..
ninja
sudo ninja install
cd ../..
```

## Step 4: Desktop Components

Repeat the following process for each repository: `dock`, `launcher`, `statusbar`, `settings`, `wallpapers`, `icons`.

```bash
REPO="dock" # Change to launcher, statusbar, etc.
git clone https://github.com/cutefishos/$REPO.git
cd $REPO
mkdir build && cd build
cmake -DCMAKE_INSTALL_PREFIX=/usr -GNinja ..
ninja
sudo ninja install
cd ../..
```

## Step 5: Applications

Repeat for: `terminal`, `filemanager`, `calculator`, `screenshot`.

```bash
REPO="terminal"
git clone https://github.com/cutefishos/$REPO.git
cd $REPO
mkdir build && cd build
cmake -DCMAKE_INSTALL_PREFIX=/usr -GNinja ..
ninja
sudo ninja install
cd ../..
```

## Starting the Session

After installing all components, you can start Cutefish OS using SDDM or by adding the following to your `.xinitrc`:

```bash
exec cutefish-session
```
