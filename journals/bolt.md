# Bolt Journal

## 2025-05-15 - [Build & Shell Optimization]

**Learning:** Integrating `eatmydata` in ISO build environments significantly reduces disk I/O wait by skipping `fsync`, while caching `compinit` dumps and avoiding redundant `vcs_info` calls when using Starship noticeably improves shell interactive responsiveness. Also, Bash heredocs must have delimiters at column 0 to close correctly.
**Action:** Always use `eatmydata` for heavy package installation tasks in build scripts, and audit `zshrc` for redundant prompt logic. Always verify heredoc indentation in Bash scripts.

## 2026-06-21 - [Shell Loop & Batching Optimization]
**Learning:** Process forks in shell loops (e.g., `awk`, `sed`, `sha256sum`) are a major performance killer, especially on low-power devices. `sha256sum --check` is significantly more efficient than per-file verification. Additionally, Bash built-ins like `read` and parameter expansion provide substantial speedups and better handle edge cases like filenames with spaces compared to `awk` pipelines.
**Action:** Always prefer `sha256sum --check` for manifest verification and Bash built-ins for string parsing in loops to minimize process overhead.
