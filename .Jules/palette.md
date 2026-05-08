# Palette's Journal - KibaTV UX Learnings

## 2025-05-15 - Interactive Welcome Tool for Live Environment
**Learning:** The first-run experience is critical for new users in a live environment. A functional welcome tool provides immediate value by surfacing essential actions (install, terminal, app store) without requiring the user to explore the desktop environment blindly. Zenity is a lightweight and effective way to build these menus on Alpine/postmarketOS.
**Action:** Replace empty placeholder welcome scripts with interactive Zenity-based menus that include emojis, clear labels, and backgrounded informational dialogs for a smooth experience.

## 2025-05-15 - System-wide Icon Resolution
**Learning:** To ensure discoverability and cross-desktop compatibility, system-branded icons (like `kiba-logo`) must be installed to `/usr/share/pixmaps/`. This allows `.desktop` entries to resolve `Icon=kiba-logo` without needing absolute paths, ensuring the visual identity is preserved in app launchers and menus.
**Action:** Always install primary branding logos to `/usr/share/pixmaps/` in addition to internal application directories.
