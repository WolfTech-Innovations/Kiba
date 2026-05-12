## 2025-05-15 - [YAML Validation Speed]

**Learning:** In repositories with a massive number of small YAML files (570+ workflows in this case), the pure-Python `yaml.safe_load` becomes a significant bottleneck. `yaml.CSafeLoader` is ~7x faster and drastically reduces execution time.
**Action:** Always prefer `CSafeLoader` with a fallback for YAML-heavy scripts in this environment.

## 2025-05-15 - [Robust CI Audit Optimization]
**Learning:** Replacing `yq` loops with `awk` for speed can introduce regressions if the regex doesn't account for all valid characters (like hyphens in kebab-case). A single-pass Python script with `CSafeLoader` provides the same speed boost (~500x) while maintaining full YAML parsing correctness.
**Action:** Use embedded Python with `yaml.CSafeLoader` for high-performance, complex audits of structured data like YAML or JSON.
