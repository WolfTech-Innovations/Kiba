## 2025-05-14 - [Build Process Caching]
**Learning:** pmbootstrap and apt-get installations consume the majority of build time. Incremental builds are disabled when the WORKDIR is wiped.
**Action:** Use --no-install-recommends for apt-get and preserve pmbootstrap work directory between runs.
