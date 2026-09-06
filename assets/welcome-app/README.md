# KibaOS Welcome Application

A user-friendly onboarding experience for new KibaOS users, designed to provide a warm welcome and quick access to essential system features.

## Overview

The KibaOS Welcome App is a GTK4/Libadwaita application that guides new users through their first experience with KibaOS. It provides:

- A warm welcome message introducing KibaOS
- An overview of key features and capabilities
- Helpful tips for getting started
- Quick access to system settings
- A clean, coherent UI matching the KibaOS theme

## Features

### Welcome Page
- Friendly greeting with KibaOS branding
- Brief introduction to the operating system
- Clear call-to-action to get started
- Option to skip the onboarding

### Features Overview
Showcases what makes KibaOS special:

1. **Ready to Use**: All essential apps pre-installed
2. **Simple Design**: Clean, modern interface
3. **Windows Workspace**: Run Windows programs seamlessly
4. **Automatic Updates**: System stays up-to-date
5. **Help Available**: Easy access to documentation
6. **Make It Yours**: Personalization options

### Quick Tips
Provides practical guidance for new users:

1. Right-click for context menus
2. Finding applications in the menu
3. Customizing system settings
4. Managing files with Nemo
5. Using the terminal (when needed)
6. Getting help from the community

### Finish Page
- Confirmation that setup is complete
- Option to open system settings
- Encouragement to start exploring

## Design Principles

### User-Friendly Language
- **No emojis**: Uses plain text for maximum compatibility
- **Clear and concise**: Short, direct statements
- **Action-oriented**: Focuses on what users can do
- **Reassuring tone**: Welcoming and supportive

### Visual Design
- **Consistent with KibaOS Theme**: Uses the same color palette and styling
- **Modern and clean**: Follows current design trends
- **Accessible**: High contrast, readable fonts
- **Responsive**: Adapts to different screen sizes

### Navigation
- **Linear flow**: Step-by-step progression
- **Clear hierarchy**: One primary action per screen
- **Back navigation**: Allows users to review previous steps
- **Skip option**: Respects users who want to dive in immediately

## Technical Details

### Architecture
- **Language**: Vala (compiled to C)
- **Framework**: GTK4 + Libadwaita
- **Build System**: Meson
- **Installation**: System-wide via `/usr/local/bin/kibaos-welcome`

### File Structure

```
assets/welcome-app/
├── main.vala              # Main application source code
├── welcome.css           # Custom CSS styling
├── welcome.desktop       # Desktop entry for manual launch
├── kibaos-welcome.desktop # Autostart desktop entry
├── meson.build           # Meson build configuration
└── README.md             # This file
```

### Dependencies
- `gtk4` (>= 4.0)
- `libadwaita` (>= 1.0)
- `glib2` (>= 2.0)
- `vala` (>= 0.56)
- `meson` (>= 0.60)
- `ninja`

## Installation

The welcome app is automatically installed as part of the KibaOS build process. The build script:

1. Copies the source files to the build directory
2. Compiles the Vala code using Meson
3. Installs the binary to `/usr/local/bin/kibaos-welcome`
4. Installs the CSS to `/usr/share/kibaos-welcome/welcome.css`
5. Installs desktop entries for manual launch and autostart

### Manual Installation

To build and install manually:

```bash
# Install dependencies
sudo pacman -S gtk4 libadwaita vala meson ninja

# Build and install
cd /path/to/welcome-app
meson setup builddir
cd builddir
ninja
sudo ninja install
```

## Usage

### Automatic Launch
The welcome app automatically launches on first login through the autostart mechanism. It checks for a marker file at `/var/lib/kibaos/.welcome-shown` to determine if it has already been shown.

### Manual Launch
Users can manually launch the welcome app by:
- Running `kibaos-welcome` from the terminal
- Finding "Welcome to KibaOS" in the application menu

### Command Line Options
The welcome app accepts standard GTK application arguments:

```bash
kibaos-welcome [OPTIONS...]
```

Common GTK options:
- `--help`: Show help options
- `--version`: Show version information
- `--gdk-debug=FLAGS`: GDK debugging flags
- `--gtk-debug=FLAGS`: GTK debugging flags

