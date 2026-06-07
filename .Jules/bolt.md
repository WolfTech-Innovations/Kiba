## 2025-05-15 - [YAML Validation Speed]

**Learning:** In repositories with a massive number of small YAML files (570+ workflows in this case), the pure-Python `yaml.safe_load` becomes a significant bottleneck. `yaml.CSafeLoader` is ~7x faster and drastically reduces execution time.
**Action:** Always prefer `CSafeLoader` with a fallback for YAML-heavy scripts in this environment.

## 2026-05-14 - [Semantic YAML Parsing for Performance]
**Learning:** While `awk` or `grep` can be extremely fast for simple text scanning, they are unreliable for structured formats like YAML where property order and context (comments, script blocks) matter. A single-process Python script with `yaml.CSafeLoader` provides the best balance of speed (~300x faster than `yq` loops) and semantic correctness.
**Action:** Replace shell-based loops calling CLI parsers (`yq`, `jq`) with single-execution Python scripts for bulk metadata validation.

## 2027-04-18 - [Parallelism in Build Environments]
**Learning:** Build environments like Archiso's `customize_airootfs.sh` often default to conservative serial processing. Injected environment variables like `MAKEFLAGS` and `PKGEXT` can unlock massive performance gains in multi-core CI environments without requiring permanent configuration changes to the underlying OS image. Skipping package compression (`PKGEXT='.pkg.tar'`) is a massive time-saver for intermediate build steps.
**Action:** Always check for `makepkg` or `make` calls in build scripts and inject parallelism where possible.
