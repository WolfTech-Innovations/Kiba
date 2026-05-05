## 2025-05-15 - [Build Script Optimization & Mktemp Anti-pattern]
**Learning:** Redundant `$(mktemp -d)` calls in shell script hooks created an anti-pattern that was both inefficient and logic-breaking. Each call generated a new directory, causing assets to be cloned into one location and searched for in another (empty) one. Additionally, the ISO build process is heavily I/O bound.
**Action:** Always assign `mktemp -d` to a variable at the start of a block for consistent access. Use `eatmydata` to wrap `lb build` and `apt` operations in disposable build environments to significantly reduce disk I/O wait times.

## 2025-05-22 - [Optimized ISO Build Chain]
**Learning:** The `zstd` compression level 19 in `mksquashfs` is a massive time-sink for negligible size gains compared to level 15. Also, `eatmydata` must be explicitly used within `su -c` strings to affect subprocesses.
**Action:** Default to `zstd -Xcompression-level 15` for squashfs. Ensure `eatmydata` is installed early and used inside shell escape contexts like `su -c`.
