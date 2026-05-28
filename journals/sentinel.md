# Sentinel Journal

## 2025-05-15 - [Strong Default Password Requirements]

**Vulnerability:** Weak default user passwords allowed during installation (minimum 6 characters).
**Learning:** Default settings in OS installers significantly impact the long-term security of the installed system, as users often stick to the minimum required complexity.
**Prevention:** Enforce a robust minimum password length (e.g., 12 characters) at the installer level to ensure all new installations meet modern security standards.

## 2025-05-15 - [Command Injection in GitHub Actions]

**Vulnerability:** Use of GitHub context variables (e.g., `${{ github.base_ref }}`) directly in `run` steps.
**Learning:** GitHub context variables can contain malicious shell characters or CLI flags if not properly sanitized or mapped to environment variables.
**Prevention:** Always map GitHub context variables to environment variables before using them in shell scripts within workflows. Use the `--` separator for CLI tools to prevent flag injection where applicable.

## 2025-05-15 - [AUR Source Integrity Verification]

**Vulnerability:** Skipping PGP signature verification (`--skippgpcheck`) during AUR package builds.
**Learning:** Build scripts often skip verification to simplify the CI/CD pipeline, but this introduces a supply chain risk where compromised sources can be injected into the ISO.
**Prevention:** Mandatory enforcement of PGP signature verification for all AUR packages. Require explicit PGP key imports in the build environment to maintain a trusted root of trust for third-party software.
