## 2026-06-04 - Harden chpasswd and automated audit
**Vulnerability:** Plaintext password setting using `chpasswd` in `build.sh` within the `customize_airootfs.sh` heredoc.
**Learning:** Even when hashes are used elsewhere (like in `/etc/shadow` generation), internal scripts might still use insecure convenience methods like `echo "user:pass" | chpasswd`.
**Prevention:** Always use `chpasswd -e` with pre-hashed strings in build scripts and maintain an automated audit check in `scripts/repo_audit.sh` to catch regressions.
