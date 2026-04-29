# Contributing to KibaOS

<p align="center">
  <img src="../branding/kibaos_banner.png" alt="KibaOS Banner" width="100%">
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Status-Welcome-success?style=for-the-badge" alt="Welcome">
  <img src="https://img.shields.io/badge/License-MIT-purple?style=for-the-badge" alt="License">
</p>

---

First of all, thank you for your interest in contributing to KibaOS! We welcome contributions from developers, designers, and documentation enthusiasts.

---

## Developer Quick Start

To begin contributing to the KibaOS build system or customization hooks, follow these steps:

1. **Fork the Repo:** Create your own fork of [WolfTech-Innovations/Kiba](https://github.com/WolfTech-Innovations/Kiba).
2. **Setup Environment:** Ensure you have **Docker** installed on a Linux host.
3. **Local Build:** Run a local build to ensure your environment is working:
   ```bash
   git clone https://github.com/YOUR_USERNAME/Kiba
   cd Kiba
   docker run --rm --privileged -v "$PWD:/w" -e RUN_NUM=local debian:trixie /w/build.sh
   ```

---

## How to Contribute

### Reporting Bugs

If you find a bug, please open an issue. Provide:

- Steps to reproduce.
- Expected vs. Actual behavior.
- System logs or screenshots.

### Suggesting Features

We love new ideas! Please open an issue to discuss significant features before implementation. This ensures they align with the KibaOS philosophy of "modern simplicity."

### Submitting Pull Requests

- **Branching:** Work on a descriptive branch name (e.g., `feature/custom-icons`).
- **Commits:** Follow conventional commit messages.
- **Testing:** Always run a local build (see above) to verify your changes don't break the ISO generation.

---

## Project Structure

| Directory               | Purpose                                         |
| :---------------------- | :---------------------------------------------- |
| **`.github/workflows`** | GitHub Actions build and release orchestration. |
| **`branding/`**         | Visual assets (banners, logos).                 |
| **`docs/`**             | Technical documentation.                        |
| **`README.md`**         | Main project entry point.                       |
| **`WIKI.md`**           | Detailed technical manual.                      |

> [!TIP]
> Most of the system customization logic resides in the **`build.sh`** generation block within **`.github/workflows/kiba.yml`**. Look for the `cat > config/hooks/live/...` sections.

---

## Automated Triage

We use automated workflows to help manage the project:

- **Labeler:** Automatically labels PRs based on changed files.
- **Issue Triage:** Auto-labels new issues based on keywords (`bug`, `feature`, etc.).
- **Stale:** Automatically closes inactive issues after a period of time.

---

## License

By contributing to KibaOS, you agree that your contributions will be licensed under the **MIT License**.

---

## Related Reading

- [**Build System**](./build-system.md)
- [**Architecture**](./architecture.md)
- [**FAQ**](./faq.md)
