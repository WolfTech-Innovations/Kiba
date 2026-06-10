# Sentinel Journal

## 2025-05-15 - [Strong Default Password Requirements]

**Vulnerability:** Weak default user passwords allowed during installation (minimum 6 characters).
**Learning:** Default settings in OS installers significantly impact the long-term security of the installed system, as users often stick to the minimum required complexity.
**Prevention:** Enforce a robust minimum password length (e.g., 12 characters) at the installer level to ensure all new installations meet modern security standards.

## 2025-05-15 - [Command Injection in GitHub Actions]

**Vulnerability:** Use of GitHub context variables (e.g., `${{ github.base_ref }}`) directly in `run` steps.
**Learning:** GitHub context variables can contain malicious shell characters or CLI flags if not properly sanitized or mapped to environment variables.
**Prevention:** Always map GitHub context variables to environment variables before using them in shell scripts within workflows. Use the `--` separator for CLI tools to prevent flag injection where applicable.

## 2025-06-10 - [Harden password handling in build scripts]

**Vulnerability:** Use of `echo "user:pass" | chpasswd` exposes passwords in plaintext within build scripts and potentially shell history/logs.
**Learning:** Using `chpasswd -e` with pre-computed hashes (e.g., SHA-512 via `openssl passwd -6`) ensures that sensitive credentials are never stored or transmitted in plaintext.
**Prevention:** Implement automated repository audits to flag `chpasswd` usage that lacks the `-e` (encrypted) flag.
