# Palette's Journal

## 2025-05-15 - [Accessible Zenity Menus for TV]

**Learning:** Zenity list dialogs on KibaTV require specific configuration for TV usability: 450x500 dimensions, hidden internal tag columns to decouple user-facing labels from selection logic, and backgrounding informational sub-dialogs to prevent the main menu from hanging.
**Action:** Always specify `--width=450 --height=500`, use `--hide-column` for tags, and wrap informational zenity calls in `( ... ) &`.

## 2026-05-10 - [Enhanced Documentation Navigability & Accessibility]

**Learning:** For documentation-heavy repositories, the README is the primary UI. Long READMEs (>100 lines) require a "Table of Contents" for better navigability (and to pass CI audits), and hero images must have descriptive alt text to ensure an accessible first impression for screen-reader users.
**Action:** Always include a Table of Contents for READMEs exceeding 100 lines and audit all documentation images for descriptive `alt` attributes instead of generic placeholders like "image".

## 2027-02-25 - [Standardized Shortcuts & Visual Onboarding]

**Learning:** Micro-UX delight in a custom OS is best achieved by aligning system-level defaults (KDE shortcuts) with user-facing onboarding tools. Using `Meta` (Super) for primary navigation (Terminal, File Manager, Search) follows modern user expectations. Zenity menus become significantly more intuitive when paired with standard icon sets (Kora) and actionable button labels like "Launch".
**Action:** Always synchronize `kglobalshortcutsrc` with the advertised shortcuts in `kiba-welcome`, and use `--image-column` in Zenity to provide visual anchors for menu actions.
