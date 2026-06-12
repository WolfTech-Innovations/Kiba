## 2025-05-15 - [YAML Validation Speed]

**Learning:** In repositories with a massive number of small YAML files (570+ workflows in this case), the pure-Python `yaml.safe_load` becomes a significant bottleneck. `yaml.CSafeLoader` is ~7x faster and drastically reduces execution time.
**Action:** Always prefer `CSafeLoader` with a fallback for YAML-heavy scripts in this environment.

## 2026-05-14 - [Semantic YAML Parsing for Performance]
**Learning:** While `awk` or `grep` can be extremely fast for simple text scanning, they are unreliable for structured formats like YAML where property order and context (comments, script blocks) matter. A single-process Python script with `yaml.CSafeLoader` provides the best balance of speed (~300x faster than `yq` loops) and semantic correctness.
**Action:** Replace shell-based loops calling CLI parsers (`yq`, `jq`) with single-execution Python scripts for bulk metadata validation.

## 2024-05-20 - [Optimizing AUR builds in CI/CD]
**Learning:** AUR package builds via `makepkg` default to single-core compilation and heavy compression. In throwaway build environments (like `build.sh` inside a container or chroot), these defaults are major bottlenecks. Injecting `MAKEFLAGS="-j$(nproc)"` and `PKGEXT='.pkg.tar'` bypasses these inefficiencies.
**Action:** Always optimize source-based builds in the KibaOS build pipeline by enabling multi-core compilation and disabling redundant package compression.
