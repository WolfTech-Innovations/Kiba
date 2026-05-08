## 2025-05-15 - [Discovery Loop Pattern in Zenity Menus]
**Learning:** In looping Zenity selection menus (like `kiba-welcome`), primary terminal actions (e.g., system installation) must include a `break` to exit the tool, while informational dialogs (shortcuts, documentation) should be backgrounded with `&` to ensure the menu loop remains responsive and does not block on the dialog closure.
**Action:** Always background informational Zenity actions and ensure a clear exit path for primary system tasks.

## 2025-05-15 - [Standardizing Zenity UI Dimensions]
**Learning:** To ensure visual consistency and adequate space for list descriptions across different resolutions in KibaTV, a default window size of `--width=450 --height=500` is preferred for Zenity list menus.
**Action:** Use standard 450x500 dimensions for main Zenity application menus in this repository.
