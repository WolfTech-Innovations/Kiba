## 2025-05-15 - Host Contamination via Undefined Variables

**Vulnerability:** The `build.sh` script used the `AIROOTFS` variable to modify system files (like `/etc/passwd`) before the variable was actually defined. When run as root (a requirement for `mkarchiso`), this caused the script to accidentally modify the host system's files because `AIROOTFS` evaluated to an empty string.

**Learning:** Shell scripts that use path variables for chroot environments are dangerous if those variables are not initialized before use. An empty variable can point to the root directory `/`, leading to unintended modifications of the host system.

**Prevention:** Always define all path and directory variables at the very top of the script, before any commands use them. Use `set -u` to catch unset variables, and explicitly create target directories before writing to them.
