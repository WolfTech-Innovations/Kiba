## 2025-05-14 - [Fixed UI Syntax and Cleaned User-Facing Strings]
**Learning:** Professional UX requires removing technical debt or build-time artifacts from user-facing strings. In KibaTV, trailing comments like `# -dm755` in `.desktop` files are visible in the UI and must be cleaned. Also, QML requires `//` for comments; using `#` breaks the UI rendering.
**Action:** Always audit generated UI files (QML, Desktop entries) for trailing artifacts and ensure correct language-specific comment syntax is used in `scripts/kibatv_build.sh`.
