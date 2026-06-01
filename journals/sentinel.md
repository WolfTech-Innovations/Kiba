# Sentinel Journal

## 2025-05-15 - [Strong Default Password Requirements]

**Vulnerability:** Weak default user passwords allowed during installation (minimum 6 characters).
**Learning:** Default settings in OS installers significantly impact the long-term security of the installed system, as users often stick to the minimum required complexity.
**Prevention:** Enforce a robust minimum password length (e.g., 12 characters) at the installer level to ensure all new installations meet modern security standards.

## 2025-05-15 - [Command Injection in GitHub Actions]

**Vulnerability:** Use of GitHub context variables (e.g., `${{ github.base_ref }}`) directly in `run` steps.
**Learning:** GitHub context variables can contain malicious shell characters or CLI flags if not properly sanitized or mapped to environment variables.
**Prevention:** Always map GitHub context variables to environment variables before using them in shell scripts within workflows. Use the `--` separator for CLI tools to prevent flag injection where applicable.

## 2026-06-01 - [Eliminating Redundant Plaintext Passwords in Build Scripts]

**Vulnerability:** Redundant `echo "user:pass" | chpasswd` call in `build.sh` despite the password being already set via a hashed shadow entry.
**Learning:** Redundant credential setting commands often bypass established security patterns (like using `openssl passwd` for hashing) and introduce plaintext secrets into logs or script files unnecessarily.
**Prevention:** Audit build scripts for multiple methods of setting the same credential. Consolidate into a single, secure method (e.g., pre-hashed shadow entries) and enforce this via automated audits that flag `chpasswd` usage without the `-e` (encrypted) flag.
