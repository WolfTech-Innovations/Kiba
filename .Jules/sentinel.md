
## 2025-05-15 - [Credential Hardening in Single-Quoted Heredocs]
**Vulnerability:** Hardcoded plaintext passwords in shell scripts, specifically within single-quoted heredocs where host-side variable expansion is disabled.
**Learning:** Single-quoted heredocs (`'EOF'`) prevent `bash` from expanding variables like `${LIVE_HASH}` at write-time. To inject secrets without exposing them in plaintext or breaking the heredoc, use a unique placeholder (e.g., `__LIVE_HASH__`) and perform a post-write substitution using `sed`.
**Prevention:** Always use `chpasswd -e` with pre-calculated hashes. For complex script generation, use placeholders and `sed` to inject sensitive values from environment variables instead of hardcoding them.
