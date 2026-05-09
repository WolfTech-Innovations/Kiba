# Bolt's Journal

## 2025-05-14 - [pmbootstrap caching and apt optimization]
**Learning:** Manual deletion of the pmbootstrap work directory was preventing the reuse of cached APKs and build artifacts, causing massive overhead in subsequent builds. Additionally, omitting --no-install-recommends in Debian-based build environments leads to bloat and increased setup time.
**Action:** Always ensure pmbootstrap cache directories are preserved across builds and enforce --no-install-recommends for all apt-get install commands in CI/build scripts.
