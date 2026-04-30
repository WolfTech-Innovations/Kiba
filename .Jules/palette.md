## 2025-05-14 - [Installer Accessibility and Theme Consistency]

**Learning:** Standardizing the installer slideshow interval to 8 seconds significantly improves readability for diverse users, and a full dark theme in the installer (WindowBackground/Foreground) reduces visual jarring during the transition from boot splash to setup.
**Action:** Always check the default slideshow intervals and theming scope in installer configurations to ensure they meet accessibility standards and maintain visual continuity.

## 2026-04-30 - [Boot Splash Animation and Accessibility]

**Learning:** Implementing a SequentialAnimation or direct property animation for a fade-in effect on the boot splash screen adds a touch of delight. Furthermore, adding explicit `Accessible` properties to static text elements in QML ensures that screen readers can properly interpret system-critical messages during the boot process.
**Action:** When modifying QML-based UI components, always include `Accessible` properties for informative text and use smooth transitions to enhance the perceived quality of the user experience.
