# Sentinel Journal

## 2025-05-31 - [Avoid Redundant Plaintext chpasswd]

**Vulnerability:** Redundant `chpasswd` call with plaintext password in `build.sh`.
**Learning:** Even if a secure hash is already set in `/etc/shadow`, additional scripts (like `customize_airootfs.sh` embedded in `build.sh`) might contain legacy or redundant `chpasswd` calls that expose the same password in plaintext.
**Prevention:** Audit all build-time scripts for `chpasswd` usage. Ensure credentials are only managed via secure hashes in `/etc/shadow` or encrypted via `chpasswd -e`. Automated audits should flag `chpasswd` without the `-e` flag.
