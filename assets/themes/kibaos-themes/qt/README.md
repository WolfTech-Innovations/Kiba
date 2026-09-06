# KibaOS Qt Theme

This directory contains the Qt theme components for KibaOS, designed to match the GTK theme's visual appearance.

## Structure

```
assets/themes/kibaos-themes/qt/
├── kvantum/
│   └── KibaOS/
│       ├── config/
│       │   └── KibaOS.kvconfig    # Main Kvantum theme configuration
│       ├── KibaOS.svg             # Theme preview SVG with color definitions
│       └── Translations/
│           └── KibaOS.ts           # Translation file for theme metadata
└── README.md                      # This file
```

## Theme Details

### Color Palette

The Qt theme uses the **exact same color palette** as the GTK theme for perfect visual consistency:

| Element | Color | Hex | RGB |
|---------|-------|-----|-----|
| Background | Deep Navy | `#0d1b2a` | 13, 27, 42 |
| Surface | Dark Surface | `#1a2029` | 26, 32, 41 |
| Card | Card Surface | `#1e293b` | 30, 41, 59 |
| Primary | KibaOS Blue | `#0071e3` | 0, 113, 227 |
| Primary Hover | Light Blue | `#0077ed` | 0, 119, 237 |
| Primary Active | Dark Blue | `#0068d6` | 0, 104, 214 |
| Accent | Secondary Blue | `#409cff` | 64, 156, 255 |
| Success | Green | `#10b981` | 16, 185, 129 |
| Warning | Amber | `#f59e0b` | 245, 158, 11 |
| Error | Red | `#ef4444` | 239, 68, 68 |
| Text Primary | Light Gray | `#f1f5f9` | 241, 245, 249 |
| Text Secondary | Medium Gray | `#94a3b8` | 148, 163, 184 |
| Text Tertiary | Dark Gray | `#64748b` | 100, 116, 139 |

### Design Principles

The Qt theme mirrors the GTK theme's design language:

1. **Consistent Rounding**: All elements use matching border-radius values
   - Buttons: Pill-shaped (999px radius)
   - Entry fields: 8px rounded corners
   - Windows: 12px rounded corners
   - Checkboxes: 4px rounded corners
   - Radio buttons: Circular (999px)
   - Scrollbars: Pill-shaped (999px)
   - Progress bars: Pill-shaped (999px)

2. **Shadow System**: Matches GTK theme shadows
   - Window shadow: `0 1px 2px rgba(0, 0, 0, 0.3), 0 4px 12px rgba(0, 0, 0, 0.2)`
   - Button shadow: `0 1px 2px rgba(0, 113, 227, 0.2), 0 3px 8px rgba(0, 113, 227, 0.18)`
   - Button hover: `0 1px 3px rgba(0, 113, 227, 0.25), 0 4px 12px rgba(0, 113, 227, 0.22)`
   - Entry focus: `0 0 0 3px rgba(0, 113, 227, 0.16)`
   - Menu/Tooltip: `0 4px 16px rgba(0, 0, 0, 0.4)`

3. **Animation**: Uses the same cubic-bezier timing function
   - `cubic-bezier(0.22, 1, 0.36, 1)` - 140ms duration

4. **Opacity**: Scrollbar uses 204/255 (80%) opacity for the slider

## Kvantum Configuration File

The `KibaOS.kvconfig` file contains all the theme settings in Kvantum's configuration format. It defines:

- **Colors**: For all widget states (normal, hover, pressed, disabled, etc.)
- **Borders**: Border widths for each widget type
- **Roundings**: Corner radius for each widget type
- **Opacity**: Transparency levels
- **Sizes**: Widget dimensions
- **Shadows**: Drop shadow effects
- **Animations**: Transition effects

### Widget Color Mapping

| Widget | State | Color | Source |
|--------|-------|-------|--------|
| Window | Background | `#0d1b2a` | GTK bg-color |
| Window | Text | `#f1f5f9` | GTK text-primary |
| Button | Background | `#0071e3` | GTK primary-color |
| Button | Text | `#ffffff` | White |
| Button | Hover | `#0077ed` | GTK primary-hover |
| Button | Pressed | `#0068d6` | GTK primary-active |
| Button | Disabled | `#0f172a, 51%` | GTK bg-color at 51% opacity |
| Entry | Background | `#1a2029` | GTK surface-color |
| Entry | Text | `#f1f5f9` | GTK text-primary |
| Entry | Frame | `rgba(255,255,255,0.08)` | GTK border-color |
| Scrollbar | Groove | `rgba(148,163,184,0.16)` | GTK text-secondary at 16% |
| Scrollbar | Slider | `#64748b` | GTK text-tertiary |
| Scrollbar | Slider Hover | `#94a3b8` | GTK text-secondary |
| Scrollbar | Slider Pressed | `#f1f5f9` | GTK text-primary |

## Installation

The theme is automatically installed as part of the KibaOS build process to:
```
/usr/share/Kvantum/KibaOS/
```

### Manual Installation

To install manually:

```bash
# Create the Kvantum themes directory
sudo mkdir -p /usr/share/Kvantum

# Copy the theme
sudo cp -r assets/themes/kibaos-themes/qt/kvantum/KibaOS /usr/share/Kvantum/

# Set permissions
sudo chmod -R 755 /usr/share/Kvantum/KibaOS
```

### Activating the Theme

The theme is activated system-wide via the environment variable:
```bash
QT_STYLE_OVERRIDE=kvantum
```

This is set in `/etc/environment` by the build script.

To select the KibaOS theme specifically:
```bash
# Using Kvantum Manager (GUI)
# Or via command line:
kvconfigmanager5 --set KibaOS
```

## Usage with Kvantum

