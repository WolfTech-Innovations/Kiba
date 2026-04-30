## 2026-04-30 - [Optimization of Build Pipeline via Native Flags]
**Learning:** Using native `live-build` flags (like `--chroot-squashfs-compression-level`) is significantly more efficient than manual build hooks that repack filesystems. It avoids redundant decompression/compression cycles and simplifies the CI/CD pipeline.
**Action:** Always check if a build tool supports a feature natively before implementing a manual script or hook for the same purpose.
