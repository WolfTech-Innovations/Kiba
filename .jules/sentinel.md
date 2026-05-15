## 2025-05-22 - Prevent Command Injection in GitHub Action Workflows
**Vulnerability:** Command injection via direct expansion of GitHub context variables (e.g., `github.head_ref`, `github.base_ref`) in `run` blocks.
**Learning:** GitHub Actions substitutes context variables into the script BEFORE execution. If an attacker can control the value (like a branch name or PR title), they can execute arbitrary shell commands on the runner.
**Prevention:** Always map potentially untrusted GitHub context variables to environment variables and reference them as shell variables (e.g., `$HEAD_REF`) in the `run` block.
