# Bolt's Journal - Critical Learnings

## 2025-05-14 - CI Optimization: Pruning Build Dependencies
**Learning:** Removing unused build dependencies from CI workflows can significantly reduce runner setup time. In the `kiba.yml` workflow, several development headers and build systems were being installed but never utilized by the `live-build` process or any subsequent scripts.
**Action:** Always audit `apt-get install` lists in CI workflows to ensure only necessary packages are installed. Document expected time savings (estimated ~45s in this case).