### Kvantum Manager

The Kvantum Manager application (installed via `kvantum` package) allows users to:
- Preview the theme
- Select the theme
- Customize colors and settings
- Export/import themes

Note: The Kvantum Manager desktop file is hidden from the application menu in the build script (line 14123 in build.sh), but the theme itself is fully functional.

### Configuration Files

Kvantum stores user-specific theme configurations in:
```
~/.config/kvantum/KibaOS/
```

The system-wide configuration is in:
```
/usr/share/Kvantum/KibaOS/
```

## Compatibility

This theme is designed for:
- **Qt 5.x** applications
- **Qt 6.x** applications (via Kvantum's Qt6 support)
- **Kvantum** theme engine (version 1.0.0+)
- **KDE Plasma** desktop environment
- **Cutefish OS** desktop environment (x86_64)

### KDE Integration

For KDE Plasma, the theme integrates with:
- Plasma desktop widgets
- KWin window decorations
- KDE applications (Dolphin, Kate, Konsole, etc.)
- System settings

### Cutefish Integration

For Cutefish OS (the primary x86_64 desktop):
- Qt applications automatically use the Kvantum theme via `QT_STYLE_OVERRIDE=kvantum`
- The `cutefish-meta` package (installed via AUR/yay) provides additional KDE/Qt integration
- Wayland support via `QT_QPA_PLATFORM=wayland`

## Theme Components

### Color Definitions

The theme defines colors for all standard Qt widget states:
- **Normal**: Default appearance
- **Hover**: Mouse over state
- **Pressed**: Clicked/active state
- **Disabled**: Unavailable state
- **Focus**: Keyboard focus state
- **Selected**: Selected state
- **Inactive**: Window inactive state

### Widget Types

All standard Qt widgets are styled:
- QPushButton
- QLineEdit, QTextEdit, QPlainTextEdit
- QComboBox
- QSpinBox, QDoubleSpinBox
- QCheckBox
- QRadioButton
- QSlider
- QProgressBar
- QScrollBar
- QTabBar, QTabWidget
- QMenu, QMenuBar
- QStatusBar
- QTooltip
- QGroupBox
- QFrame
- QLabel
- QTreeView, QListView, QTableView
- QHeaderView
- QDialog
- QMessageBox
- QFileDialog
- QColorDialog
- QFontDialog

## Customization

To customize the theme:

1. **Edit the .kvconfig file**: Modify colors, borders, roundings, etc.
2. **Use Kvantum Manager**: GUI tool for live preview and editing
3. **Create a variant**: Copy the theme and modify as needed

### Common Customizations

#### Change Accent Color

Edit the primary color values in `KibaOS.kvconfig`:
```ini
[Root/General/Colors/Button/Normal]
Color=0,113,227
```

Change to your preferred RGB values.

#### Adjust Rounding

Edit the rounding values:
```ini
[Root/General/Roundings/Button]
Value=999
```

Use lower values for less rounded corners (0 = square).

#### Change Animation Duration

Edit the animation settings:
```ini
[Root/General/Animations/Duration]
Value=140
```

## Light Theme Variant

Currently, the theme is dark-only. To create a light variant:

1. Copy the theme directory
2. Modify all color values to use light theme colors from the GTK theme
3. Update the metadata to indicate it's a light variant

The GTK theme's light variant uses:
- Background: `#f8fafc`
- Surface: `#ffffff`
- Text Primary: `#0f172a`
- All accent colors remain the same

## Testing

To test the theme locally:

```bash
# Set the theme for a single application
QT_STYLE_OVERRIDE=kvantum kvconfigmanager5 --set KibaOS

# Test with a Qt application
QT_STYLE_OVERRIDE=kvantum qt5ct

# Or use Kvantum Manager to preview
kvantummanager
```

## Build Integration

The theme is integrated into the KibaOS build process:

1. **Package Installation**: `kvantum` is installed via pacman (line 2637 in build.sh)
2. **x86_64 Specific**: `cutefish-meta` is installed via AUR/yay for x86_64 (lines 5989-6007)
3. **Environment Configuration**: `QT_STYLE_OVERRIDE=kvantum` is set in `/etc/environment` (line 14259)
4. **Theme Installation**: This theme should be copied to `/usr/share/Kvantum/KibaOS/` during build

### Required Build Script Changes

To integrate this theme into the build process, add the following to `build.sh`:

```bash
# Install KibaOS Qt theme
mkdir -p /usr/share/Kvantum
cp -r assets/themes/kibaos-themes/qt/kvantum/KibaOS /usr/share/Kvantum/
chmod -R 755 /usr/share/Kvantum/KibaOS

# Set default Kvantum theme
echo "[General]
Theme=KibaOS" > /etc/xdg/kvantum.kvconfig
```

## Files

| File | Purpose |
|------|---------|
| `KibaOS.kvconfig` | Main theme configuration |
| `KibaOS.svg` | Theme preview and color definitions |
| `KibaOS.ts` | Translation file for metadata |

## License

This theme is released under the **MIT License**, consistent with the rest of the KibaOS project.

## See Also

- [KibaOS GTK Theme](../README.md) - The GTK theme this Qt theme matches
- [KibaOS Welcome App](../../welcome-app/README.md) - The onboarding experience
- [Kvantum Documentation](https://github.com/tsujan/Kvantum) - Kvantum theme engine documentation
- [Qt Style Sheets](https://doc.qt.io/qt-5/stylesheet.html) - Qt styling reference

## Credits

- **Design**: Based on the KibaOS GTK theme color palette
- **Kvantum**: Theme engine by Tsujan (https://github.com/tsujan/Kvantum)
- **Color Palette**: Dracula-inspired with KibaOS blue accents
