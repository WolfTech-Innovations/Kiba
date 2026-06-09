## 2025-06-09 - [Plaintext Passwords in Build Scripts]
**Vulnerability:** The live user's password was exposed in plaintext within a heredoc in `build.sh`.
**Learning:** Hardcoding passwords in scripts, even for live environments, creates a security risk where the password can be easily extracted from the source or build logs. Quoted heredocs prevent variable expansion, which led to the use of plaintext strings.
**Prevention:** Use placeholder injection with `sed` to pass securely generated hashes from the main script into embedded scripts/heredocs. Always use `chpasswd -e` with pre-computed hashes.
