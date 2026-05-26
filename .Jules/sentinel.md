## 2025-05-15 - Insecure SSH credentials in build workflow
**Vulnerability:** The `kiba.yml` workflow was using `sshpass -p "$SF_PASS"` and `StrictHostKeyChecking=no`.
**Learning:** Hardcoding passwords in command lines, even via variables, can expose them in process lists. Disabling host key verification invites MITM attacks.
**Prevention:** Use `sshpass -e` with the `SSHPASS` environment variable and use `ssh-keyscan` to populate `known_hosts` instead of disabling verification.
