## 2025-05-15 - [YAML Validation Speed]

**Learning:** In repositories with a massive number of small YAML files (570+ workflows in this case), the pure-Python `yaml.safe_load` becomes a significant bottleneck. `yaml.CSafeLoader` is ~7x faster and drastically reduces execution time.
**Action:** Always prefer `CSafeLoader` with a fallback for YAML-heavy scripts in this environment.

## 2026-05-14 - [Semantic YAML Parsing for Performance]
**Learning:** While `awk` or `grep` can be extremely fast for simple text scanning, they are unreliable for structured formats like YAML where property order and context (comments, script blocks) matter. A single-process Python script with `yaml.CSafeLoader` provides the best balance of speed (~300x faster than `yq` loops) and semantic correctness.
**Action:** Replace shell-based loops calling CLI parsers (`yq`, `jq`) with single-execution Python scripts for bulk metadata validation.

## 2025-05-16 - [ISO Build Optimization]
**Learning:** In ISO build environments (archiso), default `makepkg` settings use single-core compilation and high-compression `zstd` for packages. Since built AUR packages are immediately installed and then squashed into the final image, `zstd` compression is redundant and extremely slow.
**Action:** Always set `MAKEFLAGS="-j$(nproc)"` and `PKGEXT='.pkg.tar'` for AUR builds in `build.sh` to leverage multi-core speed and bypass compression latency.
