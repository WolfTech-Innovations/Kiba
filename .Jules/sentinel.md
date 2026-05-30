# Sentinel Journal

## 2025-05-30 - [Hardcoded Plaintext Passwords in Build Scripts]

**Vulnerability:** Use of `chpasswd` with plaintext passwords (e.g., `echo "user:password" | chpasswd`) in system build scripts.
**Learning:** Hardcoding plaintext passwords in scripts exposes credentials in the repository history and on the live system's build logs. Even for "live" users, using a pre-computed hash is more secure and follows best practices.
**Prevention:** Always use hashed passwords with `chpasswd -e` or pre-populate `/etc/shadow` with secure hashes. Implement automated repository audits to detect and block the introduction of plaintext `chpasswd` calls in the codebase.
