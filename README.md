actionlint
==========
[![CI Status][ci-badge]][ci]
[![API Document][apidoc-badge]][apidoc]

[actionlint][repo] is a static checker for GitHub Actions workflow files. [Try it online!][playground]

Features:

- **Syntax check for workflow files** to check unexpected or missing keys following [workflow syntax][syntax-doc]
- **Strong type check for `${{ }}` expressions** to catch several semantic errors like access to not existing property,
  type mismatches, ...
- **Actions usage check** to check that inputs at `with:` and outputs in `steps.{id}.outputs` are correct
- **Reusable workflow check** to check inputs/outputs/secrets of reusable workflows and workflow calls
- **[shellcheck][] and [pyflakes][] integrations** for scripts at `run:`
- **Security checks**; [script injection][script-injection-doc] by untrusted inputs, hard-coded credentials
- **Other several useful checks**; [glob syntax][filter-pattern-doc] validation, dependencies check for `needs:`,
  runner label validation, cron syntax validation, ...

See the [full list][checks] of checks done by actionlint.

<img src="https://github.com/rhysd/ss/blob/master/actionlint/main.gif?raw=true" alt="actionlint reports 7 errors" width="806" height="492"/>

**Example of broken workflow:**

```yaml
on:
  push:
    branch: main
    tags:
      - 'v\d+'
jobs:
  test:
    strategy:
      matrix:
        os: [macos-latest, linux-latest]
    runs-on: ${{ matrix.os }}
    steps:
      - run: echo "Checking commit '${{ github.event.head_commit.message }}'"
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node_version: 18.x
      - uses: actions/cache@v4
        with:
          path: ~/.npm
          key: ${{ matrix.platform }}-node-${{ hashFiles('**/package-lock.json') }}
        if: ${{ github.repository.permissions.admin == true }}
      - run: npm install && npm test
```

**actionlint reports 7 errors:**

```
test.yaml:3:5: unexpected key "branch" for "push" section. expected one of "branches", "branches-ignore", "paths", "paths-ignore", "tags", "tags-ignore", "types", "workflows" [syntax-check]
  |
3 |     branch: main
  |     ^~~~~~~
test.yaml:5:11: character '\' is invalid for branch and tag names. only special characters [, ?, +, *, \, ! can be escaped with \. see `man git-check-ref-format` for more details. note that regular expression is unavailable. note: filter pattern syntax is explained at https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions#filter-pattern-cheat-sheet [glob]
  |
5 |       - 'v\d+'
  |           ^~~~
test.yaml:10:28: label "linux-latest" is unknown. available labels are "windows-latest", "windows-latest-8-cores", "windows-2025", "windows-2022", "windows-2019", "ubuntu-latest", "ubuntu-latest-4-cores", "ubuntu-latest-8-cores", "ubuntu-latest-16-cores", "ubuntu-24.04", "ubuntu-22.04", "ubuntu-20.04", "macos-latest", "macos-latest-xl", "macos-latest-xlarge", "macos-latest-large", "macos-15-xlarge", "macos-15-large", "macos-15", "macos-14-xl", "macos-14-xlarge", "macos-14-large", "macos-14", "macos-13-xl", "macos-13-xlarge", "macos-13-large", "macos-13", "self-hosted", "x64", "arm", "arm64", "linux", "macos", "windows". if it is a custom label for self-hosted runner, set list of labels in actionlint.yaml config file [runner-label]
   |
10 |         os: [macos-latest, linux-latest]
   |                            ^~~~~~~~~~~~~
test.yaml:13:41: "github.event.head_commit.message" is potentially untrusted. avoid using it directly in inline scripts. instead, pass it through an environment variable. see https://docs.github.com/en/actions/security-for-github-actions/security-guides/security-hardening-for-github-actions for more details [expression]
   |
13 |       - run: echo "Checking commit '${{ github.event.head_commit.message }}'"
   |                                         ^~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
test.yaml:17:11: input "node_version" is not defined in action "actions/setup-node@v4". available inputs are "always-auth", "architecture", "cache", "cache-dependency-path", "check-latest", "node-version", "node-version-file", "registry-url", "scope", "token" [action]
   |
17 |           node_version: 18.x
   |           ^~~~~~~~~~~~~
test.yaml:21:20: property "platform" is not defined in object type {os: string} [expression]
   |
21 |           key: ${{ matrix.platform }}-node-${{ hashFiles('**/package-lock.json') }}
   |                    ^~~~~~~~~~~~~~~
test.yaml:22:17: receiver of object dereference "permissions" must be type of object but got "string" [expression]
   |
22 |         if: ${{ github.repository.permissions.admin == true }}
   |                 ^~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
```

---

## Technical Details

### Shell

<img src="https://img.shields.io/badge/Shell-Zsh-blue?style=flat-square&logo=zsh&logoColor=white" alt="Shell: Zsh">
<img src="https://img.shields.io/badge/Kernel-CachyOS-orange?style=flat-square" alt="Kernel: CachyOS">

KibaOS uses **Zsh** by default with a pre-configured system-wide config at **`/etc/zsh/zshrc`**:

- Shared history across sessions.
- Tab completion with menu select.
- Autosuggestions & syntax highlighting.
- Minimalist Dracula-themed prompt.

**Useful Aliases:**

- `ll` -> `ls -lah` (via `eza`)
- `update` -> `sudo nala update && sudo nala upgrade -y`
- `install` -> `sudo nala install`
- `edit` -> Quick access to `micro`
- `please` -> Alias for `sudo`
- `cls` -> Clear the terminal

