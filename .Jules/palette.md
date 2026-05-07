## 2025-05-15 - [Zenity Newline Rendering in Heredocs]

**Learning:** Zenity dialogs embedded within shell script heredocs (like in `kibatv-build.sh`) render more reliably when using literal newlines instead of escaped sequences like `\n`, which may be interpreted literally depending on the environment.
**Action:** Use literal newlines within the `--text` attribute of Zenity commands when defining them in heredocs to ensure proper multi-line formatting.

## 2025-05-15 - [Discovery Loop Pattern]

**Learning:** For informational items in a selection menu (like "Keyboard Shortcuts"), omitting the `break` command ensures the user remains in the menu after dismissing the info dialog, encouraging further exploration.
**Action:** Only use `break` for primary actions that launch a full application or process (like the installer) in looping welcome tools.

## 2025-05-15 - [Discoverable Shortcuts in Menu Labels]

**Learning:** Incorporating keyboard shortcut hints (e.g., "Terminal (Meta+T)") directly into Zenity menu labels in the `kiba-welcome` tool improves functional discoverability and teaches users efficient interaction methods within the live environment.
**Action:** Include shortcut hints in labels for primary system tools to enhance user onboarding and system proficiency.

## 2025-05-16 - [Search-Friendly Desktop Metadata]

**Learning:** Enhancing `.desktop` files with descriptive `GenericName` (e.g., 'Package Manager') and relevant `Keywords` (e.g., 'software;install') ensures core tools are findable via natural language search launchers even if the formal app name is unfamiliar.
**Action:** Always include `GenericName` and `Keywords` in system-level `.desktop` entries to improve application discoverability and accessibility.

## 2026-05-07 - [Non-Blocking Informational Dialogs]

**Learning:** Backgrounding informational Zenity dialogs (like "Shortcuts" or "Documentation") with `&` in selection loops prevents the menu from being blocked, allowing users to keep the menu open while viewing information.
**Action:** Always background informational popups in looping menus to maintain UI responsiveness and parallel exploration.

## 2026-05-07 - [Icon Consistency: Monitor vs Laptop]

**Learning:** For desktop distributions like KibaTV, using the desktop monitor emoji (🖥️) for the Terminal icon is more contextually appropriate and consistent with system-wide branding than the laptop emoji (💻).
**Action:** Use 🖥️ for terminal-related UI elements in desktop-focused environments.
