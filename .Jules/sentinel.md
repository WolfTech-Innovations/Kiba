## 2025-05-14 - [Command Injection in GitHub Actions]

**Vulnerability:** Direct expansion of untrusted GitHub context variables (e.g., `github.event.pull_request.body`, `github.head_ref`, `github.event.pull_request.user.login`) in `run` steps.
**Learning:** Untrusted input from pull requests can contain shell-metacharacters that execute arbitrary commands when expanded directly into a shell script.
**Prevention:** Always map untrusted GitHub context variables to environment variables and reference the environment variables in the `run` script.
