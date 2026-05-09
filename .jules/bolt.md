# Bolt Optimization Journal

## 2025-05-15 - [Package Installation Efficiency]
**Learning:** The build script `scripts/kibatv_build.sh` was installing recommended packages during the dependency setup phase, which increased the number of installed packages and lengthened the setup time unnecessarily for a build environment.
**Action:** Implemented `--no-install-recommends` in the `apt-get install` command to streamline the build environment setup.
