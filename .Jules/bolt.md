## 2025-05-15 - [YAML Validation Speed]

**Learning:** In repositories with a massive number of small YAML files (570+ workflows in this case), the pure-Python `yaml.safe_load` becomes a significant bottleneck. `yaml.CSafeLoader` is ~7x faster and drastically reduces execution time.
**Action:** Always prefer `CSafeLoader` with a fallback for YAML-heavy scripts in this environment.

## 2026-05-14 - [Semantic YAML Parsing for Performance]
**Learning:** While `awk` or `grep` can be extremely fast for simple text scanning, they are unreliable for structured formats like YAML where property order and context (comments, script blocks) matter. A single-process Python script with `yaml.CSafeLoader` provides the best balance of speed (~300x faster than `yq` loops) and semantic correctness.
**Action:** Replace shell-based loops calling CLI parsers (`yq`, `jq`) with single-execution Python scripts for bulk metadata validation.

## 2026-05-15 - [Parallel Build Optimization]
**Learning:** Sequential package downloads and single-threaded compilation are massive bottlenecks in Archiso-based build pipelines. Enabling `ParallelDownloads` and exporting `MAKEFLAGS="-j$(nproc)"` to `makepkg` (ensuring it's passed through `sudo`) can reduce total build time by over 50% for complex ISOs containing heavy AUR packages like Calamares.
**Action:** Always verify that build scripts for Arch Linux ISOs explicitly enable parallelized pacman operations and multi-threaded compilation flags.
