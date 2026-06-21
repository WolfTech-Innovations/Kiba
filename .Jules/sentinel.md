# Sentinel Journal

## 2026-06-18 - [Secure Connectivity Check URL]

**Vulnerability:** Use of insecure HTTP (`http://example.com`) for Calamares internet connectivity checks.
**Learning:** Even seemingly innocuous connectivity checks can be leveraged for MitM attacks or traffic analysis. Using HTTPS ensures the integrity of the connectivity check and prevents potential redirection or interception.
**Prevention:** Always use HTTPS for any external network requests, including "ping" or connectivity check URLs in system installers.

## 2026-06-19 - [Secure Temporary Files in OTA Update System]

**Vulnerability:** Use of predictable temporary filenames in `/tmp` by root-privileged processes (`kibaos-ota` and public key import) and insecure file handling for unprivileged user data.
**Learning:** Predictable paths in `/tmp` are vulnerable to symlink attacks. When a root-privileged script needs data from an unprivileged user (e.g., `grim` screenshots), using stdout redirection from a `sudo -u` command to a root-restricted file is more secure than granting broad directory permissions or using world-writable directories.
**Prevention:** Use `mktemp` for short-lived temporary files or utilize root-only persistent directories (e.g., `/var/lib/kibaos-ota`) for sensitive operations. Avoid predictable `/tmp` paths for any root-privileged file operations.
