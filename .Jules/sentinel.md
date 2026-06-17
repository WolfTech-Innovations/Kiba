## 2025-05-14 - Host Contamination Risk via Undefined Variables
**Vulnerability:** In `build.sh`, the variable `AIROOTFS` was used in `grep` and `echo` commands before it was defined. This can lead to commands like `echo '...' >> /etc/passwd` being executed on the host system if the script is run as root and the variable is empty.
**Learning:** Shell scripts running with elevated privileges are extremely sensitive to variable ordering. Using a variable before its definition defaults it to an empty string, which can pivot targeted paths to root-level system files.
**Prevention:** Always define all path and directory variables at the very top of the script, before any functional logic or side-effect-producing commands are executed.
