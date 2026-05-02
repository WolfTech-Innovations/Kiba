## 2025-05-15 - [Build & Shell Optimization]
**Learning:** Integrating `eatmydata` in ISO build environments significantly reduces disk I/O wait by skipping `fsync`, while caching `compinit` dumps and avoiding redundant `vcs_info` calls when using Starship noticeably improves shell interactive responsiveness. Also, Bash heredocs must have delimiters at column 0 to close correctly.
**Action:** Always use `eatmydata` for heavy package installation tasks in build scripts, and audit `zshrc` for redundant prompt logic. Always verify heredoc indentation in Bash scripts.

## 2025-05-22 - [Zsh Startup Optimization]
**Learning:** In Zsh, using native glob qualifiers like `(mh-24)` within a local array expansion is significantly faster than forking a `find` process for cache validation. However, these globs do not expand inside `[[ ... ]]` test blocks, so the array length check is the correct pattern. Also, pre-compiling `zshrc` into wordcode via `zcompile` reduces parsing overhead during shell initialization.
**Action:** Use native Zsh globbing for file attribute checks in shell configurations to avoid process forks. Always wrap `zcompile` in checks for file existence and handle errors gracefully in build scripts.
