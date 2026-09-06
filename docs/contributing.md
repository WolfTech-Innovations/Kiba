# Contributing to KibaOS Documentation

<p align="center">
  <img src="../branding/kibaos_banner.png" alt="KibaOS Banner" width="100%">
</p>

---

Thank you for your interest in contributing to KibaOS documentation! Good documentation is essential for helping users understand and make the most of KibaOS.

---

## Table of Contents

- [Getting Started](#getting-started)
- [Documentation Guidelines](#documentation-guidelines)
- [Documentation Structure](#documentation-structure)
- [Writing Style](#writing-style)
- [Related Reading](#related-reading)

---

## Getting Started

### Prerequisites

- A GitHub account
- Basic knowledge of Markdown
- Familiarity with KibaOS (recommended)

### Setting Up

1. **Fork the repository** on GitHub
2. **Clone your fork** locally:
   ```bash
   git clone https://github.com/YOUR_USERNAME/Kiba
   cd Kiba
   ```
3. **Create a branch** for your documentation changes:
   ```bash
   git checkout -b docs/<your-topic>
   ```

---

## Documentation Guidelines

### File Organization

- **Root-level docs:** High-level overviews (README.md, WIKI.md, CONTRIBUTING.md)
- **docs/ folder:** Detailed technical documentation
- **Use clear, descriptive filenames** in lowercase with hyphens (e.g., `build-system.md`)

### Cross-References

- Link to other documentation files using relative paths
- Use consistent link formatting: `[description](./path/to/file.md)`
- Always test your links to ensure they work

### Code Examples

- Use proper Markdown code blocks with language specification
- Keep examples concise and relevant
- Include comments explaining non-obvious parts

```bash
# Good example
sudo pacman -Syu  # Update all packages
```

---

## Documentation Structure

### Root Documentation

| File | Purpose |
| :--- | :------ |
| `README.md` | Main project entry point, user-facing |
| `WIKI.md` | Technical deep-dive and internals |
| `CONTRIBUTING.md` | Development contribution guide |
| `SECURITY.md` | Security policy and vulnerability reporting |
| `ACKNOWLEDGMENTS.md` | Credits and acknowledgments |

### Technical Documentation (docs/)

| File | Purpose |
| :--- | :------ |
| `architecture.md` | System architecture and components |
| `build-system.md` | Build infrastructure and CI/CD |
| `software-management.md` | Package management and repositories |
| `security-compliance.md` | Security features and compliance |
| `ux-design.md` | Visual design and user experience |
| `faq.md` | Frequently asked questions |
| `manual-compilation.md` | Manual build instructions |

---

## Writing Style

### General Guidelines

- **Be clear and concise:** Get to the point quickly
- **Use active voice:** "Run this command" not "This command should be run"
- **Be consistent:** Use the same terms for the same concepts throughout
- **Use present tense:** "The system does X" not "The system will do X"

### Formatting

- **Use headings** to create clear hierarchy
- **Use lists** for steps, features, or items
- **Use tables** for comparing options or showing configurations
- **Use code formatting** for commands, filenames, and technical terms
- **Use bold** for UI elements and important terms
- **Use italics** for emphasis and notes

### Examples

**Good:**
> To update the system, run `update` in the terminal.

**Bad:**
> You should probably run the update command if you want to update your system.

---

## Related Reading

- [Main Contributing Guide](../CONTRIBUTING.md)
- [Architecture Documentation](./architecture.md)
- [Build System Documentation](./build-system.md)
- [KibaOS Wiki](../WIKI.md)
