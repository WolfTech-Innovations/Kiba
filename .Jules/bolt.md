## 2025-05-15 - [YAML Validation Speed]

**Learning:** In repositories with a massive number of small YAML files (570+ workflows in this case), the pure-Python `yaml.safe_load` becomes a significant bottleneck. `yaml.CSafeLoader` is ~7x faster and drastically reduces execution time.
**Action:** Always prefer `CSafeLoader` with a fallback for YAML-heavy scripts in this environment.

## 2026-05-14 - [Semantic YAML Parsing for Performance]
**Learning:** While `awk` or `grep` can be extremely fast for simple text scanning, they are unreliable for structured formats like YAML where property order and context (comments, script blocks) matter. A single-process Python script with `yaml.CSafeLoader` provides the best balance of speed (~300x faster than `yq` loops) and semantic correctness.
**Action:** Replace shell-based loops calling CLI parsers (`yq`, `jq`) with single-execution Python scripts for bulk metadata validation.

## 2025-05-16 - [Consolidated Image Processing]
**Learning:** ImageMagick 7 can perform multiple resize operations in a single process using `\( -clone 0 ... -write ... \)`. This avoids the overhead of multiple process startups and redundant decoding of the source image, which is especially valuable in resource-constrained build environments.
**Action:** Use single-process `magick` calls with clones and writes for all bulk image transformation tasks.

## 2025-05-16 - [Redundant I/O in Build Scripts]
**Learning:** Repeated recursive `chown` and `chmod` operations on large directories (like `/home/liveuser`) trigger massive amounts of redundant file system I/O. These operations are often hidden performance killers in long-running build scripts.
**Action:** Ensure ownership and permissions are set exactly once after all files have been copied to the target directory.
