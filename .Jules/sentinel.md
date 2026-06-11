## 2025-06-11 - Salted Password Hashing in Build Scripts
**Vulnerability:** Plaintext default credentials in `build.sh`.
**Learning:** Default user passwords (e.g., `liveuser:live`) were set via `echo "user:pass" | chpasswd`, exposing credentials in source and potentially process logs.
**Prevention:** Use `openssl passwd -6` to generate salted SHA-512 hashes and apply them using `chpasswd -e` to ensure no plaintext secrets exist in the automation scripts.
