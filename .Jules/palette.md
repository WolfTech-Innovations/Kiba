# Palette's Journal

## 2025-05-15 - [Accessible Zenity Menus for TV]

**Learning:** Zenity list dialogs on KibaTV require specific configuration for TV usability: 450x500 dimensions, hidden internal tag columns to decouple user-facing labels from selection logic, and backgrounding informational sub-dialogs to prevent the main menu from hanging.
**Action:** Always specify `--width=450 --height=500`, use `--hide-column` for tags, and wrap informational zenity calls in `( ... ) &`.

## 2026-05-10 - [Enhanced Documentation Navigability & Accessibility]

**Learning:** For documentation-heavy repositories, the README is the primary UI. Long READMEs (>100 lines) require a "Table of Contents" for better navigability (and to pass CI audits), and hero images must have descriptive alt text to ensure an accessible first impression for screen-reader users.
**Action:** Always include a Table of Contents for READMEs exceeding 100 lines and audit all documentation images for descriptive `alt` attributes instead of generic placeholders like "image".

## 2025-05-20 - [Synchronized Desktop Shortcuts]

**Learning:** Synchronizing KDE global shortcuts with advertised shortcuts in onboarding tools (like `kiba-welcome`) is crucial for a cohesive "it just works" experience. In Plasma 6, these are configured via `kglobalshortcutsrc` in `~/.config/`, which decouples them from application-specific configs in some cases.
**Action:** When adding or changing advertised shortcuts in onboarding scripts, ensure the corresponding `kglobalshortcutsrc` entries are also updated in the system skeleton (`/etc/skel`).
