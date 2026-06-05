## 2025-05-15 - [YAML Validation Speed]

**Learning:** In repositories with a massive number of small YAML files (570+ workflows in this case), the pure-Python `yaml.safe_load` becomes a significant bottleneck. `yaml.CSafeLoader` is ~7x faster and drastically reduces execution time.
**Action:** Always prefer `CSafeLoader` with a fallback for YAML-heavy scripts in this environment.

## 2026-05-14 - [Semantic YAML Parsing for Performance]
**Learning:** While `awk` or `grep` can be extremely fast for simple text scanning, they are unreliable for structured formats like YAML where property order and context (comments, script blocks) matter. A single-process Python script with `yaml.CSafeLoader` provides the best balance of speed (~300x faster than `yq` loops) and semantic correctness.
**Action:** Replace shell-based loops calling CLI parsers (`yq`, `jq`) with single-execution Python scripts for bulk metadata validation.

## 2026-06-04 - [ImageMagick Batch Processing]

**Learning:** Spawning multiple `magick` processes to generate different sizes of the same asset is inefficient due to repeated process startup, image decoding, and I/O. Using `-clone` and `-write` within a single `magick` execution allows processing the image once and outputting multiple versions, which is significantly faster in build environments.
**Action:** Consolidate multiple image transformations of the same source into a single ImageMagick command using parenthetical sub-commands and clones.
