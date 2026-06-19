# Sentinel Journal

## 2026-06-18 - [Secure Connectivity Check URL]

**Vulnerability:** Use of insecure HTTP (`http://example.com`) for Calamares internet connectivity checks.
**Learning:** Even seemingly innocuous connectivity checks can be leveraged for MitM attacks or traffic analysis. Using HTTPS ensures the integrity of the connectivity check and prevents potential redirection or interception.
**Prevention:** Always use HTTPS for any external network requests, including "ping" or connectivity check URLs in system installers.

## 2026-06-19 - [Secure OTA Runtime Directory]

**Vulnerability:** Use of world-writable `/tmp` for sensitive OTA runtime files (PID and snapshots) enabled potential symlink attacks and local privilege escalation.
**Learning:** Standard temporary directories are unsafe for root-owned processes that handle sensitive state or rely on predictable filenames.
**Prevention:** Use a dedicated, root-owned directory in `/var/run` (or `/run`) with strict `700` permissions for all sensitive runtime data.
