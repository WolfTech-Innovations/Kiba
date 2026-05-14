# Palette's Journal

## 2025-05-15 - [Accessible Zenity Menus for TV]

**Learning:** Zenity list dialogs on KibaTV require specific configuration for TV usability: 450x500 dimensions, hidden internal tag columns to decouple user-facing labels from selection logic, and backgrounding informational sub-dialogs to prevent the main menu from hanging.
**Action:** Always specify `--width=450 --height=500`, use `--hide-column` for tags, and wrap informational zenity calls in `( ... ) &`.

## 2026-05-10 - [Enhanced Documentation Navigability & Accessibility]

**Learning:** For documentation-heavy repositories, the README is the primary UI. Long READMEs (>100 lines) require a "Table of Contents" for better navigability (and to pass CI audits), and hero images must have descriptive alt text to ensure an accessible first impression for screen-reader users.
**Action:** Always include a Table of Contents for READMEs exceeding 100 lines and audit all documentation images for descriptive `alt` attributes instead of generic placeholders like "image".

## 2025-05-20 - [Enhanced Application Discoverability and Accessibility]

**Learning:** In Linux distributions like KibaOS, application discoverability and accessibility are significantly improved by including `GenericName` (e.g., 'System Installer') and appropriate `Categories` (e.g., 'System;Utility;') in `.desktop` files. This ensures that users can find tools via keyword search even if they don't know the specific application name.
**Action:** Always include `GenericName` and `Categories` in `.desktop` entries for all user-facing applications to ensure proper context in application menus and accessibility tools.
