# Sentinel Security Journal

## 2026-06-03 - Initializing Sentinel Journal

**Vulnerability:** N/A
**Learning:** Initializing the security journal to track critical security learnings for KibaOS.
**Prevention:** N/A

## 2026-06-03 - Hardening liveuser password setting
**Vulnerability:** Plaintext password exposure in build scripts.
**Learning:** The liveuser password was being set using `echo "liveuser:live" | chpasswd` which exposes the plaintext password in the source code and potentially in process lists during the build.
**Prevention:** Use `chpasswd -e` with a pre-hashed password and implement automated audit checks to detect plaintext `chpasswd` usage.
