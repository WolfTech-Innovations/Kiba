## 2025-05-29 - [Hardcoded Credentials in Build Scripts]
**Vulnerability:** A plain-text password was being passed to `chpasswd` in `build.sh` despite the same account already having a secure hashed password set in `/etc/shadow`.
**Learning:** Redundant credential setting often leads to insecure practices when one method is updated and the other is forgotten. The plain-text `chpasswd` call was a leftover that bypassed the security of the hashed password.
**Prevention:** Implement automated repository audits to detect the `echo "user:pass" | chpasswd` pattern and ensure all system accounts use hashed credentials from the start of the build process.