### Theme

<img src="https://img.shields.io/badge/Theme-Dracula-bd93f9?style=flat-square&logo=dracula&logoColor=white" alt="Theme: Dracula">

KibaOS ships the **Dracula** color scheme system-wide using the official palette from [draculatheme.com](https://draculatheme.com).

| Color      | Hex       | Role         |
| ---------- | --------- | ------------ |
| Background | `#282a36` | Primary BG   |
| Purple     | `#bd93f9` | Accent Color |
| Pink       | `#ff79c6` | Selection    |
| Green      | `#50fa7b` | Success      |

The scheme is applied to **KDE Plasma**, **Konsole**, **KWin** decorations, **Breeze Dark** panel, and **Plymouth**.

### System Requirements

| Component | Minimum                | Recommended         |
| --------- | ---------------------- | ------------------- |
| **CPU**   | 64-bit x86 (amd64)     | Dual-core or better |
| **RAM**   | 2 GB                   | 4 GB                |
| **Disk**  | 20 GB                  | **SSD** recommended |
| **GPU**   | **OpenGL 2.0** support | Dedicated GPU       |

---

## Build System

<p align="left">
  <img src="https://img.shields.io/badge/Build-live--build-blue?style=flat-square" alt="Build: live-build">
  <img src="https://img.shields.io/badge/CI-GitHub%20Actions-2088FF?style=flat-square&logo=github-actions&logoColor=white" alt="CI: GitHub Actions">
  <img src="https://img.shields.io/badge/Infrastructure-Docker-2496ED?style=flat-square&logo=docker&logoColor=white" alt="Infrastructure: Docker">
</p>

KibaOS is built using **live-build** inside a **Debian Trixie** **Docker** container via **GitHub Actions**.

- **Orchestration:** `.github/workflows/kiba.yml`
- **Automation:** Workflow runs on push to `main`, weekly schedules, and manual dispatch.
- **Delivery:** Completed ISOs are automatically uploaded to **SourceForge** from the `main` branch.

### Building Locally

Install `actionlint` command by downloading [the released binary][releases] or by Homebrew or by `go install`. See
[the installation document][install] for more details like how to manage the command with several package managers
or run via Docker container.

```sh
go install github.com/rhysd/actionlint/cmd/actionlint@latest
```

Basically all you need to do is run the `actionlint` command in your repository. actionlint automatically detects workflows and
checks errors. actionlint focuses on finding out mistakes. It tries to catch errors as much as possible and make false positives
as minimal as possible.

```sh
actionlint
```

Another option to try actionlint is [the online playground][playground]. Your browser can run actionlint through WebAssembly.

See [the usage document][usage] for more details.

## Documents

- [Checks][checks]: Full list of all checks done by actionlint with example inputs, outputs, and playground links.
- [Installation][install]: Installation instructions. Prebuilt binaries, a Docker image, building from source, a download script
  (for CI), supports by several package managers are available.
- [Usage][usage]: How to use `actionlint` command locally or on GitHub Actions, the online playground, an official Docker image,
  and integrations with reviewdog, Problem Matchers, super-linter, pre-commit, VS Code.
- [Configuration][config]: How to configure actionlint behavior. Currently, the labels of self-hosted runners, the configuration
  variables, and ignore patterns of errors for each file paths can be set.
- [Go API][api]: How to use actionlint as Go library.
- [References][refs]: Links to resources.

## Bug reporting

When you see some bugs or false positives, it is helpful to [file a new issue][issue-form] with a minimal example
of input. Giving me some feedbacks like feature requests or ideas of additional checks is also welcome.

See the [contribution guide](./CONTRIBUTING.md) for more details.

## License

actionlint is distributed under [the MIT license](./LICENSE.txt).

[ci-badge]: https://github.com/rhysd/actionlint/actions/workflows/ci.yaml/badge.svg
[ci]: https://github.com/rhysd/actionlint/actions/workflows/ci.yaml
[apidoc-badge]: https://pkg.go.dev/badge/github.com/rhysd/actionlint.svg
[apidoc]: https://pkg.go.dev/github.com/rhysd/actionlint
[repo]: https://github.com/rhysd/actionlint
[playground]: https://rhysd.github.io/actionlint/
[shellcheck]: https://github.com/koalaman/shellcheck
[pyflakes]: https://github.com/PyCQA/pyflakes
[syntax-doc]: https://docs.github.com/en/actions/reference/workflow-syntax-for-github-actions
[filter-pattern-doc]: https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions#filter-pattern-cheat-sheet
[script-injection-doc]: https://docs.github.com/en/actions/learn-github-actions/security-hardening-for-github-actions#understanding-the-risk-of-script-injections
[releases]: https://github.com/rhysd/actionlint/releases
[checks]: https://github.com/rhysd/actionlint/blob/v1.7.7/docs/checks.md
[install]: https://github.com/rhysd/actionlint/blob/v1.7.7/docs/install.md
[usage]: https://github.com/rhysd/actionlint/blob/v1.7.7/docs/usage.md
[config]: https://github.com/rhysd/actionlint/blob/v1.7.7/docs/config.md
[api]: https://github.com/rhysd/actionlint/blob/v1.7.7/docs/api.md
[refs]: https://github.com/rhysd/actionlint/blob/v1.7.7/docs/reference.md
[issue-form]: https://github.com/rhysd/actionlint/issues/new
