## 2025-05-16 - [Insecure Remote Execution & Unhardened Downloads]
**Vulnerability:** The build script used the `curl | bash` anti-pattern for installing remote repositories and lacked protocol enforcement for asset downloads.
**Learning:** `curl | bash` bypasses integrity checks and executes arbitrary code. Unhardened `curl` calls can fallback to insecure protocols or fail silently, leading to compromised or incomplete builds.
**Prevention:** Replace `curl | bash` with manual GPG key validation and `signed-by` repository configuration. Enforce HTTPS and TLS 1.2 using `curl --proto '=https' --tlsv1.2 -Sf`.
