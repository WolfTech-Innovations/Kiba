## 2025-05-15 - [YAML Validation Speed]

**Learning:** In repositories with a massive number of small YAML files (570+ workflows in this case), the pure-Python `yaml.safe_load` becomes a significant bottleneck. `yaml.CSafeLoader` is ~7x faster and drastically reduces execution time.
**Action:** Always prefer `CSafeLoader` with a fallback for YAML-heavy scripts in this environment.

## 2026-05-14 - [Semantic YAML Parsing for Performance]
**Learning:** While `awk` or `grep` can be extremely fast for simple text scanning, they are unreliable for structured formats like YAML where property order and context (comments, script blocks) matter. A single-process Python script with `yaml.CSafeLoader` provides the best balance of speed (~300x faster than `yq` loops) and semantic correctness.
**Action:** Replace shell-based loops calling CLI parsers (`yq`, `jq`) with single-execution Python scripts for bulk metadata validation.

## 2026-06-05 - [Audit Performance and Hygiene]
**Learning:** Recursive text searches (like `grep` in `repo_audit.sh`) are extremely slow and prone to false positives when they traverse `node_modules`. Excluding dependency directories is essential for audit performance and correctness.
**Action:** Always include `--exclude-dir=node_modules` in repository-wide search commands.

## 2026-06-05 - [Build Performance: Makepkg Tuning]
**Learning:** For ISO builds where AUR packages are intermediate artifacts, the default `makepkg` compression (`zstd`) and single-threaded compilation are massive bottlenecks. Parallelizing compilation and disabling compression can reduce build time by over 50%.
**Action:** Inject `MAKEFLAGS="-j$(nproc)"` and `PKGEXT='.pkg.tar'` into `/etc/makepkg.conf` in the build environment.
