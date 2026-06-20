# Sentinel Journal

## 2026-06-18 - [Secure Connectivity Check URL]

**Vulnerability:** Use of insecure HTTP (`http://example.com`) for Calamares internet connectivity checks.
**Learning:** Even seemingly innocuous connectivity checks can be leveraged for MitM attacks or traffic analysis. Using HTTPS ensures the integrity of the connectivity check and prevents potential redirection or interception.
**Prevention:** Always use HTTPS for any external network requests, including "ping" or connectivity check URLs in system installers.

## 2026-06-21 - [Secure Runtime Directories for Root Scripts]
**Vulnerability:** Use of world-writable `/tmp` for sensitive data (desktop screenshots and PID files) in a root-owned background script.
**Learning:** Background processes running as root that interact with unprivileged users must avoid `/tmp` to prevent symlink-based local privilege escalation and information disclosure.
**Prevention:** Utilize restricted root-owned directories (e.g., `/var/run/app-name` with `700` permissions) for all temporary runtime files. Use stdout redirection in unprivileged commands (`sudo -u user cmd - > secure_file`) to safely bridge data between trust levels.
