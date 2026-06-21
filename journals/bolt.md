# Bolt Journal

## 2025-05-15 - [Build & Shell Optimization]

**Learning:** Integrating `eatmydata` in ISO build environments significantly reduces disk I/O wait by skipping `fsync`, while caching `compinit` dumps and avoiding redundant `vcs_info` calls when using Starship noticeably improves shell interactive responsiveness. Also, Bash heredocs must have delimiters at column 0 to close correctly.
**Action:** Always use `eatmydata` for heavy package installation tasks in build scripts, and audit `zshrc` for redundant prompt logic. Always verify heredoc indentation in Bash scripts.

## 2026-06-21 - [Save Release Notes Optimization]
**Learning:** Replacing external command pipes (`date`, `echo`, `cut`, `sed`) with Bash built-ins like `printf -v %(...)T` and parameter expansion significantly reduces process overhead in scripts called by CI.
**Action:** Prioritize Bash built-ins for string manipulation and date formatting in performance-sensitive scripts.
