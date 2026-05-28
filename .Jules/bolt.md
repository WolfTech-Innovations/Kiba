## 2025-05-15 - [YAML Validation Speed]

**Learning:** In repositories with a massive number of small YAML files (570+ workflows in this case), the pure-Python `yaml.safe_load` becomes a significant bottleneck. `yaml.CSafeLoader` is ~7x faster and drastically reduces execution time.
**Action:** Always prefer `CSafeLoader` with a fallback for YAML-heavy scripts in this environment.

## 2026-05-14 - [Semantic YAML Parsing for Performance]
**Learning:** While `awk` or `grep` can be extremely fast for simple text scanning, they are unreliable for structured formats like YAML where property order and context (comments, script blocks) matter. A single-process Python script with `yaml.CSafeLoader` provides the best balance of speed (~300x faster than `yq` loops) and semantic correctness.
**Action:** Replace shell-based loops calling CLI parsers (`yq`, `jq`) with single-execution Python scripts for bulk metadata validation.

## 2026-05-28 - [ISO Build Pipeline Optimizations]
**Learning:** Significant build time reductions in Arch Linux-based ISO creation are achieved by enabling `ParallelDownloads` across all environments (host, profile, and chroot) and utilizing `MAKEFLAGS="-j$(nproc)"` for source builds. Consolidating ImageMagick operations using `\( ... -write ... \)` also reduces I/O and CPU overhead by avoiding redundant image decoding.
**Action:** Always verify that parallelization is enabled for both package management and compilation in build scripts. Refactor sequential image processing into single-pass commands.
