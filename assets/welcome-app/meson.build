project('kibaos-welcome', 'vala', 'c')

# Dependencies
gtk_dep = dependency('gtk4')
adw_dep = dependency('libadwaita-1')
gio_dep = dependency('gio-2.0')

# Source files
sources = files(
    'main.vala'
)

# Executable
executable('kibaos-welcome', sources,
    dependencies: [gtk_dep, adw_dep, gio_dep],
    install: true
)

# Install desktop file
desktop_file = import('gnome')
desktop_file.install_app(
    'welcome.desktop',
    name: 'Welcome to KibaOS',
    exec: 'kibaos-welcome',
    icon: 'start-here-symbolic',
    categories: ['System', 'Settings', 'GTK'],
    startup_notify: true
)

# Install CSS
css = import('data')
css.install_data(
    'welcome.css',
    install_dir: join_paths(get_option('datadir'), 'kibaos-welcome')
)
