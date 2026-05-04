## 2025-05-15 - Enforcing GPG Verification for External Repositories
**Vulnerability:** Use of `trusted=yes` in APT repository configuration.
**Learning:** The `trusted=yes` flag instructs APT to skip GPG signature verification for a repository. While often used as a "quick fix" for certificate errors, it exposes the build process to Man-in-the-Middle (MITM) attacks where malicious packages can be injected.
**Prevention:** Always use the `signed-by` attribute pointing to a valid keyring file to ensure package integrity without bypassing security checks.
