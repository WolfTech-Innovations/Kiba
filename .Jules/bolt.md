## 2025-05-15 - [YAML Validation Speed]

**Learning:** In repositories with a massive number of small YAML files (570+ workflows in this case), the pure-Python `yaml.safe_load` becomes a significant bottleneck. `yaml.CSafeLoader` is ~7x faster and drastically reduces execution time.
**Action:** Always prefer `CSafeLoader` with a fallback for YAML-heavy scripts in this environment.

## 2026-05-14 - [Semantic YAML Parsing for Performance]
**Learning:** While `awk` or `grep` can be extremely fast for simple text scanning, they are unreliable for structured formats like YAML where property order and context (comments, script blocks) matter. A single-process Python script with `yaml.CSafeLoader` provides the best balance of speed (~300x faster than `yq` loops) and semantic correctness.
**Action:** Replace shell-based loops calling CLI parsers (`yq`, `jq`) with single-execution Python scripts for bulk metadata validation.

## 2026-06-03 - [ISO Build Bottlenecks: Network & Image I/O]
**Learning:** KibaOS ISO builds are heavily gated by package download speeds and redundant image processing. Enabling `ParallelDownloads = 10` in `pacman.conf` provides a major speedup for the provisioning phase. Consolidating multiple ImageMagick calls into a single command using `-clone` and `-write` reduces process overhead and redundant disk reads of source assets.
**Action:** Ensure `ParallelDownloads` is enabled in all build-related `pacman.conf` files and use parenthetical grouping for bulk ImageMagick operations.
