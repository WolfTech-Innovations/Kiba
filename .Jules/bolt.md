## 2025-05-15 - [YAML Validation Speed]

**Learning:** In repositories with a massive number of small YAML files (570+ workflows in this case), the pure-Python `yaml.safe_load` becomes a significant bottleneck. `yaml.CSafeLoader` is ~7x faster and drastically reduces execution time.
**Action:** Always prefer `CSafeLoader` with a fallback for YAML-heavy scripts in this environment.

## 2025-05-15 - [GitHub Actions Workflow Audit Performance]
**Learning:** Iterating over a large number of workflow files (580+) in a shell loop and calling `yq` for each file is extremely inefficient due to process spawning overhead, taking ~95-100s. A single-pass `awk` or `grep` command can perform the same structured scan in < 0.1s.
**Action:** Replace shell loops that call external YAML parsers per file with single-pass `awk`, `grep`, or optimized Python scripts (using `CSafeLoader`) when auditing the entire `.github/workflows/` directory.
