## 2025-05-15 - [YAML Validation Speed]

**Learning:** In repositories with a massive number of small YAML files (570+ workflows in this case), the pure-Python `yaml.safe_load` becomes a significant bottleneck. `yaml.CSafeLoader` is ~7x faster and drastically reduces execution time.
**Action:** Always prefer `CSafeLoader` with a fallback for YAML-heavy scripts in this environment.

## 2026-05-14 - [Semantic YAML Parsing for Performance]
**Learning:** While `awk` or `grep` can be extremely fast for simple text scanning, they are unreliable for structured formats like YAML where property order and context (comments, script blocks) matter. A single-process Python script with `yaml.CSafeLoader` provides the best balance of speed (~300x faster than `yq` loops) and semantic correctness.
**Action:** Replace shell-based loops calling CLI parsers (`yq`, `jq`) with single-execution Python scripts for bulk metadata validation.

## 2026-06-01 - [Consolidated Recursive Ownership Operations]
**Learning:** Performing redundant recursive `chown` and `chmod` operations on large directories like `/home/liveuser` during a build process significantly increases disk I/O and build time. These operations should be consolidated to a single execution after all files have been copied to the target directory.
**Action:** Identify and remove redundant `chown -R` and `chmod -R` calls in build scripts, ensuring a single final application before user-level tasks.
