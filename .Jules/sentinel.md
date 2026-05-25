# Sentinel Journal

## 2025-05-15 - [Secure SSH in CI/CD]
**Vulnerability:** Use of `sshpass -p` and `StrictHostKeyChecking=no` in deployment workflows.
**Learning:** `sshpass -p` exposes secrets in the process list, and disabling host key checking facilitates Man-in-the-Middle attacks.
**Prevention:** Use `sshpass -e` with the `SSHPASS` environment variable and use `ssh-keyscan` to populate `known_hosts` before connecting.
