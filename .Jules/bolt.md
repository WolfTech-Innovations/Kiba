## 2025-05-15 - [YAML Validation Speed]

**Learning:** In repositories with a massive number of small YAML files (570+ workflows in this case), the pure-Python `yaml.safe_load` becomes a significant bottleneck. `yaml.CSafeLoader` is ~7x faster and drastically reduces execution time.
**Action:** Always prefer `CSafeLoader` with a fallback for YAML-heavy scripts in this environment.

## 2026-05-10 - [Shell Script Optimization]

**Learning:** Repetitive process spawning (like calling `date` or `cut` multiple times) in shell scripts adds significant overhead. Consolidating these into a single call and using Bash internal parameter expansion is much more efficient.
**Action:** Use `read` with a single `date` call and Bash string slicing `${var:start:len}` for high-performance scripting.
