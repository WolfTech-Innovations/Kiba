# Bolt.md

## 2025-05-15 - [Build & Shell Optimization]

**Learning:** Integrating `eatmydata` in ISO build environments significantly reduces disk I/O wait by skipping `fsync`, while caching `compinit` dumps and avoiding redundant `vcs_info` calls when using Starship noticeably improves shell interactive responsiveness. Also, Bash heredocs must have delimiters at column 0 to close correctly.
**Action:** Always use `eatmydata` for heavy package installation tasks in build scripts, and audit `zshrc` for redundant prompt logic. Always verify heredoc indentation in Bash scripts.

## 2025-05-16 - [YAML Parsing Optimization]

**Learning:** When dealing with hundreds of YAML files (like 570+ workflows), switching from `yaml.safe_load` (pure Python) to `yaml.load(stream, Loader=yaml.CSafeLoader)` (C-based) significantly reduces execution time (from ~1.6s to ~0.9s in this environment). A fallback to `SafeLoader` ensures portability across environments without C bindings.
**Action:** Use `CSafeLoader` for bulk YAML processing tasks to improve CI script performance.
