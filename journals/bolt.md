\n## 2025-05-15 - [Build & Shell Optimization]
**Learning:** Integrating `eatmydata` in ISO build environments significantly reduces disk I/O wait by skipping `fsync`, while caching `compinit` dumps and avoiding redundant `vcs_info` calls when using Starship noticeably improves shell interactive responsiveness. Also, Bash heredocs must have delimiters at column 0 to close correctly.
**Action:** Always use `eatmydata` for heavy package installation tasks in build scripts, and audit `zshrc` for redundant prompt logic. Always verify heredoc indentation in Bash scripts.

## 2025-05-22 - [Zsh Cache Logic Error]
**Learning:** When checking for cached files using Zsh glob qualifiers (e.g., `(mh-24)`), a non-zero array length indicates the cache is VALID (file is young enough). Using `-eq 0` would mistakenly bypass the cache when it's most needed.
**Action:** Always use `${#matches} -gt 0` to confirm a file meets the age/existence criteria in Zsh glob-based cache checks.
