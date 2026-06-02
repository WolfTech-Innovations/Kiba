# Sentinel Journal

## 2026-06-01 - [Hardcoded Plaintext Passwords in Build Scripts]
**Vulnerability:** Use of `echo "user:password" | chpasswd` in `build.sh` exposed the live user's default password in plaintext.
**Learning:** Hardcoded credentials in build scripts are easily leaked via logs or version control; redundant password settings can persist even after secure hashing is implemented elsewhere.
**Prevention:** Remove redundant plaintext password assignments and implement automated audit checks to flag `chpasswd` usage without the `-e` (encrypted) flag.
