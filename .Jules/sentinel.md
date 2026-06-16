
## 2025-05-14 - Build Script Path Contamination
**Vulnerability:** Use of path variables (like `${AIROOTFS}`) before they are defined in a script run with root privileges.
**Learning:** If variables are empty, commands like `chmod 755 "${AIROOTFS}/var/cache/pacman"` resolve to `chmod 755 /var/cache/pacman`, which modifies the host system instead of the intended target directory.
**Prevention:** Always define all path and directory variables at the very top of the script, and use `set -u` or `${VAR:?error}` to ensure the script fails if a variable is undefined.
