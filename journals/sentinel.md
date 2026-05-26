# Sentinel Journal

## 2025-05-15 - [Strong Default Password Requirements]

**Vulnerability:** Weak default user passwords allowed during installation (minimum 6 characters).
**Learning:** Default settings in OS installers significantly impact the long-term security of the installed system, as users often stick to the minimum required complexity.
**Prevention:** Enforce a robust minimum password length (e.g., 12 characters) at the installer level to ensure all new installations meet modern security standards.

## 2025-05-15 - [Command Injection in GitHub Actions]

**Vulnerability:** Use of GitHub context variables (e.g., `${{ github.base_ref }}`) directly in `run` steps.
**Learning:** GitHub context variables can contain malicious shell characters or CLI flags if not properly sanitized or mapped to environment variables.
**Prevention:** Always map GitHub context variables to environment variables before using them in shell scripts within workflows. Use the `--` separator for CLI tools to prevent flag injection where applicable.

## 2024-05-26 - [Enforcing AUR Source Integrity]
**Vulnerability:** Use of `--skippgpcheck` in `makepkg` allowed building AUR packages without verifying upstream signatures.
**Learning:** Build scripts for custom ISOs often bypass signature checks to simplify dependency management, creating a supply chain risk.
**Prevention:** Remove insecure bypass flags and explicitly import required upstream PGP keys into the build environment to ensure source integrity without breaking automation.
