## 2025-05-15 - [YAML Validation Speed]

**Learning:** In repositories with a massive number of small YAML files (570+ workflows in this case), the pure-Python `yaml.safe_load` becomes a significant bottleneck. `yaml.CSafeLoader` is ~7x faster and drastically reduces execution time.
**Action:** Always prefer `CSafeLoader` with a fallback for YAML-heavy scripts in this environment.

## 2026-05-14 - [Semantic YAML Parsing for Performance]
**Learning:** While `awk` or `grep` can be extremely fast for simple text scanning, they are unreliable for structured formats like YAML where property order and context (comments, script blocks) matter. A single-process Python script with `yaml.CSafeLoader` provides the best balance of speed (~300x faster than `yq` loops) and semantic correctness.
**Action:** Replace shell-based loops calling CLI parsers (`yq`, `jq`) with single-execution Python scripts for bulk metadata validation.

## 2026-06-02 - [Consolidating Recursive Filesystem Ops]
**Learning:** In ISO build scripts (like `build.sh`), redundant recursive `chown` and `chmod` operations on the same directory tree (e.g., `/home/liveuser`) create significant disk I/O bottlenecks. Consolidating these into a single pass at the end of the filesystem preparation phase provides a measurable efficiency gain.
**Action:** Audit build scripts for redundant recursive filesystem traversals and consolidate them before finalization or user-context operations.
