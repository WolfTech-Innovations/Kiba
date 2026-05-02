## 2025-05-15 - [Build & Shell Optimization]

**Learning:** Integrating `eatmydata` in ISO build environments significantly reduces disk I/O wait by skipping `fsync`, while caching `compinit` dumps and avoiding redundant `vcs_info` calls when using Starship noticeably improves shell interactive responsiveness. Also, Bash heredocs must have delimiters at column 0 to close correctly.
**Action:** Always use `eatmydata` for heavy package installation tasks in build scripts, and audit `zshrc` for redundant prompt logic. Always verify heredoc indentation in Bash scripts.

## 2025-05-22 - [Zsh Startup Optimization]
**Learning:** In Zsh, using native glob qualifiers like `(mh-24)` within a local array expansion is significantly faster than forking a `find` process for cache validation. Note that these globs must be unquoted to expand correctly.
**Action:** Use native Zsh globbing for file attribute checks in shell configurations to avoid process forks. Ensure qualifiers are applied to unquoted variables/strings.
