## 2025-05-15 - [Build Script Optimization & Mktemp Anti-pattern]

**Learning:** Redundant `$(mktemp -d)` calls in shell script hooks created an anti-pattern that was both inefficient and logic-breaking. Each call generated a new directory, causing assets to be cloned into one location and searched for in another (empty) one. Additionally, the ISO build process is heavily I/O bound.
**Action:** Always assign `mktemp -d` to a variable at the start of a block for consistent access. Use `eatmydata` to wrap `lb build` and `apt` operations in disposable build environments to significantly reduce disk I/O wait times.

## 2025-05-16 - [Squashfs Compression Optimization]

**Learning:** Using `zstd` compression level 19 in `mksquashfs` for the rootfs provides negligible size benefits compared to level 15 but significantly increases build time and CPU usage, acting as a major bottleneck in the ISO creation pipeline.
**Action:** Default to `zstd` compression level 15 for `mksquashfs` in build scripts to optimize for build speed without sacrificing significant disk space.
