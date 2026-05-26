## 2025-05-15 - [YAML Validation Speed]

**Learning:** In repositories with a massive number of small YAML files (570+ workflows in this case), the pure-Python `yaml.safe_load` becomes a significant bottleneck. `yaml.CSafeLoader` is ~7x faster and drastically reduces execution time.
**Action:** Always prefer `CSafeLoader` with a fallback for YAML-heavy scripts in this environment.

## 2026-05-14 - [Semantic YAML Parsing for Performance]
**Learning:** While `awk` or `grep` can be extremely fast for simple text scanning, they are unreliable for structured formats like YAML where property order and context (comments, script blocks) matter. A single-process Python script with `yaml.CSafeLoader` provides the best balance of speed (~300x faster than `yq` loops) and semantic correctness.
**Action:** Replace shell-based loops calling CLI parsers (`yq`, `jq`) with single-execution Python scripts for bulk metadata validation.

## 2025-05-22 - [Robust Configuration Auditing and Multi-core Compilation]
**Learning:** When auditing configuration files with `grep`, anchoring patterns with `^` is critical to avoid false positives on commented-out lines (e.g., `#ParallelDownloads`). Additionally, `MAKEFLAGS` must be explicitly passed to `sudo makepkg` in chroot environments to ensure multi-core compilation is actually utilized by the build user.
**Action:** Use anchored regex for config checks and explicitly inject build environment variables into `sudo` commands for compilation.
