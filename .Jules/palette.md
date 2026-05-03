## 2025-05-15 - [Zenity Newline Rendering in Heredocs]
**Learning:** Zenity dialogs embedded within shell script heredocs (like in `kibatv-build.sh`) render more reliably when using literal newlines instead of escaped sequences like `\n`, which may be interpreted literally depending on the environment.
**Action:** Use literal newlines within the `--text` attribute of Zenity commands when defining them in heredocs to ensure proper multi-line formatting.

## 2025-05-15 - [Discovery Loop Pattern]
**Learning:** For informational items in a selection menu (like "Keyboard Shortcuts"), omitting the `break` command ensures the user remains in the menu after dismissing the info dialog, encouraging further exploration.
**Action:** Only use `break` for primary actions that launch a full application or process (like the installer) in looping welcome tools.
