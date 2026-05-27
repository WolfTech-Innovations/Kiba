# Sentinel Journal

## 2025-05-15 - [Strong Default Password Requirements]

**Vulnerability:** Weak default user passwords allowed during installation (minimum 6 characters).
**Learning:** Default settings in OS installers significantly impact the long-term security of the installed system, as users often stick to the minimum required complexity.
**Prevention:** Enforce a robust minimum password length (e.g., 12 characters) at the installer level to ensure all new installations meet modern security standards.

## 2025-05-15 - [Command Injection in GitHub Actions]

**Vulnerability:** Use of GitHub context variables (e.g., `${{ github.base_ref }}`) directly in `run` steps.
**Learning:** GitHub context variables can contain malicious shell characters or CLI flags if not properly sanitized or mapped to environment variables.
**Prevention:** Always map GitHub context variables to environment variables before using them in shell scripts within workflows. Use the `--` separator for CLI tools to prevent flag injection where applicable.

## 2025-05-15 - [AUR Package Signature Verification]

**Vulnerability:** AUR packages being built with `--skippgpcheck`, bypassing source integrity and authenticity verification.
**Learning:** `makepkg` requires the maintainer's public key to be present in the build user's GPG keyring to verify source signatures. Skipping this check introduces a supply chain risk.
**Prevention:** Always import required PGP keys into the build user's keyring (e.g., via `gpg --recv-keys`) and ensure `--skippgpcheck` is never used in production build scripts.
