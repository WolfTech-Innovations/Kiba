## 2025-05-15 - Variable Definition Order and MitM Mitigation
**Vulnerability:** Use of `AIROOTFS` variable before its definition in `build.sh` posed a risk of host system contamination when running with elevated privileges. Additionally, an insecure `http://` URL was used for Calamares connectivity checks.
**Learning:** Shell scripts that use variables as target paths for destructive operations (`mkdir`, `chmod`, redirection) must ensure those variables are defined and non-empty at the absolute top of the script. Insecure `http` endpoints in system installers can be exploited for MitM attacks.
**Prevention:** Implement automated repository audits that verify critical path variables are defined before their first usage and enforce HTTPS for all installation-time connectivity checks.
