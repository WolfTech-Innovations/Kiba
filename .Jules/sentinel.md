## 2025-06-08 - Harden password handling and audit enhancements
**Vulnerability:** Hardcoded plaintext password in build script and missing audit checks for insecure password handling.
**Learning:** Hardcoded credentials in build scripts can persist in the final image and are easily discoverable. Even if a password is set securely via a hash earlier, redundant insecure calls like `chpasswd` can re-expose the system.
**Prevention:** Remove hardcoded passwords and use secure hashing. Implement automated audit checks in `repo_audit.sh` to detect insecure `chpasswd` usage and dangerous `chmod` settings while avoiding false positives.
