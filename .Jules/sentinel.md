# Sentinel Journal

## 2026-06-18 - [Secure Connectivity Check URL]

**Vulnerability:** Use of insecure HTTP (`http://example.com`) for Calamares internet connectivity checks.
**Learning:** Even seemingly innocuous connectivity checks can be leveraged for MitM attacks or traffic analysis. Using HTTPS ensures the integrity of the connectivity check and prevents potential redirection or interception.
**Prevention:** Always use HTTPS for any external network requests, including "ping" or connectivity check URLs in system installers.

## 2025-05-15 - [LPE via Symlink in Root OTA Script]

**Vulnerability:** Local Privilege Escalation (LPE) via symlink attack in the `kibaos-ota` script. The script, running as root, wrote screenshots to the world-writable `/tmp` directory. An unprivileged user could create a symlink at `/tmp/kibaos-ota-snap.png` pointing to a root-owned file, causing the root process to overwrite it.
**Learning:** Shell scripts running as root must never write to world-writable directories (`/tmp`, `/var/tmp`) without using secure file creation methods (like `mktemp`) or, preferably, using a restricted-access directory (`/run/project/`).
**Prevention:** Use restricted runtime directories (e.g., `/run/kibaos-ota` with 700 permissions) for all temporary files in root-level scripts. When an unprivileged user must provide data to a root-owned file, use `sudo -u user command - > /root/path` to ensure the root process controls the file creation.
