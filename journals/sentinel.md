# Sentinel Journal

## 2025-05-15 - [Strong Default Password Requirements]

**Vulnerability:** Weak default user passwords allowed during installation (minimum 6 characters).
**Learning:** Default settings in OS installers significantly impact the long-term security of the installed system, as users often stick to the minimum required complexity.
**Prevention:** Enforce a robust minimum password length (e.g., 12 characters) at the installer level to ensure all new installations meet modern security standards.

## 2025-05-15 - [Command Injection in GitHub Actions]

**Vulnerability:** Use of GitHub context variables (e.g., `${{ github.base_ref }}`) directly in `run` steps.
**Learning:** GitHub context variables can contain malicious shell characters or CLI flags if not properly sanitized or mapped to environment variables.
**Prevention:** Always map GitHub context variables to environment variables before using them in shell scripts within workflows. Use the `--` separator for CLI tools to prevent flag injection where applicable.

## 2025-05-31 - [Redundant Plaintext Password Configuration]
**Vulnerability:** Redundant `chpasswd` call with a plaintext password in `build.sh` despite a secure SHA-512 hash already being configured in `/etc/shadow`.
**Learning:** Legacy or redundant configuration steps in complex build scripts can inadvertently re-introduce security weaknesses that were previously addressed by more secure methods.
**Prevention:** Regularly audit build scripts for duplicate logic and enforce the use of secure password hashing, avoiding any plaintext credential handling even for default accounts.
