## 2026-05-29 - [Security audit script improvements]
**Vulnerability:** The `scripts/repo_audit.sh` script was generating false positives for `chmod 777` by matching its own code, and it lacked checks for hardcoded passwords in `chpasswd` calls.
**Learning:** Security auditing scripts should exclude themselves from recursive searches to avoid false positives. Additionally, hardcoded credentials in build scripts are a common risk that needs automated verification.
**Prevention:** Always use `--exclude` flags in `grep` based audits to ignore the audit script itself and known safe patterns. Incorporate checks for sensitive commands like `chpasswd` to ensure password management follows best practices.
