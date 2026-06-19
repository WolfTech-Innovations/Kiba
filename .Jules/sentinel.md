## 2026-06-19 - [Security] Hardened OTA runtime and host isolation
**Vulnerability:** Symlink-based privilege escalation in world-writable directories and potential host contamination from early script failures.
**Learning:** Temporary runtime files must use restricted, root-owned directories.
**Learning:** Critical build variables must be defined before any file operations occur to ensure correct chroot isolation.
**Prevention:** Use `/var/run/` with 700 permissions for OTA runtime; enforce variable definition order in build scripts.
