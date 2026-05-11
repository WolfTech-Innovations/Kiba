## 2025-05-15 - [YAML Validation Speed]

**Learning:** In repositories with a massive number of small YAML files (570+ workflows in this case), the pure-Python `yaml.safe_load` becomes a significant bottleneck. `yaml.CSafeLoader` is ~7x faster and drastically reduces execution time.
**Action:** Always prefer `CSafeLoader` with a fallback for YAML-heavy scripts in this environment.

## 2026-05-11 - [Build Optimization with eatmydata]
**Learning:** Using `eatmydata` during `lb build` significantly reduces disk I/O wait by skipping `fsync`, which is highly effective in containerized CI environments.
**Action:** Wrap long-running OS build commands with `eatmydata` and set `LC_CTYPE=C` to ensure tool compatibility and performance.
