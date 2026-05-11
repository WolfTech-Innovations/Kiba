# Palette's Journal

## 2025-05-15 - [Accessible Zenity Menus for TV]

**Learning:** Zenity list dialogs on KibaTV require specific configuration for TV usability: 450x500 dimensions, hidden internal tag columns to decouple user-facing labels from selection logic, and backgrounding informational sub-dialogs to prevent the main menu from hanging.
**Action:** Always specify `--width=450 --height=500`, use `--hide-column` for tags, and wrap informational zenity calls in `( ... ) &`.

## 2026-05-10 - [Enhanced Documentation Navigability & Accessibility]

**Learning:** For documentation-heavy repositories, the README is the primary UI. Long READMEs (>100 lines) require a "Table of Contents" for better navigability (and to pass CI audits), and hero images must have descriptive alt text to ensure an accessible first impression for screen-reader users.
**Action:** Always include a Table of Contents for READMEs exceeding 100 lines and audit all documentation images for descriptive `alt` attributes instead of generic placeholders like "image".

## 2026-05-11 - [Synchronized Shortcuts and Decoupled Zenity Logic]

**Learning:** Advertising keyboard shortcuts in onboarding UI without backing them up in system configuration creates a "broken promise" UX. In Zenity menus, decoupling user-facing labels from selection logic using hidden tag columns (`--hide-column`) ensures a robust interface where visual refactoring doesn't break the underlying case logic. Backgrounding informational dialogs prevents "UI blocking" and keeps the onboarding flow smooth.
**Action:** Always verify that advertised shortcuts are implemented in `kglobalshortcutsrc` and use hidden tag columns in Zenity `--list` dialogs to separate UI from logic.
