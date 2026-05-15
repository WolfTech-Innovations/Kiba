# Sentinel's Journal - Critical Security Learnings

## 2025-05-15 - GitHub Actions Command Injection via Context Variables
**Vulnerability:** Command injection in GitHub Action `run:` blocks.
**Learning:** Using `${{ github.event.pull_request.body }}` or `${{ github.event.pull_request.user.login }}` directly in shell scripts allows an attacker to execute arbitrary commands by crafting a malicious PR description or username.
**Prevention:** Always map untrusted GitHub context variables to environment variables before using them in shell scripts.

## 2025-05-15 - GitHub Actions Audit Failures and Shell Specification
**Vulnerability:** Missing explicit shell specifications and timeout-minutes in workflows.
**Learning:** Many automated audits in this repository require strict adherence to security and reliability standards, including explicit shells (`bash`) and timeouts for every job to prevent resource exhaustion and inconsistent behavior.
**Prevention:** Always include `timeout-minutes` for jobs and specify `shell: bash` (or similar) when needed by audits.
