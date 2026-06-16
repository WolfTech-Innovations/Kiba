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

## 2025-06-15 - Dracula Theme for Welcome Screen
**Learning:** Transitioning the Welcome screen to the Dracula palette improves visual consistency with the rest of the OS. Using box-shadow for focus indicators provides a smoother, more accessible experience than standard outlines.
**Action:** Use Dracula design tokens (#282a36, #44475a, etc.) for all first-party UI components.

## 2025-06-16 - Tactile Feedback and Accessibility in Welcome Screen
**Learning:** For web-based system components like the Welcome screen, adding `tabindex="0"` to informational cards allows keyboard users to "walk through" features. Combining this with a "snappy but smooth" tactile effect (scale-down on `:active` with `transition: transform 0s`) makes the interface feel significantly more responsive and polished.
**Action:** Always ensure informational elements are keyboard-focusable if they have hover/active styles, and use the 0s active transition trick for immediate tactile feedback.
