## 2025-05-15 - [YAML Validation Speed]

**Learning:** In repositories with a massive number of small YAML files (570+ workflows in this case), the pure-Python `yaml.safe_load` becomes a significant bottleneck. `yaml.CSafeLoader` is ~7x faster and drastically reduces execution time.
**Action:** Always prefer `CSafeLoader` with a fallback for YAML-heavy scripts in this environment.

## 2026-05-14 - [Semantic YAML Parsing for Performance]
**Learning:** While `awk` or `grep` can be extremely fast for simple text scanning, they are unreliable for structured formats like YAML where property order and context (comments, script blocks) matter. A single-process Python script with `yaml.CSafeLoader` provides the best balance of speed (~300x faster than `yq` loops) and semantic correctness.
**Action:** Replace shell-based loops calling CLI parsers (`yq`, `jq`) with single-execution Python scripts for bulk metadata validation.

## 2025-06-15 - Kernel Build Performance with CachyOS
**Learning:** Migrating to CachyOS kernel requires proper repository configuration at the host level in the build script to avoid 'package not found' errors during mkarchiso execution.
**Action:** Ensure custom repositories are added to both /etc/pacman.conf and the profile's pacman.conf before building the ISO.

## 2026-06-16 - [Robust Mirror Monitoring for Build Workflows]

**Learning:** CachyOS kernel monitoring scripts rely on scraping HTML mirrors. These mirrors can change paths (e.g., from `/main/` to `/cachyos/`). Using a correct and specific sub-repository URL prevents build workflow failures and ensures the latest stable kernel is always detected.
**Action:** Periodically verify mirror URLs in automated monitoring scripts to prevent silent detection failures.
