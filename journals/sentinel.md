# Sentinel Journal

## 2025-05-15 - [Strong Default Password Requirements]

**Vulnerability:** Weak default user passwords allowed during installation (minimum 6 characters).
**Learning:** Default settings in OS installers significantly impact the long-term security of the installed system, as users often stick to the minimum required complexity.
**Prevention:** Enforce a robust minimum password length (e.g., 12 characters) at the installer level to ensure all new installations meet modern security standards.

## 2025-05-15 - [Command Injection in GitHub Actions]

**Vulnerability:** Use of GitHub context variables (e.g., `${{ github.base_ref }}`) directly in `run` steps.
**Learning:** GitHub context variables can contain malicious shell characters or CLI flags if not properly sanitized or mapped to environment variables.
**Prevention:** Always map GitHub context variables to environment variables before using them in shell scripts within workflows. Use the `--` separator for CLI tools to prevent flag injection where applicable.

## 2026-05-27 - [Enforcing PGP Verification for AUR Packages]

**Vulnerability:** AUR package builds in `build.sh` used the `--skippgpcheck` flag, bypassing source integrity verification.
**Learning:** Automated build scripts often skip security checks for convenience, but this exposes the system to supply chain attacks if the AUR source is compromised.
**Prevention:** Never use `--skippgpcheck` in production build scripts. Pre-import required PGP keys for all AUR packages built from source to ensure non-interactive verification passes.
