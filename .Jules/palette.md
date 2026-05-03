## 2025-05-15 - [UX Enhancement: Persistent Onboarding Menu]
**Learning:** For initial onboarding or "Welcome" tools, a closing menu after every action frustrates users who want to explore multiple resources. Implementing a persistent loop for informational items significantly improves the discovery flow.
**Action:** Always wrap selection menus in a `while true` loop and only `break` on primary/destructive actions or manual cancellation.

## 2025-05-15 - [Visual Scannability: Emoji Integration]
**Learning:** Adding emojis to Zenity list items in a CLI/GUI hybrid environment (like a Linux live ISO) improves scannability and makes the interface feel more modern and welcoming to non-technical users.
**Action:** Use relevant emojis as prefixes for primary menu actions to aid visual identification.

## 2025-05-15 - [UX Discovery: Keyboard Shortcut Reference]
**Learning:** In a specialized Linux environment (like KibaTV with Plasma Bigscreen), users often don't know the custom keybindings. Providing a "Keyboard Shortcuts" dialog within the primary welcome tool significantly lowers the barrier to entry for power-user features.
**Action:** Include a dedicated "Keyboard Shortcuts" info dialog in the main onboarding tool to surface critical system interactions (e.g., Meta, Terminal, File Manager).
