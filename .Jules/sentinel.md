# Sentinel Journal

## 2025-06-07 - Enhanced Security Audit and Hardened Build Script
**Vulnerability:** Redundant plaintext password assignment in `build.sh` and bypass of package integrity checks via `--skippgpcheck`.
**Learning:** Even when secure hashing is implemented, legacy commands like `chpasswd` with plaintext input might remain, creating a small but unnecessary risk. Auditing tools themselves can trigger false positives if not carefully scoped.
**Prevention:** Always verify package integrity by allowing PGP checks in `makepkg`. Use secure hashing for all user credentials and avoid redundant plaintext password assignments. Ensure audit scripts exclude themselves and documentation from pattern-based security scans.
