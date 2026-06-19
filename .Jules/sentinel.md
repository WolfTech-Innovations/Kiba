# Sentinel Journal

## 2026-06-18 - [Secure Connectivity Check URL]

**Vulnerability:** Use of insecure HTTP (`http://example.com`) for Calamares internet connectivity checks.
**Learning:** Even seemingly innocuous connectivity checks can be leveraged for MitM attacks or traffic analysis. Using HTTPS ensures the integrity of the connectivity check and prevents potential redirection or interception.
**Prevention:** Always use HTTPS for any external network requests, including "ping" or connectivity check URLs in system installers.

## 2026-06-19 - [Host Isolation and Secure Temp Files]

**Vulnerability:** Host filesystem contamination in `build.sh` and insecure `/tmp` usage in `kibaos-ota`.
**Learning:** Build scripts running with elevated privileges can accidentally leak files onto the host if paths are not strictly scoped to the target root (`AIROOTFS`) before any filesystem operations occur. Similarly, runtime scripts like `kibaos-ota` using `/tmp` with predictable names are vulnerable to local symlink attacks.
**Prevention:** Define all target-scope path variables at the absolute start of build scripts and enforce their use via automated audits (`repo_audit.sh`). Use private, root-owned runtime directories (e.g., `/var/run/app`) for sensitive temporary data instead of world-writable `/tmp`.
