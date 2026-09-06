# KibaOS Unified Theme

A polished, coherent dark theme for KibaOS based on the Dracula color palette with improved readability and user-friendly aesthetics.

## Overview

This theme provides a unified visual experience across both Cutefish (x86_64) and Budgie (ARM) desktop environments. It replaces the previous combination of Ant-Dark with Dracula color scheme and Kora icons with a fully integrated, custom-designed theme.

## Color Palette

The theme uses the following color scheme:

- **Background**: `#0d1b2a` (Deep navy - easy on eyes)
- **Surface**: `#1a2029` (Slightly lighter for cards and elevated surfaces)
- **Primary**: `#0071e3` (KibaOS blue accent)
- **Secondary**: `#409cff` (Lighter blue for highlights)
- **Success**: `#10b981` (Green for positive actions)
- **Warning**: `#f59e0b` (Amber for attention states)
- **Error**: `#ef4444` (Red for critical issues)
- **Text Primary**: `#f1f5f9` (Light gray for main text)
- **Text Secondary**: `#94a3b8` (Medium gray for secondary text)
- **Text Tertiary**: `#64748b` (Dark gray for subtle text)

## Structure

```
assets/themes/kibaos-themes/
├── gtk-3.0/
│   ├── gtk.css              # Main GTK 3.0 theme styles
│   ├── gtk-dark.css         # Dark variant
│   ├── theme.json           # Theme metadata
│   └── settings.ini         # Default GTK settings
├── gtk-4.0/
│   ├── gtk.css              # Main GTK 4.0 theme styles
│   ├── gtk-dark.css         # Dark variant
│   ├── theme.json           # Theme metadata
│   └── settings.ini         # Default GTK settings
└── index.theme              # Icon theme configuration
```

## Features

### Consistent Design Language
- **Rounded Corners**: All UI elements use consistent border-radius values for a modern, polished look
- **Glass Morphism**: Subtle transparency effects on panels, popovers, and tooltips
- **Asymmetric Radius**: Slightly different corner radii create a natural, organic feel
- **Depth Cues**: Proper shadows and opacity changes indicate hierarchy and focus

### Animation System
The theme uses a carefully crafted set of cubic-bezier timing functions:

- **settle** (`cubic-bezier(0.22, 1, 0.36, 1)`): For entering states (hover, focus, opening). Quick and confident.
- **fade** (`cubic-bezier(0.5, 0, 0.75, 0)`): For leaving states. Slightly slower, things drift off.
- **spring** (`cubic-bezier(0.34, 1.56, 0.64, 1)`): For physical switch knobs with slight overshoot.
- **grow** (`cubic-bezier(0.16, 1, 0.3, 1)`): For structural reveals (menus, panels).

### Component Styling

#### Buttons
- Primary buttons: Pill-shaped with blue accent color and subtle shadow
- Secondary buttons: Transparent with border, hover effects
- Flat buttons: Minimal styling for toolbar actions
- Destructive buttons: Red accent for critical actions

#### Entry Fields
- Clean, rounded design with focus states
- Subtle glow effect on focus
- Error states with red border

#### List Items
- Card-like appearance with rounded corners
- Hover and selection states
- Consistent spacing

#### Switches
- Pill-shaped track with smooth sliding animation
- Accent color when active
- Spring-like motion for the slider

#### Progress Bars
- Rounded pill design
- Gradient fill from primary to accent color
- Smooth width transitions

#### Tooltips
- Small glass cards with subtle border
- Consistent with popover styling
- Proper shadows for depth

### Light Theme Support
The theme includes a light variant that automatically activates when the system prefers light mode. The light variant uses:

- Background: `#f8fafc`
- Surface: `#ffffff`
- Text Primary: `#0f172a`
- All accent colors remain the same for consistency

## Installation

The theme is automatically installed as part of the KibaOS build process. It will be available at:
- `/usr/share/themes/KibaOS/gtk-3.0/`
- `/usr/share/themes/KibaOS/gtk-4.0/`

## Usage

### GTK 3.0 Applications
To use this theme, set the following in your GTK settings:

```ini
[Settings]
gtk-theme-name=KibaOS
gtk-icon-theme-name=Kora
gtk-font-name=Noto Sans 11
```

### GTK 4.0 Applications
GTK 4.0 applications will automatically pick up the theme from `/etc/gtk-4.0/gtk.css`.

### System-Wide Configuration
The build script configures the theme system-wide by:
1. Installing theme files to `/usr/share/themes/KibaOS/`
2. Setting default GTK settings in `/etc/gtk-3.0/settings.ini`
3. Copying configuration to the skeleton directory for new users

## Compatibility

This theme is designed to work with:
- **Cutefish OS** (x86_64): Primary desktop environment for KibaOS
- **Budgie Desktop** (ARM): Mobile/ARM variant
- **GTK 3.0** applications: Full support
- **GTK 4.0** applications: Full support
- **Libadwaita** applications: Compatible with the glass morphism design

## Customization

To customize the theme:

1. **Change Accent Color**: Edit the `@define-color primary-color` values in `gtk.css` files
2. **Adjust Rounding**: Modify the `border-radius` values throughout the CSS
3. **Change Animations**: Update the `transition` properties to use different timing functions
4. **Light/Dark Mode**: Edit the `@media (prefers-color-scheme: light)` sections

## Testing

To test the theme locally:

```bash
# For GTK 3.0
GTK_THEME=KibaOS gtk3-demo

# For GTK 4.0
GTK_THEME=KibaOS gtk4-demo
```

## Contributing

When making changes to the theme:
1. Maintain consistency between GTK 3.0 and GTK 4.0 versions
2. Keep the color palette coherent
3. Test with both light and dark mode preferences
4. Ensure all animations use the defined timing functions
5. Verify compatibility with Cutefish and Budgie desktop environments

## License

This theme is released under the **MIT License**, consistent with the rest of the KibaOS project.

## Credits

- **Design Inspiration**: Dracula color palette
- **Motion Language**: KibaOS Organic Motion Language (custom)
- **Base Theme**: Adwaita-dark (modified)
- **Icon Theme**: Kora (referenced, not included)

## See Also

- [KibaOS Welcome App](../welcome-app/README.md) - The onboarding experience
- [KibaOS Documentation](../../../WIKI.md) - Main project documentation
- [Dracula Theme](https://draculatheme.com/) - Original Dracula color palette
