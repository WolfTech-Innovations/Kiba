## 2025-05-15 - [YAML Validation Speed]

**Learning:** In repositories with a massive number of small YAML files (570+ workflows in this case), the pure-Python `yaml.safe_load` becomes a significant bottleneck. `yaml.CSafeLoader` is ~7x faster and drastically reduces execution time.
**Action:** Always prefer `CSafeLoader` with a fallback for YAML-heavy scripts in this environment.

## 2026-05-14 - [Semantic YAML Parsing for Performance]
**Learning:** While `awk` or `grep` can be extremely fast for simple text scanning, they are unreliable for structured formats like YAML where property order and context (comments, script blocks) matter. A single-process Python script with `yaml.CSafeLoader` provides the best balance of speed (~300x faster than `yq` loops) and semantic correctness.
**Action:** Replace shell-based loops calling CLI parsers (`yq`, `jq`) with single-execution Python scripts for bulk metadata validation.

## 2025-05-26 - [Chroot Keyring Initialization Order]
**Learning:** When adding external binary repositories (like Chaotic-AUR) to an Arch Linux chroot in `build.sh`, `pacman-key --init` and `pacman-key --populate archlinux` must be executed *before* any `pacman-key --recv-key` or `--lsign-key` operations. Failing to do so results in GPG errors as the trust database is not yet initialized.
**Action:** Always ensure standard keyring population happens at the very start of the customization script before third-party repository setup.

## 2025-05-26 - [Binary Repository vs. AUR Compilation]
**Learning:** Compiling packages like `arc-gtk-theme` and `calamares` from the AUR during a CI build is extremely slow and resource-intensive. Using a trusted binary repository like Chaotic-AUR reduces ISO build time significantly (~5-10 minutes saved).
**Action:** Prioritize pre-built binaries for common AUR packages in build orchestration scripts.
