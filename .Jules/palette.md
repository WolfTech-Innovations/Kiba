# Palette's Journal

## 2025-05-15 - [Accessible Zenity Menus for TV]

**Learning:** Zenity list dialogs on KibaTV require specific configuration for TV usability: 450x500 dimensions, hidden internal tag columns to decouple user-facing labels from selection logic, and backgrounding informational sub-dialogs to prevent the main menu from hanging.
**Action:** Always specify `--width=450 --height=500`, use `--hide-column` for tags, and wrap informational zenity calls in `( ... ) &`.

## 2026-05-10 - [Enhanced Documentation Navigability & Accessibility]

**Learning:** For documentation-heavy repositories, the README is the primary UI. Long READMEs (>100 lines) require a "Table of Contents" for better navigability (and to pass CI audits), and hero images must have descriptive alt text to ensure an accessible first impression for screen-reader users.
**Action:** Always include a Table of Contents for READMEs exceeding 100 lines and audit all documentation images for descriptive `alt` attributes instead of generic placeholders like "image".

## 2025-05-20 - [Visual Scannability with Emojis in Zenity Lists]

**Learning:** In list-heavy Zenity dialogs (like keyboard shortcut help), prepending descriptive emojis to action labels significantly improves visual anchor points and scannability for users. This reduces the cognitive load required to find specific information compared to plain text lists.
**Action:** Always prepend appropriate, high-contrast emojis to action labels in multi-column Zenity lists.

## 2025-05-25 - [Cohesive Tool Integration Pattern]
**Learning:** Integrating new utilities into KibaOS requires a multi-layered approach to ensure discoverability and accessibility: adding the package to the build list, configuring a standard global shortcut (e.g., Print for screenshots), and advertising the feature via the `kiba-welcome` launcher and the shortcuts help dialog. This "Full-Stack UX" approach ensures users can find and use the feature regardless of their preferred workflow (menu-driven vs. keyboard-driven).
**Action:** When adding new desktop utilities, always update the package list, `kglobalshortcutsrc`, `kiba-welcome` actions, and the `kiba-welcome` shortcuts help list simultaneously.

## 2024-11-20 - [Accessibility Integrity in Hero Images]

**Learning:** Hero images in README files are often the first point of contact for users. Using generic alt text like "image" is an accessibility failure that creates a poor first impression. Descriptive alt text should accurately reflect the actual state of the UI (e.g., LXDE/Openbox) rather than remaining stagnant when the architecture shifts.
**Action:** Always audit hero images in primary documentation for descriptive, accurate `alt` attributes that align with the current system architecture.

## 2024-05-21 - [Accessible Color Contrast for Primary Actions]

**Learning:** The KibaOS primary accent color (#0099cc) fails WCAG AA contrast against white text (2.9:1). Using a darker variant (#0070a0) achieves a 5:1 ratio, meeting accessibility standards for normal text while maintaining the brand's blue identity. Pairing this with a `:focus-visible` outline in the original lighter accent ensures both high contrast for readability and high visibility for keyboard navigation.
**Action:** Use #0070a0 for primary action backgrounds with white text, and use #0099cc for focus outlines or non-text decorative elements.
