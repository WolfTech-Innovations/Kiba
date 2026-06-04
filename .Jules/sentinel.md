# Sentinel Journal - Security Learnings

## 2026-06-04 - Secure Secret Injection in Build Scripts
**Vulnerability:** Plaintext password exposure in build-time heredocs (`liveuser:live`) and insecure HTTP connectivity checks (`http://example.com`).
**Learning:** Single-quoted heredocs in shell scripts are often used to avoid host-side expansion, but this can lead to hardcoding secrets. Using unique placeholders and `sed` for post-generation substitution allows injecting hashed secrets securely without compromising the heredoc's integrity.
**Prevention:** Enforce the use of `chpasswd -e` through automated repository audits and ensure all system-level connectivity checks utilize HTTPS.
