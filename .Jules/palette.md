# Palette's Journal

## 2025-05-15 - [Accessible Zenity Menus for TV]

**Learning:** Zenity list dialogs on KibaTV require specific configuration for TV usability: 450x500 dimensions, hidden internal tag columns to decouple user-facing labels from selection logic, and backgrounding informational sub-dialogs to prevent the main menu from hanging.
**Action:** Always specify `--width=450 --height=500`, use `--hide-column` for tags, and wrap informational zenity calls in `( ... ) &`.

## 2026-05-10 - [Enhanced Documentation Navigability & Accessibility]

**Learning:** For documentation-heavy repositories, the README is the primary UI. Long READMEs (>100 lines) require a "Table of Contents" for better navigability (and to pass CI audits), and hero images must have descriptive alt text to ensure an accessible first impression for screen-reader users.
**Action:** Always include a Table of Contents for READMEs exceeding 100 lines and audit all documentation images for descriptive `alt` attributes instead of generic placeholders like "image".

## 2026-05-11 - [Standardized Zenity Menus & Global Shortcuts Sync]

**Learning:** UX consistency in KibaOS relies on synchronizing advertised features (like keyboard shortcuts) in onboarding tools with the actual system configuration. Zenity list menus are most effective when utilizing `--image-column` for visual recognition and standardized 450x500 dimensions for TV/monitor accessibility.
**Action:** Always use `--image-column=1 --hide-column=1 --print-column=2` for Zenity lists with icons, and ensure all advertised Meta shortcuts in the Welcome app are explicitly defined in `/etc/skel/.config/kglobalshortcutsrc`.
