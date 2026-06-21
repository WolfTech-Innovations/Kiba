## 2025-05-15 - [YAML Validation Speed]

**Learning:** In repositories with a massive number of small YAML files (570+ workflows in this case), the pure-Python `yaml.safe_load` becomes a significant bottleneck. `yaml.CSafeLoader` is ~7x faster and drastically reduces execution time.
**Action:** Always prefer `CSafeLoader` with a fallback for YAML-heavy scripts in this environment.

## 2026-05-14 - [Semantic YAML Parsing for Performance]
**Learning:** While `awk` or `grep` can be extremely fast for simple text scanning, they are unreliable for structured formats like YAML where property order and context (comments, script blocks) matter. A single-process Python script with `yaml.CSafeLoader` provides the best balance of speed (~300x faster than `yq` loops) and semantic correctness.
**Action:** Replace shell-based loops calling CLI parsers (`yq`, `jq`) with single-execution Python scripts for bulk metadata validation.

## 2025-06-15 - Kernel Build Performance with CachyOS
**Learning:** Migrating to CachyOS kernel requires proper repository configuration at the host level in the build script to avoid 'package not found' errors during mkarchiso execution.
**Action:** Ensure custom repositories are added to both /etc/pacman.conf and the profile's pacman.conf before building the ISO.

## 2026-05-21 - [Shell Subprocess Overhead in Naming Logic]
**Learning:** Shell scripts that perform string manipulation or date formatting using external processes like `date`, `cut`, and `sed` suffer from significant subprocess spawning overhead. In a tight loop (e.g., 1000 iterations), this can be the difference between 36s and 0.1s.
**Action:** Use Bash built-ins like `printf %()T`, parameter expansion (`${var#0}`), and string indexing (`${var:offset:length}`) to keep logic internal to the shell process. For atomic timestamping, capture all variables in a single `printf` call.
