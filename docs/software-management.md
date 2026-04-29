# Software Management in KibaOS

KibaOS provides multiple ways to discover, install, and manage software, balancing user-friendliness with powerful command-line tools.

## KibaStore (Bazaar)

The primary graphical software manager in KibaOS is **KibaStore**, which is a native build of **Bazaar**.

- **Purpose:** KibaStore is designed to be a lightweight and user-friendly frontend for managing **Flatpaks**.
- **Native Build:** Unlike many other software centers, KibaStore in KibaOS is built from source during the system build process to ensure it is a native application without unnecessary overhead.
- **Flatpak Integration:** It is pre-configured with the **Flathub** remote, giving users access to thousands of applications out-of-the-box.

## Package Management (CLI)

For users who prefer the command line, KibaOS defaults to **Nala**.

- **Nala:** A frontend for `libapt-pkg`. It provides a much cleaner output, parallel downloads, and a history feature that allows you to undo/redo transactions.
- **Aliases:** To make the transition easier, `apt` and `apt-get` are aliased to `nala` system-wide.

## Specialized Software

### Ungoogled Chromium

KibaOS includes **Ungoogled Chromium** as a privacy-focused browser alternative. It is integrated into the system via a dedicated Open Build Service (OBS) repository to ensure regular updates directly from the source.

### Modern CLI Suite

As detailed in the [UX Design](./ux-design.md) document, KibaOS ships with a suite of modern CLI tools like `eza`, `bat`, `btop`, and `yt-dlp` to provide a superior terminal experience.

## System Updates

Keeping KibaOS up-to-date is simple. You can use KibaStore for graphical updates or the following command in the terminal:

```bash
update
```

This is a pre-configured alias for `sudo nala update && sudo nala upgrade -y`.
