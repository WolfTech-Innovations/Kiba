/* KibaOS Welcome Application
 * A user-friendly onboarding experience for new KibaOS users
 * 
 * This app provides:
 * - A warm welcome message
 * - Quick access to essential system features
 * - Helpful tips for getting started
 * - Clean, coherent UI matching KibaOS theme
 */

using Gtk;
using Adw;
using Gee;

public class KibaWelcome : Adw.Application {
    private Adw.ApplicationWindow window;
    private Adw.NavigationView nav_view;
    private const string CSS_PATH = "/usr/share/kibaos-welcome/welcome.css";
    private const string MARKER_FILE = "/var/lib/kibaos/.welcome-shown";

    public KibaWelcome () {
        Object (application_id: "com.wolftechinnovations.kibaos.Welcome");
    }

    protected override void activate () {
        // Check if we should show the welcome app
        if (GLib.FileUtils.test (MARKER_FILE, GLib.FileTest.EXISTS)) {
            // Already shown, just exit
            this.quit ();
            return;
        }

        // Load our custom CSS
        var provider = new Gtk.CssProvider ();
        provider.load_from_path (CSS_PATH);
        Gtk.StyleContext.add_provider_for_display (
            Gdk.Display.get_default (), provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        // Create main window
        window = new Adw.ApplicationWindow (this) {
            default_width = 800,
            default_height = 600,
            title = "Welcome to KibaOS",
            resizable = false,
            decorated = true
        };
        window.add_css_class ("kibaos-welcome-window");

        // Prevent closing during onboarding
        window.close_request.connect (() => {
            // Allow closing if user wants to skip
            mark_as_shown ();
            return false; // Allow close
        });

        // Set up navigation
        nav_view = new Adw.NavigationView ();
        window.set_content (nav_view);

        // Build pages
        var welcome_page = build_welcome_page ();
        var features_page = build_features_page ();
        var tips_page = build_tips_page ();
        var finish_page = build_finish_page ();

        // Add pages to navigation
        nav_view.add (welcome_page);
        nav_view.add (features_page);
        nav_view.add (tips_page);
        nav_view.add (finish_page);

        // Show the window
        window.present ();

        // Mark as shown when we reach the finish page
        nav_view.notify["visible-page"].connect (() => {
            if (nav_view.visible_page == finish_page) {
                mark_as_shown ();
            }
        });
    }

    private void mark_as_shown () {
        try {
            var dir = GLib.Path.get_dirname (MARKER_FILE);
            GLib.Mkdir.with_parents (dir, 0755);
            GLib.FileUtils.set_contents (MARKER_FILE, "shown");
        } catch (GLib.Error e) {
            // Silently fail if we can't write the marker
        }
    }

    private Adw.NavigationPage build_welcome_page () {
        var page = new Adw.NavigationPage () {
            title = "Welcome to KibaOS"
        };

        var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 24) {
            margin_all = 32,
            halign = Gtk.Align.CENTER,
            valign = Gtk.Align.CENTER
        };

        // Logo/Icon
        var logo = new Gtk.Image () {
            icon_name = "start-here-symbolic",
            pixel_size = 128
        };
        logo.add_css_class ("welcome-logo");

        // Welcome title
        var title = new Gtk.Label ("Welcome to KibaOS") {
            halign = Gtk.Align.CENTER
        };
        title.add_css_class ("welcome-title");

        // Subtitle
        var subtitle = new Gtk.Label ("A friendly, ready-to-use Linux desktop built for simplicity") {
            halign = Gtk.Align.CENTER,
            wrap = true,
            max_width_chars = 40
        };
        subtitle.add_css_class ("welcome-subtitle");

        // Description
        var description = new Gtk.Label ("KibaOS makes Linux easy. Everything works out of the box, with a clean, modern look that feels familiar and comfortable.") {
            halign = Gtk.Align.CENTER,
            wrap = true,
            max_width_chars = 50
        };
        description.add_css_class ("welcome-description");

        // Main action button
        var start_button = new Gtk.Button () {
            label = "Get Started",
            halign = Gtk.Align.CENTER,
            margin_top = 24
        };
        start_button.add_css_class ("welcome-primary-button");
        start_button.clicked.connect (() => {
            nav_view.push (build_features_page ());
        });

        // Skip link
        var skip_link = new Gtk.Button () {
            label = "Skip and start using KibaOS",
            halign = Gtk.Align.CENTER
        };
        skip_link.add_css_class ("welcome-skip-link");
        skip_link.clicked.connect (() => {
            mark_as_shown ();
            window.destroy ();
        });

        // Assemble the page
        box.append (logo);
        box.append (title);
        box.append (subtitle);
        box.append (description);
        box.append (start_button);
        box.append (skip_link);

        page.set_child (box);
        return page;
    }

