# KibaOS UX & Design

KibaOS is designed with a focus on visual consistency, modern aesthetics, and a powerful yet simple user experience.

## Visual Identity

The KibaOS aesthetic is built around the **Dracula** color palette, providing a dark, high-contrast interface that is easy on the eyes.

### Look and Feel

- **Desktop Environment:** KDE Plasma 6.3.
- **Global Theme:** A customized version of **Ant-Dark**.
- **Color Scheme:** **Dracula**, applied system-wide to Plasma widgets, window decorations, and applications.
- **Icons:** **Kora** icon theme for a colorful and modern look.
- **Cursors:** **Vimix** cursor theme.
- **Fonts:** **Inter** for the system UI and **JetBrains Mono** for monospace/terminal text.

### Window Management

- **Rounded Corners:** KWin is configured to provide 16px rounded corners for all windows.
- **Glass Effects:** Blur and contrast effects are enabled for an elegant, translucent look.
- **Floating Panel:** The Plasma panel is configured to be floating and rounded by default.

## Shell Experience

KibaOS provides a highly optimized terminal experience using **Zsh** as the default shell for all users.

### Starship Prompt

The **Starship** cross-shell prompt is pre-installed and configured with a minimalist Dracula-themed layout.

### Modern CLI Tools

We prefer modern, faster alternatives to classic Unix commands:

- **`nala`**: A beautiful and feature-rich frontend for `apt`.
- **`eza`**: A modern replacement for `ls` with icons and color-coding.
- **`bat`**: A `cat` clone with syntax highlighting and Git integration.
- **`fastfetch`**: A fast and highly customizable system information tool.
- **`btop`**: An interactive resource monitor.
- **`ripgrep` (`rg`)**: An extremely fast alternative to `grep`.
- **`fd-find` (`fd`)**: A simple, fast, and user-friendly alternative to `find`.
- **`tealdeer` (`tldr`)**: A fast implementation of `tldr` for simplified man pages.

### System-wide Aliases

Common aliases are configured in `/etc/zsh/zshrc` to improve workflow:

- `apt` -> `nala`
- `ls` -> `eza`
- `cat` -> `bat`
- `grep` -> `ripgrep`
- `update` -> `sudo nala update && sudo nala upgrade -y`

## Boot Branding

The branding experience starts from the moment the system boots:

- **Plymouth:** A custom "kibaos-spinner" theme with a Dracula-themed progress bar.
- **ISOLINUX:** The bootloader menu features Dracula colors and plain-English options for ease of use.
