## 2025-05-15 - [YAML Validation Speed]

**Learning:** In repositories with a massive number of small YAML files (570+ workflows in this case), the pure-Python `yaml.safe_load` becomes a significant bottleneck. `yaml.CSafeLoader` is ~7x faster and drastically reduces execution time.
**Action:** Always prefer `CSafeLoader` with a fallback for YAML-heavy scripts in this environment.

## 2026-05-14 - [Semantic YAML Parsing for Performance]
**Learning:** While `awk` or `grep` can be extremely fast for simple text scanning, they are unreliable for structured formats like YAML where property order and context (comments, script blocks) matter. A single-process Python script with `yaml.CSafeLoader` provides the best balance of speed (~300x faster than `yq` loops) and semantic correctness.
**Action:** Replace shell-based loops calling CLI parsers (`yq`, `jq`) with single-execution Python scripts for bulk metadata validation.

## 2025-05-30 - [ImageMagick & Build Speed]
**Learning:** Consolidating multiple `magick` operations into a single command with `-clone` and `-write` significantly reduces build-time overhead by avoiding redundant image decoding and filesystem IO. Enabling `ParallelDownloads` in `pacman.conf` for both the host and the chroot environment is essential for minimizing network bottlenecks during ISO generation.
**Action:** Always prefer single-pass ImageMagick commands for batch processing and ensure `ParallelDownloads` is explicitly enabled in all `pacman.conf` variants in the build pipeline.
