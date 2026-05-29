# Bolt Journal

## 2025-05-15 - [Build & Shell Optimization]

**Learning:** Integrating `eatmydata` in ISO build environments significantly reduces disk I/O wait by skipping `fsync`, while caching `compinit` dumps and avoiding redundant `vcs_info` calls when using Starship noticeably improves shell interactive responsiveness. Also, Bash heredocs must have delimiters at column 0 to close correctly.
**Action:** Always use `eatmydata` for heavy package installation tasks in build scripts, and audit `zshrc` for redundant prompt logic. Always verify heredoc indentation in Bash scripts.

## 2026-05-29 - [ImageMagick Multi-Output Optimization]
**Learning:** Sequential calls to ImageMagick for resizing the same source into multiple dimensions are inefficient as they re-decode the source each time. Consolidating into a single command with `-write` outputs all sizes in one pass, significantly reducing CPU and IO overhead.
**Action:** Always prefer consolidated `magick` commands for multi-thumb generation in build scripts.