    private Adw.NavigationPage build_features_page () {
        var page = new Adw.NavigationPage () {
            title = "What KibaOS Offers"
        };

        var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 16) {
            margin_all = 24
        };

        // Header
        var header = new Gtk.Label ("Discover what makes KibaOS special") {
            halign = Gtk.Align.CENTER
        };
        header.add_css_class ("features-header");

        // Features grid
        var grid = new Gtk.Grid () {
            column_spacing = 16,
            row_spacing = 16,
            halign = Gtk.Align.CENTER,
            margin_top = 16
        };

        // Feature 1: Ready to Use
        var feature1_box = create_feature_card (
            "applications-system-symbolic",
            "Ready to Use",
            "All the apps you need are already installed and waiting for you"
        );

        // Feature 2: Simple Design
        var feature2_box = create_feature_card (
            "video-display-symbolic",
            "Simple Design",
            "Clean, modern interface that feels familiar from day one"
        );

        // Feature 3: Windows Support
        var feature3_box = create_feature_card (
            "windows-symbolic",
            "Windows Workspace",
            "Run Windows programs seamlessly alongside your Linux apps"
        );

        // Feature 4: Automatic Updates
        var feature4_box = create_feature_card (
            "system-software-update-symbolic",
            "Automatic Updates",
            "Your system stays up to date without interrupting your work"
        );

        // Feature 5: Help When You Need It
        var feature5_box = create_feature_card (
            "help-browser-symbolic",
            "Help Available",
            "Easy access to documentation and support when you need it"
        );

        // Feature 6: Customizable
        var feature6_box = create_feature_card (
            "preferences-system-symbolic",
            "Make It Yours",
            "Personalize your experience with easy-to-use settings"
        );

        // Add features to grid
        grid.attach (feature1_box, 0, 0, 1, 1);
        grid.attach (feature2_box, 1, 0, 1, 1);
        grid.attach (feature3_box, 2, 0, 1, 1);
        grid.attach (feature4_box, 0, 1, 1, 1);
        grid.attach (feature5_box, 1, 1, 1, 1);
        grid.attach (feature6_box, 2, 1, 1, 1);