## Configuration

### Marker File
The welcome app uses a marker file to track whether it has been shown:
- **Location**: `/var/lib/kibaos/.welcome-shown`
- **Content**: Simple text file containing "shown"
- **Purpose**: Prevents the welcome app from showing on every login

### Autostart Configuration
The welcome app is configured to autostart through:
- **Desktop Entry**: `/etc/xdg/autostart/kibaos-welcome.desktop`
- **Condition**: Only if the marker file does not exist

## Customization

### Changing the Content
To modify the welcome app content:

1. Edit `main.vala` to change the text, features, or tips
2. Update `welcome.css` to change the styling
3. Rebuild and reinstall the application

### Adding New Pages
The app uses `Adw.NavigationView` for navigation. To add a new page:

1. Create a new method `build_newpage_page()` in `main.vala`
2. Add the page to the navigation view
3. Update the navigation flow between pages

### Theming
The welcome app uses custom CSS that matches the KibaOS theme. To change the appearance:

1. Edit `welcome.css`
2. Ensure color palette matches the main theme
3. Test with both light and dark mode

## Platform Support

The welcome app is designed to work with both KibaOS variants:

### x86_64 (Cutefish OS)
- Full support for all features
- Optimized for desktop/laptop use
- Uses Cutefish-specific settings commands

### ARM (Budgie Desktop)
- Full support for all features
- Adapted for mobile/touch use
- Uses Budgie-specific settings commands

## Testing

To test the welcome app:

```bash
# Run directly
kibaos-welcome

# Reset the marker file to test first-run experience
sudo rm -f /var/lib/kibaos/.welcome-shown

# Test with different GTK themes
GTK_THEME=Adwaita-dark kibaos-welcome
```

## Troubleshooting

### App Doesn't Launch
- Check that all dependencies are installed
- Verify the binary exists at `/usr/local/bin/kibaos-welcome`
- Check the marker file doesn't exist at `/var/lib/kibaos/.welcome-shown`
- Look for errors in the terminal output

### Styling Issues
- Verify the CSS file is installed at `/usr/share/kibaos-welcome/welcome.css`
- Check that the app can read the CSS file (permissions)
- Ensure the theme colors match your system theme

### Navigation Problems
- Check the navigation view connections in `main.vala`
- Verify all page methods return valid widgets
- Ensure the marker file is being created correctly

## Integration with KibaOS

The welcome app integrates with KibaOS in several ways:

### Settings Integration
The app can launch the appropriate settings application based on the desktop environment:
- Cutefish: `cutefish-settings`
- Budgie: `budgie-desktop-settings`
- Fallback: `kibaos-settings`

### First Login Script
The welcome app works alongside the `kibaos-first-login` script, which:
1. Configures default system settings
2. Sets up the panel and applets
3. Creates the marker file

### Branding
The welcome app uses KibaOS branding:
- Icon: `start-here-symbolic`
- Colors: Matches the KibaOS theme palette
- Typography: Uses Noto Sans font family

## Future Enhancements

Potential improvements for future versions:

1. **Interactive Tutorials**: Step-by-step guides for common tasks
2. **Video Content**: Embedded videos demonstrating features
3. **Customization Options**: Allow users to configure preferences during setup
4. **Language Selection**: Support for multiple languages
5. **Accessibility Options**: Configure accessibility features during setup
6. **Hardware Detection**: Provide hardware-specific tips and configuration

## License

The KibaOS Welcome App is released under the **MIT License**, consistent with the rest of the KibaOS project.

## Credits

- **Design**: Kiba Labs, LLC
- **Development**: KibaOS Team
- **Framework**: GTK4 + Libadwaita
- **Icon**: `start-here-symbolic` from the system icon theme

## See Also

- [KibaOS Unified Theme](../themes/kibaos-themes/README.md) - The system theme
- [KibaOS Documentation](../../../WIKI.md) - Main project documentation
- [GTK4 Documentation](https://docs.gtk.org/gtk4/) - GTK4 framework documentation
- [Libadwaita Documentation](https://gnome.pages.gitlab.gnome.org/libadwaita/) - Libadwaita library documentation
