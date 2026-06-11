## 2025-05-15 - [YAML Validation Speed]

**Learning:** In repositories with a massive number of small YAML files (570+ workflows in this case), the pure-Python `yaml.safe_load` becomes a significant bottleneck. `yaml.CSafeLoader` is ~7x faster and drastically reduces execution time.
**Action:** Always prefer `CSafeLoader` with a fallback for YAML-heavy scripts in this environment.

## 2026-05-14 - [Semantic YAML Parsing for Performance]
**Learning:** While `awk` or `grep` can be extremely fast for simple text scanning, they are unreliable for structured formats like YAML where property order and context (comments, script blocks) matter. A single-process Python script with `yaml.CSafeLoader` provides the best balance of speed (~300x faster than `yq` loops) and semantic correctness.
**Action:** Replace shell-based loops calling CLI parsers (`yq`, `jq`) with single-execution Python scripts for bulk metadata validation.

## 2025-05-16 - [Arch Linux Build Optimizations]
**Learning:** For ISO or system image builds using `makepkg`, the default compression stage is a significant bottleneck, especially for large packages. Additionally, standard `ParallelDownloads` settings on the host are not inherited by chroot environments.
**Action:** Always inject `PKGEXT='.pkg.tar'` and `MAKEFLAGS="-j$(nproc)"` into `makepkg` calls for local/transient installs, and explicitly enable `ParallelDownloads` in the chroot's `pacman.conf`.