        // Navigation buttons
        var nav_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 16) {
            halign = Gtk.Align.CENTER,
            margin_top = 24
        };

        var back_button = new Gtk.Button () {
            label = "Back"
        };
        back_button.add_css_class ("welcome-secondary-button");
        back_button.clicked.connect (() => {
            nav_view.pop ();
        });

        var next_button = new Gtk.Button () {
            label = "Continue"
        };
        next_button.add_css_class ("welcome-primary-button");
        next_button.clicked.connect (() => {
            nav_view.push (build_tips_page ());
        });

        nav_box.append (back_button);
        nav_box.append (next_button);

        box.append (header);
        box.append (grid);
        box.append (nav_box);

        page.set_child (box);
        return page;
    }

    private Adw.NavigationPage build_tips_page () {
        var page = new Adw.NavigationPage () {
            title = "Quick Tips"
        };

        var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 16) {
            margin_all = 24
        };

        // Header
        var header = new Gtk.Label ("Helpful tips to get you started") {
            halign = Gtk.Align.CENTER
        };
        header.add_css_class ("tips-header");

        // Tips list
        var tips_list = new Gtk.Box (Gtk.Orientation.VERTICAL, 12) {
            margin_top = 16
        };

        // Tip 1: Right-click
        var tip1 = create_tip_row (
            "1.",
            "Right-click for options",
            "Right-click on the desktop or in folders to access context menus with common actions"
        );

        // Tip 2: App Menu
        var tip2 = create_tip_row (
            "2.",
            "Find your apps",
            "Click the application menu in the bottom-left corner to see all installed apps"
        );

        // Tip 3: Settings
        var tip3 = create_tip_row (
            "3.",
            "Customize your system",
            "Use the Settings app to personalize your desktop, change themes, and more"
        );

        // Tip 4: File Manager
        var tip4 = create_tip_row (
            "4.",
            "Manage your files",
            "Nemo file manager makes it easy to browse, copy, and organize your files"
        );

        // Tip 5: Terminal
        var tip5 = create_tip_row (
            "5.",
            "Need the terminal?",
            "The terminal is available for advanced tasks, but most things can be done without it"
        );

        // Tip 6: Help
        var tip6 = create_tip_row (
            "6.",
            "Get help anytime",
            "Visit our Wiki or GitHub for documentation and community support"
        );

        tips_list.append (tip1);
        tips_list.append (tip2);
        tips_list.append (tip3);
        tips_list.append (tip4);
        tips_list.append (tip5);
        tips_list.append (tip6);

        // Navigation buttons
        var nav_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 16) {
            halign = Gtk.Align.CENTER,
            margin_top = 24
        };

        var back_button = new Gtk.Button () {
            label = "Back"
        };
        back_button.add_css_class ("welcome-secondary-button");
        back_button.clicked.connect (() => {
            nav_view.pop ();
        });

        var next_button = new Gtk.Button () {
            label = "Finish"
        };
        next_button.add_css_class ("welcome-primary-button");
        next_button.clicked.connect (() => {
            nav_view.push (build_finish_page ());
        });

        nav_box.append (back_button);
        nav_box.append (next_button);

        box.append (header);
        box.append (tips_list);
        box.append (nav_box);

        page.set_child (box);
        return page;
    }

    private Adw.NavigationPage build_finish_page () {
        var page = new Adw.NavigationPage () {
            title = "You're All Set!"
        };

        var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 24) {
            margin_all = 32,
            halign = Gtk.Align.CENTER,
            valign = Gtk.Align.CENTER
        };

        // Success icon
        var icon = new Gtk.Image () {
            icon_name = "object-select-symbolic",
            pixel_size = 128
        };
        icon.add_css_class ("finish-icon");

        // Success message
        var title = new Gtk.Label ("You're all set!") {
            halign = Gtk.Align.CENTER
        };
        title.add_css_class ("finish-title");

        // Subtitle
        var subtitle = new Gtk.Label ("KibaOS is ready to use") {
            halign = Gtk.Align.CENTER
        };
        subtitle.add_css_class ("finish-subtitle");

        // Description
        var description = new Gtk.Label ("Start exploring your new system. Everything is set up and ready to go. If you need help, check out the documentation or ask in our community.") {
            halign = Gtk.Align.CENTER,
            wrap = true,
            max_width_chars = 50
        };
        description.add_css_class ("finish-description");

        // Action buttons
        var button_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 16) {
            halign = Gtk.Align.CENTER,
            margin_top = 24
        };

        var open_settings = new Gtk.Button () {
            label = "Open Settings"
        };
        open_settings.add_css_class ("welcome-secondary-button");
        open_settings.clicked.connect (() => {
            try {
                GLib.Process.spawn_command_line_async ("kibaos-settings");
            } catch (GLib.SpawnError e) {
                // Fallback to generic settings
                try {
                    GLib.Process.spawn_command_line_async ("cutefish-settings");
                } catch (GLib.SpawnError e2) {
                    // Try another approach
                    try {
                        GLib.Process.spawn_command_line_async ("budgie-desktop-settings");
                    } catch (GLib.SpawnError e3) {}
                }
            }
            mark_as_shown ();
            window.destroy ();
        });

        var start_exploring = new Gtk.Button () {
            label = "Start Exploring"
        };
        start_exploring.add_css_class ("welcome-primary-button");
        start_exploring.clicked.connect (() => {
            mark_as_shown ();
            window.destroy ();
        });

        button_box.append (open_settings);
        button_box.append (start_exploring);

        box.append (icon);
        box.append (title);
        box.append (subtitle);
        box.append (description);
        box.append (button_box);

        page.set_child (box);
        return page;
    }

    private Gtk.Widget create_feature_card (string icon_name, string title, string description) {
        var card = new Gtk.Box (Gtk.Orientation.VERTICAL, 12) {
            width_request = 240
        };
        card.add_css_class ("feature-card");

        // Icon
        var icon = new Gtk.Image () {
            icon_name = icon_name,
            pixel_size = 48
        };
        icon.add_css_class ("feature-icon");
        icon.halign = Gtk.Align.CENTER;

        // Title
        var title_label = new Gtk.Label (title) {
            halign = Gtk.Align.CENTER
        };
        title_label.add_css_class ("feature-title");

        // Description
        var desc_label = new Gtk.Label (description) {
            halign = Gtk.Align.CENTER,
            wrap = true,
            max_width_chars = 30
        };
        desc_label.add_css_class ("feature-description");

        card.append (icon);
        card.append (title_label);
        card.append (desc_label);

        return card;
    }

    private Gtk.Widget create_tip_row (string number, string title, string description) {
        var row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 16) {
            hexpand = true
        };
        row.add_css_class ("tip-row");

        // Number
        var number_label = new Gtk.Label (number) {
            width_request = 32
        };
        number_label.add_css_class ("tip-number");

        // Content
        var content_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 4) {
            hexpand = true
        };

        var title_label = new Gtk.Label (title) {
            halign = Gtk.Align.START
        };
        title_label.add_css_class ("tip-title");

        var desc_label = new Gtk.Label (description) {
            halign = Gtk.Align.START,
            wrap = true
        };
        desc_label.add_css_class ("tip-description");

        content_box.append (title_label);
        content_box.append (desc_label);

        row.append (number_label);
        row.append (content_box);

        return row;
    }

    public static int main (string[] args) {
        var app = new KibaWelcome ();
        return app.run (args);
    }
}
