# Palette's Journal

## 2025-05-15 - [Accessible Zenity Menus for TV]

**Learning:** Zenity list dialogs on KibaTV require specific configuration for TV usability: 450x500 dimensions, hidden internal tag columns to decouple user-facing labels from selection logic, and backgrounding informational sub-dialogs to prevent the main menu from hanging.
**Action:** Always specify `--width=450 --height=500`, use `--hide-column` for tags, and wrap informational zenity calls in `( ... ) &`.

## 2026-05-10 - [Enhanced Documentation Navigability & Accessibility]

**Learning:** For documentation-heavy repositories, the README is the primary UI. Long READMEs (>100 lines) require a "Table of Contents" for better navigability (and to pass CI audits), and hero images must have descriptive alt text to ensure an accessible first impression for screen-reader users.
**Action:** Always include a Table of Contents for READMEs exceeding 100 lines and audit all documentation images for descriptive `alt` attributes instead of generic placeholders like "image".

## 2025-05-20 - [Visual Hierarchy with Emojis in System Menus]

**Learning:** In minimal desktop environments like KibaOS, system-onboarding menus (e.g., Zenity lists) benefit significantly from emoji-prefixed labels. They provide immediate visual anchors for scanning, satisfy repository-specific UI audits, and add a layer of "delight" that makes the interface feel more modern and approachable.
**Action:** Use emoji prefixes (🚀, 🌐, 🛍️, ⌨️, ✨) for top-level menu actions in Zenity dialogs to improve scan-ability and visual hierarchy.
