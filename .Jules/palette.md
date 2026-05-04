## 2025-05-15 - [Zenity Newline Rendering in Heredocs]

**Learning:** Zenity dialogs embedded within shell script heredocs (like in `kibatv-build.sh`) render more reliably when using literal newlines instead of escaped sequences like `\n`, which may be interpreted literally depending on the environment.
**Action:** Use literal newlines within the `--text` attribute of Zenity commands when defining them in heredocs to ensure proper multi-line formatting.

## 2025-05-15 - [Discovery Loop Pattern]

**Learning:** For informational items in a selection menu (like "Keyboard Shortcuts"), omitting the `break` command ensures the user remains in the menu after dismissing the info dialog, encouraging further exploration.
**Action:** Only use `break` for primary actions that launch a full application or process (like the installer) in looping welcome tools.

## 2025-05-15 - [Discoverable Shortcuts in Menu Labels]
**Learning:** Incorporating keyboard shortcut hints (e.g., "Terminal (Meta+T)") directly into Zenity menu labels in the `kiba-welcome` tool improves functional discoverability and teaches users efficient interaction methods within the live environment.
**Action:** Include shortcut hints in labels for primary system tools to enhance user onboarding and system proficiency.

## 2025-05-15 - [Toolkit Compatibility in TV Interfaces]
**Learning:** Using GTK-based tools like Zenity for welcome dialogs in TV-focused environments (like Plasma Bigscreen) can lead to poor accessibility as they often lack proper focus handling and D-pad/remote navigation support compared to native Qt/QML components.
**Action:** Prioritize native toolkit components (Qt/Kirigami for KDE) for interactive system tools in TV-centric distros to ensure full input device compatibility.
