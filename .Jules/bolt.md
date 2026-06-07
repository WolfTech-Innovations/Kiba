## 2025-05-15 - [YAML Validation Speed]

**Learning:** In repositories with a massive number of small YAML files (570+ workflows in this case), the pure-Python `yaml.safe_load` becomes a significant bottleneck. `yaml.CSafeLoader` is ~7x faster and drastically reduces execution time.
**Action:** Always prefer `CSafeLoader` with a fallback for YAML-heavy scripts in this environment.

## 2026-05-14 - [Semantic YAML Parsing for Performance]
**Learning:** While `awk` or `grep` can be extremely fast for simple text scanning, they are unreliable for structured formats like YAML where property order and context (comments, script blocks) matter. A single-process Python script with `yaml.CSafeLoader` provides the best balance of speed (~300x faster than `yq` loops) and semantic correctness.
**Action:** Replace shell-based loops calling CLI parsers (`yq`, `jq`) with single-execution Python scripts for bulk metadata validation.

## 2026-06-07 - [Optimizing Archiso Build Latency]
**Learning:** ISO build time is dominated by AUR package compilation and redundant database refreshes. In a multi-core environment (4+ cores), `makepkg` defaults to single-core, and `-Syy` forces unnecessary downloads. Intermediate packages do not need Zstd compression (`PKGEXT='.pkg.tar'`).
**Action:** Always inject `MAKEFLAGS="-j$(nproc)"` and `PKGEXT='.pkg.tar'` into `makepkg` calls for internal build stages. Prefer `pacman -Sy` over `-Syy` unless a full refresh is explicitly required for dependency resolution.
