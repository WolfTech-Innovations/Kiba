# Sentinel Journal

This journal tracks critical security learnings for the KibaOS project.

## 2025-06-10 - [Harden password handling in build scripts]
**Vulnerability:** Use of `echo "user:pass" | chpasswd` exposes passwords in plaintext within build scripts and potentially shell history/logs.
**Learning:** Using `chpasswd -e` with pre-computed hashes (e.g., SHA-512 via `openssl passwd -6`) ensures that sensitive credentials are never stored or transmitted in plaintext.
**Prevention:** Implement automated repository audits to flag `chpasswd` usage that lacks the `-e` (encrypted) flag.
