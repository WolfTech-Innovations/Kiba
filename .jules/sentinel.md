# Sentinel Security Journal 🛡️

## 2026-05-15 - Command Injection in Workflow Context Variables
**Vulnerability:** GitHub context variables like `github.event.pull_request.body` and `github.event.pull_request.user.login` were directly expanded in `run:` blocks, allowing for command injection via malicious PR descriptions or usernames.
**Learning:** Even internal-only scripts or CI workflows are susceptible if they process untrusted input from the GitHub event context.
**Prevention:** Always map untrusted context variables to environment variables and use them via shell variable expansion (e.g., `"$PR_BODY"`) instead of direct expression expansion.

## 2026-05-15 - CI Audit Resilience and Hardening
**Vulnerability:** Massive CI audit failure due to legacy branding, non-standard headings, and malformed heredocs in build scripts.
**Learning:** Large-scale repository automation can be fragile. Hardening the build script (`kiba.yml`) to use quoted heredoc terminators and zero indentation for embedded scripts prevents parsing errors and improves security.
**Prevention:** Enforce quoted heredocs (`<< 'EOF'`) and strict indentation in automated build workflows to pass rigorous linting.
