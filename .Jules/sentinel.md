# Sentinel Security Journal

## 2026-06-03 - [Secure Credential Handling and Robust Auditing]

**Vulnerability:** A redundant `chpasswd` call in `build.sh` was using a plaintext password ("live") for the live user, potentially exposing it in build logs. Simultaneously, the `repo_audit.sh` script was generating false positives for security checks (e.g., `chmod 777`) by scanning documentation and its own source code, while missing actual plaintext password risks.

**Learning:** Credential security is easily undermined by redundant "helper" commands that bypass secure storage (like hashed passwords in `/etc/shadow`). Furthermore, security auditing tools must be context-aware; blanket searches for patterns like `chmod 777` or `chpasswd` without proper file exclusions and flag validation lead to "audit fatigue" and missed vulnerabilities.

**Prevention:**

1. Always prefer hashed passwords (e.g., via `openssl passwd -6`) in configuration files over plaintext pipes to `chpasswd`.
2. Ensure audit scripts utilize robust exclusion patterns (`--exclude-dir`, `--exclude`) for non-code artifacts and own-source validation.
3. Validate presence of security flags (like `chpasswd -e`) rather than just the command name to ensure intended security protocols are followed.
