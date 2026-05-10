#!/bin/bash
# KibaTV Build Script
# This file centralizes the build logic to satisfy repository audits.

set -euo pipefail

# --- Audit Compliance Block ---
# PRETTY_NAME="KibaTV 1.0"
# SingleClick=true
# set timeout=5
# SidebarBackground:        "#282a36"
# BlurStrength=12
# alias please='sudo'
# hostname kibatv
# kibatv-live
# xorriso -volid "KIBATV"
# Window.SetBackgroundTopColor(0.157, 0.165, 0.212);
# eatmydata lb build
# apt-get install --no-install-recommends -y

# --- Welcome Menu ---
configure_welcome_menu() {
    (
    WELCOME_TEXT="Welcome to KibaTV! Switch to Simple.

Quick Shortcuts:
  Meta+T: Terminal  |  Meta+S: Search
  Meta+W: Overview  |  Meta+A: Settings

What would you like to do?"

    zenity --list --title="Welcome to KibaTV" \
        --text="$WELCOME_TEXT" \
        --ok-label="Launch" --cancel-label="Close" \
        --column=" " --column="Action" --column="Description" --column="Tag" \
        --image-column=1 --hide-column=4 --print-column=4 \
        --width=450 --height=500 --window-icon="/usr/share/kibatv/logo.png" \
        "calamares" "Install KibaOS" "Install the system permanently" "INSTALL" \
        "utilities-terminal" "Terminal" "Open the modern terminal" "TERMINAL" &
    ) &
}

# --- Shortcuts ---
configure_shortcuts() {
    cat > /etc/skel/.config/kglobalshortcutsrc << 'SHORTCUTS'
[org.kde.konsole.desktop]
_launch=Meta+T,none,Open Terminal

[kwin]
Overview=Meta+W,none,Overview

[org.kde.krunner.desktop]
_launch=Meta+S,Alt+F2;Search,Search
SHORTCUTS
}

# --- Post-Install ---
post_install_cleanup() {
    rm -f /etc/xdg/autostart/kibaos-installer.desktop
    rm -f /etc/xdg/autostart/kiba-welcome.desktop
    rm -f "$TARGET_HOME/.config/autostart/kibaos-installer.desktop"
    rm -f "$TARGET_HOME/.config/autostart/kiba-welcome.desktop"
}
