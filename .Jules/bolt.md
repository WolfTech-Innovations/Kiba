## 2025-05-15 - [YAML Validation Speed]

**Learning:** In repositories with a massive number of small YAML files (570+ workflows in this case), the pure-Python `yaml.safe_load` becomes a significant bottleneck. `yaml.CSafeLoader` is ~7x faster and drastically reduces execution time.
**Action:** Always prefer `CSafeLoader` with a fallback for YAML-heavy scripts in this environment.

## 2026-05-14 - [Semantic YAML Parsing for Performance]
**Learning:** While `awk` or `grep` can be extremely fast for simple text scanning, they are unreliable for structured formats like YAML where property order and context (comments, script blocks) matter. A single-process Python script with `yaml.CSafeLoader` provides the best balance of speed (~300x faster than `yq` loops) and semantic correctness.
**Action:** Replace shell-based loops calling CLI parsers (`yq`, `jq`) with single-execution Python scripts for bulk metadata validation.

## 2025-06-13 - [Arch ISO Build Bottlenecks]
**Learning:** AUR package builds during ISO creation are often a major bottleneck due to single-core compilation and redundant package compression (zstd/xz) for packages that are immediately installed and discarded.
**Action:** Inject `MAKEFLAGS="-j$(nproc)"` for parallel compilation and `PKGEXT='.pkg.tar'` to skip compression when building AUR packages in a transient build environment. Also, ensure `ParallelDownloads` is enabled in both host and chroot `pacman.conf`.
