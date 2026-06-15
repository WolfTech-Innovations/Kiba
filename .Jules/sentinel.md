## 2026-06-15 - Secure Installation Defaults and Audit Robustness

**Vulnerability:** Use of insecure HTTP for Calamares connectivity checks (`internetCheckUrl`) and false positives in security audit scripts that hinder detection of real issues.
**Learning:** Default configurations in installer frameworks (like Calamares) often use insecure placeholders (e.g., `http://example.com`) which can be exploited via MitM to bypass connectivity checks or provide malicious feedback during installation. Additionally, security audit scripts that don't account for their own presence can create noise that leads to "security fatigue" or ignored failures.
**Prevention:** Always default to HTTPS for any external connectivity checks in build and installation scripts. Ensure audit scripts use targeted exclusions (like `--exclude` for self-referential matches) to maintain a high signal-to-noise ratio and ensure all flagged issues are actionable.
